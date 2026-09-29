-- Party frames, reproduced from Camelot's blizzard_unitframe (shared/partyframe.*,
-- mainline/partyframetemplates.xml, partymemberframe.lua). Members and pets are secure
-- buttons shown by RegisterUnitWatch and the container hides in raids through a state driver,
-- so both work in combat. 3.3.5 has no heal prediction, absorbs, phase, summon or away icons.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local SEP = string.char(92)
local L = ForeverUI.L

-- Sizes, offsets and atlases from Camelot's code, in one table: Lua 5.1 limits a function
-- to 60 upvalues. x, y: container position (Camelot anchors it under the folded raid manager).
local P = {
	memberW = 120, memberH = 53, spacing = 10, petSpacing = 26, down = 2,
	x = 22, y = -147,
	art = "ui-hud-unitframe-party-portraiton",
	vehicleArt = "ui-hud-unitframe-party-portraiton-vehicle",
	glow = "ui-hud-unitframe-party-portraiton-incombat",
	vehicleGlow = "ui-hud-unitframe-party-portraiton-vehicle-incombat",
	status = "ui-hud-unitframe-party-portraiton-status",
	vehicleStatus = "ui-hud-unitframe-party-portraiton-vehicle-status",
	health = "ui-hud-unitframe-party-portraiton-bar-health",
	vehicleHealth = "ui-hud-unitframe-party-portraiton-vehicle-bar-health",
	leader = "ui-hud-unitframe-player-group-leadericon",
	guide = "ui-hud-unitframe-player-group-guideicon",
	pvpFfa = "ui-hud-unitframe-player-pvp-ffaicon",
	pvpHorde = "ui-hud-unitframe-player-pvp-hordeicon",
	pvpAlliance = "ui-hud-unitframe-player-pvp-allianceicon",
	pvpScale = 0.6,
	disconnected = "Interface" .. SEP .. "CharacterFrame" .. SEP .. "Disconnect-Icon",
	auraBorder = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Debuff-Overlays",
	markers = {
		ready = "Interface" .. SEP .. "ForeverUI" .. SEP .. "lfgframe" .. SEP .. "ui-lfg-readymark",
		notready = "Interface" .. SEP .. "ForeverUI" .. SEP .. "lfgframe" .. SEP .. "ui-lfg-declinemark",
		waiting = "Interface" .. SEP .. "ForeverUI" .. SEP .. "lfgframe" .. SEP .. "ui-lfg-pendingmark",
	},
	readyCheckStay = 10, readyCheckFade = 1.5,
	auras = 4, auraSide = 15, auraGap = 2,
	pulse = 0.5, pulseMin = 127 / 255,
	-- Normal / vehicle: anchors and widths set by ToPlayerArt and ToVehicleArt
	-- ({ x, y } or { x, y, width })
	player = { art = { 1, -2 }, glow = { 1, -2 }, status = { 1, -2 }, health = { 45, -19, 70 },
		resource = { 42, -30, 73 }, name = { 46, -6, 57 } },
	vehicle = { art = { 0, 0 }, glow = { -4, 4 }, status = { -3, 3 }, health = { 48, -18, 67 },
		resource = { 45, -29, 70 }, name = { 49, -6, 56 } },
}

-- Resource atlas name, built from the power token
local RESOURCE = { MANA = "Mana", RAGE = "Rage", FOCUS = "Focus", ENERGY = "Energy", RUNIC_POWER = "RunicPower" }

local function resourceAtlas(token, vehicle)
	local name = RESOURCE[token or ""] or "Mana"
	return "ui-hud-unitframe-party-portraiton" .. (vehicle and "-vehicle" or "") .. "-bar-" .. string.lower(name)
end

local G = {}                         -- shared state
ForeverUI.PartyFrame = G

-- ----------------------------------------------------------------- Container

local container = CreateFrame("Frame", "ForeverUIPartyFrame", UIParent)
container:SetFrameStrata("LOW")
container:SetWidth(P.memberW)
G.container = container

