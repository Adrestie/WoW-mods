-- ForeverUI: tooltips in camelot's style (SharedTooltipTemplate, TooltipDefaultLayout).
-- The <Backdrop> of the client templates is replaced by a nine-slice made of the tooltip's
-- own regions (a child frame would cover the lines), stretched rather than tiled (3.3.5 tiles
-- only whole images). SetBackdropColor/SetBackdropBorderColor tint the pieces; a new backdrop
-- hides them. Compare tooltips get camelot's CompareHeader; 3.3.5 has no EQUIPPED string, so
-- it shows CURRENTLY_EQUIPPED, moved from the tooltip's first line.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local T = {}
ForeverUI.Tooltips = T

local SEP = string.char(92)
local CLIENT_EDGE = string.lower("Interface" .. SEP .. "Tooltips" .. SEP .. "UI-Tooltip-Border")

-- TooltipDefaultLayout, in nineSliceSetup's order and anchors:
-- name, atlas, point (for an edge: opposite point and its two corners)
local PIECES = {
	{ "TopLeftCorner", "tooltip-nineslice-cornertopleft", "TOPLEFT" },
	{ "TopRightCorner", "tooltip-nineslice-cornertopright", "TOPRIGHT" },
	{ "BottomLeftCorner", "tooltip-nineslice-cornerbottomleft", "BOTTOMLEFT" },
	{ "BottomRightCorner", "tooltip-nineslice-cornerbottomright", "BOTTOMRIGHT" },
	{ "TopEdge", "_tooltip-nineslice-edgetop", "TOPLEFT", "TOPRIGHT", "TopLeftCorner", "TopRightCorner" },
	{ "BottomEdge", "_tooltip-nineslice-edgebottom", "BOTTOMLEFT", "BOTTOMRIGHT", "BottomLeftCorner", "BottomRightCorner" },
	{ "LeftEdge", "!tooltip-nineslice-edgeleft", "TOPLEFT", "BOTTOMLEFT", "TopLeftCorner", "BottomLeftCorner" },
	{ "RightEdge", "!tooltip-nineslice-edgeright", "TOPRIGHT", "BOTTOMRIGHT", "TopRightCorner", "BottomRightCorner" },
}
local CENTER = { atlas = "tooltip-nineslice-center", x = -4, y = 4, x1 = 4, y1 = -4 }

-- SharedTooltip_OnLoad
local SCREEN_INSETS = { 0, 0, 25, 0 }

-- CompareHeader
local HEADER = { width = 100, height = 22, y = -1, margin = 30, atlas = "tooltip-compare-label" }

-- UIPanelCloseButtonNoScripts, at ItemRefTooltip's TOPRIGHT (2, 2)
local CLOSE_BUTTON = { side = 24, x = 2, y = 2 }

-- client tooltip frames that are not GameTooltips
local TOOLTIP_FRAMES = { "FriendsTooltip", "PartyMemberBuffTooltip", "SmallTextTooltip" }

-- tooltips embedded in a window (IsEmbedded): left alone
local EXCLUDED = { ItemSocketingDescription = true }

-- true if the frame has the backdrop set by the client templates
local function hasClientBackground(f)
	local background = f.GetBackdrop and f:GetBackdrop()
	local edge = background and background.edgeFile
	return type(edge) == "string" and string.lower(string.gsub(edge, "/", SEP)) == CLIENT_EDGE
end

-- center: true tints the center (SetCenterColor), false the eight other pieces
-- (SetBorderColor)
local function applyTint(tooltipFrame, center, r, g, b, a)
	local p = tooltipFrame.foreverNineSlice
	if not p or not r then return end
	for name, t in pairs(p) do
		if (name == "Center") == center then
			t:SetVertexColor(r, g, b, a or 1)
		end
	end
end

-- Replaces the 3.3.5 backdrop with camelot's nine-slice. Returns the pieces by name.
function T.Skin(tooltipFrame)
	if not tooltipFrame or tooltipFrame.foreverNineSlice then return tooltipFrame and tooltipFrame.foreverNineSlice end
	tooltipFrame:SetBackdrop(nil)

	local p = {}
	for _, m in ipairs(PIECES) do
		local t = tooltipFrame:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(t, m[2])
		if m[4] then
			t:SetPoint(m[3], p[m[5]], m[4], 0, 0)
			t:SetPoint(m[4], p[m[6]], m[3], 0, 0)
		else
			t:SetPoint(m[3], tooltipFrame, m[3], 0, 0)
		end
		p[m[1]] = t
	end
	local c = tooltipFrame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(c, CENTER.atlas)
	c:SetPoint("TOPLEFT", p.TopLeftCorner, "BOTTOMRIGHT", CENTER.x, CENTER.y)
	c:SetPoint("BOTTOMRIGHT", p.BottomRightCorner, "TOPLEFT", CENTER.x1, CENTER.y1)
	p.Center = c
	tooltipFrame.foreverNineSlice = p

	local background, edge = TOOLTIP_DEFAULT_BACKGROUND_COLOR, TOOLTIP_DEFAULT_COLOR
	applyTint(tooltipFrame, true, background.r, background.g, background.b, 1)
	applyTint(tooltipFrame, false, edge.r, edge.g, edge.b, 1)
	hooksecurefunc(tooltipFrame, "SetBackdropColor", function(self, r, g, b, a)
		applyTint(self, true, r, g, b, a)
	end)
	hooksecurefunc(tooltipFrame, "SetBackdropBorderColor", function(self, r, g, b, a)
		applyTint(self, false, r, g, b, a)
	end)
	hooksecurefunc(tooltipFrame, "SetBackdrop", function(self, other)
		for _, t in pairs(self.foreverNineSlice) do
			if other then t:Hide() else t:Show() end
		end
	end)

	if tooltipFrame:GetObjectType() == "GameTooltip" then
		tooltipFrame:SetClampRectInsets(SCREEN_INSETS[1], SCREEN_INSETS[2], SCREEN_INSETS[3], SCREEN_INSETS[4])
	end
	return p
