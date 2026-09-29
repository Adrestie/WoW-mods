-- Hunter stable (PetStableFrame) reskinned after camelot's blizzard_stableui ([Game] flavor).
-- 3.3.5 has five slots (current + 4) against three: the row is centered under the scene.
-- 3.3.5 has no loyalty, and the STABLES title stays in the title band.
-- The specialization name comes in the client language and is matched through the addon
-- texts; another language leaves the marble background.
-- Only the summoned pet has experience (GetPetExperience), so the bar shows only for it.
-- The money frame sits 7 from the bottom: camelot's other anchor, 28, covers Purchase.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = ForeverUI.Templates
local L = ForeverUI.L

local E = {}
ForeverUI.Stable = E

local SEP = string.char(92)
local COMMON = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP

-- Layout measures, from camelot's blizzard_stableui.
local N = {
	portrait = { side = 48, x = 1, y = 1.5 },
	level = { 0, -34 },
	scene = { 7, -72, -10, 140 },
	backgroundAlpha = 0.8,
	shadow = { 410, 90, -8, -80, 0.6 },
	diet = { 4, -6 },
	controls = { y = -10, side = 32, icon = 16, gap = -6, alpha = 0.5, glow = 0.4 },
	experience = { 322, 10, 0, 10, half = 161, halfH = 13 },
	-- row: 37 + 53 + 37 + 3 x (15 + 37) = 283, centered under the scene
	rowLine = { x = -123, y = -23, yNoPurchase = -43, current = 53, gap = 15 },
	stableTag = { 26, 6 },
	slotsText = { 0, 55 },
	cost = { 70, 30 },
	purchase = { 80, 22, -75, 25 },
	money = { 10, 7, edge = 8, h = 17 },
	levels = { background = 1, model = 2, hovered = 3, controls = 4, closeButton = 22 },
}

local ART = {
	marble = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	edgeShadow = { corner = COMMON .. "shadowoverlay-corner", top = COMMON .. "shadowoverlay-top",
		down = COMMON .. "shadowoverlay-bottom", left = COMMON .. "shadowoverlay-left", right = COMMON .. "shadowoverlay-right" },
	dwarf = "Interface" .. SEP .. "MainMenuBar" .. SEP .. "UI-MainMenuBar-Dwarf",
}

-- Specializations: client name (addon texts) -> background atlas
local SPECIALIZATIONS = {
	{ L.STABLE_TALENT_FEROCITY, "hunter-stable-bg-art_ferocity" },
	{ L.STABLE_TALENT_TENACITY, "hunter-stable-bg-art_tenacity" },
	{ L.STABLE_TALENT_CUNNING, "hunter-stable-bg-art_cunning" },
}

