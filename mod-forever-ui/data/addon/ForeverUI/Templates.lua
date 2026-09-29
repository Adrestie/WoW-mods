-- ForeverUI: Camelot templates for the in-game windows restyled over 3.3.5 (Esc menu,
-- settings), ported from the glue screen ones (ForeverUIGlue.lua, ForeverUIGlueTemplates.lua).
-- ART holds Camelot's atlas data (ForeverUIGlueAtlas.lua): size (OverrideWidth / OverrideHeight),
-- tiling and nine-slice margins. The game's UIAtlas lacks them (a DiamondMetal corner is 128).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Tpl = {}
ForeverUI.Templates = Tpl

-- { file, u1, u2, v1, v2, width, height, tileH, tileV, slice { left, top, right, bottom } }
local ART = {
	["ui-frame-diamondmetal-cornertopleft"] = { "interface\\ForeverUI\\framegeneral\\uiframediamondmetal2xc60", 0.003906, 0.503906, 0.508789, 0.633789, 32, 32 },
	["ui-frame-diamondmetal-cornertopright"] = { "interface\\ForeverUI\\framegeneral\\uiframediamondmetal2xc60", 0.003906, 0.503906, 0.635742, 0.760742, 32, 32 },
	["ui-frame-diamondmetal-cornerbottomleft"] = { "interface\\ForeverUI\\framegeneral\\uiframediamondmetal2xc60", 0.003906, 0.503906, 0.254883, 0.379883, 32, 32 },
	["ui-frame-diamondmetal-cornerbottomright"] = { "interface\\ForeverUI\\framegeneral\\uiframediamondmetal2xc60", 0.003906, 0.503906, 0.381836, 0.506836, 32, 32 },
	["_ui-frame-diamondmetal-edgetop"] = { "interface\\ForeverUI\\framegeneral\\uiframediamondmetal2xc60", 0.000000, 0.500000, 0.127930, 0.252930, 32, 32, true, false },
	["_ui-frame-diamondmetal-edgebottom"] = { "interface\\ForeverUI\\framegeneral\\uiframediamondmetal2xc60", 0.000000, 0.500000, 0.000977, 0.125977, 32, 32, true, false },
	["!ui-frame-diamondmetal-edgeleft"] = { "interface\\ForeverUI\\framegeneral\\uiframediamondmetalvertical2xc60", 0.001953, 0.251953, 0.000000, 1.000000, 32, 32, false, true },
	["!ui-frame-diamondmetal-edgeright"] = { "interface\\ForeverUI\\framegeneral\\uiframediamondmetalvertical2xc60", 0.255859, 0.505859, 0.000000, 1.000000, 32, 32, false, true },
	["ui-frame-diamondmetal-header-cornerleft"] = { "interface\\ForeverUI\\framegeneral\\uiframediamondmetalheader2xc60", 0.003906, 0.503906, 0.310547, 0.615234, 32, 39 },
	["ui-frame-diamondmetal-header-cornerright"] = { "interface\\ForeverUI\\framegeneral\\uiframediamondmetalheader2xc60", 0.003906, 0.503906, 0.619141, 0.923828, 32, 39 },
	["_ui-frame-diamondmetal-header-tile"] = { "interface\\ForeverUI\\framegeneral\\uiframediamondmetalheader2xc60", 0.000000, 0.500000, 0.001953, 0.306641, 32, 39, true, false },
	["ui-frame-metal-cornertopleft"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.188477, 0.374023, 0.001953, 0.373047, 95, 95 },
	["ui-frame-metal-cornertopright"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.188477, 0.374023, 0.376953, 0.748047, 95, 95 },
	["ui-frame-metal-cornerbottomleft"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.000977, 0.186523, 0.001953, 0.392578, 95, 100 },
	["ui-frame-metal-cornerbottomright"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.000977, 0.186523, 0.396484, 0.787109, 95, 100 },
	["_ui-frame-metal-edgetop"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalhorizontal2xc60", 0.000000, 1.000000, 0.396484, 0.767578, 128, 95, true, false },
	["_ui-frame-metal-edgebottom"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalhorizontal2xc60", 0.000000, 1.000000, 0.001953, 0.392578, 128, 100, true, false },
	["!ui-frame-metal-edgeleft"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalvertical2xc60", 0.001953, 0.373047, 0.000000, 1.000000, 95, 128, false, true },
	["!ui-frame-metal-edgeright"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalvertical2xc60", 0.376953, 0.748047, 0.000000, 1.000000, 95, 128, false, true },
	["_ui-frame-toptilestreaks"] = { "interface\\ForeverUI\\framegeneral\\uiframehorizontal", 0.000000, 1.000000, 0.007812, 0.343750, 256, 43, true, false },
	["ui-frame-innertopleft"] = { "interface\\ForeverUI\\framegeneral\\uiframe", 0.757812, 0.804688, 0.554688, 0.601562, 6, 6 },
	["ui-frame-innertopright"] = { "interface\\ForeverUI\\framegeneral\\uiframe", 0.820312, 0.867188, 0.554688, 0.601562, 6, 6 },
	["ui-frame-innerbotleftcorner"] = { "interface\\ForeverUI\\framegeneral\\uiframe", 0.632812, 0.679688, 0.554688, 0.601562, 6, 6 },
	["ui-frame-innerbotright"] = { "interface\\ForeverUI\\framegeneral\\uiframe", 0.695312, 0.742188, 0.554688, 0.601562, 6, 6 },
	["_ui-frame-innertoptile"] = { "interface\\ForeverUI\\framegeneral\\uiframehorizontal", 0.000000, 1.000000, 0.906250, 0.929688, 256, 3, true, false },
	["_ui-frame-innerbottile"] = { "interface\\ForeverUI\\framegeneral\\uiframehorizontal", 0.000000, 1.000000, 0.867188, 0.890625, 256, 3, true, false },
	["!ui-frame-innerlefttile"] = { "interface\\ForeverUI\\framegeneral\\uiframevertical", 0.484375, 0.531250, 0.000000, 1.000000, 3, 256, false, true },
	["!ui-frame-innerrighttile"] = { "interface\\ForeverUI\\framegeneral\\uiframevertical", 0.562500, 0.609375, 0.000000, 1.000000, 3, 256, false, true },
	-- profession schematic frame (SchematicFormCraftingTemplate), slice 53 on all sides, c60
	["common-insideframe"] = { "interface\\ForeverUI\\common\\commoninsideframec60", 0.007812, 0.843750, 0.007812, 0.843750, 107, 107, false, false, { 53, 53, 53, 53, 0 } },
	-- heavybronze frame of the barber shop (CharCustomizeFrame), slice 32, c60 variant,
	-- as in character creation (ForeverUIGlueAtlas)
	["heavybronze-frame-basic"] = { "interface\\ForeverUI\\unknown\\8203429", 0.003906, 0.316406, 0.007812, 0.632812, 80, 80, false, false, { 32, 32, 32, 32, 0 } },
	-- barber shop choice list: item hover and color swatches, at character creation sizes
	-- (ForeverUIGlueAtlas; UIAtlas stores these swatches at double density)
	["common-dropdown-customize-mouseover"] = { "interface\\ForeverUI\\common\\commondropdown", 0.138672, 0.177734, 0.363281, 0.441406, 20, 20, false, false, { 4, 4, 4, 4, 0 } },
	["charactercreate-customize-palette"] = { "interface\\ForeverUI\\glues\\charactercreate-customize-palette", 0.000000, 0.656250, 0.000000, 0.625000, 42, 10 },
	["charactercreate-customize-palette-glow"] = { "interface\\ForeverUI\\glues\\charactercreate-customize-palette-glow", 0.000000, 0.656250, 0.000000, 0.625000, 42, 10 },
	["charactercreate-customize-palette-selected"] = { "interface\\ForeverUI\\glues\\charactercreate-customize-palette-selected", 0.000000, 0.796875, 0.000000, 0.625000, 51, 20 },
	-- dialog box border (GameDialogBackgroundTop), c60 variant
	["ui-diamonddialogbox-border"] = { "interface\\ForeverUI\\dialogframe\\uiframediamondmetalborder2xc60", 0.003906, 0.550781, 0.003906, 0.550781, 70, 70, false, false, { 32, 32, 32, 32, 0 } },
	["redbutton-exit"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.007812, 0.257812, 32, 32 },
	["redbutton-exit-pressed"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.539062, 0.789062, 32, 32 },
	["redbutton-exit-disabled"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.273438, 0.523438, 32, 32 },
	["redbutton-highlight"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.402344, 0.527344, 0.007812, 0.257812, 32, 32 },
	["128-redbutton-left"] = { "interface\\ForeverUI\\buttons\\128-redbutton-left-c60", 0.015625, 0.906250, 0.000000, 1.000000, 114, 128 },
	["128-redbutton-left-pressed"] = { "interface\\ForeverUI\\buttons\\128-redbutton-left-pressed-c60", 0.015625, 0.906250, 0.000000, 1.000000, 114, 128 },
	["128-redbutton-left-disabled"] = { "interface\\ForeverUI\\buttons\\128-redbutton-left-disabled-c60", 0.015625, 0.906250, 0.000000, 1.000000, 114, 128 },
	["_128-redbutton-center"] = { "interface\\ForeverUI\\buttons\\_128-redbutton-center-c60", 0.015625, 0.515625, 0.000000, 1.000000, 64, 128, true, false },
	["_128-redbutton-center-pressed"] = { "interface\\ForeverUI\\buttons\\_128-redbutton-center-pressed-c60", 0.015625, 0.515625, 0.000000, 1.000000, 64, 128, true, false },
	["_128-redbutton-center-disabled"] = { "interface\\ForeverUI\\buttons\\_128-redbutton-center-disabled-c60", 0.015625, 0.515625, 0.000000, 1.000000, 64, 128, true, false },
	["128-redbutton-right"] = { "interface\\ForeverUI\\buttons\\128-redbutton-right-c60", 0.003906, 0.574219, 0.000000, 1.000000, 292, 128 },
	["128-redbutton-right-pressed"] = { "interface\\ForeverUI\\buttons\\128-redbutton-right-pressed-c60", 0.003906, 0.574219, 0.000000, 1.000000, 292, 128 },
	["128-redbutton-right-disabled"] = { "interface\\ForeverUI\\buttons\\128-redbutton-right-disabled-c60", 0.003906, 0.574219, 0.000000, 1.000000, 292, 128 },
	["128-redbutton-highlight"] = { "interface\\ForeverUI\\buttons\\128-redbutton-highlight", 0.003906, 0.865234, 0.000000, 1.000000, 441, 128 },
	["checkbox-minimal"] = { "interface\\ForeverUI\\common\\minimalcheckboxc60", 0.031250, 0.968750, 0.031250, 0.937500, 30, 29 },
	["checkmark-minimal"] = { "interface\\ForeverUI\\common\\minimalcheckbox-hd", 0.015625, 0.484375, 0.500000, 0.953125, 30, 29 },
	["checkmark-minimal-disabled"] = { "interface\\ForeverUI\\common\\minimalcheckbox-hd", 0.515625, 0.984375, 0.015625, 0.468750, 30, 29 },
	["minimal_sliderbar_left"] = { "interface\\ForeverUI\\buttons\\minimalsliderbarc60-hd", 0.437500, 0.781250, 0.320312, 0.453125, 11, 17 },
	["minimal_sliderbar_right"] = { "interface\\ForeverUI\\buttons\\minimalsliderbarc60-hd", 0.031250, 0.375000, 0.484375, 0.617188, 11, 17 },
	["_minimal_sliderbar_middle"] = { "interface\\ForeverUI\\buttons\\minimalsliderbarc60-hd", 0.000000, 0.031250, 0.007812, 0.140625, 1, 17, true, false },
	["minimal_sliderbar_button"] = { "interface\\ForeverUI\\buttons\\minimalsliderbarc60-hd", 0.031250, 0.656250, 0.156250, 0.304688, 20, 19 },
	["options_list_active"] = { "interface\\ForeverUI\\optionsframe\\options", 0.589844, 0.772461, 0.000977, 0.021484, 187, 21 },
	["options_list_hover"] = { "interface\\ForeverUI\\optionsframe\\optionsc60", 0.000977, 0.183594, 0.891602, 0.912109, 187, 21 },
	["common-dropdown-c-button"] = { "interface\\ForeverUI\\common\\commondropdownc60", 0.281250, 0.357422, 0.664062, 0.968750, 39, 39, false, false, { 12, 0, 12, 0, 0 } },
	["common-dropdown-c-button-hover-1"] = { "interface\\ForeverUI\\common\\commondropdownc60", 0.501953, 0.578125, 0.226562, 0.531250, 39, 39, false, false, { 12, 0, 12, 0, 0 } },
	["common-dropdown-c-button-pressed-1"] = { "interface\\ForeverUI\\common\\commondropdownc60", 0.921875, 0.998047, 0.226562, 0.531250, 39, 39, false, false, { 14, 0, 12, 0, 0 } },
	["common-dropdown-c-button-pressedhover-1"] = { "interface\\ForeverUI\\common\\commondropdownc60", 0.841797, 0.917969, 0.226562, 0.531250, 39, 39, false, false, { 14, 0, 12, 0, 0 } },
	["common-dropdown-c-button-open"] = { "interface\\ForeverUI\\common\\commondropdownc60", 0.582031, 0.658203, 0.226562, 0.531250, 39, 39, false, false, { 12, 0, 12, 0, 0 } },
	["common-dropdown-c-button-disabled"] = { "interface\\ForeverUI\\common\\commondropdownc60", 0.501953, 0.578125, 0.546875, 0.851562, 39, 39, false, false, { 12, 0, 12, 0, 0 } },
	["common-dropdown-c-button-hover-arrow"] = { "interface\\ForeverUI\\common\\commondropdownc60", 0.001953, 0.025391, 0.914062, 0.953125, 12, 5 },
	["common-dropdown-c-bg"] = { "interface\\ForeverUI\\common\\commondropdownc60", 0.662109, 0.837891, 0.226562, 0.929688, 90, 90, false, false, { 23, 18, 23, 28, 0 } },
	["common-dropdown-tickradial"] = { "interface\\ForeverUI\\common\\commondropdown", 0.138672, 0.173828, 0.527344, 0.597656, 18, 18 },
	["common-dropdown-icon-radialtick-yellow"] = { "interface\\ForeverUI\\common\\commondropdown", 0.138672, 0.173828, 0.449219, 0.519531, 18, 18 },
}

-- 3.3.5 returns 1 / nil, sometimes 0 / 1, and 0 is true in Lua
local function truthy(v)
	return v and v ~= 0 and true or false
end
Tpl.Truthy = truthy

function Tpl.Art(name)
	return ART[name]
end

-- applies element name to texture; size: also apply its size (SetAtlas(name, true)).
-- Returns the entry.
function Tpl.Place(texture, name, size)
	local e = ART[name]
	if not e then
		return nil
	end
	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[3], e[4], e[5])
	if size then
		texture:SetWidth(e[6])
		texture:SetHeight(e[7])
	end
	return e
end

function Tpl.SetShown(region, yes)
	if yes then region:Show() else region:Hide() end
end

-- 3.3.5 can only tile a whole image: an element filling its sheet tiles, others stretch
local function tile(texture, e)
	local isWhole = e[2] == 0 and e[3] == 1 and e[4] == 0 and e[5] == 1
	if isWhole and (e[8] or e[9]) and texture.SetHorizTile then
		texture:SetTexture(e[1], true)
		texture:SetHorizTile(e[8] and true or false)
		texture:SetVertTile(e[9] and true or false)
	end
end

-- ------------------------------------------------------------ Stretched atlas

-- A sliced element draws as nine pieces when stretched: the margins keep their size, the rest
-- stretches. 3.3.5 has no slicing, so the pieces are host regions laid around an invisible
-- rectangle.
local function cut(obj)
	local e = obj.e
	local d = e[10]
	for _, t in ipairs(obj.pieces) do
		t:Hide()
	end
	if not d then
		obj.rect:SetTexture(e[1])
		obj.rect:SetTexCoord(e[2], e[3], e[4], e[5])
		return
	end
	obj.rect:SetTexture(nil)
	local W, H = e[6], e[7]
	local g, h, dr, b = d[1], d[2], d[3], d[4]
	local us = { e[2], e[2] + (e[3] - e[2]) * g / W, e[3] - (e[3] - e[2]) * dr / W, e[3] }
	local vs = { e[4], e[4] + (e[5] - e[4]) * h / H, e[5] - (e[5] - e[4]) * b / H, e[5] }
	local widths = { g, nil, dr }
	local heights = { h, nil, b }
	local r = obj.rect
	local n = 0
	for row = 1, 3 do
		for col = 1, 3 do
			local lw, lh = widths[col], heights[row]
			if (lw == nil or lw > 0) and (lh == nil or lh > 0) then
				n = n + 1
				local t = obj.pieces[n]
				if not t then
					t = obj.host:CreateTexture(nil, obj.layer)
					obj.pieces[n] = t
				end
				t:SetTexture(e[1])
				t:SetTexCoord(us[col], us[col + 1], vs[row], vs[row + 1])
				t:ClearAllPoints()
				if col == 1 then
					t:SetPoint("LEFT", r, "LEFT")
					t:SetWidth(lw)
				elseif col == 3 then
					t:SetPoint("RIGHT", r, "RIGHT")
					t:SetWidth(lw)
				else
					t:SetPoint("LEFT", r, "LEFT", g, 0)
					t:SetPoint("RIGHT", r, "RIGHT", -dr, 0)
				end
				if row == 1 then
					t:SetPoint("TOP", r, "TOP")
					t:SetHeight(lh)
				elseif row == 3 then
					t:SetPoint("BOTTOM", r, "BOTTOM")
					t:SetHeight(lh)
				else
					t:SetPoint("TOP", r, "TOP", 0, -h)
					t:SetPoint("BOTTOM", r, "BOTTOM", 0, b)
				end
				if obj.visible ~= false then
					t:Show()
				end
			end
		end
	end
	obj.count = n
end

-- Stretched atlas element; the caller anchors .rect as it would anchor the Camelot texture.
-- Returns { rect, Place(name), SetShown(yes), Alpha(a) }.
function Tpl.StretchedAtlas(host, name, layer)
	local obj = { host = host, layer = layer or "ARTWORK", pieces = {} }
	obj.rect = host:CreateTexture(nil, obj.layer)
	function obj:Place(n)
		self.e = ART[n]
		cut(self)
	end
	function obj:SetShown(yes)
		self.visible = yes and true or false
		if self.e[10] then
			for i = 1, self.count or 0 do
				Tpl.SetShown(self.pieces[i], yes)
			end
		else
			Tpl.SetShown(self.rect, yes)
		end
	end
	function obj:Alpha(a)
		self.rect:SetAlpha(a)
		for _, t in ipairs(self.pieces) do
			t:SetAlpha(a)
		end
	end
	obj:Place(name)
	return obj
end

-- ------------------------------------------------------------ Nine-slice

-- Source: blizzard_sharedxml/mainline/nineslicelayouts.lua (layouts copied as is) and
-- nineslice.lua (ApplyLayout); ButtonFrameTemplateNoPortrait follows
-- camelot/NineSliceLayoutOverrides.lua.
Tpl.LAYOUTS = {
	Dialog = {
		TopLeftCorner = { atlas = "ui-frame-diamondmetal-cornertopleft" },
		TopRightCorner = { atlas = "ui-frame-diamondmetal-cornertopright" },
		BottomLeftCorner = { atlas = "ui-frame-diamondmetal-cornerbottomleft" },
		BottomRightCorner = { atlas = "ui-frame-diamondmetal-cornerbottomright" },
		TopEdge = { atlas = "_ui-frame-diamondmetal-edgetop" },
		BottomEdge = { atlas = "_ui-frame-diamondmetal-edgebottom" },
		LeftEdge = { atlas = "!ui-frame-diamondmetal-edgeleft" },
		RightEdge = { atlas = "!ui-frame-diamondmetal-edgeright" },
	},
	ButtonFrameTemplateNoPortrait = {
		TopLeftCorner = { layer = "OVERLAY", atlas = "ui-frame-metal-cornertopleft", x = -8, y = 16 },
		TopRightCorner = { layer = "OVERLAY", atlas = "ui-frame-metal-cornertopright", x = 2, y = 16 },
		BottomLeftCorner = { layer = "OVERLAY", atlas = "ui-frame-metal-cornerbottomleft", x = -8, y = -8 },
		BottomRightCorner = { layer = "OVERLAY", atlas = "ui-frame-metal-cornerbottomright", x = 2, y = -8 },
		TopEdge = { layer = "OVERLAY", atlas = "_ui-frame-metal-edgetop" },
		BottomEdge = { layer = "OVERLAY", atlas = "_ui-frame-metal-edgebottom" },
		LeftEdge = { layer = "OVERLAY", atlas = "!ui-frame-metal-edgeleft" },
		RightEdge = { layer = "OVERLAY", atlas = "!ui-frame-metal-edgeright" },
	},
	InsetFrameTemplate = {
		TopLeftCorner = { atlas = "ui-frame-innertopleft" },
		TopRightCorner = { atlas = "ui-frame-innertopright" },
		BottomLeftCorner = { atlas = "ui-frame-innerbotleftcorner", x = 0, y = -1 },
		BottomRightCorner = { atlas = "ui-frame-innerbotright", x = 0, y = -1 },
		TopEdge = { atlas = "_ui-frame-innertoptile" },
		BottomEdge = { atlas = "_ui-frame-innerbottile" },
		LeftEdge = { atlas = "!ui-frame-innerlefttile" },
		RightEdge = { atlas = "!ui-frame-innerrighttile" },
	},
}

-- piece order and anchors of nineSliceSetup (nineslice.lua)
local PIECES = {
	{ "TopLeftCorner", "TOPLEFT" },
	{ "TopRightCorner", "TOPRIGHT" },
	{ "BottomLeftCorner", "BOTTOMLEFT" },
	{ "BottomRightCorner", "BOTTOMRIGHT" },
	{ "TopEdge", "TOPLEFT", "TOPRIGHT", "TopLeftCorner", "TopRightCorner" },
	{ "BottomEdge", "BOTTOMLEFT", "BOTTOMRIGHT", "BottomLeftCorner", "BottomRightCorner" },
	{ "LeftEdge", "TOPLEFT", "BOTTOMLEFT", "TopLeftCorner", "BottomLeftCorner" },
	{ "RightEdge", "TOPRIGHT", "BOTTOMRIGHT", "TopRightCorner", "BottomRightCorner" },
	{ "Center" },
}

-- Applies a layout as regions of host (a child frame would cover its texts).
-- target: rectangle the corners anchor to (host by default); layer: overrides the layout's
-- layer (3.3.5 has no sublevels). Returns the pieces by name.
function Tpl.NineSlice(host, layoutName, target, layer)
	local layout = Tpl.LAYOUTS[layoutName]
	local p = {}
	for _, m in ipairs(PIECES) do
		local name = m[1]
		local l = layout[name]
		if l then
			local t = host:CreateTexture(nil, layer or l.layer or "BORDER")
			p[name] = t
			if name == "Center" then
				local e = Tpl.Place(t, l.atlas, true)
				t:SetPoint("TOPLEFT", p.TopLeftCorner, "BOTTOMRIGHT", l.x or 0, l.y or 0)
				t:SetPoint("BOTTOMRIGHT", p.BottomRightCorner, "TOPLEFT", l.x1 or 0, l.y1 or 0)
				tile(t, e)
			elseif m[3] then
				local e = Tpl.Place(t, l.atlas, true)
				t:SetPoint(m[2], p[m[4]], m[3], l.x or 0, l.y or 0)
				t:SetPoint(m[3], p[m[5]], m[2], l.x1 or 0, l.y1 or 0)
				tile(t, e)
			else
				Tpl.Place(t, l.atlas, true)
				t:SetPoint(l.point or m[2], target or host, l.relativePoint or l.point or m[2], l.x or 0, l.y or 0)
			end
		end
	end
	return p
end

-- NineSlicePanel SetCenterColor / SetBorderColor; center, edge: { r, g, b[, a] } or nil
function Tpl.Colors(p, center, edge)
	for name, t in pairs(p) do
		local c = (name == "Center") and center or edge
		if c then
			t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		end
	end
end

-- ------------------------------------------------------------ Dialog

-- DialogBorderTemplate: UI-DialogBox-Background tiled 7 from the edge, Dialog layout
-- (DialogBorderNoCenterTemplate)
function Tpl.DialogFrame(host)
	local SEP = string.char(92)
	local background = host:CreateTexture(nil, "BACKGROUND")
	background:SetTexture("Interface" .. SEP .. "DialogFrame" .. SEP .. "UI-DialogBox-Background", true)
	if background.SetHorizTile then
		background:SetHorizTile(true)
		background:SetVertTile(true)
	end
	background:SetPoint("TOPLEFT", host, "TOPLEFT", 7, -7)
	background:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -7, 7)
	return Tpl.NineSlice(host, "Dialog"), background
end

-- DialogHeaderTemplate: 200 x 39 at TOP (0, 11); 32 x 39 corners, tile between them;
-- text at TOP (0, -13); width = text + margin (headerTextPadding, 64 by default)
function Tpl.Header(parent, text, font, margin)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(200)
	f:SetHeight(39)
	f:SetPoint("TOP", parent, "TOP", 0, 11)
	local g = f:CreateTexture(nil, "ARTWORK")
	Tpl.Place(g, "ui-frame-diamondmetal-header-cornerleft", true)
	g:SetPoint("LEFT", f, "LEFT")
	local d = f:CreateTexture(nil, "ARTWORK")
	Tpl.Place(d, "ui-frame-diamondmetal-header-cornerright", true)
	d:SetPoint("RIGHT", f, "RIGHT")
	local c = f:CreateTexture(nil, "ARTWORK")
	Tpl.Place(c, "_ui-frame-diamondmetal-header-tile")
	c:SetPoint("TOPLEFT", g, "TOPRIGHT")
	c:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	local t = f:CreateFontString(nil, "ARTWORK")
	t:SetFontObject(font or GameFontNormal)
	t:SetPoint("TOP", f, "TOP", 0, -13)
	f.Text = t
	function f:Place(text2)
		self.Text:SetText(text2 or "")
		self:SetWidth(self.Text:GetStringWidth() + (margin or 64))
	end
	f:Place(text)
	return f
end

-- ------------------------------------------------------------ Window

-- ButtonFrameTemplate without portrait (shareduipaneltemplates.xml / .lua): metal frame
-- ButtonFrameTemplateNoPortrait, top streaks, GameFontNormal title in a child frame
-- (TitleContainer) so it draws above the metal. Background: translucent black 0.8
-- (DialogBorderTranslucentTemplate) instead of the rock. Returns the parts by name.
function Tpl.Window(host, title)
	local background = host:CreateTexture(nil, "BACKGROUND")
	background:SetTexture(0, 0, 0, 0.8)
	background:SetPoint("TOPLEFT", host, "TOPLEFT", 7, -21)
	background:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -2, 2)
	local stripes = host:CreateTexture(nil, "BORDER")
	Tpl.Place(stripes, "_ui-frame-toptilestreaks", true)
	stripes:SetPoint("TOPLEFT", host, "TOPLEFT", 6, -21)
	stripes:SetPoint("TOPRIGHT", host, "TOPRIGHT", -2, -21)
	local frame = Tpl.NineSlice(host, "ButtonFrameTemplateNoPortrait")
	local container = CreateFrame("Frame", nil, host)
	container:SetFrameLevel(host:GetFrameLevel() + 10)
	container:SetHeight(20)
	container:SetPoint("TOPLEFT", host, "TOPLEFT", 0, -1)
	container:SetPoint("TOPRIGHT", host, "TOPRIGHT", 0, -1)
	local t = container:CreateFontString(nil, "OVERLAY")
	t:SetFontObject(GameFontNormal)
	t:SetPoint("TOP", container, "TOP", 0, -5)
	t:SetPoint("LEFT", container, "LEFT")
	t:SetPoint("RIGHT", container, "RIGHT")
	t:SetText(title or "")
	return { title = t, frame = frame, background = background, stripes = stripes, container = container }
end

-- InsetFrameTemplate without the marble background (translucent window, see Tpl.Window):
-- the border as host regions, fitted to target
function Tpl.Inset(host, target)
	return Tpl.NineSlice(host, "InsetFrameTemplate", target)
end

-- UIPanelCloseButton: 24 x 24, RedButton-Exit states, ADD RedButton-Highlight glow;
-- at TOPRIGHT (-2, 1) of window (UIPanelCloseButtonDefaultAnchorsMixin)
function Tpl.CloseButton(b, window)
	b:SetWidth(24)
	b:SetHeight(24)
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, 1)
	for _, v in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetDisabledTexture", "GetDisabledTexture", "redbutton-exit-disabled" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		b[v[1]](b, ART[v[3]][1])
		local t = b[v[2]](b)
		Tpl.Place(t, v[3])
		t:ClearAllPoints()
		t:SetAllPoints(b)
		if v[1] == "SetHighlightTexture" then
			t:SetBlendMode("ADD")
		end
	end
	return b
