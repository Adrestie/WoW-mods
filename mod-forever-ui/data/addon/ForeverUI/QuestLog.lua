-- Quest log as the list pane of the world map. In camelot the log is not a window: it is
-- QuestMapFrame, a 330-wide pane on the right of the map (blizzard_worldmap.lua,
-- AttachQuestLog), and L opens the map with it. Quest markers and map jumps use WotLK's own
-- (WorldMapQuestFrame<n>, QuestPOI_DisplayButton, WorldMap_OpenToQuest). Clicking a quest
-- replaces the list with its details page.

ForeverUI = ForeverUI or {}

local J = {}
ForeverUI.QuestLog = J
local L = ForeverUI.L

-- Pane layout (camelot questmapframe.xml)
local V = {
	width = 330, x = -3, top = -25, down = 3,
	listRight = -22, listBottom = 9, listTop = -29,
	headerW = 289, headerH = 22, headerX = 9,
	questW = 290, questTextX = 31, questTextY = -8,
	checkboxSide = 14, checkboxY = -8,
	objectiveW = 220, objectiveTextW = 205,
	searchW = 200, searchH = 20, searchX = 6, searchY = 7,
	counterW = 100, counterH = 20, counterX = 3,
	settingW = 15, settingH = 16, settingX = 19, settingY = 25,
	barX = 8, barTop = 2, barBottom = -4,
	step = 16,
}

-- Row gaps from QuestLogQuests_UpdateButtonSpacing, for the row types 3.3.5 has
local GAP = {
	headerAfterNone = 8, headerAfterHeader = 6, headerAfterQuest = 4,
	questAfterHeader = 2, questAfterQuest = -3,
}

-- camelot colors: GlobalColor.db2, and blizzard_framexmlbase/constants.lua for difficulty
local COLOR = {
	objective = { 0.8, 0.8, 0.8 },               -- QUEST_OBJECTIVE_FONT_COLOR
	objectiveHover = { 1, 1, 1 },               -- QUEST_OBJECTIVE_HIGHLIGHT_FONT_COLOR
	headerIdle = { 0.502, 0.502, 0.502 },      -- DISABLED_FONT_COLOR
	headerHover = { 1, 1, 1 },                 -- HIGHLIGHT_FONT_COLOR
	difficulty = {
		trivial = { 0.50, 0.50, 0.50 }, standard = { 0.25, 0.75, 0.25 },
		difficult = { 1.00, 0.82, 0.00 }, verydifficult = { 1.00, 0.50, 0.25 },
		impossible = { 1.00, 0.10, 0.10 },
	},
	difficultyHover = {
		trivial = { 0.70, 0.70, 0.70 }, standard = { 0.43, 0.93, 0.43 },
		difficult = { 1.00, 1.00, 0.10 }, verydifficult = { 1.00, 0.75, 0.44 },
		impossible = { 1.00, 0.40, 0.40 },
	},
	-- Quest details page: the "Default" material of GetMaterialTextColors
	text = { 0.18, 0.122, 0.059 },             -- DEFAULT_MATERIAL_TEXT_COLOR
	title = { 0, 0, 0 },                        -- DEFAULT_MATERIAL_TITLETEXT_COLOR
	titleShadow = { 0.49, 0.35, 0.05 },          -- QuestFont_Shadow_Huge
	objectiveDone = { 0.2, 0.2, 0.2 },           -- QUEST_OBJECTIVE_COMPLETED_FONT_COLOR
	reward = { 0.902, 0.788, 0.671 },       -- QuestMapRewardsFont
	commonGray = { 0.659, 0.659, 0.659 },       -- COMMON_GRAY_COLOR
}

-- Texts: 3.3.5's when it has them, camelot's otherwise (GlobalStrings.db2), in
-- Texts_<locale>.lua
local TEXT = {
	search = L.QUESTLOG_SEARCH,                   -- SEARCH_QUEST_LOG
	noResults = L.QUESTLOG_NO_RESULTS,           -- QUEST_LOG_NO_RESULTS
	empty = L.QUESTLOG_EMPTY,                         -- QUEST_LOG_NO_QUESTS
	counter = L.QUESTLOG_COUNT,                     -- QUEST_LOG_COUNT_TEMPLATE
	showObjectives = L.QUESTLOG_SHOW_OBJECTIVES,   -- QUEST_LOG_SHOW_OBJECTIVES
	ready = L.QUESTLOG_READY,                         -- QUEST_WATCH_QUEST_READY
	details = L.QUESTLOG_CLICK_DETAILS,              -- CLICK_QUEST_DETAILS
	untrack = L.QUESTLOG_UNTRACK_QUEST,         -- UNTRACK_QUEST
	shareInChat = L.QUESTLOG_SHARE_IN_CHAT,         -- SHARE_IN_CHAT
	trackAll = L.QUESTLOG_TRACK_ALL,               -- QUEST_LOG_TRACK_ALL
	untrackAll = L.QUESTLOG_UNTRACK_ALL,           -- QUEST_LOG_UNTRACK_ALL
	-- Quest details page
	untrackShort = L.QUESTLOG_UNTRACK,          -- UNTRACK_QUEST_ABBREV
	rewards = QUEST_REWARDS,                     -- REWARDS (3.3.5: QUEST_REWARDS)
	titleFailed = L.QUESTLOG_TITLE_FAILED,            -- QUEST_TITLE_FORMAT_FAILED
}

local FONT = "Fonts\\FRIZQT__.TTF"

local function color(t, c)
	t:SetTextColor(c[1], c[2], c[3])
end

-- ---------------------------------------------------------------- state
-- ForeverUIDB exists only once our saved variables are loaded.
local function settings()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.questLog = ForeverUIDB.questLog or {}
	local r = ForeverUIDB.questLog
	if r.pane == nil then r.pane = true end            -- questLogOpen
	if r.objectives == nil then r.objectives = true end
	return r
end
J.settings = settings

-- -------------------------------------------------------------- difficulty
-- WotLK's ranking, camelot's colors.
local function difficultyKey(level)
	local c = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
	if c and QuestDifficultyColors then
		for key, value in pairs(QuestDifficultyColors) do
			if value == c and COLOR.difficulty[key] then
				return key
			end
		end
	end
	return "difficult"
end

-- ------------------------------------------------------------- data
-- A log entry, with what its row shows.
local function entry(index)
	local title, level, tag, group, headerFlag, collapsed, completed, daily, questID = GetQuestLogTitle(index)
	if not title then
		return nil
	end
	return {
		index = index, title = title, level = level, questTag = tag,
		isHeader = headerFlag and true or false, isCollapsed = collapsed and true or false,
		isComplete = completed, isDaily = daily, questID = questID,
	}
end

local function isElite(info)
	return info.questTag == ELITE
end

-- QuestLogQuests_GetTitle with camelot's override: "[" level ("+" if elite) "] ",
-- preceded by "[n] " if n party members have the quest.
local function questTitle(info)
	local title = "[" .. tostring(info.level) .. (isElite(info) and "+" or "") .. "] " .. info.title
	local members = 0
	for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
		if IsUnitOnQuest and IsUnitOnQuest(info.index, "party" .. i) then
			members = members + 1
		end
	end
	if members > 0 then
		title = "[" .. members .. "] " .. title
	end
	return title
end

-- ------------------------------------------------------------- search
-- QuestSearcher: plain text, on the title, objective text and objectives. A collapsed
-- header hides its quests in 3.3.5, so everything is expanded during a search and each
-- header gets its state back by name.
local R = { text = nil, states = nil }

local function expandAll()
	R.states = {}
	for i = GetNumQuestLogEntries(), 1, -1 do
		local info = entry(i)
		if info and info.isHeader then
			R.states[info.title] = info.isCollapsed
			if info.isCollapsed then
				ExpandQuestHeader(i)
			end
		end
	end
end

local function restoreStates()
	if not R.states then
		return
	end
	for i = GetNumQuestLogEntries(), 1, -1 do
		local info = entry(i)
		if info and info.isHeader and R.states[info.title] then
			CollapseQuestHeader(i)
		end
	end
	R.states = nil
end

-- Whether a quest matches the search text
local function linkMatches(info)
	if not R.text then
		return true
	end
	local searching = R.text
	if string.find(string.lower(info.title), searching, 1, true) then
		return true
	end
	local selection = GetQuestLogSelection()
	SelectQuestLogEntry(info.index)
	local _, objectives = GetQuestLogQuestText()
	SelectQuestLogEntry(selection)
	if objectives and string.find(string.lower(objectives), searching, 1, true) then
		return true
	end
	for i = 1, GetNumQuestLeaderBoards(info.index) do
		local text = GetQuestLogLeaderBoard(i, info.index)
		if text and string.find(string.lower(text), searching, 1, true) then
			return true
		end
	end
	return false
end

-- Filters the list by text; an empty text ends the search
function J.find(text)
	if text and text ~= "" then
		if not R.text then
			expandAll()
		end
		R.text = string.lower(text)
	else
		if R.text then
			restoreStates()
		end
		R.text = nil
	end
	J.update()
end

-- ------------------------------------------------------ markers, map
local POI_PARENT = "ForeverUIQuestScrollContents"

-- WotLK numbering for the shown map: WorldMapFrame_GetQuestFrame counts completed quests
-- apart (QUEST_POI_COMPLETE_IN) and numbers the others (QUEST_POI_NUMERIC, index - completed).
local function mapPois()
	local pois = {}
	local completedCount = 0
	for i = 1, (WorldMapFrame and WorldMapFrame.numQuests or 0) do
		local f = _G["WorldMapQuestFrame" .. i]
		if f and f.questId and f.questId ~= 0 then
			if f.completed then
				completedCount = completedCount + 1
				pois[f.questId] = { QUEST_POI_COMPLETE_IN, completedCount }
			else
				pois[f.questId] = { QUEST_POI_NUMERIC, i - completedCount }
			end
		end
	end
	return pois
end

local function selectedQuest()
	return WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.selectedQuestId
end

-- Lights or clears a quest's area on the map, like the WotLK list on hover
-- (WorldMapQuestFrame_OnEnter / _OnLeave). The selected quest keeps its area.
local function zone(info, lightUp)
	if not (WorldMapBlobFrame and WorldMapBlobFrame.DrawQuestBlob and info.questID) then
		return
	end
	if info.isComplete and info.isComplete > 0 then
		return
	end
	if not lightUp and selectedQuest() == info.questID then
		return
	end
	WorldMapBlobFrame:DrawQuestBlob(info.questID, lightUp and true or false)
