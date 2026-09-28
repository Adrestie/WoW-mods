-- ForeverUI : les gabarits de camelot des fenetres reprises « 3.3.5
-- rhabillee » en jeu (menu Echap, reglages) -- le portage de ceux des
-- options des ecrans d'accueil, VALIDEES le 28/09 (ForeverUIGlue.lua,
-- ForeverUIGlueGabarits.lua) : memes elements, memes nombres.
--
-- L'ART. Les elements sont ceux de la table des ecrans d'accueil
-- (ForeverUIGlueAtlas.lua, tiree de l'index des atlas de camelot) : la
-- taille qu'y impose camelot (OverrideWidth / OverrideHeight, divisee par
-- la densite pour une feuille -2x), la mosaique (horizontale, verticale) et
-- la decoupe en neuf (UiTextureAtlasElementSliceData : gauche, haut, droite,
-- bas). La table du jeu (UIAtlas) ne porte ni l'une ni les autres : un coin
-- DiamondMetal y fait 128, la ou camelot le pose a 32. Les feuilles affinees
-- de l'accueil (coche minimalcheckbox-hd, curseur minimalsliderbarc60-hd)
-- servent ici aussi.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = {}
ForeverUI.Gabarits = Gb

-- { fichier, u1, u2, v1, v2, largeur, hauteur, mosaique horizontale,
--   mosaique verticale, decoupe { gauche, haut, droite, bas } }
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

-- 3.3.5 rend 1 / nil, parfois 0 / 1 : zero est vrai en Lua
local function vrai(v)
	return v and v ~= 0 and true or false
end
Gb.Vrai = vrai

function Gb.Art(nom)
	return ART[nom]
end

-- pose un element ; taille : prend sa taille (SetAtlas(nom, true)). Rend
-- l'entree.
function Gb.Poser(texture, nom, taille)
	local e = ART[nom]
	if not e then
		return nil
	end
	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[3], e[4], e[5])
	if taille then
		texture:SetWidth(e[6])
		texture:SetHeight(e[7])
	end
	return e
end

function Gb.Montrer(region, oui)
	if oui then region:Show() else region:Hide() end
end

-- une mosaique n'est possible, en 3.3.5, que sur une image entiere : un
-- element qui occupe toute sa feuille se repete, les autres s'etirent
local function mosaique(texture, e)
	local entiere = e[2] == 0 and e[3] == 1 and e[4] == 0 and e[5] == 1
	if entiere and (e[8] or e[9]) and texture.SetHorizTile then
		texture:SetTexture(e[1], true)
		texture:SetHorizTile(e[8] and true or false)
		texture:SetVertTile(e[9] and true or false)
	end
end

-- ------------------------------------------------------------ l'atlas etire

-- Un element a DECOUPE se dessine en neuf morceaux quand on l'etire : les
-- marges gardent leur taille, le reste s'etire. 3.3.5 n'a pas cette
-- decoupe : on pose les morceaux, en regions de l'hote, autour d'un
-- rectangle invisible que l'appelant ancre comme il ancrerait la texture de
-- camelot. Rend { rect = <texture a ancrer>, Poser(nom), Montrer(oui) }.
local function decouper(obj)
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
	local largeurs = { g, nil, dr }
	local hauteurs = { h, nil, b }
	local r = obj.rect
	local n = 0
	for ligne = 1, 3 do
		for col = 1, 3 do
			local lw, lh = largeurs[col], hauteurs[ligne]
			if (lw == nil or lw > 0) and (lh == nil or lh > 0) then
				n = n + 1
				local t = obj.pieces[n]
				if not t then
					t = obj.hote:CreateTexture(nil, obj.couche)
					obj.pieces[n] = t
				end
				t:SetTexture(e[1])
				t:SetTexCoord(us[col], us[col + 1], vs[ligne], vs[ligne + 1])
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
				if ligne == 1 then
					t:SetPoint("TOP", r, "TOP")
					t:SetHeight(lh)
				elseif ligne == 3 then
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
	obj.nombre = n
end

function Gb.AtlasEtire(hote, nom, couche)
	local obj = { hote = hote, couche = couche or "ARTWORK", pieces = {} }
	obj.rect = hote:CreateTexture(nil, obj.couche)
	function obj:Poser(n)
		self.e = ART[n]
		decouper(self)
	end
	function obj:Montrer(oui)
		self.visible = oui and true or false
		if self.e[10] then
			for i = 1, self.nombre or 0 do
				Gb.Montrer(self.pieces[i], oui)
			end
		else
			Gb.Montrer(self.rect, oui)
		end
	end
	function obj:Alpha(a)
		self.rect:SetAlpha(a)
		for _, t in ipairs(self.pieces) do
			t:SetAlpha(a)
		end
	end
	obj:Poser(nom)
	return obj
end

-- ------------------------------------------------------------ la decoupe en neuf