end

-- clears the art the 3.3.5 client puts on its own buttons
function Tpl.ClearArt(b)
	for _, read in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local t = b[read] and b[read](b)
		if t then
			t:SetTexture(nil)
		end
	end
end

-- ------------------------------------------------------------ Red button

-- Source: blizzard_sharedxml/shared/button/threeslicebuttontemplate.xml / .lua. Left and Right
-- keep their atlas size scaled to the button height, Center stretches between them; if Left
-- and Right do not fit the width they are cropped (UpdateScale). -Pressed and -Disabled states,
-- atlasName-Highlight glow, text pushed by (-2, -1) (BigRedThreeSliceButtonTemplate).

-- crops t to a fraction part of element e, keeping its left side if leftToRight
local function cropTexture(t, e, leftToRight, part)
	local u1, u2 = e[2], e[3]
	if leftToRight then
		t:SetTexCoord(u1, u1 + (u2 - u1) * part, e[4], e[5])
	else
		t:SetTexCoord(u2 - (u2 - u1) * part, u2, e[4], e[5])
	end
end

-- sets the three slices for state (NORMAL or PUSHED), then applies UpdateScale
local function paintThreeSlices(b, state)
	local r = b.foreverThreeSlice
	if not truthy(b:IsEnabled()) then
		state = "DISABLED"
	end
	local suffix = ""
	if state == "DISABLED" then
		suffix = "-disabled"
	elseif state == "PUSHED" then
		suffix = "-pressed"
	end
	local eg = Tpl.Place(r.left, r.atlas .. "-left" .. suffix)
	Tpl.Place(r.center, "_" .. r.atlas .. "-center" .. suffix)
	local ed = Tpl.Place(r.right, r.atlas .. "-right" .. suffix)

	-- UpdateScale
	local height, width = b:GetHeight(), b:GetWidth()
	local scale = height / eg[7]
	local lg, ld = eg[6] * scale, ed[6] * scale
	if lg + ld > width then
		local excess = lg + ld - width
		local ng, nd = lg, ld
		if (lg - excess) > ld then
			ng = lg - excess
		elseif (ld - excess) > lg then
			nd = ld - excess
		else
			if lg ~= ld then
				excess = excess - math.abs(lg - ld)
				ng = math.min(lg, ld)
				nd = ng
			end
			ng = ng - excess / 2
			nd = nd - excess / 2
		end
		cropTexture(r.left, eg, true, ng / lg)
		cropTexture(r.right, ed, false, nd / ld)
		lg, ld = ng, nd
	end
	r.left:SetWidth(lg)
	r.left:SetHeight(height)
	r.right:SetWidth(ld)
	r.right:SetHeight(height)
	r.active = truthy(b:IsEnabled())