end

-- Map part of QuestMapFrame_ShowQuestDetails: WorldMap_OpenToQuest moves the map to the
-- quest's zone and selects the quest.
local function showOnMap(info)
	SelectQuestLogEntry(info.index)
	if info.questID and WorldMap_OpenToQuest then
		WorldMap_OpenToQuest(info.questID)
	end
	if J.onSelect then J.onSelect(info.index) end
end
J.showOnMap = showOnMap

-- ------------------------------------------------------------- actions

-- _QuestLog_ToggleQuestWatch from QuestLogFrame.lua (local to the client, so copied).
-- The list and page are then redrawn: AddQuestWatch and RemoveQuestWatch fire no event
-- the pane listens to.
local function toggleTracking(index)
	if IsQuestWatched(index) then
		RemoveQuestWatch(index)
		WatchFrame_Update()
	else
		if GetNumQuestWatches() >= MAX_WATCHABLE_QUESTS then
			UIErrorsFrame:AddMessage(format(QUEST_WATCH_TOO_MANY, MAX_WATCHABLE_QUESTS), 1.0, 0.1, 0.1, 1.0)
			return
		end
		AddQuestWatch(index)
		WatchFrame_Update()
	end
	if J.isOpen() then
		J.update()
		J.updateDetails()
	end
end
J.toggleTracking = toggleTracking

-- Abandon button of QuestLogFrame.xml
local function abandonQuest(index)
	SelectQuestLogEntry(index)
	SetAbandonQuest()
	local objects = GetAbandonQuestItems()
	if objects then
		StaticPopup_Hide("ABANDON_QUEST")
		StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", GetAbandonQuestName(), objects)
	else
		StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
		StaticPopup_Show("ABANDON_QUEST", GetAbandonQuestName())
	end
end

local function shareQuest(index)
	SelectQuestLogEntry(index)
	QuestLogPushQuest()
	PlaySound("igQuestLogOpen")
end

local function inGroup()
	return (GetNumPartyMembers and GetNumPartyMembers() > 0) or (GetNumRaidMembers and GetNumRaidMembers() > 1)
end

local function menu(anchor, list)
	if ForeverUI.WorldMap and ForeverUI.WorldMap.openMenu then
		ForeverUI.WorldMap.openMenu(anchor, list)
	end
end

-- QuestMapLogTitleButton_CreateContextMenu, without super tracking (missing in 3.3.5)
local function questMenu(row)
	local index = row.index
	local l = {}
	table.insert(l, {
		text = IsQuestWatched(index) and TEXT.untrack or TRACK_QUEST,
		func = function() toggleTracking(index) end,
	})
	local shareable = GetQuestLogPushable and GetQuestLogPushable(index) and inGroup()
	table.insert(l, {
		text = SHARE_QUEST,
		disabled = not shareable,
		func = function() shareQuest(index) end,
	})
	table.insert(l, {
		text = TEXT.shareInChat,
		func = function()
			local link = GetQuestLink(index)
			if link and not (ChatEdit_InsertLink and ChatEdit_InsertLink(link)) then
				ChatFrame_OpenChat(link)
			end
		end,
	})
	table.insert(l, {
		text = ABANDON_QUEST,
		func = function() abandonQuest(index) end,
	})
	menu(row, l)
end

-- QuestMapLogHeaderButton_CreateContextMenu: track or untrack the quests of a header
-- (SetHeaderQuestsTracked)
local function trackHeader(headerName, follow)
	local inside = false
	for i = 1, GetNumQuestLogEntries() do
		local info = entry(i)
		if info and info.isHeader then
			inside = (info.title == headerName)
		elseif info and inside then
			local isTracked = IsQuestWatched(i) and true or false
			if follow and not isTracked then
				if GetNumQuestWatches() >= MAX_WATCHABLE_QUESTS then
					UIErrorsFrame:AddMessage(format(QUEST_WATCH_TOO_MANY, MAX_WATCHABLE_QUESTS), 1.0, 0.1, 0.1, 1.0)
					break
				end
				AddQuestWatch(i)
			elseif not follow and isTracked then
				RemoveQuestWatch(i)
			end
		end
	end
	WatchFrame_Update()
	J.update()
end

-- ------------------------------------------------------------- tooltip
-- QuestMapLogTitleButton_OnEnter: title, failure, completion or objective text, then
-- objectives (white, grey when done), required money, the click hint.
local function tooltip(row)
	local info = row.info
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPLEFT", row, "TOPRIGHT", 34, 0)
	GameTooltip:SetOwner(row, "ANCHOR_PRESERVE")
	GameTooltip:SetText(info.title)
	local width = 20 + math.max(231, GameTooltipTextLeft1:GetStringWidth())
	-- Right edge of the map in UI units: WorldMapFrame has its own scale (WorldMap.lua)
	local right = WorldMapFrame:GetRight() * WorldMapFrame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	if width > UIParent:GetRight() - right then
		GameTooltip:ClearAllPoints()
		GameTooltip:SetPoint("TOPRIGHT", row, "TOPLEFT", -5, 0)
		GameTooltip:SetOwner(row, "ANCHOR_PRESERVE")
		GameTooltip:SetText(info.title)
	end
	if info.isComplete and info.isComplete < 0 then
		GameTooltip:AddLine(FAILED, 1, 0.125, 0.125)
	end
	GameTooltip:AddLine(" ")
	if info.isComplete and info.isComplete > 0 then
		GameTooltip:AddLine(GetQuestLogCompletionText(info.index) or TEXT.ready, 1, 1, 1, true)
		GameTooltip:AddLine(" ")
	else
		local selection = GetQuestLogSelection()
		SelectQuestLogEntry(info.index)
		local _, objectives = GetQuestLogQuestText()
		SelectQuestLogEntry(selection)
		GameTooltip:AddLine(objectives, 1, 1, 1, true)
		GameTooltip:AddLine(" ")
		local addSeparator = false
		for i = 1, GetNumQuestLeaderBoards(info.index) do
			local text, _, finished = GetQuestLogLeaderBoard(i, info.index)
			if text then
				local g = finished and 0.502 or 1
				GameTooltip:AddLine(QUEST_DASH .. text, g, g, g, true)
				addSeparator = true
			end
		end
		local required = GetQuestLogRequiredMoney(info.index)
		if required and required > 0 then
			local money = GetMoney()
			local g = 1
			if required <= money then
				money = required
				g = 0.502
			end
			GameTooltip:AddLine(QUEST_DASH .. GetMoneyString(money) .. " / " .. GetMoneyString(required), g, g, g)
			addSeparator = true
		end
		if addSeparator then
			GameTooltip:AddLine(" ")
		end
	end
	GameTooltip:AddLine(TEXT.details, 0.098, 1, 0.098)
	GameTooltip:Show()
end

-- ------------------------------------------------------ quest details page
--
-- camelot DetailsFrame (questmapframe.xml, QuestLogQuestDetailsMixin) and QuestInfo
-- (QUEST_TEMPLATE_MAP_DETAILS / _MAP_REWARDS). The QuestInfo frames are not reused: they
-- are unique and shared with the NPC quest frame, which reparents them on every show. The
-- page has its own, stacked like QuestInfo_Display (each TOPLEFT on the previous BOTTOMLEFT).
-- Missing in 3.3.5, so absent here: giver portrait, path buttons, campaign seal, spell
-- objectives, major faction reputation, currencies. 3.3.5 arena point rewards look like honor.
local D = {
	width = 308, height = 502, x = -22, y = -1, backgroundMax = 440,
	edgeLeft = -3, edgeH = 4, edgeRight = 3, edgeBottom = 17,
	backW = 307, backH = 52, backButtonW = 90, backButtonX = 11, backButtonY = 4,
	buttonH = 22, abandonW = 105, shareW = 103, trackW = 105, buttonsX = -3, buttonsY = -2,
	separatorX = 6,
	textW = 298, textH = 430, textX = 5, textY = -43,
	barX = 13, barTop = 17, barBottom = -27,
	content = 289,                                   -- contentWidth
	rewardW = 307, rewardY = 23, rewardLevel = 50, rewardMin = 124,
	rewardTileTop = 56, tile = 83, captionY = -22,
	-- QUEST_TEMPLATE_MAP_REWARDS and questinfo.lua
	rewardX = 12, rewardY2 = -52, rewardSpacing = 8, rewardSectionGap = 5, rewardRowGap = 2,
	rewardExtra = 62, rewardEmpty = 59, choiceW = 265,
	itemW = 134, itemH = 30, icon = 30, nameW = 92, nameH = 36,
	step = 16,
}

-- camelot text styles with their fonts (fontstyles.xml, fonts.xml): QuestTitleFont =
-- MORPHEUS 18, shadow (1, -1); QuestFont = FRIZQT 13; QuestFontNormalSmall = FRIZQT 12;
-- QuestMapRewardsFont = FRIZQT 10; QuestFont_Huge = MORPHEUS 18.
local MORPHEUS = "Fonts\\MORPHEUS.ttf"
local FONTS = {
	title = { MORPHEUS, 18 }, text = { FONT, 13 }, small = { FONT, 12 },
	reward = { FONT, 10 }, caption = { MORPHEUS, 18 },
}

local PANEL = "Interface\\Buttons\\UI-Panel-Button-"
local ICONS = {
	money = "Interface\\Icons\\INV_Misc_Coin_01",
	xp = "interface\\ForeverUI\\icons\\xp_icon",
	title = "Interface\\Icons\\INV_Misc_Note_02",
	honor = "interface\\ForeverUI\\icons\\pvpcurrency-honor-",
	arena = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon",
	outline = "Interface\\ForeverUI\\common\\whiteiconframe",
}

-- Applies a FONTS model to a font string; c: optional color
local function font(fs, model, c)
	local p = FONTS[model]
	fs:SetFont(p[1], p[2])
	if c then color(fs, c) end
end