-- Re-anchors region r to a single point.
local function place(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- ------------------------------------------------------------ Scene

-- ShadowOverlayTemplate (mainline/shareduipaneltemplates.xml): 32 corners, 32 edges between
-- them, as files. host: owner of the textures; rect: region the shadow frames.
local function createEdgeShadow(host, rect)
	local A = ART.edgeShadow
	local function corner(point, u1, u2, v1, v2)
		local t = host:CreateTexture(nil, "ARTWORK")
		t:SetTexture(A.corner)
		t:SetTexCoord(u1, u2, v1, v2)
		t:SetWidth(32)
		t:SetHeight(32)
		t:SetPoint(point, rect, point)
		return t
	end
	local topLeft = corner("TOPLEFT", 0, 1, 0, 1)
	local topRight = corner("TOPRIGHT", 1, 0, 0, 1)
	local bottomLeft = corner("BOTTOMLEFT", 0, 1, 1, 0)
	local bottomRight = corner("BOTTOMRIGHT", 1, 0, 1, 0)
	local function edge(file, a1, c1, r1, a2, c2, r2, l, h)
		local t = host:CreateTexture(nil, "ARTWORK")
		t:SetTexture(file)
		if l then t:SetWidth(l) end
		if h then t:SetHeight(h) end
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
		return t
	end
	return {
		topLeft = topLeft, topRight = topRight, bottomLeft = bottomLeft, bottomRight = bottomRight,
		top = edge(A.top, "TOPLEFT", topLeft, "TOPRIGHT", "TOPRIGHT", topRight, "TOPLEFT", nil, 32),
		down = edge(A.down, "BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", bottomRight, "BOTTOMLEFT", nil, 32),
		left = edge(A.left, "TOPLEFT", topLeft, "BOTTOMLEFT", "BOTTOMLEFT", bottomLeft, "TOPLEFT", 32, nil),
		right = edge(A.right, "TOPRIGHT", topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", bottomRight, "TOPRIGHT", 32, nil),
	}
end

-- Turns button b into a ModelSceneControlFrameTemplate square button; icon: atlas name.
local function squareButton(b, icon)
	local C = N.controls
	b:SetWidth(C.side)
	b:SetHeight(C.side)
	for _, read in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
		local t = b[read] and b[read](b)
		if t then t:SetAlpha(0) end
	end
	local background = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "common-button-square-gray-up", true)
	background:SetAllPoints(b)
	local image = b:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(image, icon, true)
	image:SetWidth(C.icon)
	image:SetHeight(C.icon)
	image:SetPoint("CENTER", b, "CENTER", 0, 0)
	local glow = b:CreateTexture(nil, "HIGHLIGHT")
	ForeverUI.SetAtlas(glow, icon, true)
	glow:SetWidth(C.icon)
	glow:SetHeight(C.icon)
	glow:SetPoint("CENTER", image, "CENTER", 0, 0)
	glow:SetBlendMode("ADD")
	glow:SetAlpha(C.glow)
	b:HookScript("OnMouseDown", function()
		ForeverUI.SetAtlas(background, "common-button-square-gray-down", true)
		place(image, "CENTER", b, "CENTER", 1, -1)
	end)
	b:HookScript("OnMouseUp", function()
		ForeverUI.SetAtlas(background, "common-button-square-gray-up", true)
		place(image, "CENTER", b, "CENTER", 0, 0)
	end)
	b.foreverSquare = { background = background, image = image, glow = glow }
	return b
end

-- ------------------------------------------------------------ Experience

-- Experience bar at the bottom of the scene (PetExpStatusBarTemplate).
local function createExperienceBar(parent, scene)
	local X = N.experience
	local b = CreateFrame("Frame", "ForeverUIPetStableExpBar", parent)
	b:SetWidth(X[1])
	b:SetHeight(X[2])
	b:SetPoint("BOTTOM", scene, "BOTTOM", X[3], X[4])
	b:EnableMouse(true)
	local background = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(background, "ui-hud-experiencebar-background-camelot", true)
	background:SetAllPoints(b)
	local fill = b:CreateTexture(nil, "ARTWORK")
	fill:SetPoint("LEFT", b, "LEFT", 0, 0)
	fill:SetHeight(X[2])
	fill:Hide()
	-- The two halves of the dwarf art (PetExpStatusBarTemplate)
	local g = b:CreateTexture(nil, "OVERLAY")
	g:SetTexture(ART.dwarf)
	g:SetTexCoord(0.1953125, 0.8046875, 0.2890625, 0.33984375)
	g:SetWidth(X.half)
	g:SetHeight(X.halfH)
	g:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 2)
	local d = b:CreateTexture(nil, "OVERLAY")
	d:SetTexture(ART.dwarf)
	d:SetTexCoord(0.203125, 0.8125, 0.2890625, 0.33984375)
	d:SetWidth(X.half)
	d:SetHeight(X.halfH)
	d:SetPoint("LEFT", g, "RIGHT", 0, 0)
	local text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	text:SetPoint("CENTER", b, "CENTER", 0, 0)
	text:Hide()
	b:SetScript("OnEnter", function() text:Show() end)
	b:SetScript("OnLeave", function() text:Hide() end)
	b.fill, b.text = fill, text
	b:Hide()
	return b
end

-- Summoned pet experience (3.3.5 gives no other). summoned: the selected pet is the
-- summoned one.
function E.UpdateExperience(summoned)
	local b = E.experience
	if not b then return end
	local earned, maximum
	if summoned and GetPetExperience then earned, maximum = GetPetExperience() end
	if not maximum or maximum <= 0 then
		b:Hide()
		return
	end
	b:Show()
	local fraction = math.min(1, (earned or 0) / maximum)
	local e = ForeverUI.AtlasEntry("ui-hud-experiencebar-fill-experience-camelot")
	local w = N.experience[1] * fraction
	if e and w >= 1 then
		b.fill:SetTexture(e[1])
		b.fill:SetTexCoord(e[2], e[2] + (e[3] - e[2]) * fraction, e[4], e[5])
		b.fill:SetWidth(w)
		b.fill:Show()
	else
		b.fill:Hide()
	end
	b.text:SetText(string.format("%d / %d  (%d%%)", earned or 0, maximum, math.floor(fraction * 100)))
end

-- ------------------------------------------------------------ After the client

