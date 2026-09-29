-- ForeverUI: the trade window (TradeFrame) reskinned after camelot tradeframe.xml; the client's
-- frames and logic stay. Portraits are 48, centered in their ring hole, as in Inspect.lua.
-- Names are copied into a frame above the metal, which would cover them.
-- The money input keeps its 3.3.5 layout: camelot's growing compact mode does not exist here.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local T = {}
ForeverUI.Trade = T

local SEP = string.char(92)

local N = {
	window = { 344, 446 },
	portrait = { side = 48, x = 1, y = 1.5 },
	-- Recipient: metal corner at TOPRIGHT (-180 + 2 - 8, 7 + 9); portrait at the same offset
	-- from its corner as the player's portrait (14, -14.5).
	other = { corner = { -186, 16 }, portrait = { 14, -14.5 } },
	names = { player = { 65, -5, 100, 12 }, other = { 230, -5, 80, 12 } },
	targetBackground = { -172, -20, a = 0.15 },
	-- UI-Frame-BotCornerLeft 14 x 14, !UI-Frame-LeftTile 16 wide (their virtual texture sizes).
	-- Without a size, the 3.3.5 client draws a texture at the size of its whole sheet.
	separation = { top = { -178, -50 }, corner = { -178, -3 }, cornerSide = 14, ruleW = 16 },
	insets = {
		{ name = "playerItems", 4, -83, 166, -352 },
		{ name = "playerEnchant", 4, -354, 166, -418 },
		{ name = "playerMoney", 4, -58, 166, -82 },
		{ name = "otherItems", 175, -83, 338, -352, marble = 0.1 },
		{ name = "otherEnchant", 175, -354, 338, -418, marble = 0.1 },
		{ name = "otherMoney", 175, -58, 338, -81, marble = 0 },
	},
	otherBorder = { -168, -80, -7, -60, a = 0.6 },
	targetMoney = { -5, -64 },
	input = { 11, -61 },
	highlight = { player = { 6, -85 }, other = { 176, -85 }, l = 150 },
	objects = { player = { 14, -89 }, other = { 182, -89 } },
	enchant = { 15, -360, 166 },
	trade = { -85, 5 },
}

local ART = {
	marble = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	money = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	portraitCorner = "ui-frame-portraitmetal-cornertopleft",
	separation = "!ui-frame-lefttile",
	bottomCorner = "ui-frame-botcornerleft",
}

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- An inset (InsetFrameTemplate): marble and trim as window regions on an anchor frame.
-- e: TOPLEFT and BOTTOMRIGHT offsets from the window's TOPLEFT; e.marble: marble alpha.
local function inset(f, e)
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", e[1], e[2])
	rect:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", e[3], e[4])
	local marble = f:CreateTexture(nil, "BACKGROUND")
	marble:SetTexture(ART.marble, true)
	if marble.SetHorizTile then marble:SetHorizTile(true) marble:SetVertTile(true) end
	marble:SetAllPoints(rect)
	marble:SetAlpha(e.marble or 1)
	rect.marble = marble
	rect.trim = Tpl.NineSlice(f, "InsetFrameTemplate", rect)
	return rect
end

-- ThinGoldEdgeTemplate: three slices around rect, at the given alpha.
local function goldBorder(f, rect, alpha)
	local function piece(u1, u2, v1, v2)
		local t = f:CreateTexture(nil, "ARTWORK")
		t:SetTexture(ART.money)
		t:SetTexCoord(u1, u2, v1, v2)
		t:SetAlpha(alpha)
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

-- After the client: portraits (TradeFrame_Update sets them again)
function T.AfterUpdate()
	local h = TradeFrame.foreverSkin
	if not h then return end
	SetPortraitTexture(h.portrait, "player")
	SetPortraitTexture(h.otherPortrait, "NPC")
end

-- After the client: item quality. id: trade slot; the seventh (the enchant) keeps the color
-- its text carries.
function T.AfterPlayer(id)
	local link = GetTradePlayerItemLink(id)
	local name = (id ~= TRADE_ENCHANT_SLOT) and _G["TradePlayerItem" .. id .. "Name"] or nil
	Tpl.Quality(name, _G["TradePlayerItem" .. id .. "ItemButton"], link)
end

-- Same for the recipient's items.
function T.AfterTarget(id)
	local _, _, _, q = GetTradeTargetItemInfo(id)
	local name = (id ~= TRADE_ENCHANT_SLOT) and _G["TradeRecipientItem" .. id .. "Name"] or nil
	Tpl.Quality(name, _G["TradeRecipientItem" .. id .. "ItemButton"], GetTradeTargetItemLink(id), q)
end