-- Distance between two members: 10 apart, 26 when party pets are shown
local function step()
	local pets = GetCVarBool and GetCVarBool("showPartyPets")
	return P.memberH + (pets and P.petSpacing or P.spacing)
end

-- ------------------------------------------------------------------ Parts

local function field(parent, layer, font)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", font)
	return fs
end

local function createAuras(parent, name, x, y, unit)
	local auras = {}
	for k = 1, P.auras do
		local b = CreateFrame("Button", name .. "Debuff" .. k, parent)
		b:SetWidth(P.auraSide)
		b:SetHeight(P.auraSide)
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (k - 1) * (P.auraSide + P.auraGap), y)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetAllPoints(b)
		b.border = b:CreateTexture(nil, "OVERLAY")
		b.border:SetTexture(P.auraBorder)
		b.border:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		b.border:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
		b.border:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
		b.stack = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		b.stack:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 5, 0)
		b.cooldown = CreateFrame("Cooldown", nil, b)
		b.cooldown:SetReverse(true)
		b.cooldown:SetPoint("CENTER", b, "CENTER", 0, -1)
		b.cooldown:SetWidth(P.auraSide)
		b.cooldown:SetHeight(P.auraSide)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetUnitDebuff(self.unit, self.index, self.filter)
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		b:Hide()
		auras[k] = b
	end
	return auras
end

-- Debuffs follow RefreshDebuffs: filter "RAID" when the dispellable-debuffs option is on
-- and the unit can be assisted
local function updateAuras(auras, unit)
	local filter
	if GetCVarBool("showDispelDebuffs") and UnitCanAssist("player", unit) then
		filter = "RAID"
	end
	local color
	for k, b in ipairs(auras) do
		local name, _, icon, stack, type, duration, finish = UnitDebuff(unit, k, filter)
		if icon then
			b.unit, b.index, b.filter = unit, k, filter
			b.icon:SetTexture(icon)
			local c = DebuffTypeColor[type or "none"] or DebuffTypeColor["none"]
			b.border:SetVertexColor(c.r, c.g, c.b)
			if stack and stack > 1 then
				b.stack:SetText(stack > 99 and "*" or stack)
			else
				b.stack:SetText("")
			end
			if duration and duration > 0 and finish then
				CooldownFrame_SetTimer(b.cooldown, finish - duration, duration, 1)
			else
				b.cooldown:Hide()
			end
			b:Show()
			if type and not color then color = c end
		else
			b:Hide()
		end
	end
	return color
end

-- --------------------------------------------------------------- Pet

local function createPet(member, i)
	local f = CreateFrame("Button", "ForeverUIPartyMemberFrame" .. i .. "PetFrame", member, "SecureUnitButtonTemplate")
	f:SetWidth(64)
	f:SetHeight(23)
	f:SetFrameStrata("LOW")
	f:SetPoint("TOPLEFT", member, "TOPLEFT", 23, -43)
	f.unit = "partypet" .. i
	f:SetAttribute("unit", f.unit)
	f:SetAttribute("*type1", "target")
	f:SetAttribute("toggleForVehicle", true)
	f:RegisterForClicks("AnyUp")
	f.portrait = f:CreateTexture(nil, "BACKGROUND")
	f.portrait:SetWidth(18)
	f.portrait:SetHeight(18)
	f.portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
	-- 3.3.5 cannot scale a texture: art and glow at scale 0.5 are sized by hand,
	-- 120 x 49 -> 60 x 24.5; 114 x 47 -> 57 x 23.5
	f.art = f:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(f.art, P.art, true)
	f.art:SetWidth(60)
	f.art:SetHeight(24.5)
	f.art:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -0.5)
	local hovered = CreateFrame("Frame", nil, f)
	hovered:SetAllPoints(f)
	hovered:SetFrameLevel(f:GetFrameLevel() + 1)
	f.glow = hovered:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(f.glow, P.glow, true)
	f.glow:SetWidth(57)
	f.glow:SetHeight(23.5)
	f.glow:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -0.5)
	f.glow:Hide()
	-- Health: 71 x 10 at (43, -18), at scale 0.5
	f.health = hovered:CreateTexture(nil, "BORDER")
	f.health:SetPoint("TOPLEFT", f, "TOPLEFT", 21.5, -9)
	f.auras = createAuras(f, f:GetName(), 24, -16)
	f:SetScript("OnEnter", function(self)
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetUnit(self.display or self.unit)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:FadeOut() end)
	return f