end

-- Restyles button b as a Camelot three-slice button.
-- atlas: lowercase prefix (e.g. 128-redbutton); fonts: font objects { normal, highlight, disabled }
function Tpl.ThreeSliceButton(b, atlas, fonts)
	Tpl.ClearArt(b)
	local r = { atlas = atlas }
	r.left = b:CreateTexture(nil, "BACKGROUND")
	r.left:SetPoint("TOPLEFT", b, "TOPLEFT")
	r.right = b:CreateTexture(nil, "BACKGROUND")
	r.right:SetPoint("TOPRIGHT", b, "TOPRIGHT")
	r.center = b:CreateTexture(nil, "BACKGROUND")
	r.center:SetPoint("TOPLEFT", r.left, "TOPRIGHT")
	r.center:SetPoint("BOTTOMRIGHT", r.right, "BOTTOMLEFT")
	b.foreverThreeSlice = r

	-- glow: SetHighlightAtlas over the whole button, ADD blend
	b:SetHighlightTexture(ART[atlas .. "-highlight"][1])
	local h = b:GetHighlightTexture()
	Tpl.Place(h, atlas .. "-highlight")
	h:ClearAllPoints()
	h:SetAllPoints(b)
	h:SetBlendMode("ADD")

	if fonts then
		b:SetNormalFontObject(fonts[1])
		b:SetHighlightFontObject(fonts[2] or fonts[1])
		b:SetDisabledFontObject(fonts[3] or fonts[1])
	end
	local text = b:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
	b:SetPushedTextOffset(-2, -1)

	b:HookScript("OnMouseDown", function(self)
		if truthy(self:IsEnabled()) then
			paintThreeSlices(self, "PUSHED")
		end
	end)
	b:HookScript("OnMouseUp", function(self) paintThreeSlices(self, "NORMAL") end)
	b:HookScript("OnShow", function(self) paintThreeSlices(self, "NORMAL") end)
	b:HookScript("OnSizeChanged", function(self) paintThreeSlices(self, "NORMAL") end)
	b:HookScript("OnEnable", function(self) paintThreeSlices(self, "NORMAL") end)
	b:HookScript("OnDisable", function(self) paintThreeSlices(self, "NORMAL") end)
	paintThreeSlices(b, "NORMAL")
	return b