function T.Skin()
	local f = TradeFrame
	if not f or f.foreverSkin then return end

	-- 3.3.5 art: the four unnamed pieces, the two portraits
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then
			r:SetAlpha(0)
		end
	end
	TradeFramePlayerPortrait:SetAlpha(0)
	TradeFrameRecipientPortrait:SetAlpha(0)
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	f:SetHitRectInsets(0, 0, 0, 0)

	-- ButtonFrameTemplate, player portrait, no title
	local skin = Tpl.PortraitWindow(f, {
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y, title = "",
	})
	f.foreverSkin = skin

	-- Insets, then the recipient's veil above their marble
	skin.insets = {}
	for _, e in ipairs(N.insets) do
		skin.insets[e.name] = inset(f, e)
	end
	local TB = N.targetBackground
	local veil = f:CreateTexture(nil, "BACKGROUND")
	veil:SetTexture(1, 1, 1, TB.a)
	veil:SetPoint("TOPLEFT", f, "TOPRIGHT", TB[1], TB[2])
	veil:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
	skin.otherVeil = veil
	-- Separator between the two halves
	local S = N.separation
	local bottomCorner = f:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(bottomCorner, ART.bottomCorner, true)
	bottomCorner:SetWidth(S.cornerSide)
	bottomCorner:SetHeight(S.cornerSide)
	bottomCorner:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", S.corner[1], S.corner[2])
	local rule = f:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(rule, ART.separation, true)
	rule:SetWidth(S.ruleW)
	rule:SetPoint("TOPLEFT", f, "TOPRIGHT", S.top[1], S.top[2])
	rule:SetPoint("BOTTOMLEFT", bottomCorner, "TOPLEFT", 0, 0)
	skin.separation = { rule = rule, corner = bottomCorner }
	-- Recipient's money: gold edge at 0.6, and the money frame
	local B = N.otherBorder
	local edge = CreateFrame("Frame", nil, f)
	edge:EnableMouse(false)
	edge:SetPoint("BOTTOMLEFT", f, "TOPRIGHT", B[1], B[2])
	edge:SetPoint("TOPRIGHT", f, "TOPRIGHT", B[3], B[4])
	skin.otherBorder = edge
	skin.goldBorder = goldBorder(f, edge, B.a)
	place(TradeRecipientMoneyFrame, "TOPRIGHT", f, "TOPRIGHT", N.targetMoney[1], N.targetMoney[2])
	place(TradePlayerInputMoneyFrame, "TOPLEFT", f, "TOPLEFT", N.input[1], N.input[2])

	-- Recipient's portrait and metal corner, above the window metal
	local A = N.other
	local hovered = CreateFrame("Frame", nil, f)
	hovered:SetAllPoints(f)
	hovered:SetFrameLevel(f:GetFrameLevel() + 21)
	hovered:EnableMouse(false)
	local corner = hovered:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(corner, ART.portraitCorner)
	corner:SetPoint("TOPLEFT", f, "TOPRIGHT", A.corner[1], A.corner[2])
	local portrait = hovered:CreateTexture(nil, "ARTWORK")
	portrait:SetWidth(N.portrait.side)
	portrait:SetHeight(N.portrait.side)
	portrait:SetPoint("TOPLEFT", corner, "TOPLEFT", A.portrait[1], A.portrait[2])
	skin.otherCorner, skin.otherPortrait = corner, portrait

	-- Names, copied above the metal
	skin.names = {}
	for key, fs in pairs({ player = TradeFramePlayerNameText, other = TradeFrameRecipientNameText }) do
		local P = N.names[key]
		fs:SetWidth(P[3])
		fs:SetHeight(P[4])
		place(fs, "TOPLEFT", f, "TOPLEFT", P[1], P[2])
		local copy = Tpl.Mirror(fs, hovered, GameFontNormal)
		copy:SetWidth(P[3])
		copy:SetHeight(P[4])
		skin.names[key] = copy
	end

	-- Highlights, items, enchant texts
	local H = N.highlight
	for _, v in ipairs({ { TradeHighlightPlayer, H.player }, { TradeHighlightRecipient, H.other } }) do
		v[1]:SetWidth(H.l)
		place(v[1], "TOPLEFT", f, "TOPLEFT", v[2][1], v[2][2])
	end
	TradeHighlightPlayerEnchant:SetWidth(H.l)
	TradeHighlightRecipientEnchant:SetWidth(H.l)
	place(TradePlayerItem1, "TOPLEFT", f, "TOPLEFT", N.objects.player[1], N.objects.player[2])
	place(TradeRecipientItem1, "TOPLEFT", f, "TOPLEFT", N.objects.other[1], N.objects.other[2])
	place(TradeFramePlayerEnchantText, "TOPLEFT", f, "TOPLEFT", N.enchant[1], N.enchant[2])
	place(TradeFrameRecipientEnchantText, "LEFT", TradeFramePlayerEnchantText, "LEFT", N.enchant[3], 0)

	-- Buttons, close button
	place(TradeFrameTradeButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.trade[1], N.trade[2])
	Tpl.CloseButton(TradeFrameCloseButton, f)
	TradeFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)

	hooksecurefunc("TradeFrame_Update", T.AfterUpdate)
	hooksecurefunc("TradeFrame_UpdatePlayerItem", T.AfterPlayer)
	hooksecurefunc("TradeFrame_UpdateTargetItem", T.AfterTarget)
end

T.Skin()