end

-- ----------------------------------------------------------------- Member

local function createMember(i)
	local m = CreateFrame("Button", "ForeverUIPartyMemberFrame" .. i, container, "SecureUnitButtonTemplate")
	m:SetID(i)
	m:SetWidth(P.memberW)
	m:SetHeight(P.memberH)
	m:SetFrameStrata("LOW")
	m.unit = "party" .. i
	m:SetAttribute("unit", m.unit)
	m:SetAttribute("*type1", "target")
	m:SetAttribute("*type2", "menu")
	m:SetAttribute("toggleForVehicle", true)
	m:RegisterForClicks("AnyUp")
	-- The client's menu: that of its own party frame, UnitPopup "PARTY"
	m.menu = function(self)
		ForeverUI.UnitMenu.open(ToggleDropDownMenu, 1, nil, _G["PartyMemberFrame" .. i .. "DropDown"], self:GetName(), 47, 15)
	end

	m.portrait = m:CreateTexture(nil, "BACKGROUND")
	m.portrait:SetWidth(37)
	m.portrait:SetHeight(37)
	m.portrait:SetPoint("TOPLEFT", m, "TOPLEFT", 7, -6)
	m.art = m:CreateTexture(nil, "ARTWORK")

	-- Bars above the art (Camelot puts them in a child frame)
	local bars = CreateFrame("Frame", nil, m)
	bars:SetAllPoints(m)
	bars:SetFrameLevel(m:GetFrameLevel() + 1)
	m.health = bars:CreateTexture(nil, "ARTWORK")
	m.resource = bars:CreateTexture(nil, "ARTWORK")
	m.healthText = field(bars, "OVERLAY", "TextStatusBarText")
	m.resourceText = field(bars, "OVERLAY", "TextStatusBarText")

	-- What goes above everything
	local hovered = CreateFrame("Frame", nil, m)
	hovered:SetAllPoints(m)
	hovered:SetFrameLevel(m:GetFrameLevel() + 2)
	m.hovered = hovered
	m.glow = hovered:CreateTexture(nil, "BACKGROUND")
	m.glow:Hide()
	m.status = hovered:CreateTexture(nil, "BACKGROUND")
	m.status:Hide()
	m.name = field(hovered, "OVERLAY", "GameFontNormalSmall")
	m.name:SetJustifyH("LEFT")
	m.name:SetHeight(12)
	m.leader = hovered:CreateTexture(nil, "OVERLAY")
	m.leader:SetPoint("BOTTOM", m, "TOP", -10, -6)
	m.leader:Hide()
	m.pvp = hovered:CreateTexture(nil, "OVERLAY")
	m.pvp:Hide()
	m.disconnected = hovered:CreateTexture(nil, "OVERLAY")
	m.disconnected:SetTexture(P.disconnected)
	m.disconnected:SetWidth(64)
	m.disconnected:SetHeight(64)
	m.disconnected:SetPoint("LEFT", m, "LEFT", -7, -1)
	m.disconnected:Hide()
	m.role = hovered:CreateTexture(nil, "OVERLAY")
	m.role:SetWidth(12)
	m.role:SetHeight(12)
	m.role:SetPoint("TOPRIGHT", m, "TOPRIGHT", -5, -5)
	m.role:Hide()

	-- Ready check icon: 36 x 36, two levels above (RaiseFrameLevelByTwo). The marks are
	-- Camelot's UI-LFG-*Mark, cut from their 2048 sheet (tools/cut_marks.py).
	local call = CreateFrame("Frame", nil, m)
	call:SetWidth(36)
	call:SetHeight(36)
	call:SetPoint("CENTER", m.portrait, "CENTER", 0, -2)
	call:SetFrameLevel(m:GetFrameLevel() + 4)
	call.icon = call:CreateTexture(nil, "ARTWORK")
	call.icon:SetAllPoints(call)
	call:Hide()
	m.call = call

	m.auras = createAuras(hovered, m:GetName(), 48, -43)
	m.pet = createPet(m, i)

	m:SetScript("OnEnter", function(self)
		-- Hover shows the bar texts (when CVar partyStatusText is 0). The tooltip has no
		-- UNIT_POPUP_RIGHT_CLICK line: that string does not exist in the 3.3.5 client.
		self.hover = true
		G.updateMember(self)
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetUnit(self.unit)
		GameTooltip:Show()
		-- The client's buff tooltip (PartyMemberBuffTooltip), where Camelot puts its own
		if PartyMemberBuffTooltip and PartyMemberBuffTooltip_Update then
			PartyMemberBuffTooltip:ClearAllPoints()
			PartyMemberBuffTooltip:SetPoint("TOPLEFT", self, "TOPLEFT", 47, -25)
			PartyMemberBuffTooltip_Update(self)
		end
	end)
	m:SetScript("OnLeave", function(self)
		self.hover = nil
		G.updateMember(self)
		GameTooltip:FadeOut()
		if PartyMemberBuffTooltip then PartyMemberBuffTooltip:Hide() end
	end)
	return m
