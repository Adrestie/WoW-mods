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
    Solstice and Equinox -- the celestial gauge, client side.

    Sent to the client by AIO: nothing to install, nothing to package.

    NO SECOND BAR IS DRAWN. The client already carries the EclipseBarFrame
    addon, a bar anchored under the player's portrait. We TAKE IT OVER rather
    than put another one beside it.

    WHAT THE ADDON DOES BY ITSELF, and what we replace:

      * it only shows for a druid in moonkin form (24858) -- which suits us,
        and is left alone;
      * its cursor follows the REMAINING DURATION of the game's own Eclipse
        buffs, 48517 (solar) and 48518 (lunar): xPos = +/-38 x (duration / 15);
      * it lights the solar or the lunar half, dims the other, and pulses a
        halo on the body reached, all from those same buffs.

    WHAT WE PUT IN ITS PLACE:

      * the cursor follows OUR gauge, xPos = 38 x notch / 3, the notch coming
        from the stacks of "Lunar gauge" (8610032) and "Solar gauge" (8610033).
        THOSE AURAS MUST STAY VISIBLE: marked as having no icon, they stopped
        being returned by UnitBuff and the cursor froze in the middle.
      * a half lights when AN END IS REACHED -- that is, when the player
        carries Solstice (8610029, sun) or Equinox (8610030, moon);
      * and the bar is put away for a druid who does NOT know the spell: the
        addon shows for any moonkin, which is one condition short of ours.

    The addon calls EclipseBar_Update from its own OnUpdate every frame, so
    replacing that one function is enough for everything to follow. OnShow and
    CheckBuffs are replaced too, without which the game's own buffs would take
    the lit halves back.

    /solstice prints what the client actually reads, so a disagreement can be
    settled rather than guessed at.
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- server side: we stop here
end

-- ---------------------------------------------------------------------------
-- What the server tells us
-- ---------------------------------------------------------------------------
local ID_SPELL = 8600092                                  -- the spell itself
local ID_LUNAR_GAUGE, ID_SOLAR_GAUGE = 8610032, 8610033   -- 1 to 3 stacks
local ID_EQUINOX, ID_SOLSTICE = 8610030, 8610029          -- an end reached
local ID_SUN_SPENT, ID_MOON_SPENT = 8610034, 8610035      -- that body is spent
local END_NOTCH = 3                                       -- notches per half
local TRAVEL = 38                                         -- pixels, as the addon has it

-- Read off EclipseBarFrame.lua: its own cuts are reused so that the halo and
-- the cursor keep exactly the look it gives them.
local MARKER = {
    none = { 0.914, 1.0, 0.82, 1.0 },
    sun  = { 1.0, 0.914, 0.641, 0.82 },   -- left and right swapped: a mirror
    moon = { 0.914, 1.0, 0.641, 0.82 },
}
local HALO = {
    moon   = { x = 43, y = 45, l = 0.73437500, r = 0.90234375,
               h = 0.00781250, b = 0.35937500 },
    sun = { x = 43, y = 45, l = 0.55859375, r = 0.72656250,
               h = 0.00781250, b = 0.35937500 },
}

-- WHERE IT SITS, AND HOW BIG. The addon anchors the bar under the player's
-- portrait and leaves it at that frame's scale; we bring it back to the middle
-- of the screen, under the character, and make it larger. Three numbers to
-- change if the place or the size do not suit.
local ANCHOR_X, ANCHOR_Y = 0, -180
local SCALE = 1.6

local lastState
local repositioned = false
local known = false


-- ---------------------------------------------------------------------------
-- Does the player know the spell?
-- ---------------------------------------------------------------------------
-- THE BAR BELONGS TO THE SPELL, NOT TO THE FORM. The addon we take over shows
-- for any moonkin, so a druid who has never bought the cell was given a gauge
-- that meant nothing.
--
-- 3.3.5 has no IsSpellKnown, so the SPELL BOOK is read: GetSpellLink hands
-- back a link carrying the identifier, which neither the client's language nor
-- a renamed spell can disturb. It is read when the book changes, never every
-- frame.
-- The form the bar belongs to. MOONKIN_FORM is a global of the client; the
-- number is the fallback for a client that does not declare it.
local function moonkin()
    local form = GetShapeshiftFormID and GetShapeshiftFormID()
    return form == (MOONKIN_FORM or 31)
end


-- SHOWN OR PUT AWAY BY US, not only by the addon. Its own rule fires on a
-- change of form: a druid already in moonkin who bought the cell saw nothing
-- until he changed form, logged in again or reloaded the interface.
local function follow()
    if not EclipseBarFrame then
        return
    end
    if known and moonkin() then
        if not EclipseBarFrame:IsShown() then
            lastState = nil
            EclipseBarFrame:Show()
        end
    elseif not known and EclipseBarFrame:IsShown() then
        EclipseBarFrame:Hide()
    end
