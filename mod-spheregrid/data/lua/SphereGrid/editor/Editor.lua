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
    The layout editor, server side.

    THIS FILE HOLDS NO GAME RULES. It is a workshop: it serves the client the
    catalogue and the geometry, then writes, reads back and checks layouts as
    XML files under lua_scripts\SphereGrid\editor\layouts\.

    The XML is deliberately readable and editable by hand: it is the exchange
    format between the in-game editor and any other tool.

    In game: .spheregrid editor (administrators only).
------------------------------------------------------------------------------]]

local AIO = require("AIO")

local EditorHandlers = AIO.AddHandlers("SphereGridEditor", {})

local sqrt, cos, sin, pi, floor = math.sqrt, math.cos, math.sin, math.pi, math.floor
local fmt = string.format

-- ---------------------------------------------------------------------------
-- The geometry of a cluster
-- ---------------------------------------------------------------------------
-- Three concentric rings of eight cells each. The eight cells of a ring share
-- their angles with the other rings, so the cells line up along eight branches
-- radiating from the centre, like a star.
--
-- The radii are chosen so that no pair of cells in one cluster falls below
-- SEP_MIN. The gap between rings went from 0.80 to 1.00: it was that, and not
-- the chord, that looked tightest.
--
--   chord within a ring: 2 R sin(22.5 deg)  ->  0.84 / 1.61 / 2.37
--   gap between rings:                          1.00 / 1.00
--
-- The tightest point is therefore the chord of the inner ring, at 0.84.
--
-- CAREFUL: a cell's position follows from these radii, so changing them moves
-- every cell of every layout already saved. Two neighbouring clusters must now
-- stand at least 6.9 units apart (3.1 + 3.1 + 0.7) instead of 6.1.

local GEOMETRY = {
    radii    = { 1.1, 2.1, 3.1 },
    branches = 8,
}

local SEP_MIN = 0.70            -- the smallest gap tolerated between two cells

-- ---------------------------------------------------------------------------
-- The catalogue
-- ---------------------------------------------------------------------------
-- The key is what gets written into the XML; it must never change.