end

G.members = {}
for i = 1, 4 do
	G.members[i] = createMember(i)
end

-- ------------------------------------------------------------ Updates

-- Displayed unit: the vehicle if any (the frame follows partypetN)
local function units(m)
	local i = m:GetID()
	if UnitHasVehicleUI("party" .. i) then
		return "partypet" .. i, "party" .. i, true
	end
	return "party" .. i, "partypet" .. i, false
end

local function place(tex, atlas, x, y, rel)
	ForeverUI.SetAtlas(tex, atlas)
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", rel, "TOPLEFT", x, y)
end

-- ToPlayerArt / ToVehicleArt
local function updateArt(m)
	local geo = m.vehicle and P.vehicle or P.player
	place(m.art, m.vehicle and P.vehicleArt or P.art, geo.art[1], geo.art[2], m)
	place(m.glow, m.vehicle and P.vehicleGlow or P.glow, geo.glow[1], geo.glow[2], m)
	place(m.status, m.vehicle and P.vehicleStatus or P.status, geo.status[1], geo.status[2], m)
	m.health:ClearAllPoints()
	m.health:SetPoint("TOPLEFT", m, "TOPLEFT", geo.health[1], geo.health[2])
	m.resource:ClearAllPoints()
	m.resource:SetPoint("TOPLEFT", m, "TOPLEFT", geo.resource[1], geo.resource[2])
	m.name:ClearAllPoints()
	m.name:SetPoint("TOPLEFT", m, "TOPLEFT", geo.name[1], geo.name[2])
	m.name:SetWidth(geo.name[3])
end

local function fraction(value, maximum)
	if not maximum or maximum <= 0 then return 0 end
	return value / maximum
end

local function updateBarText(fs, value, maximum, hover)
	local always = GetCVar("partyStatusText") == "1"
	if not (always or hover) or not maximum or maximum <= 0 then
		fs:Hide()
		return
	end
	if GetCVarBool("statusTextPercentage") then
		fs:SetText(math.ceil(value / maximum * 100) .. "%")
	else
		fs:SetText(value .. " / " .. maximum)
	end
	fs:Show()
end

