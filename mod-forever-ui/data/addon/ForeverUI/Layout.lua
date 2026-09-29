-- ForeverUI: movable positions.
-- Every frame ForeverUI builds registers here with a default position; this table places it
-- on load and remembers where the player moves it. Everything is anchored to UIParent, never
-- to another ForeverUI frame, so moving one element never drags another.

ForeverUI = ForeverUI or {}

-- Disable a client frame. Hiding is not enough: its own code shows it again (page change,
-- vehicle exit, rune update). So we unregister its events, hide it, and hide it again on
-- OnShow.
function ForeverUI.Suppress(frame)
	if not frame or frame.foreverSuppressed then
		return
	end

	if frame.UnregisterAllEvents then
		frame:UnregisterAllEvents()
	end
	frame:Hide()

	if frame.HookScript then
		frame:HookScript("OnShow", function(self)
			self:Hide()
		end)
	end

	frame.foreverSuppressed = true
end

local Layout = {}
ForeverUI.Layout = Layout

Layout.systems = {}   -- id -> { frame, label, defaults }
Layout.order = {}     -- ids, in registration order
Layout.editing = false

local PREFIX = "|cff66ccffForeverUI|r : "
local L = ForeverUI.L

local function say(message)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

local function positions()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

-- Place the frame at its saved position, or at its default position.
function Layout.Apply(id)
	local system = Layout.systems[id]
	if not system then
		return false
	end

	local saved = positions()[id]
	local p = saved or system.defaults

	system.frame:ClearAllPoints()
	system.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
	return true
end

function Layout.Save(id)
	local system = Layout.systems[id]
	if not system then
		return false
	end

	local point, _, relativePoint, x, y = system.frame:GetPoint(1)
	if not point then
		return false
	end

	positions()[id] = {
		point = point,
		relativePoint = relativePoint or point,
		x = x or 0,
		y = y or 0,
	}
	return true
end

function Layout.Reset(id)
	if id then
		if not Layout.systems[id] then
			return false
		end
		positions()[id] = nil
		Layout.Apply(id)
		return true
	end

	for _, systemID in ipairs(Layout.order) do
		positions()[systemID] = nil
		Layout.Apply(systemID)
	end
	return true
end

-- Make the frame movable, place it, and show its overlay in edit mode.
-- id: saved-position key; label: overlay text; point..y: default anchor on UIParent
function Layout.Register(frame, id, label, point, relativePoint, x, y)
	Layout.systems[id] = {
		frame = frame,
		label = label,
		defaults = { point = point, relativePoint = relativePoint, x = x, y = y },
	}
	table.insert(Layout.order, id)

	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	Layout.Apply(id)

	if Layout.editing then
		Layout.ShowOverlay(id)
	end
	return frame
end

-- Change the default position of a registered element. The bottom of the screen is a chain:
-- the action bar and the bags sit on each side of the micro menu, whose width is known only
-- once its buttons are counted. An element the player has moved keeps its position.
function Layout.SetDefaults(id, point, relativePoint, x, y)
	local system = Layout.systems[id]
	if not system then
		return false
	end

	system.defaults = { point = point, relativePoint = relativePoint, x = x, y = y }
	if not positions()[id] then
		Layout.Apply(id)
	end
	return true
end

local function buildOverlay(id, system)
	local overlay = CreateFrame("Frame", nil, system.frame)
	overlay:SetAllPoints(system.frame)
	overlay:SetFrameStrata("DIALOG")
	overlay:EnableMouse(true)
	overlay:RegisterForDrag("LeftButton")

	local background = overlay:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(overlay)
	background:SetTexture(0.1, 0.6, 1, 0.35)

	local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("CENTER")
	text:SetText(system.label)

	overlay:SetScript("OnDragStart", function()
		if InCombatLockdown() then
			say(L.LAYOUT_NO_MOVE_IN_COMBAT)
			return
		end
		system.frame:StartMoving()
	end)

	overlay:SetScript("OnDragStop", function()
		system.frame:StopMovingOrSizing()
		Layout.Save(id)
	end)

	system.overlay = overlay
	return overlay