end

-- ------------------------------------------------------------ Panel button

-- UIPanelButtonTemplate: three pieces of UI-Panel-Button-Up (12 / rest / 12), -Down when
-- pressed, -Disabled when disabled; ADD UI-Panel-Button-Highlight glow; centered text,
-- GameFontNormal / Highlight / Disable. Camelot uses the same image; only the 3.3.5 gray
-- button (UIPanelButtonGrayTemplate) differs.
function Tpl.PanelButton(b)
	local SEP = string.char(92)
	local PANEL = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Panel-Button-"
	Tpl.ClearArt(b)
	local g = b:CreateTexture(nil, "BACKGROUND")
	g:SetWidth(12)
	g:SetPoint("TOPLEFT", b, "TOPLEFT")
	g:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT")
	local d = b:CreateTexture(nil, "BACKGROUND")
	d:SetWidth(12)
	d:SetPoint("TOPRIGHT", b, "TOPRIGHT")
	d:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT")
	local m = b:CreateTexture(nil, "BACKGROUND")
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	local pieces = { { g, 0, 0.09375 }, { m, 0.09375, 0.53125 }, { d, 0.53125, 0.625 } }
	local function file(name)
		for _, v in ipairs(pieces) do
			v[1]:SetTexture(PANEL .. name)
			v[1]:SetTexCoord(v[2], v[3], 0, 0.6875)
		end
	end
	local function idle()
		file(truthy(b:IsEnabled()) and "Up" or "Disabled")
	end
	idle()
	b:HookScript("OnMouseDown", function()
		if truthy(b:IsEnabled()) then file("Down") end
	end)
	b:HookScript("OnMouseUp", idle)
	b:HookScript("OnShow", idle)
	b:HookScript("OnDisable", idle)
	b:HookScript("OnEnable", idle)
	b:SetHighlightTexture(PANEL .. "Highlight")
	local h = b:GetHighlightTexture()
	h:SetTexCoord(0, 0.625, 0, 0.6875)
	h:SetBlendMode("ADD")
	h:ClearAllPoints()
	h:SetAllPoints(b)
	b:SetNormalFontObject(GameFontNormal)
	b:SetHighlightFontObject(GameFontHighlight)
	b:SetDisabledFontObject(GameFontDisable)
	local text = b:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
end

-- ------------------------------------------------------------ Windows-1252

-- Audio output names (Sound_GameSystem_GetOutputDriverNameByIndex) come in the system code
-- page (Windows-1252), but the client renders them as UTF-8, which breaks accented letters.
-- Invalid UTF-8 strings are converted for display; the stored value stays the client's.

-- Windows-1252 0x80 to 0x9F; 0xA0 to 0xFF map to their own code point
local CP1252 = {
	[0x80] = 0x20AC, [0x82] = 0x201A, [0x83] = 0x0192, [0x84] = 0x201E, [0x85] = 0x2026,
	[0x86] = 0x2020, [0x87] = 0x2021, [0x88] = 0x02C6, [0x89] = 0x2030, [0x8A] = 0x0160,
	[0x8B] = 0x2039, [0x8C] = 0x0152, [0x8E] = 0x017D, [0x91] = 0x2018, [0x92] = 0x2019,
	[0x93] = 0x201C, [0x94] = 0x201D, [0x95] = 0x2022, [0x96] = 0x2013, [0x97] = 0x2014,
	[0x98] = 0x02DC, [0x99] = 0x2122, [0x9A] = 0x0161, [0x9B] = 0x203A, [0x9C] = 0x0153,
	[0x9E] = 0x017E, [0x9F] = 0x0178,
}

