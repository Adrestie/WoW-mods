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
    The sphere grid at the workbench: what the SHARED bench
    (lua_scripts/Workbench, a component several modules bring their recipes
    to) can do with stones and runes.

      fuse      3 identical stones           -> 1 stone of the quality above
      reroll    2 stones of the same quality -> 1 stone, same quality, other effect
      reforge   3 runes, any of them         -> 1 rune drawn from the catalogue
      grind     1 item                       -> Spherite, and the item is gone

    THIS FILE DECIDES NOTHING. It says which items are the sphere grid's and
    which combinations the bench may offer; the module's commands, run as the
    player, carry every rule and answer the player in their own language --
    the same division as socketing. The window, the object in the world and
    the lock by content belong to the shared component; the sphere grid only
    registers itself as a provider.
------------------------------------------------------------------------------]]

local fmt = string.format

if not Workbench then
    print("SphereGrid: the shared workbench (lua_scripts/Workbench/Workbench.ext) is not loaded; no recipe registered.")
    return
end

-- The identifiers the module allocates (SphereGridMgr.h): a stone is
-- STONE_BASE + (statistic - 1) x qualities + (quality - 1), a statistic rune
-- STAT_RUNE_BASE + (statistic - 1).
local STONE_BASE = 803100
local STAT_RUNE_BASE = 803600
local QUALITY_COUNT = 5
local STAT_COUNT = 16

-- What a stone and a rune are, read once from the base -- the same reading
-- as before, minus the amounts the old window used to announce: the module
-- says what it pays when it pays it.
local stones, runes = {}, {}

local q = WorldDBQuery(fmt(
    "SELECT entry FROM item_template WHERE entry BETWEEN %d AND %d",
    STONE_BASE, STONE_BASE + STAT_COUNT * QUALITY_COUNT - 1))
if q then
    repeat
        local entry = q:GetUInt32(0)
        local rank = entry - STONE_BASE
        stones[entry] = { stat = math.floor(rank / QUALITY_COUNT) + 1, quality = rank % QUALITY_COUNT + 1 }
    until not q:NextRow()
end

q = WorldDBQuery("SELECT item_entry FROM mod_spheregrid_rune")
if q then
    repeat runes[q:GetUInt32(0)] = true until not q:NextRow()
end

q = WorldDBQuery(fmt(
    "SELECT entry FROM item_template WHERE entry BETWEEN %d AND %d",
    STAT_RUNE_BASE, STAT_RUNE_BASE + STAT_COUNT - 1))
if q then
    repeat runes[q:GetUInt32(0)] = true until not q:NextRow()
end

local function AllStones(entries)
    for _, e in ipairs(entries) do
        if not stones[e] then return false end
    end
    return true
end

local function AllRunes(entries)
    for _, e in ipairs(entries) do
        if not runes[e] then return false end
    end
    return true
end

-- WHAT THE BENCH SHOWS AS THE RESULT, as the old window did: the stone one
-- quality above, a stone of the same quality as a witness of a reroll, "a
-- rune" for a reforge, Spherite for a grind -- with the amount, read from
-- mod-spheregrid.conf as the module itself reads it (a display, nothing
-- more: the module remains the only judge of what is paid).
local LOCALE_FRFR = 2
local QUALITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
-- A result drawn at random shows the type's icon under the game's red
-- question mark: the module's own textures (data/art/Textures).
local RANDOM_STONE = "Textures\\random_stone_"           -- .. common / uncommon / rare / epic / legendary
local RANDOM_RUNE = "Textures\\random_rune"
local SPHERITE = "Interface\\Icons\\Spell_Nature_WispSplode"

local function Conf(key, fallback)
    return tonumber(GetConfigValue(key)) or fallback
end

local function StoneEntry(stat, quality)
    return STONE_BASE + (stat - 1) * QUALITY_COUNT + (quality - 1)
end

