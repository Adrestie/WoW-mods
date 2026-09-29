-- ForeverUI: the clock window (TimeManagerFrame, loaded on demand by Blizzard_TimeManager),
-- dressed as camelot's blizzard_timemanager: ButtonFrameTemplate, globe portrait, no button bar.
-- The client's frames and logic stay. The alarm button becomes a check box: its button art is
-- cleared after each client update and a UI-CheckBox, checked by timeMgrAlarmEnabled, drawn on it.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local H = {}
ForeverUI.Clock = H

-- backslash, the texture path separator
local SEP = string.char(92)

-- Sizes and offsets from camelot's blizzard_timemanager/mainline.
local N = {
	window = { 220, 240 }, position = { -10, -190 },
	portrait = { side = 64, x = -6, y = 9 },
	title = { 15, -5 },
	inset = { 4, -60, -6, 4 },
	stopwatch = { 10, -12 },
	alarm = { 12, -65 },
	menus = { hour = 60, minute = 60, ampm = 65, gap = 5, belowLabel = -4 },
	message = { y = -5, field = 190 },
	activate = { x = 12, y = -45, side = 24, text = -2 },
	military = { 185, -190 },
}

-- Clears r's anchors and sets the given point.
local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- Places each control. Runs again after the client, which re-anchors the AM / PM menu and
-- what follows it (TimeManagerAlarmAMPMDropDown_OnShow / _OnHide).
function H.Place()
	local f = TimeManagerFrame
	local M = N.menus
	place(TimeManagerStopwatchFrame, "TOPRIGHT", f, "TOPRIGHT", N.stopwatch[1], N.stopwatch[2])
	place(TimeManagerAlarmTimeFrame, "TOPLEFT", f, "TOPLEFT", N.alarm[1], N.alarm[2])
	place(TimeManagerAlarmHourDropDown, "TOPLEFT", TimeManagerAlarmTimeLabel, "BOTTOMLEFT", 0, M.belowLabel)
	place(TimeManagerAlarmMinuteDropDown, "LEFT", TimeManagerAlarmHourDropDown, "RIGHT", M.gap, 0)
	place(TimeManagerAlarmAMPMDropDown, "LEFT", TimeManagerAlarmMinuteDropDown, "RIGHT", M.gap, 0)
	place(TimeManagerAlarmMessageFrame, "TOPLEFT", TimeManagerAlarmHourDropDown, "BOTTOMLEFT", 0, N.message.y)
	place(TimeManagerAlarmEnabledButton, "LEFT", f, "LEFT", N.activate.x, N.activate.y)
	place(TimeManagerMilitaryTimeCheck, "TOPLEFT", f, "TOPLEFT", N.military[1], N.military[2])
end

-- Alarm check box, after TimeManagerAlarmEnabledButton_Update: clears the button art the
-- client just set; the check mark follows the setting.
function H.PaintAlarm()
	local b = TimeManagerAlarmEnabledButton
	if not b or not b.foreverCell then return end
	for _, read in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
		local t = b[read](b)
		if t then
			t:SetTexture(nil)
			t:SetAlpha(0)
		end
	end
	b:SetNormalFontObject(GameFontNormalSmall)
	b:SetHighlightFontObject(GameFontNormalSmall)
	b:SetText(TIMEMANAGER_ALARM_ENABLED)
	Tpl.SetShown(b.foreverCheck, GetCVar("timeMgrAlarmEnabled") == "1")
end

