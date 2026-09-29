-- ForeverUI: realm list in the camelot style. camelot has none (it picks a region by cards), so
-- the 3.3.5 list keeps its places, sizes and logic inside a camelot window (ButtonFrameTemplate
-- without portrait, as its AddOns list). The client keeps its buttons, offset and sort; art and
-- fonts are re-applied after RealmListUpdate and RealmList_UpdateTabs.

local G = ForeverUIGlue

local background = RealmListBackground
local ROWS = 18                -- client MAX_REALMS_DISPLAYED
local ROW_HEIGHT = 16         -- client REALM_BUTTON_HEIGHT

-- camelot font replacing a client font, when camelot has one
local function camelotFont(object)
	local name = object and object.GetName and object:GetName()
	if not name or string.find(name, "^ForeverUIGlue_") then
		return nil
	end
	return _G["ForeverUIGlue_" .. name]
end

-- ------------------------------------------------------------ Window

-- Client art: HelpFrame-* border, header and its title
for _, r in ipairs({ background:GetRegions() }) do
	local texture = r:GetObjectType() == "Texture" and string.lower(r:GetTexture() or "")
	if (texture and string.find(texture, "helpframe", 1, true))
		or (r:GetObjectType() == "FontString" and r:GetText() == SERVER_SELECTION) then
		r:SetAlpha(0)
		r:Hide()
	end
end
RealmListHeader:SetAlpha(0)
RealmListHeader:Hide()

-- The window covers the client list: its width holds the selection bar (up to 22 + 587 from
-- the edge, GlueScrollFrame_Update) inside the inset (6 from the right edge). It sits at the
-- client background level, so the client buttons, list and tabs draw in front.
local window = CreateFrame("Frame", "ForeverUIRealmListWindow", RealmList)
window:SetFrameLevel(background:GetFrameLevel())
window:SetPoint("TOPLEFT", background, "TOPLEFT", 0, 0)
window:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", -22, 0)
G.Window(window, SERVER_SELECTION, true)

-- Inset: 9 from the left edge (no portrait), 6 from the right, 26 from the bottom; its top is
-- below the column headers (their bottom is 50 below the top).
local inset = CreateFrame("Frame", nil, window)
inset:SetPoint("TOPLEFT", window, "TOPLEFT", 9, -52)
inset:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -6, 26)
G.Inset(window, inset, true)

-- ------------------------------------------------------------ Columns

for _, name in ipairs({ "RealmNameSort", "RealmTypeSort", "RealmCharactersSort", "RealmLoadSort" }) do
	_G[name]:SetNormalFontObject(G.Font("GlueFontHighlightSmall"))
end

-- ------------------------------------------------------------ Tabs

local function place(t, atlas, point, x)
	G.PlaceAtlas(t, atlas, true)
	t:ClearAllPoints()
	t:SetPoint(point, t:GetParent(), point, x, 0)
end

-- Skins a realm category tab (RealmListTabButtonTemplate) with the camelot tab art.
local function skinTab(tab)
	local name = tab:GetName()
	if not tab.foreverTab then
		tab.foreverTab = true
		-- Normal: uiframe-tab-*
		local g, d, m = _G[name .. "Left"], _G[name .. "Right"], _G[name .. "Middle"]
		place(g, "uiframe-tab-left", "TOPLEFT", -3)
		place(d, "uiframe-tab-right", "TOPRIGHT", 7)
		G.PlaceAtlas(m, "_uiframe-tab-center", true)
		m:ClearAllPoints()
		m:SetPoint("LEFT", g, "RIGHT")
		m:SetPoint("RIGHT", d, "LEFT")
		-- Selected: uiframe-activetab-*
		local ga, da, ma = _G[name .. "LeftDisabled"], _G[name .. "RightDisabled"], _G[name .. "MiddleDisabled"]
		place(ga, "uiframe-activetab-left", "TOPLEFT", -1)
		place(da, "uiframe-activetab-right", "TOPRIGHT", 8)
		G.PlaceAtlas(ma, "_uiframe-activetab-center", true)
		ma:ClearAllPoints()
		ma:SetPoint("LEFT", ga, "RIGHT")
		ma:SetPoint("RIGHT", da, "LEFT")
		-- Hover: the tab art in ADD at 0.4 (HIGHLIGHT layer)
		local h = tab:GetHighlightTexture()
		if h then
			h:SetTexture(nil)
			h:SetAlpha(0)
		end
		local topLeft = tab:CreateTexture(nil, "HIGHLIGHT")
		G.PlaceAtlas(topLeft, "uiframe-tab-left", true)
		topLeft:SetPoint("TOPLEFT", g, "TOPLEFT")
		local topRight = tab:CreateTexture(nil, "HIGHLIGHT")
		G.PlaceAtlas(topRight, "uiframe-tab-right", true)
		topRight:SetPoint("TOPRIGHT", d, "TOPRIGHT")
		local hm = tab:CreateTexture(nil, "HIGHLIGHT")
		G.PlaceAtlas(hm, "_uiframe-tab-center", true)
		hm:SetPoint("LEFT", m, "LEFT")
		hm:SetPoint("RIGHT", m, "RIGHT")
		for _, t in ipairs({ topLeft, topRight, hm }) do
			t:SetBlendMode("ADD")
			t:SetAlpha(0.4)
		end
		tab:SetNormalFontObject(G.Font("GlueFontNormalSmall"))
		tab:SetHighlightFontObject(G.Font("GlueFontHighlightSmall"))
	end
	-- RealmList_UpdateTabs resets the disabled tab font on every pass
	tab:SetDisabledFontObject(G.Font(tab.disabled and "GlueFontDisableSmall" or "GlueFontHighlightSmall"))