-- camelot UIPanelButtonTemplate: three UI-Panel-Button-* pieces, where the 3.3.5 button
-- stretches a single one.
local function panelButton(parent, name, text, width)
	local b = CreateFrame("Button", name, parent)
	b:SetWidth(width)
	b:SetHeight(D.buttonH)
	local function piece(u1, u2)
		local t = b:CreateTexture(nil, "BACKGROUND")
		t:SetTexCoord(u1, u2, 0, 0.6875)
		return t
	end
	local g = piece(0, 0.09375)
	g:SetWidth(12)
	g:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	g:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	local d = piece(0.53125, 0.625)
	d:SetWidth(12)
	d:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	d:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	local m = piece(0.09375, 0.53125)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	b.pieces = { g, m, d }
	local function state(suffix)
		for _, t in ipairs(b.pieces) do
			t:SetTexture(PANEL .. suffix)
		end
	end
	state("Up")
	local fs = b:CreateFontString(nil, "ARTWORK")
	fs:SetFontObject(GameFontNormal)
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:SetFontString(fs)
	b:SetNormalFontObject(GameFontNormal)
	b:SetHighlightFontObject(GameFontHighlight)
	b:SetDisabledFontObject(GameFontDisable)
	b:SetText(text)
	b:SetHighlightTexture(PANEL .. "Highlight")
	local s = b:GetHighlightTexture()
	if s then
		s:SetTexCoord(0, 0.625, 0, 0.6875)
		s:SetBlendMode("ADD")
	end
	b.active = true
	b:SetScript("OnMouseDown", function(self)
		if self.active then state("Down") end
	end)
	b:SetScript("OnMouseUp", function(self)
		if self.active then state("Up") end
	end)
	-- UIPanelButton_OnEnable / _OnDisable
	function b:Activate(yes)
		self.active = yes and true or false
		if yes then
			self:Enable()
			state("Up")
		else
			self:Disable()
			state("Disabled")
		end
	end
	return b
end

-- SmallItemButtonTemplate (+ SmallQuestRewardItemButtonTemplate): icon 30, QuestItemBorder
-- name frame at its size, name 92 x 36, count at the icon's bottom right, quality outline.
local function createItem(parent, name)
	local b = CreateFrame("Button", name, parent)
	b:SetWidth(D.itemW)
	b:SetHeight(D.itemH)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local icon = b:CreateTexture(nil, "BACKGROUND")
	icon:SetWidth(D.icon)
	icon:SetHeight(D.icon)
	icon:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	local frame = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(frame, "questitemborder")
	frame:SetPoint("LEFT", icon, "RIGHT", 2, 0)
	local text = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	text:SetWidth(D.nameW)
	text:SetHeight(D.nameH)
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", frame, "LEFT", 4, 0)
	local count = b:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall")
	count:SetJustifyH("RIGHT")
	count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 0, 1)
	local outline = b:CreateTexture(nil, "OVERLAY")
	outline:SetTexture(ICONS.outline)
	outline:SetAllPoints(icon)
	outline:Hide()
	b.Icon, b.NameFrame, b.Name, b.Count, b.IconBorder = icon, frame, text, count, outline
	return b
end

-- SetItemButtonCount: the count shows only above 1
local function setItemCount(b, n)
	if n and n > 1 then
		b.Count:SetText(n)
		b.Count:Show()
	else
		b.Count:Hide()
	end
end

-- Log index of a quest; the 3.3.5 log only has indexes.
local function questIndex(questID)
	if not questID then return nil end
	for i = 1, GetNumQuestLogEntries() do
		local info = entry(i)
		if info and not info.isHeader and info.questID == questID then
			return i
		end
	end
	return nil
end

-- Reward buttons: tooltip and click of QuestInfoRewardItemMixin (item) and
-- QuestInfoRewardSpellCodeMixin (spell).
local function onRewardEnter(self)
	local d = J.details
	if d and d.index then SelectQuestLogEntry(d.index) end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if self.objectType == "item" then
		GameTooltip:SetQuestLogItem(self.type, self:GetID())
		if GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem(GameTooltip) end
	elseif self.objectType == "spell" then
		GameTooltip:SetQuestLogRewardSpell()
	elseif self.tooltip then
		GameTooltip:SetText(self.tooltip, 1, 1, 1)
	else
		GameTooltip:Hide()
		return
	end
	GameTooltip:Show()
end

local function onRewardClick(self)
	if not IsModifiedClick() then return end
	local d = J.details
	if d and d.index then SelectQuestLogEntry(d.index) end
	if self.objectType == "item" then
		HandleModifiedItemClick(GetQuestLogItemLink(self.type, self:GetID()))
	elseif self.objectType == "spell" and IsModifiedClick("CHATLINK") then
		ChatEdit_InsertLink(GetQuestLogSpellLink())
	end
end

local function hookReward(b)
	b:SetScript("OnEnter", onRewardEnter)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", onRewardClick)
	return b
end

-- Rewards background: header, bottom, and between them the vertical pattern in tiles of 83,
-- since SetTexCoord cannot repeat an atlas piece.
local function placeRewardsBackground(r, height)
	local e = ForeverUI.AtlasEntry("questlog-reward-tile-vertical")
	local rest = height - D.rewardTileTop
	local n = 0
	while e and rest > 0 do
		n = n + 1
		local t = r.tiles[n]
		if not t then
			t = r:CreateTexture(nil, "BACKGROUND")
			ForeverUI.SetAtlas(t, "questlog-reward-tile-vertical")
			r.tiles[n] = t
		end
		local h = math.min(D.tile, rest)
		t:SetHeight(h)
		t:SetTexCoord(e[2], e[3], e[4], e[4] + (e[5] - e[4]) * h / D.tile)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", r.top, "BOTTOMLEFT", 0, -(n - 1) * D.tile)
		t:Show()
		rest = rest - h
	end
	for i = n + 1, #r.tiles do
		r.tiles[i]:Hide()
	end
end

-- Builds the quest details page inside the pane v
local function createDetails(v)
	local d = CreateFrame("Frame", "ForeverUIQuestDetailsFrame", v)
	d:SetWidth(D.width)
	d:SetHeight(D.height)
	d:SetPoint("TOPRIGHT", v, "TOPRIGHT", D.x, D.y)
	d:EnableMouse(true)

	-- Background at the frame's width, capped at 440 (AdjustBackgroundTexture)
	local background = d:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "questdetailsbackgrounds")
	local e = ForeverUI.AtlasEntry("questdetailsbackgrounds")
	background:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
	background:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 0)
	if e then
		local wantedValue = e[7] * D.width / e[6]
		if wantedValue > D.backgroundMax then
			background:SetTexCoord(e[2], e[3], e[4], e[4] + (e[5] - e[4]) * D.backgroundMax / wantedValue)
			background:SetHeight(D.backgroundMax)
		else
			background:SetHeight(wantedValue)
		end
	end
	d.background = background

	-- Border (QuestLogBorderFrameTemplate), level 100
	local edge = CreateFrame("Frame", nil, d)
	edge:SetPoint("TOPLEFT", d, "TOPLEFT", D.edgeLeft, D.edgeH)
	edge:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", D.edgeRight, D.edgeBottom)
	edge:SetFrameLevel(d:GetFrameLevel() + 100)
	if ForeverUI.CreateNineSlice then
		ForeverUI.CreateNineSlice(edge, "questlog-frame", 53, { 0, 0, 0, 0 }, "BORDER")
	end
	local filigree = edge:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(filigree, "questlog-frame-filigree")
	filigree:SetPoint("TOP", edge, "TOP", 0, 1)
	d.edge = edge

	-- Top banner and Back button
	local banner = CreateFrame("Frame", nil, d)
	banner:SetWidth(D.backW)
	banner:SetHeight(D.backH)
	banner:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
	local image = banner:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(image, "questlog-reward-top-frame")
	image:SetPoint("TOPLEFT", banner, "TOPLEFT", 0, 0)
	local backButton = panelButton(banner, "ForeverUIQuestDetailsBackButton", BACK, D.backButtonW)
	backButton:SetPoint("LEFT", banner, "LEFT", D.backButtonX, D.backButtonY)
	backButton:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		J.backFromDetails()
	end)
	d.backButton = backButton

	-- Scrolling text
	local scroll = CreateFrame("ScrollFrame", "ForeverUIQuestDetailsScrollFrame", d)
	scroll:SetWidth(D.textW)
	scroll:SetHeight(D.textH)
	scroll:SetPoint("TOPLEFT", d, "TOPLEFT", D.textX, D.textY)
	local content = CreateFrame("Frame", "ForeverUIQuestDetailsContents", scroll)
	content:SetWidth(D.textW)
	content:SetHeight(1)
	scroll:SetScrollChild(content)
	d.scroll, d.content = scroll, content

	local function text(model, c)
		local fs = content:CreateFontString(nil, "BACKGROUND")
		font(fs, model, c)
		fs:SetJustifyH("LEFT")
		fs:SetWidth(D.content)
		return fs
	end
	d.title = text("title", COLOR.title)
	d.title:SetShadowOffset(1, -1)
	d.title:SetShadowColor(COLOR.titleShadow[1], COLOR.titleShadow[2], COLOR.titleShadow[3], 1)
	d.objectivesText = text("text", COLOR.text)
	d.timer = text("small", COLOR.text)
	d.group = text("text", COLOR.text)
	d.descriptionHeader = text("title", COLOR.title)
	d.descriptionHeader:SetShadowOffset(1, -1)
	d.descriptionHeader:SetShadowColor(COLOR.titleShadow[1], COLOR.titleShadow[2], COLOR.titleShadow[3], 1)
	d.descriptionHeader:SetText(QUEST_DESCRIPTION)
	d.description = text("text", COLOR.text)
	d.objectives = {}
	d.newObjective = function() return text("small", COLOR.text) end

	-- Required money: label and a small static money frame
	local money = CreateFrame("Frame", nil, content)
	money:SetWidth(285)
	money:SetHeight(28)
	local moneyText = money:CreateFontString(nil, "BACKGROUND")
	font(moneyText, "small")
	moneyText:SetPoint("LEFT", money, "LEFT", 0, 0)
	moneyText:SetText(REQUIRED_MONEY)
	local purse = CreateFrame("Frame", "ForeverUIQuestDetailsRequiredMoney", money, "SmallMoneyFrameTemplate")
	purse:SetPoint("LEFT", moneyText, "RIGHT", 10, 0)
	if MoneyFrame_SetType then MoneyFrame_SetType(purse, "STATIC") end
	money.text, money.purse = moneyText, purse
	d.money = money

	-- Countdown (QuestInfoTimerFrame_OnUpdate)
	local clock = CreateFrame("Frame", nil, content)
	clock:SetScript("OnUpdate", function(self, elapsed)
		if self.rest then
			self.rest = math.max(self.rest - elapsed, 0)
			d.timer:SetText(TIME_REMAINING .. " " .. SecondsToTime(self.rest))
		end
	end)
	d.clock = clock

	-- Space left for the rewards, at the bottom of the text
	local space = CreateFrame("Frame", nil, content)
	space:SetWidth(5)
	space:SetHeight(5)
	d.space = space

	local bar = ForeverUI.CreateScrollBar and ForeverUI.CreateScrollBar("ForeverUIQuestDetailsScrollBar", d, scroll)
	if bar then
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", D.barX, D.barTop)
		bar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", D.barX, D.barBottom)
		bar:SetFrameLevel(edge:GetFrameLevel() + 1)
		bar.onScroll = function(step)
			J.scrollDetails(step * D.step)
		end
		d.bar = bar
	end
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, direction)
		if d.bar and d.bar:IsShown() then
			d.bar:MoveTo(d.bar.offset - direction * 3)
		end
	end)

	-- Rewards: a still ScrollFrame that clips overflow (3.3.5 has no clipChildren; a ScrollFrame
	-- is the only frame that clips its children)
	local container = CreateFrame("ScrollFrame", "ForeverUIQuestDetailsRewardsContainer", d)
	container:SetWidth(D.rewardW)
	container:SetHeight(100)
	container:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, D.rewardY)
	container:SetFrameLevel(d:GetFrameLevel() + D.rewardLevel)
	local r = CreateFrame("Frame", "ForeverUIQuestDetailsRewardsFrame", container)
	r:SetWidth(D.rewardW)
	r:SetHeight(275)
	container:SetScrollChild(r)
	local down = r:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(down, "questlog-reward-bottom")
	down:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
	local top = r:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(top, "questlog-reward-header-top")
	top:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
	local caption = r:CreateFontString(nil, "ARTWORK")
	font(caption, "caption", COLOR.reward)
	caption:SetPoint("TOP", r, "TOP", 0, D.captionY)
	caption:SetText(TEXT.rewards)
	r.top, r.down, r.caption, r.tiles = top, down, caption, {}
	d.container, d.rewards = container, r

	-- MapQuestInfoRewardsFrame, at (12, -52)
	local list = CreateFrame("Frame", nil, r)
	list:SetWidth(285)
	list:SetHeight(10)
	list:SetPoint("TOPLEFT", r, "TOPLEFT", D.rewardX, D.rewardY2)
	local header = CreateFrame("Frame", nil, list)
	header:SetWidth(1)
	header:SetHeight(1)
	header:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
	local function rewardCaption(width)
		local fs = list:CreateFontString(nil, "BACKGROUND")
		font(fs, "reward", COLOR.reward)
		fs:SetJustifyH("LEFT")
		if width then fs:SetWidth(width) end
		return fs
	end
	list.header = header
	list.choose = rewardCaption(D.choiceW)
	list.receive = rewardCaption()
	list.playerTitle = rewardCaption()
	list.playerTitle:SetText(REWARD_TITLE)
	list.spell = rewardCaption()
	list.objects = {}
	list.xp = hookReward(createItem(list))
	list.xp.Icon:SetTexture(ICONS.xp)
	list.xp.Name:SetFontObject(NumberFontNormal)
	list.money = hookReward(createItem(list))
	list.money.Icon:SetTexture(ICONS.money)
	list.money.Name:SetFontObject(GameFontHighlight)
	list.title = hookReward(createItem(list))
	list.title.Icon:SetTexture(ICONS.title)
	list.honor = hookReward(createItem(list))
	list.arena = hookReward(createItem(list))
	list.arena.Icon:SetTexture(ICONS.arena)
	list.spellButton = hookReward(createItem(list))
	list.spellButton.objectType = "spell"
	d.list = list

	-- Abandon, Share, Track
	local abandon = panelButton(d, "ForeverUIQuestDetailsAbandonButton", ABANDON_QUEST_ABBREV, D.abandonW)
	abandon:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", D.buttonsX, D.buttonsY)
	abandon:SetScript("OnClick", function()
		if d.index then abandonQuest(d.index) end
	end)
	local share = panelButton(d, "ForeverUIQuestDetailsShareButton", SHARE_QUEST_ABBREV, D.shareW)
	share:SetPoint("LEFT", abandon, "RIGHT", 0, 0)
	for i, side in ipairs({ { "RIGHT", "LEFT", D.separatorX }, { "LEFT", "RIGHT", -D.separatorX } }) do
		local s = share:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(s, "ui-frame-btndivmiddle")
		s:SetPoint(side[1], share, side[2], side[3], 0)
		share["separator" .. i] = s
	end
	share:SetScript("OnClick", function()
		if d.index then shareQuest(d.index) end
	end)
	local follow = panelButton(d, "ForeverUIQuestDetailsTrackButton", TRACK_QUEST_ABBREV, D.trackW)
	follow:SetPoint("LEFT", share, "RIGHT", 0, 0)
	follow:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		if d.index then
			toggleTracking(d.index)
			J.updateDetailsButtons()
			J.update()
		end
	end)
	d.abandon, d.share, d.follow = abandon, share, follow

	d:Hide()
	return d
