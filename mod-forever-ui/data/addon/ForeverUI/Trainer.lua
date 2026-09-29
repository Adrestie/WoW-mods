-- Trainer window (ClassTrainerFrame, load-on-demand Blizzard_TrainerUI) in the Camelot style
-- (blizzard_trainerui.xml / .lua, with categories). The list is ours; clicks and headers use
-- the client's logic, and its rows, list and detail panel stay in place, invisible and
-- without mouse (the panel drives the Train button). Camelot has no detail panel, greeting,
-- Collapse All or Exit: the description is in the tooltip.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates
local L = ForeverUI.L

local T = {}

local SEP = string.char(92)
local TEXTURES = "Interface" .. SEP .. "ForeverUI" .. SEP .. "classtrainerframe" .. SEP .. "trainertextures"

-- Layout from camelot blizzard_trainerui.xml
local N = {
	window = { 338, 424 },
	portrait = { side = 48, x = 1, y = 1.5 },
	inset = { 4, -60, -6, 26 },
	rank = { 64, -35, 130, 18, edge = 18 },
	filter = { -13, -35, 18 },
	list = { 5, -5, 302, 330, noBar = 318, top = 1, down = 1, right = 1, indent = 10 },
	listBackground = { -3, 4, 3, -4 },
	bar = { 5, -2 },
	category = { h = 25, name = { 10, 2, 10 }, arrow = { -10, 2 }, tip = 2 },
	skill = { h = 47, icon = { 36, 6 }, name = { 6, -1, 12 }, rank = { 5, -1, 12 },
		prereq = { 0, -19, 240, 30 }, price = { 5, -7 }, veil = 2, gray = 0.55, tooltipFrame = 35 },
	train = { 80, 22, -6, 4 },
	money = { 148, 34, 5, -9, purse = { 8, 6 } },
}

-- TrainerTextures coordinates
local COORDS = {
	background = { 0.00195313, 0.5859375, 0.00195313, 0.65429688 },
	plate = { 0.00195313, 0.57421875, 0.65820313, 0.75 },
	hover = { 0.00195313, 0.57421875, 0.75390625, 0.84570313 },
	choice = { 0.00195313, 0.57421875, 0.84960938, 0.94140625 },
	rankLeft = { 0.60742188, 0.625, 0.78710938, 0.82226563 },
	rankRight = { 0.60742188, 0.625, 0.82617188, 0.86132813 },
	rankMiddle = { 0.60742188, 0.625, 0.74804688, 0.78320313 },
}

local ART = {
	marble = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	guild = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildframe" .. SEP .. "guildframe",
	bar = "Interface" .. SEP .. "PaperDollInfoFrame" .. SEP .. "UI-Character-Skills-Bar",
	money = "Interface" .. SEP .. "ForeverUI" .. SEP .. "moneyframe" .. SEP .. "ui-moneyframe-border",
}

-- camelot GameFontNormal_NoShadow / GameFontHighlight_NoShadow, missing from 3.3.5
local function noShadowFont(name, model)
	local p = CreateFont(name)
	p:SetFontObject(model)
	p:SetShadowOffset(0, 0)
	p:SetShadowColor(0, 0, 0, 0)
	return p
end
local FONTS = {
	category = noShadowFont("ForeverUIFontNormalNoShadow", GameFontNormal),
	categoryHover = noShadowFont("ForeverUIFontHighlightNoShadow", GameFontHighlight),
}

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- Texture with a file and tex coords; c: { left, right, top, bottom }
local function piece(host, layer, file, c)
	local t = host:CreateTexture(nil, layer)
	t:SetTexture(file)
	t:SetTexCoord(c[1], c[2], c[3], c[4])
	return t
end

-- ------------------------------------------------------------ rows