-- RELEVE -- blizzard_sharedxml/mainline/nineslicelayouts.lua (dispositions,
-- recopiees telles quelles) et nineslice.lua (ApplyLayout) ;
-- ButtonFrameTemplateNoPortrait apres camelot/NineSliceLayoutOverrides.lua.
Gb.DISPOSITIONS = {
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

-- l'ordre et les ancrages de nineSliceSetup (nineslice.lua)
local MORCEAUX = {
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

-- pose une disposition sur un cadre, en regions de ce cadre (un cadre fils
-- couvrirait ses textes). cible : le rectangle sur lequel se calent les
-- coins, l'hote par defaut. Rend les morceaux par nom.
function Gb.NeufTranches(hote, nomDisposition, cible)
	local disposition = Gb.DISPOSITIONS[nomDisposition]
	local p = {}
	for _, m in ipairs(MORCEAUX) do
		local nom = m[1]
		local l = disposition[nom]
		if l then
			local t = hote:CreateTexture(nil, l.layer or "BORDER")
			p[nom] = t
			if nom == "Center" then
				local e = Gb.Poser(t, l.atlas, true)
				t:SetPoint("TOPLEFT", p.TopLeftCorner, "BOTTOMRIGHT", l.x or 0, l.y or 0)
				t:SetPoint("BOTTOMRIGHT", p.BottomRightCorner, "TOPLEFT", l.x1 or 0, l.y1 or 0)
				mosaique(t, e)
			elseif m[3] then
				local e = Gb.Poser(t, l.atlas, true)
				t:SetPoint(m[2], p[m[4]], m[3], l.x or 0, l.y or 0)
				t:SetPoint(m[3], p[m[5]], m[2], l.x1 or 0, l.y1 or 0)
				mosaique(t, e)
			else
				Gb.Poser(t, l.atlas, true)
				t:SetPoint(l.point or m[2], cible or hote, l.relativePoint or l.point or m[2], l.x or 0, l.y or 0)
			end
		end
	end
	return p
end

-- SetCenterColor / SetBorderColor du NineSlicePanel
function Gb.Couleurs(p, centre, bord)
	for nom, t in pairs(p) do
		local c = (nom == "Center") and centre or bord
		if c then
			t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		end
	end
end

-- ------------------------------------------------------------ le dialogue

-- DialogBorderTemplate : fond UI-DialogBox-Background en mosaique a 7 du
-- bord, disposition Dialog (DialogBorderNoCenterTemplate)
function Gb.CadreDialogue(hote)
	local SEP = string.char(92)
	local fond = hote:CreateTexture(nil, "BACKGROUND")
	fond:SetTexture("Interface" .. SEP .. "DialogFrame" .. SEP .. "UI-DialogBox-Background", true)
	if fond.SetHorizTile then
		fond:SetHorizTile(true)
		fond:SetVertTile(true)
	end
	fond:SetPoint("TOPLEFT", hote, "TOPLEFT", 7, -7)
	fond:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", -7, 7)
	return Gb.NeufTranches(hote, "Dialog"), fond
end

-- DialogHeaderTemplate : 200 x 39 a TOP (0, 11) ; coins 32 x 39, tuile entre
-- eux ; texte TOP (0, -13) ; largeur = texte + headerTextPadding (64 par
-- defaut ; marge pour une autre valeur)
function Gb.EnTete(parent, texte, police, marge)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(200)
	f:SetHeight(39)
	f:SetPoint("TOP", parent, "TOP", 0, 11)
	local g = f:CreateTexture(nil, "ARTWORK")
	Gb.Poser(g, "ui-frame-diamondmetal-header-cornerleft", true)
	g:SetPoint("LEFT", f, "LEFT")
	local d = f:CreateTexture(nil, "ARTWORK")
	Gb.Poser(d, "ui-frame-diamondmetal-header-cornerright", true)
	d:SetPoint("RIGHT", f, "RIGHT")
	local c = f:CreateTexture(nil, "ARTWORK")
	Gb.Poser(c, "_ui-frame-diamondmetal-header-tile")
	c:SetPoint("TOPLEFT", g, "TOPRIGHT")
	c:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	local t = f:CreateFontString(nil, "ARTWORK")
	t:SetFontObject(police or GameFontNormal)
	t:SetPoint("TOP", f, "TOP", 0, -13)
	f.Text = t
	function f:Poser(texte2)
		self.Text:SetText(texte2 or "")
		self:SetWidth(self.Text:GetStringWidth() + (marge or 64))
	end
	f:Poser(texte)
	return f
end

-- ------------------------------------------------------------ la fenetre

-- ButtonFrameTemplate sans portrait (shareduipaneltemplates.xml / .lua) :
-- cadre de metal ButtonFrameTemplateNoPortrait, stries
-- _UI-Frame-TopTileStreaks de (6, -21) a (-2, -21), titre GameFontNormal
-- sur toute la largeur a 5 sous le haut (TitleContainer 20 de haut a
-- (0, -1)). Tout en regions de l'hote, le titre dans un cadre fils
-- (TitleContainer) : il passe au-dessus du metal. ECART (28/09, demande a
-- l'accueil et repris ici) : fond noir translucide a 0,8
-- (DialogBorderTranslucentTemplate) de (7, -21) a (-2, 2), a la place de la
-- pierre. Rend { titre, cadre, fond, stries }.
function Gb.Fenetre(hote, titre)
	local fond = hote:CreateTexture(nil, "BACKGROUND")
	fond:SetTexture(0, 0, 0, 0.8)
	fond:SetPoint("TOPLEFT", hote, "TOPLEFT", 7, -21)
	fond:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", -2, 2)
	local stries = hote:CreateTexture(nil, "BORDER")
	Gb.Poser(stries, "_ui-frame-toptilestreaks", true)
	stries:SetPoint("TOPLEFT", hote, "TOPLEFT", 6, -21)
	stries:SetPoint("TOPRIGHT", hote, "TOPRIGHT", -2, -21)
	local cadre = Gb.NeufTranches(hote, "ButtonFrameTemplateNoPortrait")
	local conteneur = CreateFrame("Frame", nil, hote)
	conteneur:SetFrameLevel(hote:GetFrameLevel() + 10)
	conteneur:SetHeight(20)
	conteneur:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, -1)
	conteneur:SetPoint("TOPRIGHT", hote, "TOPRIGHT", 0, -1)
	local t = conteneur:CreateFontString(nil, "OVERLAY")
	t:SetFontObject(GameFontNormal)
	t:SetPoint("TOP", conteneur, "TOP", 0, -5)
	t:SetPoint("LEFT", conteneur, "LEFT")
	t:SetPoint("RIGHT", conteneur, "RIGHT")
	t:SetText(titre or "")
	return { titre = t, cadre = cadre, fond = fond, stries = stries, conteneur = conteneur }
end

-- InsetFrameTemplate, sans marbre (fenetre translucide, voir Gb.Fenetre) :
-- le lisere en regions de l'hote, cale sur le rectangle cible
function Gb.Encart(hote, cible)
	return Gb.NeufTranches(hote, "InsetFrameTemplate", cible)
end

-- UIPanelCloseButton : 24 x 24, RedButton-Exit / -exit-pressed /
-- -Exit-Disabled, lueur RedButton-Highlight en ADD ; a TOPRIGHT (-2, 1) de
-- sa fenetre (UIPanelCloseButtonDefaultAnchorsMixin)
function Gb.Croix(b, fenetre)
	b:SetWidth(24)
	b:SetHeight(24)
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", fenetre, "TOPRIGHT", -2, 1)
	for _, v in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetDisabledTexture", "GetDisabledTexture", "redbutton-exit-disabled" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		b[v[1]](b, ART[v[3]][1])
		local t = b[v[2]](b)
		Gb.Poser(t, v[3])
		t:ClearAllPoints()
		t:SetAllPoints(b)
		if v[1] == "SetHighlightTexture" then
			t:SetBlendMode("ADD")
		end
	end
	return b
end

-- efface l'art que le client 3.3.5 pose sur ses propres boutons
function Gb.EffacerArt(b)
	for _, lire in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local t = b[lire] and b[lire](b)
		if t then
			t:SetTexture(nil)
		end
	end
end

-- ------------------------------------------------------------ le bouton rouge

-- RELEVE -- blizzard_sharedxml/shared/button/threeslicebuttontemplate.xml et
-- .lua : Left et Right a leur taille d'atlas mise a l'echelle de la hauteur
-- du bouton (hauteur / hauteur de Left) ; Center tendu entre eux ; si Left et
-- Right ne tiennent pas dans la largeur, on les rogne (UpdateScale) ; etats
-- -Pressed et -Disabled ; lueur atlasName-Highlight ; texte enfonce de
-- (-2, -1) (BigRedThreeSliceButtonTemplate).

local function rogner(t, e, gaucheVersDroite, part)
	local u1, u2 = e[2], e[3]
	if gaucheVersDroite then
		t:SetTexCoord(u1, u1 + (u2 - u1) * part, e[4], e[5])
	else
		t:SetTexCoord(u2 - (u2 - u1) * part, u2, e[4], e[5])
	end
end

local function peindreTroisTranches(b, etat)
	local r = b.foreverTrois
	if not vrai(b:IsEnabled()) then
		etat = "DISABLED"
	end
	local suffixe = ""
	if etat == "DISABLED" then
		suffixe = "-disabled"
	elseif etat == "PUSHED" then
		suffixe = "-pressed"
	end
	local eg = Gb.Poser(r.gauche, r.atlas .. "-left" .. suffixe)
	Gb.Poser(r.centre, "_" .. r.atlas .. "-center" .. suffixe)
	local ed = Gb.Poser(r.droite, r.atlas .. "-right" .. suffixe)

	-- UpdateScale
	local hauteur, largeur = b:GetHeight(), b:GetWidth()
	local echelle = hauteur / eg[7]
	local lg, ld = eg[6] * echelle, ed[6] * echelle
	if lg + ld > largeur then
		local surplus = lg + ld - largeur
		local ng, nd = lg, ld
		if (lg - surplus) > ld then
			ng = lg - surplus
		elseif (ld - surplus) > lg then
			nd = ld - surplus
		else
			if lg ~= ld then
				surplus = surplus - math.abs(lg - ld)
				ng = math.min(lg, ld)
				nd = ng
			end
			ng = ng - surplus / 2
			nd = nd - surplus / 2
		end
		rogner(r.gauche, eg, true, ng / lg)
		rogner(r.droite, ed, false, nd / ld)
		lg, ld = ng, nd
	end
	r.gauche:SetWidth(lg)
	r.gauche:SetHeight(hauteur)
	r.droite:SetWidth(ld)
	r.droite:SetHeight(hauteur)
	r.actif = vrai(b:IsEnabled())
end

-- atlas en minuscules (« 128-redbutton ») ; polices : { normale, survol,
-- grisee }, des objets police
function Gb.BoutonTroisTranches(b, atlas, polices)
	Gb.EffacerArt(b)
	local r = { atlas = atlas }
	r.gauche = b:CreateTexture(nil, "BACKGROUND")
	r.gauche:SetPoint("TOPLEFT", b, "TOPLEFT")
	r.droite = b:CreateTexture(nil, "BACKGROUND")
	r.droite:SetPoint("TOPRIGHT", b, "TOPRIGHT")
	r.centre = b:CreateTexture(nil, "BACKGROUND")
	r.centre:SetPoint("TOPLEFT", r.gauche, "TOPRIGHT")
	r.centre:SetPoint("BOTTOMRIGHT", r.droite, "BOTTOMLEFT")
	b.foreverTrois = r

	-- la lueur : SetHighlightAtlas, sur tout le bouton, en ADD
	b:SetHighlightTexture(ART[atlas .. "-highlight"][1])
	local h = b:GetHighlightTexture()
	Gb.Poser(h, atlas .. "-highlight")
	h:ClearAllPoints()
	h:SetAllPoints(b)
	h:SetBlendMode("ADD")

	if polices then
		b:SetNormalFontObject(polices[1])
		b:SetHighlightFontObject(polices[2] or polices[1])
		b:SetDisabledFontObject(polices[3] or polices[1])
	end
	local texte = b:GetFontString()
	if texte then
		texte:ClearAllPoints()
		texte:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
	b:SetPushedTextOffset(-2, -1)

	b:HookScript("OnMouseDown", function(self)
		if vrai(self:IsEnabled()) then
			peindreTroisTranches(self, "PUSHED")
		end
	end)
	b:HookScript("OnMouseUp", function(self) peindreTroisTranches(self, "NORMAL") end)
	b:HookScript("OnShow", function(self) peindreTroisTranches(self, "NORMAL") end)
	b:HookScript("OnSizeChanged", function(self) peindreTroisTranches(self, "NORMAL") end)
	b:HookScript("OnEnable", function(self) peindreTroisTranches(self, "NORMAL") end)
	b:HookScript("OnDisable", function(self) peindreTroisTranches(self, "NORMAL") end)
	peindreTroisTranches(b, "NORMAL")
	return b
end

-- ------------------------------------------------------------ le bouton de panneau

-- UIPanelButtonTemplate : trois morceaux de UI-Panel-Button-Up (12 / reste /
-- 12), -Down enfonce, -Disabled grise ; lueur UI-Panel-Button-Highlight en
-- ADD ; texte au centre, GameFontNormal / Highlight / Disable. L'image est
-- la meme chez camelot : c'est le bouton gris de 3.3.5
-- (UIPanelButtonGrayTemplate) qui change.
function Gb.BoutonPanneau(b)
	local SEP = string.char(92)
	local PANNEAU = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Panel-Button-"
	Gb.EffacerArt(b)
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
	local morceaux = { { g, 0, 0.09375 }, { m, 0.09375, 0.53125 }, { d, 0.53125, 0.625 } }
	local function fichier(nom)
		for _, v in ipairs(morceaux) do
			v[1]:SetTexture(PANNEAU .. nom)
			v[1]:SetTexCoord(v[2], v[3], 0, 0.6875)
		end
	end
	local function repos()
		fichier(vrai(b:IsEnabled()) and "Up" or "Disabled")
	end
	repos()
	b:HookScript("OnMouseDown", function()
		if vrai(b:IsEnabled()) then fichier("Down") end
	end)
	b:HookScript("OnMouseUp", repos)
	b:HookScript("OnShow", repos)
	b:HookScript("OnDisable", repos)
	b:HookScript("OnEnable", repos)
	b:SetHighlightTexture(PANNEAU .. "Highlight")
	local h = b:GetHighlightTexture()
	h:SetTexCoord(0, 0.625, 0, 0.6875)
	h:SetBlendMode("ADD")
	h:ClearAllPoints()
	h:SetAllPoints(b)
	b:SetNormalFontObject(GameFontNormal)
	b:SetHighlightFontObject(GameFontHighlight)
	b:SetDisabledFontObject(GameFontDisable)
	local texte = b:GetFontString()
	if texte then
		texte:ClearAllPoints()
		texte:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
end

-- ------------------------------------------------------------ Windows-1252

-- TEXTES VENUS DE WINDOWS : les noms des sorties audio
-- (Sound_GameSystem_GetOutputDriverNameByIndex) arrivent dans la page de
-- code du systeme (Windows-1252), que le client affiche comme de l'UTF-8 :
-- les lettres accentuees sautent ou se deforment (constate a l'accueil le
-- 28/09). Une chaine qui n'est pas de l'UTF-8 valide est convertie a
-- l'affichage ; la valeur choisie reste celle du client.

-- 0x80 a 0x9F de Windows-1252 ; 0xA0 a 0xFF valent leur point de code
local CP1252 = {
	[0x80] = 0x20AC, [0x82] = 0x201A, [0x83] = 0x0192, [0x84] = 0x201E, [0x85] = 0x2026,
	[0x86] = 0x2020, [0x87] = 0x2021, [0x88] = 0x02C6, [0x89] = 0x2030, [0x8A] = 0x0160,
	[0x8B] = 0x2039, [0x8C] = 0x0152, [0x8E] = 0x017D, [0x91] = 0x2018, [0x92] = 0x2019,
	[0x93] = 0x201C, [0x94] = 0x201D, [0x95] = 0x2022, [0x96] = 0x2013, [0x97] = 0x2014,
	[0x98] = 0x02DC, [0x99] = 0x2122, [0x9A] = 0x0161, [0x9B] = 0x203A, [0x9C] = 0x0153,
	[0x9E] = 0x017E, [0x9F] = 0x0178,
}

local function enUtf8(cp)
	if cp < 0x80 then
		return string.char(cp)
	elseif cp < 0x800 then
		return string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
	end
	return string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64)
end

local function utf8Valide(s)
	local i, n = 1, string.len(s)
	while i <= n do
		local c = string.byte(s, i)
		local suite
		if c < 0x80 then
			suite = 0
		elseif c >= 0xC2 and c <= 0xDF then
			suite = 1
		elseif c >= 0xE0 and c <= 0xEF then
			suite = 2
		elseif c >= 0xF0 and c <= 0xF4 then
			suite = 3
		else
			return false
		end
		for j = 1, suite do
			local d = string.byte(s, i + j)
			if not d or d < 0x80 or d > 0xBF then
				return false
			end
		end
		i = i + suite + 1
	end
	return true
end

-- une chaine de Windows-1252 en UTF-8 ; une chaine deja valide ne change pas
function Gb.TexteUtf8(s)
	if type(s) ~= "string" or utf8Valide(s) then
		return s
	end
	return (string.gsub(s, "[\128-\255]", function(ch)
		local b = string.byte(ch)
		return enUtf8(CP1252[b] or b)
	end))
end

-- ------------------------------------------------------------ la barre posee

-- LA BARRE DE DEFILEMENT DE CAMELOT SUR CELLE DU CLIENT (UIPanelScrollBar-
-- Template : un Slider, son curseur UI-ScrollBar-Knob, ses deux boutons de
-- pas AU-DESSUS et AU-DESSOUS de lui). L'art de MinimalScrollBar (memes
-- morceaux que ScrollBar.lua : fleches minimal-scrollbar-arrow-top /
-- -bottom 17 x 11 et leur survol, glissiere track-top / middle / bottom et
-- curseur thumb-top, middle, thumb-top retourne, 8 de large) se pose dans un
-- cadre SANS SOURIS au-dessus de la barre du client, dont les images
-- s'eteignent (alpha 0) : c'est elle qu'on clique, glisse et fait tourner,
-- par le chemin du client -- faire defiler depuis le code d'un addon
-- rejouerait ses mises a jour hors de ce chemin (voir Settings.lua). Enfant
-- de la barre, l'art la suit quand elle se cache. ECART : le curseur a la
-- taille de celui du client (fixe), et non a la part visible.
local BARRE = {
	largeur = 8, bout = 8,
	flecheHaut = "minimal-scrollbar-arrow-top-c60", flecheHautSurvol = "minimal-scrollbar-arrow-top-over-c60",
	flecheBas = "minimal-scrollbar-arrow-bottom-c60", flecheBasSurvol = "minimal-scrollbar-arrow-bottom-over-c60",
	pisteHaut = "minimal-scrollbar-track-top-c60", pisteMilieu = "!minimal-scrollbar-track-middle-c60",
	pisteBas = "minimal-scrollbar-track-bottom-c60",
	curseurBout = "minimal-scrollbar-thumb-top-c60", curseurMilieu = "minimal-scrollbar-thumb-middle-c60",
}

