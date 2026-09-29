-- ForeverUI: compact raid frames in the camelot style (CompactUnitFrame, CompactRaidGroup).
-- Eight SecureRaidGroupHeaderTemplate headers, one per group, place the players, even in combat.
-- 3.3.5 has no heal or absorb prediction, phase, summon or incoming resurrection icons, and
-- UnitAura does not flag boss debuffs, so all debuffs are 11 px.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local SEP = string.char(92)
local L = ForeverUI.L
local LFG = "Interface" .. SEP .. "ForeverUI" .. SEP .. "lfgframe" .. SEP

-- Sizes from camelot (editmodepresetlayouts: 98 x 44; component scale min(44/36, 98/72)).
-- background: estimated, the source constant is missing. Outlines are nine-sliced with
-- corners measured on the art: stretched whole, their edges thicken.
local P = {
	width = 98, height = 44, titleH = 14, groups = 8, perGroup = 5,
	x = 22, y = -145,
	resourceH = 8, auraBottom = 2, aura = 11, auraBorder = 5, dispel = 14,
	buffs = 6, debuffs = 5, dispels = 3, perRow = 3, dispelGap = 2,
	role = 17, call = 20, status = 12, readyCheckFinish = 11,
	background = { 0.1, 0.1, 0.1 },
	threatCorner = 10, targetCorner = 10, dispelCorner = 2,
	outOfRangeAlpha = 0.5, rangePeriod = 0.5,
	markers = {
		ready = LFG .. "ui-lfg-readymark-raid",
		notready = LFG .. "ui-lfg-declinemark-raid",
		waiting = LFG .. "ui-lfg-pendingmark-raid",
	},
	roles = {
		TANK = LFG .. "ui-lfg-roleicon-tank-micro-groupfinder",
		HEALER = LFG .. "ui-lfg-roleicon-healer-micro-groupfinder",
		DAMAGER = LFG .. "ui-lfg-roleicon-dps-micro-groupfinder",
	},
	borders = { Magic = "magic", Curse = "curse", Disease = "disease", Poison = "poison" },
}
P.scale = math.min(P.height / 36, P.width / 72)

local R = { buttons = {} }
ForeverUI.RaidFrame = R

-- ----------------------------------------------------------------- pieces

local function showRegion(slices, yes)
	for _, t in ipairs(slices) do
		if yes then t:Show() else t:Hide() end
	end
end

local function applyTint(slices, r, g, b)
	for _, t in ipairs(slices) do t:SetVertexColor(r, g, b) end
end

-- Crops the bar texture to fraction of isFull, the full width; hidden under half a pixel.
local function populate(tex, fraction, isFull)
	if not fraction or fraction ~= fraction or fraction < 0 then fraction = 0 end
	if fraction > 1 then fraction = 1 end
	local width = isFull * fraction
	if width < 0.5 then
		tex:Hide()
		return
	end
	tex:SetWidth(width)
	tex:SetTexCoord(tex.u1, tex.u1 + (tex.u2 - tex.u1) * fraction, tex.v1, tex.v2)
	tex:Show()
end

-- Bar texture from an atlas entry, keeping its tex coords for populate.
local function bar(parent, layer, atlas)
	local t = parent:CreateTexture(nil, layer)
	local e = ForeverUI.AtlasEntry(atlas)
	t:SetTexture(e[1])
	t.u1, t.u2, t.v1, t.v2 = e[2], e[3], e[4], e[5]
	return t
end

-- Aura icon of size side, with cooldown and stack count; border: add a debuff border.
local function createAura(parent, side, border)
	local a = CreateFrame("Frame", nil, parent)
	a:SetWidth(side)
	a:SetHeight(side)
	a:EnableMouse(false)
	a.icon = a:CreateTexture(nil, "ARTWORK")
	a.icon:SetAllPoints(a)
	if border then
		a.border = a:CreateTexture(nil, "OVERLAY")
		a.border:SetWidth(side + P.auraBorder)
		a.border:SetHeight(side + P.auraBorder)
		a.border:SetPoint("CENTER", a, "CENTER", 0, 0)
	end
	a.cooldown = CreateFrame("Cooldown", nil, a)
	a.cooldown:SetReverse(true)
	a.cooldown:SetPoint("TOPLEFT", a, "TOPLEFT", 0, -1)
	a.cooldown:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", 0, -1)
	a.stack = a:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	a.stack:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -2, 2)
	a:Hide()
	return a
end