end

G.HookFunction("RealmList_UpdateTabs", function()
	for i = 1, MAX_REALM_CATEGORY_TABS or 8 do
		local tab = _G["RealmListTab" .. i]
		if tab then
			skinTab(tab)
		end
	end
end)
skinTab(RealmListTab1)

-- ------------------------------------------------------------ Close button

G.WindowCloseButton(RealmListCloseButton, window)

-- ------------------------------------------------------------ Cancel / OK

-- SharedButtonSmallTemplate in the bottom bar: client width (125), camelot height (22);
-- Cancel at (-4, 4), OK against its left side.
for _, b in ipairs({ RealmListCancelButton, RealmListOkButton }) do
	b:SetWidth(125)
	b:SetHeight(22)
	G.ThreeSliceButton(b, "128-RedButton", { "GameFontNormal", "GameFontHighlight", "GameFontDisable" })
end
RealmListCancelButton:ClearAllPoints()
RealmListCancelButton:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -4, 4)
RealmListOkButton:ClearAllPoints()
RealmListOkButton:SetPoint("TOPRIGHT", RealmListCancelButton, "TOPLEFT", 0, 0)

-- ------------------------------------------------------------ Rows

for i = 1, ROWS do
	local b = _G["RealmListRealmButton" .. i]
	b:SetDisabledFontObject(G.Font("GlueFontDisableLeft"))
	_G[b:GetName() .. "PVP"]:SetFontObject(G.Font("GlueFontRedSmall"))
	_G[b:GetName() .. "Players"]:SetFontObject(G.Font("GlueFontHighlightSmall"))
	_G[b:GetName() .. "Load"]:SetFontObject(G.Font("GlueFontHighlightSmall"))
end

-- ------------------------------------------------------------ Scroll bar

-- The client bar (GlueScrollFrameTemplate) still does the scrolling (wheel and offset go
-- through it) but is hidden.
local clientBar = RealmListScrollFrameScrollBar
clientBar:SetAlpha(0)
clientBar:EnableMouse(false)
for _, child in ipairs({ clientBar:GetChildren() }) do
	child:EnableMouse(false)
end
for _, name in ipairs({ "ScrollBarTop", "ScrollBarMiddle", "ScrollBarBottom" }) do
	local t = _G["RealmListScrollFrame" .. name]
	if t then
		t:SetAlpha(0)
	end
end

-- MinimalScrollBar, placed as in camelot addonlist.xml: right edge 16 inside the inset; top 3
-- below the inset top; bottom 4 above the client list bottom (27 above the inset bottom).
local bar = G.MinimalBar(background, "ForeverUIRealmListScrollBar")
bar:SetPoint("TOPRIGHT", inset, "TOPRIGHT", -16, -3)
bar:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -16, 27)
bar.step = ROW_HEIGHT
bar.onScroll = function(position)
	clientBar:SetValue(position)
end

-- The bar shows only when needed. Without it, the content keeps on the right of the inset
-- (9 .. 612) the margin it has on the left: selection bar 577 (the client uses 587), headers
-- up to 600, so the last column grows 138 -> 176 and each row's load 110 -> 148. With the bar,
-- the client widths.
bar.hideIfUnneeded = true
local REALM = { choice = { 557, 577 }, load = { 138, 176 }, rowLoad = { 110, 148 } }
local function adjustForBar()
	local k = bar:IsShown() and 1 or 2
	RealmListHighlight:SetWidth(REALM.choice[k])
	RealmLoadSort:SetWidth(REALM.load[k])
	for i = 1, ROWS do
		local t = _G["RealmListRealmButton" .. i .. "Load"]
		if t then t:SetWidth(REALM.rowLoad[k]) end
	end
end

-- ------------------------------------------------------------ After the client

G.HookFunction("RealmListUpdate", function()
	for i = 1, ROWS do
		local b = _G["RealmListRealmButton" .. i]
		local n = camelotFont(b:GetNormalFontObject())
		if n then
			b:SetNormalFontObject(n)
		end
		local h = camelotFont(b:GetHighlightFontObject())
		if h then
			b:SetHighlightFontObject(h)
		end
	end
	local total = GetNumRealms(RealmList.selectedCategory or 1) or 0
	bar:Configure(total * ROW_HEIGHT, ROWS * ROW_HEIGHT, (RealmList.offset or 0) * ROW_HEIGHT)
	-- After GlueScrollFrame_Update, which set the selection bar to 557 / 587
	adjustForBar()
end)
