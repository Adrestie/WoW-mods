-- ForeverUI: the guild bank (GuildBankFrame, from Blizzard_GuildBankUI) with Camelot's layout.
-- The client's frames and logic stay. The log scrolls with the client's FauxScrollFrame bar, put
-- where Camelot's is; the search follows the bag rule; the bottom tabs are Social's and drive
-- the client's. The tab icon picker (GuildBankPopupFrame) is not restyled.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local G = {}
ForeverUI.GuildBank = G

local SEP = string.char(92)

local N = {
	window = { 750, 428 },
	marble = { 2, -20, -2, 20 },
	outer = { bottomLeft = { -2, 21 }, bottomRight = { 0, 21 }, topRight = { 0, -18 }, topLeft = { -2, -18 } },
	inner = { bottomLeft = { 14, 32 }, bottomRight = { -9, 32 }, topRight = { -9, -35 }, topLeft = { 14, -35 } },
	black = { 4, -4, -4, 3 },
	tabTitle = { 0, -30 }, limit = { 0, -370 }, emblem = { -70, 59 },
	column = { 18, -59 },
	money = { edge = { 1, 25, -4, 2 }, limit = { 8, 6 }, purse = { -2, 6 }, deposit = { -8, 30 } },
	tab = { x = 7, y = -30, gap = 3 },
	tabSide = { -1, -17 },
	-- Without a bar, widths leave on the right of the black background (16 .. 737: inner corners
	-- at 14 / -9 from the outer ones, then 4) the margin they have on the left: log (24, margin 8)
	-- 705, info (23, margin 7) 707 and its field 706
	questLog = { 24, -64, bar = { 6, 0, 3 }, width = 688, noBar = 705 },
	info = { scroll = { -9, 12 }, bar = { 4, -2, 3 }, save = { 20, 31 }, width = 691, field = 690,
		noBar = 707, fieldNoBar = 706 },
	search = { -15, -36, 130, 20 },
}

local ART = {
	vault = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildbankframe" .. SEP .. "guildvaultbg",
	gbCorners = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildbankframe" .. SEP .. "corners",
	vertical = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildbankframe" .. SEP .. "verttile",
	horizontal = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildbankframe" .. SEP .. "horiztile",
	money = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
}

-- The four corners in Corners (one file, four strips)
local CORNERS = {
	bottomLeft = { 0.015625, 0.515625, 0.00390625, 0.12890625 },
	bottomRight = { 0.015625, 0.515625, 0.13671875, 0.26171875 },
	topRight = { 0.015625, 0.515625, 0.26953125, 0.39453125 },
	topLeft = { 0.015625, 0.515625, 0.40234375, 0.52734375 },
}

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- h, v: tile horizontally / vertically
local function tile(t, file, h, v)
	t:SetTexture(file, true)
	if t.SetHorizTile then
		t:SetHorizTile(h and true or false)
		t:SetVertTile(v and true or false)
	end
end

