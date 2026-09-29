-- Battlegrounds in the right pane of the PvP tab: the list at the top, win and loss rewards
-- at the bottom, and the Join as Party / Join Battle buttons (no Cancel). Camelot has no such
-- screen, so it follows WotLK's PVPBattlegroundFrame and BattlefieldFrame (.lua/.xml),
-- styled like the arena teams (PvPArena.lua).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local L = ForeverUI.L

local B = {}
ForeverUI.PvPBattlegrounds = B

local SEP = string.char(92)
local PVP = "Interface" .. SEP .. "PVPFrame" .. SEP
local STATE_ICON = "Interface" .. SEP .. "CharacterFrame" .. SEP .. "UI-StateIcon"

-- Layout of the two boxes (list and rewards), built on Camelot's InsetFrameTemplate
local MARGIN = 12                        -- box to pane edge
local FRAME_BOX_TOP = -12
local INNER = 4                     -- rows to box edge
local MAX_ROWS = 8
local ROW_H = 20
local STATE_SIDE, STATE_X = 16, 2
local NAME_X = 22
local HOVER_ALPHA, SELECTED_ALPHA = 0.10, 0.20

local BUTTON_H, BUTTON_GAP, BUTTONS_BOTTOM = 22, 4, 14

local REWARD_H, REWARDS_GAP, REWARDS_ABOVE_BUTTONS = 36, 2, 8
-- Plate contents never truncate: columns are sized from the measured texts (GetStringWidth),
-- the same for both plates so symbols and amounts line up. If the whole overflows the plate
-- (long labels in another language, large amounts), the next smaller font is used.
local PLATE_EDGE = 8                   -- plate edge to text
local COLUMN_GAP = 8                 -- between two columns
local SYMBOL_GAP = 3                 -- symbol to its amount
local SYMBOL_SIZE = 20
local FONTS = {
	{ tag = "GameFontNormal", amount = "NumberFontNormal" },
	{ tag = "GameFontNormalSmall", amount = "NumberFontNormalSmall" },
}
-- Each reward row is Camelot's list plate (common-button-list-collapseexpand, nine-slice,
-- corner 12, as on the arena cards); the label carries the color: Win in the client's green,
-- Loss in its red (GREEN_FONT_COLOR, RED_FONT_COLOR). GREEN and RED are fallbacks.
local ATLAS_PLATE = "common-button-list-collapseexpand"
local PLATE_CORNER = 12
local GREEN = { 0.1, 1.0, 0.1 }
local RED = { 1.0, 0.1, 0.1 }

local frame, rows, rewards, join, joinAsGroup
local selected

local function faction()
	return (UnitFactionGroup and UnitFactionGroup("player")) or "Alliance"
end

-- --------------------------------------------------------------- Session

-- The instance info request goes out on the next frame: the client frames the tab hides
-- (PVPFrame, PVPBattlegroundFrame) call CloseBattlefield in their OnHide, which would close
-- our session if they hid after the request.
local deferred = CreateFrame("Frame")
deferred:Hide()
deferred:SetScript("OnUpdate", function(self)
	self:Hide()
	if frame and frame:IsVisible() and selected then
		RequestBattlegroundInstanceInfo(selected)
	end
end)

local function request()
	deferred:Show()
end
B.deferred = deferred

-- --------------------------------------------------------------- Box

-- Camelot's InsetFrameTemplate: ForeverUI.CreateInset (AtlasUtil)
local function frameBox(name)
	return ForeverUI.CreateInset(frame, name)
end

-- ------------------------------------------------------------------ List