local function eteindre(b)
	for _, lire in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local t = b[lire] and b[lire](b)
		if t then t:SetAlpha(0) end
	end
end
Gb.Eteindre = eteindre

function Gb.Barre(sb)
	if not sb or sb.foreverBarre then return sb and sb.foreverBarre end
	local B = BARRE
	local pouce = sb:GetThumbTexture()
	if pouce then pouce:SetAlpha(0) end
	local v = CreateFrame("Frame", nil, sb)
	v:SetAllPoints(sb)
	v:SetFrameLevel(sb:GetFrameLevel() + 5)
	-- les fleches, sur les boutons du client, a la taille de l'element
	local function fleche(bouton, atlas, survol)
		if not bouton then return nil end
		eteindre(bouton)
		local t = v:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(t, atlas)
		t:SetPoint("CENTER", bouton, "CENTER", 0, 0)
		bouton:HookScript("OnEnter", function() ForeverUI.SetAtlas(t, survol, true) end)
		bouton:HookScript("OnLeave", function() ForeverUI.SetAtlas(t, atlas, true) end)
		return t
	end
	local nom = sb:GetName()
	v.haut = fleche(nom and _G[nom .. "ScrollUpButton"], B.flecheHaut, B.flecheHautSurvol)
	v.bas = fleche(nom and _G[nom .. "ScrollDownButton"], B.flecheBas, B.flecheBasSurvol)
	local function tranche(atlas, couche)
		local t = v:CreateTexture(nil, couche)
		ForeverUI.SetAtlas(t, atlas)
		t:SetWidth(B.largeur)
		return t
	end
	local ph = tranche(B.pisteHaut, "BACKGROUND")
	ph:SetPoint("TOP", sb, "TOP", 0, 0)
	local pb = tranche(B.pisteBas, "BACKGROUND")
	pb:SetPoint("BOTTOM", sb, "BOTTOM", 0, 0)
	local pm = tranche(B.pisteMilieu, "BACKGROUND")
	pm:SetPoint("TOP", ph, "BOTTOM", 0, 0)
	pm:SetPoint("BOTTOM", pb, "TOP", 0, 0)
	if pouce then
		local ch = tranche(B.curseurBout, "ARTWORK")
		ch:SetHeight(B.bout)
		ch:SetPoint("TOP", pouce, "TOP", 0, 0)
		local cb = tranche(B.curseurBout, "ARTWORK")
		local e = ForeverUI.AtlasEntry(B.curseurBout)
		cb:SetTexCoord(e[2], e[3], e[5], e[4])
		cb:SetHeight(B.bout)
		cb:SetPoint("BOTTOM", pouce, "BOTTOM", 0, 0)
		local cm = tranche(B.curseurMilieu, "ARTWORK")
		cm:SetPoint("TOP", ch, "BOTTOM", 0, 0)
		cm:SetPoint("BOTTOM", cb, "TOP", 0, 0)
		v.curseur = { ch, cm, cb }
	end
	sb.foreverBarre = v
	return v