-- TrainerUICategoryTemplate: a collapsible header row; n: pool index
local function createCategory(list, n)
	local C = N.category
	local b = CreateFrame("Button", "ForeverUITrainerCategory" .. n, list)
	b:SetHeight(C.h)
	local g = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(g, "professions-recipe-header-left")
	g:SetPoint("LEFT", b, "LEFT", 0, C.tip)
	local d = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(d, "professions-recipe-header-right")
	d:SetPoint("RIGHT", b, "RIGHT", 0, C.tip)
	local m = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(m, "professions-recipe-header-middle", true)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	local name = b:CreateFontString(nil, "OVERLAY")
	name:SetFontObject(FONTS.category)
	name:SetJustifyH("LEFT")
	name:SetHeight(C.name[3])
	name:SetPoint("LEFT", b, "LEFT", C.name[1], C.name[2])
	local arrow = b:CreateTexture(nil, "ARTWORK")
	arrow:SetPoint("RIGHT", b, "RIGHT", C.arrow[1], C.arrow[2])
	local glow = b:CreateTexture(nil, "HIGHLIGHT")
	glow:SetBlendMode("ADD")
	glow:SetPoint("CENTER", arrow, "CENTER", 0, 0)
	b.name, b.arrow, b.glow = name, arrow, glow
	b:SetScript("OnEnter", function(self) self.name:SetFontObject(FONTS.categoryHover) end)
	b:SetScript("OnLeave", function(self) self.name:SetFontObject(FONTS.category) end)
	b:SetScript("OnClick", function(self)
		if self.expanded then
			CollapseTrainerSkillLine(self:GetID())
		else
			ExpandTrainerSkillLine(self:GetID())
		end
	end)
	return b
end

-- ClassTrainerSkillButtonTemplate: a skill row; n: pool index. A modified click acts like
-- the 3.3.5 detail icon (HandleModifiedItemClick).
local function createSkill(list, n)
	local C = N.skill
	local name = "ForeverUITrainerSkill" .. n
	local b = CreateFrame("Button", name, list)
	b:SetHeight(C.h)
	b:RegisterForClicks("LeftButtonUp")
	b:SetNormalTexture(TEXTURES)
	local plate = b:GetNormalTexture()
	plate:SetTexCoord(COORDS.plate[1], COORDS.plate[2], COORDS.plate[3], COORDS.plate[4])
	plate:ClearAllPoints()
	plate:SetAllPoints(b)
	b:SetHighlightTexture(TEXTURES)
	local h = b:GetHighlightTexture()
	h:SetTexCoord(COORDS.hover[1], COORDS.hover[2], COORDS.hover[3], COORDS.hover[4])
	h:ClearAllPoints()
	h:SetAllPoints(b)
	h:SetBlendMode("ADD")
	local veil = b:CreateTexture(nil, "BACKGROUND")
	veil:SetTexture(C.gray, C.gray, C.gray, 1)
	veil:SetBlendMode("MOD")
	veil:SetPoint("TOPLEFT", b, "TOPLEFT", C.veil, -C.veil)
	veil:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -C.veil, C.veil)
	veil:Hide()
	local choice = piece(b, "OVERLAY", TEXTURES, COORDS.choice)
	choice:SetBlendMode("ADD")
	choice:SetAllPoints(b)
	choice:Hide()
	local icon = b:CreateTexture(nil, "OVERLAY")
	icon:SetWidth(C.icon[1])
	icon:SetHeight(C.icon[1])
	icon:SetPoint("LEFT", b, "LEFT", C.icon[2], 0)
	local title = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetJustifyH("LEFT")
	title:SetHeight(C.name[3])
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", C.name[1], C.name[2])
	local prereq = b:CreateFontString(nil, "OVERLAY")
	prereq:SetFontObject(_G.SystemFont_Shadow_Small or GameFontHighlightSmall)
	prereq:SetJustifyH("LEFT")
	prereq:SetJustifyV("MIDDLE")
	prereq:SetWidth(C.prereq[3])
	prereq:SetHeight(C.prereq[4])
	prereq:SetPoint("LEFT", title, "LEFT", C.prereq[1], C.prereq[2])
	local rank = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	rank:SetJustifyH("LEFT")
	rank:SetHeight(C.rank[3])
	rank:SetPoint("BOTTOMLEFT", title, "BOTTOMRIGHT", C.rank[1], C.rank[2])
	local price = CreateFrame("Frame", name .. "Money", b, "SmallMoneyFrameTemplate")
	price:SetPoint("TOPRIGHT", b, "TOPRIGHT", C.price[1], C.price[2])
	if MoneyFrame_SetType then MoneyFrame_SetType(price, "STATIC") end
	b.veil, b.choice, b.icon, b.title, b.prereq, b.rank, b.price = veil, choice, icon, title, prereq, rank, price
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", C.tooltipFrame)
		GameTooltip:SetTrainerService(self:GetID())
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self, button)
		if IsModifiedClick() then
			HandleModifiedItemClick(GetTrainerServiceItemLink(self:GetID()))
			return
		end
		ClassTrainerSkillButton_OnClick(self, button)
	end)
	return b
