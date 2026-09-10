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
    The player interface, server side.

    It serves the definition -- the module's tables in the world database, filled
    by the editor's import -- and the character's state, and relays purchases to
    the module's `.spheregrid activate` command, RUN AS THE PLAYER: every rule of
    the game applies there (the start, adjacency, the cost, the class) and the
    localised messages come from there. The module's writes are synchronous, so
    the state read back here is always fresh.

    It opens with .spheregrid show, /spheregrid, or the button on the talent
    window. THIS file owns the interception of `.spheregrid show`;
    editor/Editor.lua owns the one for `.spheregrid editor`.
------------------------------------------------------------------------------]]

local AIO = require("AIO")

local PlayerHandlers = AIO.AddHandlers("SphereGridPlayer", {})

local fmt = string.format

local STONE_BASE = 803100
-- NODE STONES. A pre-filled cell carries its own family of entries; a stone
-- the player socketed keeps another. Same arithmetic, a different base.
local NODE_STONE_BASE = 803310
-- A statistic rune, one per statistic; and the pin, which empties a cell.
local STAT_RUNE_BASE = 803600
local PIN_ENTRY = 803300

-- HOW MANY QUALITIES, and the names the settings give them. Both belong to the
-- module (SphereGridMgr.h, SPHEREGRID_QUALITY_COUNT; SphereGridMgr.cpp,
-- QUALITIES) -- letting them drift would quote amounts the server never grants.
local QUALITY_COUNT = 5
local QUALITIES = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }

-- WHAT AN OPERATOR TUNES LIVES IN mod-spheregrid.conf, the very file the module
-- reads: one source for both sides, and no table to keep in step. A key that is
-- absent gives back the empty string, hence the fallback -- WHICH MUST BE THE
-- C++ DEFAULT, or the interface would announce a figure the module does not
-- honour.
local function Conf(key, fallback)
    return tonumber(GetConfigValue(key)) or fallback
end

-- The statistics by index, in the order the module allocates them. THE ORDER
-- IS A CONTRACT -- see docs/PRESENTATION.md.
local STAT_KEYS = {
    "stamina", "intellect", "spirit", "agility", "strength",
    "parry", "block", "dodge", "haste", "crit", "hit",
    "spell_power", "attack_power", "armor_penetration", "expertise", "bonus_healing",
}

-- Messages follow the client's language, the same rule as module_string.
local LOCALE_FRFR = 2
local MESSAGES = {
    no_grid = { "[Sphere grid] No grid is defined for your class yet.",
                      "[Sphèrier] Aucune grille n'est encore définie pour votre classe." },
    -- Neither the cost nor what the player holds: the refusal says only that
    -- there is not enough.
    not_enough_spherite = { "Not enough Spherite.", "Spherite insuffisante." },
}

-- An error, or something that cannot be done: the standard red text in the
-- middle of the screen, as the game does for its own refusals.
local function SayError(player, key, ...)
    local m = MESSAGES[key]
    local text = player:GetDbLocaleIndex() == LOCALE_FRFR and m[2] or m[1]
    if select("#", ...) > 0 then text = text:format(...) end
    player:SendNotification(text)
end

-- ---------------------------------------------------------------------------
-- Reading the definition from the world database. Cached per class and
-- refreshed on every opening -- the tables are small and openings are rare.
-- ---------------------------------------------------------------------------

local DEF_CACHE = {}

