-- ForeverUI: Raid page of the Social window (client tab 5), after RaidFrame and Blizzard_RaidUI.
-- Outside a raid: description, raid browser and convert buttons. In a raid: eight groups, class
-- row (at the bottom, no room on the right), ready check state and saved instances; pullout
-- frames come from the Blizzard_RaidUI functions.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local S = ForeverUI.Social
if not S or not S.registerPage then
	return
end

local R = {}
S.Raid = R

local SEP = string.char(92)
local txt = S.txt

local P = {
	frameBoxY1 = -60, frameBoxBottom = 30,
	icon = 10, iconStep = 11, call = 12,
	classSide = 18, classStep = 26, classX = 22, classBottom = 10,
	tank = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-MainTankIcon",
	mainAssist = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-MainAssistIcon",
	masterLooter = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-MasterLooter",
	classes = "Interface" .. SEP .. "Glues" .. SEP .. "CharacterCreate" .. SEP .. "UI-CharacterCreate-Classes",
	pets = "Interface" .. SEP .. "RaidFrame" .. SEP .. "UI-RaidFrame-Pets",
	mt = "Interface" .. SEP .. "RaidFrame" .. SEP .. "UI-RaidFrame-MainTank",
	ma = "Interface" .. SEP .. "RaidFrame" .. SEP .. "UI-RaidFrame-MainAssist",
	squareHighlight = "Interface" .. SEP .. "Buttons" .. SEP .. "ButtonHilight-Square",
	ready = "Interface" .. SEP .. "RaidFrame" .. SEP .. "ReadyCheck-Ready",
	notReady = "Interface" .. SEP .. "RaidFrame" .. SEP .. "ReadyCheck-NotReady",
	pending = "Interface" .. SEP .. "RaidFrame" .. SEP .. "ReadyCheck-Waiting",
	readyCheckFinish = 10,
	groupsX = 8, groupsY = -64, groupW = 180, groupGapX = 4, groupH = 66, groupGapY = 16,
	slotH = 12, tagH = 12,
	leader = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-LeaderIcon",
	assistant = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-AssistantIcon",
	highlight = "Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestTitleHighlight",
	buttonY = -34,
}

local function active(b, yes)
	if b.Activate then b:Activate(yes) elseif yes then b:Enable() else b:Disable() end
end

local function inRaid()
	return (GetNumRaidMembers() or 0) > 0
end

local function isLeaderOrOfficer()
	return (IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())
end

-- Pullout frames of Blizzard_RaidUI, loaded with the raid. filter: group number, player name
-- or class file; className: class label.
local function pullOut(filter, className)
	if not (RaidPullout_GeneratePulloutFrame and RaidPulloutButton_OnDragStart) then return false end
	local f = RaidPullout_GeneratePulloutFrame(filter, className)
	if not f then return false end
	RaidPulloutButton_OnDragStart(f)
	-- The client places it far from the cursor on wide screens: it converts the cursor with
	-- GetScreenWidthScale (width / 1024), valid for 4:3 only. Re-anchor it with the frame's
	-- effective scale, keeping the started drag.
	local x, y = GetCursorPosition()
	local e = f:GetEffectiveScale()
	if e and e > 0 then
		f:ClearAllPoints()
		f:SetPoint("TOP", UIParent, "BOTTOMLEFT", x / e, y / e)
	end
	return true
end

local function dropPullout()
	if RaidPulloutStopMoving then RaidPulloutStopMoving() end
end

-- ------------------------------------------------------------ Groups