-- Turns the alarm button into a check box.
local function skinAlarm()
	local b = TimeManagerAlarmEnabledButton
	local A = N.activate
	b:SetWidth(A.side)
	b:SetHeight(A.side)
	local checkbox = b:CreateTexture(nil, "ARTWORK")
	checkbox:SetTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-CheckBox-Up")
	checkbox:SetAllPoints(b)
	local checkMark = b:CreateTexture(nil, "OVERLAY")
	checkMark:SetTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-CheckBox-Check")
	checkMark:SetAllPoints(b)
	b.foreverCell, b.foreverCheck = checkbox, checkMark
	b:SetHighlightTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-CheckBox-Highlight")
	local glow = b:GetHighlightTexture()
	glow:SetTexCoord(0, 1, 0, 1)
	glow:ClearAllPoints()
	glow:SetAllPoints(b)
	glow:SetBlendMode("ADD")
	b:HookScript("OnMouseDown", function()
		checkbox:SetTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-CheckBox-Down")
	end)
	b:HookScript("OnMouseUp", function()
		checkbox:SetTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-CheckBox-Up")
	end)
	local text = b:GetFontString()
	if text then
		place(text, "LEFT", b, "RIGHT", A.text, 0)
	end
	hooksecurefunc("TimeManagerAlarmEnabledButton_Update", H.PaintAlarm)
	H.PaintAlarm()
end

-- Dresses TimeManagerFrame once, when Blizzard_TimeManager is loaded.
function H.Skin()
	local f = TimeManagerFrame
	if not f or f.foreverSkin then return end
	f:SetWidth(N.window[1])
	f:SetHeight(N.window[2])
	place(f, "TOPRIGHT", UIParent, "TOPRIGHT", N.position[1], N.position[2])
	-- hide the 3.3.5 art: the four unnamed pieces, the unnamed title, the globe (redrawn as the
	-- portrait), the stopwatch background
	for _, r in ipairs({ f:GetRegions() }) do
		local kind = r:GetObjectType()
		if kind == "Texture" then
			r:SetAlpha(0)
		elseif kind == "FontString" and r:GetText() == TIMEMANAGER_TITLE then
			r:SetAlpha(0)
		end
	end
	place(TimeManagerGlobe, "TOPLEFT", f, "TOPLEFT", N.portrait.x, N.portrait.y)
	TimeManagerStopwatchFrameBackground:SetAlpha(0)
	local skin = Tpl.PortraitWindow(f, {
		portrait = "Interface" .. SEP .. "TimeManager" .. SEP .. "GlobeIcon",
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = TIMEMANAGER_TITLE,
	})
	f.foreverSkin = skin
	skin.title:SetFontObject(GameFontWhite)
	place(skin.title, "TOP", f, "TOP", N.title[1], N.title[2])
	-- the time, above the globe and the metal
	skin.hour = Tpl.Mirror(TimeManagerFrameTicker, skin.metal, GameFontHighlightLarge)
	-- the inset, without a button bar
	local E = N.inset
	local rect = CreateFrame("Frame", nil, f)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", E[1], E[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", E[3], E[4])
	local marble = f:CreateTexture(nil, "BACKGROUND")
	marble:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble", true)
	if marble.SetHorizTile then marble:SetHorizTile(true) marble:SetVertTile(true) end
	marble:SetAllPoints(rect)
	skin.frameBox = Tpl.NineSlice(f, "InsetFrameTemplate", rect)
	skin.marble = marble
	-- close button, above the metal
	Tpl.CloseButton(TimeManagerCloseButton, f)
	TimeManagerCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	-- the three menus and the message field
	local M = N.menus
	Tpl.MenuStyle1(TimeManagerAlarmHourDropDown, M.hour)
	Tpl.MenuStyle1(TimeManagerAlarmMinuteDropDown, M.minute)
	Tpl.MenuStyle1(TimeManagerAlarmAMPMDropDown, M.ampm)
	TimeManagerAlarmMessageEditBox:SetWidth(N.message.field)
	ForeverUI.Social.skinInput(TimeManagerAlarmMessageEditBox)
	skinAlarm()
	H.Place()
	f:HookScript("OnShow", H.Place)
	TimeManagerAlarmAMPMDropDown:HookScript("OnShow", H.Place)
	TimeManagerAlarmAMPMDropDown:HookScript("OnHide", H.Place)
end

H.Skin()

local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:SetScript("OnEvent", function(_, _, name)
	if name == "Blizzard_TimeManager" then
		H.Skin()
	end
end)