-- THE GRID'S FINGERPRINT: a handful of aggregates over the module's tables,
-- far cheaper than reading 2 500 cells again. It changes the moment an export
-- or a setting touches the database; while it holds, the cached definition is
-- still good -- and a client that already carries it has nothing to receive.
local function Fingerprint()
    local shares = {}
    local function aggregate(sql)
        local q = WorldDBQuery(sql)
        if not q then shares[#shares + 1] = "-" return end
        local fields = {}
        for i = 0, q:GetColumnCount() - 1 do fields[#fields + 1] = tostring(q:GetString(i)) end
        shares[#shares + 1] = table.concat(fields, ",")
    end
    aggregate("SELECT COUNT(*), COALESCE(SUM(node_id), 0), COALESCE(SUM(stone_stat), 0), "
        .. "COALESCE(SUM(stone_quality), 0), COALESCE(SUM(spell_id), 0), COALESCE(SUM(class_id), 0), "
        .. "COALESCE(SUM(cluster), 0) FROM mod_spheregrid_node")
    aggregate("SELECT COUNT(*), COALESCE(SUM(node_a), 0), COALESCE(SUM(node_b), 0) FROM mod_spheregrid_edge")
    aggregate("SELECT COUNT(*), COALESCE(SUM(node_id), 0), COALESCE(SUM(spell_id), 0), COALESCE(SUM(class_id), 0) FROM mod_spheregrid_node_spell")
    aggregate("SELECT COUNT(*), COALESCE(SUM(node_id), 0), COALESCE(SUM(class_id), 0) FROM mod_spheregrid_start")
    aggregate("SELECT COUNT(*), COALESCE(SUM(cluster_id), 0), COALESCE(SUM(x), 0), COALESCE(SUM(y), 0), COALESCE(SUM(rot), 0) FROM mod_spheregrid_cluster")
    aggregate("SELECT COUNT(*), COALESCE(SUM(first_spell_id), 0), COALESCE(SUM(base_rank), 0), COALESCE(SUM(class_id), 0) FROM mod_spheregrid_rune")

    -- THE SETTINGS COUNT AS WELL. What a stone grants, what a rune adds and what
    -- a step costs no longer live in a table: no aggregate would see them move,
    -- and all three travel in the wire. So they are read into the fingerprint,
    -- and an operator who edits the conf reaches every client on the next
    -- opening.
    local tuned = {}
    for q = 1, QUALITY_COUNT do
        tuned[#tuned + 1] = Conf("SphereGrid.Stone.StatBonus." .. QUALITIES[q], 0)
        tuned[#tuned + 1] = Conf("SphereGrid.NodeStone.StatBonus." .. QUALITIES[q], 0)
    end
    tuned[#tuned + 1] = Conf("SphereGrid.StatRune.Percent", 0)
    tuned[#tuned + 1] = Conf("SphereGrid.Cost.PerStep", 0)
    tuned[#tuned + 1] = Conf("SphereGrid.Cost.Cap", 0)
    tuned[#tuned + 1] = Conf("SphereGrid.Runes.PerSpell", 0)
    shares[#shares + 1] = table.concat(tuned, ",")

    -- A VERSION FOR THE WIRE FORMAT. The fingerprint follows from the database
    -- and the settings, yet the wire has changed shape on its own before -- it
    -- gained the cost of a cell, and it has since lost the old cost scale and the
    -- icon table. Without this token, clients would keep a cached definition of
    -- the older shape. Bump it whenever the shape of the wire changes.
    shares[#shares + 1] = "wire5-cost-by-distance"
    return table.concat(shares, "|")
end

local function Whole(x)
    return math.floor((x or 0) * 10000 + 0.5)
end

-- COST BY DISTANCE. What a cell costs no longer depends on how many cells are
-- already lit but on its POSITION -- its distance in links from the class's
-- start. The start is therefore free, each step away adds COST_PER_STEP, and
-- the whole is capped.
--
-- BOTH COME FROM THE CONF, the same two keys the module reads. The module is
-- the authority that charges; this script only displays and checks ahead, so
-- reading the settings rather than repeating them is what keeps the price shown
-- and the price taken the same.
local function CostPerStep() return Conf("SphereGrid.Cost.PerStep", 75) end
local function CostCap()     return Conf("SphereGrid.Cost.Cap", 2500) end

-- A breadth-first walk from `def.start` over the links already pruned, then
-- the cost of each cell. A cell not joined to the start is charged the cap,
-- as the module does.
local function ComputeCosts(def)
    local neighbours = {}
    for _, e in ipairs(def.edges) do
        neighbours[e[1]] = neighbours[e[1]] or {}
        neighbours[e[2]] = neighbours[e[2]] or {}
        neighbours[e[1]][#neighbours[e[1]] + 1] = e[2]
        neighbours[e[2]][#neighbours[e[2]] + 1] = e[1]
    end

    local dist = {}
    if def.start and def.start > 0 then
        dist[def.start] = 0
        local queue, first = { def.start }, 1
        while first <= #queue do
            local current = queue[first]
            first = first + 1
            local next = dist[current] + 1
            for _, v in ipairs(neighbours[current] or {}) do
                if dist[v] == nil then
                    dist[v] = next
                    queue[#queue + 1] = v
                end
            end
        end
    end

    local perStep, cap = CostPerStep(), CostCap()
    def.byId = {}
    for _, n in ipairs(def.nodes) do
        local d = dist[n.id]
        if d == nil then
            n.cost = cap
        else
            local raw = d * perStep
            n.cost = (raw > cap) and cap or raw
        end
        n.dist = d
        def.byId[n.id] = n
    end
    def.neighbours = neighbours
end

-- The cost of a cell, zero if it is unknown (the module will settle it).
local function NodeCost(def, nodeId)
    local n = def.byId and def.byId[nodeId]
    return n and n.cost or 0
end

-- THE WIRE FORMAT: what actually goes to the client. Positional arrays -- no
-- key repeated two thousand times -- coordinates as integers to the ten
-- thousandth, and nothing that follows from anything else: the stone alone is
-- enough to recover statistic, amount, quality and icon. The client unpacks it
-- (`UnpackDef`).
--   n : { id, kind, cluster, ring, branch, stone, spell, x*10000, y*10000, cost }
--   e : { a1, b1, a2, b2, ... }     c : { { id, x, y, rot } * 10000 }
--
-- THE OLD COST SCALE HAS LEFT THE WIRE. It priced a cell by how many were
-- already lit; the price now follows from the cell's distance and travels with
-- the cell itself. So has the icon table: a statistic's icon is a file the
-- module ships, named after the statistic, and the interface composes the path.
local function Compact(def, fingerprint)
    local wire = { v = fingerprint, n = {}, e = {}, c = {},
                  stones = def.stones, runes = def.runes, statRunes = def.statRunes,
                  pin = def.pin, runesPerSpell = def.runesPerSpell,
                  class = def.class, start = def.start }
    for i, n in ipairs(def.nodes) do
        wire.n[i] = { n.id, n.kind, n.cluster, n.ring, n.branch, n.stone or 0, n.spell or 0,
                     Whole(n.x), Whole(n.y), n.cost or 0 }
    end
    for _, e in ipairs(def.edges) do
        wire.e[#wire.e + 1] = e[1]
        wire.e[#wire.e + 1] = e[2]
    end
    for i, c in ipairs(def.clusters) do
        wire.c[i] = { c.id, Whole(c.x), Whole(c.y), Whole(c.rot) }
    end
    return wire
end

-- What a stone grants: entry -> statistic, amount, quality. NOT ONE ROW OF THIS
-- IS STORED. The entry says which statistic and which quality (the allocation
-- above), and the conf says what that quality is worth -- exactly the
-- computation the module makes (SphereGridMgr::LoadFromConfig).
--
-- Both families are built: the stones a player holds, and the node stones a
-- pre-filled cell carries, which are worth less and exist as no item.
local function LoadStones()
    local stones = {}
    local function lay(base, prefix, defaults)
        for stat = 1, #STAT_KEYS do
            for q = 1, QUALITY_COUNT do
                stones[base + (stat - 1) * QUALITY_COUNT + (q - 1)] = {
                    stat = STAT_KEYS[stat],
                    amount = Conf(prefix .. QUALITIES[q], defaults[q]),
                    quality = q,
                }
            end
        end
    end
    lay(STONE_BASE, "SphereGrid.Stone.StatBonus.", { 5, 7, 10, 15, 30 })
    lay(NODE_STONE_BASE, "SphereGrid.NodeStone.StatBonus.", { 1, 2, 3, 5, 7 })
    return stones
end

-- THE SHARED GRID. A class with no cells of its own reads the grid of class 0,
-- which belongs to everyone. The start stays its own: the module's table holds
-- one per class, all placed on the shared grid.
local function GridClass(classId)
    local q = WorldDBQuery(fmt(
        "SELECT COUNT(*) FROM mod_spheregrid_node WHERE class_id = %d", classId))
    if q and q:GetUInt32(0) > 0 then return classId end
    return 0
end

local function LoadDefinition(classId)
    -- Same database, same grid: the cached definition and its wire form still hold.
    local fingerprint = Fingerprint()
    local cached = DEF_CACHE[classId]
    if cached and cached.fingerprint == fingerprint then return cached end

    local def = { nodes = {}, edges = {}, clusters = {}, start = 0 }
    local stones = LoadStones()
    local grid = GridClass(classId)

    -- A CELL SAYS WHAT THE DESIGNER CHOSE -- a statistic and a quality -- and not
    -- what follows from it. The entry is computed from the allocation, so moving
    -- the base moves every pre-filled stone with it and no row of the shipped
    -- grid has to be rewritten. The module reads the same two columns the same
    -- way (SphereGridMgr::LoadFromDB).
    local q = WorldDBQuery(fmt(
        "SELECT node_id, kind, grid_x, grid_y, stone_stat, stone_quality, cluster, ring, branch, spell_id "
        .. "FROM mod_spheregrid_node WHERE class_id = %d", grid))
    if q then
        repeat
            local statId, quality = q:GetUInt32(4), q:GetUInt32(5)
            local stone = (statId > 0 and quality > 0)
                and (NODE_STONE_BASE + (statId - 1) * QUALITY_COUNT + (quality - 1)) or 0
            local effect = stones[stone]
            -- stat stays nil for an empty node (stone = 0): the client uses that to tell
            -- the drawing apart. `amount` feeds the summary, which adds up what the whole
            -- grid could grant.
            def.nodes[#def.nodes + 1] = {
                id = q:GetUInt32(0), kind = q:GetUInt32(1),
                x = q:GetFloat(2), y = q:GetFloat(3),
                stat = effect and effect.stat or nil,
                amount = effect and effect.amount or 0,
                quality = quality,
                stone = stone,
                cluster = q:GetUInt32(6), ring = q:GetUInt32(7), branch = q:GetUInt32(8),
                spell = q:GetUInt32(9),
            }
        until not q:NextRow()
    end

    -- SPELLS BY CLASS: on the shared grid, a spell cell teaches each class its own;
    -- spell_id remains the fallback.
    q = WorldDBQuery(fmt("SELECT node_id, spell_id FROM mod_spheregrid_node_spell WHERE class_id = %d", classId))
    if q then
        local own = {}
        repeat
            own[q:GetUInt32(0)] = q:GetUInt32(1)
        until not q:NextRow()
        for _, n in ipairs(def.nodes) do
            if n.kind == 2 and (own[n.id] or 0) > 0 then n.spell = own[n.id] end
        end
    end

    -- A spell cell with no spell for the class DOES NOT EXIST for it, nor do its
    -- links: the grid sent does not carry them.
    local hidden, kept = {}, {}
    for _, n in ipairs(def.nodes) do
        if n.kind == 2 and (n.spell or 0) == 0 then hidden[n.id] = true else kept[#kept + 1] = n end
    end
    def.nodes = kept

    q = WorldDBQuery(fmt("SELECT node_a, node_b FROM mod_spheregrid_edge WHERE class_id = %d", grid))
    if q then
        repeat
            local a, b = q:GetUInt32(0), q:GetUInt32(1)
            if not hidden[a] and not hidden[b] then def.edges[#def.edges + 1] = { a, b } end
        until not q:NextRow()
    end

    q = WorldDBQuery(fmt("SELECT cluster_id, x, y, rot FROM mod_spheregrid_cluster WHERE class_id = %d", grid))
    if q then
        repeat
            def.clusters[#def.clusters + 1] =
                { id = q:GetUInt32(0), x = q:GetFloat(1), y = q:GetFloat(2), rot = q:GetFloat(3) }
        until not q:NextRow()
    end

    q = WorldDBQuery(fmt("SELECT node_id FROM mod_spheregrid_start WHERE class_id = %d", classId))
    if q then def.start = q:GetUInt32(0) end

    -- The cost of every cell follows from the start and the links, so both are
    -- needed -- and the pruning of spell cells must already be done.
    ComputeCosts(def)

    -- The whole catalogue of stones: the client uses it to recognise, among the
    -- player's bags, what can be socketed -- and to describe it.
    def.stones = stones

    -- Rank runes: entry -> the spell improved, and the rank the FIRST rune grants.
    -- The client uses this to recognise them in the bags and describe them; the
    -- rule of three per spell stays with the module.
    -- The grid's class goes too: the client needs it to set aside the runes of
    -- other classes, `UnitClass` returning no numeric identifier in 3.3.5.
    def.class = classId

    def.runes = {}
    q = WorldDBQuery("SELECT item_entry, first_spell_id, base_rank, base_spell_id, is_talent, "
                     .. "class_id FROM mod_spheregrid_rune")
    if q then
        repeat
            def.runes[q:GetUInt32(0)] = {
                spell = q:GetUInt32(1),
                rank = q:GetUInt32(2) + 1,
                quality = 4,
                -- The game's own rank that must ALREADY be known: without it the rune stays
                -- inert, which is the module's rule. The player is told which one before
                -- socketing, but only when the spell comes from a talent -- anywhere else the
                -- requirement goes without saying.
                required = q:GetUInt32(3),
                talent = q:GetUInt32(4) ~= 0 or nil,
                -- Only this class can socket it. A rune drops with no condition attached: it is
                -- the workbench that makes it useful.
                class = q:GetUInt32(5),
            }
        until not q:NextRow()
    end

    -- Statistic runes give no points: they raise, by a percentage, what THE GRID
    -- already grants in that statistic. One per statistic, allocated in a row,
    -- and a single percentage for all of them -- the module builds the same
    -- catalogue from the same setting.
    def.statRunes = {}
    local pct = Conf("SphereGrid.StatRune.Percent", 10)
    for stat = 1, #STAT_KEYS do
        def.statRunes[STAT_RUNE_BASE + stat - 1] = {
            stat = STAT_KEYS[stat], pct = pct, quality = 4,
        }
    end

    -- The pin's entry is an identifier the module allocates, not a setting: the
    -- client only counts the ones in the bags, to say so before confirming.
    def.pin = PIN_ENTRY

    -- How many identical runes one grid accepts. The rule belongs to the module;
    -- the interface needs the number to stop offering a fourth.
    def.runesPerSpell = Conf("SphereGrid.Runes.PerSpell", 3)

    def.fingerprint = fingerprint
    def.wire = Compact(def, fingerprint)
    DEF_CACHE[classId] = def
    return def
end

-- ---------------------------------------------------------------------------
-- The character's state, from the characters database
-- ---------------------------------------------------------------------------

-- NO "NEXT COST" IN THE STATE. With cost by distance there is no single price
-- for the next purchase: every cell has its own, sent in the wire and shown in
-- the tooltip. The field was dropped rather than repaired.

local function LoadState(player, def)
    local guid = player:GetGUIDLow()
    local actives, content, raw, activeCount = {}, {}, {}, 0
    local forgotten = {}
    local earned, spent = 0, 0
    local stones = def.stones or LoadStones()

    -- WHAT IS EARNED BELONGS TO THE ACCOUNT, WHAT IS SPENT TO THE CHARACTER. Two
    -- queries, then, and what is available reads as "earned by the account, less
    -- spent by this character".
    local q = CharDBQuery(fmt(
        "SELECT earned FROM mod_spheregrid_account_points WHERE account_id = %d",
        player:GetAccountId()))
    if q then earned = q:GetUInt32(0) end
    q = CharDBQuery(fmt(
        "SELECT spent FROM mod_spheregrid_character_points WHERE guid = %d", guid))
    if q then spent = q:GetUInt32(0) end

    -- `active = 1` ONLY: a reset leaves the row in place, with its stone or its
    -- rune, but the cell is no longer bought.
    --
    -- `forgotten` comes too. A spell cell emptied by the pin STAYS BOUGHT, and
    -- its spell is unlearned until it is bought again: without this the interface
    -- would show it learned and offer nothing.
    q = CharDBQuery(fmt(
        "SELECT node_id, content_entry, forgotten FROM mod_spheregrid_character_node "
        .. "WHERE guid = %d AND active = 1", guid))
    if q then
        repeat
            local node, entry = q:GetUInt32(0), q:GetUInt32(1)
            if q:GetUInt32(2) ~= 0 then forgotten[node] = true end
            actives[node] = true
            activeCount = activeCount + 1
            -- `raw` says what the cell really carries, zero included: that is what tells an
            -- EMPTY active cell (socketable) from a filled one (pinnable). `content` exists
            -- only for stones, whose effect is known.
            raw[node] = entry
            local effect = stones[entry]
            if effect then
                content[node] = { stat = effect.stat, amount = effect.amount,
                                  quality = effect.quality }
            end
        until not q:NextRow()
    end

    -- WHAT A STONE CELL HOLDS BELONGS TO THE ACCOUNT: the account's row wins,
    -- failing that the node's own stone -- the same rule as the module
    -- (SphereGridPlayerMgr::Load). Sockets and spells belong to the character.
    local kindById, stoneById = {}, {}
    for _, n in ipairs(def.nodes) do
        kindById[n.id], stoneById[n.id] = n.kind, n.stone or 0
    end
    local account = {}
    q = CharDBQuery(fmt(
        "SELECT node_id, content_entry FROM mod_spheregrid_account_node WHERE account_id = %d",
        player:GetAccountId()))
    if q then
        repeat account[q:GetUInt32(0)] = q:GetUInt32(1) until not q:NextRow()
    end
    for node in pairs(actives) do
        if kindById[node] == 0 then
            local entry = account[node]
            if entry == nil then entry = stoneById[node] end
            raw[node] = entry
        end
    end

    -- The prerequisites the player REALLY meets, here and now: they move with his
    -- talents, so they follow the state and not the catalogue. Only the ones met
    -- are sent; absence means "not met".
    local requiredOk = {}
    for entry, r in pairs(def.runes or {}) do
        if r.required and r.required > 0 and player:HasSpell(r.required) then
            requiredOk[entry] = true
        end
    end

    -- `actives` and `content` follow from `raw` and the stone catalogue: the client
    -- rebuilds them (`UnpackState`), and the wire carries only the entry of each
    -- active cell.
    return {
        raw         = raw,
        -- What the ACCOUNT holds in EVERY stone node, bought or not: a node emptied on
        -- another character shows empty here too.
        contentCount = account,
        -- The spell cells whose spell has been given back: bought, yet unlearned.
        forgotten      = forgotten,
        requiredOk     = requiredOk,
        activeCount     = activeCount,
        available  = (earned > spent) and (earned - spent) or 0,
    }
end

-- ---------------------------------------------------------------------------
-- Handlers
-- ---------------------------------------------------------------------------

-- The catalogue of the module's items, asked for by the client as it loads.
-- Without it, a right-click on a stone BEFORE the window is first opened would
-- go unrecognised: the client would not know it is one.
function PlayerHandlers.Catalogue(player)
    local def = LoadDefinition(player:GetClass())
    AIO.Handle(player, "SphereGridPlayer", "Catalogue", {
        stones      = def.stones,
        runes        = def.runes,
        statRunes    = def.statRunes,
        pin      = def.pin,
        runesPerSpell = def.runesPerSpell,
    })
end

-- SPHERITE CAN ARRIVE WITHOUT THE PLAYER TOUCHING THE INTERFACE: a Nexus used,
-- a boss down, a dungeon finished. That credit happens in C++, which has no way
-- of sending an AIO message -- so it is the client that asks, and only while its
-- window is open.
--
-- TWO HANDLERS RATHER THAN ONE, so that nothing is redrawn for nothing: this
-- one returns ONLY the number, from a single query; the client asks for the
-- full state, which costs more, only if it moved.
function PlayerHandlers.Points(player)
    local earned, spent = 0, 0
    local q = CharDBQuery(fmt(
        "SELECT earned FROM mod_spheregrid_account_points WHERE account_id = %d",
        player:GetAccountId()))
    if q then earned = q:GetUInt32(0) end
    q = CharDBQuery(fmt(
        "SELECT spent FROM mod_spheregrid_character_points WHERE guid = %d",
        player:GetGUIDLow()))
    if q then spent = q:GetUInt32(0) end
    AIO.Handle(player, "SphereGridPlayer", "Points",
        (earned > spent) and (earned - spent) or 0)
end

-- The full state, without the grid's definition: the client already has it.
function PlayerHandlers.Refresh(player)
    local def = LoadDefinition(player:GetClass())
    if #def.nodes == 0 then return end
    AIO.Handle(player, "SphereGridPlayer", "Update", LoadState(player, def))
end

-- THE DEFINITION IS SENT ONCE PER VERSION. The client says which fingerprint it
-- holds; if it is the right one, only the state travels (`false` in place of the
-- wire -- a nil in the middle of the arguments does not survive the trip).
function PlayerHandlers.Open(player, version)
    local def = LoadDefinition(player:GetClass())
    if #def.nodes == 0 then
        SayError(player, "no_grid")
        return
    end
    local wire = (version == def.fingerprint) and false or def.wire
    AIO.Handle(player, "SphereGridPlayer", "Show", wire, LoadState(player, def), def.fingerprint)
end

function PlayerHandlers.Buy(player, nodeId)
    if type(nodeId) ~= "number" then return end

    -- Run AS THE PLAYER (his session, his security): the C++ module applies the
    -- rules and answers in his own language. The write is synchronous.
    player:RunCommand("spheregrid activate " .. math.floor(nodeId))

    local def = DEF_CACHE[player:GetClass()] or LoadDefinition(player:GetClass())
    AIO.Handle(player, "SphereGridPlayer", "Update", LoadState(player, def))
end

-- Buying a whole path, in order (from what is already lit towards the target),
-- all or nothing: the total is locked BEFORE the first purchase -- without that,
-- a path too dear would be bought halfway.
function PlayerHandlers.BuyPath(player, path)
    if type(path) ~= "table" or #path == 0 or #path > 300 then return end

    local def = DEF_CACHE[player:GetClass()] or LoadDefinition(player:GetClass())
    local state = LoadState(player, def)

    local total = 0
    for i = 1, #path do
        if type(path[i]) ~= "number" then return end
        -- The price depends on the cell, no longer on the order of purchase: the order
        -- along the path therefore does not change the total.
        total = total + NodeCost(def, math.floor(path[i]))
    end
    if state.available < total then
        SayError(player, "not_enough_spherite")
        return
    end

    -- Bought one step at a time through the module's command: each step checks every
    -- rule again (the order along the path satisfies adjacency). The writes being
    -- synchronous, a failure shows at once -- we stop there, the module having
    -- already told the player why.
    local guid = player:GetGUIDLow()
    for _, nodeId in ipairs(path) do
        nodeId = math.floor(nodeId)
        player:RunCommand("spheregrid activate " .. nodeId)
        if not CharDBQuery(fmt(
            "SELECT 1 FROM mod_spheregrid_character_node WHERE guid = %d AND node_id = %d AND active = 1",
            guid, nodeId)) then
            break
        end
    end

    AIO.Handle(player, "SphereGridPlayer", "Update", LoadState(player, def))
end

-- SOCKETING AND PINNING follow the same principle as buying: the module's command
-- carries EVERY rule -- the cell is active, the type fits, the item is in the
-- bags, the old content is destroyed -- and answers the player in his language.
-- The Lua only passes the request on and refreshes. The module's writes being
-- synchronous, the state read straight after is already the right one.
--
-- The client refuses a purchase before even offering it when the Spherite is
-- short; it comes through here so the message takes the usual red channel, with
-- the same words as the server's own refusal. Nothing is changed, nothing read.
function PlayerHandlers.Reject(player)
    SayError(player, "not_enough_spherite")
end

function PlayerHandlers.Socket(player, nodeId, itemEntry)
    if type(nodeId) ~= "number" or type(itemEntry) ~= "number" then return end
    nodeId, itemEntry = math.floor(nodeId), math.floor(itemEntry)
    if nodeId <= 0 or itemEntry <= 0 then return end

    player:RunCommand(fmt("spheregrid socket %d %d", nodeId, itemEntry))

    local def = DEF_CACHE[player:GetClass()] or LoadDefinition(player:GetClass())
    AIO.Handle(player, "SphereGridPlayer", "Update", LoadState(player, def))
end

function PlayerHandlers.Pin(player, nodeId)
    if type(nodeId) ~= "number" then return end
    nodeId = math.floor(nodeId)
    if nodeId <= 0 then return end

    player:RunCommand(fmt("spheregrid unsocket %d", nodeId))

    local def = DEF_CACHE[player:GetClass()] or LoadDefinition(player:GetClass())
    AIO.Handle(player, "SphereGridPlayer", "Update", LoadState(player, def))
end

-- RESETTING: the player hands back every cell and recovers the Spherite spent on
-- THIS character. As with buying, everything is in the module's command --
-- spells unlearned, stones and runes left where they sit, the refund -- and the
-- Lua only passes it on and refreshes.
-- The command takes no target: it acts on the character logged in.
function PlayerHandlers.Reset(player)
    player:RunCommand("spheregrid respec")

    local def = DEF_CACHE[player:GetClass()] or LoadDefinition(player:GetClass())
    AIO.Handle(player, "SphereGridPlayer", "Update", LoadState(player, def))
end

-- ---------------------------------------------------------------------------
-- The way in: .spheregrid show
-- ---------------------------------------------------------------------------

local function OnCommand(_, player, command)
    if not player then return end
    if not command then return end

    if command:lower():match("^spheregrid%s+show%s*$") then
        PlayerHandlers.Open(player)
        return false
    end
end

RegisterPlayerEvent(42, OnCommand)          -- PLAYER_EVENT_ON_COMMAND

print("SphereGrid: player interface loaded.")