-- 3-wide grids (AnchorUtil.CreateGridLayout): the k-th cell from corner.
-- directionX: 1 rightwards, -1 leftwards; x, y: first cell offset; side: cell size
local function placeGrid(auras, corner, directionX, x, y, side)
	for k, a in ipairs(auras) do
		local col, row = (k - 1) % P.perRow, math.floor((k - 1) / P.perRow)
		a:ClearAllPoints()
		a:SetPoint(corner, a:GetParent(), corner, x + directionX * col * side, y + row * side)
	end
end

-- -------------------------------------------------------- player frame

local function buildButton(f)
	f.background = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(f.background, "raidframe-hp-bg-white", true)
	f.background:SetAllPoints(f)
	f.background:SetVertexColor(P.background[1], P.background[2], P.background[3])

	f.health = bar(f, "BORDER", "raidframe-hp-fill")
	f.health:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.resourceBackground = bar(f, "BORDER", "_raidframe-resource-background")
	f.resource = bar(f, "ARTWORK", "_raidframe-resource-fill")

	f.threat = ForeverUI.CreateNineSlice(f, "raidframe-agroframe", P.threatCorner, { 0, 0, 0, 0 }, "ARTWORK") or {}
	showRegion(f.threat, false)

	-- dispel overlay
	local overlay = CreateFrame("Frame", nil, f)
	overlay:SetAllPoints(f)
	overlay:SetFrameLevel(f:GetFrameLevel() + 1)
	overlay.background = overlay:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(overlay.background, "raidframe-dispel-fill", true)
	overlay.background:SetAllPoints(overlay)
	overlay.background:SetAlpha(0.2)
	overlay.gradient = overlay:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(overlay.gradient, "_raidframe-dispel-highlight-horizontal", true)
	overlay.gradient:SetAllPoints(overlay)
	overlay.edge = ForeverUI.CreateNineSlice(overlay, "raidframe-dispelhighlight", P.dispelCorner, { 0, 0, 0, 0 }, "ARTWORK") or {}
	overlay:Hide()
	f.overlay = overlay

	-- text, role and auras above the bars
	local hovered = CreateFrame("Frame", nil, f)
	hovered:SetAllPoints(f)
	hovered:SetFrameLevel(f:GetFrameLevel() + 2)
	f.hovered = hovered
	f.role = hovered:CreateTexture(nil, "ARTWORK")
	f.role:SetWidth(P.role)
	f.role:SetHeight(P.role)
	f.role:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -2)
	f.name = hovered:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	f.name:SetPoint("TOPLEFT", f.role, "TOPRIGHT", 0, -1)
	f.name:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
	f.name:SetJustifyH("LEFT")
	f.name:SetHeight(12)
	f.status = hovered:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	local font, _, flags = f.status:GetFont()
	if font then f.status:SetFont(font, P.status * P.scale, flags) end
	f.status:SetHeight(P.status * P.scale)
	f.status:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 3, P.height / 3 - 2)
	f.status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, P.height / 3 - 2)

	f.buffs, f.debuffs, f.dispels = {}, {}, {}
	for k = 1, P.buffs do f.buffs[k] = createAura(hovered, P.aura) end
	for k = 1, P.debuffs do f.debuffs[k] = createAura(hovered, P.aura, true) end
	for k = 1, P.dispels do
		local t = hovered:CreateTexture(nil, "OVERLAY")
		t:SetWidth(P.dispel)
		t:SetHeight(P.dispel)
		t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3 - (k - 1) * P.dispel, -2)
		t:Hide()
		f.dispels[k] = t
	end

	-- target outline and ready check: full alpha even out of range
	local top = CreateFrame("Frame", nil, f)
	top:SetAllPoints(f)
	top:SetFrameLevel(f:GetFrameLevel() + 3)
	f.target = ForeverUI.CreateNineSlice(top, "raidframe-targetframe", P.targetCorner, { 0, 0, 0, 0 }, "OVERLAY") or {}
	showRegion(f.target, false)
	f.call = top:CreateTexture(nil, "OVERLAY")
	f.call:SetWidth(P.call * P.scale)
	f.call:SetHeight(P.call * P.scale)
	f.call:SetPoint("BOTTOM", f, "BOTTOM", 0, P.height / 3 - 4)
	f.call:Hide()

	-- What range fades. 3.3.5 has no ignoreParentAlpha, so regions fade one by one.
	f.fadedRegions = { f.background, f.health, f.resourceBackground, f.resource, f.name, f.status, f.role }