end

-- QuestMapFrame_UpdateQuestDetailsButtons, with the 3.3.5 rules
-- (QuestLogControlPanel_UpdateState)
function J.updateDetailsButtons()
	local d = J.details
	if not d or not d.index then return end
	-- QuestLog_SetSelection: the selected quest is also the one to abandon, and
	-- GetAbandonQuestName names it if abandoning is allowed
	SelectQuestLogEntry(d.index)
	SetAbandonQuest()
	d.abandon:Activate(GetAbandonQuestName() and true or false)
	if IsQuestWatched(d.index) then
		d.follow:SetText(TEXT.untrackShort)
	else
		d.follow:SetText(TRACK_QUEST_ABBREV)
	end
	d.share:Activate(GetQuestLogPushable() and inGroup() and true or false)
end

-- QuestInfo_ShowRewards for what 3.3.5 provides. Returns the list height, or nil if there is
-- no reward.
local function showRewards(d)
	local l = d.list
	for _, b in ipairs(l.objects) do b:Hide() end
	for _, f in ipairs({ l.choose, l.receive, l.playerTitle, l.spell, l.xp, l.money,
		l.title, l.honor, l.arena, l.spellButton }) do
		f:ClearAllPoints()
		f:Hide()
	end
	l.rows, l.headers = 0, 0

	local numItems = GetNumQuestLogRewards() or 0
	local numChoices = GetNumQuestLogChoices() or 0
	local money = GetQuestLogRewardMoney() or 0
	local xp = GetQuestLogRewardXP and GetQuestLogRewardXP() or 0
	local honor = GetQuestLogRewardHonor() or 0
	local arena = GetQuestLogRewardArenaPoints and GetQuestLogRewardArenaPoints() or 0
	local playerTitle = GetQuestLogRewardTitle()
	local spellIcon, spellName, spellTradeSkill, spellLearned = GetQuestLogRewardSpell()
	if numItems + numChoices == 0 and money == 0 and xp == 0 and honor == 0 and arena == 0
		and not playerTitle and not spellIcon then
		return nil
	end

	-- camelot layout: two elements per row; a section starts again on the left; a header takes
	-- a row of its own
	local total = l.header:GetHeight()
	local anchor = l.header
	local newSection, onePerRow, rightPlaced = true, false, false
	local function section(wide)
		newSection = true
		onePerRow = wide and true or false
	end
	local function add(f, h)
		if not newSection and not rightPlaced and not onePerRow then
			f:SetPoint("TOPLEFT", anchor, "TOPRIGHT", D.rewardSpacing, 0)
			rightPlaced = true
		else
			local gap = newSection and D.rewardSectionGap or D.rewardRowGap
			f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
			total = total + (h or f:GetHeight()) + gap
			anchor = f
			rightPlaced = false
			newSection = false
			l.rows = l.rows + 1
		end
		f:Show()
	end
	local function header(f)
		l.headers = l.headers + 1
		section(true)
		add(f)
	end
	local n = 0
	local function object(type, i, read)
		n = n + 1
		local b = l.objects[n]
		if not b then
			b = hookReward(createItem(l, "ForeverUIQuestDetailsRewardItem" .. n))
			l.objects[n] = b
		end
		local name, icon, count, quality, usable = read(i)
		b.type, b.objectType = type, "item"
		b:SetID(i)
		b.Name:SetText(name)
		b.Icon:SetTexture(icon)
		setItemCount(b, count)
		-- camelot BAG_ITEM_QUALITY_COLORS: common in COMMON_GRAY_COLOR, higher qualities in their
		-- color, poor without outline
		local c = quality and quality >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
		if quality == 1 then
			b.IconBorder:SetVertexColor(COLOR.commonGray[1], COLOR.commonGray[2], COLOR.commonGray[3])
			b.IconBorder:Show()
		elseif c then
			b.IconBorder:SetVertexColor(c.r, c.g, c.b)
			b.IconBorder:Show()
		else
			b.IconBorder:Hide()
		end
		if usable then
			b.Icon:SetVertexColor(1, 1, 1)
			b.NameFrame:SetVertexColor(1, 1, 1)
		else
			b.Icon:SetVertexColor(0.9, 0, 0)
			b.NameFrame:SetVertexColor(0.9, 0, 0)
		end
		add(b, D.itemH)
	end

	-- Choices
	if numChoices > 0 then
		l.choose:SetText(numChoices == 1 and REWARD_ITEMS_ONLY or REWARD_CHOICES)
		header(l.choose)
		section()
		for i = 1, numChoices do
			object("choice", i, GetQuestLogChoiceInfo)
		end
	end
	-- Spell: 3.3.5 gives only one
	if spellIcon then
		l.spell:SetText((spellTradeSkill and REWARD_TRADESKILL_SPELL) or (not spellLearned and REWARD_AURA) or REWARD_SPELL)
		header(l.spell)
		section()
		l.spellButton.Icon:SetTexture(spellIcon)
		l.spellButton.Name:SetText(spellName)
		setItemCount(l.spellButton, 0)
		add(l.spellButton, D.itemH)
	end
	-- Title
	if playerTitle then
		header(l.playerTitle)
		l.title.Name:SetText(playerTitle)
		setItemCount(l.title, 0)
		section()
		add(l.title, D.itemH)
	end
	-- Rewards received in any case
	if numItems > 0 or money > 0 or xp > 0 or honor > 0 or arena > 0 then
		l.receive:SetText((numChoices > 0 or spellIcon or playerTitle) and REWARD_ITEMS or REWARD_ITEMS_ONLY)
		header(l.receive)
		section()
		if xp > 0 then
			l.xp.Name:SetText(xp)
			setItemCount(l.xp, 0)
			add(l.xp, D.itemH)
		end
		if money > 0 then
			l.money.Name:SetText(GetMoneyString(money))
			setItemCount(l.money, 0)
			add(l.money, D.itemH)
		end
		section()
		for i = 1, numItems do
			object("reward", i, GetQuestLogRewardInfo)
		end
		if honor > 0 then
			local faction = UnitFactionGroup("player") == "Horde" and "horde" or "alliance"
			l.honor.Icon:SetTexture(ICONS.honor .. faction)
			l.honor.Name:SetText(HONOR)
			setItemCount(l.honor, honor)
			l.honor.tooltip = HONOR_POINTS
			section()
			add(l.honor, D.itemH)
		end
		if arena > 0 then
			l.arena.Name:SetText(ARENA_POINTS)
			setItemCount(l.arena, arena)
			l.arena.tooltip = ARENA_POINTS
			section()
			add(l.arena, D.itemH)
		end
	end
	l:SetHeight(total)
	return total
