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
    The workbench, server side.

    Four recipes:

      fuse      3 identical stones           -> 1 stone of the quality above
      reroll    2 stones of the same quality -> 1 stone, same quality, other effect
      reforge   3 runes, any of them         -> 1 rune drawn from the catalogue
      grind     1 item                       -> Spherite, and the item is gone

    THIS FILE DECIDES NOTHING. It relays to the module's commands, which carry
    every rule and answer the player in their own language -- the same division
    as socketing. What it does do is serve the catalogue the client needs to
    recognise, among the bags, what can go into which recipe.

    It opens from the world object the module ships: the template comes with the
    SQL, and where it stands in the world is placed by hand.
------------------------------------------------------------------------------]]

local AIO = require("AIO")

local WorkbenchHandlers = AIO.AddHandlers("SphereGridWorkbench", {})

local fmt = string.format

local WORKBENCH_ENTRY = 803700
local GAMEOBJECT_EVENT_ON_USE = 14

-- The identifiers the module allocates (SphereGridMgr.h): a stone is
-- STONE_BASE + (statistic - 1) x qualities + (quality - 1), a statistic rune
-- STAT_RUNE_BASE + (statistic - 1).
local STONE_BASE = 804300
local STAT_RUNE_BASE = 804800
local QUALITY_COUNT = 5
local QUALITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- The settings come from mod-spheregrid.conf, the file the module itself reads.
-- A key that is absent gives back the empty string, hence the fallback -- which
-- must be the C++ default, or the window would announce a price the module does
-- not pay.
local function Conf(key, fallback)
    return tonumber(GetConfigValue(key)) or fallback
end

-- The statistics, in the order the module allocates them. THE SAME LIST AS THE
-- PLAYER INTERFACE: the order is what maps a stone onto a statistic, so the two
-- must never drift apart. See docs/PRESENTATION.md.
local STAT_KEYS = {
    "stamina", "intellect", "spirit", "agility", "strength",
    "parry", "block", "dodge", "haste", "crit", "hit",
    "spell_power", "attack_power", "armor_penetration", "expertise", "bonus_healing",
}

local CATALOGUE = nil

-- The catalogue is the same for the whole world and only moves on a
-- `.spheregrid reload`, so it is built once.
local function Catalogue()
    if CATALOGUE then return CATALOGUE end

    local cat = { stones = {}, runes = {}, statRunes = {} }

    -- WHAT A STONE IS follows from its entry -- statistic and quality -- and what
    -- it grants from the conf. THE DATABASE IS ASKED ONE THING ONLY: which of
    -- these entries exists as a real item. A node stone is worth less and exists
    -- as no item; the workbench must never fabricate one, and this is what keeps
    -- it out.
    local q = WorldDBQuery(fmt(
        "SELECT entry FROM item_template WHERE entry BETWEEN %d AND %d",
        STONE_BASE, STONE_BASE + #STAT_KEYS * QUALITY_COUNT - 1))
    if q then
        local bonus = {}
        for i = 1, QUALITY_COUNT do
            bonus[i] = Conf("SphereGrid.Stone.StatBonus." .. QUALITIES[i],
                            ({ 5, 7, 10, 15, 30 })[i])
        end
        repeat
            local entry = q:GetUInt32(0)
            local rank = entry - STONE_BASE
            local stat = STAT_KEYS[math.floor(rank / QUALITY_COUNT) + 1]
            local quality = rank % QUALITY_COUNT + 1
            if stat then
                cat.stones[entry] = { stat = stat, amount = bonus[quality],
                                       quality = quality }
            end
        until not q:NextRow()
    end

    q = WorldDBQuery(
        "SELECT r.item_entry, r.first_spell_id, r.base_rank, t.Quality FROM mod_spheregrid_rune r "
        .. "JOIN item_template t ON t.entry = r.item_entry")
    if q then
        repeat
            cat.runes[q:GetUInt32(0)] = { spell = q:GetUInt32(1), rank = q:GetUInt32(2) + 1,
                                          quality = q:GetUInt32(3) }
        until not q:NextRow()
    end

    -- Statistic runes: one per statistic, allocated in a row, and a single
    -- percentage for all of them. Epic, like the rank runes.
    local pct = Conf("SphereGrid.StatRune.Percent", 10)
    q = WorldDBQuery(fmt(
        "SELECT entry FROM item_template WHERE entry BETWEEN %d AND %d",
        STAT_RUNE_BASE, STAT_RUNE_BASE + #STAT_KEYS - 1))
    if q then
        repeat
            local entry = q:GetUInt32(0)
            local stat = STAT_KEYS[entry - STAT_RUNE_BASE + 1]
            if stat then
                cat.statRunes[entry] = { stat = stat, pct = pct, quality = 4 }
            end
        until not q:NextRow()
    end

    -- WHAT GRINDING PAYS. The window has to announce the amount BEFORE the
    -- gesture, so it needs the numbers too: stones by their quality, runes at a
    -- single price. THIS IS A DISPLAY AND NOTHING MORE -- the module remains the
    -- only judge of what is actually paid.
    cat.grind = { stone = {}, rune = 0 }
    local grindDefaults = { 100, 250, 500, 1000, 2500 }
    for i = 1, QUALITY_COUNT do
        cat.grind.stone[i] = Conf("SphereGrid.Points.Grind.Stone." .. QUALITIES[i],
                                  grindDefaults[i])
    end
    cat.grind.rune = Conf("SphereGrid.Points.Grind.Rune", 750)

    CATALOGUE = cat
    return cat
end

function WorkbenchHandlers.Catalogue(player)
    AIO.Handle(player, "SphereGridWorkbench", "Catalogue", Catalogue())
end

function WorkbenchHandlers.Open(player)
    AIO.Handle(player, "SphereGridWorkbench", "Show", Catalogue())
end

-- The four recipes. The module checks everything -- what the items are, their
-- qualities, whether the player holds them, whether there is room in the bags --
-- and speaks to the player. Here we only pass the request on, and let the client
-- refresh its own bags afterwards.
local function Whole(v)
    return type(v) == "number" and math.floor(v) or 0
end

function WorkbenchHandlers.Fuse(player, entry)
    entry = Whole(entry)
    if entry <= 0 then return end
    player:RunCommand(fmt("spheregrid fuse %d", entry))
end

function WorkbenchHandlers.Reroll(player, a, b)
    a, b = Whole(a), Whole(b)
    if a <= 0 or b <= 0 then return end
    player:RunCommand(fmt("spheregrid reroll %d %d", a, b))
end

function WorkbenchHandlers.Reforge(player, a, b, c)
    a, b, c = Whole(a), Whole(b), Whole(c)
    if a <= 0 or b <= 0 or c <= 0 then return end
    player:RunCommand(fmt("spheregrid reforge %d %d %d", a, b, c))
end

-- GRINDING takes ONE item, destroys it, and returns Spherite. It is the fourth
-- recipe and the only one that produces no item. What it pays depends on a
-- stone's quality, and is a single price for a rune.
function WorkbenchHandlers.Grind(player, entry)
    entry = Whole(entry)
    if entry <= 0 then return end
    player:RunCommand(fmt("spheregrid grind %d", entry))
end

-- The world object opens the window.
local function OnUseWorkbench(_, _, player)
    if not player then return end
    AIO.Handle(player, "SphereGridWorkbench", "Show", Catalogue())
    return true                             -- and nothing else happens
end

RegisterGameObjectEvent(WORKBENCH_ENTRY, GAMEOBJECT_EVENT_ON_USE, OnUseWorkbench)

print("SphereGrid: workbench loaded.")
