--[[----------------------------------------------------------------------------
mod-spheregrid — the feathers a priest has left, shown on the buff itself.

WHAT THIS IS FOR. Angelic Feather is held in threes: laying one down spends a
feather, and each one comes back on its own a few seconds later. The count
lives in an aura whose STACK is the number left, and the server now keeps that
aura on the priest at all times — three when none is missing, zero when none
is left.

WHY ANY CODE IS NEEDED HERE. The game hides a buff's number as soon as it is
one or less. `AuraButton_Update`, in the client's own BuffFrame.lua:

    if ( count > 1 ) then
        buff.count:SetText(count); buff.count:Show();
    else
        buff.count:Hide();
    end

So "1" and "0" would never be read, and a priest out of feathers would see a
buff saying nothing. That rule is Lua, and Lua can be wrapped: the function is
a global, this file runs as an addon after the game's own, and the wrapper
gives the number back TO THIS ONE AURA. No file of the game is touched, and
every other buff keeps the behaviour it has always had.

IF THE CLIENT DOES NOT SAY WHICH SPELL a buff belongs to, the wrapper does
nothing at all: the count then reads from two upwards, as it did before.

AND WHATEVER THE ORIGINAL RETURNS IS RETURNED IN TURN. `AuraButton_Update`
answers its caller -- BuffFrame_Update counts the buffs with that answer, and
places exactly as many buttons as it counted. A wrapper that forgets to pass
it back leaves the count at zero and the buff bar empty.
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- server side: we stop here
end

-- The aura whose stack is the number of feathers left. Written as a plain
-- number, like every other identifier the interface names: the installer
-- moves it with the rest when a server already uses this block.
local RESERVE = 8600099

local original = AuraButton_Update

if type(original) == "function" then
    AuraButton_Update = function(buttonName, index, filter)
        -- WHAT THE ORIGINAL RETURNS IS RETURNED IN TURN. That value is not a
        -- courtesy: BuffFrame_Update counts the buffs with it, and
        -- BuffFrame_UpdateAllBuffAnchors places exactly that many buttons.
        -- Swallowing it left the count at zero and emptied the whole buff bar,
        -- every buff of the game with it.
        local shown = original(buttonName, index, filter)
        if not shown then
            return shown                    -- no buff at this rank
        end

        local button = _G[tostring(buttonName) .. tostring(index)]
        if button and button.count then
            -- The eleventh value is the spell the buff comes from. A client
            -- that does not return it leaves `id` nil, and nothing happens.
            local name, _, _, count, _, _, _, _, _, _, id =
                UnitAura(PlayerFrame.unit, index, filter)
            if name and id == RESERVE then
                button.count:SetText(count or 0)
                button.count:Show()
            end
        end
        return shown
    end
end