-- Background atlas of the selected pet's specialization, or nil
local function specialization()
	local selected = GetSelectedStablePet and GetSelectedStablePet() or -1
	local talent
	if selected == 0 and UnitExists("pet") then
		talent = GetPetTalentTree and GetPetTalentTree()
	elseif selected and selected >= 0 then
		talent = select(5, GetStablePetInfo(selected))
	end
	for _, s in ipairs(SPECIALIZATIONS) do
		if talent and s[1] and talent == s[1] then return s[2] end
	end
end

-- Runs after PetStable_Update: portrait, background, slot row, experience
function E.After()
	local h = PetStableFrame and PetStableFrame.foreverSkin
	if not h then return end
	SetPortraitTexture(h.portrait, UnitExists("npc") and "npc" or "player")
	local atlas = specialization()
	if atlas and PetStableModel:IsShown() then
		ForeverUI.SetAtlas(h.background, atlas, true)
		h.background:Show()
	else
		h.background:Hide()
	end
	local R = N.rowLine
	place(PetStableCurrentPet, "TOP", h.scene, "BOTTOM", R.x,
		PetStablePurchaseButton:IsShown() and R.y or R.yNoPurchase)
	local selected = GetSelectedStablePet and GetSelectedStablePet() or -1
	E.UpdateExperience(selected == 0 and UnitExists("pet"))
end

-- Rotation controls: shown while the mouse is over the scene
local function followMouse(self)
	local h = PetStableFrame.foreverSkin
	local hovered = h.scene:IsMouseOver() and PetStableModel:IsShown()
	Tpl.SetShown(h.controls, hovered)
	if hovered then
		local overButton = false
		for _, b in ipairs(h.buttons) do
			if b:IsMouseOver() then overButton = true end
		end
		h.controls:SetAlpha(overButton and 1 or N.controls.alpha)
	end
end