local function updateHealth(m)
	local u = m.unit
	local geo = m.vehicle and P.vehicle or P.player
	local atlas = m.vehicle and P.vehicleHealth or P.health
	local connected = UnitIsConnected(m.unit)
	local health, max = UnitHealth(u), UnitHealthMax(u)
	-- Disconnected: full bar, desaturated
	ForeverUI.SetAtlasFill(m.health, atlas, connected and fraction(health, max) or 1, geo.health[3])
	m.health:SetDesaturated(not connected)
	m.healthText:ClearAllPoints()
	m.healthText:SetPoint("CENTER", m, "TOPLEFT", geo.health[1] + geo.health[3] / 2, geo.health[2] - 5)
	if UnitIsDeadOrGhost(u) then
		m.healthText:SetText(DEAD)
		m.healthText:Show()
	else
		updateBarText(m.healthText, health, max, m.hover)
	end
	-- PartyMemberHealthCheck: portrait tint
	m.percent = fraction(health, max)
	if UnitIsDead(u) then
		m.portrait:SetVertexColor(0.35, 0.35, 0.35, 1)
	elseif UnitIsGhost(u) then
		m.portrait:SetVertexColor(0.2, 0.2, 0.75, 1)
	elseif m.percent > 0 and m.percent <= 0.2 then
		m.portrait:SetVertexColor(1, 0, 0)
	else
		m.portrait:SetVertexColor(1, 1, 1, 1)
	end
	G.updatePulse()
end

local function updateResource(m)
	local u = m.unit
	local geo = m.vehicle and P.vehicle or P.player
	local type, token = UnitPowerType(u)
	local value, max = UnitPower(u, type), UnitPowerMax(u, type)
	ForeverUI.SetAtlasFill(m.resource, resourceAtlas(token, m.vehicle), fraction(value, max), geo.resource[3])
	-- 3.3.5 has no masks. Camelot's mask hides the bar's first pixel, so the bar starts one pixel
	-- further, 73 wide (P.player.resource); its 1-3 px top-left bevel is not reproduced.
	m.resourceText:ClearAllPoints()
	m.resourceText:SetPoint("CENTER", m, "TOPLEFT", geo.resource[1] + geo.resource[3] / 2 + 2, geo.resource[2] - 3.5)
	updateBarText(m.resourceText, value, max, m.hover)
end

local function updatePortrait(m)
	SetPortraitTexture(m.portrait, m.unit)
	m.portrait:SetDesaturated(not UnitIsConnected(m.unit))
end

-- Leader or guide (HasLFGRestrictions: a Dungeon Finder group)
local function updateLeader(m)
	if GetPartyLeaderIndex() == m:GetID() then
		ForeverUI.SetAtlas(m.leader, HasLFGRestrictions() and P.guide or P.leader)
		m.leader:Show()
	else
		m.leader:Hide()
	end
end

local function updatePvP(m)
	local u = m.unit
	local atlas
	if UnitIsPVPFreeForAll(u) then
		atlas = P.pvpFfa
	elseif UnitIsPVP(u) then
		local faction = UnitFactionGroup(u)
		if faction == "Horde" then atlas = P.pvpHorde elseif faction == "Alliance" then atlas = P.pvpAlliance end
	end
	if atlas and ForeverUI.SetAtlas(m.pvp, atlas) then
		-- At scale 0.6: atlas size and offset (24, -68)
		m.pvp:SetWidth(m.pvp:GetWidth() * P.pvpScale)
		m.pvp:SetHeight(m.pvp:GetHeight() * P.pvpScale)
		m.pvp:ClearAllPoints()
		m.pvp:SetPoint("CENTER", m, "TOPLEFT", 24 * P.pvpScale, -68 * P.pvpScale)
		m.pvp:Show()
	else
		m.pvp:Hide()
	end
end

-- UnitGroupRolesAssigned returns three booleans in 3.3.5
local function updateRole(m)
	local tank, healer, damage = UnitGroupRolesAssigned(m.unit)
	local atlas = (tank and "roleicon-tiny-tank") or (healer and "roleicon-tiny-healer") or (damage and "roleicon-tiny-dps")
	if atlas and ForeverUI.SetAtlas(m.role, atlas, true) then
		m.role:Show()
	else
		m.role:Hide()
	end
end

local function updateThreat(m)
	local status = UnitThreatSituation(m.unit)
	if IsThreatWarningEnabled() and status and status > 0 and not UnitIsDeadOrGhost(m.unit) then
		m.glow:SetVertexColor(GetThreatStatusColor(status))
		m.glow:Show()
	else
		m.glow:Hide()
	end