-- Slot n of group g; its .member is the raid index. Slots are not secure buttons: secure
-- children would protect this window and FriendsFrame in combat. Left click does not target;
-- right click opens the menu, drag moves the player.
local function createSlot(parent, g, n)
	local b = CreateFrame("Button", "ForeverUIRaidSlot" .. g .. "_" .. n, parent)
	b:SetHeight(P.slotH)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b.group = g
	-- Rank, role and loot icons, placed from the left.
	b.icons = {}
	for k = 1, 3 do
		local t = b:CreateTexture(nil, "ARTWORK")
		t:SetWidth(P.icon)
		t:SetHeight(P.icon)
		t:SetPoint("LEFT", b, "LEFT", 2 + (k - 1) * P.iconStep, 0)
		t:Hide()
		b.icons[k] = t
	end
	b.rank = b.icons[1]
	b.call = b:CreateTexture(nil, "OVERLAY")
	b.call:SetWidth(P.call)
	b.call:SetHeight(P.call)
	b.call:SetPoint("RIGHT", b, "RIGHT", -2, 0)
	b.call:Hide()
	b.name = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.name:SetPoint("LEFT", b, "LEFT", 14, 0)
	b.name:SetWidth(90)
	b.name:SetJustifyH("LEFT")
	b.level = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.level:SetPoint("LEFT", b.name, "RIGHT", 2, 0)
	b.level:SetWidth(20)
	b.className = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.className:SetPoint("LEFT", b.level, "RIGHT", 2, 0)
	b.className:SetPoint("RIGHT", b, "RIGHT", -2, 0)
	b.className:SetJustifyH("LEFT")
	b:SetHighlightTexture(P.highlight)
	local s = b:GetHighlightTexture()
	if s then s:SetBlendMode("ADD") end
	b:SetScript("OnClick", function(self, button)
		if button == "RightButton" and self.member then
			-- RaidGroupButton_ShowMenu, on our menu
			local d = R.menu
			d.name = GetRaidRosterInfo(self.member)
			d.id = self.member
			d.unit = "raid" .. self.member
			ForeverUI.UnitMenu.open(ToggleDropDownMenu, 1, nil, d, "cursor")
		end
	end)
	b:SetScript("OnDragStart", function(self)
		if not self.member then return end
		-- WotLK drag: Shift (leader, officer) or always (others) pulls out the player's frame;
		-- otherwise move the player.
		if not isLeaderOrOfficer() or IsShiftKeyDown() then
			self.pulledOut = pullOut(GetRaidRosterInfo(self.member), nil)
			return
		end
		R.dragging = self
		R.ghost.text:SetText(self.name:GetText())
		R.ghost:Show()
	end)
	b:SetScript("OnDragStop", function(self)
		if self.pulledOut then
			self.pulledOut = nil
			dropPullout()
			return
		end
		R.ghost:Hide()
		local source = R.dragging
		R.dragging = nil
		if not source or not source.member then return end
		-- RaidGroupButton_OnDragStop: the slot under the cursor
		for gg = 1, 8 do
			for nn = 1, 5 do
				local target = R.slots[gg][nn]
				if target ~= source and MouseIsOver(target) then
					if target.member then
						SwapRaidSubgroup(source.member, target.member)
					else
						SetRaidSubgroup(source.member, gg)
					end
					return
				end
			end
		end
	end)
	return b
end

local function clearSlot(b)
	b.member = nil
	for _, t in ipairs(b.icons) do t:Hide() end
	b.call:Hide()
	b.name:ClearAllPoints()
	b.name:SetPoint("LEFT", b, "LEFT", 14, 0)
	b.name:SetText(txt("EMPTY"))
	b.name:SetTextColor(0.35, 0.35, 0.35)
	b.level:SetText("")
	b.className:SetText("")
end