end

-- New button setup (initialConfigFunction): clicks, menu, size (initial-width / -height,
-- read by the header), art
local function configure(f)
	f:RegisterForClicks("AnyUp")
	f:SetAttribute("*type1", "target")
	f:SetAttribute("*type2", "menu")
	f:SetAttribute("toggleForVehicle", true)
	f:SetAttribute("initial-width", P.width)
	f:SetAttribute("initial-height", P.height)
	f.menu = function(self) R.openMenu(self) end
	buildButton(f)
	f:HookScript("OnAttributeChanged", function(self, name, value)
		if name == "unit" then
			self.unit = value
			R.updateButton(self)
		end
	end)
	f:HookScript("OnShow", function(self) R.updateButton(self) end)
	f:SetScript("OnEnter", function(self)
		if not self.display then return end
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetUnit(self.display)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:FadeOut() end)
	table.insert(R.buttons, f)
end

-- ------------------------------------------------------------ updates

local function fraction(v, m)
	if not m or m <= 0 then return 0 end
	return v / m
end

-- shown unit: the vehicle if any (CompactUnitFrame_UpdateUnitEvents)
local function displayedUnit(unit)
	if UnitHasVehicleUI(unit) and UnitTargetsVehicleInRaidUI(unit) then
		local v = unit:gsub("^raid(%d+)$", "raidpet%1")
		if UnitExists(v) then return v, true end
	end
	return unit, false
end

local function updateHealth(f)
	local u = f.display
	local connected = UnitIsConnected(f.unit)
	local isFull = P.width - 2
	populate(f.health, connected and fraction(UnitHealth(u), UnitHealthMax(u)) or 1, isFull)
	-- CompactUnitFrame_UpdateHealthColor
	if not connected then
		f.health:SetVertexColor(0.5, 0.5, 0.5)
	else
		local _, className = UnitClass(f.unit)
		local c = className and RAID_CLASS_COLORS[className]
		if c then f.health:SetVertexColor(c.r, c.g, c.b) else f.health:SetVertexColor(0, 1, 0) end
	end
	-- CompactUnitFrame_UpdateStatusText
	if not connected then
		f.status:SetText(PLAYER_OFFLINE)
		f.status:Show()
	elseif UnitIsDeadOrGhost(u) then
		f.status:SetText(DEAD)
		f.status:Show()
	else
		f.status:Hide()
	end
end

local function updateResource(f)
	local u = f.display
	local type, token = UnitPowerType(u)
	local c = (token and PowerBarColor[token]) or PowerBarColor[type] or PowerBarColor["MANA"]
	if not UnitIsConnected(f.unit) then
		f.resource:SetVertexColor(0.5, 0.5, 0.5)
	else
		f.resource:SetVertexColor(c.r, c.g, c.b)
	end
	populate(f.resource, fraction(UnitPower(u, type), UnitPowerMax(u, type)), P.width - 2)
end

-- vertical layout: health, then an 8 px resource bar (DefaultCompactUnitFrameSetup)
local function placeBars(f)
	f.health:SetHeight(P.height - 2 - P.resourceH)
	f.resourceBackground:ClearAllPoints()
	f.resourceBackground:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 1, 1 + P.resourceH)
	f.resourceBackground:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.resource:ClearAllPoints()
	f.resource:SetPoint("TOPLEFT", f.resourceBackground, "TOPLEFT", 0, 0)
	f.resource:SetHeight(P.resourceH)
end

-- role icon: vehicle, then MT / MA, then the group role
local function updateRole(f)
	local atlas, file
	if f.vehicle then
		atlas = "raidframe-icon-vehicle"
	else
		local id = f.unit and tonumber(f.unit:match("^raid(%d+)$"))
		local role = id and select(10, GetRaidRosterInfo(id))
		if role == "MAINTANK" then
			atlas = "raidframe-icon-maintank"
		elseif role == "MAINASSIST" then
			atlas = "raidframe-icon-mainassist"
		else
			local tank, healer, damage = UnitGroupRolesAssigned(f.unit)
			file = (tank and P.roles.TANK) or (healer and P.roles.HEALER) or (damage and P.roles.DAMAGER)
		end
	end
	if atlas then
		ForeverUI.SetAtlas(f.role, atlas, true)
	elseif file then
		f.role:SetTexture(file)
		f.role:SetTexCoord(0, 1, 0, 1)
	end
	if atlas or file then
		f.role:SetWidth(P.role)
		f.role:Show()
	else
		-- hidden, it keeps 1 px width so the name moves left
		f.role:SetWidth(1)
		f.role:Hide()
	end