end

-- Skins every tooltip made on the client templates, including those of addons loaded later.
function T.Scan()
	local f = EnumerateFrames()
	while f do
		if not f.foreverNineSlice and f:GetObjectType() == "GameTooltip"
			and not EXCLUDED[f:GetName() or ""] and hasClientBackground(f) then
			T.Skin(f)
		end
		f = EnumerateFrames(f)
	end
end

-- ------------------------------------------------------------ Comparison

-- camelot's CompareHeader of a compare tooltip, created once
local function header(tooltipFrame)
	local h = tooltipFrame.foreverHeader
	if h then return h end
	h = CreateFrame("Frame", nil, tooltipFrame)
	h:SetWidth(HEADER.width)
	h:SetHeight(HEADER.height)
	h:SetPoint("BOTTOMLEFT", tooltipFrame, "TOPLEFT", 0, HEADER.y)
	local background = h:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, HEADER.atlas, true)
	background:SetAllPoints(h)
	local label = h:CreateFontString(nil, "ARTWORK", "GameTooltipText")
	label:SetPoint("CENTER", h, "CENTER", 0, 0)
	label:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	h.Label = label
	h:Hide()
	tooltipFrame.foreverHeader = h
	-- camelot: OnTooltipCleared hides CompareHeader
	tooltipFrame:HookScript("OnTooltipCleared", function(self)
		self.foreverHeader:Hide()
	end)
	return h
end

-- Runs after the client: moves the "Currently Equipped" first line into the header.
-- mainTooltip: the tooltip being compared (GameTooltip by default).
function T.Compare(mainTooltip)
	mainTooltip = mainTooltip or GameTooltip
	local list = mainTooltip and mainTooltip.shoppingTooltips
	if not list or not CURRENTLY_EQUIPPED then return end
	for _, tooltipFrame in ipairs(list) do
		local name = tooltipFrame:GetName()
		local row = name and _G[name .. "TextLeft1"]
		if tooltipFrame:IsShown() and row and row:GetText() == CURRENTLY_EQUIPPED then
			T.Skin(tooltipFrame)
			local h = header(tooltipFrame)
			h.Label:SetText(CURRENTLY_EQUIPPED)
			h:SetWidth(h.Label:GetStringWidth() + HEADER.margin)
			h:SetFrameLevel(math.max(tooltipFrame:GetFrameLevel() - 1, 0))
			h:Show()
			row:SetText("")
			-- the client recomputes the tooltip's size on Show
			tooltipFrame:Show()
		end
	end
end

-- ------------------------------------------------------------ Close button

local function skinCloseButton(b)
	if not b or b.foreverCloseButton then return end
	b:SetWidth(CLOSE_BUTTON.side)
	b:SetHeight(CLOSE_BUTTON.side)
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", b:GetParent(), "TOPRIGHT", CLOSE_BUTTON.x, CLOSE_BUTTON.y)
	for _, state in ipairs({ { "GetNormalTexture", "redbutton-exit" },
		{ "GetPushedTexture", "redbutton-exit-pressed" },
		{ "GetHighlightTexture", "redbutton-highlight" } }) do
		local t = b[state[1]] and b[state[1]](b)
		if t then
			ForeverUI.SetAtlas(t, state[2], true)
			t:ClearAllPoints()
			t:SetAllPoints(b)
			if state[2] == "redbutton-highlight" then t:SetBlendMode("ADD") end
		end
	end
	b.foreverCloseButton = true
end

-- ------------------------------------------------------------ Setup

for _, name in ipairs(TOOLTIP_FRAMES) do
	local f = _G[name]
	if f and hasClientBackground(f) then
		T.Skin(f)
	end
end
T.Scan()
skinCloseButton(ItemRefCloseButton)
hooksecurefunc("GameTooltip_ShowCompareItem", T.Compare)

-- addons loaded later (Blizzard_DebugTools...) and those creating tooltips at login
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("ADDON_LOADED")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:SetScript("OnEvent", function()
	T.Scan()
end)
T.watcher = watcher