end

-- AdjustRewardsFrameContainer: if all the text fits, or there is only one row, the rewards
-- show in full; otherwise they grow as the text scrolls down, never below 124.
function J.adjustRewards()
	local d = J.details
	if not d then return end
	local r = d.rewards
	local height = r:GetHeight()
	local scrollRange = d.scrollRange or 0
	if scrollRange == 0 or (d.list.rows - d.list.headers) <= 1 then
		d.container:SetHeight(height)
		return
	end
	local h = height - (scrollRange - (d.scroll:GetVerticalScroll() or 0))
	if h < D.rewardMin then h = D.rewardMin end
	d.container:SetHeight(h)
end

function J.scrollDetails(y)
	local d = J.details
	if not d then return end
	d.scroll:SetVerticalScroll(math.min(y, d.scrollRange or 0))
	J.adjustRewards()
end

-- QuestInfo_Display(QUEST_TEMPLATE_MAP_DETAILS) then (..._MAP_REWARDS). Returns false if the
-- quest left the log. 3.3.5 does not measure scroll content, so the height is summed
-- element by element. start: true to scroll back to the top.
local function showDetails(start)
	local d = J.details
	local index = questIndex(d.questID)
	if not index then
		return false
	end
	d.index = index
	SelectQuestLogEntry(index)
	local info = entry(index)
	local c = d.content

	local last, total = nil, 0
	local function place(region, dx, dy, h, down)
		region:ClearAllPoints()
		if last then
			region:SetPoint("TOPLEFT", last, "BOTTOMLEFT", dx, dy)
		else
			region:SetPoint("TOPLEFT", c, "TOPLEFT", dx, dy)
		end
		region:Show()
		last = down or region
		total = total - dy + (h or region:GetHeight() or 0)
	end

	-- Title, with the failed mark
	local title = info.title
	if info.isComplete and info.isComplete < 0 then
		title = format(TEXT.titleFailed, title)
	end
	d.title:SetText(title)
	place(d.title, 5, -10)
	local description, objectives = GetQuestLogQuestText()
	d.objectivesText:SetText(objectives)
	place(d.objectivesText, 0, -5)

	-- Countdown
	local rest = GetQuestLogTimeLeft()
	d.clock.rest = rest
	if rest then
		d.timer:SetText(TIME_REMAINING .. " " .. SecondsToTime(rest))
		place(d.timer, 0, -10)
	else
		d.timer:Hide()
	end

	-- Objectives: completed ones turn grey and say "(Complete)"
	for _, o in ipairs(d.objectives) do o:Hide() end
	local seen = 0
	for i = 1, GetNumQuestLeaderBoards() do
		local text, kind, finished = GetQuestLogLeaderBoard(i)
		if kind ~= "spell" and kind ~= "log" then
			seen = seen + 1
			local o = d.objectives[seen]
			if not o then
				o = d.newObjective()
				d.objectives[seen] = o
			end
			if not text or text == "" then text = kind end
			if finished then
				color(o, COLOR.objectiveDone)
				text = text .. " (" .. COMPLETE .. ")"
			else
				color(o, COLOR.text)
			end
			o:SetText(text)
			place(o, 0, seen == 1 and -10 or -2)
		end
	end

	-- Required money: black if short, grey otherwise
	local required = GetQuestLogRequiredMoney() or 0
	if required > 0 then
		MoneyFrame_Update(d.money.purse:GetName(), required)
		if required > GetMoney() then
			color(d.money.text, { 0, 0, 0 })
			if SetMoneyFrameColor then SetMoneyFrameColor(d.money.purse:GetName(), "red") end
		else
			color(d.money.text, { 0.2, 0.2, 0.2 })
			if SetMoneyFrameColor then SetMoneyFrameColor(d.money.purse:GetName(), "white") end
		end
		place(d.money, 0, 0, 28)
	else
		d.money:Hide()
	end

	-- Suggested group
	local group = GetQuestLogGroupNum() or 0
	if group > 0 then
		d.group:SetText(format(QUEST_SUGGESTED_GROUP_NUM, group))
		place(d.group, 0, -10)
	else
		d.group:Hide()
	end

	place(d.descriptionHeader, 0, -20)
	d.description:SetText(description)
	place(d.description, 0, -5)

	-- Rewards (SetRewardsHeight): their height plus 62, or 59 when empty; the space at the
	-- bottom of the text leaves them the same room
	local list = showRewards(d)
	local height
	if list then
		d.list:Show()
		height = list + D.rewardExtra
	else
		d.list:Hide()
		height = D.rewardEmpty
	end
	d.rewards:SetHeight(height)
	placeRewardsBackground(d.rewards, height)
	if d.list.rows - d.list.headers > 0 then
		d.rewards.caption:Show()
	else
		d.rewards.caption:Hide()
	end
	d.space:SetHeight(height)
	place(d.space, 0, 0, height)

	c:SetHeight(math.max(total, 1))
	d.scrollRange = math.max(0, total - D.textH)
	if d.bar then
		local rows = math.ceil(total / D.step)
		local visibleCount = math.floor(D.textH / D.step)
		local offset = start and 0 or math.min(d.bar.offset or 0, math.max(0, rows - visibleCount))
		d.bar:Configure(rows, visibleCount, offset)
		d.scroll:SetVerticalScroll(math.min(offset * D.step, d.scrollRange))
	else
		d.scroll:SetVerticalScroll(0)
	end
	J.adjustRewards()
	J.updateDetailsButtons()
	return true
end

function J.isDetailsOpen()
	return J.details and J.details:IsShown() and true or false
end

-- QuestMapFrame_ShowQuestDetails: the map moves to the quest (keeping the one we leave),
-- the list hides, the page shows.
function J.openDetails(info)
	local d = J.details
	if not d or not info or not info.questID then
		showOnMap(info)
		return
	end
	d.returnMap = GetCurrentMapAreaID and GetCurrentMapAreaID()
	d.returnFloor = GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel()
	d.map = nil
	d.questID = info.questID
	showOnMap(info)
	d.map = GetCurrentMapAreaID and GetCurrentMapAreaID()
	StaticPopup_Hide("ABANDON_QUEST")
	StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
	-- Shown before it is filled: texts are measured only when visible
	J.pane.list:Hide()
	if J.pane.bar then J.pane.bar:Hide() end
	d:Show()
	if not showDetails(true) then
		J.closeDetails()
	end
end

-- QuestMapFrame_CloseQuestDetails
function J.closeDetails()
	local d = J.details
	if not d then return end
	d:Hide()
	d.questID, d.index, d.map, d.returnMap, d.returnFloor = nil, nil, nil, nil, nil
	d.clock.rest = nil
	J.pane.list:Show()
	StaticPopup_Hide("ABANDON_QUEST")
	StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
	J.update()
end

-- QuestMapFrame_ReturnFromQuestDetails: the map goes back where it was
function J.backFromDetails()
	local d = J.details
	if not d then return end
	local map, floor = d.returnMap, d.returnFloor
	if map and SetMapByID then
		SetMapByID(map)
		if floor and floor > 0 and SetDungeonMapLevel then
			SetDungeonMapLevel(floor)
		end
	end
	J.closeDetails()
end

-- QuestLogMixin:Refresh and QuestMapFrame_UpdateAll: the page follows the log; a quest that
-- leaves it returns to the list; a map that is no longer the quest's closes the page.
function J.updateDetails()
	local d = J.details
	if not J.isDetailsOpen() then return end
	if d.map and GetCurrentMapAreaID and GetCurrentMapAreaID() ~= d.map then
		J.closeDetails()
		return
	end
	if not showDetails(false) then
		J.backFromDetails()
	end
end

-- ------------------------------------------------------------- pane