end

function Layout.ShowOverlay(id)
	local system = Layout.systems[id]
	if not system then
		return
	end

	local overlay = system.overlay or buildOverlay(id, system)
	overlay:Show()
end

function Layout.HideOverlay(id)
	local system = Layout.systems[id]
	if system and system.overlay then
		system.overlay:Hide()
	end
end

function Layout.SetEditMode(enabled)
	if enabled and InCombatLockdown() then
		say(L.LAYOUT_EDIT_MODE_COMBAT)
		return false
	end

	Layout.editing = enabled and true or false

	for _, id in ipairs(Layout.order) do
		if Layout.editing then
			Layout.ShowOverlay(id)
		else
			Layout.HideOverlay(id)
		end
	end

	if Layout.editing then
		say(L.LAYOUT_EDIT_MODE_ON)
	else
		say(L.LAYOUT_EDIT_MODE_OFF)
	end
	return true
end

-- Edit mode turns itself off on entering combat: secure frames can no longer be moved, and
-- the blue overlays would suggest otherwise.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:SetScript("OnEvent", function(_self, event)
	if event == "PLAYER_LOGIN" then
		for _, id in ipairs(Layout.order) do
			Layout.Apply(id)
		end
	elseif event == "PLAYER_REGEN_DISABLED" and Layout.editing then
		Layout.SetEditMode(false)
	end
end)

-- /fui mouse: while active, each click prints the frame under the mouse (GetMouseFocus), its
-- parents and its regions, to find where a screen element comes from.
local spy = CreateFrame("Frame")
spy:Hide()
local function describe(frame)
	if not frame then return L.LAYOUT_SPY_NOTHING end
	local name = frame.GetName and frame:GetName() or nil
	local type_ = frame.GetObjectType and frame:GetObjectType() or "?"
	return (name or L.LAYOUT_SPY_UNNAMED) .. " [" .. type_ .. "]"
end
spy:SetScript("OnUpdate", function(self)
	local down = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
	if down and not self.pressed then
		local f = GetMouseFocus and GetMouseFocus()
		say(L.LAYOUT_SPY_UNDER_MOUSE .. describe(f))
		local p, path = f and f:GetParent(), {}
		while p and #path < 8 do
			table.insert(path, describe(p))
			p = p:GetParent()
		end
		DEFAULT_CHAT_FRAME:AddMessage("   " .. L.LAYOUT_SPY_PARENTS .. table.concat(path, " < "))
		if f and f.GetRegions then
			for _, r in ipairs({ f:GetRegions() }) do
				if r.GetTexture and r:GetTexture() then
					DEFAULT_CHAT_FRAME:AddMessage("   " .. L.LAYOUT_SPY_TEXTURE .. tostring(r:GetTexture()))
				elseif r.GetText and r:GetText() then
					DEFAULT_CHAT_FRAME:AddMessage("   " .. L.LAYOUT_SPY_TEXT .. tostring(r:GetText()))
				end
			end
		end
		for _, k in ipairs({ "name", "mapLinkID", "description", "poiID", "instanceID", "mapID" }) do
			if f and f[k] ~= nil then
				DEFAULT_CHAT_FRAME:AddMessage("   ." .. k .. " = " .. tostring(f[k]))
			end
		end
	end
	self.pressed = down and true or false
end)
ForeverUI.MouseSpy = spy
ForeverUI.MouseDebug = function()
	if spy:IsShown() then
		spy:Hide()
		say(L.LAYOUT_SPY_STOPPED)
	else
		spy.pressed = true
		spy:Show()
		say(L.LAYOUT_SPY_STARTED)
	end
end

SLASH_FOREVERUI1 = "/fui"
SLASH_FOREVERUI2 = "/foreverui"

