-- ForeverUI: the Esc menu (GameMenuFrame) in Camelot's style (MainMenuFrameTemplate: column
-- margins 48 top, 34 bottom, 28 sides; a section adds 20 above its first button).
-- The client's buttons stay, in their order: their clicks are secure (Logout, Quit) and a
-- button of ours would not be.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates

local M = {}
ForeverUI.GameMenu = M

local N = {
	top = 48, down = 34, side = 28,
	button = { 200, 36 },
	section = 20,
}

-- camelot GameFontNormalMed1: SystemFont_Med2 (FRIZQT 13), shadow (1, -1), yellow
local function headerFont()
	local f = CreateFont("ForeverUIGameMenuHeaderFont")
	f:SetFontObject(SystemFont_Med2 or GameFontNormal)
	f:SetShadowOffset(1, -1)
	f:SetShadowColor(0, 0, 0)
	f:SetTextColor(1, 0.82, 0)
	return f
end

-- buttons, top to bottom; section: a gap above the button
local function entries()
	return {
		{ GameMenuButtonOptions },
		{ GameMenuButtonSoundOptions },
		{ GameMenuButtonMacOptions },
		{ GameMenuButtonUIOptions },
		{ GameMenuButtonKeybindings },
		{ GameMenuButtonMacros },
		{ GameMenuButtonRatings },
		{ _G["GameMenuButtonAddOns"] },
		{ _G["ForeverUIGameMenuButtonCustomize"] },
		{ _G["ForeverUIGameMenuButtonHelp"], section = true },
		{ GameMenuButtonLogout, section = true },
		{ GameMenuButtonQuit },
		{ GameMenuButtonContinue, section = true },
	}
end

local FONTS = { GameFontHighlightLarge, GameFontHighlightLarge, GameFontDisableLarge }

local function skinButton(b)
	if b.foreverThreeSlice then return end
	b:SetWidth(N.button[1])
	b:SetHeight(N.button[2])
	Tpl.ThreeSliceButton(b, "128-redbutton", FONTS)
	b:HookScript("OnShow", M.Layout)
end

-- Lays out the column: each shown button in place, then the menu size.
-- Runs on every button's OnShow: ACP's AddOns button and Log Out (when Ratings is shown)
-- re-anchor Log Out in their own OnShow, after the menu.
function M.Layout()
	local f = GameMenuFrame
	local y = N.top
	local queued = false
	for _, e in ipairs(entries()) do
		local b = e[1]
		if e.section then
			queued = true
		end
		if b and b:IsShown() then
			skinButton(b)
			if queued then
				y = y + N.section
				queued = false
			end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", f, "TOPLEFT", N.side, -y)
			y = y + N.button[2]
		end
	end
	f:SetWidth(N.side + N.button[1] + N.side)
	f:SetHeight(y + N.down)
end

if GameMenuFrame then
	local f = GameMenuFrame
	f:SetBackdrop(nil)
	if GameMenuFrameHeader then
		GameMenuFrameHeader:SetAlpha(0)
	end
	-- the client's title has no name: it is the frame's MAIN_MENU text
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == MAIN_MENU then
			r:SetAlpha(0)
		end
	end
	Tpl.DialogFrame(f)
	M.header = Tpl.Header(f, MAINMENU_BUTTON, headerFont())
	for _, e in ipairs(entries()) do
		if e[1] then
			skinButton(e[1])
		end
	end
	-- a button added after us (ACP's AddOns) is skinned by the layout on first show
	f:HookScript("OnShow", M.Layout)
	M.Layout()
end