local function createRow(n)
	local list = B.list
	local l = CreateFrame("Button", "ForeverUIBattlegroundRow" .. n, list)
	l:SetHeight(ROW_H)
	l:SetPoint("TOPLEFT", list, "TOPLEFT", INNER, -INNER - (n - 1) * ROW_H)
	l:SetPoint("TOPRIGHT", list, "TOPRIGHT", -INNER, -INNER - (n - 1) * ROW_H)
	l.hover = ForeverUI.PvPArena.createHover(l)

	local state = CreateFrame("Frame", nil, l)
	state:SetWidth(STATE_SIDE)
	state:SetHeight(STATE_SIDE)
	state:SetPoint("LEFT", l, "LEFT", STATE_X, 0)
	state:EnableMouse(true)
	state.texture = state:CreateTexture(nil, "ARTWORK")
	state.texture:SetAllPoints(state)
	state:SetScript("OnEnter", function(self)
		if self.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.tooltip)
			GameTooltip:Show()
		end
	end)
	state:SetScript("OnLeave", function() GameTooltip:Hide() end)
	state:Hide()
	l.state = state

	l.name = l:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	l.name:SetJustifyH("LEFT")
	l.name:SetPoint("LEFT", l, "LEFT", NAME_X, 0)
	l.name:SetPoint("RIGHT", l, "RIGHT", -4, 0)

	l:SetScript("OnEnter", function(self)
		if self.index ~= selected then
			self.hover:SetAlpha(HOVER_ALPHA)
		end
	end)
	l:SetScript("OnLeave", function(self)
		if self.index ~= selected then
			self.hover:SetAlpha(0)
		end
	end)
	-- PVPBattlegroundButton_OnClick. The server answers RequestBattlegroundInstanceInfo with
	-- PVPQUEUE_ANYWHERE_SHOW; GetBattlefieldInfo then gives the maximum group size.
	l:SetScript("OnClick", function(self)
		if not self.index or self.index == selected then
			return
		end
		selected = self.index
		B.update()
		RequestBattlegroundInstanceInfo(selected)
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	return l
end

-- PVPBattleground_UpdateQueueStatus
local function updateStates()
	for _, l in ipairs(rows) do
		l.state:Hide()
	end
	local maxQueues = MAX_BATTLEFIELD_QUEUES or 3
	for i = 1, maxQueues do
		local status, mapName = GetBattlefieldStatus(i)
		if status and status ~= "none" then
			for _, l in ipairs(rows) do
				if l:IsShown() and l.mapName == mapName then
					if status == "queued" then
						l.state.texture:SetTexture(PVP .. "PVP-Currency-" .. faction())
						l.state.texture:SetTexCoord(0, 1, 0, 1)
						l.state.tooltip = BATTLEFIELD_QUEUE_STATUS
						l.state:Show()
					elseif status == "confirm" then
						l.state.texture:SetTexture(STATE_ICON)
						l.state.texture:SetTexCoord(0.45, 0.95, 0.0, 0.5)
						l.state.tooltip = BATTLEFIELD_CONFIRM_STATUS
						l.state:Show()
					end
				end
			end
		end
	end
end

-- PVPBattleground_UpdateBattlegrounds
local function updateList()
	local rank = 0
	for i = 1, GetNumBattlegroundTypes() do
		local name, canEnter, holiday = GetBattlegroundInfo(i)
		if name and canEnter and rank < MAX_ROWS then
			rank = rank + 1
			local l = rows[rank]
			l.index = i
			l.mapName = name
			if not selected then
				selected = i
			end
			if holiday then
				l.name:SetText(name .. " (" .. BATTLEGROUND_HOLIDAY .. ")")
			else
				l.name:SetText(name)
			end
			l.hover:SetAlpha(i == selected and SELECTED_ALPHA or 0)
			l:Show()
		end
	end
	for n = rank + 1, MAX_ROWS do
		rows[n].index = nil
		rows[n].mapName = nil
		rows[n]:Hide()
	end
	updateStates()
end

-- ------------------------------------------------------------ Rewards

-- One reward plate. tag: label text; clientColor: name of the client color global;
-- color: fallback RGB
local function createReward(tag, clientColor, color)
	local r = CreateFrame("Frame", nil, B.rewardsFrame)
	r:SetHeight(REWARD_H)
	r.plate = ForeverUI.CreateNineSlice(r, ATLAS_PLATE, PLATE_CORNER,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	r.tag = r:CreateFontString(nil, "ARTWORK", FONTS[1].tag)
	r.tag:SetJustifyH("LEFT")
	r.tag:SetPoint("LEFT", r, "LEFT", PLATE_EDGE, 0)
	r.tag:SetText(tag)
	local c = _G[clientColor]
	if c then
		r.tag:SetTextColor(c.r, c.g, c.b)
	else
		r.tag:SetTextColor(color[1], color[2], color[3])
	end
	r.honorSymbol = r:CreateTexture(nil, "ARTWORK")
	r.honorSymbol:SetWidth(SYMBOL_SIZE)
	r.honorSymbol:SetHeight(SYMBOL_SIZE)
	r.honor = r:CreateFontString(nil, "ARTWORK", FONTS[1].amount)
	r.honor:SetJustifyH("LEFT")
	r.honor:SetPoint("LEFT", r.honorSymbol, "RIGHT", SYMBOL_GAP, 0)
	r.arenaSymbol = r:CreateTexture(nil, "ARTWORK")
	r.arenaSymbol:SetTexture(PVP .. "PVP-ArenaPoints-Icon")
	r.arenaSymbol:SetWidth(SYMBOL_SIZE)
	r.arenaSymbol:SetHeight(SYMBOL_SIZE)
	r.arena = r:CreateFontString(nil, "ARTWORK", FONTS[1].amount)
	r.arena:SetJustifyH("LEFT")
	r.arena:SetPoint("LEFT", r.arenaSymbol, "RIGHT", SYMBOL_GAP, 0)
	return r
end

-- Show an amount and its symbol, or hide both when the amount is zero
local function placeAmount(symbol, text, amount)
	if amount and amount ~= 0 then
		text:SetText(amount)
		symbol:Show()
		text:Show()
	else
		symbol:Hide()
		text:Hide()
	end
end

-- Columns of both plates, sized from what their texts measure.
local function shownWidth(fs)
	return fs:IsShown() and (fs:GetStringWidth() or 0) or 0
end

local function placeColumns()
	local plates = { rewards.win, rewards.defeat }
	local width = (frame:GetWidth() or 0) - 2 * MARGIN - 2 * INNER
	if width <= 0 then
		width = 233 - 2 * MARGIN - 2 * INNER
	end
	local tag, honor, arena, total
	for rank, font in ipairs(FONTS) do
		for _, r in ipairs(plates) do
			r.tag:SetFontObject(_G[font.tag] or font.tag)
			r.honor:SetFontObject(_G[font.amount] or font.amount)
			r.arena:SetFontObject(_G[font.amount] or font.amount)
		end
		tag, honor, arena = 0, 0, 0
		for _, r in ipairs(plates) do
			tag = math.max(tag, r.tag:GetStringWidth() or 0)
			honor = math.max(honor, shownWidth(r.honor))
			arena = math.max(arena, shownWidth(r.arena))
		end
		total = PLATE_EDGE + tag + COLUMN_GAP + SYMBOL_SIZE + SYMBOL_GAP
			+ honor + COLUMN_GAP + SYMBOL_SIZE + SYMBOL_GAP + arena + PLATE_EDGE
		B.font = rank
		if total <= width then
			break
		end
	end
	local honorX = PLATE_EDGE + tag + COLUMN_GAP
	local arenaX = honorX + SYMBOL_SIZE + SYMBOL_GAP + honor + COLUMN_GAP
	for _, r in ipairs(plates) do
		r.honorSymbol:ClearAllPoints()
		r.honorSymbol:SetPoint("LEFT", r, "LEFT", honorX, 0)
		r.arenaSymbol:ClearAllPoints()
		r.arenaSymbol:SetPoint("LEFT", r, "LEFT", arenaX, 0)
	end
	B.rewardsWidth = total
end

-- PVPQueue_UpdateRandomInfo. Only random and holiday battlegrounds have rewards; for the
-- others WotLK shows the map description, which is not shown here.
local function updateRewards()
	local _, _, holiday, random = GetBattlegroundInfo(selected or 0)
	if not (random or holiday) then
		B.rewardsFrame:Hide()
		return
	end
	local _, winHonor, winArena, lossHonor, lossArena
	if random then
		_, winHonor, winArena, lossHonor, lossArena = GetRandomBGHonorCurrencyBonuses()
	else
		_, winHonor, winArena, lossHonor, lossArena = GetHolidayBGHonorCurrencyBonuses()
	end
	local symbol = PVP .. "PVP-Currency-" .. faction()
	rewards.win.honorSymbol:SetTexture(symbol)
	rewards.defeat.honorSymbol:SetTexture(symbol)
	placeAmount(rewards.win.honorSymbol, rewards.win.honor, winHonor)
	placeAmount(rewards.win.arenaSymbol, rewards.win.arena, winArena)
	placeAmount(rewards.defeat.honorSymbol, rewards.defeat.honor, lossHonor)
	placeAmount(rewards.defeat.arenaSymbol, rewards.defeat.arena, lossArena)
	placeColumns()
	B.rewardsFrame:Show()
end

-- ---------------------------------------------------------------- Buttons

-- PVPBattleground_UpdateJoinButton and PVPBattlegroundFrame_UpdateGroupAvailable.
-- maxGroupSize is MaxGroupSize in BattlemasterList.dbc: 5 (party only) for Alterac, Isle of
-- Conquest and random; 10 or 15 (a raid can join) for the others.
local function updateButtons()
	local _, _, maxGroupSize = GetBattlefieldInfo()
	if maxGroupSize and maxGroupSize == 5 then
		joinAsGroup:SetText(JOIN_AS_PARTY)
	else
		joinAsGroup:SetText(JOIN_AS_GROUP)
	end
	if ((GetNumPartyMembers() > 0) or (GetNumRaidMembers() > 0)) and IsPartyLeader() then
		joinAsGroup:Enable()
		joinAsGroup:SetAlpha(1)
	else
		joinAsGroup:Disable()
		joinAsGroup:SetAlpha(0.5)
	end
end

function B.update()
	if not frame then
		return
	end
	updateList()
	updateRewards()
	updateButtons()
end

-- ------------------------------------------------------------ Build

-- Build the screen once. pane: the right pane of the PvP tab
function B.build(pane)
	if frame or not pane then
		return
	end
	frame = pane

	-- List box at the top of the pane, tall enough for eight rows.
	B.list = frameBox("ForeverUIBattlegroundList")
	B.list:SetPoint("TOPLEFT", frame, "TOPLEFT", MARGIN, FRAME_BOX_TOP)
	B.list:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -MARGIN, FRAME_BOX_TOP)
	B.list:SetHeight(MAX_ROWS * ROW_H + 2 * INNER)
	rows = {}
	for n = 1, MAX_ROWS do
		rows[n] = createRow(n)
	end

	local width = (pane:GetWidth() or 0)
	if width < 100 then
		width = 233
	end
	local buttonW = math.floor((width - 2 * MARGIN - BUTTON_GAP) / 2)
	joinAsGroup = ForeverUI.PvPArena.panelButton(frame,
		BATTLEFIELD_GROUP_JOIN, buttonW, BUTTON_H)
	joinAsGroup:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", MARGIN, BUTTONS_BOTTOM)
	joinAsGroup:SetScript("OnClick", function()
		if selected then
			JoinBattlefield(0, true)
		end
	end)
	join = ForeverUI.PvPArena.panelButton(frame,
		BATTLEFIELD_JOIN, buttonW, BUTTON_H)
	join:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -MARGIN, BUTTONS_BOTTOM)
	join:SetScript("OnClick", function()
		if selected then
			JoinBattlefield(0)
		end
	end)
	B.join, B.joinAsGroup = join, joinAsGroup

	-- Rewards box above the buttons: two plates.
	B.rewardsFrame = frameBox("ForeverUIBattlegroundRewards")
	B.rewardsFrame:SetPoint("BOTTOMLEFT", joinAsGroup, "TOPLEFT", 0, REWARDS_ABOVE_BUTTONS)
	B.rewardsFrame:SetPoint("BOTTOMRIGHT", join, "TOPRIGHT", 0, REWARDS_ABOVE_BUTTONS)
	B.rewardsFrame:SetHeight(2 * REWARD_H + REWARDS_GAP + 2 * INNER)
	rewards = {}
	rewards.win = createReward(WIN, "GREEN_FONT_COLOR", GREEN)
	rewards.win:SetPoint("TOPLEFT", B.rewardsFrame, "TOPLEFT", INNER, -INNER)
	rewards.win:SetPoint("TOPRIGHT", B.rewardsFrame, "TOPRIGHT", -INNER, -INNER)
	rewards.defeat = createReward(LOSS, "RED_FONT_COLOR", RED)
	rewards.defeat:SetPoint("TOPLEFT", rewards.win, "BOTTOMLEFT", 0, -REWARDS_GAP)
	rewards.defeat:SetPoint("TOPRIGHT", rewards.win, "BOTTOMRIGHT", 0, -REWARDS_GAP)
	B.rewards = rewards

	-- PVPBattlegroundFrame_OnShow / _OnHide
	frame:HookScript("OnShow", function()
		if SortBGList then
			SortBGList()
		end
		B.update()
		request()
	end)
	frame:HookScript("OnHide", function()
		deferred:Hide()
		CloseBattlefield()
	end)

	B.update()
	if frame:IsVisible() then
		request()
	end