-- Builds the quest log pane on the right of the map
local function createPane(map)
	local v = CreateFrame("Frame", "ForeverUIQuestLogPanel", map)
	v:SetFrameStrata("HIGH")
	v:EnableMouse(true)
	v:SetWidth(V.width)
	v:SetPoint("TOPRIGHT", map, "TOPRIGHT", V.x, V.top)
	v:SetPoint("BOTTOMRIGHT", map, "BOTTOMRIGHT", V.x, V.down)

	-- QuestsFrame, then QuestScrollFrame
	local list = CreateFrame("ScrollFrame", "ForeverUIQuestScrollFrame", v)
	list:SetPoint("TOPLEFT", v, "TOPLEFT", 0, V.listTop)
	list:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", V.listRight, V.listBottom)
	v.list = list

	local background = list:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "questlog-main-background-2x")
	background:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
	v.background = background

	local empty = list:CreateFontString(nil, "ARTWORK")
	empty:SetFont(FONT, 16)
	empty:SetWidth(250)
	empty:SetPoint("CENTER", list, "CENTER", 0, 50)
	empty:SetText(TEXT.empty)
	empty:Hide()
	v.empty = empty
	local none = list:CreateFontString(nil, "ARTWORK")
	none:SetFont(FONT, 14)
	none:SetWidth(250)
	none:SetPoint("TOP", list, "TOP", 0, -30)
	none:SetText(TEXT.noResults)
	none:Hide()
	v.none = none

	local content = CreateFrame("Frame", "ForeverUIQuestScrollContents", list)
	content:SetWidth(304)
	content:SetHeight(454)
	list:SetScrollChild(content)
	v.content = content

	-- Border: questlog-frame, filigree on top, shadow at the bottom
	local edge = CreateFrame("Frame", nil, list)
	edge:SetPoint("TOPLEFT", list, "TOPLEFT", -3, 7)
	edge:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", 3, -6)
	v.edge = edge
	edge:SetFrameLevel(list:GetFrameLevel() + 20)
	-- camelot nine-slices questlog-frame (UiTextureAtlasElementSliceData.db2: 53 on each side
	-- of a 107 x 107 element); stretched in one piece its mouldings are distorted.
	if ForeverUI.CreateNineSlice then
		ForeverUI.CreateNineSlice(edge, "questlog-frame", 53, { 0, 0, 0, 0 }, "BORDER")
	end
	local filigree = edge:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(filigree, "questlog-frame-filigree")
	filigree:SetPoint("TOP", edge, "TOP", 0, 1)
	local shadow = edge:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(shadow, "questlog-frame-gradient-bottom")
	shadow:SetPoint("BOTTOM", edge, "BOTTOM", 0, 4)
	v.shadow = shadow

	-- Scroll bar, in steps of 16
	local bar = ForeverUI.CreateScrollBar and ForeverUI.CreateScrollBar("ForeverUIQuestScrollBar", v, list)
	if bar then
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", list, "TOPRIGHT", V.barX, V.barTop)
		bar:SetPoint("BOTTOMLEFT", list, "BOTTOMRIGHT", V.barX, V.barBottom)
		bar:SetFrameLevel(edge:GetFrameLevel() + 1)
		bar.onScroll = function(step)
			list:SetVerticalScroll(step * V.step)
			J.updateShadow()
		end
		v.bar = bar
	end
	list:EnableMouseWheel(true)
	list:SetScript("OnMouseWheel", function(_, direction)
		if v.bar and v.bar:IsShown() then
			v.bar:MoveTo(v.bar.offset - direction * 3)
		end
	end)

	-- Search box (SearchBoxTemplate)
	local r = CreateFrame("EditBox", "ForeverUIQuestSearchBox", list)
	r:SetWidth(V.searchW)
	r:SetHeight(V.searchH)
	r:SetPoint("BOTTOMLEFT", list, "TOPLEFT", V.searchX, V.searchY)
	r:SetAutoFocus(false)
	r:SetMaxLetters(60)
	r:SetFontObject("GameFontHighlightSmall")
	r:SetTextInsets(16, 20, 0, 0)
	local function border(parent, prefix)
		local g = parent:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(g, prefix .. "-left", true)
		g:SetWidth(8) g:SetHeight(20)
		g:SetPoint("LEFT", parent, "LEFT", -5, 0)
		local d = parent:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(d, prefix .. "-right", true)
		d:SetWidth(8) d:SetHeight(20)
		d:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
		local m = parent:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(m, prefix .. "-middle", true)
		m:SetPoint("TOPLEFT", g, "TOPRIGHT")
		m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
		return g, m, d
	end
	border(r, "common-search-border")
	local magnifier = r:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(magnifier, "common-search-magnifyingglass", true)
	magnifier:SetWidth(10) magnifier:SetHeight(10)
	magnifier:SetPoint("LEFT", r, "LEFT", 1, -1)
	local instruction = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	instruction:SetPoint("TOPLEFT", r, "TOPLEFT", 16, 0)
	instruction:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -20, 0)
	instruction:SetJustifyH("LEFT")
	instruction:SetTextColor(0.35, 0.35, 0.35)
	instruction:SetText(TEXT.search)
	local clear = CreateFrame("Button", nil, r)
	clear:SetWidth(17) clear:SetHeight(17)
	clear:SetPoint("RIGHT", r, "RIGHT", -3, 0)
	local closeButton = clear:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(closeButton, "common-search-clearbutton", true)
	closeButton:SetWidth(10) closeButton:SetHeight(10)
	closeButton:SetPoint("CENTER", clear, "CENTER", 0, 0)
	closeButton:SetAlpha(0.5)
	clear:SetScript("OnEnter", function() closeButton:SetAlpha(1) end)
	clear:SetScript("OnLeave", function() closeButton:SetAlpha(0.5) end)
	clear:SetScript("OnClick", function()
		r:SetText("")
		r:ClearFocus()
	end)
	clear:Hide()
	r:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	r:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	r:SetScript("OnEditFocusGained", function() instruction:Hide() end)
	r:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" then instruction:Show() end
	end)
	r:SetScript("OnTextChanged", function(self)
		local t = self:GetText()
		if t == "" then clear:Hide() else clear:Show() instruction:Hide() end
		J.find(t)
	end)
	v.search = r

	-- Counter (InputBoxVisualTemplate)
	local counter = CreateFrame("Frame", "ForeverUIQuestLogCount", list)
	counter:SetWidth(V.counterW)
	counter:SetHeight(V.counterH)
	counter:SetPoint("TOPLEFT", r, "TOPRIGHT", V.counterX, 0)
	local _, _, right = border(counter, "common-search-border")
	local counterText = counter:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	counterText:SetPoint("TOPRIGHT", right, "TOPRIGHT", -5, -5)
	counter.text = counterText
	-- The daily quest counter (WotLK only) has no place in camelot: it lives in the counter's
	-- tooltip.
	counter:EnableMouse(true)
	counter:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText(format(QUEST_LOG_DAILY_COUNT_TEMPLATE, GetDailyQuestsCompleted(), GetMaxDailyQuests()))
		if QUEST_LOG_DAILY_TOOLTIP then
			GameTooltip:AddLine(format(QUEST_LOG_DAILY_TOOLTIP, GetMaxDailyQuests(), SecondsToTime(GetQuestResetTime(), nil, 1)), 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	counter:SetScript("OnLeave", function() GameTooltip:Hide() end)
	v.counter = counter

	-- Settings: one check box, objectives
	local setting = CreateFrame("Button", "ForeverUIQuestSettingsButton", list)
	setting:SetWidth(V.settingW)
	setting:SetHeight(V.settingH)
	setting:SetPoint("TOPRIGHT", list, "TOPRIGHT", V.settingX, V.settingY)
	local icon = setting:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(icon, "questlog-icon-setting")
	icon:SetPoint("CENTER", setting, "CENTER", 0, 0)
	local hover = setting:CreateTexture(nil, "HIGHLIGHT")
	ForeverUI.SetAtlas(hover, "questlog-icon-setting")
	hover:SetPoint("CENTER", setting, "CENTER", 0, 0)
	hover:SetBlendMode("ADD")
	hover:SetAlpha(0.4)
	setting:SetScript("OnMouseDown", function() icon:SetPoint("CENTER", setting, "CENTER", 1, -1) end)
	setting:SetScript("OnMouseUp", function() icon:SetPoint("CENTER", setting, "CENTER", 0, 0) end)
	setting:SetScript("OnClick", function(self)
		menu(self, { {
			text = TEXT.showObjectives,
			checked = settings().objectives,
			keepShownOnClick = 1,
			func = function()
				settings().objectives = not settings().objectives
				J.update()
			end,
		} })
	end)
	v.setting = setting

	v.headers, v.quests, v.objectives = {}, {}, {}
	J.details = createDetails(v)
	v:Hide()
	return v
end

-- --------------------------------------------------------------- rows

-- Header background. The modern client nine-slices common-button-list-collapseExpand
-- (18 left, 18 right, tiled center); stretched in one piece over 289 its rounded ends and
-- center grain are distorted. So the two ends keep their width and the center (28 of 64
-- texels) is tiled, the last tile clipped: 3.3.5 cannot repeat part of a sheet.
-- layer: draw layer; mode, alpha: optional blend mode and alpha
local HEADER_SLICE = { side = 18, image = 64 }
local function placeHeaderBackground(b, layer, mode, alpha)
	local e = ForeverUI.AtlasEntry("common-button-list-collapseexpand")
	if not e then return end
	local du = (e[3] - e[2]) / HEADER_SLICE.image
	local side = HEADER_SLICE.side
	local middle = HEADER_SLICE.image - 2 * side
	local function piece(u1, u2)
		local t = b:CreateTexture(nil, layer)
		t:SetTexture(e[1])
		t:SetTexCoord(u1, u2, e[4], e[5])
		if mode then t:SetBlendMode(mode) end
		if alpha then t:SetAlpha(alpha) end
		return t
	end
	local left = piece(e[2], e[2] + side * du)
	left:SetWidth(side)
	left:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	left:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	local right = piece(e[3] - side * du, e[3])
	right:SetWidth(side)
	right:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	right:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	local rest = V.headerW - 2 * side
	local x = 0
	while rest > 0 do
		local l = math.min(middle, rest)
		local u1 = e[2] + side * du
		local t = piece(u1, u1 + l * du)
		t:SetWidth(l)
		t:SetPoint("TOPLEFT", left, "TOPRIGHT", x, 0)
		t:SetPoint("BOTTOMLEFT", left, "BOTTOMRIGHT", x, 0)
		x = x + l
		rest = rest - l
	end
end

local function createHeader(v, i)
	local b = CreateFrame("Button", "ForeverUIQuestLogHeader" .. i, v.content)
	b:SetWidth(V.headerW)
	b:SetHeight(V.headerH)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	-- ListHeaderVisualTemplate NormalTexture and HighlightTexture: the background in
	-- BACKGROUND, and the same in ADD at 0.4 in the HIGHLIGHT layer, drawn only on hover
	placeHeaderBackground(b, "BACKGROUND")
	placeHeaderBackground(b, "HIGHLIGHT", "ADD", 0.4)

	local plus = CreateFrame("Button", nil, b)
	plus:SetWidth(20) plus:SetHeight(20)
	plus:SetPoint("RIGHT", b, "RIGHT", -6, 0)
	plus:EnableMouse(false)
	plus.Icon = plus:CreateTexture(nil, "ARTWORK")
	plus.Icon:SetPoint("CENTER", plus, "CENTER", 0, 0)
	b.plus = plus

	local text = b:CreateFontString(nil, "OVERLAY")
	text:SetFont(FONT, 15)
	text:SetShadowOffset(1, -1)
	text:SetShadowColor(0, 0, 0, 1)
	text:SetJustifyH("LEFT")
	text:SetPoint("LEFT", b, "LEFT", 8, 0)
	text:SetPoint("RIGHT", plus, "LEFT", -4, 0)
	b.text = text

	b:SetScript("OnEnter", function(self) color(self.text, COLOR.headerHover) end)
	b:SetScript("OnLeave", function(self) color(self.text, COLOR.headerIdle) end)
	b:SetScript("OnMouseDown", function(self)
		self.text:SetPoint("LEFT", self, "LEFT", 9, -1)
		self.plus.Icon:SetPoint("CENTER", self.plus, "CENTER", 1, -1)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.text:SetPoint("LEFT", self, "LEFT", 8, 0)
		self.plus.Icon:SetPoint("CENTER", self.plus, "CENTER", 0, 0)
	end)
	b:SetScript("OnClick", function(self, button)
		PlaySound("igMainMenuOptionCheckBoxOn")
		if button == "RightButton" then
			local name = self.info.title
			menu(self, {
				{ text = TEXT.trackAll, func = function() trackHeader(name, true) end },
				{ text = TEXT.untrackAll, func = function() trackHeader(name, false) end },
			})
		elseif self.info.isCollapsed then
			ExpandQuestHeader(self.info.index)
		else
			CollapseQuestHeader(self.info.index)
		end
	end)
	return b
end

local function createQuest(v, i)
	local b = CreateFrame("Button", "ForeverUIQuestLogTitle" .. i, v.content)
	b:SetWidth(V.questW)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	-- Track check box, 14 x 14, hit insets -10
	local checkbox = CreateFrame("Button", nil, b)
	checkbox:SetWidth(V.checkboxSide) checkbox:SetHeight(V.checkboxSide)
	checkbox:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, V.checkboxY)
	checkbox:SetHitRectInsets(-10, -10, -10, -10)
	local square = checkbox:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(square, "questlog-icon-ticksquare")
	square:SetPoint("CENTER", checkbox, "CENTER", 0, 0)
	local checkMark = checkbox:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(checkMark, "questlog-icon-checkmark-yellow")
	checkMark:SetPoint("CENTER", checkbox, "CENTER", 1, 1)
	local checkboxHover = checkbox:CreateTexture(nil, "HIGHLIGHT")
	ForeverUI.SetAtlas(checkboxHover, "questlog-icon-ticksquare")
	checkboxHover:SetPoint("CENTER", checkbox, "CENTER", 0, 0)
	checkboxHover:SetBlendMode("ADD")
	checkboxHover:SetAlpha(0.4)
	checkbox:SetScript("OnClick", function()
		PlaySound(IsQuestWatched(b.index) and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOn")
		toggleTracking(b.index)
	end)
	b.checkbox, b.checkMark = checkbox, checkMark

	-- Highlight, under the text (BORDER layer)
	local glow = b:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(glow, "questlog-quest-glow-yellow")
	glow:Hide()
	b.glow = glow

	local text = b:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
	text:SetPoint("TOPLEFT", b, "TOPLEFT", V.questTextX, V.questTextY)
	text:SetJustifyH("LEFT")
	b.text = text
	local tag = b:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
	tag:SetPoint("RIGHT", checkbox, "LEFT", -4, 0)
	tag:SetPoint("TOP", text, "TOP", 0, 0)
	tag:Hide()
	b.tag = tag
	glow:SetPoint("TOP", text, "TOP", 0, 4)
	glow:SetPoint("BOTTOM", text, "BOTTOM", 0, -4)

	b:SetScript("OnEnter", function(self)
		local c = COLOR.difficultyHover[self.difficulty]
		color(self.text, c)
		color(self.tag, c)
		for _, o in ipairs(self.objectiveRows) do
			color(o.text, COLOR.objectiveHover)
			color(o.dash, COLOR.objectiveHover)
		end
		self.glow:Show()
		zone(self.info, true)
		tooltip(self)
	end)
	b:SetScript("OnLeave", function(self)
		local c = COLOR.difficulty[self.difficulty]
		color(self.text, c)
		color(self.tag, c)
		for _, o in ipairs(self.objectiveRows) do
			color(o.text, COLOR.objective)
			color(o.dash, COLOR.objective)
		end
		self.glow:Hide()
		zone(self.info, false)
		GameTooltip:Hide()
	end)
	b:SetScript("OnMouseDown", function(self)
		self.text:SetPoint("TOPLEFT", self, "TOPLEFT", V.questTextX + 1, V.questTextY - 1)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.text:SetPoint("TOPLEFT", self, "TOPLEFT", V.questTextX, V.questTextY)
	end)
	b:SetScript("OnClick", function(self, button)
		if IsModifiedClick("CHATLINK") and ChatEdit_InsertLink and ChatEdit_InsertLink(GetQuestLink(self.index)) then
			return
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
		if IsShiftKeyDown() then
			toggleTracking(self.index)
		elseif button == "RightButton" then
			questMenu(self)
		else
			J.openDetails(self.info)
		end
	end)
	b.objectiveRows = {}
	return b
end

local function createObjective(v, i)
	local o = CreateFrame("Frame", nil, v.content)
	o:SetWidth(V.objectiveW)
	local dash = o:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	dash:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 0)
	dash:SetHeight(16)
	dash:SetText(QUEST_DASH)
	local text = o:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	text:SetWidth(V.objectiveTextW)
	text:SetJustifyH("LEFT")
	text:SetJustifyV("TOP")
	text:SetPoint("TOPLEFT", dash, "TOPRIGHT", 0, 0)
	o.dash, o.text = dash, text
	return o