local function toUtf8(cp)
	if cp < 0x80 then
		return string.char(cp)
	elseif cp < 0x800 then
		return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
	end
	return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

local function isValidUtf8(s)
	local i, n = 1, string.len(s)
	while i <= n do
		local c = string.byte(s, i)
		local tail
		if c < 0x80 then
			tail = 0
		elseif c >= 0xC2 and c <= 0xDF then
			tail = 1
		elseif c >= 0xE0 and c <= 0xEF then
			tail = 2
		elseif c >= 0xF0 and c <= 0xF4 then
			tail = 3
		else
			return false
		end
		for j = 1, tail do
			local d = string.byte(s, i + j)
			if not d or d < 0x80 or d > 0xBF then
				return false
			end
		end
		i = i + tail + 1
	end
	return true
end

-- converts a Windows-1252 string to UTF-8; a valid UTF-8 string is returned unchanged
function Tpl.Utf8Text(s)
	if type(s) ~= "string" or isValidUtf8(s) then
		return s
	end
	return (string.gsub(s, "[\128-\255]", function(ch)
		local b = string.byte(ch)
		return toUtf8(CP1252[b] or b)
	end))
end

-- ------------------------------------------------------------ Overlaid scroll bar

-- Camelot's MinimalScrollBar art (ScrollBar.lua: 17 x 11 arrows, track, 8 wide thumb) laid
-- over the client's UIPanelScrollBarTemplate, whose textures go to alpha 0. The art frame takes
-- no mouse input: the client bar still handles clicks, drags and the wheel, so scrolling stays
-- on the client path (see Settings.lua). The art is a child of the bar and hides with it.
-- The thumb keeps the client's fixed size, not the visible fraction.
local BAR = {
	width = 8, tip = 8,
	upArrow = "minimal-scrollbar-arrow-top-c60", upArrowHover = "minimal-scrollbar-arrow-top-over-c60",
	downArrow = "minimal-scrollbar-arrow-bottom-c60", downArrowHover = "minimal-scrollbar-arrow-bottom-over-c60",
	trackTop = "minimal-scrollbar-track-top-c60", trackMiddle = "!minimal-scrollbar-track-middle-c60",
	trackBottom = "minimal-scrollbar-track-bottom-c60",
	cursorTip = "minimal-scrollbar-thumb-top-c60", cursorMiddle = "minimal-scrollbar-thumb-middle-c60",
}

-- hides the state textures of a client button (alpha 0)
local function turnOff(b)
	for _, read in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local t = b[read] and b[read](b)
		if t then t:SetAlpha(0) end
	end
end

function Tpl.Bar(sb)
	if not sb or sb.foreverBar then return sb and sb.foreverBar end
	local B = BAR
	local thumb = sb:GetThumbTexture()
	if thumb then thumb:SetAlpha(0) end
	local v = CreateFrame("Frame", nil, sb)
	v:SetAllPoints(sb)
	v:SetFrameLevel(sb:GetFrameLevel() + 5)
	-- arrows over the client's buttons, at the element's size
	local function arrow(button, atlas, hover)
		if not button then return nil end
		turnOff(button)
		local t = v:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(t, atlas)
		t:SetPoint("CENTER", button, "CENTER", 0, 0)
		button:HookScript("OnEnter", function() ForeverUI.SetAtlas(t, hover, true) end)
		button:HookScript("OnLeave", function() ForeverUI.SetAtlas(t, atlas, true) end)
		return t
	end
	local name = sb:GetName()
	v.top = arrow(name and _G[name .. "ScrollUpButton"], B.upArrow, B.upArrowHover)
	v.down = arrow(name and _G[name .. "ScrollDownButton"], B.downArrow, B.downArrowHover)
	local function slice(atlas, layer)
		local t = v:CreateTexture(nil, layer)
		ForeverUI.SetAtlas(t, atlas)
		t:SetWidth(B.width)
		return t
	end
	local ph = slice(B.trackTop, "BACKGROUND")
	ph:SetPoint("TOP", sb, "TOP", 0, 0)
	local pb = slice(B.trackBottom, "BACKGROUND")
	pb:SetPoint("BOTTOM", sb, "BOTTOM", 0, 0)
	local pm = slice(B.trackMiddle, "BACKGROUND")
	pm:SetPoint("TOP", ph, "BOTTOM", 0, 0)
	pm:SetPoint("BOTTOM", pb, "TOP", 0, 0)
	if thumb then
		local ch = slice(B.cursorTip, "ARTWORK")
		ch:SetHeight(B.tip)
		ch:SetPoint("TOP", thumb, "TOP", 0, 0)
		local cb = slice(B.cursorTip, "ARTWORK")
		local e = ForeverUI.AtlasEntry(B.cursorTip)
		cb:SetTexCoord(e[2], e[3], e[5], e[4])
		cb:SetHeight(B.tip)
		cb:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
		local cm = slice(B.cursorMiddle, "ARTWORK")
		cm:SetPoint("TOP", ch, "BOTTOM", 0, 0)
		cm:SetPoint("BOTTOM", cb, "TOP", 0, 0)
		v.cursor = { ch, cm, cb }
	end
	sb.foreverBar = v
	return v
end

-- Places a client scroll frame's bar where Camelot puts it (ScrollFrame_OnLoad: scrollBarX,
-- scrollBarTopY, scrollBarBottomY from target's TOPRIGHT / BOTTOMRIGHT): the client's 16 wide
-- Slider centered on MinimalScrollBar's 8, its 11 high arrows above and below, then restyled.
function Tpl.BarAt(sb, target, x, top, down)
	local half = (16 - 8) / 2
	sb:ClearAllPoints()
	sb:SetPoint("TOPLEFT", target, "TOPRIGHT", x - half, top - 11)
	sb:SetPoint("BOTTOMLEFT", target, "BOTTOMRIGHT", x - half, down + 11)
	return Tpl.Bar(sb)
end

-- ------------------------------------------------------------ Scroll bar by content

-- Every scroll bar hides when nothing scrolls, and the content adapts to its presence.
-- GUTTER: room the content gains when a Camelot bar goes (8 wide, 6 to 9 from the content).
Tpl.GUTTER = 20

-- Client scroll frame (UIPanelScrollFrameTemplate): 3.3.5 hides its bar when the range is zero
-- if the frame has scrollBarHideable (ScrollFrame_OnScrollRangeChanged). The range is also read
-- on show, as the client only reads it on change. adapter(hasBar): called on each update while
-- visible, gives or takes the bar's room from the content (idempotent). Widening can only
-- shorten the text, so it cannot oscillate.
function Tpl.BarByContent(fx, adapter)
	fx.scrollBarHideable = 1
	local sb = _G[fx:GetName() .. "ScrollBar"]
	local function update()
		local hasBar = math.floor(fx:GetVerticalScrollRange() or 0) > 0
		if sb then Tpl.SetShown(sb, hasBar) end
		if adapter and fx:IsVisible() then adapter(hasBar) end
	end
	fx:HookScript("OnScrollRangeChanged", update)
	fx:HookScript("OnShow", update)
	update()
	return update
end

-- FauxScrollFrame list: FauxScrollFrame_Update hides the frame (and its bar) when all fits;
-- adapter(hasBar) follows its own IsShown state (a hidden parent does not count as absent).
function Tpl.FauxByContent(fx, adapter)
	local function update() adapter(fx:IsShown() and true or false) end
	fx:HookScript("OnShow", update)
	fx:HookScript("OnHide", update)
	update()
	return update
end

-- ------------------------------------------------------------ Silver button

-- UIMenuButtonStretchTemplate (mainline/shareduipaneltemplates.xml / .lua), used by Camelot's
-- key bindings: UI-Silver-Button-Up in nine pieces with 12 x 6 corners; -Down while pressed;
-- ADD UI-Silver-Button-Highlight glow; text CENTER (0, -1), GameFontHighlightSmall, disabled
-- GameFontDisableSmall. Both clients have the same image.
local SILVER = {
	us = { 0, 0.09375, 0.53125, 0.625 },
	vs = { 0, 0.1875, 0.625, 0.8125 },
	corner = { 12, 6 },
}