end

-- Prerequisite text of service i (camelot ClassTrainerFrame_InitServiceButton, with 3.3.5
-- functions); kind: service type. Returns the text and whether the price shows.
local function prereq(i, kind)
	local text, sep = "", ""
	local level = GetTrainerServiceLevelReq(i)
	if level and level > 1 then
		if UnitLevel("player") >= level then
			text = text .. format(TRAINER_REQ_LEVEL, level)
		else
			text = text .. format(TRAINER_REQ_LEVEL_RED, level)
		end
		sep = PLAYER_LIST_DELIMITER
	end
	local skill, rankReq, hasRank = GetTrainerServiceSkillReq(i)
	if skill then
		text = text .. sep .. format(hasRank and TRAINER_REQ_SKILL_RANK or TRAINER_REQ_SKILL_RANK_RED, skill, rankReq)
		sep = PLAYER_LIST_DELIMITER
	end
	for j = 1, GetTrainerServiceNumAbilityReq(i) or 0 do
		local spell, hasAbility = GetTrainerServiceAbilityReq(i, j)
		if spell then
			text = text .. sep .. format(hasAbility and TRAINER_REQ_ABILITY or TRAINER_REQ_ABILITY_RED, spell)
			sep = PLAYER_LIST_DELIMITER
		end
	end
	if kind == "used" then
		return ITEM_SPELL_KNOWN, false
	elseif text ~= "" then
		return REQUIRES_LABEL .. " " .. text, true
	end
	return "", true
end

-- Fills a skill row from service i; money: the player's money, to color the price
local function fillSkill(b, i, money)
	local name, subName, kind = GetTrainerServiceInfo(i)
	b:SetID(i)
	b.icon:SetTexture(GetTrainerServiceIcon(i))
	local text, showPrice = prereq(i, kind)
	local unavailable = kind == "unavailable"
	b.icon:SetDesaturated(unavailable)
	Tpl.SetShown(b.veil, unavailable)
	b.title:SetText(name or UNKNOWN)
	b.prereq:SetText(text)
	b.rank:SetText((subName and subName ~= "") and format(PARENS_TEMPLATE, subName) or "")
	local cost = GetTrainerServiceCost(i)
	if showPrice and cost and cost > 0 then
		MoneyFrame_Update(b.price:GetName(), cost)
		SetMoneyFrameColor(b.price:GetName(), money >= cost and "white" or "red")
		b.price:Show()
	else
		b.price:Hide()
	end
	Tpl.SetShown(b.choice, ClassTrainerFrame.selectedService == i)
end

-- Row height of service i (headers and skills differ)
local function heightOf(i)
	local _, _, kind = GetTrainerServiceInfo(i)
	return kind == "header" and N.category.h or N.skill.h
end

-- How many rows from fromIndex fit in the height position
local function fitCount(fromIndex, total, position)
	local y, n = N.list.top, 0
	for i = fromIndex, total do
		local h = heightOf(i)
		if y + h > position then break end
		y = y + h
		n = n + 1
	end
	return n
end