-- A Corners / VertTile / HorizTile frame on f; slots: corner offsets, from relativeTo (the
-- outer frame's corners) or from f. ARTWORK layer: above the black (BORDER), itself above the
-- marble (BACKGROUND). Camelot puts marble and black in one layer with a sublevel; 3.3.5 has no
-- sublevels, so the marble would cover the black.
local function buildVaultFrame(f, slots, relativeTo)
	local corners = {}
	for key, point in pairs({ bottomLeft = "BOTTOMLEFT", bottomRight = "BOTTOMRIGHT", topRight = "TOPRIGHT", topLeft = "TOPLEFT" }) do
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetTexture(ART.gbCorners)
		local c = CORNERS[key]
		t:SetTexCoord(c[1], c[2], c[3], c[4])
		t:SetWidth(32)
		t:SetHeight(32)
		t:SetPoint(point, relativeTo and relativeTo[key] or f, point, slots[key][1], slots[key][2])
		corners[key] = t
	end
	local function edge(file, h, a1, c1, r1, x1, y1, a2, c2, r2, x2, y2)
		local t = f:CreateTexture(nil, "ARTWORK")
		tile(t, file, h, not h)
		t:SetPoint(a1, c1, r1, x1, y1)
		t:SetPoint(a2, c2, r2, x2, y2)
		return t
	end
	return {
		corners = corners,
		left = edge(ART.vertical, false, "TOPLEFT", corners.topLeft, "BOTTOMLEFT", -3, 0, "BOTTOMLEFT", corners.bottomLeft, "TOPLEFT", -3, 0),
		right = edge(ART.vertical, false, "TOPRIGHT", corners.topRight, "BOTTOMRIGHT", 4, 0, "BOTTOMRIGHT", corners.bottomRight, "TOPRIGHT", 4, 0),
		top = edge(ART.horizontal, true, "TOPLEFT", corners.topLeft, "TOPRIGHT", 0, 3, "TOPRIGHT", corners.topRight, "TOPLEFT", 0, 3),
		down = edge(ART.horizontal, true, "BOTTOMLEFT", corners.bottomLeft, "BOTTOMRIGHT", 0, -5, "BOTTOMRIGHT", corners.bottomRight, "BOTTOMLEFT", 0, -5),
	}
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

-- The bag search rule (name, type, subtype; case-insensitive)
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

-- After GuildBankFrame_Update: quality outline and search veil
function G.AfterUpdate()
	local tab = GetCurrentGuildBankTab()
	local text = G.field and G.field:GetText() or ""
	for c = 1, NUM_GUILDBANK_COLUMNS do
		for i = 1, NUM_SLOTS_PER_GUILDBANK_GROUP do
			local b = _G["GuildBankColumn" .. c .. "Button" .. i]
			if b then
				local link = GetGuildBankItemLink(tab, (c - 1) * NUM_SLOTS_PER_GUILDBANK_GROUP + i)
				Tpl.Quality(nil, b, link)
				if not b.foreverVeil then
					local v = b:CreateTexture(nil, "OVERLAY")
					v:SetTexture(0, 0, 0, 0.8)
					v:SetAllPoints(b)
					b.foreverVeil = v
				end
				Tpl.SetShown(b.foreverVeil, text ~= "" and link ~= nil and not linkMatches(link, text))
			end
		end
	end
end

-- The bottom tabs follow the client's
function G.UpdateTabs()
	local S = ForeverUI.Social
	for i, o in ipairs(G.tabs or {}) do
		S.selectTab(o, GuildBankFrame.selectedTab == i, true)
		o:SetWidth(S.tabWidth(o))
	end
end

-- The client's unnamed close button
local function clientCloseButton(f)
	for _, c in ipairs({ f:GetChildren() }) do
		if c:GetObjectType() == "Button" and not c:GetName() then
			local t = c:GetNormalTexture()
			local file = t and t:GetTexture()
			if type(file) == "string" and string.find(file, "MinimizeButton", 1, true) then
				return c
			end
		end
	end
end

function G.Skin()
	local f = GuildBankFrame
	if not f or f.foreverSkin then return end
	GuildBankFrameLeft:SetAlpha(0)
	GuildBankFrameRight:SetAlpha(0)
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	-- BasicFrameTemplate: the UI-Frame pieces
	local skin = Tpl.SimpleFrame(f)
	f.foreverSkin = skin
	-- The vault: red marble, outer and inner frames, black background
	local M = N.marble
	local marble = f:CreateTexture(nil, "BACKGROUND")
	tile(marble, ART.vault, true, true)
	marble:SetPoint("TOPLEFT", f, "TOPLEFT", M[1], M[2])
	marble:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", M[3], M[4])
	skin.marble = marble
	skin.outer = buildVaultFrame(f, N.outer)
	skin.inner = buildVaultFrame(f, N.inner, skin.outer.corners)
	-- Black in BORDER: above the marble and the rock, below the vault frames (see buildVaultFrame)
	local black = f:CreateTexture(nil, "BORDER")
	black:SetTexture(0, 0, 0, 1)
	black:SetPoint("TOPLEFT", skin.inner.corners.topLeft, "TOPLEFT", N.black[1], N.black[2])
	black:SetPoint("BOTTOMRIGHT", skin.inner.corners.bottomRight, "BOTTOMRIGHT", N.black[3], N.black[4])
	skin.black = black
	-- Close button
	local closeButton = clientCloseButton(f)
	if closeButton then
		Tpl.CloseButton(closeButton, f)
		closeButton:SetFrameLevel(f:GetFrameLevel() + 5)
		skin.closeButton = closeButton
	end
	-- Tab title, its limit, the emblem, the columns, the side tabs
	place(GuildBankTabTitleBackground, "TOP", f, "TOP", N.tabTitle[1], N.tabTitle[2])
	place(GuildBankTabLimitBackground, "TOP", f, "TOP", N.limit[1], N.limit[2])
	place(GuildBankEmblemFrame, "TOP", f, "TOP", N.emblem[1], N.emblem[2])
	place(GuildBankColumn1, "TOPLEFT", f, "TOPLEFT", N.column[1], N.column[2])
	place(GuildBankTab1, "TOPLEFT", f, "TOPRIGHT", N.tabSide[1], N.tabSide[2])
	-- Money
	local A = N.money
	local edge = CreateFrame("Frame", nil, f)
	edge:EnableMouse(false)
	edge:SetPoint("TOPLEFT", f, "BOTTOMLEFT", A.edge[1], A.edge[2])
	edge:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", A.edge[3], A.edge[4])
	skin.moneyBorder = edge
	skin.goldBorder = goldBorder(f, edge)
	place(GuildBankMoneyLimitLabel, "BOTTOMLEFT", f, "BOTTOMLEFT", A.limit[1], A.limit[2])
	place(GuildBankMoneyFrame, "BOTTOMRIGHT", f, "BOTTOMRIGHT", A.purse[1], A.purse[2])
	place(GuildBankFrameDepositButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", A.deposit[1], A.deposit[2])
	-- Log: the client's message frame and bar, in Camelot's place
	local J = N.questLog
	place(GuildBankMessageFrame, "TOPLEFT", GuildBankFrameLog, "TOPLEFT", J[1], J[2])
	local fx = GuildBankTransactionsScrollFrame
	fx:ClearAllPoints()
	fx:SetPoint("TOPLEFT", GuildBankMessageFrame, "TOPLEFT", 0, 0)
	fx:SetPoint("BOTTOMRIGHT", GuildBankMessageFrame, "BOTTOMRIGHT", 0, 0)
	for _, r in ipairs({ fx:GetRegions() }) do
		if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
	end
	Tpl.BarAt(GuildBankTransactionsScrollFrameScrollBar, GuildBankMessageFrame, J.bar[1], J.bar[2], J.bar[3])
	-- Log bar (FauxScrollFrame: hidden when everything fits); without it the message frame takes
	-- its room (688 from the template)
	Tpl.FauxByContent(fx, function(hasBar)
		GuildBankMessageFrame:SetWidth(hasBar and J.width or J.noBar)
	end)
	-- Tab info
	local I = N.info
	place(GuildBankInfoScrollFrame, "TOPLEFT", GuildBankInfo, "TOPLEFT", I.scroll[1], I.scroll[2])
	Tpl.BarAt(GuildBankInfoScrollFrameScrollBar, GuildBankInfoScrollFrame, I.bar[1], I.bar[2], I.bar[3])
	-- Info: the bar only when needed, the field takes its room (691 / 690 from the template)
	Tpl.BarByContent(GuildBankInfoScrollFrame, function(hasBar)
		GuildBankInfoScrollFrame:SetWidth(hasBar and I.width or I.noBar)
		GuildBankTabInfoEditBox:SetWidth(hasBar and I.field or I.fieldNoBar)
	end)
	place(GuildBankInfoSaveButton, "BOTTOMLEFT", f, "BOTTOMLEFT", I.save[1], I.save[2])
	-- Search
	local R = N.search
	local field = CreateFrame("EditBox", "ForeverUIGuildItemSearchBox", f, "InputBoxTemplate")
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
		Tpl.SetShown(placeholder, (field:GetText() or "") == "" and not field:HasFocus())
		G.AfterUpdate()
	end
	field:SetScript("OnTextChanged", update)
	field:SetScript("OnEditFocusGained", update)
	field:SetScript("OnEditFocusLost", update)
	field:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	field:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	field:HookScript("OnHide", function(self) self:SetText("") end)
	G.field = field
	-- Bottom tabs: Social's, driving the client's
	local S, O = ForeverUI.Social, N.tab
	G.tabs = {}
	for i, text in ipairs({ GUILD_BANK, GUILD_BANK_LOG, GUILD_BANK_MONEY_LOG, GUILD_BANK_TAB_INFO }) do
		local o = S.createTab(f, "ForeverUIGuildBankTab" .. i, false)
		o:SetText(text)
		if i == 1 then
			o:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", O.x, O.y)
		else
			o:SetPoint("TOPLEFT", G.tabs[i - 1], "TOPRIGHT", O.gap, 0)
		end
		o:SetScript("OnClick", function()
			GuildBankFrameTab_OnClick(_G["GuildBankFrameTab" .. i], i)
		end)
		G.tabs[i] = o
		ForeverUI.Suppress(_G["GuildBankFrameTab" .. i])
	end
	hooksecurefunc("GuildBankFrame_Update", G.AfterUpdate)
	hooksecurefunc("GuildBankFrameTab_OnClick", G.UpdateTabs)
	G.UpdateTabs()
end

G.Skin()

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(_, _, name)
	if name == "Blizzard_GuildBankUI" then
		G.Skin()
	end
end)