function Tpl.SilverButton(b)
	if b.foreverSilver then return end
	local SEP = string.char(92)
	local file = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Silver-Button-"
	local name = b:GetName()
	-- the client's art: its three named pieces (UIPanelButtonTemplate2), which its scripts
	-- retexture, are hidden by alpha, which they do not touch; so are its state textures
	for _, s in ipairs({ "Left", "Middle", "Right" }) do
		local t = name and _G[name .. s]
		if t then t:SetAlpha(0) end
	end
	turnOff(b)
	local A = SILVER
	local p = {}
	for row = 1, 3 do
		for col = 1, 3 do
			local t = b:CreateTexture(nil, "BACKGROUND")
			t:SetTexCoord(A.us[col], A.us[col + 1], A.vs[row], A.vs[row + 1])
			p[#p + 1] = t
			t.foreverCol, t.foreverRow = col, row
		end
	end
	local function piece(col, row)
		return p[(row - 1) * 3 + col]
	end
	for _, t in ipairs(p) do
		local col, row = t.foreverCol, t.foreverRow
		if col == 1 then
			t:SetPoint("LEFT", b, "LEFT", 0, 0)
			t:SetWidth(A.corner[1])
		elseif col == 3 then
			t:SetPoint("RIGHT", b, "RIGHT", 0, 0)
			t:SetWidth(A.corner[1])
		else
			t:SetPoint("LEFT", piece(1, row), "RIGHT", 0, 0)
			t:SetPoint("RIGHT", piece(3, row), "LEFT", 0, 0)
		end
		if row == 1 then
			t:SetPoint("TOP", b, "TOP", 0, 0)
			t:SetHeight(A.corner[2])
		elseif row == 3 then
			t:SetPoint("BOTTOM", b, "BOTTOM", 0, 0)
			t:SetHeight(A.corner[2])
		else
			t:SetPoint("TOP", piece(col, 1), "BOTTOM", 0, 0)
			t:SetPoint("BOTTOM", piece(col, 3), "TOP", 0, 0)
		end
	end
	local function state(suffix)
		for _, t in ipairs(p) do t:SetTexture(file .. suffix) end
	end
	state("Up")
	b:SetHighlightTexture(file .. "Highlight")
	local h = b:GetHighlightTexture()
	h:SetTexCoord(0, 1, 0.03, 0.7175)
	h:SetBlendMode("ADD")
	h:SetAlpha(1)
	h:ClearAllPoints()
	h:SetAllPoints(b)
	b:HookScript("OnMouseDown", function(self)
		if truthy(self:IsEnabled()) then state("Down") end
	end)
	b:HookScript("OnMouseUp", function() state("Up") end)
	b:HookScript("OnShow", function() state("Up") end)
	b:HookScript("OnEnable", function() state("Up") end)
	b:SetNormalFontObject(GameFontHighlightSmall)
	b:SetHighlightFontObject(GameFontHighlightSmall)
	b:SetDisabledFontObject(GameFontDisableSmall)
	local text = b:GetFontString()
	if text then
		text:ClearAllPoints()
		text:SetPoint("CENTER", b, "CENTER", 0, -1)
	end
	b.foreverSilver = p
end

-- ------------------------------------------------------------ Portrait window

-- ButtonFrameTemplate with portrait, numbers from the Social window (camelot/friendsframe.xml):
-- tiled UI-Background-Rock, top streaks, PortraitFrameTemplate metal in a child frame at +20,
-- title in a 20 high band at +21, portrait in a child frame at +19 under the metal ring.
-- Regions of f stay under the metal.
-- o = { portrait = file, portraitSide, portraitX, portraitY, title = text }
local PORTRAIT = {
	metal = {
		{ name = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
		{ name = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
		{ name = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
		{ name = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
	},
	title = { x1 = 58, x2 = -24, y = -1, h = 20, textY = -5 },
}

function Tpl.PortraitWindow(f, o)
	local SEP = string.char(92)
	local rock = f:CreateTexture(nil, "BACKGROUND")
	rock:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock", true)
	if rock.SetHorizTile then rock:SetHorizTile(true) rock:SetVertTile(true) end
	rock:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -21)
	rock:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
	local stripes = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(stripes, "_ui-frame-toptilestreaks", true)
	stripes:SetHeight(43)
	stripes:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -21)
	stripes:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -21)
	local metal = CreateFrame("Frame", nil, f)
	metal:SetAllPoints(f)
	metal:SetFrameLevel(f:GetFrameLevel() + 20)
	local p = {}
	for i, corner in ipairs(PORTRAIT.metal) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, corner.name)
		t:SetPoint(corner.point, metal, corner.point, corner.x, corner.y)
		p[i] = t
	end
	local function edge(name, a1, c1, r1, a2, c2, r2)
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, name)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
	end
	edge("_ui-frame-metal-edgetop", "TOPLEFT", p[1], "TOPRIGHT", "TOPRIGHT", p[2], "TOPLEFT")
	edge("_ui-frame-metal-edgebottom", "BOTTOMLEFT", p[3], "BOTTOMRIGHT", "BOTTOMRIGHT", p[4], "BOTTOMLEFT")
	edge("!ui-frame-metal-edgeleft", "TOPLEFT", p[1], "BOTTOMLEFT", "BOTTOMLEFT", p[3], "TOPLEFT")
	edge("!ui-frame-metal-edgeright", "TOPRIGHT", p[2], "BOTTOMRIGHT", "BOTTOMRIGHT", p[4], "TOPRIGHT")
	local portraitFrame = CreateFrame("Frame", nil, f)
	portraitFrame:SetAllPoints(f)
	portraitFrame:SetFrameLevel(f:GetFrameLevel() + 19)
	local portrait = portraitFrame:CreateTexture(nil, "OVERLAY")
	portrait:SetWidth(o.portraitSide)
	portrait:SetHeight(o.portraitSide)
	portrait:SetPoint("TOPLEFT", f, "TOPLEFT", o.portraitX, o.portraitY)
	portrait:SetTexture(o.portrait)
	local T = PORTRAIT.title
	local banner = CreateFrame("Frame", nil, f)
	banner:SetFrameLevel(f:GetFrameLevel() + 21)
	banner:SetHeight(T.h)
	banner:SetPoint("TOPLEFT", f, "TOPLEFT", T.x1, T.y)
	banner:SetPoint("TOPRIGHT", f, "TOPRIGHT", T.x2, T.y)
	local title = banner:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOP", banner, "TOP", 0, T.textY)
	title:SetText(o.title or "")
	return { rock = rock, stripes = stripes, metal = metal, portrait = portrait, title = title,
		banner = banner, portraitFrame = portraitFrame }
end

-- ------------------------------------------------------------ Simple window

-- BaseBasicFrameTemplate (mainline/uipaneltemplates.xml): UI-Frame pieces as window regions,
-- at their virtual texture size (mainline/shareduipaneltemplates.xml); without a size, 3.3.5
-- draws a texture at the size of its whole sheet.
-- o.edges: layer of the bottom and side edges and bottom corners (BORDER by default, as Camelot).
local SIMPLE = {
	background = { 2, -21, -2, 2 }, titleBackground = { 2, -1, -25, -1 }, stripes = { 0, -21, -2, -21 },
	corners = { topLeft = { -6, 1 }, topRight = { 0, 1 }, bottomLeft = { -6, -5 }, bottomRight = { 0, -5 } },
	pieces = { titleBackground = 18, stripes = 43, topCorner = 33, bottomLeftCorner = 14, bottomRightCorner = 11,
		top = 28, down = 9, left = 16, right = 10 },
}