-- RaidGroupFrame_Update, for our slots
local function updateGroups()
	local filled = {}
	for g = 1, 8 do
		filled[g] = 0
		for n = 1, 5 do clearSlot(R.slots[g][n]) end
	end
	for i = 1, (GetNumRaidMembers() or 0) do
		local name, rank, group, level, className, file, _, online, isDead = GetRaidRosterInfo(i)
		if name and group and group >= 1 and group <= 8 and filled[group] < 5 then
			filled[group] = filled[group] + 1
			local b = R.slots[group][filled[group]]
			b.member = i
			b.name:SetText(name)
			b.level:SetText(level)
			b.className:SetText(className)
			local c = file and RAID_CLASS_COLORS and RAID_CLASS_COLORS[file] or NORMAL_FONT_COLOR
			if isDead then
				b.name:SetTextColor(1, 0, 0)
			elseif not online then
				b.name:SetTextColor(0.5, 0.5, 0.5)
			else
				b.name:SetTextColor(c.r, c.g, c.b)
			end
			local gray = online and 1 or 0.5
			b.level:SetTextColor(gray, gray, gray)
			b.className:SetTextColor(gray, gray, gray)
			-- Icons: rank, role, loot, in this order, without gaps (role and master looter are the 10th
			-- and 11th values of GetRaidRosterInfo).
			local role, masterLooter = select(10, GetRaidRosterInfo(i))
			local list = {}
			if rank == 2 then list[#list + 1] = P.leader elseif rank == 1 then list[#list + 1] = P.assistant end
			if role == "MAINTANK" then list[#list + 1] = P.tank elseif role == "MAINASSIST" then list[#list + 1] = P.mainAssist end
			if masterLooter then list[#list + 1] = P.masterLooter end
			for k, t in ipairs(b.icons) do
				if list[k] then t:SetTexture(list[k]) t:Show() else t:Hide() end
			end
			b.name:ClearAllPoints()
			b.name:SetPoint("LEFT", b, "LEFT", math.max(14, 3 + #list * P.iconStep), 0)
			-- Ready check: ready, not ready, waiting (AFK once the check is over).
			local state = GetReadyCheckStatus and GetReadyCheckStatus("raid" .. i)
			if state == "ready" then
				b.call:SetTexture(READY_CHECK_READY_TEXTURE or P.ready)
				b.call:Show()
			elseif state == "notready" then
				b.call:SetTexture(READY_CHECK_NOT_READY_TEXTURE or P.notReady)
				b.call:Show()
			elseif state == "waiting" then
				b.call:SetTexture((R.callFinished and READY_CHECK_AFK_TEXTURE) or READY_CHECK_WAITING_TEXTURE or P.pending)
				b.call:Show()
			end
		end
	end
end

-- -------------------------------------------------------------- Classes

-- RAID_CLASS_BUTTONS: the ten classes in client order, then pets, main tank and main assist.
local function classes()
	local l = {}
	for _, file in ipairs(CLASS_SORT_ORDER or {}) do
		local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[file]
		l[#l + 1] = { file = file, icon = P.classes, coords = c,
			name = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[file]) or file }
	end
	l[#l + 1] = { file = "PETS", icon = P.pets, name = txt("PETS") }
	l[#l + 1] = { file = "MAINTANK", icon = P.mt, name = txt("MAINTANK") }
	l[#l + 1] = { file = "MAINASSIST", icon = P.ma, name = txt("MAINASSIST") }
	return l
end

-- Members counted by a class button: players of that class, pets, or role holders.
local function membersOf(file)
	local names = {}
	for i = 1, (GetNumRaidMembers() or 0) do
		local name, _, _, _, _, f, _, _, _, role = GetRaidRosterInfo(i)
		if file == "PETS" then
			if UnitExists and UnitExists("raidpet" .. i) then names[#names + 1] = UnitName("raidpet" .. i) end
		elseif file == "MAINTANK" or file == "MAINASSIST" then
			if role == file then names[#names + 1] = name end
		elseif f == file then
			names[#names + 1] = name
		end
	end
	return names
end

local function createClasses(parent)
	R.classes = {}
	for k, def in ipairs(classes()) do
		local b = CreateFrame("Button", "ForeverUIRaidClassButton" .. k, parent)
		b:SetWidth(P.classSide)
		b:SetHeight(P.classSide)
		b:SetPoint("BOTTOMLEFT", S.frame, "BOTTOMLEFT", P.classX + (k - 1) * P.classStep, P.classBottom)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints(b)
		b.icon:SetTexture(def.icon)
		if def.coords then b.icon:SetTexCoord(def.coords[1], def.coords[2], def.coords[3], def.coords[4]) end
		b.countText = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		b.countText:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -2)
		b:SetHighlightTexture(P.squareHighlight)
		local h = b:GetHighlightTexture()
		if h then h:SetBlendMode("ADD") end
		b:RegisterForDrag("LeftButton")
		b.def = def
		-- RaidClassButton_OnEnter
		b:SetScript("OnEnter", function(self)
			local names = membersOf(self.def.file)
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetText(string.format("%s%s (%d)|r", self.def.name, NORMAL_FONT_COLOR_CODE or "|cffffd200", #names), 1, 1, 1)
			if #names > 0 then GameTooltip:AddLine(table.concat(names, ", "), 1, 1, 1, 1) end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		b:SetScript("OnDragStart", function(self)
			if (self.count or 0) > 0 then pullOut(self.def.file, self.def.name) end
		end)
		b:SetScript("OnDragStop", dropPullout)
		R.classes[k] = b
	end
end

-- RaidClassButton_Update
local function updateClasses()
	for _, b in ipairs(R.classes) do
		local n = #membersOf(b.def.file)
		b.count = n
		if n > 0 then
			b.icon:SetDesaturated(false)
			b.icon:SetAlpha(1)
			local single = b.def.file == "MAINTANK" or b.def.file == "MAINASSIST"
			b.countText:SetText(single and "" or n)
		else
			b.icon:SetDesaturated(true)
			b.icon:SetAlpha(0.5)
			b.countText:SetText("")
		end
	end
end

-- ----------------------------------------------------------- Instances

local N = {}

local function createInstances()
	local a = S.createPopup("ForeverUIRaidInfoFrame", 345, 270)
	a.title:SetText(txt("RAID_INFORMATION"))
	N.frame = a
	local e = ForeverUI.CreateInset(a)
	e:SetPoint("TOPLEFT", a, "TOPLEFT", 12, -30)
	e:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -12, 42)
	local h1 = S.createHeader(e, "ForeverUIRaidInfoColumn1", 173, txt("INSTANCE"))
	h1:SetPoint("TOPLEFT", e, "TOPLEFT", 4, -4)
	local h2 = S.createHeader(e, "ForeverUIRaidInfoColumn2", 140, txt("LOCK_EXPIRE"))
	h2:SetPoint("LEFT", h1, "RIGHT", -1, 0)
	N.list = S.createList(e, "ForeverUIRaidInfoList", 30, function(l)
		l.name = l:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		l.name:SetPoint("TOPLEFT", l, "TOPLEFT", 5, -3)
		l.name:SetWidth(150)
		l.name:SetJustifyH("LEFT")
		l.difficulty = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		l.difficulty:SetPoint("TOPLEFT", l.name, "BOTTOMLEFT", 10, -2)
		l.reset = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		l.reset:SetPoint("TOPRIGHT", l, "TOPRIGHT", -2, -4)
		l.reset:SetJustifyH("RIGHT")
		l.extended = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		l.extended:SetPoint("TOPRIGHT", l.reset, "BOTTOMRIGHT", 0, -2)
		l.extended:SetText(txt("EXTENDED"))
		l:SetHighlightTexture(P.highlight)
		local s = l:GetHighlightTexture()
		if s then s:SetBlendMode("ADD") end
		l:SetScript("OnClick", function(self)
			N.selected = self.longID
			N.update()
		end)
		l:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.name:GetText())
			GameTooltip:AddLine(self.difficulty:GetText(), 1, 1, 1)
			GameTooltip:AddLine(string.format(txt("INSTANCE_ID"), self.instanceID or 0), 1, 1, 1)
			GameTooltip:Show()
		end)
		l:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end, function(l, i)
		local name, id, reset, _, locked, extended, idHigh, _, _, difficulty = GetSavedInstanceInfo(i)
		l.instanceID = id
		l.longID = string.format("%x%x", idHigh or 0, id or 0)
		l.difficulty:SetText(difficulty)
		if extended or locked then
			l.reset:SetText(SecondsToTime and SecondsToTime(reset or 0, true, nil, 3) or tostring(reset))
			l.name:SetText(name)
		else
			l.reset:SetText("|cff808080" .. txt("RAID_INSTANCE_EXPIRES_EXPIRED") .. "|r")
			l.name:SetText("|cff808080" .. (name or "") .. "|r")
		end
		if extended then l.extended:Show() else l.extended:Hide() end
		if N.selected == l.longID then l:LockHighlight() else l:UnlockHighlight() end
	end)
	N.list:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -2)
	N.list:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -18, 4)
	N.extend = S.button(a, txt("EXTEND_RAID_LOCK"), 200)
	N.extend:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 14, 13)
	N.extend:SetScript("OnClick", function(self)
		if N.index then
			SetSavedInstanceExtend(N.index, self.extend)
			RequestRaidInfo()
			N.update()
		end
	end)
	local close = S.button(a, txt("CLOSE"), 90)
	close:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -14, 13)
	close:SetScript("OnClick", function() a:Hide() end)
	a:HookScript("OnShow", function() N.update() end)
end

-- RaidInfoFrame_Update and RaidInfoFrame_UpdateSelectedIndex
function N.update()
	if not N.frame or not N.frame:IsShown() then return end
	local total = GetNumSavedInstances() or 0
	N.list:Update(total)
	N.index = nil
	for i = 1, total do
		local _, id, _, _, locked, extended, idHigh = GetSavedInstanceInfo(i)
		if N.selected and string.format("%x%x", idHigh or 0, id or 0) == N.selected then
			N.index = i
			if extended then
				N.extend.extend = false
				N.extend:SetText(txt("UNEXTEND_RAID_LOCK"))
			elseif locked then
				N.extend.extend = true
				N.extend:SetText(txt("EXTEND_RAID_LOCK"))
			else
				N.extend.extend = true
				N.extend:SetText(txt("REACTIVATE_RAID_LOCK"))
			end
		end
	end
	active(N.extend, N.index ~= nil)
end

-- ------------------------------------------------------------ Update

-- Secure menu overlays. Hidden out of combat only; on entering combat, the event hides them
-- before the lockdown.
function R.hideOverlays()
	if InCombatLockdown and InCombatLockdown() then return end
	for _, o in ipairs(R.overlays or {}) do o:Hide() end
end

-- Secure button k laid over a menu line. Child of UIParent: a secure child would protect the
-- window in combat.
local function overlay(k)
	R.overlays = R.overlays or {}
	local o = R.overlays[k]
	if o then return o end
	o = CreateFrame("Button", "ForeverUIRaidMenuSecure" .. k, UIParent, "SecureActionButtonTemplate")
	o:RegisterForClicks("LeftButtonUp")
	o:SetHighlightTexture(P.highlight)
	local h = o:GetHighlightTexture()
	if h then h:SetBlendMode("ADD") end
	o:SetScript("PostClick", function(self)
		if self.after then self.after() end
		CloseDropDownMenus()
	end)
	o:Hide()
	R.overlays[k] = o
	return o
end

-- Right-click menu: the client's (UnitPopup "RAID"), then secure lines for leader and
-- assistants. The client offers RAID_MAINTANK / RAID_MAINASSIST only when issecure(), never
-- true for an addon menu, and its RAID_DEMOTE calls the protected ClearPartyAssignment. So we
-- add SET_MAIN_TANK / SET_MAIN_ASSIST lines and cover them and Demote with secure overlays
-- (SecureTemplates.lua actions "maintank" / "mainassist": set, clear). Out of combat only.
function R.initMenu(self)
	local menu = UIDROPDOWNMENU_OPEN_MENU or self
	if not menu or not R.menu.name then return end
	UnitPopup_ShowMenu(menu, "RAID", R.menu.unit, R.menu.name, R.menu.id)
	R.hideOverlays()
	if (UIDROPDOWNMENU_MENU_LEVEL or 1) ~= 1 or (InCombatLockdown and InCombatLockdown()) then return end
	local leader = IsRaidLeader and IsRaidLeader()
	local officer = IsRaidOfficer and IsRaidOfficer()
	if not (leader or officer) then return end
	local list = DropDownList1
	local name, role = R.menu.name, select(10, GetRaidRosterInfo(R.menu.id))
	local unit = "raid" .. R.menu.id
	local k = 0
	local function place(button, type, action, after)
		k = k + 1
		local o = overlay(k)
		o:SetAttribute("type", type)
		o:SetAttribute("action", action)
		o:SetAttribute("unit", unit)
		o.after = after
		o:ClearAllPoints()
		o:SetAllPoints(button)
		-- Strata TOOLTIP, above FULLSCREEN_DIALOG: ToggleDropDownMenu fills the list and then shows
		-- it, and the toplevel DropDownList1 rises to the front of its strata, so a frame level set
		-- before does not hold and clicks reach the plain line.
		o:SetFrameStrata("TOOLTIP")
		o:Show()
	end
	-- Demote line of a main tank or main assist: clearing the role is protected; demoting an
	-- assistant is not.
	if role == "MAINTANK" or role == "MAINASSIST" then
		for i = 1, list.numButtons do
			local b = _G["DropDownList1Button" .. i]
			if b and b.value == "RAID_DEMOTE" then
				place(b, string.lower(role), "clear", function()
					if leader and UnitIsRaidOfficer and UnitIsRaidOfficer(unit) then DemoteAssistant(name, 1) end
				end)
			end
		end
	end
	-- Remove Cancel while adding our lines, then add it back last.
	local last = _G["DropDownList1Button" .. list.numButtons]
	local cancel = last and last.value == "CANCEL"
	if cancel then list.numButtons = list.numButtons - 1 end
	local function row(text, type)
		local info = UIDropDownMenu_CreateInfo()
		info.text = text
		info.notCheckable = 1
		info.func = function() end
		UIDropDownMenu_AddButton(info, 1)
		place(_G["DropDownList1Button" .. list.numButtons], type, "set")
	end
	if role ~= "MAINTANK" then row(txt("SET_MAIN_TANK"), "maintank") end
	if role ~= "MAINASSIST" then row(txt("SET_MAIN_ASSIST"), "mainassist") end
	if cancel then
		local info = UIDropDownMenu_CreateInfo()
		info.text = txt("CANCEL")
		info.value = "CANCEL"
		info.owner = "RAID"
		info.notCheckable = 1
		info.func = UnitPopup_OnClick
		UIDropDownMenu_AddButton(info, 1)
	end
end

function R.update()
	if not R.outside then return end
	local raid = inRaid()
	if raid then
		R.outside:Hide()
		R.groups:Show()
		updateGroups()
		updateClasses()
		R.convert:Hide()
		R.browser:Show()
		if isLeaderOrOfficer() then R.call:Show() else R.call:Hide() end
	else
		R.outside:Show()
		R.groups:Hide()
		R.convert:Show()
		R.browser:Hide()
		R.call:Hide()
		local ok = GetPartyMember and GetPartyMember(1) and IsPartyLeader() and UnitLevel("player") >= 10
			and not (HasLFGRestrictions and HasLFGRestrictions())
		active(R.convert, ok and true or false)
	end
	-- The instances button follows the saved list (UPDATE_INSTANCE_INFO).
	active(R.info, (GetNumSavedInstances() or 0) > 0)
	N.update()
end

local function build(frame)
	-- Outside a raid
	local outside = ForeverUI.CreateInset(frame, "ForeverUIRaidNotInRaid")
	outside:SetPoint("TOPLEFT", S.frame, "TOPLEFT", 4, P.frameBoxY1)
	outside:SetPoint("BOTTOMRIGHT", S.frame, "BOTTOMRIGHT", -6, P.frameBoxBottom)
	local desc = outside:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	desc:SetPoint("TOPLEFT", outside, "TOPLEFT", 18, -16)
	desc:SetWidth(335)
	desc:SetJustifyH("LEFT")
	desc:SetText(txt("RAID_DESCRIPTION"))
	local nav = outside:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	nav:SetPoint("TOP", desc, "BOTTOM", 0, -30)
	nav:SetWidth(335)
	nav:SetText(txt("RAID_BROWSER_DESCRIPTION"))
	local open = S.button(outside, txt("OPEN_RAID_BROWSER"), 260)
	open:SetPoint("TOP", nav, "BOTTOM", 0, -10)
	open:SetScript("OnClick", function()
		if LFRParentFrame then ShowUIPanel(LFRParentFrame) end
	end)
	R.outside = outside

	-- In a raid: eight groups, two columns of four
	local groups = CreateFrame("Frame", "ForeverUIRaidGroups", frame)
	groups:SetAllPoints(S.frame)
	R.groups = groups
	R.slots = {}
	for g = 1, 8 do
		local col, rowLine = (g - 1) % 2, math.floor((g - 1) / 2)
		local box = ForeverUI.CreateInset(groups, "ForeverUIRaidGroup" .. g)
		box:SetWidth(P.groupW)
		box:SetHeight(P.groupH)
		box:SetPoint("TOPLEFT", S.frame, "TOPLEFT", P.groupsX + col * (P.groupW + P.groupGapX),
			P.groupsY - P.tagH - rowLine * (P.groupH + P.groupGapY))
		-- Group label: dragging it pulls out the group frame
		local tag = CreateFrame("Button", "ForeverUIRaidGroupLabel" .. g, groups)
		tag:SetHeight(P.tagH)
		tag:SetWidth(80)
		tag:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 4, 1)
		local et = tag:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		et:SetPoint("LEFT", tag, "LEFT", 0, 0)
		et:SetText(txt("GROUP") .. " " .. g)
		tag.text = et
		tag:RegisterForDrag("LeftButton")
		tag:SetScript("OnDragStart", function() pullOut(g) end)
		tag:SetScript("OnDragStop", dropPullout)
		R.slots[g] = {}
		for n = 1, 5 do
			local b = createSlot(box, g, n)
			b:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3 - (n - 1) * P.slotH)
			b:SetPoint("TOPRIGHT", box, "TOPRIGHT", -3, -3 - (n - 1) * P.slotH)
			R.slots[g][n] = b
		end
	end
	-- Ghost that follows the cursor during a drag
	local f = CreateFrame("Frame", "ForeverUIRaidDragGhost", UIParent)
	f:SetFrameStrata("TOOLTIP")
	f:SetWidth(120)
	f:SetHeight(14)
	f.text = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	f.text:SetAllPoints(f)
	f:Hide()
	f:SetScript("OnUpdate", function(self)
		local x, y = GetCursorPosition()
		local e = UIParent:GetEffectiveScale()
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / e, y / e)
	end)
	R.ghost = f
	createClasses(groups)
	-- Right-click menu: RaidGroupButton_ShowMenu sets .initialize and .displayMode, and
	-- ToggleDropDownMenu fills it on open. Do not use UIDropDownMenu_Initialize here: it calls the
	-- function at once, with no open menu (UnitPopup_ShowMenu(nil) at login).
	R.menu = CreateFrame("Frame", "ForeverUIRaidDropDown", frame, "UIDropDownMenuTemplate")
	R.menu:Hide()
	R.menu.displayMode = "MENU"
	R.menu.initialize = R.initMenu
	-- The list closes: hide our overlays too
	if DropDownList1 then DropDownList1:HookScript("OnHide", R.hideOverlays) end

	-- Top buttons
	R.info = S.button(frame, txt("RAID_INFO"), 90)
	R.info:SetPoint("TOPRIGHT", S.frame, "TOPRIGHT", -10, P.buttonY)
	R.info:SetScript("OnClick", function()
		if N.frame:IsShown() then N.frame:Hide() else N.frame:Show() end
	end)
	R.convert = S.button(frame, txt("CONVERT_TO_RAID"), 115)
	R.convert:SetPoint("RIGHT", R.info, "LEFT", -4, 0)
	R.convert:SetScript("OnClick", function() ConvertToRaid() end)
	R.call = S.button(frame, txt("READY_CHECK"), 90)
	R.call:SetPoint("RIGHT", R.info, "LEFT", -2, 0)
	R.call:SetScript("OnClick", function()
		DoReadyCheck()
		PlaySound("UChatScrollButton")
	end)
	R.browser = S.button(frame, txt("LOOKING_FOR_RAID"), 90)
	R.browser:SetPoint("RIGHT", R.call, "LEFT", -2, 0)
	R.browser:SetScript("OnClick", function()
		if LFRParentFrame then ShowUIPanel(LFRParentFrame) end
	end)

	createInstances()
end

S.registerPage(5, {
	build = build,
	title = function() return txt("RAID") end,
	update = R.update,
	-- RaidFrame OnShow
	showRegion = function() RequestRaidInfo() end,
	hide = function()
		if N.frame then N.frame:Hide() end
		if R.ghost then R.ghost:Hide() end
	end,
})

local listener = CreateFrame("Frame")
for _, ev in ipairs({ "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PARTY_LEADER_CHANGED",
	"UPDATE_INSTANCE_INFO", "UNIT_LEVEL", "UNIT_NAME_UPDATE", "UNIT_PET", "PARTY_LFG_RESTRICTED",
	"READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED" }) do
	listener:RegisterEvent(ev)
end
-- End of the ready check: RaidGroupFrame_ReadyCheckFinished marks missing players AFK, then
-- clears the icons; here after P.readyCheckFinish seconds.
local timer = CreateFrame("Frame")
timer:Hide()
timer:SetScript("OnUpdate", function(self, elapsed)
	self.rest = (self.rest or 0) - (elapsed or 0)
	if self.rest <= 0 then
		self:Hide()
		R.callFinished = nil
		if R.slots then
			for g = 1, 8 do for n = 1, 5 do R.slots[g][n].call:Hide() end end
		end
	end
end)
R.timer = timer
listener:SetScript("OnEvent", function(self, ev)
	-- Entering combat, before the lockdown: hide the secure buttons.
	if ev == "PLAYER_REGEN_DISABLED" then
		for _, o in ipairs(R.overlays or {}) do o:Hide() end
		return
	elseif ev == "PLAYER_REGEN_ENABLED" then
		return
	end
	if ev == "READY_CHECK" then
		R.callFinished = nil
		timer:Hide()
	elseif ev == "READY_CHECK_FINISHED" then
		R.callFinished = true
		timer.rest = P.readyCheckFinish
		timer:Show()
	end
	if R.outside and R.outside:GetParent():IsVisible() then R.update() end
end)