end

-- LA BARRE D'UNE FENETRE A DEFILEMENT DU CLIENT, A LA PLACE DE CAMELOT
-- (ScrollFrame_OnLoad : scrollBarX, scrollBarTopY, scrollBarBottomY, depuis
-- le TOPRIGHT / BOTTOMRIGHT de la fenetre) : le Slider de 16 du client
-- centre sur les 8 de MinimalScrollBar, ses fleches de 11 au-dessus et
-- au-dessous -- le calcul de Macros.lua, VALIDE -- puis habillee.
function Gb.BarreA(sb, cible, x, haut, bas)
	local demi = (16 - 8) / 2
	sb:ClearAllPoints()
	sb:SetPoint("TOPLEFT", cible, "TOPRIGHT", x - demi, haut - 11)
	sb:SetPoint("BOTTOMLEFT", cible, "BOTTOMRIGHT", x - demi, bas + 11)
	return Gb.Barre(sb)
end

-- ------------------------------------------------------------ le bouton argente

-- UIMenuButtonStretchTemplate (mainline/shareduipaneltemplates.xml / .lua),
-- celui des raccourcis de camelot (KeyBindingFrameBindingButtonTemplate) :
-- UI-Silver-Button-Up en neuf morceaux -- coins 12 x 6 (u 0 / 0,09375 et
-- 0,53125 / 0,625 ; v 0 / 0,1875 et 0,625 / 0,8125), bords et milieu entre
-- eux ; -Down tant qu'on appuie ; lueur UI-Silver-Button-Highlight en ADD
-- (v 0,03 a 0,7175) ; texte CENTER (0, -1), GameFontHighlightSmall,
-- GameFontDisableSmall grise. L'image est la meme dans les deux clients.
local ARGENT = {
	us = { 0, 0.09375, 0.53125, 0.625 },
	vs = { 0, 0.1875, 0.625, 0.8125 },
	coin = { 12, 6 },
}