-- List width depending on the scroll bar: camelot's width, or without a bar the same margin
-- on the right as on the left
local function layoutList(hasBar)
	local h = ClassTrainerFrame.foreverSkin
	local Li = N.list
	h.list:SetWidth(hasBar and Li[3] or Li.noBar)
end

-- Runs after ClassTrainerFrame_Update: camelot's list on the client's data, plus portrait,
-- title and rank. The list scrolls one row at a time (3.3.5 clips only in a ScrollFrame).
function T.Update()
	local f = ClassTrainerFrame
	local h = f and f.foreverSkin
	if not h then return end
	SetPortraitTexture(h.portrait, "npc")
	T.UpdateRank()
	local total = GetNumTrainerServices() or 0
	local position = N.list[4] - N.list.down
	-- Largest offset: the one from which the end fits
	local maxValue = 0
	for d = 0, total do
		if fitCount(d + 1, total, position) >= total - d then
			maxValue = d
			break
		end
	end
	h.maxValue = maxValue
	-- Keep the selection in view when it changes (the client selects the first learnable skill
	-- on open)
	local selected = f.selectedService
	if selected and selected ~= h.lastChoice then
		h.lastChoice = selected
		if selected <= h.offset then
			h.offset = selected - 1
		elseif selected > h.offset + fitCount(h.offset + 1, total, position) then
			local d = selected - 1
			while d > 0 and fitCount(d, total, position) >= selected - d + 1 do d = d - 1 end
			h.offset = d
		end
	end
	h.offset = math.max(0, math.min(h.offset or 0, maxValue))
	local hasBar = maxValue > 0
	if hasBar ~= h.hasBar then
		h.hasBar = hasBar
		layoutList(hasBar)
	end
	local width = h.list:GetWidth() - N.list.right
	local money = GetMoney()
	local y, nc, ns = N.list.top, 0, 0
	local subCategory = false
	-- A header before the offset indents the following skills
	for i = 1, h.offset do
		local _, _, kind = GetTrainerServiceInfo(i)
		if kind == "header" then subCategory = true end
	end
	for i = h.offset + 1, total do
		local name, _, kind, expanded = GetTrainerServiceInfo(i)
		local ht = (kind == "header") and N.category.h or N.skill.h
		if y + ht > position then break end
		local row
		if kind == "header" then
			subCategory = true
			nc = nc + 1
			row = h.categories[nc] or createCategory(h.list, nc)
			h.categories[nc] = row
			row:SetID(i)
			row.expanded = expanded and true or false
			row.name:SetText(name or "")
			local atlas = expanded and "professions-recipe-header-collapse" or "professions-recipe-header-expand"
			ForeverUI.SetAtlas(row.arrow, atlas)
			ForeverUI.SetAtlas(row.glow, atlas)
			place(row, "TOPLEFT", h.list, "TOPLEFT", 0, -y)
			row:SetWidth(width)
		else
			ns = ns + 1
			row = h.skills[ns] or createSkill(h.list, ns)
			h.skills[ns] = row
			fillSkill(row, i, money)
			local indent = subCategory and N.list.indent or 0
			place(row, "TOPLEFT", h.list, "TOPLEFT", indent, -y)
			row:SetWidth(width - indent)
		end
		row:Show()
		y = y + ht
	end
	for i = nc + 1, #h.categories do h.categories[i]:Hide() end
	for i = ns + 1, #h.skills do h.skills[i]:Hide() end
	h.bar:Configure(maxValue + 1, 1, h.offset)
end

