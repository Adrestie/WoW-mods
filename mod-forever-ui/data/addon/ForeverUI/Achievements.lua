-- ForeverUI: makes the achievement window (Blizzard_AchievementUI, load-on-demand) movable.
-- camelot has no achievement UI, so the window keeps its 3.3.5 look and stays a UI panel.
-- The panel system (UpdateUIPanelPositions) re-anchors it on every panel open or close, so
-- the saved place (ForeverUIDB.positions) is applied again after it and on show.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local A = {}
ForeverUI.Achievements = A

local KEY = "achievements"

-- Saved window positions (ForeverUIDB.positions), created on first use.
local function positions()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

-- Anchors the window's top centre at its saved place, as WindowStack.lua does.
function A.Reposition()
	local f = AchievementFrame
	local p = positions()[KEY]
	if not f or not p then return end
	f:ClearAllPoints()
	f:SetPoint("TOP", UIParent, "TOP", p.x, p.y)
end

-- Makes the window movable by its header, once. No secure code, so it also works in combat.
function A.Skin()
	local f = AchievementFrame
	local handle = AchievementFrameHeader
	if not f or not handle or f.foreverMovable then return end
	f.foreverMovable = true
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", function()
		f:StartMoving()
	end)
	handle:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local cx = f:GetCenter()
		local ux = UIParent:GetCenter()
		local x, y = cx - ux, f:GetTop() - UIParent:GetTop()
		f:ClearAllPoints()
		f:SetPoint("TOP", UIParent, "TOP", x, y)
		-- we save the place ourselves: keep the client from saving it too
		if f.SetUserPlaced then f:SetUserPlaced(false) end
		positions()[KEY] = { x = x, y = y }
	end)
	f:HookScript("OnShow", A.Reposition)
	hooksecurefunc("UpdateUIPanelPositions", function()
		if f:IsShown() then A.Reposition() end
	end)
	A.Reposition()
end

A.Skin()

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(_, _, name)
	if name == "Blizzard_AchievementUI" then
		A.Skin()
	end
end)
