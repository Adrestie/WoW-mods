-- ForeverUI: NPC gossip (GossipFrame) and quest (QuestFrame) windows in Camelot's style.
-- The client's frames and logic stay, moved to Camelot's places (portrait ButtonFrameTemplate
-- 338 x 496, QuestBG-Parchment background). The gossip keeps the 3.3.5 ScrollFrame instead of
-- Camelot's ScrollBox. The reward Cancel button stays (Camelot has only Complete Quest).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local D = {}
ForeverUI.NpcDialog = D

local SEP = string.char(92)

local N = {
	window = { 338, 496 },
	portrait = { side = 48, x = 1, y = 1.5 },
	parchment = { 7, -62, right = -9 },
	left = { 6, 4 }, right = { -6, 4 },
	-- gossip
	dialog = { scroll = { 8, -65, 300, 403 }, bar = { 6, -3, 3 } },
	-- quest
	quest = { scroll = { 5, -65, 300, 403 }, bar = { 9, -2, 5 }, child = 403, rewardChild = 334,
		material = { 7, -62, top = 300, down = 138, left = 239, right = 64 },
		progressTitle = { 10, -10 } },
}

local ART = {
	parchment = "questbg-parchment",
	book = "Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestLog-BookIcon",
}

local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- hides the 3.3.5 panel art: its four UI-QuestGreeting pieces and the greeting's bottom patch
local function blankPanel(p)
	for _, r in ipairs({ p:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local f = r:GetTexture()
			if type(f) == "string" then
				f = string.lower(f)
				if string.find(f, "questgreeting", 1, true) or string.find(f, "botleftpatch", 1, true) then
					r:SetAlpha(0)
				end
			end
		end
	end
end

-- Portrait ButtonFrameTemplate, parchment and close button; the NPC name moves to the title bar.
-- name, clientPortrait, closeButton: regions of client frame f;
-- o (optional): { height, page = parchment height }, by default 496 and the atlas height.
local function applySkin(f, name, clientPortrait, closeButton, o)
	o = o or {}
	clientPortrait:SetAlpha(0)
	name:SetAlpha(0)
	f:SetWidth(N.window[1])
	f:SetHeight(o.height or N.window[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	local skin = Tpl.PortraitWindow(f, {
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = name:GetText(),
	})
	local function follow() skin.title:SetText(name:GetText() or "") end
	hooksecurefunc(name, "SetText", follow)
	hooksecurefunc(name, "SetFormattedText", follow)
	-- Parchment in BORDER: Camelot puts it above the frame's rock and streaks with a sublevel;
	-- 3.3.5 has none, and in the same layer the rock draws in front. The panels and their
	-- material, child frames, stay on top.
	local background = f:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(background, ART.parchment)
	if o.page then background:SetHeight(o.page) end
	background:SetPoint("TOPLEFT", f, "TOPLEFT", N.parchment[1], N.parchment[2])
	skin.parchment = background
	Tpl.CloseButton(closeButton, f)
	closeButton:SetFrameLevel(f:GetFrameLevel() + 22)
	f.foreverSkin = skin
	return skin
end

-- unit portrait, else the book (GossipFrameUpdate, QuestFrame_SetPortrait)
local function portrait(skin, unit)
	if UnitExists(unit) then
		SetPortraitTexture(skin.portrait, unit)
	else
		skin.portrait:SetTexture(ART.book)
	end
end

-- quality outline on the 39 wide icon of a LargeItemButtonTemplate
local function outline(b, q)
	local icon = _G[b:GetName() .. "IconTexture"]
	local t = Tpl.Outline(b)
	if icon and not b.foreverOutlinePlaced then
		t:ClearAllPoints()
		t:SetAllPoints(icon)
		b.foreverOutlinePlaced = true
	end
	Tpl.QualityOutline(b, q)
end

-- Without a scroll bar the page takes all the room: the parchment covers the bar's gutter up
-- to the inner right edge, with the same margin as on the left (Camelot's inset 4 / -6 gives
-- 7 / -9); with the bar it gets back its atlas width.
local function fullPage(f, isFull)
	local h = f.foreverSkin
	local t = h and h.parchment
	if not t then return end
	local P = N.parchment
	t:ClearAllPoints()
	t:SetPoint("TOPLEFT", f, "TOPLEFT", P[1], P[2])
	if isFull then
		t:SetPoint("TOPRIGHT", f, "TOPRIGHT", P.right, P[2])
	else
		local e = ForeverUI.AtlasEntry(ART.parchment)
		t:SetWidth(e[6])
	end
end

-- Content follows the bar (Tpl.BarByContent): with it, the scroll frame, its child and the
-- client texts keep their XML widths; without it, each widens to leave the same margin right
-- of the page as on the left. widths: { { object, width with bar, width without bar } }
local function widen(widths, hasBar)
	for _, v in ipairs(widths) do
		if v[1] then v[1]:SetWidth(hasBar and v[2] or v[3]) end
	end
end

-- width that leaves right of the page (without bar: from N.parchment[1] to the window width
-- + N.parchment.right) the margin an object has on the left; left: its left edge in the window
local function widthToMargin(left)
	local P = N.parchment
	return (N.window[1] + P.right) - (left - P[1]) - left
end

-- adapter: what the window does besides the page (the quest has four scroll frames: only the
-- visible one decides, as Tpl.BarByContent calls it only when visible)
local function barIfNeeded(fx, f, adapter)
	return Tpl.BarByContent(fx, function(hasBar)
		fullPage(f, not hasBar)
		if adapter then adapter(hasBar) end
	end)
end

-- ------------------------------------------------------------ Gossip

function D.AfterDialog()
	local h = GossipFrame.foreverSkin
	if h then portrait(h, "npc") end
end

function D.SkinDialog()
	local f = GossipFrame
	if not f or f.foreverSkin then return end
	applySkin(f, GossipFrameNpcNameText, GossipFramePortrait, GossipFrameCloseButton)
	blankPanel(GossipFrameGreetingPanel)
	local S = N.dialog
	local fx = GossipGreetingScrollFrame
	fx:SetWidth(S.scroll[3])
	fx:SetHeight(S.scroll[4])
	place(fx, "TOPLEFT", f, "TOPLEFT", S.scroll[1], S.scroll[2])
	Tpl.BarAt(GossipGreetingScrollFrameScrollBar, fx, S.bar[1], S.bar[2], S.bar[3])
	-- content: scroll frame, its child, greeting text (270, at (10, -10) of the child), options
	-- (300, at -10 of the text; their text 275: GossipTitleButtonTemplate, follows its button)
	local x, textX = S.scroll[1], S.scroll[1] + 10
	local fxNoBar = widthToMargin(x)
	local widths = { { fx, S.scroll[3], fxNoBar }, { GossipGreetingScrollChildFrame, S.scroll[3], fxNoBar },
		{ GossipGreetingText, 270, widthToMargin(textX) } }
	for i = 1, NUMGOSSIPBUTTONS do
		local b = _G["GossipTitleButton" .. i]
		if b then
			widths[#widths + 1] = { b, 300, widthToMargin(x) }
			widths[#widths + 1] = { b:GetFontString(), 275, 275 + widthToMargin(x) - 300 }
		end
	end
	barIfNeeded(fx, f, function(hasBar) widen(widths, hasBar) end)
	place(GossipFrameGreetingGoodbyeButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.right[1], N.right[2])
	hooksecurefunc("GossipFrameUpdate", D.AfterDialog)
end

-- ------------------------------------------------------------ Quest

function D.AfterQuestPortrait()
	local h = QuestFrame.foreverSkin
	if h then portrait(h, "questnpc") end
end

-- after QuestInfo_ShowRewards: item quality outlines outside the quest log
-- (the log has its own, QuestLog.lua)
function D.AfterRewards()
	if QuestInfoFrame and QuestInfoFrame.questLog then return end
	for i = 1, MAX_NUM_ITEMS do
		local b = _G["QuestInfoItem" .. i]
		if b and b:IsShown() and b.type then
			local _, _, _, q = GetQuestItemInfo(b.type, b:GetID())
			outline(b, q)
		elseif b and b.foreverOutline then
			b.foreverOutline:Hide()
		end
	end
end

-- after QuestFrameProgressItems_Update: required items
function D.AfterProgress()
	for i = 1, MAX_REQUIRED_ITEMS do
		local b = _G["QuestProgressItem" .. i]
		if b and b:IsShown() and b.type == "required" then
			local _, _, _, q = GetQuestItemInfo("required", b:GetID())
			outline(b, q)
		elseif b and b.foreverOutline then
			b.foreverOutline:Hide()
		end
	end
end

function D.SkinQuest()
	local f = QuestFrame
	if not f or f.foreverSkin then return end
	applySkin(f, QuestFrameNpcNameText, QuestFramePortrait, QuestFrameCloseButton)
	local Q = N.quest
	local M = Q.material
	for _, name in ipairs({ "QuestFrameGreetingPanel", "QuestFrameDetailPanel", "QuestFrameProgressPanel", "QuestFrameRewardPanel" }) do
		local p = _G[name]
		blankPanel(p)
		-- material (QuestFrame_SetMaterial shows and hides it)
		local topLeft = _G[name .. "MaterialTopLeft"]
		topLeft:SetWidth(M.left)
		topLeft:SetHeight(M.top)
		place(topLeft, "TOPLEFT", f, "TOPLEFT", M[1], M[2])
		_G[name .. "MaterialTopRight"]:SetWidth(M.right)
		_G[name .. "MaterialTopRight"]:SetHeight(M.top)
		_G[name .. "MaterialBotLeft"]:SetWidth(M.left)
		_G[name .. "MaterialBotLeft"]:SetHeight(M.down)
		_G[name .. "MaterialBotRight"]:SetWidth(M.right)
		_G[name .. "MaterialBotRight"]:SetHeight(M.down)
	end
	-- content shared by quest pages (QuestInfo.xml: 285; QuestInfoFrame 300; all 5 from the child,
	-- QUEST_TEMPLATE_*: title at (5, -10)), progress (285 / 275 / 295, 10 from the child) and
	-- greeting (270 / 300 at 10, title buttons 300 at 0, their text 275); without bar, each widens
	-- to its left margin
	local x = Q.scroll[1]
	local fxNoBar = widthToMargin(x)
	local common = { { QuestInfoFrame, 300, widthToMargin(x) } }
	for _, n in ipairs({ "QuestInfoTitleHeader", "QuestInfoObjectivesText", "QuestInfoRewardText",
		"QuestInfoDescriptionHeader", "QuestInfoObjectivesHeader", "QuestInfoDescriptionText", "QuestInfoTimerText",
		"QuestInfoRewardsHeader", "QuestInfoItemChooseText", "QuestInfoReputationText", "QuestInfoObjectivesFrame",
		"QuestInfoRewardsFrame", "QuestInfoReputationsFrame", "QuestInfoRequiredMoneyFrame" }) do
		common[#common + 1] = { _G[n], 285, widthToMargin(x + 5) }
	end
	for i = 1, 10 do common[#common + 1] = { _G["QuestInfoObjective" .. i], 285, widthToMargin(x + 5) } end
	local progress, home = widthToMargin(x + Q.progressTitle[1]), widthToMargin(x + 10)
	local perPage = {
		QuestProgressScrollFrame = { { QuestProgressTitleText, 285, progress }, { QuestProgressText, 275, progress },
			{ QuestProgressRequiredItemsText, 295, progress } },
		QuestGreetingScrollFrame = { { GreetingText, 270, home }, { CurrentQuestsText, 300, home },
			{ AvailableQuestsText, 300, home } },
	}
	for i = 1, 32 do
		local b = _G["QuestTitleButton" .. i]
		if b then
			table.insert(perPage.QuestGreetingScrollFrame, { b, 300, widthToMargin(x) })
			table.insert(perPage.QuestGreetingScrollFrame, { b:GetFontString(), 275, 275 + widthToMargin(x) - 300 })
		end
	end
	-- material of each panel (239 + 64): without bar, up to the page edge like the parchment
	local material = widthToMargin(M[1]) - M.right
	for fx, p in pairs({ QuestGreetingScrollFrame = "QuestFrameGreetingPanel", QuestDetailScrollFrame = "QuestFrameDetailPanel",
		QuestProgressScrollFrame = "QuestFrameProgressPanel", QuestRewardScrollFrame = "QuestFrameRewardPanel" }) do
		perPage[fx] = perPage[fx] or {}
		table.insert(perPage[fx], { _G[p .. "MaterialTopLeft"], M.left, material })
		table.insert(perPage[fx], { _G[p .. "MaterialBotLeft"], M.left, material })
	end
	-- scroll frames and their children
	for _, v in ipairs({ { "QuestGreetingScrollFrame", "QuestGreetingScrollChildFrame", Q.child },
		{ "QuestDetailScrollFrame", "QuestDetailScrollChildFrame", Q.child },
		{ "QuestProgressScrollFrame", "QuestProgressScrollChildFrame", Q.child },
		{ "QuestRewardScrollFrame", "QuestRewardScrollChildFrame", Q.rewardChild } }) do
		local fx = _G[v[1]]
		fx:SetWidth(Q.scroll[3])
		fx:SetHeight(Q.scroll[4])
		place(fx, "TOPLEFT", f, "TOPLEFT", Q.scroll[1], Q.scroll[2])
		_G[v[2]]:SetHeight(v[3])
		Tpl.BarAt(_G[v[1] .. "ScrollBar"], fx, Q.bar[1], Q.bar[2], Q.bar[3])
		local widths = { { fx, Q.scroll[3], fxNoBar }, { _G[v[2]], Q.scroll[3], fxNoBar } }
		for _, c in ipairs(common) do widths[#widths + 1] = c end
		for _, c in ipairs(perPage[v[1]] or {}) do widths[#widths + 1] = c end
		barIfNeeded(fx, f, function(hasBar) widen(widths, hasBar) end)
	end
	place(QuestProgressTitleText, "TOPLEFT", QuestProgressScrollChildFrame, "TOPLEFT", Q.progressTitle[1], Q.progressTitle[2])
	-- buttons: action on the left, refusal on the right
	for _, b in ipairs({ QuestFrameAcceptButton, QuestFrameCompleteButton, QuestFrameCompleteQuestButton }) do
		place(b, "BOTTOMLEFT", f, "BOTTOMLEFT", N.left[1], N.left[2])
	end
	for _, b in ipairs({ QuestFrameDeclineButton, QuestFrameGoodbyeButton, QuestFrameCancelButton, QuestFrameGreetingGoodbyeButton }) do
		place(b, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.right[1], N.right[2])
	end
	hooksecurefunc("QuestFrame_SetPortrait", D.AfterQuestPortrait)
	hooksecurefunc("QuestInfo_ShowRewards", D.AfterRewards)
	hooksecurefunc("QuestFrameProgressItems_Update", D.AfterProgress)
end

-- ------------------------------------------------------------ Book, petition, guild registrar

-- ItemTextFrame, PetitionFrame and GuildRegistrarFrame (3.3.5: 384 x 512) in Camelot's
-- ButtonFrameTemplate 338 x 424 (DEFAULT_ITEM_TEXT_FRAME_WIDTH / HEIGHT), QuestBG-Parchment page
-- at (7, -62); positions from Camelot's itemtextframe, petitionframe and guildregistrarframe.
-- Portrait: the book, the charter or the NPC. The book follows the gossip scroll bar rules.
-- The large book mode (ParchmentLarge) and full page (ItemTextIsFullPage) do not exist in 3.3.5.
local P2 = {
	height = 424,
	book = { page = 357, scrollTopRight = { -31, -63 }, scrollBottomLeft = { 6, 6 }, bar = { 7, -5, 5 }, text = { 18, -15 }, textWidth = 270,
		currentPage = { 20, -35 }, previous = { 75, -41 }, following = { -23, -41 } },
	petition = { page = 334, charter = { 12, -80 }, left = { 4, 4 } },
	registrar = { page = 334, services = { 20, -70 }, purchase = { 20, -70 } },
}

local ART2 = {
	book = "Interface" .. SEP .. "Spellbook" .. SEP .. "Spellbook-Icon",
}

-- hides a window's unnamed textures (before skinning: ours are unnamed too)
local function blankUnnamed(f)
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then r:SetAlpha(0) end
	end
end

function D.SkinBook()
	local f = ItemTextFrame
	if not f or f.foreverSkin then return end
	local L = P2.book
	blankUnnamed(f)
	local skin = applySkin(f, ItemTextTitleText, ItemTextTitleText, ItemTextCloseButton,
		{ height = P2.height, page = L.page })
	skin.portrait:SetTexture(ART2.book)
	place(ItemTextMaterialTopLeft, "TOPLEFT", f, "TOPLEFT", N.parchment[1], N.parchment[2])
	place(ItemTextCurrentPage, "TOP", f, "TOP", L.currentPage[1], L.currentPage[2])
	place(ItemTextPrevPageButton, "CENTER", f, "TOPLEFT", L.previous[1], L.previous[2])
	place(ItemTextNextPageButton, "CENTER", f, "TOPRIGHT", L.following[1], L.following[2])
	local fx = ItemTextScrollFrame
	fx:ClearAllPoints()
	fx:SetPoint("TOPRIGHT", f, "TOPRIGHT", L.scrollTopRight[1], L.scrollTopRight[2])
	fx:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", L.scrollBottomLeft[1], L.scrollBottomLeft[2])
	for _, s in ipairs({ "Top", "Bottom", "Middle" }) do
		local t = _G["ItemTextScrollFrame" .. s]
		if t then t:SetAlpha(0) end
	end
	place(ItemTextPageText, "TOPLEFT", ItemTextPageScrollChild, "TOPLEFT", L.text[1], L.text[2])
	Tpl.BarAt(ItemTextScrollFrameScrollBar, fx, L.bar[1], L.bar[2], L.bar[3])
	-- content: without bar, the scroll frame covers the gutter, the text (270, 18 from the scroll
	-- frame) widens to its left margin, the material (256 + 64) reaches the page edge
	local textNoBar = widthToMargin(L.scrollBottomLeft[1] + L.text[1])
	local material = widthToMargin(N.parchment[1]) - 64
	barIfNeeded(fx, f, function(hasBar)
		fx:SetPoint("TOPRIGHT", f, "TOPRIGHT", L.scrollTopRight[1] + (hasBar and 0 or Tpl.GUTTER), L.scrollTopRight[2])
		ItemTextPageText:SetWidth(hasBar and L.textWidth or textNoBar)
		ItemTextMaterialTopLeft:SetWidth(hasBar and 256 or material)
		ItemTextMaterialBotLeft:SetWidth(hasBar and 256 or material)
	end)
end

function D.SkinPetition()
	local f = PetitionFrame
	if not f or f.foreverSkin then return end
	local T = P2.petition
	local charter = PetitionFramePortrait:GetTexture()
	blankPanel(f)
	local skin = applySkin(f, PetitionFrameNpcNameText, PetitionFramePortrait, PetitionFrameCloseButton,
		{ height = P2.height, page = T.page })
	skin.portrait:SetTexture(charter)
	place(PetitionFrameCharterTitle, "TOPLEFT", f, "TOPLEFT", T.charter[1], T.charter[2])
	place(PetitionFrameCancelButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.right[1], N.right[2])
	for _, b in ipairs({ PetitionFrameSignButton, PetitionFrameRequestButton }) do
		place(b, "BOTTOMLEFT", f, "BOTTOMLEFT", T.left[1], T.left[2])
	end
end

function D.AfterRegistrar()
	local h = GuildRegistrarFrame.foreverSkin
	if h then portrait(h, "npc") end
end

function D.SkinRegistrar()
	local f = GuildRegistrarFrame
	if not f or f.foreverSkin then return end
	local R = P2.registrar
	blankPanel(f)
	blankPanel(GuildRegistrarGreetingFrame)
	applySkin(f, GuildRegistrarFrameNpcNameText, GuildRegistrarFramePortrait, GuildRegistrarFrameCloseButton,
		{ height = P2.height, page = R.page })
	place(AvailableServicesText, "TOPLEFT", f, "TOPLEFT", R.services[1], R.services[2])
	place(GuildRegistrarPurchaseText, "TOPLEFT", f, "TOPLEFT", R.purchase[1], R.purchase[2])
	for _, b in ipairs({ GuildRegistrarFrameGoodbyeButton, GuildRegistrarFrameCancelButton }) do
		place(b, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.right[1], N.right[2])
	end
	place(GuildRegistrarFramePurchaseButton, "BOTTOMLEFT", f, "BOTTOMLEFT", N.left[1], N.left[2])
	hooksecurefunc("GuildRegistrar_OnShow", D.AfterRegistrar)
end

D.SkinDialog()
D.SkinQuest()
D.SkinBook()
D.SkinPetition()
D.SkinRegistrar()