local function GrindAmount(entry)
    local stone = stones[entry]
    if stone then
        return Conf("SphereGrid.Points.Grind.Stone." .. QUALITIES[stone.quality],
                    ({ 100, 250, 500, 1000, 2500 })[stone.quality])
    end
    return Conf("SphereGrid.Points.Grind.Rune", 750)
end

local function Text(player, en, fr)
    return player:GetDbLocaleIndex() == LOCALE_FRFR and fr or en
end

Workbench.Register({
    module = "mod-spheregrid",
    Owns = function(entry)
        return stones[entry] ~= nil or runes[entry] == true
    end,
    kinds = {
        { key = "stone", name = { enUS = "Stones", frFR = "Pierres" },
          Of = function(entry) return stones[entry] ~= nil end },
        { key = "rune", name = { enUS = "Runes", frFR = "Runes" },
          Of = function(entry) return runes[entry] == true end },
    },
    recipes = {
        {
            key = "fuse", slots = 3,
            name = { enUS = "Merging: the same stone, one quality above.",
                     frFR = "Fusion : la même pierre, une qualité au-dessus." },
            Fits = function(_, placed, entry)
                if not stones[entry] or stones[entry].quality >= QUALITY_COUNT then return false end
                for _, p in ipairs(placed) do
                    if p ~= entry then return false end
                end
                return true
            end,
            Accepts = function(_, e)
                return AllStones(e) and e[1] == e[2] and e[2] == e[3] and stones[e[1]].quality < QUALITY_COUNT
            end,
            Preview = function(_, e)
                local s = stones[e[1]]
                return { entry = StoneEntry(s.stat, s.quality + 1) }
            end,
            Run = function(player, e) player:RunCommand(fmt("spheregrid fuse %d", e[1])) end,
        },
        {
            key = "reroll", slots = 2,
            name = { enUS = "Reroll: another stone, of the same quality.",
                     frFR = "Relance : une autre pierre, de même qualité." },
            Fits = function(_, placed, entry)
                if not stones[entry] then return false end
                for _, p in ipairs(placed) do
                    if not stones[p] or stones[p].quality ~= stones[entry].quality then return false end
                end
                return true
            end,
            Accepts = function(_, e)
                return AllStones(e) and stones[e[1]].quality == stones[e[2]].quality
            end,
            Preview = function(player, e)
                local quality = stones[e[1]].quality
                return { icon = RANDOM_STONE .. string.lower(QUALITIES[quality]), quality = quality - 1,
                         text = Text(player, "Stone drawn at random, statistic unknown.",
                                     "Pierre tirée au hasard, statistique inconnue.") }
            end,
            Run = function(player, e) player:RunCommand(fmt("spheregrid reroll %d %d", e[1], e[2])) end,
        },
        {
            key = "reforge", slots = 3,
            name = { enUS = "Recasting: one rune drawn at random from the whole catalogue.",
                     frFR = "Refonte : une rune tirée au hasard dans tout le catalogue." },
            Fits = function(_, placed, entry) return runes[entry] == true and AllRunes(placed) end,
            Accepts = function(_, e) return AllRunes(e) end,
            Preview = function(player)
                return { icon = RANDOM_RUNE, text = Text(player, "Rune drawn at random.", "Rune tirée au hasard."), quality = 4 }
            end,
            Run = function(player, e) player:RunCommand(fmt("spheregrid reforge %d %d %d", e[1], e[2], e[3])) end,
        },
        {
            key = "grind", slots = 1,
            name = { enUS = "Grinding: the item is destroyed and turned into Spherite.",
                     frFR = "Broyage : l'objet est détruit et rendu en Spherite." },
            Fits = function(_, placed, entry)
                return #placed == 0 and (stones[entry] ~= nil or runes[entry] == true)
            end,
            Accepts = function(_, e) return stones[e[1]] ~= nil or runes[e[1]] == true end,
            Preview = function(_, e)
                return { icon = SPHERITE, text = fmt("+%d Spherite", GrindAmount(e[1])) }
            end,
            Run = function(player, e) player:RunCommand(fmt("spheregrid grind %d", e[1])) end,
        },
    },
})