end


local function readBook()
    known = false
    local total = 0
    for tab = 1, (GetNumSpellTabs() or 0) do
        local _, _, offset, count = GetSpellTabInfo(tab)
        if offset and count then
            total = offset + count
        end
    end
    for index = 1, total do
        local link = GetSpellLink(index, BOOKTYPE_SPELL)
        local id = link and tonumber(link:match("spell:(%d+)"))
        if id == ID_SPELL then
            known = true
            return
        end
    end
end


-- ---------------------------------------------------------------------------
-- Reading the auras
-- ---------------------------------------------------------------------------
-- Returns the notch (-3 moon .. +3 sun) and the end reached ("moon", "sun" or
-- nil). EVERYTHING IS READ BY SPELL IDENTIFIER: neither the client's language
-- nor a misspelt name can get in the way.
local function readGauge()
    local notch, endpoint, lock = 0, nil, nil
    for i = 1, 40 do
        local name, _, _, stacks, _, _, _, _, _, _, id = UnitBuff("player", i)
        if not name then
            break
        end
        if id == ID_LUNAR_GAUGE or id == ID_SOLAR_GAUGE then
            local notches = (stacks and stacks > 0) and stacks or 1
            if notches > END_NOTCH then notches = END_NOTCH end
            notch = (id == ID_LUNAR_GAUGE) and -notches or notches
        elseif id == ID_EQUINOX then
            endpoint = "moon"
        elseif id == ID_SOLSTICE then
            endpoint = "sun"
        elseif id == ID_SUN_SPENT then
            lock = "sun"
        elseif id == ID_MOON_SPENT then
            lock = "moon"
        end
    end
    return notch, endpoint, lock
end

-- ---------------------------------------------------------------------------
-- Driving the bar that is already there
-- ---------------------------------------------------------------------------
local function placeHalo(frame, side)
    local info = HALO[side]
    frame.glow:ClearAllPoints()
    frame.glow:SetPoint("CENTER", (side == "moon") and frame.moon or frame.sun,
                        "CENTER", 0, 0)
    frame.glow:SetWidth(info.x)
    frame.glow:SetHeight(info.y)
    frame.glow:SetTexCoord(info.l, info.r, info.h, info.b)
    frame.glow:Show()
    if frame.glow.pulse and not frame.glow.pulse:IsPlaying() then
        frame.glow.pulse:Play()
    end
end

local function updateEclipse(frame)
    if not frame or not frame.marker then
        return                              -- OnLoad has not run yet
    end
    -- Hidden, the frame stops updating on its own; the addon shows it again on
    -- the next change of form, and OnShow sends us straight back here.
    if not known then
        frame:Hide()
        return
    end
    local notch, endpoint, lock = readGauge()

    -- THE CURSOR: our notch, over the addon's own travel.
    --
    -- ITS LOOK FOLLOWS THE LOCK, NOT THE BUFF. It takes the arrow of the side
    -- reached and KEEPS it once the six seconds are up, until the other end is
    -- touched -- because the spent-body aura lasts that long, where the buff
    -- itself fades. At the moment of arrival both name the same side, so the
    -- arrow does not blink.
    frame.marker:ClearAllPoints()
    frame.marker:SetPoint("CENTER", TRAVEL * notch / END_NOTCH, 2)
    frame.marker:SetTexCoord(unpack(MARKER[endpoint or lock or "none"]))

    -- THREE STATES, in this order of priority:
    --   1. an end has just been reached: its half lights and the halo pulses,
    --      for six seconds;
    --   2. otherwise, if a body is SPENT, it dims -- the opposite school is
    --      the one to cast, and the bar says so;
    --   3. otherwise both bodies are plain: the player picks a school.
    -- The addon's animations are kept, but only replayed ON A CHANGE, without
    -- which OnUpdate would restart them every frame.
    local state = (endpoint and ("end:" .. endpoint))
              or (lock and ("lock:" .. lock))
              or "free"
    if state ~= lastState then
        lastState = state
        if endpoint == "moon" then
            frame.sunBar:Hide()
            frame.darkMoon:Hide()
            frame.darkSun:Hide()
            frame.moonBar:Show()
            placeHalo(frame, "moon")
            if frame.moonDeactivate:IsPlaying() then frame.moonDeactivate:Stop() end
            if not frame.moonActivate:IsPlaying() then frame.moonActivate:Play() end
        elseif endpoint == "sun" then
            frame.moonBar:Hide()
            frame.darkSun:Hide()
            frame.darkMoon:Hide()
            frame.sunBar:Show()
            placeHalo(frame, "sun")
            if frame.sunDeactivate:IsPlaying() then frame.sunDeactivate:Stop() end
            if not frame.sunActivate:IsPlaying() then frame.sunActivate:Play() end
        else
            frame.sunBar:Hide()
            frame.moonBar:Hide()
            if frame.glow.pulse and frame.glow.pulse:IsPlaying() then
                frame.glow.pulse:Stop()
            end
            frame.glow:Hide()
            -- THE SPENT BODY DIMS, the other stays plain. With no lock,
            -- both stay plain: the player has the choice.
            if lock == "sun" then
                frame.darkMoon:Hide()
                frame.darkSun:Show()
            elseif lock == "moon" then
                frame.darkSun:Hide()
                frame.darkMoon:Show()
            else
                frame.darkSun:Hide()
                frame.darkMoon:Hide()
            end
        end
    end

    -- The addon keeps these two flags for its own switching, so they are kept
    -- current: it must never believe itself at odds with the screen.
    frame.hasLunarEclipse = (endpoint == "moon")
    frame.hasSolarEclipse = (endpoint == "sun")
    frame.eclipseDuration = 0