function E.Skin()
	local f = PetStableFrame
	if not f or f.foreverSkin then return end
	-- 3.3.5 art (two unnamed pieces, two named) and its portrait
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local t = r:GetTexture()
			if type(t) == "string" and string.find(string.lower(t), "ui-petstable-", 1, true) then r:SetAlpha(0) end
		end
	end
	PetStableFramePortrait:SetAlpha(0)
	PetStableTitleLabel:SetAlpha(0)
	f:SetHitRectInsets(0, 0, 0, 0)
	local skin = Tpl.PortraitWindow(f, {
		portraitSide = N.portrait.side, portraitX = N.portrait.x, portraitY = N.portrait.y,
		title = STABLES,
	})
	f.foreverSkin = skin
	local base = f:GetFrameLevel()
	local NV = N.levels
	-- Scene: an anchor frame; under the model, the marble, the specialization background and
	-- the pet shadow
	local S = N.scene
	local scene = CreateFrame("Frame", "ForeverUIPetStableScene", f)
	scene:SetPoint("TOPLEFT", f, "TOPLEFT", S[1], S[2])
	scene:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", S[3], S[4])
	scene:SetFrameLevel(base + NV.background)
	scene:EnableMouse(false)
	skin.scene = scene
	local marble = scene:CreateTexture(nil, "BACKGROUND")
	marble:SetTexture(ART.marble, true)
	if marble.SetHorizTile then marble:SetHorizTile(true) marble:SetVertTile(true) end
	marble:SetAllPoints(scene)
	local background = scene:CreateTexture(nil, "BORDER")
	background:SetAllPoints(scene)
	background:SetAlpha(N.backgroundAlpha)
	background:Hide()
	skin.marble, skin.background = marble, background
	local O = N.shadow
	local shadow = scene:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(shadow, "perks-char-shadow", true)
	shadow:SetWidth(O[1])
	shadow:SetHeight(O[2])
	shadow:SetPoint("CENTER", scene, "CENTER", O[3], O[4])
	shadow:SetAlpha(O[5])
	skin.petShadow = shadow
	-- The client model fills the scene and rotates with the mouse
	place(PetStableModel, "TOPLEFT", scene, "TOPLEFT", 0, 0)
	PetStableModel:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT", 0, 0)
	PetStableModel:SetFrameLevel(base + NV.model)
	if ForeverUI.RotateWithMouse then ForeverUI.RotateWithMouse(PetStableModel) end
	-- Above: inset trim and edge shadow
	local hovered = CreateFrame("Frame", nil, f)
	hovered:SetAllPoints(scene)
	hovered:SetFrameLevel(base + NV.hovered)
	hovered:EnableMouse(false)
	skin.trim = Tpl.NineSlice(hovered, "InsetFrameTemplate", scene)
	local shadowFrame = CreateFrame("Frame", nil, hovered)
	shadowFrame:SetPoint("TOPLEFT", scene, "TOPLEFT", 0, 0)
	shadowFrame:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT", 1, -1)
	skin.edgeShadow = createEdgeShadow(hovered, shadowFrame)
	-- Diet, top left of the scene
	PetStablePetInfo:SetParent(hovered)
	place(PetStablePetInfo, "TOPLEFT", scene, "TOPLEFT", N.diet[1], N.diet[2])
	PetStablePetInfo:SetFrameLevel(base + NV.controls)
	-- Controls: rotate left, rotate right, reset
	local C = N.controls
	local controls = CreateFrame("Frame", nil, f)
	controls:SetFrameLevel(base + NV.controls)
	controls:SetHeight(C.side)
	controls:SetPoint("TOP", scene, "TOP", 0, C.y)
	local left = squareButton(PetStableModelRotateLeftButton, "common-icon-rotateleft")
	local right = squareButton(PetStableModelRotateRightButton, "common-icon-rotateright")
	local backButton = squareButton(CreateFrame("Button", "ForeverUIPetStableResetButton", controls), "common-icon-undo")
	backButton:SetScript("OnClick", function()
		PetStableModel.rotation = MODELFRAME_DEFAULT_ROTATION or 0.61
		PetStableModel:SetRotation(PetStableModel.rotation)
	end)
	for i, b in ipairs({ left, right, backButton }) do
		b:SetParent(controls)
		b:SetFrameLevel(base + NV.controls + 1)
		if i == 1 then
			place(b, "LEFT", controls, "LEFT", 0, 0)
		else
			place(b, "LEFT", i == 2 and left or right, "RIGHT", C.gap, 0)
		end
	end
	controls:SetWidth(3 * C.side + 2 * C.gap)
	skin.controls, skin.buttons = controls, { left, right, backButton }
	controls:Hide()
	hovered:SetScript("OnUpdate", followMouse)
	-- Summoned pet experience
	E.experience = createExperienceBar(hovered, scene)
	-- Top texts
	place(PetStableLevelText, "TOP", f, "TOP", N.level[1], N.level[2])
	-- Slots centered under the scene; STABLED_PETS over the four stabled ones
	local R = N.rowLine
	place(PetStableCurrentPet, "TOP", scene, "BOTTOM", R.x, R.y)
	for _, r in ipairs({ PetStableStabledPet2:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == STABLED_PETS then
			place(r, "BOTTOM", PetStableStabledPet2, "TOP", N.stableTag[1], N.stableTag[2])
		end
	end
	-- Bottom
	place(PetStableSlotText, "BOTTOM", f, "BOTTOM", N.slotsText[1], N.slotsText[2])
	place(PetStableCostLabel, "BOTTOMLEFT", f, "BOTTOMLEFT", N.cost[1], N.cost[2])
	place(PetStableCostMoneyFrame, "LEFT", PetStableCostLabel, "RIGHT", 0, 0)
	local A = N.purchase
	PetStablePurchaseButton:SetWidth(A[1])
	PetStablePurchaseButton:SetHeight(A[2])
	place(PetStablePurchaseButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", A[3], A[4])
	Tpl.PanelButton(PetStablePurchaseButton)
	-- Player money in its coin box
	local M = N.money
	place(PetStableMoneyFrame, "BOTTOMLEFT", f, "BOTTOMLEFT", M[1], M[2])
	PetStableMoneyFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -M[1], M[2])
	local bottomLeft = PetStableMoneyFrame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(bottomLeft, "common-coinbox-left", true)
	bottomLeft:SetWidth(M.edge)
	bottomLeft:SetHeight(M.h)
	bottomLeft:SetPoint("LEFT", PetStableMoneyFrame, "LEFT", 0, 0)
	local bottomRight = PetStableMoneyFrame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(bottomRight, "common-coinbox-right", true)
	bottomRight:SetWidth(M.edge)
	bottomRight:SetHeight(M.h)
	bottomRight:SetPoint("RIGHT", PetStableMoneyFrame, "RIGHT", 0, 0)
	local bm = PetStableMoneyFrame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(bm, "_common-coinbox-center", true)
	bm:SetPoint("TOPLEFT", bottomLeft, "TOPRIGHT")
	bm:SetPoint("BOTTOMRIGHT", bottomRight, "BOTTOMLEFT")
	skin.purse = { bottomLeft, bm, bottomRight }
	Tpl.CloseButton(PetStableFrameCloseButton, f)
	PetStableFrameCloseButton:SetFrameLevel(base + NV.closeButton)
	hooksecurefunc("PetStable_Update", E.After)
end

E.Skin()