-- Rank of the trainer's profession. GetTrainerTradeskillRankValues is missing in 3.3.5, so
-- it is read from GetSkillLineInfo by the profession name (GetTrainerServiceSkillLine).
function T.UpdateRank()
	local h = ClassTrainerFrame.foreverSkin
	local bar = h.rank
	local profession
	if IsTradeskillTrainer() then
		for i = 1, GetNumTrainerServices() or 0 do
			profession = GetTrainerServiceSkillLine(i)
			if profession then break end
		end
	end
	local rank, maxValue, bonus
	if profession then
		for j = 1, GetNumSkillLines() or 0 do
			local name, header, _, r, _, b, m = GetSkillLineInfo(j)
			if not header and name == profession then
				rank, bonus, maxValue = r, b, m
				break
			end
		end
	end
	if not rank or not maxValue or maxValue <= 0 then
		bar:Hide()
		return
	end
	bar:SetMinMaxValues(0, maxValue)
	bar:SetValue(rank)
	if bonus and bonus > 0 then
		bar.text:SetFormattedText(L.TRAINER_RANK_BONUS, rank, bonus, maxValue)
	else
		bar.text:SetFormattedText(L.TRAINER_RANK, rank, maxValue)
	end
	bar:Show()
end

-- ------------------------------------------------------------ window

-- Client screen made invisible and mouse-free: rows, lists, details
local function suppress()
	for i = 1, CLASS_TRAINER_SKILLS_DISPLAYED or 11 do
		local b = _G["ClassTrainerSkill" .. i]
		if b then b:SetAlpha(0) b:EnableMouse(false) end
	end
	for _, name in ipairs({ "ClassTrainerListScrollFrame", "ClassTrainerDetailScrollFrame" }) do
		local fx = _G[name]
		if fx then
			fx:SetAlpha(0)
			fx:EnableMouse(false)
			if fx.EnableMouseWheel then fx:EnableMouseWheel(false) end
			for _, s in ipairs({ "ScrollBar", "ScrollBarScrollUpButton", "ScrollBarScrollDownButton" }) do
				local c = _G[name .. s]
				if c then c:EnableMouse(false) end
			end
		end
	end
	if ClassTrainerSkillIcon then ClassTrainerSkillIcon:EnableMouse(false) end
	for _, r in ipairs({ ClassTrainerSkillHighlightFrame, ClassTrainerGreetingText, ClassTrainerHorizontalBarLeft,
		ClassTrainerNameText, ClassTrainerFramePortrait }) do
		if r then r:SetAlpha(0) end
	end
	for _, c in ipairs({ ClassTrainerExpandButtonFrame, ClassTrainerCancelButton }) do
		if c then ForeverUI.Suppress(c) end
	end
end