end

-- ---------------------------------------------------------------------------
-- Replacing the addon's three functions
-- ---------------------------------------------------------------------------
-- They are globals in EclipseBarFrame.lua, and that addon is loaded well before
-- AIO sends us over, so replacing them here is enough. EclipseBar_Update being
-- called from the frame's own OnUpdate, the cursor then follows by itself.
--
-- THE BAR IS MOVED AND ENLARGED. The frame is parented to PlayerFrame and
-- anchored under it; we reparent it to UIParent -- without which it would
-- inherit the portrait's scale -- and place it in the middle, under the
-- character. Show and Hide stay the addon's own; reparenting does not disturb
-- them.
--
-- AND THE PLAYER MOVES IT. The bar drags with the left button, and where it
-- was left is remembered PER CHARACTER through AIO's saved variables
-- (AIO.SavePosition, LibWindow underneath): the anchor above is only where it
-- starts the first time. A client whose AIO is older than these two helpers
-- keeps the fixed bar, and nothing breaks.
local function reposition()
    if repositioned or not EclipseBarFrame then
        return
    end
    EclipseBarFrame:SetParent(UIParent)
    EclipseBarFrame:ClearAllPoints()
    EclipseBarFrame:SetPoint("CENTER", UIParent, "CENTER", ANCHOR_X, ANCHOR_Y)
    EclipseBarFrame:SetScale(SCALE)
    repositioned = true

    local LibWindow = LibStub and LibStub("LibWindow-1.1", true)
    if AIO.SavePosition and LibWindow and LibWindow.MakeDraggable then
        AIO.SavePosition(EclipseBarFrame, true)   -- restores a saved place, or keeps this one
        EclipseBarFrame:EnableMouse(true)
        LibWindow.MakeDraggable(EclipseBarFrame)
    end
end

local function connect()
    if not EclipseBarFrame or type(EclipseBar_Update) ~= "function" then
        return false                        -- the addon is not there
    end
    reposition()

    -- THE SCRIPTS GO ON THE FRAME, not only on the globals. The addon's XML
    -- binds its handlers BY VALUE at load time
    -- (<OnUpdate function="EclipseBar_Update"/>), so reassigning the global
    -- changes nothing about what the frame already calls. That is what left the
    -- cursor sitting still.
    EclipseBarFrame:SetScript("OnUpdate", function(self) updateEclipse(self) end)
    EclipseBarFrame:SetScript("OnShow", function(self)
        lastState = nil                   -- replay the state when shown
        updateEclipse(self)
    end)

    -- The globals still matter: EclipseBar_OnEvent looks them up at run time to
    -- show or hide the bar according to the form. So its OnEvent is kept, and
    -- what it calls is replaced.
    EclipseBar_Update = function(self) updateEclipse(self) end
    EclipseBar_CheckBuffs = function(self)
        if self:IsShown() then updateEclipse(self) end
    end
    EclipseBar_OnShow = function(self)
        lastState = nil
        updateEclipse(self)
    end
    return true
end

readBook()
local branch = connect()

-- If the addon was not loaded yet, try again on entering the world. The book is
-- read again whenever it changes: buying the cell lights the bar without a
-- reconnection, giving it back puts the bar away.
local idle = CreateFrame("Frame")
idle:RegisterEvent("PLAYER_ENTERING_WORLD")
idle:RegisterEvent("SPELLS_CHANGED")
idle:RegisterEvent("LEARNED_SPELL_IN_TAB")
idle:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
idle:SetScript("OnEvent", function()
    readBook()
    if not branch then
        branch = connect()
    end
    reposition()
    follow()
    if branch and EclipseBarFrame and EclipseBarFrame:IsShown() then
        lastState = nil
        updateEclipse(EclipseBarFrame)
    end
end)