function Tpl.SimpleFrame(f, o)
	o = o or {}
	local SEP = string.char(92)
	local F, T, S, P = SIMPLE.background, SIMPLE.titleBackground, SIMPLE.stripes, SIMPLE.pieces
	local layer = o.edges or "BORDER"
	local rock = f:CreateTexture(nil, "BACKGROUND")
	rock:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock", true)
	if rock.SetHorizTile then rock:SetHorizTile(true) rock:SetVertTile(true) end
	rock:SetPoint("TOPLEFT", f, "TOPLEFT", F[1], F[2])
	rock:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", F[3], F[4])
	local titleBackground = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(titleBackground, "_ui-frame-titletilebg", true)
	titleBackground:SetHeight(P.titleBackground)
	titleBackground:SetPoint("TOPLEFT", f, "TOPLEFT", T[1], T[2])
	titleBackground:SetPoint("TOPRIGHT", f, "TOPRIGHT", T[3], T[4])
	local stripes = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(stripes, "_ui-frame-toptilestreaks", true)
	stripes:SetHeight(P.stripes)
	stripes:SetPoint("TOPLEFT", f, "TOPLEFT", S[1], S[2])
	stripes:SetPoint("TOPRIGHT", f, "TOPRIGHT", S[3], S[4])
	local C = SIMPLE.corners
	local function corner(atlas, c, point, p, side)
		local t = f:CreateTexture(nil, c)
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetWidth(side)
		t:SetHeight(side)
		t:SetPoint(point, f, point, p[1], p[2])
		return t
	end
	local topLeft = corner("ui-frame-topleftcornernoportrait", "OVERLAY", "TOPLEFT", C.topLeft, P.topCorner)
	local topRight = corner("ui-frame-topcornerright", "OVERLAY", "TOPRIGHT", C.topRight, P.topCorner)
	local bottomLeft = corner("ui-frame-botcornerleft", layer, "BOTTOMLEFT", C.bottomLeft, P.bottomLeftCorner)
	local bottomRight = corner("ui-frame-botcornerright", layer, "BOTTOMRIGHT", C.bottomRight, P.bottomRightCorner)
	-- an edge: length from its two anchors, fixed thickness
	local function edge(atlas, c, thickness, horizontal, a1, c1, r1, a2, c2, r2, x)
		local t = f:CreateTexture(nil, c)
		ForeverUI.SetAtlas(t, atlas, true)
		if horizontal then t:SetHeight(thickness) else t:SetWidth(thickness) end
		t:SetPoint(a1, c1, r1, x or 0, 0)
		t:SetPoint(a2, c2, r2)
		return t
	end
	return {
		rock = rock, titleBackground = titleBackground, stripes = stripes, corners = { topLeft = topLeft, topRight = topRight, bottomLeft = bottomLeft, bottomRight = bottomRight },
		top = edge("_ui-frame-titletile", "OVERLAY", P.top, true, "TOPLEFT", topLeft, "TOPRIGHT", "TOPRIGHT", topRight, "TOPLEFT"),
		down = edge("_ui-frame-bot", layer, P.down, true, "BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", bottomRight, "BOTTOMLEFT"),
		left = edge("!ui-frame-lefttile", layer, P.left, false, "TOPLEFT", topLeft, "BOTTOMLEFT", "BOTTOMLEFT", bottomLeft, "TOPLEFT"),
		right = edge("!ui-frame-righttile", layer, P.right, false, "TOPRIGHT", topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", bottomRight, "TOPRIGHT", 1),
	}
end

-- ------------------------------------------------------------ Inner frame

-- Camelot's Options_InnerFrame (see Settings.lua) without its separator: 3 x 3 slices, 29 wide
-- edges, 82 high top and 167 high bottom gradients at their size, the rest stretched; fitted
-- to rect, as host regions.
local INNER = { cols = { 0, 29, 857, 886 }, ranks = { 0, 82, 451, 618 } }

function Tpl.InnerFrame(host, rect)
	local I = INNER
	local e = ForeverUI.AtlasEntry("options_innerframe")
	local du, dv = (e[3] - e[2]) / e[6], (e[5] - e[4]) / e[7]
	local pieces = {}
	for c = 1, 3 do
		for r = 1, 3 do
			local t = host:CreateTexture(nil, "ARTWORK")
			t:SetTexture(e[1])
			t:SetTexCoord(e[2] + I.cols[c] * du, e[2] + I.cols[c + 1] * du,
				e[4] + I.ranks[r] * dv, e[4] + I.ranks[r + 1] * dv)
			if c == 1 then
				t:SetPoint("LEFT", rect, "LEFT", 0, 0)
				t:SetWidth(I.cols[2])
			elseif c == 3 then
				t:SetPoint("RIGHT", rect, "RIGHT", 0, 0)
				t:SetWidth(I.cols[4] - I.cols[3])
			else
				t:SetPoint("LEFT", rect, "LEFT", I.cols[2], 0)
				t:SetPoint("RIGHT", rect, "RIGHT", -(I.cols[4] - I.cols[3]), 0)
			end
			if r == 1 then
				t:SetPoint("TOP", rect, "TOP", 0, 0)
				t:SetHeight(I.ranks[2])
			elseif r == 3 then
				t:SetPoint("BOTTOM", rect, "BOTTOM", 0, 0)
				t:SetHeight(I.ranks[4] - I.ranks[3])
			else
				t:SetPoint("TOP", rect, "TOP", 0, -I.ranks[2])
				t:SetPoint("BOTTOM", rect, "BOTTOM", 0, I.ranks[4] - I.ranks[3])
			end
			pieces[#pieces + 1] = t
		end
	end
	return pieces
end

-- ------------------------------------------------------------ Mirrored text

-- A client text that our background would cover goes to alpha 0; our copy in host, drawn above,
-- follows it in place after every SetText / SetFormattedText (post-hooks: the client writes
-- first). fs: client font string; font: font object of the copy (GameFontNormal by default).
function Tpl.Mirror(fs, host, font)
	local copy = host:CreateFontString(nil, "OVERLAY")
	copy:SetFontObject(font or GameFontNormal)
	copy:SetPoint("CENTER", fs, "CENTER", 0, 0)
	copy:SetText(fs:GetText() or "")
	fs:SetAlpha(0)
	local function follow()
		copy:SetText(fs:GetText() or "")
	end
	hooksecurefunc(fs, "SetText", follow)
	hooksecurefunc(fs, "SetFormattedText", follow)
	return copy
end

-- ------------------------------------------------------------ Item quality

-- Camelot ItemButton IconBorder: WhiteIconFrame 37 x 37 centered, OVERLAY, tinted by quality
-- (BAG_ITEM_QUALITY_COLORS); common in COMMON_GRAY_COLOR (Camelot GlobalColor.db2, see
-- QuestLog.lua), poor without outline (SetItemButtonQuality_Base).
local QUALITY = {
	outline = "Interface" .. string.char(92) .. "ForeverUI" .. string.char(92) .. "common" .. string.char(92) .. "whiteiconframe",
	commonGray = { 0.659, 0.659, 0.659 },
}

-- creates, once, the quality outline texture of item button b
function Tpl.Outline(b)
	if b.foreverOutline then return b.foreverOutline end
	local t = b:CreateTexture(nil, "OVERLAY")
	t:SetTexture(QUALITY.outline)
	t:SetWidth(37)
	t:SetHeight(37)
	t:SetPoint("CENTER", b, "CENTER", 0, 0)
	t:Hide()
	b.foreverOutline = t
	return t
end

-- shows the outline of item button b for quality q (nil: none)
function Tpl.QualityOutline(b, q)
	local t = Tpl.Outline(b)
	local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if q == 1 then
		local g = QUALITY.commonGray
		t:SetVertexColor(g[1], g[2], g[3])
		t:Show()
	elseif q and q >= 2 and c then
		t:SetVertexColor(c.r, c.g, c.b)
		t:Show()
	else
		t:Hide()
	end
end

-- MerchantFrameItem_UpdateQuality / TradeFrame_Update*Item: name in quality color
-- (NORMAL_FONT_COLOR if unknown), icon outlined. q is read from link when missing.
function Tpl.Quality(name, button, link, q)
	q = q or (link and select(3, GetItemInfo(link)))
	local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if name then
		if c then
			name:SetTextColor(c.r, c.g, c.b)
		else
			name:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		end
	end
	Tpl.QualityOutline(button, q)
end

-- ------------------------------------------------------------ Style 1 dropdown

-- WowStyle1DropdownTemplate (blizzard_menu/mainline/menutemplates.xml / .lua) laid over a
-- client UIDropDownMenuTemplate: 25 high; common-dropdown-textholder-c60 background in three
-- pieces; common-dropdown-a-button arrow with its GetWowStyle1ArrowButtonState states. The
-- client button covers the whole menu (a click anywhere opens it) and the style 1 list
-- (DropDown.lua) opens below it. The text color stays the client's.
local STYLE1 = { top = 25, background = { -8, 7, 8, -9 }, parts = { 16, 19 }, arrow = { 1, -3 }, text = { 8, -8, 10 },
	-- compact mode: opaque box of common-dropdown-textholder-c60 (columns 8 to 46 of 54,
	-- rows 7 to 32 of 41, shadow around it) and its 8 and 11 wide tips
	box = { 8, 46, 7, 32 }, boxTips = { 8, 11 }, compactText = 12 }
local style1Menus = {}

-- sets the arrow atlas matching the button state
local function paintStyle1(dd)
	local b = dd.foreverButton
	local state = "common-dropdown-a-button"
	if not truthy(b:IsEnabled()) then
		state = state .. "-disabled"
	elseif b.foreverMouseDown and b.foreverHovered then
		state = state .. "-pressedhover"
	elseif b.foreverHovered then
		state = state .. "-hover"
	elseif b.foreverMouseDown then
		state = state .. "-pressed"
	elseif DropDownList1 and DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU == dd then
		state = state .. "-open"
	end
	-- compact: arrow without shadow (Camelot -shadowless variants)
	if dd.foreverCompact then state = state .. "-shadowless" end
	ForeverUI.SetAtlas(dd.foreverArrow, state)
	-- at a height other than 25, the arrow follows the menu scale
	local k = dd.foreverScale or 1
	if k ~= 1 then
		local e = ForeverUI.AtlasEntry(state)
		if e then
			dd.foreverArrow:SetWidth(e[6] * k)
			dd.foreverArrow:SetHeight(e[7] * k)
		end
	end
end

-- Restyles client dropdown dd; width: menu width.
-- height: optional (25 by default, as Camelot); another height scales all the art for tighter
-- 3.3.5 layouts, the text keeps its font. compact: optional; the background is cropped to its
-- opaque box and the arrow has no shadow, so the frame is exactly the menu height.
function Tpl.MenuStyle1(dd, width, height, compact)
	if dd.foreverButton then return dd end
	local S = STYLE1
	local k = (height or S.top) / S.top
	dd.foreverScale = k
	dd.foreverCompact = compact and true or nil
	-- The height is enforced: UIDropDownMenu_Initialize (on each list opening, via
	-- ToggleDropDownMenu) resets the menu to 32 (UIDROPDOWNMENU_BUTTON_HEIGHT * 2);
	-- a hook below restores foreverHeight.
	dd.foreverHeight = S.top * k
	local name = dd:GetName()
	for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
		_G[name .. suffix]:SetAlpha(0)
	end
	dd:SetWidth(width)
	dd:SetHeight(S.top * k)
	local b = _G[name .. "Button"]
	dd.foreverButton = b
	b:ClearAllPoints()
	b:SetAllPoints(dd)
	Tpl.ClearArt(b)
	-- background: menu regions, under its text
	local e = ForeverUI.AtlasEntry("common-dropdown-textholder-c60")
	local rect = CreateFrame("Frame", nil, dd)
	local du, dv = (e[3] - e[2]) / e[6], (e[5] - e[4]) / e[7]
	-- art rectangle (u, v) and its tip widths
	local uLeft, uRight, vh, vb, bottomLeft, bottomRight
	if compact then
		rect:SetAllPoints(dd)
		uLeft, uRight = e[2] + S.box[1] * du, e[2] + S.box[2] * du
		vh, vb = e[4] + S.box[3] * dv, e[4] + S.box[4] * dv
		bottomLeft, bottomRight = S.boxTips[1], S.boxTips[2]
	else
		rect:SetPoint("TOPLEFT", dd, "TOPLEFT", S.background[1] * k, S.background[2] * k)
		rect:SetPoint("BOTTOMRIGHT", dd, "BOTTOMRIGHT", S.background[3] * k, S.background[4] * k)
		uLeft, uRight, vh, vb = e[2], e[3], e[4], e[5]
		bottomLeft, bottomRight = S.parts[1], S.parts[2]
	end
	local u1, u2 = uLeft + bottomLeft * du, uRight - bottomRight * du
	local function piece(a, z)
		local t = dd:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(e[1])
		t:SetTexCoord(a, z, vh, vb)
		return t
	end
	local g = piece(uLeft, u1)
	g:SetWidth(bottomLeft * k)
	g:SetPoint("TOPLEFT", rect, "TOPLEFT", 0, 0)
	g:SetPoint("BOTTOMLEFT", rect, "BOTTOMLEFT", 0, 0)
	local d = piece(u2, uRight)
	d:SetWidth(bottomRight * k)
	d:SetPoint("TOPRIGHT", rect, "TOPRIGHT", 0, 0)
	d:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT", 0, 0)
	local m = piece(u1, u2)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	dd.foreverBackground = { g, m, d }
	-- arrow on the button (child frame, above the background)
	local arrow = b:CreateTexture(nil, "OVERLAY")
	arrow:SetPoint("RIGHT", dd, "RIGHT", S.arrow[1] * k, S.arrow[2] * k)
	dd.foreverArrow = arrow
	local text = _G[name .. "Text"]
	text:SetFontObject(GameFontHighlight)
	text:SetJustifyH("LEFT")
	text:ClearAllPoints()
	if compact then
		-- compact: text on the arrow's line, centered on the menu height,
		-- up to the arrow's left edge
		text:SetHeight(S.compactText)
		text:SetPoint("LEFT", dd, "LEFT", S.text[1], 0)
		text:SetPoint("RIGHT", dd, "RIGHT", (S.arrow[1] - 27) * k, 0)
	else
		text:SetHeight(S.text[3])
		-- (8, -8) at height 25: the 10 high text centered, half a point lower;
		-- same rule at any height
		local textY = (k == 1) and S.text[2] or -((S.top * k - S.text[3]) / 2 + 0.5 * k)
		text:SetPoint("TOPLEFT", dd, "TOPLEFT", S.text[1], textY)
		text:SetPoint("TOPRIGHT", arrow, "LEFT", 0, 0)
	end
	UIDropDownMenu_SetAnchor(dd, 0, 0, "TOPLEFT", dd, "BOTTOMLEFT")
	b:HookScript("OnEnter", function(self) self.foreverHovered = true paintStyle1(dd) end)
	b:HookScript("OnLeave", function(self) self.foreverHovered = false paintStyle1(dd) end)
	b:HookScript("OnMouseDown", function(self) self.foreverMouseDown = true paintStyle1(dd) end)
	b:HookScript("OnMouseUp", function(self) self.foreverMouseDown = false paintStyle1(dd) end)
	b:HookScript("OnEnable", function() paintStyle1(dd) end)
	b:HookScript("OnDisable", function() paintStyle1(dd) end)
	dd:HookScript("OnShow", function() paintStyle1(dd) end)
	style1Menus[#style1Menus + 1] = dd
	paintStyle1(dd)
	return dd
end

-- ------------------------------------------------------------ Filter dropdown

-- WowStyle1FilterDropdownTemplate (blizzard_menu/mainline/menutemplates.xml 66-104,
-- menutemplates.lua 692-732, 991-1013): common-dropdown-b-button (c60) from (-4, 4) to
-- (4, -4) of the menu, three slices (8 and 18 tips, the arrow is in the right tip); text pushed
-- by (2, -1); width = text + 60 (resizeToText); list at (6, 2) below. The client
-- UIDropDownMenuTemplate keeps its logic. height: menu height.
local FILTER = { background = { -4, 4, 4, -4 }, parts = { 8, 18 }, textHeight = 20, pressed = { 2, -1 }, margin = 60,
	list = { 6, 2 } }
local filterMenus = {}

-- paints the background slices and the text offset for the button state
local function paintFilter(dd)
	local b = dd.foreverButton
	local state = ""
	if not truthy(b:IsEnabled()) then
		state = "-disabled"
	elseif b.foreverMouseDown and b.foreverHovered then
		state = "-pressedhover"
	elseif b.foreverHovered then
		state = "-hover"
	elseif b.foreverMouseDown then
		state = "-pressed"
	elseif DropDownList1 and DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU == dd then
		state = "-open"
	end
	local e = ForeverUI.AtlasEntry("common-dropdown-b-button" .. state .. "-c60")
		or ForeverUI.AtlasEntry("common-dropdown-b-button" .. state)
	if not e then return end
	local g, m, d = dd.foreverBackground[1], dd.foreverBackground[2], dd.foreverBackground[3]
	local du = (e[3] - e[2]) / e[6]
	local u1, u2 = e[2] + FILTER.parts[1] * du, e[3] - FILTER.parts[2] * du
	for _, t in ipairs(dd.foreverBackground) do t:SetTexture(e[1]) end
	g:SetTexCoord(e[2], u1, e[4], e[5])
	m:SetTexCoord(u1, u2, e[4], e[5])
	d:SetTexCoord(u2, e[3], e[4], e[5])
	local text = _G[dd:GetName() .. "Text"]
	text:ClearAllPoints()
	if b.foreverMouseDown and truthy(b:IsEnabled()) then
		text:SetPoint("TOP", dd, "TOP", FILTER.pressed[1], FILTER.pressed[2])
	else
		text:SetPoint("TOP", dd, "TOP", 0, 0)
	end
end

function Tpl.FilterMenu(dd, height)
	if dd.foreverButton then return dd end
	local F = FILTER
	local name = dd:GetName()
	for _, suffix in ipairs({ "Left", "Middle", "Right" }) do
		_G[name .. suffix]:SetAlpha(0)
	end
	-- enforced height (UIDropDownMenu_Initialize resets it to 32)
	dd.foreverHeight = height
	dd:SetHeight(height)
	local b = _G[name .. "Button"]
	dd.foreverButton = b
	b:ClearAllPoints()
	b:SetAllPoints(dd)
	Tpl.ClearArt(b)
	local rect = CreateFrame("Frame", nil, dd)
	rect:SetPoint("TOPLEFT", dd, "TOPLEFT", F.background[1], F.background[2])
	rect:SetPoint("BOTTOMRIGHT", dd, "BOTTOMRIGHT", F.background[3], F.background[4])
	local function piece()
		return dd:CreateTexture(nil, "BACKGROUND")
	end
	local g, m, d = piece(), piece(), piece()
	g:SetWidth(F.parts[1])
	g:SetPoint("TOPLEFT", rect, "TOPLEFT", 0, 0)
	g:SetPoint("BOTTOMLEFT", rect, "BOTTOMLEFT", 0, 0)
	d:SetWidth(F.parts[2])
	d:SetPoint("TOPRIGHT", rect, "TOPRIGHT", 0, 0)
	d:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT", 0, 0)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	dd.foreverBackground = { g, m, d }
	local text = _G[name .. "Text"]
	text:SetFontObject(GameFontNormal)
	text:SetJustifyH("CENTER")
	text:SetHeight(F.textHeight)
	-- width follows the text (resizeToText)
	local function width()
		dd:SetWidth((text:GetStringWidth() or 0) + F.margin)
		text:SetWidth(dd:GetWidth())
	end
	width()
	hooksecurefunc(text, "SetText", width)
	UIDropDownMenu_SetAnchor(dd, F.list[1], F.list[2], "TOPLEFT", dd, "BOTTOMLEFT")
	b:HookScript("OnEnter", function(self) self.foreverHovered = true paintFilter(dd) end)
	b:HookScript("OnLeave", function(self) self.foreverHovered = false paintFilter(dd) end)
	b:HookScript("OnMouseDown", function(self) self.foreverMouseDown = true paintFilter(dd) end)
	b:HookScript("OnMouseUp", function(self) self.foreverMouseDown = false paintFilter(dd) end)
	b:HookScript("OnEnable", function() paintFilter(dd) end)
	b:HookScript("OnDisable", function() paintFilter(dd) end)
	dd:HookScript("OnShow", function() paintFilter(dd) end)
	filterMenus[#filterMenus + 1] = dd
	paintFilter(dd)
	return dd
end

-- the arrow switches to open when the list opens and back when it closes; the client clears
-- UIDROPDOWNMENU_OPEN_MENU on close, so every menu of these styles is repainted
hooksecurefunc("ToggleDropDownMenu", function()
	for _, dd in ipairs(style1Menus) do paintStyle1(dd) end
	for _, dd in ipairs(filterMenus) do paintFilter(dd) end
end)
-- restores the requested height after the client (see Tpl.MenuStyle1)
hooksecurefunc("UIDropDownMenu_Initialize", function(dd)
	if dd and dd.foreverHeight then dd:SetHeight(dd.foreverHeight) end
end)
if DropDownList1 and DropDownList1.HookScript then
	DropDownList1:HookScript("OnHide", function()
		for _, dd in ipairs(style1Menus) do paintStyle1(dd) end
		for _, dd in ipairs(filterMenus) do paintFilter(dd) end
	end)
end