function T.Skin()
	local f = ClassTrainerFrame
	if not f or f.foreverSkin then return end
	-- 3.3.5 art: the four UI-ClassTrainer-* textures (two unnamed) and the unnamed right piece
	-- of the horizontal bar
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local t = r:GetTexture()
			if type(t) == "string" then
				t = string.lower(t)
				if string.find(t, "ui-classtrainer-", 1, true) or string.find(t, "horizontalbar", 1, true) then
					r:SetAlpha(0)
				end
			end
		end
	end
	suppress()
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	local skin = Tpl.PortraitWindow(f, {
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = ClassTrainerNameText:GetText(),
	})
	f.foreverSkin = skin
	local function follow() skin.title:SetText(ClassTrainerNameText:GetText() or "") end
	hooksecurefunc(ClassTrainerNameText, "SetText", follow)
	-- Inset: marble (BORDER), list background (ARTWORK), trim (OVERLAY, above the background it
	-- frames, as in camelot)
	local E = N.inset
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", E[1], E[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", E[3], E[4])
	local marble = f:CreateTexture(nil, "BORDER")
	marble:SetTexture(ART.marble, true)
	if marble.SetHorizTile then marble:SetHorizTile(true) marble:SetVertTile(true) end
	marble:SetAllPoints(rect)
	skin.inset = { rect = rect, marble = marble, trim = Tpl.NineSlice(f, "InsetFrameTemplate", rect, "OVERLAY") }
	-- List and its background
	local Li = N.list
	local list = CreateFrame("Frame", "ForeverUITrainerList", f)
	list:SetPoint("TOPLEFT", rect, "TOPLEFT", Li[1], Li[2])
	list:SetWidth(Li[3])
	list:SetHeight(Li[4])
	skin.list = list
	skin.categories, skin.skills, skin.offset = {}, {}, 0
	local F = N.listBackground
	local background = piece(f, "ARTWORK", TEXTURES, COORDS.background)
	background:SetPoint("TOPLEFT", list, "TOPLEFT", F[1], F[2])
	background:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", F[3], F[4])
	skin.listBackground = background
	-- camelot scroll bar, right of the list
	local bar = ForeverUI.CreateScrollBar("ForeverUITrainerScrollBar", f, list)
	bar:ClearAllPoints()
	bar:SetPoint("TOPLEFT", list, "TOPRIGHT", N.bar[1], N.bar[2])
	bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", N.bar[1], N.bar[2])
	bar.onScroll = function(new)
		skin.offset = new
		T.Update()
	end
	skin.bar = bar
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, direction)
		skin.offset = math.max(0, math.min((skin.offset or 0) - direction, skin.maxValue or 0))
		T.Update()
	end)
	-- Rank bar (profession trainers)
	local R = N.rank
	local rank = CreateFrame("StatusBar", "ForeverUITrainerRankBar", f)
	rank:SetWidth(R[3])
	rank:SetHeight(R[4])
	rank:SetPoint("TOPLEFT", f, "TOPLEFT", R[1], R[2])
	rank:SetStatusBarTexture(ART.bar)
	rank:SetStatusBarColor(0, 0, 1, 0.5)
	local rankBackground = rank:CreateTexture(nil, "BACKGROUND")
	rankBackground:SetAllPoints(rank)
	rankBackground:SetTexture(0, 0, 0.75, 0.5)
	local rg = piece(rank, "ARTWORK", ART.guild, COORDS.rankLeft)
	rg:SetWidth(R.edge)
	rg:SetPoint("TOPLEFT", rank, "TOPLEFT", -2, 0)
	rg:SetPoint("BOTTOMLEFT", rank, "BOTTOMLEFT", -2, 0)
	local rd = piece(rank, "ARTWORK", ART.guild, COORDS.rankRight)
	rd:SetWidth(R.edge)
	rd:SetPoint("TOPRIGHT", rank, "TOPRIGHT", 2, 0)
	rd:SetPoint("BOTTOMRIGHT", rank, "BOTTOMRIGHT", 2, 0)
	local rm = piece(rank, "ARTWORK", ART.guild, COORDS.rankMiddle)
	rm:SetPoint("TOPLEFT", rg, "TOPRIGHT", 0, 0)
	rm:SetPoint("BOTTOMRIGHT", rd, "BOTTOMLEFT", 0, 0)
	rank.text = rank:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	rank.text:SetPoint("CENTER", rank, "CENTER", 0, 0)
	rank:Hide()
	skin.rank = rank
	-- Filter
	local Fi = N.filter
	local dd = ClassTrainerFrameFilterDropDown
	Tpl.FilterMenu(dd, Fi[3])
	place(dd, "TOPRIGHT", f, "TOPRIGHT", Fi[1], Fi[2])
	-- Train button and money
	local Tr = N.train
	local b = ClassTrainerTrainButton
	b:SetWidth(Tr[1])
	b:SetHeight(Tr[2])
	place(b, "BOTTOMRIGHT", f, "BOTTOMRIGHT", Tr[3], Tr[4])
	Tpl.PanelButton(b)
	local A = N.money
	local moneyFrame = f:CreateTexture(nil, "ARTWORK")
	moneyFrame:SetTexture(ART.money)
	moneyFrame:SetWidth(A[1])
	moneyFrame:SetHeight(A[2])
	moneyFrame:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", A[3], A[4])
	skin.moneyFrame = moneyFrame
	place(ClassTrainerMoneyFrame, "RIGHT", moneyFrame, "RIGHT", A.purse[1], A.purse[2])
	Tpl.CloseButton(ClassTrainerFrameCloseButton, f)
	ClassTrainerFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	hooksecurefunc("ClassTrainerFrame_Update", T.Update)
end

T.Skin()

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(_, _, name)
	if name == "Blizzard_TrainerUI" then
		T.Skin()
	end
end)