end

-- Reuses or creates the n-th frame of a pool; factory(v, n) creates it
local function acquire(v, list, n, factory)
	local f = list[n]
	if not f then
		f = factory(v, n)
		list[n] = f
	end
	f:ClearAllPoints()
	f:Show()
	return f
end

-- QuestLogQuests_AddQuestButton for 3.3.5; count: running counters and map markers
local function fillQuest(v, b, info, count)
	b.info, b.index = info, info.index
	b.difficulty = difficultyKey(info.level)
	local c = COLOR.difficulty[b.difficulty]
	b.text:SetText(questTitle(info))
	color(b.text, c)
	color(b.tag, c)
	if isElite(info) then
		b.tag:SetText(format(PARENS_TEMPLATE, ELITE))
		b.tag:Show()
		b.text:SetPoint("RIGHT", b.tag, "LEFT", -4, 0)
	else
		b.tag:Hide()
		b.text:SetPoint("RIGHT", b.checkbox, "LEFT", -4, 0)
	end
	if IsQuestWatched(info.index) then b.checkMark:Show() else b.checkMark:Hide() end
	b.glow:Hide()

	local height = 8 + b.text:GetHeight()
	for _, o in ipairs(b.objectiveRows) do o:Hide() end
	b.objectiveRows = {}
	local function objective(text, previous)
		count.o = count.o + 1
		local o = acquire(v, v.objectives, count.o, createObjective)
		o.text:SetText(text)
		color(o.text, COLOR.objective)
		color(o.dash, COLOR.objective)
		local h = o.text:GetHeight()
		o:SetHeight(h)
		if previous then
			o:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -2)
			h = h + 2
		else
			o:SetPoint("TOPLEFT", b.text, "BOTTOMLEFT", 0, -3)
			h = h + 3
		end
		table.insert(b.objectiveRows, o)
		height = height + h
		return o
	end

	if not settings().objectives then
		height = height + 4
	elseif info.isComplete and info.isComplete > 0 then
		objective(GetQuestLogCompletionText(info.index) or TEXT.ready)
	else
		local previous
		for i = 1, GetNumQuestLeaderBoards(info.index) do
			local text, _, finished = GetQuestLogLeaderBoard(i, info.index)
			if text and not finished then
				previous = objective(text, previous)
			end
		end
		local required = GetQuestLogRequiredMoney(info.index)
		local money = GetMoney()
		if required and required > money then
			objective(GetMoneyString(money) .. " / " .. GetMoneyString(required), previous)
		end
	end
	-- Marker: the shown map's one, if any. camelot POIButton is 20 x 20 at (6, -4); the WotLK
	-- one is 32 x 32, so it is centered at the same place.
	local r = count.pois and info.questID and count.pois[info.questID]
	if r and QuestPOI_DisplayButton then
		local poi = QuestPOI_DisplayButton(POI_PARENT, r[1], r[2], info.questID)
		poi:ClearAllPoints()
		poi:SetPoint("CENTER", b, "TOPLEFT", 6 + 10, -4 - 10)
		poi:SetFrameLevel(b:GetFrameLevel() + 2)
		poi.info = info
		poi:SetScript("OnClick", function(self)
			PlaySound("igMainMenuOptionCheckBoxOn")
			showOnMap(self.info)
		end)
		if selectedQuest() == info.questID and QuestPOI_SelectButton then
			QuestPOI_SelectButton(poi)
		end
	end
	-- Room for the quest marker (+6 in the source)
	height = height + 6
	b:SetHeight(height)
end