SlashCmdList["FOREVERUI"] = function(message)
	local command, argument = string.match(message or "", "^(%S*)%s*(.*)$")
	argument = argument or ""
	command = string.lower(command or "")

	if command == "" or command == "edit" then
		Layout.SetEditMode(not Layout.editing)
	elseif command == "reset" then
		if argument ~= "" then
			if Layout.Reset(argument) then
				say(L.LAYOUT_RESET_ONE .. argument)
			else
				say(L.LAYOUT_UNKNOWN_ELEMENT .. argument)
			end
		else
			Layout.Reset()
			say(L.LAYOUT_RESET_ALL)
		end
	elseif command == "bar" then
		if ForeverUI.ActionBarDebug then
			ForeverUI.ActionBarDebug()
		else
			say(L.LAYOUT_NO_DIAG_ACTIONBAR)
		end
	elseif command == "bottom" then
		if ForeverUI.BottomBarDebug then
			ForeverUI.BottomBarDebug()
		else
			say(L.LAYOUT_NO_DIAG_BOTTOM)
		end
	elseif command == "statusbars" then
		if ForeverUI.StatusBarsDebug then
			ForeverUI.StatusBarsDebug()
		else
			say(L.LAYOUT_NO_DIAG_STATUSBARS)
		end
	elseif command == "bags" then
		local key, value = string.match(argument, "^(%S+)%s+(%S+)$")
		if key and ForeverUI.BagsSet then
			ForeverUI.BagsSet(key, value)
		elseif ForeverUI.BagsDebug then
			ForeverUI.BagsDebug()
		else
			say(L.LAYOUT_NO_DIAG_BAGS)
		end
	elseif command == "model" then
		if ForeverUI.CharacterModelTune then
			ForeverUI.CharacterModelTune(argument)
		else
			say(L.LAYOUT_NO_MODEL_TUNE)
		end
	elseif command == "tabs" then
		if ForeverUI.CharacterTabsDebug then
			ForeverUI.CharacterTabsDebug()
		else
			say(L.LAYOUT_NO_DIAG_TABS)
		end
	elseif command == "character" then
		if ForeverUI.CharacterSheetDebug then
			ForeverUI.CharacterSheetDebug()
		else
			say(L.LAYOUT_NO_DIAG_SHEET)
		end
	elseif command == "close" then
		if ForeverUI.CharacterCloseDebug then
			ForeverUI.CharacterCloseDebug()
		else
			say(L.LAYOUT_NO_DIAG_SHEET)
		end
	elseif command == "minimap" then
		if ForeverUI.MinimapDebug then
			ForeverUI.MinimapDebug(argument)
		else
			say(L.LAYOUT_NO_DIAG_MINIMAP)
		end
	elseif command == "mouse" then
		ForeverUI.MouseDebug()
	elseif command == "map" then
		if ForeverUI.WorldMapDebug then
			ForeverUI.WorldMapDebug()
		else
			say(L.LAYOUT_NO_DIAG_WORLDMAP)
		end
	elseif command == "questlog" then
		if ForeverUI.QuestLogDebug then
			ForeverUI.QuestLogDebug()
		else
			say(L.LAYOUT_NO_DIAG_QUESTLOG)
		end
	elseif command == "tracking" then
		if ForeverUI.ObjectiveTrackerDebug then
			ForeverUI.ObjectiveTrackerDebug()
		else
			say(L.LAYOUT_NO_DIAG_TRACKER)
		end
	elseif command == "spellbook" then
		if ForeverUI.SpellBookDebug then
			ForeverUI.SpellBookDebug()
		else
			say(L.LAYOUT_NO_DIAG_SPELLBOOK)
		end
	elseif command == "micro" then
		if ForeverUI.MicroDebug then
			ForeverUI.MicroDebug()
		else
			say(L.LAYOUT_NO_DIAG_MICROMENU)
		end
	elseif command == "titles" then
		if ForeverUI.TitlesDebug then
			ForeverUI.TitlesDebug()
		else
			say(L.LAYOUT_NO_DIAG_TITLES)
		end
	elseif command == "pvp" then
		if ForeverUI.PvPDebug then
			-- /fui pvp 0.35: sets the circular gauge to 35 % without earning honor.
			ForeverUI.PvPDebug(tonumber(argument))
		else
			say(L.LAYOUT_NO_DIAG_PVP)
		end
	elseif command == "arena" then
		if ForeverUI.PvPArenaDebug then
			ForeverUI.PvPArenaDebug()
		else
			say(L.LAYOUT_NO_DIAG_ARENA)
		end
	elseif command == "tabard" then
		if ForeverUI.TabardModelTune then
			ForeverUI.TabardModelTune(argument)
		end
	elseif command == "chat" then
		if ForeverUI.ChatDebug then
			ForeverUI.ChatDebug()
		else
			say(L.LAYOUT_NO_DIAG_CHAT)
		end
	elseif command == "chatlines" then
		if ForeverUI.ChatRecordLines then
			ForeverUI.ChatRecordLines()
		else
			say(L.LAYOUT_NO_CHAT_LINES)
		end
	elseif command == "buffs" then
		if ForeverUI.BuffsDebug then
			ForeverUI.BuffsDebug()
		else
			say(L.LAYOUT_NO_DIAG_BUFFS)
		end
	elseif command == "finder" then
		if ForeverUI.GroupFinderDebug then
			ForeverUI.GroupFinderDebug()
		else
			say(L.LAYOUT_NO_DIAG_GROUPFINDER)
		end
	elseif command == "social" then
		if ForeverUI.SocialDebug then
			ForeverUI.SocialDebug()
		else
			say(L.LAYOUT_NO_DIAG_SOCIAL)
		end
	elseif command == "bg" then
		if ForeverUI.PvPBattlegroundsDebug then
			ForeverUI.PvPBattlegroundsDebug()
		else
			say(L.LAYOUT_NO_DIAG_BATTLEGROUNDS)
		end
	elseif command == "pet" then
		if ForeverUI.PetDebug then
			ForeverUI.PetDebug()
		else
			say(L.LAYOUT_NO_DIAG_PET)
		end
	elseif command == "currency" or command == "currencies" then
		if ForeverUI.TokensDebug then
			ForeverUI.TokensDebug()
		else
			say(L.LAYOUT_NO_DIAG_CURRENCY)
		end
	elseif command == "skills" then
		if ForeverUI.SkillsDebug then
			ForeverUI.SkillsDebug()
		else
			say(L.LAYOUT_NO_DIAG_SKILLS)
		end
	elseif command == "rep" then
		if ForeverUI.ReputationDebug then
			-- /fui rep Alliance: keeps only that faction.
			ForeverUI.ReputationDebug(argument ~= "" and argument or nil)
		else
			say(L.LAYOUT_NO_DIAG_REPUTATION)
		end
	elseif command == "sets" then
		if ForeverUI.EquipmentSetsDebug then
			ForeverUI.EquipmentSetsDebug()
		else
			say(L.LAYOUT_NO_DIAG_SETS)
		end
	elseif command == "debug" then
		if ForeverUI.PlayerFrameDebug then
			ForeverUI.PlayerFrameDebug()
		else
			say(L.LAYOUT_NO_DIAG)
		end
	elseif command == "list" then
		say(L.LAYOUT_LIST_HEADER)
		for _, id in ipairs(Layout.order) do
			local system = Layout.systems[id]
			local saved = positions()[id]
			DEFAULT_CHAT_FRAME:AddMessage(string.format("   %s (%s)%s", id, system.label,
				saved and L.LAYOUT_LIST_MOVED or ""))
		end
	else
		say(L.LAYOUT_HELP)
	end
end