local STATS = {
    { key = "stamina",          label = "Stamina",            cat = 1, icon = "Interface\\Icons\\Spell_Holy_WordFortitude" },
    { key = "intellect",       label = "Intellect",         cat = 1, icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
    { key = "spirit",             label = "Spirit",               cat = 1, icon = "Interface\\Icons\\Spell_Shadow_Charm" },
    { key = "agility",          label = "Agility",            cat = 1, icon = "Interface\\Icons\\Spell_Holy_BlessingOfAgility" },
    { key = "strength",              label = "Strength",                cat = 1, icon = "Interface\\Icons\\Spell_Nature_Strength" },
    { key = "parry",             label = "Parry",               cat = 2, icon = "Interface\\Icons\\Ability_Parry" },
    { key = "block",            label = "Block",              cat = 2, icon = "Interface\\Icons\\Ability_Warrior_ShieldWall" },
    { key = "dodge",            label = "Dodge",              cat = 2, icon = "Interface\\Icons\\Spell_Magic_LesserInvisibilty" },
    { key = "haste",               label = "Haste",                 cat = 2, icon = "Interface\\Icons\\Spell_Nature_BloodLust" },
    { key = "crit",           label = "Critical strike",             cat = 2, icon = "Interface\\Icons\\Ability_CriticalStrike" },
    { key = "hit",             label = "Hit",               cat = 2, icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },
    { key = "spell_power",    label = "Spell power",  cat = 2, icon = "Interface\\Icons\\Spell_Fire_FlameBolt" },
    { key = "attack_power",  label = "Attack power",  cat = 2, icon = "Interface\\Icons\\INV_Sword_04" },
    { key = "armor_penetration", label = "Armor penetration", cat = 2, icon = "Interface\\Icons\\Ability_Rogue_Ambush" },
    { key = "expertise",          label = "Expertise",            cat = 2, icon = "Interface\\Icons\\Ability_Warrior_WeaponMastery" },
    { key = "bonus_healing",        label = "Healing bonus",      cat = 2, icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
}

-- FIVE QUALITIES, the ones the game itself uses. The bonus shown here is the
-- one the editor's tooltip displays; in game it comes from the module's
-- configuration, like every other number.
--
-- What is shown is a NODE's bonus (+1/+2/+3/+5/+7); a stone the player
-- socketed grants more.
local QUALITIES = {
    { label = "Common",     bonus = 1 },
    { label = "Uncommon",   bonus = 2 },
    { label = "Rare",       bonus = 3 },
    { label = "Epic",       bonus = 5 },
    { label = "Legendary",  bonus = 7 },
}

-- There is no prismatic socket in the 3.3.5 client; the plain one exists. The
-- client now composes the socket's look itself, from the UI-ItemSockets sheet,
-- so this icon only serves the tooltips.
local SLOT_ICON = "Interface\\ItemSocketingFrame\\UI-EmptySocket"

local STAT_BY_KEY = {}
for i, s in ipairs(STATS) do STAT_BY_KEY[s.key] = i end

-- ---------------------------------------------------------------------------
-- Files
-- ---------------------------------------------------------------------------
-- The path is relative to the worldserver's working directory, the one that
-- already holds lua_scripts. Plain Lua can neither create a folder nor list a
-- directory, so the folder is made once by hand and the inventory of layouts is
-- kept in an index file.

local DIR   = "lua_scripts/SphereGrid/editor/layouts/"
local INDEX = DIR .. "index.txt"

local function SafeName(name)
    name = tostring(name or ""):gsub("[^%w%-_]", "")
    if name == "" then name = "unnamed" end
    return name:sub(1, 48)
end

local function ReadIndex()
    local list, f = {}, io.open(INDEX, "r")
    if not f then return list end
    for line in f:lines() do
        line = line:match("^%s*(.-)%s*$")
        if line ~= "" then list[#list + 1] = line end
    end
    f:close()
    return list
end

local function AddToIndex(name)
    for _, n in ipairs(ReadIndex()) do
        if n == name then return end
    end
    local f = io.open(INDEX, "a")
    if not f then return end
    f:write(name, "\n")
    f:close()
end

-- ---------------------------------------------------------------------------
-- Geometry that follows
-- ---------------------------------------------------------------------------

local function NodePosition(cluster, ring, branch)
    local r = GEOMETRY.radii[ring]
    if not r then return cluster.x, cluster.y end
    local a = (cluster.rot or 0) + (branch - 1) * 2 * pi / GEOMETRY.branches
    return cluster.x + r * cos(a), cluster.y + r * sin(a)
end

-- ---------------------------------------------------------------------------
-- Checking a layout
-- ---------------------------------------------------------------------------
-- Three faults are hard to see and easy to measure: two cells overlapping, a
-- link pointing at nothing, and a piece of grid nothing can reach.

-- THE STARTS ARE A TABLE, `class -> cell`. A class grid has only one, under
-- the key 0 ("every class"); the shared grid has one per class. A bare number
-- is still accepted -- it is the old form, and old sheets and old calls still
-- pass it.
local function Starts(d)
    if type(d) == "number" then return { [0] = d } end
    if type(d) ~= "table" then return {} end
    local t = {}
    for class, id in pairs(d) do
        class, id = tonumber(class), tonumber(id)
        if class and id then t[class] = id end
    end
    return t
end

-- The ten playable classes of WotLK: the shared grid wants, at every spell
-- cell, one spell for each of them.
local GAME_CLASSES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11 }

-- SPELLS BY CLASS. On the shared grid, a spell cell belongs to everyone: each
-- class learns ITS OWN there. `n.spells` carries the class -> identifier table;
-- `n.spell` remains the "every class" fallback.
local function Spells(t)
    local r = {}
    if type(t) ~= "table" then return r end
    for class, id in pairs(t) do
        class, id = tonumber(class), tonumber(id)
        if class and id and id > 0 then r[class] = id end
    end
    return r
end

-- The spell a class learns at a cell: its own, failing that the fallback,
-- failing that nothing.
local function SpellFor(n, class)
    local s = Spells(n.spells)[class]
    if s then return s end
    if n.spell and n.spell > 0 then return n.spell end
    return nil
end

local function Verify(clusters, nodes, edges, start)
    local starts = Starts(start)
    local byId, clusterById = {}, {}
    for _, c in ipairs(clusters) do clusterById[c.id] = c end

    local placed = {}
    for _, n in ipairs(nodes) do
        byId[n.id] = n
        local c = clusterById[n.cluster]
        if c then
            local x, y = NodePosition(c, n.ring, n.branch)
            placed[#placed + 1] = { id = n.id, x = x, y = y }
        end
    end

    local problems = {}

    -- THE OFFENDING CELLS, not just how many. A report saying "3 pieces not
    -- joined" over a grid of two hundred cells leaves the eye to hunt; the editor
    -- paints them red, but only if it is told WHICH. Only LINK faults are marked --
    -- those a particular cell is answerable for.
    local markers = {}
    local function Offender(id)
        if id and byId[id] then markers[id] = true end
    end

    -- orphan cells
    local orphans = #nodes - #placed
    if orphans > 0 then
        problems[#problems + 1] = fmt("%d cell(s) attached to a cluster that does not exist", orphans)
    end

    -- overlap
    local worst, wa, wb = math.huge, nil, nil
    for i = 1, #placed do
        for j = i + 1, #placed do
            local dx, dy = placed[i].x - placed[j].x, placed[i].y - placed[j].y
            local d = sqrt(dx * dx + dy * dy)
            if d < worst then worst, wa, wb = d, placed[i].id, placed[j].id end
        end
    end
    if #placed < 2 then worst = 0 end
    if #placed >= 2 and worst < SEP_MIN then
        problems[#problems + 1] = fmt("cells %d and %d too close (%.3f u, minimum %.2f)",
            wa or 0, wb or 0, worst, SEP_MIN)
        -- Both are painted red, like any fault a cell carries.
        Offender(wa)
        Offender(wb)
    end

    -- links pointing at nothing, and duplicates
    local adj, seenEdge, dangling, dupes = {}, {}, 0, 0
    for _, n in ipairs(nodes) do adj[n.id] = {} end
    for _, e in ipairs(edges) do
        local a, b = e[1] or e.a, e[2] or e.b
        if not byId[a] or not byId[b] or a == b then
            dangling = dangling + 1
            -- THE END THAT EXISTS carries the mark: the other is nowhere on screen, and
            -- painting it would teach nothing.
            Offender(a)
            Offender(b)
        else
            local k = (a < b) and (a .. ":" .. b) or (b .. ":" .. a)
            if seenEdge[k] then
                dupes = dupes + 1
                Offender(a)
                Offender(b)
            else
                seenEdge[k] = true
                table.insert(adj[a], b)
                table.insert(adj[b], a)
            end
        end
    end
    if dangling > 0 then
        problems[#problems + 1] = fmt("%d link(s) pointing at a cell that does not exist", dangling)
    end
    if dupes > 0 then
        problems[#problems + 1] = fmt("%d duplicate link(s)", dupes)
    end

    -- pieces standing apart
    --
    -- WHAT EACH PIECE IS MADE OF is kept, not merely how many there are: that is
    -- what says which cells to paint.
    local seen, pieces = {}, {}
    for _, n in ipairs(nodes) do
        if not seen[n.id] then
            local piece = { n.id }
            seen[n.id] = true
            local queue = { n.id }
            while #queue > 0 do
                local cur = table.remove(queue)
                for _, nb in ipairs(adj[cur] or {}) do
                    if not seen[nb] then
                        seen[nb] = true
                        queue[#queue + 1] = nb
                        piece[#piece + 1] = nb
                    end
                end
            end
            pieces[#pieces + 1] = piece
        end
    end
    local groups = #pieces
    if groups > 1 then
        problems[#problems + 1] = fmt("%d pieces not joined to one another", groups)

        -- THE PIECE OF REFERENCE is the one holding the start -- that one is the grid,
        -- and the others are what came away from it. With no start placed, or one
        -- pointing at a removed cell, the largest is taken instead: painting the two
        -- hundred cells of the trunk to flag an island of three would be exactly the
        -- opposite of a service.
        -- The reference piece holds a start -- any of them: they must all be on the
        -- same grid, and the first one found settles it.
        local ref
        local isStart = {}
        for _, id in pairs(starts) do isStart[id] = true end
        for i, m in ipairs(pieces) do
            for _, id in ipairs(m) do
                if isStart[id] and byId[id] then ref = i break end
            end
            if ref then break end
        end
        if not ref then
            ref = 1
            for i, m in ipairs(pieces) do
                if #m > #pieces[ref] then ref = i end
            end
        end

        for i, m in ipairs(pieces) do
            if i ~= ref then
                for _, id in ipairs(m) do Offender(id) end
            end
        end
    end

    -- the start: every class has one, and the import into the module's tables
    -- requires it.
    local startCount = 0
    for class, id in pairs(starts) do
        startCount = startCount + 1
        if not byId[id] then
            problems[#problems + 1] = fmt("the start (class %d) points at cell %d, which was removed", class, id)
            Offender(id)
        end
    end
    if startCount == 0 then
        problems[#problems + 1] = "no start has been set"
    end

    -- VISIBILITY BY CLASS: a spell cell with no spell for a class DOES NOT EXIST
    -- for that class, nor do its links. Each class must therefore reach, from ITS
    -- OWN start, everything it can see -- a spell cell that is silent for it, laid
    -- as a bridge, cuts its grid in two.
    -- Pointless if the grid is already in pieces: the overall fault says enough.
    if groups == 1 then
        for _, class in ipairs(GAME_CLASSES) do
            local startId = starts[class] or starts[0]
            if startId and byId[startId] then
                local function visible(id)
                    local n = byId[id]
                    return n and not (n.kind == 2 and not SpellFor(n, class))
                end
                if not visible(startId) then
                    problems[#problems + 1] = fmt(
                        "the start of class %d (%d) is a spell cell with no spell for it", class, startId)
                    Offender(startId)
                else
                    local seen, queue = { [startId] = true }, { startId }
                    while #queue > 0 do
                        local cur = table.remove(queue)
                        for _, nb in ipairs(adj[cur] or {}) do
                            if not seen[nb] and visible(nb) then
                                seen[nb] = true
                                queue[#queue + 1] = nb
                            end
                        end
                    end
                    local lost = {}
                    for _, n in ipairs(nodes) do
                        if visible(n.id) and not seen[n.id] then lost[#lost + 1] = n.id end
                    end
                    if #lost > 0 then
                        problems[#problems + 1] = fmt(
                            "class %d: %d cell(s) out of reach of its start (a spell it cannot see acts as a bridge)",
                            class, #lost)
                        for _, id in ipairs(lost) do Offender(id) end
                    end
                end
            end
        end
    end

    local slots = 0
    for _, n in ipairs(nodes) do
        if n.kind == 1 then slots = slots + 1 end
    end

    -- AS A LIST, not a table indexed by identifier: AIO serialises a dense array
    -- without complaint, where a sparse table with numeric keys travels less
    -- surely.
    local offenders = {}
    for id in pairs(markers) do offenders[#offenders + 1] = id end

    return {
        offenders  = offenders,
        starts  = startCount,
        clusters = #clusters,
        nodes    = #nodes,
        slots    = slots,
        edges    = #edges,
        minSeparation   = worst,
        groups   = groups,
        problems = problems,
        ok       = (#problems == 0),
    }
end

-- ---------------------------------------------------------------------------
-- Writing the XML
-- ---------------------------------------------------------------------------

local function WriteXML(name, clusters, nodes, edges, start)
    local path = DIR .. name .. ".xml"
    local f, err = io.open(path, "w")
    if not f then
        return nil, tostring(err)
    end

    f:write('<?xml version="1.0" encoding="UTF-8"?>\n')
    f:write('<spheregrid version="1" name="', name, '">\n')

    f:write('  <clusters>\n')
    for _, c in ipairs(clusters) do
        f:write(fmt('    <cluster id="%d" x="%.4f" y="%.4f" rot="%.4f"/>\n',
            c.id, c.x, c.y, c.rot or 0))
    end
    f:write('  </clusters>\n')

    f:write('  <cells>\n')
    for _, n in ipairs(nodes) do
        if n.kind == 1 then
            f:write(fmt('    <cell id="%d" cluster="%d" ring="%d" branch="%d" type="slot"/>\n',
                n.id, n.cluster, n.ring, n.branch))
        elseif n.kind == 2 then
            f:write(fmt('    <cell id="%d" cluster="%d" ring="%d" branch="%d" type="spell" spell="%d"/>\n',
                n.id, n.cluster, n.ring, n.branch, n.spell or 0))
        elseif STATS[n.stat] then
            f:write(fmt('    <cell id="%d" cluster="%d" ring="%d" branch="%d" type="node" stat="%s" quality="%d"/>\n',
                n.id, n.cluster, n.ring, n.branch, STATS[n.stat].key, n.quality or 1))
        else
            -- An empty node: no stat attribute.
            f:write(fmt('    <cell id="%d" cluster="%d" ring="%d" branch="%d" type="node"/>\n',
                n.id, n.cluster, n.ring, n.branch))
        end
    end
    f:write('  </cells>\n')

    f:write('  <links>\n')
    for _, e in ipairs(edges) do
        f:write(fmt('    <link a="%d" b="%d"/>\n', e[1] or e.a, e[2] or e.b))
    end
    f:write('  </links>\n')

    -- Spells by class for the spell cells: one line per (cell, class), sorted; the
    -- cell's own spell attribute keeps the fallback.
    local spellLines = {}
    for _, n in ipairs(nodes) do
        if n.kind == 2 then
            local s = Spells(n.spells)
            local classes = {}
            for class in pairs(s) do classes[#classes + 1] = class end
            table.sort(classes)
            for _, class in ipairs(classes) do
                spellLines[#spellLines + 1] = fmt('    <spell cell="%d" class="%d" id="%d"/>\n',
                    n.id, class, s[class])
            end
        end
    end
    if #spellLines > 0 then
        f:write('  <spells>\n')
        for _, l in ipairs(spellLines) do f:write(l) end
        f:write('  </spells>\n')
    end

    -- One start per line, the class as an attribute; key 0 keeps the older form
    -- with no class, so that the per-class sheets do not change.
    local starts = Starts(start)
    local classes = {}
    for class in pairs(starts) do classes[#classes + 1] = class end
    table.sort(classes)
    for _, class in ipairs(classes) do
        if class == 0 then
            f:write(fmt('  <start id="%d"/>\n', starts[class]))
        else
            f:write(fmt('  <start class="%d" id="%d"/>\n', class, starts[class]))
        end
    end

    f:write('</spheregrid>\n')
    f:close()

    return path
end

-- ---------------------------------------------------------------------------
-- Reading the XML
-- ---------------------------------------------------------------------------
-- The format is flat and carries no free text, so reading it by patterns is
-- enough and spares us a full parser. Any attribute left out takes a default
-- rather than failing the import.

local function Attr(tag, key)
    return tag:match(key .. '%s*=%s*"([^"]*)"')
end

local function ReadXML(name)
    local path = DIR .. name .. ".xml"
    local f = io.open(path, "r")
    if not f then
        return nil, "file not found: " .. path
    end
    local text = f:read("*a")
    f:close()

    local clusters, nodes, edges = {}, {}, {}

    for tag in text:gmatch("<cluster%s+[^>]->") do
        clusters[#clusters + 1] = {
            id  = tonumber(Attr(tag, "id")) or (#clusters + 1),
            x   = tonumber(Attr(tag, "x")) or 0,
            y   = tonumber(Attr(tag, "y")) or 0,
            rot = tonumber(Attr(tag, "rot")) or 0,
        }
    end

    for tag in text:gmatch("<cell%s+[^>]->") do
        local t = Attr(tag, "type")
        local kind = (t == "slot") and 1 or (t == "spell") and 2 or 0
        local n = {
            id      = tonumber(Attr(tag, "id")) or (#nodes + 1),
            cluster = tonumber(Attr(tag, "cluster")) or 0,
            ring    = tonumber(Attr(tag, "ring")) or 1,
            branch  = tonumber(Attr(tag, "branch")) or 1,
            kind    = kind,
        }
        if kind == 0 then
            -- The stone is optional: a node with no stat attribute is an empty node.
            n.stat = STAT_BY_KEY[Attr(tag, "stat") or ""]
            if n.stat then
                -- Bounded: layouts written before the move to five qualities can carry the
                -- index 6.
                n.quality = math.min(#QUALITIES, math.max(1, tonumber(Attr(tag, "quality")) or 1))
            end
        elseif kind == 2 then
            n.spell = tonumber(Attr(tag, "spell")) or 0
        end
        nodes[#nodes + 1] = n
    end

    for tag in text:gmatch("<link%s+[^>]->") do
        local a, b = tonumber(Attr(tag, "a")), tonumber(Attr(tag, "b"))
        if a and b then edges[#edges + 1] = { a, b } end
    end

    -- Spells by class: the pattern for "<spell " takes neither the <spells> tag
    -- nor a cell's type="spell" attribute, because it demands a blank after the
    -- name.
    local byId = {}
    for _, n in ipairs(nodes) do byId[n.id] = n end
    for tag in text:gmatch("<spell%s+[^>]->") do
        local n = byId[tonumber(Attr(tag, "cell")) or -1]
        local class, id = tonumber(Attr(tag, "class")), tonumber(Attr(tag, "id"))
        if n and n.kind == 2 and class and id and id > 0 then
            n.spells = n.spells or {}
            n.spells[class] = id
        end
    end

    local starts = {}
    for tag in text:gmatch("<start%s+[^>]->") do
        local id = tonumber(Attr(tag, "id"))
        local class = tonumber(Attr(tag, "class")) or 0
        if id then starts[class] = id end
    end

    return { clusters = clusters, nodes = nodes, edges = edges, start = starts }
end

-- ---------------------------------------------------------------------------
-- Handlers
-- ---------------------------------------------------------------------------
-- THE EDITOR IS FOR ADMINISTRATORS. The guard lives HERE, in every handler, and
-- not only in the command: a client can call AIO directly, so the server is what
-- settles it.

local ADMIN_RANK = 3        -- SEC_ADMINISTRATOR

local function IsAdmin(player)
    -- Test benches outside a server (the importer, the renderer) pass a stand-in
    -- player with no methods: out of the game there is no security to apply.
    if not player or type(player.GetGMRank) ~= "function" then return true end
    return player:GetGMRank() >= ADMIN_RANK
end

function EditorHandlers.RequestSession(player)
    if not IsAdmin(player) then return end
    AIO.Handle(player, "SphereGridEditor", "ReceiveSession",
        GEOMETRY, STATS, QUALITIES, SLOT_ICON, ReadIndex(), SEP_MIN)
end

function EditorHandlers.Verify(player, clusters, nodes, edges, start)
    if not IsAdmin(player) then return end
    AIO.Handle(player, "SphereGridEditor", "ReceiveReport",
        Verify(clusters or {}, nodes or {}, edges or {}, start), nil)
end

function EditorHandlers.Save(player, name, clusters, nodes, edges, start)
    if not IsAdmin(player) then return end
    name = SafeName(name)
    clusters, nodes, edges = clusters or {}, nodes or {}, edges or {}

    local report = Verify(clusters, nodes, edges, start)
    local path, err = WriteXML(name, clusters, nodes, edges, start)

    if not path then
        report.problems[#report.problems + 1] = "could not be written: " .. tostring(err)
        report.ok = false
        AIO.Handle(player, "SphereGridEditor", "ReceiveReport", report, nil)
        return
    end

    AddToIndex(name)
    AIO.Handle(player, "SphereGridEditor", "ReceiveReport", report,
        fmt("Layout \"%s\" saved (%d cells).", name, #nodes))
    AIO.Handle(player, "SphereGridEditor", "ReceiveLayoutList", ReadIndex())
end

function EditorHandlers.Load(player, name)
    if not IsAdmin(player) then return end
    name = SafeName(name)
    local data, err = ReadXML(name)
    if not data then
        AIO.Handle(player, "SphereGridEditor", "ReceiveReport",
            { problems = { tostring(err) }, ok = false, clusters = 0, nodes = 0,
              slots = 0, edges = 0, minSeparation = 0, groups = 0 }, nil)
        return
    end

    local report = Verify(data.clusters, data.nodes, data.edges, data.start)
    AIO.Handle(player, "SphereGridEditor", "ReceiveLayout",
        data.clusters, data.nodes, data.edges, name, report, data.start)
end

function EditorHandlers.ListLayouts(player)
    if not IsAdmin(player) then return end
    AIO.Handle(player, "SphereGridEditor", "ReceiveLayoutList", ReadIndex())
end

-- ---------------------------------------------------------------------------
-- The way in: .spheregrid editor (administrators)
-- ---------------------------------------------------------------------------
-- A bare .spheregrid is NOT intercepted: it goes through to the module's own
-- command, whose root prints the list of subcommands.
-- .spheregrid show belongs to the player interface (player/Player.lua).

-- Messages follow the client's language: English by default, French for frFR --
-- the same rule as the module's own module_string entries.
local LOCALE_FRFR = 2               -- LocaleConstant frFR

local MESSAGES = {
    editor_open  = { "[Sphere grid] Editor opened.",
                        "[Sphèrier] Éditeur ouvert." },
    editor_taken = { "[Sphere grid] The editor is restricted to administrators.",
                        "[Sphèrier] L'éditeur est réservé aux administrateurs." },
}

local function Say(player, key)
    local m = MESSAGES[key]
    player:SendBroadcastMessage(player:GetDbLocaleIndex() == LOCALE_FRFR and m[2] or m[1])
end

-- An error, or something that cannot be done: the standard red text in the
-- middle of the screen, as the game does for its own refusals.
local function SayError(player, key)
    local m = MESSAGES[key]
    player:SendNotification(player:GetDbLocaleIndex() == LOCALE_FRFR and m[2] or m[1])
end

local function OnCommand(_, player, command)
    if not player then return end
    if not command then return end

    local cmd = command:lower()

    if cmd:match("^spheregrid%s+editor%s*$") then
        if IsAdmin(player) then
            AIO.Handle(player, "SphereGridEditor", "OpenEditor")
            Say(player, "editor_open")
        else
            SayError(player, "editor_taken")
        end
        return false
    end
end

RegisterPlayerEvent(42, OnCommand)          -- PLAYER_EVENT_ON_COMMAND

print(fmt("SphereGrid: editor loaded, %d layout(s) in store.", #ReadIndex()))