-- QuestLogQuests_Update: everything is rebuilt on each pass.
function J.update()
	local v = J.pane
	if not v or not v:IsShown() then
		return
	end
	for _, f in ipairs(v.headers) do f:Hide() end
	for _, f in ipairs(v.quests) do f:Hide() end
	for _, f in ipairs(v.objectives) do f:Hide() end

	local count = { e = 0, q = 0, o = 0, pois = mapPois() }
	if QuestPOI_HideAllButtons then
		QuestPOI_HideAllButtons(POI_PARENT)
	end
	local top = 0
	local previous = nil          -- "header", "quest" or nil
	local currentHeader = nil
	local queued = nil          -- a header waiting for its first quest

	local function place(f, type, left)
		local gap
		if type == "header" then
			gap = (previous == nil and GAP.headerAfterNone)
				or (previous == "header" and GAP.headerAfterHeader)
				or GAP.headerAfterQuest
		else
			gap = (previous == "header" and GAP.questAfterHeader) or GAP.questAfterQuest
		end
		top = top + gap
		f:SetPoint("TOPLEFT", v.content, "TOPLEFT", left, -top)
		top = top + f:GetHeight()
		previous = type
	end

	local function placeHeader(info)
		count.e = count.e + 1
		local e = acquire(v, v.headers, count.e, createHeader)
		e.info = info
		e.text:SetText(info.title)
		color(e.text, COLOR.headerIdle)
		ForeverUI.SetAtlas(e.plus.Icon, info.isCollapsed and "common-button-list-plus" or "common-button-list-minus")
		place(e, "header", V.headerX)
	end

	local questCount = 0
	for i = 1, GetNumQuestLogEntries() do
		local info = entry(i)
		if info and info.isHeader then
			currentHeader = info
			-- A collapsed header hides its quests: show it as is. Expanded, it waits for a quest to
			-- show (QuestLogQuests_ShouldShowHeaderButton)
			if info.isCollapsed and not R.text then
				placeHeader(info)
				queued = nil
			else
				queued = info
			end
		elseif info then
			questCount = questCount + 1
			if linkMatches(info) then
				if queued then
					placeHeader(queued)
					queued = nil
				end
				count.q = count.q + 1
				local b = acquire(v, v.quests, count.q, createQuest)
				fillQuest(v, b, info, count)
				place(b, "quest", 0)
			end
		end
	end

	v.content:SetHeight(math.max(top, 1))

	-- Background: empty or normal, clipped to the frame height
	local isEmpty = (count.q == 0 and count.e == 0)
	-- Double-density variant: the 1x one is upscaled and pixelated on high-resolution screens.
	local atlas = (isEmpty and not R.text) and "questlog-empty-quest-background-2x" or "questlog-main-background-2x"
	ForeverUI.SetAtlas(v.background, atlas)
	local e = ForeverUI.AtlasEntry(atlas)
	local hFrame = v.list:GetHeight() or 0
	if e and hFrame > 0 and hFrame < e[7] then
		v.background:SetHeight(hFrame)
		v.background:SetTexCoord(e[2], e[3], e[4], e[4] + (e[5] - e[4]) * hFrame / e[7])
	end
	if isEmpty and not R.text then v.empty:Show() else v.empty:Hide() end
	if isEmpty and R.text then v.none:Show() else v.none:Hide() end
	if isEmpty and not R.text then
		v.search:EnableMouse(false)
	else
		v.search:EnableMouse(true)
	end

	-- camelot counter, with the WotLK maximum
	local _, quests = GetNumQuestLogEntries()
	quests = quests or questCount
	local red = quests > MAX_QUESTLOG_QUESTS
	v.counter.text:SetText(format(TEXT.counter, red and RED_FONT_COLOR_CODE or "|cffffffff", quests, MAX_QUESTLOG_QUESTS))

	-- Scroll bar
	if v.bar then
		local total = math.ceil(top / V.step)
		local visibleCount = math.floor(hFrame / V.step)
		local offset = math.min(v.bar.offset or 0, math.max(0, total - visibleCount))
		v.bar:Configure(total, visibleCount, offset)
		v.list:SetVerticalScroll(offset * V.step)
	end
	-- Border and background follow the bar: with the bar hidden they extend over its 22 pixels
	-- to the pane edge (the border's right edge then overflows by 3, mirroring its left edge);
	-- with the bar shown they keep camelot's size.
	local position = (v.bar and v.bar:IsShown()) and 0 or -V.listRight
	v.edge:ClearAllPoints()
	v.edge:SetPoint("TOPLEFT", v.list, "TOPLEFT", -3, 7)
	v.edge:SetPoint("BOTTOMRIGHT", v.list, "BOTTOMRIGHT", 3 + position, -6)
	if e then
		v.background:SetWidth(e[6] + position)
	end
	J.updateShadow()
	-- A details page is open: the list stays hidden, and its bar too
	if J.isDetailsOpen() and v.bar then
		v.bar:Hide()
	end
end

-- The bottom shadow fades as the end nears
function J.updateShadow()
	local v = J.pane
	if not v then return end
	local scrollRange = math.max(0, v.content:GetHeight() - (v.list:GetHeight() or 0))
	local scroll = v.list:GetVerticalScroll() or 0
	local h = v.shadow:GetHeight() or 1
	local alpha = (scrollRange - scroll) / (h > 0 and h or 1)
	if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
	v.shadow:SetAlpha(alpha)
end

-- ------------------------------------------------------ show, hide

function J.isOpen()
	return J.pane and J.pane:IsShown()
end

-- Called by WorldMap.lua when it places the small window: the pane follows the saved state
-- (questLogOpen).
function J.place()
	local v = J.pane
	if not v then return end
	-- Child of WorldMapFrame, which has the map's scale: the inverse brings it back to UI units
	v:SetScale(ForeverUI.WorldMap and ForeverUI.WorldMap.inverse or 1)
	if settings().pane then v:Show() else v:Hide() end
	J.update()
end

function J.hide()
	if J.pane then J.pane:Hide() end
end

-- HandleUserActionToggleSidePanel
function J.togglePane()
	settings().pane = not settings().pane
	if ForeverUI.WorldMap and ForeverUI.WorldMap.layoutWindowed then
		ForeverUI.WorldMap.layoutWindowed()
	end
end

-- L key: HandleUserActionToggleQuestLog. Map open with the pane: close it; otherwise open
-- it as a small window with the pane. WotLK keeps its size mode between openings; from full
-- screen, its own function switches back to the small window.
function J.toggleQuestLog()
	if WorldMapFrame:IsShown() and J.isOpen() then
		HideUIPanel(WorldMapFrame)
		return
	end
	-- Showing QuestLogFrame may have closed the map first: in movable mode the map is a
	-- "center" panel that gives way (UIParent.lua:1355). Closed in this same frame with its
	-- pane means L meant to close it.
	if J.mapClosed and J.closedWithPane then
		J.mapClosed = nil
		return
	end
	settings().pane = true
	if WORLDMAP_SETTINGS.size ~= WORLDMAP_WINDOWED_SIZE then
		if WorldMapFrame:IsShown() then
			WorldMapFrame_ToggleWindowSize()
			return
		end
		WorldMap_ToggleSizeDown()
	end
	if WorldMapFrame:IsShown() then
		if ForeverUI.WorldMap and ForeverUI.WorldMap.layoutWindowed then
			ForeverUI.WorldMap.layoutWindowed()
		end
	else
		ShowUIPanel(WorldMapFrame)
	end
end

-- QuestMapFrame_OpenToQuestDetails, called by the quest tracker: map as a small window,
-- pane open, then the quest page.
function J.openPage(index)
	local info = entry(index)
	if not info or info.isHeader then
		return
	end
	settings().pane = true
	if WORLDMAP_SETTINGS.size ~= WORLDMAP_WINDOWED_SIZE then
		if WorldMapFrame:IsShown() then
			WorldMapFrame_ToggleWindowSize()
		else
			WorldMap_ToggleSizeDown()
		end
	end
	if WorldMapFrame:IsShown() then
		if ForeverUI.WorldMap and ForeverUI.WorldMap.layoutWindowed then
			ForeverUI.WorldMap.layoutWindowed()
		end
	else
		ShowUIPanel(WorldMapFrame)
	end
	J.openDetails(info)
end

-- -------------------------------------------------------------- setup

local function build()
	if J.pane or not WorldMapFrame then
		return J.pane
	end
	J.pane = createPane(WorldMapFrame)
	return J.pane
end
J.build = build

-- QuestLogFrame stays in place, invisible: its functions and OnShow work for addons, but
-- showing it opens the pane. The hook runs after ShowUIPanel and hides it in the same
-- frame, so it is never drawn.
-- The hook's flag lasts until the next frame. Not GetTime(): time advances during a frame
-- (opening the map stalls it almost a second), and the fallback below would then toggle the
-- log again and close the map just opened.
local flagClearer = CreateFrame("Frame")
flagClearer:Hide()
flagClearer:SetScript("OnUpdate", function(self)
	J.handled, J.mapClosed = nil, nil
	self:Hide()
end)
J.flagClearer = flagClearer

if hooksecurefunc then
	hooksecurefunc("ShowUIPanel", function(frame)
		if frame and frame == QuestLogFrame and QuestLogFrame:IsShown() then
			J.handled = true
			flagClearer:Show()
			HideUIPanel(QuestLogFrame)
			J.toggleQuestLog()
		end
	end)
	-- Showing QuestLogFrame can fail silently: with the map maximized (a "full" panel), the
	-- panel manager refuses any other panel (FramePositionDelegate:ShowUIPanel,
	-- UIParent.lua:1341) and the hook above is not called. ToggleFrame(QuestLogFrame) is the
	-- only path of the micro button and L: if it did not reach the hook (no flag), take over.
	hooksecurefunc("ToggleFrame", function(frame)
		if frame and frame == QuestLogFrame then
			if J.handled then
				J.handled = nil
			elseif not QuestLogFrame:IsShown() then
				J.toggleQuestLog()
			end
		end
	end)
end

-- On entering the world camelot expands the current zone and collapses the others
-- (QuestMapFrame_ResetFilters). 3.3.5 does not say which header is "on the map": it is the
-- one named after the zone.
local function collapseByZone()
	local zone = GetRealZoneText and GetRealZoneText()
	if not zone or zone == "" then
		return
	end
	for i = GetNumQuestLogEntries(), 1, -1 do
		local info = entry(i)
		if info and info.isHeader then
			if info.title == zone then
				if info.isCollapsed then ExpandQuestHeader(i) end
			elseif not info.isCollapsed then
				CollapseQuestHeader(i)
			end
		end
	end
end
J.collapseByZone = collapseByZone

-- WotLK rebuilds its markers on each map or quest change: the list takes their numbers.
if hooksecurefunc and WorldMapFrame_UpdateQuests then
	hooksecurefunc("WorldMapFrame_UpdateQuests", function()
		if J.isOpen() then
			J.update()
			J.updateDetails()
		end
	end)
end

if WorldMapFrame and WorldMapFrame.HookScript then
	WorldMapFrame:HookScript("OnHide", function()
		-- A flag cleared on the next frame (not GetTime: see above)
		J.mapClosed = true
		J.closedWithPane = J.isOpen() and true or false
		J.flagClearer:Show()
	end)
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("QUEST_LOG_UPDATE")
listener:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
listener:RegisterEvent("PARTY_MEMBERS_CHANGED")
listener:RegisterEvent("QUEST_WATCH_UPDATE")
listener:RegisterEvent("PLAYER_ENTERING_WORLD")
listener:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_ENTERING_WORLD" then
		if not J.alreadyCollapsed then
			J.alreadyCollapsed = true
			collapseByZone()
		end
	end
	if J.isOpen() then
		J.update()
		J.updateDetails()
	end
end)

build()

ForeverUI.QuestLogDebug = function()
	local v = J.pane
	local prefix = "|cff66ccffForeverUI|r "
	if not v then
		DEFAULT_CHAT_FRAME:AddMessage(prefix .. L.QUESTLOG_DEBUG_NOT_BUILT)
		return
	end
	local headers, quests = 0, 0
	for _, f in ipairs(v.headers) do if f:IsShown() then headers = headers + 1 end end
	for _, f in ipairs(v.quests) do if f:IsShown() then quests = quests + 1 end end
	DEFAULT_CHAT_FRAME:AddMessage(prefix .. string.format(
		L.QUESTLOG_DEBUG_STATE,
		v:IsShown() and L.QUESTLOG_DEBUG_OPEN or L.QUESTLOG_DEBUG_CLOSED, v:GetWidth(), v:GetHeight(), headers, quests,
		tostring(R.text), tostring(settings().objectives)))
end