end

local function updateThreat(f)
	local status = UnitThreatSituation(f.display)
	if status and status > 0 then
		applyTint(f.threat, GetThreatStatusColor(status))
		showRegion(f.threat, true)
	else
		showRegion(f.threat, false)
	end
end

local function updateTarget(f)
	showRegion(f.target, f.display and UnitIsUnit(f.display, "target"))
end

local function applyAura(a, icon, stack, duration, finish)
	a.icon:SetTexture(icon)
	if stack and stack > 1 then a.stack:SetText(stack >= 100 and "*" or stack) else a.stack:SetText("") end
	if duration and duration > 0 and finish then
		CooldownFrame_SetTimer(a.cooldown, finish - duration, duration, 1)
	else
		a.cooldown:Hide()
	end
	a:Show()
end

local function updateAuras(f)
	local u = f.display
	-- dispel: the first debuff that has a type
	local types, first = {}, nil
	for i = 1, 40 do
		local name, _, _, _, type = UnitDebuff(u, i)
		if not name then break end
		if type and P.borders[type] and not types[type] then
			types[type] = true
			types[#types + 1] = type
			first = first or type
		end
	end
	local d = first and P.dispelGap or 0
	if first then
		local c = DebuffTypeColor[first] or DebuffTypeColor["none"]
		applyTint({ f.overlay.background, f.overlay.gradient }, c.r, c.g, c.b)
		applyTint(f.overlay.edge, c.r, c.g, c.b)
		f.overlay:Show()
	else
		f.overlay:Hide()
	end
	for k, t in ipairs(f.dispels) do
		local type = types[k]
		if type and ForeverUI.SetAtlas(t, "raidframe-icon-debuff" .. P.borders[type], true) then
			t:Show()
		else
			t:Hide()
		end
	end
	-- buffs, from BOTTOMRIGHT leftwards; the PLAYER filter stands in for camelot's
	-- player-castable buffs
	placeGrid(f.buffs, "BOTTOMRIGHT", -1, -3 - d, P.auraBottom + P.resourceH + d, P.aura)
	for k, a in ipairs(f.buffs) do
		local name, _, icon, stack, _, duration, finish = UnitBuff(u, k, "PLAYER")
		if name then applyAura(a, icon, stack, duration, finish) else a:Hide() end
	end
	-- debuffs, from BOTTOMLEFT rightwards
	placeGrid(f.debuffs, "BOTTOMLEFT", 1, 3 + d, P.auraBottom + P.resourceH + d, P.aura)
	for k, a in ipairs(f.debuffs) do
		local name, _, icon, stack, type, duration, finish = UnitDebuff(u, k)
		if name then
			ForeverUI.SetAtlas(a.border, "ui-debuff-border-" .. (P.borders[type or ""] or "default") .. "-noicon", true)
			applyAura(a, icon, stack, duration, finish)
		else
			a:Hide()
		end
	end
end

local function updateReadyCheck(f, finish)
	local state = f.unit and GetReadyCheckStatus(f.unit)
	if not state then
		if not finish then f.call:Hide() end
		return
	end
	if finish and state == "waiting" then state = "notready" end
	f.call:SetTexture(P.markers[state] or P.markers.waiting)
	f.call:Show()
end

local function updateRange(f)
	local inside = UnitInRange(f.display)
	local a = (inside or UnitIsUnit(f.display, "player")) and 1 or P.outOfRangeAlpha
	if f.rangeAlpha ~= a then
		f.rangeAlpha = a
		for _, r in ipairs(f.fadedRegions) do r:SetAlpha(a) end
		for _, g in ipairs({ f.buffs, f.debuffs }) do
			for _, x in ipairs(g) do x:SetAlpha(a) end
		end
		for _, t in ipairs(f.threat) do t:SetAlpha(a) end
		f.overlay:SetAlpha(a)
	end
end

function R.updateButton(f)
	if not f.unit or not UnitExists(f.unit) then
		f.display = nil
		return
	end
	f.display, f.vehicle = displayedUnit(f.unit)
	placeBars(f)
	f.name:SetText(GetUnitName(f.unit, false))
	updateHealth(f)
	updateResource(f)
	updateRole(f)
	updateThreat(f)
	updateTarget(f)
	updateAuras(f)
	updateReadyCheck(f)
	updateRange(f)
end

local function buttonsFor(unit)
	local l = {}
	for _, f in ipairs(R.buttons) do
		if f.unit and (f.unit == unit or f.display == unit) then l[#l + 1] = f end
	end
	return l
end

-- --------------------------------------------------------------------- menu

local menu = CreateFrame("Frame", "ForeverUICompactRaidFrameDropDown", UIParent, "UIDropDownMenuTemplate")
menu:Hide()
menu.displayMode = "MENU"
-- CompactUnitFrame_OpenMenu: SELF, VEHICLE or RAID_PLAYER; the menu fills when opened
-- (ToggleDropDownMenu), never when built
menu.initialize = function(self)
	local m = UIDROPDOWNMENU_OPEN_MENU or self
	if not m or not m.unit then return end
	UnitPopup_ShowMenu(m, m.which, m.unit, m.name, m.id)
end

function R.openMenu(f)
	if not f.unit then return end
	local id = tonumber(f.unit:match("^raid(%d+)$"))
	if UnitIsUnit(f.unit, "player") then
		menu.which = "SELF"
	elseif f.vehicle then
		menu.which = "VEHICLE"
	else
		menu.which = "RAID_PLAYER"
	end
	menu.unit = f.vehicle and f.display or f.unit
	menu.name = UnitName(f.unit)
	menu.id = id
	ForeverUI.UnitMenu.open(ToggleDropDownMenu, 1, nil, menu, "cursor")
end

-- ------------------------------------------------------ container and groups

local container = CreateFrame("Frame", "ForeverUICompactRaidFrameContainer", UIParent)
container:SetFrameStrata("LOW")
container:SetWidth(P.width)
container:SetHeight(P.titleH + P.perGroup * P.height)
R.container = container

R.headers, R.titles = {}, {}
for g = 1, P.groups do
	local h = CreateFrame("Frame", "ForeverUICompactRaidGroup" .. g, container, "SecureRaidGroupHeaderTemplate")
	h:SetAttribute("groupFilter", tostring(g))
	h:SetAttribute("point", "TOP")
	h:SetAttribute("yOffset", 0)
	h:SetAttribute("template", "SecureUnitButtonTemplate")
	h:SetAttribute("templateType", "Button")
	h:SetAttribute("unitsPerColumn", P.perGroup)
	h:SetAttribute("maxColumns", 1)
	h:SetAttribute("sortMethod", "INDEX")
	h.initialConfigFunction = configure
	h:SetWidth(P.width)
	h:SetHeight(P.perGroup * P.height)
	R.headers[g] = h

	-- title (CompactRaidGroup: 14 high, GameFontNormalSmall): a plain frame, so it can show or
	-- hide in combat. The client has no GROUP_NUMBER, so it reads GROUP and the number.
	local t = CreateFrame("Frame", nil, container)
	t:SetWidth(P.width)
	t:SetHeight(P.titleH)
	t.text = t:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	t.text:SetPoint("TOP", t, "TOP", 0, 0)
	t.text:SetText(GROUP .. " " .. g)
	t:Hide()
	R.titles[g] = t
end

-- Groups that have members; a flag per group number.
local function usedGroups()
	local inUse = {}
	for i = 1, (GetNumRaidMembers() or 0) do
		local _, _, group = GetRaidRosterInfo(i)
		if group then inUse[group] = true end
	end
	return inUse
end

-- Used groups go in adjacent columns, the others follow in order, so a group filling up in
-- combat appears at the end without overlapping. Secure headers move only out of combat,
-- so in combat the layout waits for PLAYER_REGEN_ENABLED.
function R.layout()
	if InCombatLockdown() then
		R.needsLayout = true
		return
	end
	R.needsLayout = nil
	local inUse = usedGroups()
	local order = {}
	for g = 1, P.groups do if inUse[g] then order[#order + 1] = g end end
	local n = #order
	for g = 1, P.groups do if not inUse[g] then order[#order + 1] = g end end
	for k, g in ipairs(order) do
		local x = (k - 1) * P.width
		R.titles[g]:ClearAllPoints()
		R.titles[g]:SetPoint("TOPLEFT", container, "TOPLEFT", x, 0)
		R.headers[g]:ClearAllPoints()
		R.headers[g]:SetPoint("TOPLEFT", container, "TOPLEFT", x, -P.titleH)
	end
	container:SetWidth(P.width * math.max(n, 1))
	R.updateTitles()
end

-- one title per group with members (not a protected frame)
function R.updateTitles()
	local inUse = usedGroups()
	for g = 1, P.groups do
		if inUse[g] then R.titles[g]:Show() else R.titles[g]:Hide() end
	end
end

-- Creates the five buttons of each group ahead, out of combat: startingIndex at -4 for a
-- moment makes the header build them all, so none is created in combat.
local function createButtons()
	container:Show()
	for _, h in ipairs(R.headers) do
		h:Show()
		h:SetAttribute("startingIndex", -(P.perGroup - 1))
		h:SetAttribute("startingIndex", 1)
	end
end

-- ------------------------------------------------------------------ HD addon

-- "Compact Raid Frames - HD client" (patch-5.mpq): disabled for the next session, its frames
-- hidden for this one
local function disableHDAddon()
	if not (IsAddOnLoaded and IsAddOnLoaded("CompactRaidFrame")) then return end
	if DisableAddOn then DisableAddOn("CompactRaidFrame") end
	if InCombatLockdown() then return end
	for _, name in ipairs({ "CompactRaidFrameManager", "CompactRaidFrameContainer" }) do
		local f = _G[name]
		if f then RegisterStateDriver(f, "visibility", "hide") end
	end
end

-- --------------------------------------------------------------- events

local listener = CreateFrame("Frame")
R.listener = listener
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "RAID_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED",
	"PLAYER_TARGET_CHANGED", "PLAYER_ROLES_ASSIGNED", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_DISPLAYPOWER",
	"UNIT_MANA", "UNIT_RAGE", "UNIT_FOCUS", "UNIT_ENERGY", "UNIT_RUNIC_POWER", "UNIT_MAXMANA",
	"UNIT_MAXRAGE", "UNIT_MAXFOCUS", "UNIT_MAXENERGY", "UNIT_MAXRUNIC_POWER", "UNIT_NAME_UPDATE",
	"UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
	"PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE", "READY_CHECK", "READY_CHECK_CONFIRM",
	"READY_CHECK_FINISHED" }) do
	listener:RegisterEvent(ev)
end

local function all()
	for _, f in ipairs(R.buttons) do
		if f:IsShown() then R.updateButton(f) end
	end
end

listener:SetScript("OnEvent", function(self, ev, unit)
	if ev == "PLAYER_ENTERING_WORLD" then
		disableHDAddon()
		R.layout()
		all()
	elseif ev == "RAID_ROSTER_UPDATE" then
		R.layout()
		R.updateTitles()
		all()
	elseif ev == "PLAYER_REGEN_ENABLED" then
		if R.needsLayout then R.layout() end
		disableHDAddon()
	elseif ev == "PLAYER_TARGET_CHANGED" then
		for _, f in ipairs(R.buttons) do if f.display then updateTarget(f) end end
	elseif ev == "PLAYER_ROLES_ASSIGNED" or ev == "PARTY_MEMBER_ENABLE" or ev == "PARTY_MEMBER_DISABLE" then
		all()
	elseif ev == "READY_CHECK" or ev == "READY_CHECK_CONFIRM" then
		for _, f in ipairs(R.buttons) do updateReadyCheck(f) end
	elseif ev == "READY_CHECK_FINISHED" then
		for _, f in ipairs(R.buttons) do updateReadyCheck(f, true) end
		R.readyCheckFinish = P.readyCheckFinish
		R.timer:Show()
	else
		for _, f in ipairs(buttonsFor(unit)) do R.updateButton(f) end
	end
end)

-- range (UnitInRange has no event in 3.3.5) and the end of the ready check
local timer = CreateFrame("Frame")
timer.clock = 0
timer:SetScript("OnUpdate", function(self, elapsed)
	self.clock = self.clock + elapsed
	if self.clock >= P.rangePeriod then
		self.clock = 0
		for _, f in ipairs(R.buttons) do
			if f.display and f:IsVisible() then updateRange(f) end
		end
	end
	if R.readyCheckFinish then
		R.readyCheckFinish = R.readyCheckFinish - elapsed
		if R.readyCheckFinish <= 0 then
			R.readyCheckFinish = nil
			for _, f in ipairs(R.buttons) do f.call:Hide() end
		end
	end
end)
R.timer = timer

createButtons()
RegisterStateDriver(container, "visibility", "[group:raid] show; hide")
R.layout()
ForeverUI.Layout.Register(container, "raidframe", L.RAIDFRAME_EDIT_LABEL, "TOPLEFT", "TOPLEFT", P.x, P.y)