function Gb.BoutonArgent(b)
	if b.foreverArgent then return end
	local SEP = string.char(92)
	local fichier = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Silver-Button-"
	local nom = b:GetName()
	-- l'art du client : ses trois morceaux nommes (UIPanelButtonTemplate2),
	-- que ses scripts retexturent -- eteints par l'alpha, qu'ils ne touchent
	-- pas -- et ses textures d'etat
	for _, s in ipairs({ "Left", "Middle", "Right" }) do
		local t = nom and _G[nom .. s]
		if t then t:SetAlpha(0) end
	end
	eteindre(b)
	local A = ARGENT
	local p = {}
	for ligne = 1, 3 do
		for col = 1, 3 do
			local t = b:CreateTexture(nil, "BACKGROUND")
			t:SetTexCoord(A.us[col], A.us[col + 1], A.vs[ligne], A.vs[ligne + 1])
			p[#p + 1] = t
			t.foreverCol, t.foreverLigne = col, ligne
		end
	end
	local function morceau(col, ligne)
		return p[(ligne - 1) * 3 + col]
	end
	for _, t in ipairs(p) do
		local col, ligne = t.foreverCol, t.foreverLigne
		if col == 1 then
			t:SetPoint("LEFT", b, "LEFT", 0, 0)
			t:SetWidth(A.coin[1])
		elseif col == 3 then
			t:SetPoint("RIGHT", b, "RIGHT", 0, 0)
			t:SetWidth(A.coin[1])
		else
			t:SetPoint("LEFT", morceau(1, ligne), "RIGHT", 0, 0)
			t:SetPoint("RIGHT", morceau(3, ligne), "LEFT", 0, 0)
		end
		if ligne == 1 then
			t:SetPoint("TOP", b, "TOP", 0, 0)
			t:SetHeight(A.coin[2])
		elseif ligne == 3 then
			t:SetPoint("BOTTOM", b, "BOTTOM", 0, 0)
			t:SetHeight(A.coin[2])
		else
			t:SetPoint("TOP", morceau(col, 1), "BOTTOM", 0, 0)
			t:SetPoint("BOTTOM", morceau(col, 3), "TOP", 0, 0)
		end
	end
	local function etat(suffixe)
		for _, t in ipairs(p) do t:SetTexture(fichier .. suffixe) end
	end
	etat("Up")
	b:SetHighlightTexture(fichier .. "Highlight")
	local h = b:GetHighlightTexture()
	h:SetTexCoord(0, 1, 0.03, 0.7175)
	h:SetBlendMode("ADD")
	h:SetAlpha(1)
	h:ClearAllPoints()
	h:SetAllPoints(b)
	b:HookScript("OnMouseDown", function(self)
		if vrai(self:IsEnabled()) then etat("Down") end
	end)
	b:HookScript("OnMouseUp", function() etat("Up") end)
	b:HookScript("OnShow", function() etat("Up") end)
	b:HookScript("OnEnable", function() etat("Up") end)
	b:SetNormalFontObject(GameFontHighlightSmall)
	b:SetHighlightFontObject(GameFontHighlightSmall)
	b:SetDisabledFontObject(GameFontDisableSmall)
	local texte = b:GetFontString()
	if texte then
		texte:ClearAllPoints()
		texte:SetPoint("CENTER", b, "CENTER", 0, -1)
	end
	b.foreverArgent = p
end

-- ------------------------------------------------------------ la fenetre a portrait

-- ButtonFrameTemplate AVEC portrait -- les nombres de la fenetre Social,
-- VALIDEE (Social.lua, releve camelot/friendsframe.xml et
-- shareduipaneltemplates) : fond UI-Background-Rock en mosaique (2, -21 /
-- -2, 2) ; _UI-Frame-TopTileStreaks 43 de haut (6, -21 / -2, -21) ; metal
-- PortraitFrameTemplate, coin portrait (-13, 16), haut droit (2, 16), bas
-- gauche (-13, -8), bas droit (2, -8), dans un cadre fils a +20 ; titre
-- GameFontNormal TOP (0, -5) dans une bande de 20 (58, -1 / -24, -1) a +21 ;
-- portrait dans un cadre fils a +19, sous l'anneau de metal. Tout ce qui est
-- en regions de f reste sous le metal ; le fond est en BACKGROUND.
-- o = { portrait = fichier, portraitCote, portraitX, portraitY, titre = texte }
local PORTRAIT = {
	metal = {
		{ nom = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
		{ nom = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
		{ nom = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
		{ nom = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
	},
	titre = { x1 = 58, x2 = -24, y = -1, h = 20, texteY = -5 },
}

function Gb.FenetrePortrait(f, o)
	local SEP = string.char(92)
	local roche = f:CreateTexture(nil, "BACKGROUND")
	roche:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock", true)
	if roche.SetHorizTile then roche:SetHorizTile(true) roche:SetVertTile(true) end
	roche:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -21)
	roche:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
	local stries = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(stries, "_ui-frame-toptilestreaks", true)
	stries:SetHeight(43)
	stries:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -21)
	stries:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -21)
	local metal = CreateFrame("Frame", nil, f)
	metal:SetAllPoints(f)
	metal:SetFrameLevel(f:GetFrameLevel() + 20)
	local p = {}
	for i, coin in ipairs(PORTRAIT.metal) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, coin.nom)
		t:SetPoint(coin.point, metal, coin.point, coin.x, coin.y)
		p[i] = t
	end
	local function bord(nom, a1, c1, r1, a2, c2, r2)
		local t = metal:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(t, nom)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
	end
	bord("_ui-frame-metal-edgetop", "TOPLEFT", p[1], "TOPRIGHT", "TOPRIGHT", p[2], "TOPLEFT")
	bord("_ui-frame-metal-edgebottom", "BOTTOMLEFT", p[3], "BOTTOMRIGHT", "BOTTOMRIGHT", p[4], "BOTTOMLEFT")
	bord("!ui-frame-metal-edgeleft", "TOPLEFT", p[1], "BOTTOMLEFT", "BOTTOMLEFT", p[3], "TOPLEFT")
	bord("!ui-frame-metal-edgeright", "TOPRIGHT", p[2], "BOTTOMRIGHT", "BOTTOMRIGHT", p[4], "TOPRIGHT")
	local cadrePortrait = CreateFrame("Frame", nil, f)
	cadrePortrait:SetAllPoints(f)
	cadrePortrait:SetFrameLevel(f:GetFrameLevel() + 19)
	local portrait = cadrePortrait:CreateTexture(nil, "OVERLAY")
	portrait:SetWidth(o.portraitCote)
	portrait:SetHeight(o.portraitCote)
	portrait:SetPoint("TOPLEFT", f, "TOPLEFT", o.portraitX, o.portraitY)
	portrait:SetTexture(o.portrait)
	local T = PORTRAIT.titre
	local bandeau = CreateFrame("Frame", nil, f)
	bandeau:SetFrameLevel(f:GetFrameLevel() + 21)
	bandeau:SetHeight(T.h)
	bandeau:SetPoint("TOPLEFT", f, "TOPLEFT", T.x1, T.y)
	bandeau:SetPoint("TOPRIGHT", f, "TOPRIGHT", T.x2, T.y)
	local titre = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titre:SetPoint("TOP", bandeau, "TOP", 0, T.texteY)
	titre:SetText(o.titre or "")
	return { roche = roche, stries = stries, metal = metal, portrait = portrait, titre = titre,
		bandeau = bandeau, cadrePortrait = cadrePortrait }
end

-- ------------------------------------------------------------ le cadre interieur

-- Options_InnerFrame de camelot (voir R.Interieur, Settings.lua, VALIDE sur
-- l'Interface le 28/09) SANS son separateur : decoupe en 3 x 3, bords de 29,
-- degrades de 82 en haut et 167 en bas a leur taille, le reste etire ; cale
-- sur le rectangle rect. En regions de l'hote.
local INTERIEUR = { cols = { 0, 29, 857, 886 }, rangs = { 0, 82, 451, 618 } }

function Gb.CadreInterieur(hote, rect)
	local I = INTERIEUR
	local e = ForeverUI.AtlasEntry("options_innerframe")
	local du, dv = (e[3] - e[2]) / e[6], (e[5] - e[4]) / e[7]
	local pieces = {}
	for c = 1, 3 do
		for r = 1, 3 do
			local t = hote:CreateTexture(nil, "ARTWORK")
			t:SetTexture(e[1])
			t:SetTexCoord(e[2] + I.cols[c] * du, e[2] + I.cols[c + 1] * du,
				e[4] + I.rangs[r] * dv, e[4] + I.rangs[r + 1] * dv)
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
				t:SetHeight(I.rangs[2])
			elseif r == 3 then
				t:SetPoint("BOTTOM", rect, "BOTTOM", 0, 0)
				t:SetHeight(I.rangs[4] - I.rangs[3])
			else
				t:SetPoint("TOP", rect, "TOP", 0, -I.rangs[2])
				t:SetPoint("BOTTOM", rect, "BOTTOM", 0, I.rangs[4] - I.rangs[3])
			end
			pieces[#pieces + 1] = t
		end
	end
	return pieces
end

-- ------------------------------------------------------------ le texte recopie

-- Un texte du client pose en region d'un cadre que notre fond couvrirait :
-- il s'eteint (alpha 0) et un texte a nous, dans un cadre au-dessus, le
-- recopie -- a sa place, dans sa police -- a chaque SetText / SetFormatted-
-- Text (post-accroches : le client ecrit d'abord).
function Gb.Recopier(fs, hote, police)
	local copie = hote:CreateFontString(nil, "OVERLAY")
	copie:SetFontObject(police or GameFontNormal)
	copie:SetPoint("CENTER", fs, "CENTER", 0, 0)
	copie:SetText(fs:GetText() or "")
	fs:SetAlpha(0)
	local function suivre()
		copie:SetText(fs:GetText() or "")
	end
	hooksecurefunc(fs, "SetText", suivre)
	hooksecurefunc(fs, "SetFormattedText", suivre)
	return copie
end

-- ------------------------------------------------------------ la qualite d'un objet

-- IconBorder de l'ItemButton de camelot : WhiteIconFrame 37 x 37 au centre,
-- en OVERLAY, teinte par BAG_ITEM_QUALITY_COLORS -- commun en
-- COMMON_GRAY_COLOR (GlobalColor.db2 de camelot, voir QuestLog.lua),
-- mediocre sans contour (SetItemButtonQuality_Base).
local QUALITE = {
	contour = "Interface" .. string.char(92) .. "ForeverUI" .. string.char(92) .. "common" .. string.char(92) .. "whiteiconframe",
	communGris = { 0.659, 0.659, 0.659 },
}

function Gb.Contour(b)
	if b.foreverContour then return b.foreverContour end
	local t = b:CreateTexture(nil, "OVERLAY")
	t:SetTexture(QUALITE.contour)
	t:SetWidth(37)
	t:SetHeight(37)
	t:SetPoint("CENTER", b, "CENTER", 0, 0)
	t:Hide()
	b.foreverContour = t
	return t
end

-- le contour d'un bouton d'objet pour la qualite q (nil : aucun)
function Gb.ContourQualite(b, q)
	local t = Gb.Contour(b)
	local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if q == 1 then
		local g = QUALITE.communGris
		t:SetVertexColor(g[1], g[2], g[3])
		t:Show()
	elseif q and q >= 2 and c then
		t:SetVertexColor(c.r, c.g, c.b)
		t:Show()
	else
		t:Hide()
	end
end

-- MerchantFrameItem_UpdateQuality / TradeFrame_Update*Item : le nom a la
-- couleur de qualite (NORMAL_FONT_COLOR sans qualite connue), l'icone son
-- contour. lien ou qualite : la qualite se lit dans le lien si elle manque.
function Gb.Qualite(nom, bouton, lien, q)
	q = q or (lien and select(3, GetItemInfo(lien)))
	local c = q and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
	if nom then
		if c then
			nom:SetTextColor(c.r, c.g, c.b)
		else
			nom:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		end
	end
	Gb.ContourQualite(bouton, q)
end

-- ------------------------------------------------------------ le menu deroulant, style 1

-- WowStyle1DropdownTemplate (blizzard_menu/mainline/menutemplates.xml et
-- menutemplates.lua), pose sur un UIDropDownMenuTemplate du client : 25 de
-- haut ; fond common-dropdown-textholder-c60 de (-8, 7) a (8, -9), en trois
-- morceaux (tranches 16 / 19, UiTextureAtlasElementSliceData ; comme le
-- parcours des raids) ; fleche common-dropdown-a-button a RIGHT (1, -3), a
-- sa taille, et ses etats (GetWowStyle1ArrowButtonState : pressedhover,
-- hover, pressed, open, disabled) ; texte GameFontHighlight, 10 de haut, de
-- (8, -8) a la fleche, a gauche. Le bouton du client couvre tout le menu
-- (un clic n'importe ou l'ouvre, comme chez camelot) et la liste, celle du
-- style 1 (DropDown.lua), s'ouvre sous lui. La couleur du texte reste celle
-- que le client pose (blanc, gris desactive : celles de camelot).
local STYLE1 = { haut = 25, fond = { -8, 7, 8, -9 }, bouts = { 16, 19 }, fleche = { 1, -3 }, texte = { 8, -8, 10 },
	-- le mode compact : la boite opaque de common-dropdown-textholder-c60
	-- (colonnes 8 a 46 sur 54, rangs 7 a 32 sur 41 ; l'ombre autour), ses
	-- bouts de 8 et 11 dedans
	boite = { 8, 46, 7, 32 }, boutsBoite = { 8, 11 }, texteCompact = 12 }
local menusStyle1 = {}

local function peindreStyle1(dd)
	local b = dd.foreverBouton
	local etat = "common-dropdown-a-button"
	if not vrai(b:IsEnabled()) then
		etat = etat .. "-disabled"
	elseif b.foreverBas and b.foreverDessus then
		etat = etat .. "-pressedhover"
	elseif b.foreverDessus then
		etat = etat .. "-hover"
	elseif b.foreverBas then
		etat = etat .. "-pressed"
	elseif DropDownList1 and DropDownList1:IsShown() and UIDROPDOWNMENU_OPEN_MENU == dd then
		etat = etat .. "-open"
	end
	-- compact : la fleche sans ombre (variantes -shadowless de camelot)
	if dd.foreverCompact then etat = etat .. "-shadowless" end
	ForeverUI.SetAtlas(dd.foreverFleche, etat)
	-- a une autre hauteur que 25, la fleche suit l'echelle du menu
	local k = dd.foreverEchelle or 1
	if k ~= 1 then
		local e = ForeverUI.AtlasEntry(etat)
		if e then
			dd.foreverFleche:SetWidth(e[6] * k)
			dd.foreverFleche:SetHeight(e[7] * k)
		end
	end
end

-- hauteur : facultative (25 par defaut, celle de camelot). Une autre hauteur
-- met TOUT l'art a la meme echelle -- fond, bouts, ombre, fleche -- pour un
-- menu pose dans une disposition de 3.3.5 plus serree (hotel des ventes,
-- 28/09 : « cadres trop epais »). Le texte garde sa police, centre.
-- compact : facultatif ; le fond rogne a sa boite opaque, pose sur le menu
-- meme, et la fleche sans ombre -- rien ne deborde : le cadre fait la
-- hauteur du menu, comme un champ (hotel, 28/09 : « sur une ligne »).
function Gb.MenuStyle1(dd, largeur, hauteur, compact)
	if dd.foreverBouton then return dd end
	local S = STYLE1
	local k = (hauteur or S.haut) / S.haut
	dd.foreverEchelle = k
	dd.foreverCompact = compact and true or nil
	-- la hauteur est TENUE : UIDropDownMenu_Initialize (a chaque ouverture
	-- de la liste, par ToggleDropDownMenu) remet le menu a 32
	-- (UIDropDownMenu_InitializeHelper : UIDROPDOWNMENU_BUTTON_HEIGHT * 2) --
	-- le fond suivait, le texte restait en haut, la fleche descendait (hotel,
	-- puis horloge a la demande de l'utilisateur, 28/09). Voir l'accroche
	-- plus bas.
	dd.foreverHauteur = S.haut * k
	local nom = dd:GetName()
	for _, suffixe in ipairs({ "Left", "Middle", "Right" }) do
		_G[nom .. suffixe]:SetAlpha(0)
	end
	dd:SetWidth(largeur)
	dd:SetHeight(S.haut * k)
	local b = _G[nom .. "Button"]
	dd.foreverBouton = b
	b:ClearAllPoints()
	b:SetAllPoints(dd)
	Gb.EffacerArt(b)
	-- le fond : regions du menu, sous son texte
	local e = ForeverUI.AtlasEntry("common-dropdown-textholder-c60")
	local rect = CreateFrame("Frame", nil, dd)
	local du, dv = (e[3] - e[2]) / e[6], (e[5] - e[4]) / e[7]
	-- le rectangle de l'art (u, v) et ses bouts
	local ug, ud, vh, vb, bg, bd
	if compact then
		rect:SetAllPoints(dd)
		ug, ud = e[2] + S.boite[1] * du, e[2] + S.boite[2] * du
		vh, vb = e[4] + S.boite[3] * dv, e[4] + S.boite[4] * dv
		bg, bd = S.boutsBoite[1], S.boutsBoite[2]
	else
		rect:SetPoint("TOPLEFT", dd, "TOPLEFT", S.fond[1] * k, S.fond[2] * k)
		rect:SetPoint("BOTTOMRIGHT", dd, "BOTTOMRIGHT", S.fond[3] * k, S.fond[4] * k)
		ug, ud, vh, vb = e[2], e[3], e[4], e[5]
		bg, bd = S.bouts[1], S.bouts[2]
	end
	local u1, u2 = ug + bg * du, ud - bd * du
	local function morceau(a, z)
		local t = dd:CreateTexture(nil, "BACKGROUND")
		t:SetTexture(e[1])
		t:SetTexCoord(a, z, vh, vb)
		return t
	end
	local g = morceau(ug, u1)
	g:SetWidth(bg * k)
	g:SetPoint("TOPLEFT", rect, "TOPLEFT", 0, 0)
	g:SetPoint("BOTTOMLEFT", rect, "BOTTOMLEFT", 0, 0)
	local d = morceau(u2, ud)
	d:SetWidth(bd * k)
	d:SetPoint("TOPRIGHT", rect, "TOPRIGHT", 0, 0)
	d:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT", 0, 0)
	local m = morceau(u1, u2)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	dd.foreverFond = { g, m, d }
	-- la fleche, sur le bouton (cadre fils, au-dessus du fond)
	local fleche = b:CreateTexture(nil, "OVERLAY")
	fleche:SetPoint("RIGHT", dd, "RIGHT", S.fleche[1] * k, S.fleche[2] * k)
	dd.foreverFleche = fleche
	local texte = _G[nom .. "Text"]
	texte:SetFontObject(GameFontHighlight)
	texte:SetJustifyH("LEFT")
	texte:ClearAllPoints()
	if compact then
		-- compact : le texte sur la ligne de la fleche, centre sur le menu
		-- (la partie visible de la fleche sans ombre l'est aussi), jusqu'au
		-- bord gauche de la fleche
		texte:SetHeight(S.texteCompact)
		texte:SetPoint("LEFT", dd, "LEFT", S.texte[1], 0)
		texte:SetPoint("RIGHT", dd, "RIGHT", (S.fleche[1] - 27) * k, 0)
	else
		texte:SetHeight(S.texte[3])
		-- (8, -8) a 25 : le texte de 10 centre, un demi-point plus bas ; la
		-- meme regle a toute hauteur
		local texteY = (k == 1) and S.texte[2] or -((S.haut * k - S.texte[3]) / 2 + 0.5 * k)
		texte:SetPoint("TOPLEFT", dd, "TOPLEFT", S.texte[1], texteY)
		texte:SetPoint("TOPRIGHT", fleche, "LEFT", 0, 0)
	end
	UIDropDownMenu_SetAnchor(dd, 0, 0, "TOPLEFT", dd, "BOTTOMLEFT")
	b:HookScript("OnEnter", function(self) self.foreverDessus = true peindreStyle1(dd) end)
	b:HookScript("OnLeave", function(self) self.foreverDessus = false peindreStyle1(dd) end)
	b:HookScript("OnMouseDown", function(self) self.foreverBas = true peindreStyle1(dd) end)
	b:HookScript("OnMouseUp", function(self) self.foreverBas = false peindreStyle1(dd) end)
	b:HookScript("OnEnable", function() peindreStyle1(dd) end)
	b:HookScript("OnDisable", function() peindreStyle1(dd) end)
	dd:HookScript("OnShow", function() peindreStyle1(dd) end)
	menusStyle1[#menusStyle1 + 1] = dd
	peindreStyle1(dd)
	return dd
end

-- la fleche passe a « open » quand la liste s'ouvre, et en revient quand
-- elle se ferme (le client vide UIDROPDOWNMENU_OPEN_MENU en la fermant :
-- on repeint tous les menus de ce style)
hooksecurefunc("ToggleDropDownMenu", function()
	for _, dd in ipairs(menusStyle1) do peindreStyle1(dd) end
end)
-- la hauteur demandee, reposee apres le client (voir Gb.MenuStyle1)
hooksecurefunc("UIDropDownMenu_Initialize", function(dd)
	if dd and dd.foreverHauteur then dd:SetHeight(dd.foreverHauteur) end
end)
if DropDownList1 and DropDownList1.HookScript then
	DropDownList1:HookScript("OnHide", function()
		for _, dd in ipairs(menusStyle1) do peindreStyle1(dd) end
	end)
end