end

local function updateMemberAuras(m)
	local color = updateAuras(m.auras, m.unit)
	if color then
		m.status:SetVertexColor(color.r, color.g, color.b)
		m.status:Show()
	else
		m.status:Hide()
	end
end

local function updatePet(m)
	local f = m.pet
	f.display = m.petUnit
	local u = f.display
	if not UnitExists(u) then return end
	SetPortraitTexture(f.portrait, u)
	local connected = UnitIsConnected(m.unit)
	-- 71 x 10 at scale 0.5: 35.5 long, green tint (no lockColor)
	ForeverUI.SetAtlasFill(f.health, P.health, connected and fraction(UnitHealth(u), UnitHealthMax(u)) or 1, 35.5)
	f.health:SetHeight(5)
	if connected then f.health:SetVertexColor(0, 1, 0) else f.health:SetVertexColor(0.5, 0.5, 0.5) end
	local status = UnitThreatSituation(u)
	if IsThreatWarningEnabled() and status and status > 0 then
		f.glow:SetVertexColor(GetThreatStatusColor(status))
		f.glow:Show()
	else
		f.glow:Hide()
	end
	updateAuras(f.auras, u)
end

local function updateDisconnected(m)
	if UnitIsConnected(m.unit) then m.disconnected:Hide() else m.disconnected:Show() end
end

function G.updateMember(m)
	if not UnitExists(m.unit) then return end
	local display, pet, vehicle = units(m)
	m.unit, m.petUnit, m.vehicle = display, pet, vehicle
	updateArt(m)
	m.name:SetText(GetUnitName(display, true))
	updatePortrait(m)
	updateHealth(m)
	updateResource(m)
	updateLeader(m)
	updatePvP(m)
	updateRole(m)
	updateThreat(m)
	updateMemberAuras(m)
	updateDisconnected(m)
	updatePet(m)
end

-- Portrait pulse below 20% health: alpha goes from 127/255 to 1 and back, in 0.5 s
-- half-periods, while any member is in that state
local pulse = CreateFrame("Frame")
pulse.clock = 0
pulse:Hide()
pulse:SetScript("OnUpdate", function(self, elapsed)
	self.clock = self.clock + elapsed
	local t = (self.clock % (2 * P.pulse)) / P.pulse
	local a = t <= 1 and (1 - t * (1 - P.pulseMin)) or (P.pulseMin + (t - 1) * (1 - P.pulseMin))
	for _, m in ipairs(G.members) do
		if m.pulsing then m.portrait:SetAlpha(a) end
	end
end)

function G.updatePulse()
	local one = false
	for _, m in ipairs(G.members) do
		local pulsing = m:IsShown() and not UnitIsDeadOrGhost(m.unit or m.unit) and m.percent
			and m.percent > 0 and m.percent <= 0.2
		m.pulsing = pulsing
		if not pulsing then m.portrait:SetAlpha(1) end
		one = one or pulsing
	end
	if one then pulse:Show() else pulse:Hide() end
end

-- ---------------------------------------------------------------------- Ready check

local function updateReadyCheck(m, finish)
	local state = GetReadyCheckStatus(m.unit)
	local a = m.call
	if not state then
		if not finish then a:Hide() end
		return
	end
	if finish and state == "waiting" then state = "notready" end
	a.icon:SetTexture(P.markers[state] or P.markers.waiting)
	a:SetAlpha(1)
	a.rest = nil
	if finish then a.rest = P.readyCheckStay + P.readyCheckFade end
	a:Show()
end

local timer = CreateFrame("Frame")
timer:SetScript("OnUpdate", function(self, elapsed)
	local active = false
	for _, m in ipairs(G.members) do
		local a = m.call
		if a.rest then
			a.rest = a.rest - elapsed
			if a.rest <= 0 then
				a.rest = nil
				a:Hide()
			else
				if a.rest < P.readyCheckFade then a:SetAlpha(a.rest / P.readyCheckFade) end
				active = true
			end
		end
	end
	if not active then self:Hide() end
end)
timer:Hide()