end

-- PVPBattlegroundFrame_OnEvent
local listener = CreateFrame("Frame")
listener:RegisterEvent("PVPQUEUE_ANYWHERE_SHOW")
listener:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
listener:RegisterEvent("PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE")
listener:RegisterEvent("PARTY_MEMBERS_CHANGED")
listener:RegisterEvent("RAID_ROSTER_UPDATE")
listener:SetScript("OnEvent", function(self, event)
	if not frame then
		return
	end
	if event == "UPDATE_BATTLEFIELD_STATUS" then
		updateStates()
	elseif event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
		updateButtons()
	elseif event == "PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE" then
		-- Level brackets may have changed: rebuild the list
		selected = nil
		B.update()
		request()
	else
		B.update()
	end
end)

-- Debug: /fui bg. Prints what the client returns for the list and the queues.
function ForeverUI.PvPBattlegroundsDebug()
	local say = function(t)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t)
	end
	for i = 1, GetNumBattlegroundTypes() do
		local name, canEnter, holiday, random, id = GetBattlegroundInfo(i)
		say(string.format(L.PVPBATTLEGROUNDS_DEBUG_ROW, i,
			tostring(name), tostring(canEnter), tostring(holiday), tostring(random),
			tostring(id), (i == selected) and L.PVPBATTLEGROUNDS_DEBUG_SELECTED or ""))
	end
	local mapName, _, maxGroupSize = GetBattlefieldInfo()
	say(string.format(L.PVPBATTLEGROUNDS_DEBUG_INFO, tostring(mapName), tostring(maxGroupSize)))
	say(string.format(L.PVPBATTLEGROUNDS_DEBUG_BONUSES,
		table.concat({ tostring((select(2, GetRandomBGHonorCurrencyBonuses()))),
			tostring((select(3, GetRandomBGHonorCurrencyBonuses()))),
			tostring((select(4, GetRandomBGHonorCurrencyBonuses()))),
			tostring((select(5, GetRandomBGHonorCurrencyBonuses()))) }, "/"),
		table.concat({ tostring((select(2, GetHolidayBGHonorCurrencyBonuses()))),
			tostring((select(3, GetHolidayBGHonorCurrencyBonuses()))),
			tostring((select(4, GetHolidayBGHonorCurrencyBonuses()))),
			tostring((select(5, GetHolidayBGHonorCurrencyBonuses()))) }, "/")))
	for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
		local status, queueName = GetBattlefieldStatus(i)
		say(string.format(L.PVPBATTLEGROUNDS_DEBUG_QUEUE, i, tostring(status), tostring(queueName)))
	end
end
