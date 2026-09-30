--[[
    This file is part of mod-spheregrid.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
    Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
]]

--[[----------------------------------------------------------------------------
    Sphere grid — the Camelot look of the player window, client side (shipped
    by AIO)

    When the ForeverUI interface is on the client, the player window wears
    Camelot's frame and the way in is a button of ForeverUI's micro menu.
    Without it, nothing here is used and the window keeps its own look.

    From ForeverUI this file takes only:
      * the texture FILES it installs (Interface\ForeverUI\...), with their
        coordinates copied into ART below;
      * its micro menu: ForeverUI.AddMicroButton and ForeverUI.UpdateMicro.
    It calls none of ForeverUI's drawing functions.

    Camelot sources (blizzard_sharedxml): DefaultPanelTemplate and
    InsetFrameTemplate (mainline/shareduipaneltemplates.xml), the
    ButtonFrameTemplateNoPortrait and InsetFrameTemplate layouts
    (mainline/nineslicelayouts.lua, camelot/nineslicelayoutoverrides.lua),
    ThreeSliceButtonTemplate, UIPanelCloseButton, and the Dialog look of the
    game's boxes (gamedialog.xml).
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- server side: we stop here
end

local C = {}
SphereGridCamelot = C

-- Pieces: { file, u1, u2, v1, v2, width, height }
local ART = {
    ["ui-frame-metal-cornertopleft"] = { "Interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.188477, 0.374023, 0.001953, 0.373047, 95, 95 },
    ["ui-frame-metal-cornertopright"] = { "Interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.188477, 0.374023, 0.376953, 0.748047, 95, 95 },
    ["ui-frame-metal-cornerbottomleft"] = { "Interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.000977, 0.186523, 0.001953, 0.392578, 95, 100 },
    ["ui-frame-metal-cornerbottomright"] = { "Interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.000977, 0.186523, 0.396484, 0.787109, 95, 100 },
    ["_ui-frame-metal-edgetop"] = { "Interface\\ForeverUI\\framegeneral\\uiframemetalhorizontal2xc60", 0, 1, 0.396484, 0.767578, 128, 95 },
    ["_ui-frame-metal-edgebottom"] = { "Interface\\ForeverUI\\framegeneral\\uiframemetalhorizontal2xc60", 0, 1, 0.001953, 0.392578, 128, 100 },
    ["!ui-frame-metal-edgeleft"] = { "Interface\\ForeverUI\\framegeneral\\uiframemetalvertical2xc60", 0.001953, 0.373047, 0, 1, 95, 128 },
    ["!ui-frame-metal-edgeright"] = { "Interface\\ForeverUI\\framegeneral\\uiframemetalvertical2xc60", 0.376953, 0.748047, 0, 1, 95, 128 },
    ["_ui-frame-toptilestreaks"] = { "Interface\\ForeverUI\\framegeneral\\uiframehorizontal", 0, 1, 0.007812, 0.34375, 256, 43 },
    ["ui-frame-innertopleft"] = { "Interface\\ForeverUI\\framegeneral\\uiframe", 0.757812, 0.804688, 0.554688, 0.601562, 6, 6 },
    ["ui-frame-innertopright"] = { "Interface\\ForeverUI\\framegeneral\\uiframe", 0.820312, 0.867188, 0.554688, 0.601562, 6, 6 },
    ["ui-frame-innerbotleftcorner"] = { "Interface\\ForeverUI\\framegeneral\\uiframe", 0.632812, 0.679688, 0.554688, 0.601562, 6, 6 },
    ["ui-frame-innerbotright"] = { "Interface\\ForeverUI\\framegeneral\\uiframe", 0.695312, 0.742188, 0.554688, 0.601562, 6, 6 },
    ["_ui-frame-innertoptile"] = { "Interface\\ForeverUI\\framegeneral\\uiframehorizontal", 0, 1, 0.90625, 0.929688, 256, 3 },
    ["_ui-frame-innerbottile"] = { "Interface\\ForeverUI\\framegeneral\\uiframehorizontal", 0, 1, 0.867188, 0.890625, 256, 3 },
    ["!ui-frame-innerlefttile"] = { "Interface\\ForeverUI\\framegeneral\\uiframevertical", 0.484375, 0.53125, 0, 1, 3, 256 },
    ["!ui-frame-innerrighttile"] = { "Interface\\ForeverUI\\framegeneral\\uiframevertical", 0.5625, 0.609375, 0, 1, 3, 256 },
    ["redbutton-exit"] = { "Interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.007812, 0.257812, 32, 32 },
    ["redbutton-exit-pressed"] = { "Interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.539062, 0.789062, 32, 32 },
    ["redbutton-exit-disabled"] = { "Interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.273438, 0.523438, 32, 32 },
    ["redbutton-highlight"] = { "Interface\\ForeverUI\\buttons\\redbuttonsc60", 0.402344, 0.527344, 0.007812, 0.257812, 32, 32 },
    ["128-redbutton-left"] = { "Interface\\ForeverUI\\buttons\\128-redbutton-left-c60", 0.015625, 0.90625, 0, 1, 114, 128 },
    ["128-redbutton-left-pressed"] = { "Interface\\ForeverUI\\buttons\\128-redbutton-left-pressed-c60", 0.015625, 0.90625, 0, 1, 114, 128 },
    ["128-redbutton-left-disabled"] = { "Interface\\ForeverUI\\buttons\\128-redbutton-left-disabled-c60", 0.015625, 0.90625, 0, 1, 114, 128 },
    ["_128-redbutton-center"] = { "Interface\\ForeverUI\\buttons\\_128-redbutton-center-c60", 0.015625, 0.515625, 0, 1, 64, 128 },
    ["_128-redbutton-center-pressed"] = { "Interface\\ForeverUI\\buttons\\_128-redbutton-center-pressed-c60", 0.015625, 0.515625, 0, 1, 64, 128 },
    ["_128-redbutton-center-disabled"] = { "Interface\\ForeverUI\\buttons\\_128-redbutton-center-disabled-c60", 0.015625, 0.515625, 0, 1, 64, 128 },
    ["128-redbutton-right"] = { "Interface\\ForeverUI\\buttons\\128-redbutton-right-c60", 0.003906, 0.574219, 0, 1, 292, 128 },
    ["128-redbutton-right-pressed"] = { "Interface\\ForeverUI\\buttons\\128-redbutton-right-pressed-c60", 0.003906, 0.574219, 0, 1, 292, 128 },
    ["128-redbutton-right-disabled"] = { "Interface\\ForeverUI\\buttons\\128-redbutton-right-disabled-c60", 0.003906, 0.574219, 0, 1, 292, 128 },
    ["128-redbutton-highlight"] = { "Interface\\ForeverUI\\buttons\\128-redbutton-highlight", 0.003906, 0.865234, 0, 1, 441, 128 },
    ["ui-diamonddialogbox-border"] = { "Interface\\ForeverUI\\dialogframe\\uiframediamondmetalborder2xc60", 0.003906, 0.550781, 0.003906, 0.550781, 70, 70 },
    ["ui-hud-micromenu-buttonbg-down-c60-2x"] = { "Interface\\ForeverUI\\hud\\uimicromenuc602x", 0.000977, 0.063477, 0.658203, 0.818359, 32, 41 },
}

-- Whole files, tiled
local ROCK = "Interface\\ForeverUI\\framegeneral\\ui-background-rock"
local MARBLE = "Interface\\ForeverUI\\framegeneral\\ui-background-marble"
local DIALOG_BACKGROUND = "Interface\\ForeverUI\\dialogframe\\uiframedialogboxbackgrounddark"

-- Geometry.
--   window: DefaultPanelTemplate (rock and streaks from (6, -21) to (-2, 2),
--     title from (30, -1) to (-24, -1), 20 high, text 5 below its top) and the
--     ButtonFrameTemplateNoPortrait layout with camelot's overrides;
--   close: UIPanelCloseButton, 24 a side, at (-2, 1);
--   dialog: dark background 7 inside the edge, diamond border cut at 32,
--     close button at (-3, -3);
--   content: the header row under the title, then the two insets side by side,
--     `gap` apart, their content `pad` inside the inset's trim;
--   levels: the metal over the content, the title and close over the metal.
C.WINDOW = {
    background = { 6, -21, -2, 2 }, streaks = 43,
    title = { left = 30, right = -24, y = -1, height = 20, textY = -5 },
    corners = {
        { "ui-frame-metal-cornertopleft", "TOPLEFT", -8, 16 },
        { "ui-frame-metal-cornertopright", "TOPRIGHT", 2, 16 },
        { "ui-frame-metal-cornerbottomleft", "BOTTOMLEFT", -8, -8 },
        { "ui-frame-metal-cornerbottomright", "BOTTOMRIGHT", 2, -8 },
    },
    close = { side = 24, x = -2, y = 1 },
    content = { left = 8, right = 6, top = 22, bottom = 6, gap = 6, pad = 3 },
    levels = { metal = 20, title = 21, close = 22 },
}
C.DIALOG = { background = 7, cut = 32, close = { side = 24, x = -3, y = -3 } }

-- The micro button: the empty camelot button ("buttonbg" set), with a round
-- picture of the sphere drawn on it, 1 lower while pushed.
C.MICRO = { name = "SphereGridMicroButton", set = "buttonbg", icon = "Interface\\Icons\\inv_112_arcane_orb",
            side = 20, x = 0, y = 1, pushedY = -1, highlightAlpha = 0.4 }

-- ForeverUI is on the client and offers its micro menu
function C.Available()
    return ForeverUI ~= nil and type(ForeverUI.AddMicroButton) == "function"
end

-- The piece on the texture; keepSize: leave the texture's size alone
local function place(t, name, keepSize)
    local e = ART[name]
    t:SetTexture(e[1])
    t:SetTexCoord(e[2], e[3], e[4], e[5])
    if not keepSize then
        t:SetWidth(e[6])
        t:SetHeight(e[7])
    end
    return e
end

local function tiled(t, file)
    t:SetTexture(file, true)
    if t.SetHorizTile then
        t:SetHorizTile(true)
        t:SetVertTile(true)
    end
end

-- 3.3.5 returns 1 / nil from IsEnabled
local function enabled(b)
    local v = b:IsEnabled()
    return v and v ~= 0
end

-- A texture state of a button, stretched over it
local function buttonState(b, setter, getter, name)
    local e = ART[name]
    b[setter](b, e[1])
    local t = b[getter](b)
    t:SetTexCoord(e[2], e[3], e[4], e[5])
    t:ClearAllPoints()
    t:SetAllPoints(b)
    return t
end

-- The red cross; parent: the button's frame, x, y: its offset from the top
-- right corner
function C.CloseButton(parent, x, y, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(C.WINDOW.close.side)
    b:SetHeight(C.WINDOW.close.side)
    b:SetPoint("TOPRIGHT", parent, "TOPRIGHT", x, y)
    buttonState(b, "SetNormalTexture", "GetNormalTexture", "redbutton-exit")
    buttonState(b, "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed")
    buttonState(b, "SetDisabledTexture", "GetDisabledTexture", "redbutton-exit-disabled")
    buttonState(b, "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight"):SetBlendMode("ADD")
    b:SetScript("OnClick", onClick)
    return b
end

-- The window's frame: rock, streaks, metal, title and close. f keeps its size and
-- place; title: the text; onClose: what the cross does. The title row drags
-- the window. Returns the title font string.
function C.Window(f, title, onClose)
    local W = C.WINDOW
    local rock = f:CreateTexture(nil, "BACKGROUND")
    tiled(rock, ROCK)
    rock:SetPoint("TOPLEFT", f, "TOPLEFT", W.background[1], W.background[2])
    rock:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", W.background[3], W.background[4])
    local streaks = f:CreateTexture(nil, "BACKGROUND")
    place(streaks, "_ui-frame-toptilestreaks", true)
    streaks:SetHeight(W.streaks)
    streaks:SetPoint("TOPLEFT", f, "TOPLEFT", W.background[1], W.background[2])
    streaks:SetPoint("TOPRIGHT", f, "TOPRIGHT", W.background[3], W.background[2])

    local metal = CreateFrame("Frame", nil, f)
    metal:SetAllPoints(f)
    metal:SetFrameLevel(f:GetFrameLevel() + W.levels.metal)
    local corners = {}
    for i, c in ipairs(W.corners) do
        local t = metal:CreateTexture(nil, "OVERLAY")
        place(t, c[1])
        t:SetPoint(c[2], metal, c[2], c[3], c[4])
        corners[i] = t
    end
    local function edge(name, a1, c1, r1, a2, c2, r2)
        local t = metal:CreateTexture(nil, "OVERLAY")
        place(t, name)
        t:SetPoint(a1, c1, r1)
        t:SetPoint(a2, c2, r2)
    end
    edge("_ui-frame-metal-edgetop", "TOPLEFT", corners[1], "TOPRIGHT", "TOPRIGHT", corners[2], "TOPLEFT")
    edge("_ui-frame-metal-edgebottom", "BOTTOMLEFT", corners[3], "BOTTOMRIGHT", "BOTTOMRIGHT", corners[4], "BOTTOMLEFT")
    edge("!ui-frame-metal-edgeleft", "TOPLEFT", corners[1], "BOTTOMLEFT", "BOTTOMLEFT", corners[3], "TOPLEFT")
    edge("!ui-frame-metal-edgeright", "TOPRIGHT", corners[2], "BOTTOMRIGHT", "BOTTOMRIGHT", corners[4], "TOPRIGHT")

    local T = W.title
    local bar = CreateFrame("Frame", nil, f)
    bar:SetFrameLevel(f:GetFrameLevel() + W.levels.title)
    bar:SetHeight(T.height)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", T.left, T.y)
    bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", T.right, T.y)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() f:StartMoving() end)
    bar:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local text = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOP", bar, "TOP", 0, T.textY)
    text:SetPoint("LEFT", bar, "LEFT")
    text:SetPoint("RIGHT", bar, "RIGHT")
    text:SetText(title)

    local close = C.CloseButton(f, W.close.x, W.close.y, onClose)
    close:SetFrameLevel(f:GetFrameLevel() + W.levels.close)
    return text
end

-- The inset (InsetFrameTemplate): tiled marble, 6 px corners joined by 3 px
-- edges; the bottom corners 1 lower.
function C.Inset(parent)
    local e = CreateFrame("Frame", nil, parent)
    local background = e:CreateTexture(nil, "BACKGROUND")
    tiled(background, MARBLE)
    background:SetAllPoints(e)
    local function corner(name, point, y)
        local t = e:CreateTexture(nil, "BORDER")
        place(t, name)
        t:SetPoint(point, e, point, 0, y)
        return t
    end
    local topLeft = corner("ui-frame-innertopleft", "TOPLEFT", 0)
    local topRight = corner("ui-frame-innertopright", "TOPRIGHT", 0)
    local bottomLeft = corner("ui-frame-innerbotleftcorner", "BOTTOMLEFT", -1)
    local bottomRight = corner("ui-frame-innerbotright", "BOTTOMRIGHT", -1)
    local function edge(name, a1, c1, r1, a2, c2, r2)
        local t = e:CreateTexture(nil, "BORDER")
        place(t, name, true)
        t:SetPoint(a1, c1, r1)
        t:SetPoint(a2, c2, r2)
        return t
    end
    edge("_ui-frame-innertoptile", "TOPLEFT", topLeft, "TOPRIGHT", "TOPRIGHT", topRight, "TOPLEFT"):SetHeight(3)
    edge("_ui-frame-innerbottile", "BOTTOMLEFT", bottomLeft, "BOTTOMRIGHT", "BOTTOMRIGHT", bottomRight, "BOTTOMLEFT"):SetHeight(3)
    edge("!ui-frame-innerlefttile", "TOPLEFT", topLeft, "BOTTOMLEFT", "BOTTOMLEFT", bottomLeft, "TOPLEFT"):SetWidth(3)
    edge("!ui-frame-innerrighttile", "TOPRIGHT", topRight, "BOTTOMRIGHT", "BOTTOMRIGHT", bottomRight, "TOPRIGHT"):SetWidth(3)
    return e
end

-- The box of the game's dialogs: dark tiled background, diamond border cut in
-- nine (corners keep their size, edges stretch one way, the center both).
function C.Dialog(f)
    local D = C.DIALOG
    local background = f:CreateTexture(nil, "BACKGROUND")
    tiled(background, DIALOG_BACKGROUND)
    background:SetPoint("TOPLEFT", f, "TOPLEFT", D.background, -D.background)
    background:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -D.background, D.background)
    local e = ART["ui-diamonddialogbox-border"]
    local du, dv = (e[3] - e[2]) * D.cut / e[6], (e[5] - e[4]) * D.cut / e[7]
    local us = { e[2], e[2] + du, e[3] - du, e[3] }
    local vs = { e[4], e[4] + dv, e[5] - dv, e[5] }
    local points = { "LEFT", nil, "RIGHT" }
    local rows = { "TOP", nil, "BOTTOM" }
    for row = 1, 3 do
        for column = 1, 3 do
            local t = f:CreateTexture(nil, "BORDER")
            t:SetTexture(e[1])
            t:SetTexCoord(us[column], us[column + 1], vs[row], vs[row + 1])
            if points[column] then
                t:SetWidth(D.cut)
                t:SetPoint(points[column], f, points[column])
            else
                t:SetPoint("LEFT", f, "LEFT", D.cut, 0)
                t:SetPoint("RIGHT", f, "RIGHT", -D.cut, 0)
            end
            if rows[row] then
                t:SetHeight(D.cut)
                t:SetPoint(rows[row], f, rows[row])
            else
                t:SetPoint("TOP", f, "TOP", 0, -D.cut)
                t:SetPoint("BOTTOM", f, "BOTTOM", 0, D.cut)
            end
        end
    end
end

-- THE RED BUTTON (ThreeSliceButtonTemplate): left and right at their size scaled
-- to the button's height, the center stretched between them, both ends
-- cropped when they do not fit the width (UpdateScale). States -pressed and
-- -disabled; the -highlight glow in ADD; text pushed by (-2, -1).
local function crop(t, e, fromLeft, part)
    if fromLeft then
        t:SetTexCoord(e[2], e[2] + (e[3] - e[2]) * part, e[4], e[5])
    else
        t:SetTexCoord(e[3] - (e[3] - e[2]) * part, e[3], e[4], e[5])
    end
end

local function paint(b, state)
    local r = b.slices
    if not enabled(b) then state = "DISABLED" end
    local suffix = (state == "DISABLED" and "-disabled") or (state == "PUSHED" and "-pressed") or ""
    local el = place(r.left, "128-redbutton-left" .. suffix, true)
    place(r.center, "_128-redbutton-center" .. suffix, true)
    local er = place(r.right, "128-redbutton-right" .. suffix, true)
    local height, width = b:GetHeight(), b:GetWidth()
    local scale = height / el[7]
    local wl, wr = el[6] * scale, er[6] * scale
    if wl + wr > width then
        local excess = wl + wr - width
        local nl, nr = wl, wr
        if wl - excess > wr then
            nl = wl - excess
        elseif wr - excess > wl then
            nr = wr - excess
        else
            if wl ~= wr then
                excess = excess - math.abs(wl - wr)
                nl = math.min(wl, wr)
                nr = nl
            end
            nl = nl - excess / 2
            nr = nr - excess / 2
        end
        crop(r.left, el, true, nl / wl)
        crop(r.right, er, false, nr / wr)
        wl, wr = nl, nr
    end
    r.left:SetWidth(wl)
    r.left:SetHeight(height)
    r.right:SetWidth(wr)
    r.right:SetHeight(height)
end

-- parent, text; the caller sizes and places it
function C.RedButton(parent, text)
    local b = CreateFrame("Button", nil, parent)
    local r = {}
    r.left = b:CreateTexture(nil, "BACKGROUND")
    r.left:SetPoint("TOPLEFT", b, "TOPLEFT")
    r.right = b:CreateTexture(nil, "BACKGROUND")
    r.right:SetPoint("TOPRIGHT", b, "TOPRIGHT")
    r.center = b:CreateTexture(nil, "BACKGROUND")
    r.center:SetPoint("TOPLEFT", r.left, "TOPRIGHT")
    r.center:SetPoint("BOTTOMRIGHT", r.right, "BOTTOMLEFT")
    b.slices = r
    buttonState(b, "SetHighlightTexture", "GetHighlightTexture", "128-redbutton-highlight"):SetBlendMode("ADD")
    local label = b:CreateFontString(nil, "OVERLAY")
    label:SetPoint("CENTER", b, "CENTER", 0, 0)
    b:SetFontString(label)
    b:SetNormalFontObject(GameFontNormal)
    b:SetHighlightFontObject(GameFontHighlight)
    b:SetDisabledFontObject(GameFontDisable)
    b:SetPushedTextOffset(-2, -1)
    b:SetText(text)
    b:HookScript("OnMouseDown", function(self) if enabled(self) then paint(self, "PUSHED") end end)
    b:HookScript("OnMouseUp", function(self) paint(self, "NORMAL") end)
    b:HookScript("OnShow", function(self) paint(self, "NORMAL") end)
    b:HookScript("OnSizeChanged", function(self) paint(self, "NORMAL") end)
    b:HookScript("OnEnable", function(self) paint(self, "NORMAL") end)
    b:HookScript("OnDisable", function(self) paint(self, "NORMAL") end)
    paint(b, "NORMAL")
    return b
end

-- THE MICRO BUTTON. ForeverUI draws the empty camelot button; the sphere is
-- drawn here, round (SetPortraitToTexture), with a glow on hover like the
-- character button's. def: tooltip (text or function), onClick.
local function decorate(b)
    local M = C.MICRO
    local sphere = b:CreateTexture(nil, "OVERLAY")
    sphere:SetWidth(M.side)
    sphere:SetHeight(M.side)
    SetPortraitToTexture(sphere, M.icon)
    local function follow()
        sphere:ClearAllPoints()
        local pushed = b:GetButtonState() == "PUSHED"
        sphere:SetPoint("CENTER", b, "CENTER", M.x, M.y + (pushed and M.pushedY or 0))
    end
    follow()
    hooksecurefunc(b, "SetButtonState", follow)
    b:HookScript("OnMouseDown", follow)
    b:HookScript("OnMouseUp", follow)
    if not b:GetHighlightTexture() then
        local glow = buttonState(b, "SetHighlightTexture", "GetHighlightTexture", "ui-hud-micromenu-buttonbg-down-c60-2x")
        glow:SetBlendMode("ADD")
        glow:SetAlpha(M.highlightAlpha)
    end
end

function C.AddMicroButton(def)
    return ForeverUI.AddMicroButton({
        name = C.MICRO.name,
        atlasSet = C.MICRO.set,
        tooltip = def.tooltip,
        onClick = def.onClick,
        ready = decorate,
    })
end

-- Pushes the micro button while the window is open
function C.UpdateMicro(isOpen)
    if ForeverUI and ForeverUI.UpdateMicro then
        ForeverUI.UpdateMicro(C.MICRO.name, isOpen and true or false)
    end
end