-- ------------------------------------------------------------ Layout

-- The step depends on the party pets option; out of combat only
function G.layout()
	if InCombatLockdown() then
		G.needsLayout = true
		return
	end
	G.needsLayout = nil
	local p = step()
	for i, m in ipairs(G.members) do
		m:ClearAllPoints()
		m:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(i - 1) * p)
		local f = m.pet
		UnregisterUnitWatch(f)
		if GetCVarBool("showPartyPets") then
			RegisterUnitWatch(f)
		else
			f:Hide()
		end
	end
	container:SetHeight(4 * P.memberH + 3 * (p - P.memberH) + P.down)
end

-- Client party frames: no events, and kept hidden by a state driver, so a Show from
-- elsewhere (the client, another addon), even in combat, is undone
local function hideClient()
	if InCombatLockdown() or G.clientHidden then return end
	for i = 1, 4 do
		local f = _G["PartyMemberFrame" .. i]
		if f then
			f:UnregisterAllEvents()
			f:Hide()
			RegisterStateDriver(f, "visibility", "hide")
		end
	end
	if PartyMemberBackground then ForeverUI.Suppress(PartyMemberBackground) end
	G.clientHidden = true
end

-- ---------------------------------------------------------------- Events

local function memberOf(unit)
	if not unit then return nil end
	local i = unit:match("^party(%d)$") or unit:match("^partypet(%d)$")
	return i and G.members[tonumber(i)]
end

local listener = CreateFrame("Frame")
G.listener = listener
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PARTY_MEMBERS_CHANGED", "PARTY_LEADER_CHANGED",
	"PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_DISPLAYPOWER",
	"UNIT_MANA", "UNIT_RAGE", "UNIT_FOCUS", "UNIT_ENERGY", "UNIT_RUNIC_POWER", "UNIT_MAXMANA",
	"UNIT_MAXRAGE", "UNIT_MAXFOCUS", "UNIT_MAXENERGY", "UNIT_MAXRUNIC_POWER", "UNIT_NAME_UPDATE",
	"UNIT_PORTRAIT_UPDATE", "UNIT_AURA", "UNIT_PET", "UNIT_FACTION", "UNIT_THREAT_SITUATION_UPDATE",
	"UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "READY_CHECK", "READY_CHECK_CONFIRM",
	"READY_CHECK_FINISHED", "PLAYER_ROLES_ASSIGNED", "CVAR_UPDATE", "PLAYER_REGEN_ENABLED" }) do
	listener:RegisterEvent(ev)
end

local function all()
	for _, m in ipairs(G.members) do G.updateMember(m) end
end

listener:SetScript("OnEvent", function(self, ev, unit)
	if ev == "PLAYER_ENTERING_WORLD" then
		hideClient()
		G.layout()
		all()
	elseif ev == "PLAYER_REGEN_ENABLED" then
		hideClient()
		if G.needsLayout then G.layout() end
	elseif ev == "PARTY_MEMBERS_CHANGED" or ev == "PARTY_LEADER_CHANGED" or ev == "PLAYER_ROLES_ASSIGNED" then
		all()
	elseif ev == "CVAR_UPDATE" then
		G.layout()
		all()
	elseif ev == "READY_CHECK" or ev == "READY_CHECK_CONFIRM" then
		for _, m in ipairs(G.members) do updateReadyCheck(m) end
	elseif ev == "READY_CHECK_FINISHED" then
		for _, m in ipairs(G.members) do updateReadyCheck(m, true) end
		timer:Show()
	else
		local m = memberOf(unit)
		if m then G.updateMember(m) end
	end
end)

for _, m in ipairs(G.members) do
	RegisterUnitWatch(m)
end

-- In a party, not in a raid (ShouldShowPartyFrames)
RegisterStateDriver(container, "visibility", "[group:raid] hide; [group] show; hide")

G.layout()
ForeverUI.Layout.Register(container, "partyframe", L.PARTYFRAME_EDIT_LABEL, "TOPLEFT", "TOPLEFT", P.x, P.y)
