-- ForeverUI: the guild tabard window in camelot's style (camelot: mainline/tabardframe.xml).
-- The client's TabardFrame and TabardModel are kept, resized, re-anchored and re-skinned; none
-- of their frames changes parent. The merchant portrait sits inside the metal ring, as in the
-- Social window. In 3.3.5 two frames at the same level draw in an undefined order, so the
-- insets and the gold edge are regions of the window itself (BACKGROUND, BORDER, ARTWORK),
-- under the tabard frame and the emblem (OVERLAY). Empty frames serve as anchors.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local L = ForeverUI.L

local SEP = string.char(92)

local P = {
	width = 338, height = 424,
	rock = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock",
	money = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP .. "moneyframe",
	portraitSide = 60, portraitX = -5, portraitY = 7,
	closeButton = 24, closeButtonX = -2, closeButtonY = 1,
}

local METAL = {
	{ key = "topLeft", name = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ key = "topRight", name = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
	{ key = "bottomLeft", name = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ key = "bottomRight", name = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}

-- camelot anchors: { region, point, relative frame, relative point, x, y }
local ANCHORS = {
	{ "TabardFrameOuterFrameTopLeft", "TOPLEFT", "TabardFrame", "TOPLEFT", 8, -63 },
	{ "TabardFrameGreetingText", "TOP", "TabardFrame", "TOP", 15, -28 },
	-- model: left half of the inset (see model framing below), camelot's bottom offset
	{ "TabardModel", "BOTTOMLEFT", "TabardFrame", "BOTTOMLEFT", 4, 38 },
	{ "TabardCharacterModelRotateLeftButton", "BOTTOMLEFT", "TabardFrame", "BOTTOMLEFT", 14, 33 },
	{ "TabardFrameCustomizationBorder", "BOTTOMRIGHT", "TabardFrame", "BOTTOMRIGHT", 26, -28 },
	{ "TabardFrameMoneyFrame", "BOTTOMRIGHT", "TabardFrame", "BOTTOMLEFT", 175, 8 },
	{ "TabardFrameAcceptButton", "CENTER", "TabardFrame", "TOPLEFT", 213, -409 },
	{ "TabardFrameCancelButton", "CENTER", "TabardFrame", "TOPLEFT", 294, -409 },
}
-- model width: left half of the inset, from 4 to the customization panel (154); its height
-- stays the client's (317)
local MODEL_WIDTH = 150

local T = {}
ForeverUI.TabardFrame = T

-- ButtonFrameTemplate shell (same values as the Social window)
local function wrap(f)
	local rock = f:CreateTexture(nil, "BACKGROUND")
	rock:SetTexture(P.rock, true)
	if rock.SetHorizTile then rock:SetHorizTile(true) rock:SetVertTile(true) end
	rock:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -21)
	rock:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
	T.rock = rock

	local stripes = f:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(stripes, "_ui-frame-toptilestreaks", true)
	stripes:SetHeight(43)
	stripes:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -21)
	stripes:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -21)

	local metal = CreateFrame("Frame", nil, f)
	metal:SetAllPoints(f)
	metal:SetFrameLevel(f:GetFrameLevel() + 20)
	local c = {}
	for _, corner in ipairs(METAL) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, corner.name)
		t:SetPoint(corner.point, metal, corner.point, corner.x, corner.y)
		c[corner.key] = t
	end
	local function edge(name, a1, c1, r1, a2, c2, r2)
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, name)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
	end
	edge("_ui-frame-metal-edgetop", "TOPLEFT", c.topLeft, "TOPRIGHT", "TOPRIGHT", c.topRight, "TOPLEFT")
	edge("_ui-frame-metal-edgebottom", "BOTTOMLEFT", c.bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", c.bottomRight, "BOTTOMLEFT")
	edge("!ui-frame-metal-edgeleft", "TOPLEFT", c.topLeft, "BOTTOMLEFT", "BOTTOMLEFT", c.bottomLeft, "TOPLEFT")
	edge("!ui-frame-metal-edgeright", "TOPRIGHT", c.topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", c.bottomRight, "TOPRIGHT")
	T.metal = metal

	-- merchant portrait, inside the ring
	local portraitFrame = CreateFrame("Frame", nil, f)
	portraitFrame:SetAllPoints(f)
	portraitFrame:SetFrameLevel(f:GetFrameLevel() + 19)
	T.portrait = portraitFrame:CreateTexture(nil, "OVERLAY")
	T.portrait:SetWidth(P.portraitSide)
	T.portrait:SetHeight(P.portraitSide)
	T.portrait:SetPoint("TOPLEFT", f, "TOPLEFT", P.portraitX, P.portraitY)

	-- merchant name, above the metal (TabardFrame_OnEvent fills the client text on open)
	local banner = CreateFrame("Frame", nil, f)
	banner:SetAllPoints(f)
	banner:SetFrameLevel(f:GetFrameLevel() + 21)
	T.name = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	T.name:SetWidth(109)
	T.name:SetHeight(16)
	T.name:SetPoint("CENTER", f, "CENTER", 6, 202)
end

-- client close button, skinned as camelot's red button
local function skinCloseButton(closeButton, f)
	closeButton:ClearAllPoints()
	closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", P.closeButtonX, P.closeButtonY)
	closeButton:SetWidth(P.closeButton)
	closeButton:SetHeight(P.closeButton)
	closeButton:SetFrameLevel(f:GetFrameLevel() + 22)
	for _, state in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		local e = ForeverUI.AtlasEntry(state[3])
		closeButton[state[1]](closeButton, e and e[1] or "")
		local t = closeButton[state[2]](closeButton)
		if t then
			ForeverUI.SetAtlas(t, state[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(closeButton)
			if state[3] == "redbutton-highlight" then t:SetBlendMode("ADD") end
		end
	end
end

-- Empty frame used only for geometry.
local function createGuideFrame(f, name)
	local r = CreateFrame("Frame", name, f)
	r:EnableMouse(false)
	return r
end

-- InsetFrameTemplate (same art as ForeverUI.DecorateInset), drawn as regions of f over the
-- guide frame r
local MARBLE = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble"
local function drawFrameBox(f, r)
	local background = f:CreateTexture(nil, "BORDER")
	background:SetTexture(MARBLE, true)
	if background.SetHorizTile then background:SetHorizTile(true) background:SetVertTile(true) end
	background:SetAllPoints(r)
	r.background = background
	local function corner(atlas, point, y)
		local t = f:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(t, atlas)
		t:SetPoint(point, r, point, 0, y or 0)
		return t
	end
	local topLeft = corner("ui-frame-innertopleft", "TOPLEFT")
	local topRight = corner("ui-frame-innertopright", "TOPRIGHT")
	local bottomLeft = corner("ui-frame-innerbotleftcorner", "BOTTOMLEFT", -1)
	local bottomRight = corner("ui-frame-innerbotright", "BOTTOMRIGHT", -1)
	local function edge(atlas, a1, c1, r1, a2, c2, r2)
		local t = f:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
		return t
	end
	edge("_ui-frame-innertoptile", "TOPLEFT", topLeft, "TOPRIGHT", "TOPRIGHT", topRight, "TOPLEFT"):SetHeight(3)
	edge("_ui-frame-innerbottile", "BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", bottomRight, "BOTTOMLEFT"):SetHeight(3)
	edge("!ui-frame-innerlefttile", "TOPLEFT", topLeft, "BOTTOMLEFT", "BOTTOMLEFT", bottomLeft, "TOPLEFT"):SetWidth(3)
	edge("!ui-frame-innerrighttile", "TOPRIGHT", topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", bottomRight, "TOPRIGHT"):SetWidth(3)
end

-- Money area: inset and gold edge (ThinGoldEdgeTemplate, three pieces)
local function skinMoney(f)
	local frameBox = createGuideFrame(f, "ForeverUITabardMoneyInset")
	frameBox:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 4, 4)
	frameBox:SetPoint("TOPRIGHT", f, "BOTTOMLEFT", 170, 25)
	drawFrameBox(f, frameBox)
	T.moneyFrameBox = frameBox

	local edge = createGuideFrame(f, "ForeverUITabardMoneyBg")
	edge:SetPoint("TOPRIGHT", f, "BOTTOMLEFT", 166, 24)
	edge:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 7, 6)
	edge.pieces = {}
	local function piece(u1, u2, v1, v2)
		local t = f:CreateTexture(nil, "ARTWORK")
		table.insert(edge.pieces, t)
		t:SetTexture(P.money)
		t:SetTexCoord(u1, u2, v1, v2)
		return t
	end
	local g = piece(0.953125, 0.9921875, 0, 0.296875)
	g:SetWidth(7)
	g:SetPoint("TOPLEFT", edge, "TOPLEFT")
	g:SetPoint("BOTTOMLEFT", edge, "BOTTOMLEFT")
	local d = piece(0, 0.0546875, 0, 0.296875)
	d:SetWidth(7)
	d:SetPoint("TOPRIGHT", edge, "TOPRIGHT")
	d:SetPoint("BOTTOMRIGHT", edge, "BOTTOMRIGHT")
	local m = piece(0, 0.9921875, 0.3125, 0.609375)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	T.moneyBorder = edge
end

function T.applySkin()
	local f = TabardFrame
	if not f or f.foreverSkinApplied then return end
	f.foreverSkinApplied = true
	f:SetWidth(P.width)
	f:SetHeight(P.height)
	f:SetHitRectInsets(0, 0, 0, 0)

	-- gone in camelot: the WotLK frame and its large background
	for _, r in ipairs({ f:GetRegions() }) do
		if r.GetTexture and r:GetObjectType() == "Texture" then
			local path = string.lower(tostring(r:GetTexture() or ""))
			if string.find(path, "ui-character-general", 1, true) or string.find(path, "ui-classtrainer-bot", 1, true) then
				r:Hide()
			end
		end
	end
	if TabardFrameBackground then TabardFrameBackground:Hide() end
	if TabardFramePortrait then TabardFramePortrait:Hide() end
	if TabardFrameNameText then TabardFrameNameText:Hide() end

	wrap(f)
	local frameBox = createGuideFrame(f, "ForeverUITabardInset")
	frameBox:SetPoint("TOPLEFT", f, "TOPLEFT", 4, -60)
	frameBox:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 26)
	drawFrameBox(f, frameBox)
	T.frameBox = frameBox
	skinMoney(f)
	if TabardFrameCloseButton then skinCloseButton(TabardFrameCloseButton, f) end

	for _, p in ipairs(ANCHORS) do
		local r = _G[p[1]]
		if r then
			r:ClearAllPoints()
			r:SetPoint(p[2], _G[p[3]], p[4], p[5], p[6])
		end
	end
	if TabardModel then TabardModel:SetWidth(MODEL_WIDTH) end
end

-- Model framing. The client offers SetCamera, SetPosition(depth, lateral, height) and
-- SetModelScale; the engine resets them after SetUnit, so they are re-applied every frame for
-- 1.5 s after opening, as for the character sheet. Camera 0 is the portrait camera (it aims
-- at the face, drawn bottom left); camera 1 is the per-race full-body camera, which centers
-- the whole character whatever its size. No position offset: the model frame itself takes
-- the left half of the inset.
local SETTING = { camera = 1, position = { 0, 0, 0 }, scale = nil }
T.setting = { camera = SETTING.camera, position = SETTING.position, scale = SETTING.scale }
local CATCHUP = 1.5

local function applySetting()
	local m = TabardModel
	if not m then return end
	local r = T.setting
	if r.camera and m.SetCamera then m:SetCamera(r.camera) end
	if r.scale and m.SetModelScale then m:SetModelScale(r.scale) end
	if r.position and m.SetPosition then m:SetPosition(r.position[1], r.position[2], r.position[3]) end
end
T.applySetting = applySetting

local recheck = CreateFrame("Frame")
recheck:Hide()
recheck.rest = 0
recheck:SetScript("OnUpdate", function(self, elapsed)
	applySetting()
	self.rest = self.rest - (elapsed or 0)
	if self.rest <= 0 then self:Hide() end
end)
T.recheck = recheck

-- Re-apply the model setting every frame for CATCHUP seconds.
local function catchUp()
	recheck.rest = CATCHUP
	recheck:Show()
end

-- Tune the tabard model from chat:
--   /fui tabard                      print the model state
--   /fui tabard camera <n>           SetCamera
--   /fui tabard scale <s>            SetModelScale
--   /fui tabard position <x> <y> <z> SetPosition(depth, lateral, height)
--   /fui tabard default              restore the default setting
--   /fui tabard client               give the model back to the client (no setting)
function ForeverUI.TabardModelTune(argument)
	local say = function(text) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. text) end
	local m = TabardModel
	if not m then return end
	local key, rest = string.match(argument or "", "^(%S*)%s*(.*)$")
	key = string.lower(key or "")
	local r = T.setting
	if key == "camera" then
		r.camera = tonumber(rest)
	elseif key == "scale" then
		r.scale = tonumber(rest)
	elseif key == "position" then
		local x, y, z = string.match(rest, "^(%-?[%d%.]+)%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)$")
		if not x then
			say(L.TABARDFRAME_POSITION_USAGE)
			return
		end
		r.position = { tonumber(x), tonumber(y), tonumber(z) }
	elseif key == "default" then
		T.setting = { camera = SETTING.camera, position = SETTING.position, scale = SETTING.scale }
		m:SetUnit("player")
		if m.InitializeTabardColors then m:InitializeTabardColors() end
	elseif key == "client" then
		T.setting = { camera = nil, position = { 0, 0, 0 }, scale = 1 }
		m:SetUnit("player")
		if m.InitializeTabardColors then m:InitializeTabardColors() end
	elseif key ~= "" then
		say(L.TABARDFRAME_USAGE)
		return
	end
	applySetting()
	catchUp()
	local x, y, z
	if m.GetPosition then x, y, z = m:GetPosition() end
	say(string.format(L.TABARDFRAME_STATE, tostring(T.setting.camera),
		tostring(m.GetModelScale and m:GetModelScale()), tostring(x), tostring(y), tostring(z)))
end

-- On OPEN_TABARD_FRAME the 3.3.5 client calls TabardModel:SetUnit("player") before
-- ShowUIPanel, so the model frames itself on a hidden window and ends up bottom left. As
-- camelot does, SetUnit is called again once the window is shown (next frame), then the
-- current tabard is restored as the client does after SetUnit (InitializeTabardColors,
-- TabardFrame_UpdateTextures).
local reframe = CreateFrame("Frame")
reframe:Hide()
reframe:SetScript("OnUpdate", function(self)
	self:Hide()
	if not (TabardFrame and TabardFrame:IsShown() and TabardModel) then return end
	TabardModel:SetUnit("player")
	if TabardModel.InitializeTabardColors then TabardModel:InitializeTabardColors() end
	if TabardFrame_UpdateTextures then TabardFrame_UpdateTextures() end
	if TabardFrame_UpdateButtons then TabardFrame_UpdateButtons() end
	catchUp()
end)
T.reframe = reframe

-- On open: merchant portrait and name (just set by TabardFrame_OnEvent on the client
-- regions), then reframe the model
function T.open()
	SetPortraitTexture(T.portrait, "npc")
	T.name:SetText(TabardFrameNameText and TabardFrameNameText:GetText() or UnitName("npc"))
	reframe:Show()
end

if TabardFrame then
	T.applySkin()
	TabardFrame:HookScript("OnShow", T.open)
end
