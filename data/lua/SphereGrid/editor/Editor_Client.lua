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
    The layout editor, client side.

    Sent to the client by AIO: nothing to install, nothing to package.

    Three tools:
      Select   click a cell to inspect and change it;
               drag a cluster's marker to move it;
               drag the background to move about the grid.
      Cluster  click empty space to lay a cluster down;
               click a cluster's marker to delete it.
      Link     click two cells to make or unmake the link between them.

    A cluster is three concentric rings of eight cells, lined up along eight
    branches from the centre. What it holds is drawn at random when it is laid
    down, and can then be edited cell by cell.

    Saving produces a readable XML file under
    lua_scripts\SphereGrid\editor\layouts\.
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- server side: we stop here
end

local EditorHandlers = AIO.AddHandlers("SphereGridEditor", {})

local sqrt, cos, sin, pi     = math.sqrt, math.cos, math.sin, math.pi
local floor, max, min, abs   = math.floor, math.max, math.min, math.abs
local random                 = math.random
local fmt                    = string.format

-- ---------------------------------------------------------------------------
-- Drawing constants
-- ---------------------------------------------------------------------------

-- Lua 5.1, which the client runs, allows a function sixty upvalues at most. So
-- every drawing constant lives in ONE table -- a single upvalue.
local RC = {}

RC.SPACING    = 64       -- pixels per grid unit
RC.NODE_SIZE  = 34
RC.EDGE_THICK = 11   -- the "conduit" style: must match the generator's thicknesses
RC.MARGIN     = 120

-- A NODE (a stone): a round plate plus a ring tinted to the quality's colour.
-- gradientCircle and ping4 are textures WITH NO ALPHA, white on black: they only
-- work in ADD blending, where the black disappears and the white takes the tint
-- -- which is what allows a blue or purple ring, impossible with the client's
-- golden rings (multiplying the channels: gold x blue is nearly black).
RC.NODE_DISC_TEXTURE = "Interface\\GLUES\\MODELS\\UI_Tauren\\gradientCircle"
RC.NODE_RING_TEXTURE = "Interface\\Cooldown\\ping4"
RC.NODE_DISC_SIZE  = 78  -- the gradient's core is about 42% of the texture, so a disc of about 33 px
RC.NODE_RING_SIZE  = 46  -- ping4's ring runs at about 94% of its texture, which gives
                         -- a radius of about 21.6: just beyond the icon's frame
RC.NODE_DISC_COLOR = { 0.05, 0.05, 0.06 }

-- A SOCKET (a rune): the gem setting from the socketing window, unchanged.
-- The composition is read off Blizzard_ItemSocketingUI.xml (a 40px button): a
-- shadowed hollow 72x74 plus a frame 57x52 -- the sheet's plain "Socket"
-- region, silver, and therefore tintable for the editor's states.
RC.SOCKET_SHEET        = "Interface\\ItemSocketingFrame\\UI-ItemSockets"
RC.SOCKET_HOLE_COORDS  = { 0.71875, 1, 0.7109375, 1 }
RC.SOCKET_FRAME_COORDS = { 0.171875, 0.3984375, 0.40234375, 0.609375 }
RC.SLOT_SCALE = 0.80     -- our grid step is tighter than the game's own button

-- A NODE'S ICON FILLS THE CIRCLE: the engine's portrait mask
-- (SetPortraitToTexture) cuts it round and makes the square's corners vanish.
-- The ring being a thin additive stroke and not a covering edge, the icon's disc
-- must stay inside it: radius 17 against a ring at 18.8, the dark disc filling
-- the sliver between the two. Two pixels short of the circle, so the mask also
-- trims the white border the game's icons carry.
RC.ICON_SIZE_NODE = 34
RC.SNAP       = 0.25     -- the step a cluster snaps to, in grid units

RC.ZOOM_MIN, RC.ZOOM_MAX, RC.ZOOM_STEP = 0.30, 1.60, 0.10

RC.PANEL_W = 208

RC.KIND_NODE, RC.KIND_SLOT, RC.KIND_SPELL = 0, 1, 2

-- The module's textures, shipped in its archive and read from there. A path is
-- written WITHOUT its extension: the client adds .blp itself.
--
-- The line replaces UI-Taxi-Line, whose core is nearly black (RGB 18, opaque):
-- tinted grey it produced the dark streak down the middle of every segment. A
-- line texture must always carry TRANSPARENT margins around the stroke -- that
-- is what lets a rotation through SetTexCoord produce a slanted segment.
RC.ART_DIR      = "Interface\\Spheregrid\\"
RC.LINE_TEXTURE = RC.ART_DIR .. "line"
RC.LINEFACTOR_2 = (128 / 126) / 2

-- RING ARCS BAKED INTO TEXTURES: one file per cluster radius, with the 45
-- degree arc drawn once and for all -- a curved link becomes ONE smooth quad
-- instead of a string of segments. The geometry is baked in: a chord of 240
-- texels between (8,100) and (248,100) in a 256x128 image, bulging towards
-- decreasing v.
RC.ARC_TEXTURES = { RC.ART_DIR .. "arc1", RC.ART_DIR .. "arc2", RC.ART_DIR .. "arc3" }

-- AN ICON'S FRAME. The round icon sits in ARTWORK and, over it in OVERLAY, this
-- ring of the client's: transparent centre, opaque band, transparent outside.
-- That is what covers the icon's edge, the engine's mask not being adjustable
-- (and a SetTexCoord applied afterwards would destroy it). A brown-gold ring,
-- RGB(113,99,71), inner radius at 0.636 of the half-side: at 44px it bites 3px
-- into an icon of 34.
RC.FRAME_SHEET  = "Interface\\Journeys\\JourneysFrame2x"
RC.FRAME_COORDS = { 0.762207, 0.814941, 0.124512, 0.177246 }
RC.FRAME_SIZE   = 44
RC.ARC_TEX_W, RC.ARC_TEX_H = 256, 128
RC.ARC_CHORD_U0, RC.ARC_CHORD_V, RC.ARC_CHORD_TEXELS = 8, 100, 240

-- Five qualities -- common, uncommon, rare, epic, legendary -- lined up with the
-- client's own item colours: white, green, blue, purple, orange.
RC.QUALITY_COLORS = {
    { 1.00, 1.00, 1.00 }, { 0.12, 1.00, 0.00 }, { 0.00, 0.44, 0.87 },
    { 0.64, 0.21, 0.93 }, { 1.00, 0.50, 0.00 },
}

RC.SLOT_COLOR    = { 0.31, 0.69, 0.89 }
-- A SPELL CELL: the spell frame from the custom spellbook (NewSpellBook, sheet
-- Spellbook-Parts, regions read off NewSpellBookFrame.xml) -- a parchment plate,
-- the spell's SQUARE icon, and a frame of vines: gold when learned or while
-- editing, brown when not. Blizzard's reference: a 37 button, a gold frame 70x65
-- offset by +1.5, a brown frame 70x59 offset by -3, a plate of 43 -- transposed
-- here for an icon of 30 (a factor of 30/37).
RC.SPELL_COLOR = { 1.00, 0.30, 0.85 }         -- colour d'accent (infobulles)
RC.SB_SHEET       = "Interface\\FrameXML\\NewSpellBook\\NewSpellbook\\Spellbook-Parts"
RC.SB_BACKGROUND_COORDS = { 0.79296875, 0.9609375, 0.00390625, 0.171875 }
RC.SB_BACKGROUND_SIZE   = 35
RC.SB_GOLD_COORDS   = { 0.00390625, 0.27734375, 0.44140625, 0.6953125 }
RC.SB_GOLD_W, RC.SB_GOLD_H, RC.SB_GOLD_DX, RC.SB_GOLD_DY = 57, 53, 1.2, 0
RC.SB_BROWN_COORDS = { 0.00390625, 0.27734375, 0.703125, 0.93359375 }
RC.SB_BROWN_W, RC.SB_BROWN_H, RC.SB_BROWN_DX, RC.SB_BROWN_DY = 57, 48, 1.2, -2.4
RC.ICON_SIZE_SPELL = 30    -- a square icon, as in the spellbook
-- An EMPTY NODE, with no stone laid in it: a grey ring, and the centre stopped
-- by an opaque dark disc (a portrait mask over a plain texture) -- the links
-- must not show through.
RC.EMPTY_NODE_COLOR = { 0.55, 0.55, 0.55 }
-- A round texture with REAL transparency: the stopper draws with no mask, which
-- removes the last SetPortraitToTexture (client crash 0061949A). NOT
-- `gradientCircle`: its circle is painted on an opaque black square, which only
-- disappears in SetBlendMode("ADD") and not in a normal fade.
RC.PLUG_TEXTURE     = "Interface\\Minimap\\UI-Minimap-Background"
RC.PLUG_COLOR       = { 0.07, 0.07, 0.08 }
-- The class's start: a second golden ring, discreet, around the marked cell.
-- The same additive texture as the quality ring.
RC.START_COLOR     = { 1.00, 0.82, 0 }
RC.START_RING_SIZE = 52
RC.EDGE_COLOR    = { 0.45, 0.45, 0.45, 1 }
RC.EDGE_ACTIVE   = { 0.20, 0.88, 0.96, 1 }   -- a link with both ends bought
RC.EDGE_OFF      = { 0.14, 0.14, 0.14, 1 }   -- a dimmed link, in the preview only
RC.SELECT_COLOR  = { 1.00, 1.00, 1.00 }
RC.PENDING_COLOR = { 1.00, 0.35, 0.35 }
-- THE RED OF A FAULT, franker than the salmon of a link being drawn: the two
-- stand side by side on screen and must tell apart at a glance.
RC.FAULT_COLOR   = { 1.00, 0.10, 0.10 }

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local UI
-- A fallback only: the geometry that counts is the one the server sends.
local session = { geometry = { radii = { 1.1, 2.1, 3.1 }, branches = 8 },
                  stats = {}, qualities = {}, slotIcon = "", layouts = {}, minSeparation = 0.7 }

-- doc.starts: class -> the id of the cell marked as its start. Key 0 means
-- "every class" (a class grid); the shared grid carries one per class
-- (1-9 and 11).
local doc = { clusters = {}, nodes = {}, edges = {}, nextCluster = 1, nextNode = 1, starts = {} }

-- The WotLK classes, in the client's order. Zero is the older single mark, kept
-- for the per-class sheets.
local CLASSES = {
    { 0, "all classes" }, { 1, "Warrior" }, { 2, "Paladin" }, { 3, "Hunter" },
    { 4, "Rogue" }, { 5, "Priest" }, { 6, "Death knight" }, { 7, "Shaman" },
    { 8, "Mage" }, { 9, "Warlock" }, { 11, "Druid" },
}
local startClass = 1          -- the index into CLASSES of the class being shown

local function ClassName(id)
    for _, c in ipairs(CLASSES) do
        if c[1] == id then return c[2] end
    end
    return "class " .. tostring(id)
end

-- The classes a cell is the start of (a list, usually empty).
local function StartClasses(id)
    local t = {}
    for class, d in pairs(doc.starts) do
        if d == id then t[#t + 1] = class end
    end
    table.sort(t)
    return t
end

local function RemoveStart(id)
    for class, d in pairs(doc.starts) do
        if d == id then doc.starts[class] = nil end
    end
end

local tool        = "select"        -- select | cluster | link | preview

-- Cells marked as "bought" in the preview. THIS IS WORKING STATE: it does not
-- describe the layout and is therefore never written into the XML.
local bought      = {}

local selNode     = nil
local selCluster  = nil
local linkPending = nil

-- The cells THE LAST REPORT named as offenders. Working state too, never
-- written: it holds until the next report. Editing meanwhile does not clear it
-- -- like any check, it says what it saw when it looked, and "Verify" brings it
-- up to date.
local offenders     = {}
local zoom        = 1
local bounds      = { minx = 0, miny = 0 }

-- ---------------------------------------------------------------------------
-- The model
-- ---------------------------------------------------------------------------

-- INDEXES, NOT SEARCHES. These two lookups used to sweep the whole list on
-- every call; Rebuild calls NodeById twice per link and ClusterById six times
-- per cell -- on the shared grid, SIX MILLION iterations per rebuild, before any
-- visibility test. That is what made it crawl, and drawing only what the window
-- shows could do nothing about it.
-- The indexes are rebuilt at the head of Rebuild, in O(N); between two rebuilds,
-- an identifier missing from an index falls back on the search.
local nodeIndex, clusterIndex, placedIndex = {}, {}, {}

-- A place's key: cluster, ring (0-3), branch (1-8).
local function PlaceKey(clusterId, ring, branch)
    return clusterId * 100 + ring * 10 + branch
end

local function Reindex()
    nodeIndex, clusterIndex, placedIndex = {}, {}, {}
    for _, n in ipairs(doc.nodes) do
        nodeIndex[n.id] = n
        placedIndex[PlaceKey(n.cluster, n.ring, n.branch)] = n
    end
    for _, c in ipairs(doc.clusters) do clusterIndex[c.id] = c end
end

local function ClusterById(id)
    local c = clusterIndex[id]
    if c then return c end
    for _, k in ipairs(doc.clusters) do
        if k.id == id then return k end
    end
end

local function NodeById(id)
    local n = nodeIndex[id]
    if n then return n end
    for _, k in ipairs(doc.nodes) do
        if k.id == id then return k end
    end
end

-- The position of a place in a cluster, taken or not. NOTHING IS STORED: it all
-- follows from the cluster, the ring and the branch.
local function PosOf(clusterId, ring, branch)
    local c = ClusterById(clusterId)
    if not c then return 0, 0 end
    -- Ring 0 is the cluster's centre place.
    local r = session.geometry.radii[ring]
    if not r then return c.x, c.y end
    local a = (c.rot or 0) + (branch - 1) * 2 * pi / session.geometry.branches
    return c.x + r * cos(a), c.y + r * sin(a)
end

local function NodePos(n)
    return PosOf(n.cluster, n.ring, n.branch)
end

local function NodeAt(clusterId, ring, branch)
    local n = placedIndex[PlaceKey(clusterId, ring, branch)]
    if n then return n end
    for _, k in ipairs(doc.nodes) do
        if k.cluster == clusterId and k.ring == ring and k.branch == branch then
            return k
        end
    end
end

local function EdgeKey(a, b)
    if a < b then return a .. ":" .. b end
    return b .. ":" .. a
end

local function FindEdge(a, b)
    local k = EdgeKey(a, b)
    for i, e in ipairs(doc.edges) do
        if EdgeKey(e[1], e[2]) == k then return i end
    end
end

-- A SOCKET IS EMPTY BY DEFINITION: it waits for a rune, it carries no stone.
-- Turning a cell into a socket must therefore erase its stone, not keep it
-- sleeping.
local function MakeSlot(n)
    n.kind    = RC.KIND_SLOT
    n.stat    = nil
    n.quality = nil
    n.spell    = nil
    n.spells   = nil
end

local function MakeNode(n)
    n.kind    = RC.KIND_NODE
    n.stat    = random(#session.stats)
    n.quality = random(#session.qualities)
    n.spell    = nil
    n.spells   = nil
end

-- A spell cell for a spell of the module's own: the spell is named by its
-- identifier, typed into the panel (0 meaning "to be decided").
local function MakeSpell(n)
    n.kind    = RC.KIND_SPELL
    n.stat    = nil
    n.quality = nil
    n.spell    = n.spell or 0
    n.spells   = n.spells or {}
end

-- SPELLS BY CLASS. On the shared grid a spell cell belongs to everyone: each
-- class learns ITS OWN there. `n.spells` carries the class -> identifier table;
-- `n.spell` remains the "every class" fallback.
local function SpellFor(n, class)
    local s = n.spells and n.spells[class]
    if s and s > 0 then return s end
    if n.spell and n.spell > 0 then return n.spell end
    return nil
end

-- The spell that stands for the cell on screen: the fallback if there is one,
-- otherwise the one of the first class served.
local function SpellShown(n)
    if n.spell and n.spell > 0 then return n.spell end
    for _, c in ipairs(CLASSES) do
        if c[1] ~= 0 and n.spells and n.spells[c[1]] then return n.spells[c[1]] end
    end
    return 0
end

-- How many of the ten classes find a spell here.
local function ClassesServed(n)
    local nb, total = 0, 0
    for _, c in ipairs(CLASSES) do
        if c[1] ~= 0 then
            total = total + 1
            if SpellFor(n, c[1]) then nb = nb + 1 end
        end
    end
    return nb, total
end

local function RandomContent(n)
    if random(100) <= 15 then MakeSlot(n) else MakeNode(n) end
end

local function AddCluster(x, y)
    local c = { id = doc.nextCluster, x = x, y = y, rot = 0 }
    doc.nextCluster = doc.nextCluster + 1
    doc.clusters[#doc.clusters + 1] = c

    local B = session.geometry.branches
    local ids = {}
    for ring = 1, #session.geometry.radii do
        ids[ring] = {}
        for branch = 1, B do
            local n = { id = doc.nextNode, cluster = c.id, ring = ring, branch = branch }
            doc.nextNode = doc.nextNode + 1
            RandomContent(n)
            doc.nodes[#doc.nodes + 1] = n
            ids[ring][branch] = n.id
        end
    end

    -- The links inside a cluster, by default: each ring closed on itself, and the
    -- eight branches joined from one ring to the next. They are ordinary links and
    -- are removed like any other.
    for ring = 1, #ids do
        for branch = 1, B do
            local nb = branch % B + 1
            doc.edges[#doc.edges + 1] = { ids[ring][branch], ids[ring][nb] }
        end
    end
    for ring = 1, #ids - 1 do
        for branch = 1, B do
            doc.edges[#doc.edges + 1] = { ids[ring][branch], ids[ring + 1][branch] }
        end
    end

    Reindex()
    return c
end

-- REMOVING A CELL LEAVES A HOLE in the cluster: the place is still there, only
-- empty. That is what allows it to be restored later without rebuilding the
-- cluster.
local function RemoveNode(id)
    local keep = {}
    for _, n in ipairs(doc.nodes) do
        if n.id ~= id then keep[#keep + 1] = n end
    end
    doc.nodes = keep
    Reindex()

    local keepEdges = {}
    for _, e in ipairs(doc.edges) do
        if e[1] ~= id and e[2] ~= id then keepEdges[#keepEdges + 1] = e end
    end
    doc.edges = keepEdges

    if selNode == id then selNode = nil end
    if linkPending == id then linkPending = nil end
    RemoveStart(id)
    bought[id] = nil
end

-- Restoring an empty place. The new cell is joined to its immediate neighbours
-- in the cluster -- the two on its ring, and those on the adjacent rings along
-- the same branch -- so they need not be drawn again by hand.
local function AddNodeAt(clusterId, ring, branch)
    if NodeAt(clusterId, ring, branch) then return end

    local n = { id = doc.nextNode, cluster = clusterId, ring = ring, branch = branch }
    doc.nextNode = doc.nextNode + 1
    RandomContent(n)
    doc.nodes[#doc.nodes + 1] = n
    Reindex()

    -- Built without gaps: a missing neighbour (an empty place) must not cut short
    -- the walk over the ones after it.
    local B = session.geometry.branches
    local neighbours = {}
    local function neighbour(r, b)
        local nb = NodeAt(clusterId, r, b)
        if nb then neighbours[#neighbours + 1] = nb end
    end
    if ring == 0 then
        -- The centre place: joined by default to the whole first ring.
        for b = 1, B do neighbour(1, b) end
    else
        neighbour(ring, branch % B + 1)
        neighbour(ring, (branch - 2) % B + 1)
        neighbour(ring - 1, branch)
        neighbour(ring + 1, branch)
        -- The inner ring also reaches the centre place (branch 1, the only one).
        if ring == 1 then neighbour(0, 1) end
    end
    for _, nb in ipairs(neighbours) do
        if not FindEdge(n.id, nb.id) then
            doc.edges[#doc.edges + 1] = { n.id, nb.id }
        end
    end

    return n
end

local function RemoveCluster(id)
    local keepNodes, dropped = {}, {}
    for _, n in ipairs(doc.nodes) do
        if n.cluster == id then dropped[n.id] = true else keepNodes[#keepNodes + 1] = n end
    end
    doc.nodes = keepNodes
    Reindex()

    local keepEdges = {}
    for _, e in ipairs(doc.edges) do
        if not dropped[e[1]] and not dropped[e[2]] then keepEdges[#keepEdges + 1] = e end
    end
    doc.edges = keepEdges

    local keepClusters = {}
    for _, c in ipairs(doc.clusters) do
        if c.id ~= id then keepClusters[#keepClusters + 1] = c end
    end
    doc.clusters = keepClusters

    if selCluster == id then selCluster = nil end
    if selNode and dropped[selNode] then selNode = nil end
    for class, d in pairs(doc.starts) do
        if dropped[d] then doc.starts[class] = nil end
    end
end

-- ---------------------------------------------------------------------------
-- Drawing a segment at any angle
-- ---------------------------------------------------------------------------
-- THE 3.3.5 CLIENT HAS NO LINE PRIMITIVE: CreateLine only arrives with Legion.
-- We use Blizzard's own flight-path method, taken up since by LibGraph: the four
-- corners of an axis-aligned rectangle are given rotated texture coordinates, so
-- that the stroke drawn INSIDE the texture comes out slanted.

local function AcquireLine(canvas, pool, col, layer, tex)
    local t = table.remove(pool.free)
    if not t then t = canvas:CreateTexture(nil, "ARTWORK") end
    t:SetTexture(tex or RC.LINE_TEXTURE)
    -- The layer is placed afresh on every take: a texture returned to the pool can
    -- serve any other link.
    t:SetDrawLayer(layer or "ARTWORK")
    col = col or RC.EDGE_COLOR
    t:SetVertexColor(col[1], col[2], col[3], col[4])
    t:Show()
    pool.used[#pool.used + 1] = t
    return t
end

local function DrawSegment(canvas, pool, sx, sy, ex, ey, w, col, layer)
    local T = AcquireLine(canvas, pool, col, layer)
    T:ClearAllPoints()

    local dx, dy = ex - sx, ey - sy
    local cx, cy = (sx + ex) / 2, (sy + ey) / 2

    if dx == 0 and dy == 0 then
        T:Hide()
        return T
    end

    if dy == 0 then
        T:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
        T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", min(sx, ex), cy - w / 2)
        T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", max(sx, ex), cy + w / 2)
        return T
    end

    if dx == 0 then
        T:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
        T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", cx - w / 2, min(sy, ey))
        T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", cx + w / 2, max(sy, ey))
        return T
    end

    if dx < 0 then dx, dy = -dx, -dy end

    local l = sqrt(dx * dx + dy * dy)
    local s, c = -dy / l, dx / l
    local sc = s * c

    local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy
    if dy >= 0 then
        Bwid = ((l * c) - (w * s)) * RC.LINEFACTOR_2
        Bhgt = ((w * c) - (l * s)) * RC.LINEFACTOR_2
        BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc
        BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx
        TRy = BRx
    else
        Bwid = ((l * c) + (w * s)) * RC.LINEFACTOR_2
        Bhgt = ((w * c) + (l * s)) * RC.LINEFACTOR_2
        BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc
        BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy
        TRx = TLy
    end

    local function cl(v) return v > 10000 and 10000 or (v < -10000 and -10000 or v) end

    T:SetTexCoord(cl(TLx), cl(TLy), cl(BLx), cl(BLy), cl(TRx), cl(TRy), cl(BRx), cl(BRy))
    T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", cx - Bwid, cy - Bhgt)
    T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", cx + Bwid, cy + Bhgt)
    return T
end

-- An arc between two neighbouring cells of one ring: A SINGLE QUAD, the curve
-- being baked into that ring's texture. The quad laid down is the bounding
-- rectangle of the rotated image; the texture coordinates apply the inverse
-- rotation, and sampling that falls outside the image lands on its transparent
-- edges (the client's CLAMP mode).
local function DrawClusterArc(canvas, pool, ax, ay, bx, by, ccx, ccy, ring, col)
    local tex = RC.ARC_TEXTURES[ring]
    if not tex then return end

    local dx, dy = bx - ax, by - ay
    local L = sqrt(dx * dx + dy * dy)
    if L == 0 then return end
    local ux, uy = dx / L, dy / L
    local s = L / RC.ARC_CHORD_TEXELS          -- screen pixels per texel

    -- The outward normal: from the cluster's centre towards the middle of the chord.
    local nx, ny = (ax + bx) / 2 - ccx, (ay + by) / 2 - ccy
    local nl = sqrt(nx * nx + ny * ny)
    if nl == 0 then nx, ny = -uy, ux else nx, ny = nx / nl, ny / nl end

    -- A texel (tu,tv) lands at A + u.(tu-U0).s + n.(V-tv).s.
    local function toScreen(tu, tv)
        local du = (tu - RC.ARC_CHORD_U0) * s
        local dv = (RC.ARC_CHORD_V - tv) * s
        return ax + ux * du + nx * dv, ay + uy * du + ny * dv
    end
    local x1, y1 = toScreen(0, 0)
    local x2, y2 = toScreen(RC.ARC_TEX_W, 0)
    local x3, y3 = toScreen(0, RC.ARC_TEX_H)
    local x4, y4 = toScreen(RC.ARC_TEX_W, RC.ARC_TEX_H)
    local minx, maxx = min(x1, x2, x3, x4), max(x1, x2, x3, x4)
    local miny, maxy = min(y1, y2, y3, y4), max(y1, y2, y3, y4)

    -- The inverse transform, for the corners of the bounding rectangle.
    local function toTex(qx, qy)
        local rx, ry = qx - ax, qy - ay
        return (RC.ARC_CHORD_U0 + (rx * ux + ry * uy) / s) / RC.ARC_TEX_W,
               (RC.ARC_CHORD_V - (rx * nx + ry * ny) / s) / RC.ARC_TEX_H
    end

    local T = AcquireLine(canvas, pool, col, nil, tex)
    T:ClearAllPoints()
    local ulu, ulv = toTex(minx, maxy)
    local llu, llv = toTex(minx, miny)
    local uru, urv = toTex(maxx, maxy)
    local lru, lrv = toTex(maxx, miny)
    T:SetTexCoord(ulu, ulv, llu, llv, uru, urv, lru, lrv)
    T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", minx, miny)
    T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", maxx, maxy)
    return T
end

-- ---------------------------------------------------------------------------
-- Rendu
-- ---------------------------------------------------------------------------

local function ToPixels(gx, gy)
    return (gx - bounds.minx) * RC.SPACING + RC.MARGIN,
           (gy - bounds.miny) * RC.SPACING + RC.MARGIN
end

local function ToGrid(pxv, pyv)
    return (pxv - RC.MARGIN) / RC.SPACING + bounds.minx,
           (pyv - RC.MARGIN) / RC.SPACING + bounds.miny
end

local function NodeBorderColor(n)
    if n.kind == RC.KIND_SLOT then
        return RC.SLOT_COLOR[1], RC.SLOT_COLOR[2], RC.SLOT_COLOR[3]
    end
    if n.kind == RC.KIND_SPELL then
        -- White: the spellbook frame keeps its natural gold; the states (selected,
        -- link pending, preview) tint over it.
        return 1, 1, 1
    end
    if not n.stat then
        return RC.EMPTY_NODE_COLOR[1], RC.EMPTY_NODE_COLOR[2], RC.EMPTY_NODE_COLOR[3]
    end
    local q = RC.QUALITY_COLORS[n.quality or 1] or RC.QUALITY_COLORS[1]
    return q[1], q[2], q[3]
end

-- Dresses the frame of a spell cell: gold when learned or while editing, brown
-- when not -- the geometry of NewSpellBookFrame.xml, transposed.
local function DressSpellFrame(btn, gold, r, g, b)
    local frame = btn.sbFrame
    if gold then
        frame:SetTexCoord(RC.SB_GOLD_COORDS[1], RC.SB_GOLD_COORDS[2],
            RC.SB_GOLD_COORDS[3], RC.SB_GOLD_COORDS[4])
        frame:SetWidth(RC.SB_GOLD_W)
        frame:SetHeight(RC.SB_GOLD_H)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", RC.SB_GOLD_DX, RC.SB_GOLD_DY)
    else
        frame:SetTexCoord(RC.SB_BROWN_COORDS[1], RC.SB_BROWN_COORDS[2],
            RC.SB_BROWN_COORDS[3], RC.SB_BROWN_COORDS[4])
        frame:SetWidth(RC.SB_BROWN_W)
        frame:SetHeight(RC.SB_BROWN_H)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", RC.SB_BROWN_DX, RC.SB_BROWN_DY)
    end
    frame:SetVertexColor(r, g, b)
    btn.sbBackground:SetVertexColor(r, g, b)
    btn.sbBackground:Show()
    frame:Show()
end

local function ShowNodeTooltip(btn, n)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    if n.kind == RC.KIND_SLOT then
        GameTooltip:SetText("Slot", 0.31, 0.69, 0.89)
        GameTooltip:AddLine("Accepts runes only.", 0.8, 0.8, 0.8, true)
    elseif n.kind == RC.KIND_SPELL then
        GameTooltip:SetText("Spell", RC.SPELL_COLOR[1], RC.SPELL_COLOR[2], RC.SPELL_COLOR[3])
        -- One spell per class: the list says who learns what here.
        for _, c in ipairs(CLASSES) do
            if c[1] ~= 0 then
                local id = SpellFor(n, c[1])
                if id then
                    local name = GetSpellInfo(id)
                    GameTooltip:AddLine(fmt("%s: %s (no. %d)", c[2], name or "?", id), 1, 1, 1, true)
                else
                    -- With no spell, the cell does not exist for that class.
                    GameTooltip:AddLine(fmt("%s: invisible (no spell)", c[2]), 0.55, 0.55, 0.55, true)
                end
            end
        end
        if n.spell and n.spell > 0 then
            GameTooltip:AddLine(fmt("All-class fallback: no. %d", n.spell), 0.6, 0.6, 0.6, true)
        end
        GameTooltip:AddLine("Each class learns its own spell here; with no spell, it sees neither the cell nor its links.",
            0.8, 0.8, 0.8, true)
    elseif not n.stat then
        GameTooltip:SetText("Empty node", RC.EMPTY_NODE_COLOR[1], RC.EMPTY_NODE_COLOR[2], RC.EMPTY_NODE_COLOR[3])
        GameTooltip:AddLine("No stone laid in: it will take one socketed in game.",
            0.8, 0.8, 0.8, true)
    else
        local s = session.stats[n.stat]
        local q = RC.QUALITY_COLORS[n.quality or 1] or RC.QUALITY_COLORS[1]
        local qual = session.qualities[n.quality or 1]
        GameTooltip:SetText("Node", 1, 1, 1)
        GameTooltip:AddLine(fmt("%s stone", qual and qual.label or "?"),
            q[1], q[2], q[3], true)
        GameTooltip:AddLine(fmt("+%d %s", qual and qual.bonus or 0, s and s.label or "?"),
            0.1, 1, 0.1, true)
    end
    local cd = StartClasses(n.id)
    if #cd > 0 then
        local names = {}
        for _, c in ipairs(cd) do names[#names + 1] = ClassName(c) end
        GameTooltip:AddLine("Start: " .. table.concat(names, ", "), 1, 0.82, 0, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(fmt("no. %d · cluster %d · ring %d · branch %d",
        n.id, n.cluster, n.ring, n.branch), 0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local Rebuild, UpdateInspector, SetStatus

local function CountLinks(id)
    local c = 0
    for _, e in ipairs(doc.edges) do
        if e[1] == id or e[2] == id then c = c + 1 end
    end
    return c
end

local function CutAllLinks(id)
    local keep, cut = {}, 0
    for _, e in ipairs(doc.edges) do
        if e[1] == id or e[2] == id then cut = cut + 1 else keep[#keep + 1] = e end
    end
    doc.edges = keep
    return cut
end

local function OnNodeClick(n, button)
    if tool == "preview" then
        if button == "RightButton" then
            bought = {}
            SetStatus("Preview cleared.")
        else
            bought[n.id] = (not bought[n.id]) or nil
        end
        Rebuild()
        return
    end

    if tool == "link" then
        -- Right-click cuts every link of the cell at once. Without it, undoing a
        -- cluster's internal links would take forty pairs of clicks.
        if button == "RightButton" then
            local cut = CutAllLinks(n.id)
            linkPending = nil
            SetStatus(cut > 0
                and fmt("Cell %d: %d link(s) cut.", n.id, cut)
                or fmt("Cell %d had no link.", n.id))
            Rebuild()
            return
        end

        if not linkPending then
            linkPending = n.id
            SetStatus(fmt("Cell %d held (%d link(s)). Click the second to link or unlink.",
                n.id, CountLinks(n.id)))
        elseif linkPending == n.id then
            linkPending = nil
            SetStatus("Selection cancelled.")
        else
            local i = FindEdge(linkPending, n.id)
            if i then
                table.remove(doc.edges, i)
                SetStatus(fmt("Link %d - %d removed.", linkPending, n.id))
            else
                doc.edges[#doc.edges + 1] = { linkPending, n.id }
                SetStatus(fmt("Link %d - %d created.", linkPending, n.id))
            end
            linkPending = nil
        end
    elseif button == "RightButton" then
        local id = n.id
        RemoveNode(id)
        SetStatus(fmt("Cell %d removed. Its place remains: click it to put the cell back.", id))
    else
        selNode    = n.id
        selCluster = n.cluster
    end
    Rebuild()
end

-- THE VISIBLE RECTANGLE, in canvas pixels. With the shared grid -- 2 442 cells,
-- 2 485 links -- dressing every cell and drawing every link on each rebuild
-- brought the client to its knees. So only what falls inside the window is
-- drawn, with a margin: the rest is hidden, and a rebuild happens when the
-- window has moved far enough.
--
-- A ScrollFrame's scrolling counts in ITS OWN units, while the child is scaled
-- by the zoom: one canvas pixel is `zoom` window pixels. The canvas's y axis
-- goes UP -- cells anchor bottom-left -- and the scroll's goes down, hence the
-- flip over the canvas height.
local CULL_MARGIN = 160

local function RectVisible()
    -- With no filter everything is visible and everything is dressed on rebuild.
    -- That is the comparison switch at the foot of the window.
    if UI.noFilter then
        return -math.huge, -math.huge, math.huge, math.huge
    end
    local vp, canvas = UI.viewport, UI.canvas
    local z = zoom > 0 and zoom or 1
    local w, h = vp:GetWidth() / z, vp:GetHeight() / z
    -- A window with no size yet (the first frame after creation): show everything
    -- rather than nothing.
    if w < 1 or h < 1 then
        return -math.huge, -math.huge, math.huge, math.huge
    end
    -- THE SCROLL OFFSET IS ALREADY IN CANVAS PIXELS -- established by trying it in
    -- the player interface: without dividing the mouse's movement by the zoom, the
    -- content runs away faster than the hand. Only the window's size is converted.
    local sx, sy = vp:GetHorizontalScroll(), vp:GetVerticalScroll()
    local ch = canvas:GetHeight()
    return sx - CULL_MARGIN, ch - sy - h - CULL_MARGIN,
           sx + w + CULL_MARGIN, ch - sy + CULL_MARGIN
end

local function Inside(rect, x, y)
    return x >= rect[1] and x <= rect[3] and y >= rect[2] and y <= rect[4]
end

-- DRESSING A CELL IS A SEPARATE JOB from rebuilding. Rebuilding places and
-- dresses, and happens rarely; filtering shows or hides on every movement, and
-- dresses only a cell entering the window for the first time since the last
-- rebuild (`btn.styled`).
local function StyleNode(btn, n, x, y)
    local canvas = UI.canvas
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", canvas, "BOTTOMLEFT", x, y)

    -- The state's colour: the stone's quality for a node's ring; white for a
    -- selection, red for a link being drawn, grey and dimmed in the preview.
    local r, g, b = NodeBorderColor(n)
    if tool == "preview" then
        if not bought[n.id] then r, g, b = 0.12, 0.12, 0.12 end
    elseif linkPending == n.id then
        r, g, b = RC.PENDING_COLOR[1], RC.PENDING_COLOR[2], RC.PENDING_COLOR[3]
    elseif selNode == n.id then
        r, g, b = RC.SELECT_COLOR[1], RC.SELECT_COLOR[2], RC.SELECT_COLOR[3]
    elseif offenders[n.id] then
        r, g, b = RC.FAULT_COLOR[1], RC.FAULT_COLOR[2], RC.FAULT_COLOR[3]
    end

    -- In the preview, what is not bought fades out so that the path walked reads at
    -- a glance. In the editing tools everything stays fully visible, without which
    -- one would be editing blind.
    local dim  = (tool == "preview" and not bought[n.id])
    local tint = dim and 0.15 or 1

    if n.kind == RC.KIND_SLOT then
        -- A socket is an empty setting: the hollow and the frame, no icon.
        btn.disc:Hide()
        btn.ring:Hide()
        btn.icon:Hide()
        btn.iconRim:Hide()
        btn.sbBackground:Hide()
        btn.sbFrame:Hide()
        btn.hole:Show()
        btn.socket:Show()

        -- The setting stays silver at rest -- its shape alone says "rune". It only
        -- takes a tint to signal a state.
        local sr, sg, sb = 1, 1, 1
        if tool == "preview" then
            if not bought[n.id] then sr, sg, sb = 0.12, 0.12, 0.12 end
        elseif linkPending == n.id then
            sr, sg, sb = RC.PENDING_COLOR[1], RC.PENDING_COLOR[2], RC.PENDING_COLOR[3]
        elseif selNode == n.id then
            sr, sg, sb = 1, 0.82, 0
        elseif offenders[n.id] then
            sr, sg, sb = RC.FAULT_COLOR[1], RC.FAULT_COLOR[2], RC.FAULT_COLOR[3]
        end
        btn.socket:SetVertexColor(sr, sg, sb)
        btn.hole:SetAlpha(dim and 0.20 or 1)
    else
        btn.hole:Hide()
        btn.socket:Hide()

        -- The icon: round (a portrait mask) for stones, SQUARE for spells -- the
        -- spellbook frame surrounds a square. An empty node gets a dark opaque disc cut
        -- round: the links must not show through. The mask is costly, so the icon is
        -- only redone when the path OR the mode changes.
        local path, plug, square
        if n.kind == RC.KIND_SPELL then
            local _, _, iconFile = GetSpellInfo(SpellShown(n))
            path, square = iconFile or "Interface\\Icons\\INV_Misc_QuestionMark", true
        elseif n.stat then
            -- THE ROUND ICON IS BAKED INTO A FILE: no more SetPortraitToTexture on the fly
            -- -- that was a mask per button, and the stutter of the first pass. Square as
            -- far as the engine is concerned: the alpha makes it round.
            -- Here n.stat is an INDEX into session.stats, while the player interface
            -- receives the key: the file is named by the KEY.
            local sDef = session.stats[n.stat]
            path, square = RC.ART_DIR .. "stat_" .. ((sDef and sDef.key) or tostring(n.stat)), true
        else
            -- NO MORE PORTRAIT MASK, for the same reason and with the same fix as in
            -- player/Player_Client.lua: SetPortraitToTexture crashes the 3.3.5 client
            -- (ACCESS_VIOLATION at 0061949A). RC.PLUG_TEXTURE is a round texture with real
            -- transparency.
            path, plug, square = RC.PLUG_TEXTURE, true, true
        end

        btn.icon:Show()
        local mode = square and "square" or "rond"
        if btn.iconPath ~= path or btn.iconMode ~= mode then
            btn.iconPath, btn.iconMode = path, mode
            if square or not SetPortraitToTexture then
                -- A diagnosis: SetTexture returns 1 if the client found the file and nil
                -- otherwise, and the node's tooltip shows which.
                btn.iconOk = btn.icon:SetTexture(path)
                btn.icon:SetTexCoord(0, 1, 0, 1)
            else
                -- A DEAD BRANCH, AND IT MUST STAY DEAD: all three cases above set `square`.
                -- Never add one without it -- SetPortraitToTexture crashes the 3.3.5 client
                -- (ACCESS_VIOLATION at 0061949A).
                btn.iconOk = "portrait"
                -- NEVER call SetTexCoord afterwards: the engine then loses its circular mask
                -- and the icon goes square again.
                SetPortraitToTexture(btn.icon, path)
            end
        end
        btn.icon:SetAlpha(1)
        btn.iconPlug = plug

        if n.kind == RC.KIND_SPELL then
            -- The spellbook frame replaces the circle entirely. In the preview, the brown
            -- "not learned" frame tells the state.
            btn.disc:Hide()
            btn.ring:Hide()
            btn.iconRim:Hide()
            btn.icon:SetWidth(RC.ICON_SIZE_SPELL)
            btn.icon:SetHeight(RC.ICON_SIZE_SPELL)
            DressSpellFrame(btn, tool ~= "preview" or bought[n.id], r, g, b)
        else
            btn.disc:Show()
            btn.ring:Show()
            btn.iconRim:Show()
            btn.iconRim:SetVertexColor(tint, tint, tint)
            btn.icon:SetWidth(RC.ICON_SIZE_NODE)
            btn.icon:SetHeight(RC.ICON_SIZE_NODE)
            btn.ring:SetVertexColor(r, g, b)
            btn.sbBackground:Hide()
            btn.sbFrame:Hide()
        end
    end

    if btn.iconPlug then
        btn.icon:SetVertexColor(RC.PLUG_COLOR[1], RC.PLUG_COLOR[2], RC.PLUG_COLOR[3])
    else
        btn.icon:SetVertexColor(tint, tint, tint)
    end
    if #StartClasses(n.id) > 0 then btn.startRing:Show() else btn.startRing:Hide() end
    btn:Show()
    btn.styled, btn.visible = true, true
end

-- THE FILTER shows or hides according to the window, from the positions the
-- last rebuild remembered. Cheap enough to run every frame while dragging: a
-- few thousand comparisons and a handful of Show/Hide calls -- only those whose
-- state changes.
-- Where the window stood at the last filtering: nothing to do if it has not
-- moved.
local lastFilter = { h = nil, v = nil, z = nil }

-- A SPATIAL INDEX. The filter used to walk EVERY cell and EVERY link on each
-- frame of a drag -- five thousand iterations, visible or not, and a table
-- allocated on the way. At 160% zoom, twenty cells on screen and still
-- micro-freezes. So everything is filed into buckets of CELL pixels at rebuild
-- time, and only the buckets the window touches are walked, plus whatever was
-- shown and must now go.
local CELL = 256
local currentView = { 0, 0, 0, 0 }         -- reused: nothing allocated per frame
local shownN, shownE = {}, {}         -- what is shown: indices / items
local newN, newE = {}, {}       -- the filter's buffers, reused
-- The "others": empty places and cluster markers. Nine textures each, and 886
-- of them shown at all times on the shared grid.
local shownA, newA = {}, {}
local perf = { max = 0, since = 0 }

local function CellKey(x, y)
    return floor(x / CELL) * 65536 + floor(y / CELL)
end

-- Called at the end of a rebuild: the buckets, and the shown set to start from.
local function LayOutInCells()
    local cells = {}
    for i, _ in ipairs(doc.nodes) do
        local btn = UI.nodeButtons[i]
        if btn and btn.px then
            local k = CellKey(btn.px, btn.py)
            local c = cells[k]
            if not c then c = { n = {}, e = {}, a = {} } cells[k] = c end
            c.n[#c.n + 1] = i
        end
    end
    for _, it in ipairs(UI.others) do
        local k = CellKey(it.px, it.py)
        local c = cells[k]
        if not c then c = { n = {}, e = {}, a = {} } cells[k] = c end
        c.a[#c.a + 1] = it
    end
    for _, it in ipairs(UI.edgeItems) do
        -- a link goes into every bucket its box touches
        for cx = floor(it.x0 / CELL), floor(it.x1 / CELL) do
            for cy = floor(it.y0 / CELL), floor(it.y1 / CELL) do
                local k = cx * 65536 + cy
                local c = cells[k]
                if not c then c = { n = {}, e = {}, a = {} } cells[k] = c end
                c.e[#c.e + 1] = it
            end
        end
    end
    UI.cells = cells
    for k in pairs(shownN) do shownN[k] = nil end
    for k in pairs(shownE) do shownE[k] = nil end
    for i, _ in ipairs(doc.nodes) do
        local btn = UI.nodeButtons[i]
        if btn and btn.visible then shownN[i] = true end
    end
    for _, it in ipairs(UI.edgeItems) do
        if it.visible then shownE[it] = true end
    end
    for k in pairs(shownA) do shownA[k] = nil end
    for _, it in ipairs(UI.others) do
        if it.visible then shownA[it] = true end
    end
end

local function Cull(strength)
    if not UI or not UI.cells then return end
    local vp = UI.viewport
    local h, v = vp:GetHorizontalScroll(), vp:GetVerticalScroll()
    if not strength and h == lastFilter.h and v == lastFilter.v and zoom == lastFilter.z then
        return
    end
    lastFilter.h, lastFilter.v, lastFilter.z = h, v, zoom
    local t0 = debugprofilestop()

    local vis = currentView
    vis[1], vis[2], vis[3], vis[4] = RectVisible()
    UI.currentView = vis
    local drawn, traces = 0, 0

    -- The buckets the window touches. Bounded -- the "infinite" window of the
    -- unfiltered mode simply walks them all.
    for k in pairs(newN) do newN[k] = nil end
    for k in pairs(newE) do newE[k] = nil end
    for k in pairs(newA) do newA[k] = nil end
    local cells = UI.cells
    local function visited(c)
        for _, i in ipairs(c.n) do
            local btn = UI.nodeButtons[i]
            if btn and btn.px and Inside(vis, btn.px, btn.py) then
                if not btn.styled then
                    StyleNode(btn, doc.nodes[i], btn.px, btn.py)
                elseif not btn.visible then
                    btn:SetPoint("CENTER", UI.canvas, "BOTTOMLEFT", btn.px, btn.py)
                    btn:Show()
                    btn.visible = true
                end
                newN[i] = true
                drawn = drawn + 1
            end
        end
        for _, it in ipairs(c.e) do
            if not newE[it]
               and not (it.x1 < vis[1] or it.x0 > vis[3] or it.y1 < vis[2] or it.y0 > vis[4]) then
                if not it.visible then
                    it.tex:SetPoint(it.a1[1], it.a1[2], it.a1[3], it.a1[4], it.a1[5])
                    it.tex:SetPoint(it.a2[1], it.a2[2], it.a2[3], it.a2[4], it.a2[5])
                    it.tex:Show()
                    it.visible = true
                end
                newE[it] = true
                traces = traces + 1
            end
        end
        for _, it in ipairs(c.a) do
            if Inside(vis, it.px, it.py) then
                if not it.visible then
                    it.f:Show()
                    it.visible = true
                end
                newA[it] = true
            end
        end
    end
    if vis[1] == -math.huge then
        for _, c in pairs(cells) do visited(c) end
    else
        for cx = floor(vis[1] / CELL), floor(vis[3] / CELL) do
            for cy = floor(vis[2] / CELL), floor(vis[4] / CELL) do
                local c = cells[cx * 65536 + cy]
                if c then visited(c) end
            end
        end
    end

    -- What was shown and is no longer.
    for i in pairs(shownN) do
        if not newN[i] then
            local btn = UI.nodeButtons[i]
            if btn and btn.visible then
                btn:Hide()
                btn:ClearAllPoints()            -- detached: the engine stops recomputing it
                btn.visible = false
            end
        end
    end
    for it in pairs(shownE) do
        if not newE[it] and it.visible then
            it.tex:Hide()
            it.tex:ClearAllPoints()
            it.visible = false
        end
    end
    -- The marker of a cluster being dragged is never hidden: hiding a frame while it
    -- is dragged cancels the drag.
    for it in pairs(shownA) do
        if not newA[it] and it.visible and not it.pinned then
            it.f:Hide()
            it.visible = false
        end
    end
    -- The two sets are swapped: the old one becomes the scratch buffer for the next
    -- pass.
    shownN, newN = newN, shownN
    shownE, newE = newE, shownE
    shownA, newA = newA, shownA

    if UI.drawnLabel and (drawn ~= UI.drawn or traces ~= UI.traces) then
        UI.drawnLabel:SetText(fmt("%d drawn, %d links", drawn, traces))
    end
    UI.drawn, UI.traces = drawn, traces
    -- The measure: the worst filtering of the last half second, shown at the foot.
    local dt = debugprofilestop() - t0
    if dt > perf.max then perf.max = dt end
    local now = GetTime()
    if now - perf.since > 0.5 then
        if UI.perfLabel then
            UI.perfLabel:SetText(fmt("filter %.1f ms", perf.max))
        end
        perf.max, perf.since = 0, now
    end
end

-- DRESSING IN THE BACKGROUND. Dressing a cell is expensive -- textures,
-- coordinates, colours -- and doing it as a cell entered the window produced a
-- stutter every time a drag reached new ground. So after a rebuild EVERYTHING is
-- dressed, a few cells per frame, starting with those nearest the window: the
-- whole grid is ready in two or three seconds, and nothing is dressed while
-- dragging any more.
--
-- THE REAL COST IS THE ROUND MASK: SetPortraitToTexture builds a texture per
-- button the first time, and the client loads each icon of the disc on its first
-- appearance. Sixteen per frame was still too many at once. So dressing runs
-- under a TIME BUDGET per frame (debugprofilestop, in milliseconds), at least
-- one cell and never more than STYLE_PER_FRAME_MAX.
local STYLE_BUDGET_MS = 2.5
local STYLE_PER_FRAME_MAX = 48

local function DressAsBackground()
    local queue = UI and UI.aStyler
    if not queue or #queue == 0 then return end
    local done = 0
    local t0 = debugprofilestop()
    while #queue > 0 and done < STYLE_PER_FRAME_MAX
          and (done == 0 or debugprofilestop() - t0 < STYLE_BUDGET_MS) do
        local i = table.remove(queue)
        local btn, n = UI.nodeButtons[i], doc.nodes[i]
        if btn and n and btn.px and not btn.styled then
            StyleNode(btn, n, btn.px, btn.py)
            -- Dressed but outside the window: hidden again at once.
            local vis = UI.currentView
            if vis and not Inside(vis, btn.px, btn.py) then
                btn:Hide()
                btn:ClearAllPoints()
                btn.visible = false
            end
            done = done + 1
        end
    end
end

function Rebuild()
    if not UI then return end
    Reindex()

    local canvas = UI.canvas
    local pool   = UI.linePool

    for _, t in ipairs(pool.used) do
        t:Hide()
        t:ClearAllPoints()
        pool.free[#pool.free + 1] = t
    end
    pool.used = {}

    -- The buttons and markers are NOT hidden here only to be shown again straight
    -- after: hiding a frame while it is being dragged cancels the drag, and
    -- OnDragStop never fires. Only the surplus is hidden, at the end.

    -- the extent
    -- The extent counts whole clusters and not only the places taken: a cluster
    -- emptied of all its cells must stay visible, or nothing could ever be restored
    -- in it.
    local minx, maxx, miny, maxy
    local function extend(x, y)
        minx = (not minx or x < minx) and x or minx
        maxx = (not maxx or x > maxx) and x or maxx
        miny = (not miny or y < miny) and y or miny
        maxy = (not maxy or y > maxy) and y or maxy
    end

    for _, n in ipairs(doc.nodes) do extend(NodePos(n)) end

    local outer = session.geometry.radii[#session.geometry.radii] or 2.7
    for _, c in ipairs(doc.clusters) do
        extend(c.x - outer, c.y - outer)
        extend(c.x + outer, c.y + outer)
    end

    if not minx then minx, maxx, miny, maxy = 0, 8, 0, 6 end

    bounds.minx, bounds.miny = minx, miny
    canvas:SetWidth((maxx - minx) * RC.SPACING + RC.MARGIN * 2)
    canvas:SetHeight((maxy - miny) * RC.SPACING + RC.MARGIN * 2)

    -- The window, once the canvas has its size: everything after this is bounded by
    -- it.
    local vis = { RectVisible() }
    -- Held on UI, because the status line reads them from ANOTHER function. Writing
    -- them as locals of Rebuild left two nils there -- and a "bad argument #2 to 'i'"
    -- once the code had been shrunk by LuaSrcDiet.
    UI.drawn, UI.traces = 0, 0

    -- links
    local B = session.geometry.branches
    -- EVERY link is placed, one texture each, and keeps its box: it is the filter
    -- that shows or hides them afterwards.
    UI.edgeItems = {}
    for _, e in ipairs(doc.edges) do
        local a, b = NodeById(e[1]), NodeById(e[2])
        if a and b then
            local ax, ay = ToPixels(NodePos(a))
            local bx, by = ToPixels(NodePos(b))

            -- A link is active only if BOTH its ends are bought. In the preview, what is not
            -- active goes plainly dark.
            local col = RC.EDGE_COLOR
            if bought[a.id] and bought[b.id] then
                col = RC.EDGE_ACTIVE
            elseif tool == "preview" then
                col = RC.EDGE_OFF
            end

            -- Two cells of the same ring on neighbouring branches: that is a piece of a
            -- circle, and it is drawn as one.
            local sameRing = a.cluster == b.cluster and a.ring == b.ring
            local adjacent = sameRing and
                (abs(a.branch - b.branch) == 1 or abs(a.branch - b.branch) == B - 1)

            local T
            if adjacent then
                local c = ClusterById(a.cluster)
                local ccx, ccy = ToPixels(c.x, c.y)
                T = DrawClusterArc(canvas, pool, ax, ay, bx, by, ccx, ccy, a.ring, col)
            else
                T = DrawSegment(canvas, pool, ax, ay, bx, by, RC.EDGE_THICK, col)
            end
            if T then
                -- Both anchors are remembered: a hidden link is DETACHED from the canvas
                -- (ClearAllPoints) so the engine stops recomputing it on every move, and
                -- re-anchored when it comes back.
                local p1, r1, rp1, x1_, y1_ = T:GetPoint(1)
                local p2, r2, rp2, x2_, y2_ = T:GetPoint(2)
                UI.edgeItems[#UI.edgeItems + 1] = {
                    tex = T, visible = true,
                    x0 = min(ax, bx), y0 = min(ay, by), x1 = max(ax, bx), y1 = max(ay, by),
                    a1 = { p1, r1, rp1, x1_, y1_ }, a2 = { p2, r2, rp2, x2_, y2_ },
                }
            end
        end
    end

    -- the cells
    local backdrop = UISTYLE_BACKDROPS and UISTYLE_BACKDROPS.Frame or {
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    }

    -- The scripts are bound ONCE, at creation, and read self.node. Binding them on
    -- every rebuild broke dragging and made the second click of the Link tool
    -- unreliable.
    for i, n in ipairs(doc.nodes) do
        local btn = UI.nodeButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, canvas)
            btn:SetWidth(RC.NODE_SIZE)
            btn:SetHeight(RC.NODE_SIZE)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetFrameLevel(canvas:GetFrameLevel() + 5)

            -- A node: a dark round plate under the icon...
            btn.disc = btn:CreateTexture(nil, "BACKGROUND")
            btn.disc:SetTexture(RC.NODE_DISC_TEXTURE)
            btn.disc:SetBlendMode("ADD")
            btn.disc:SetWidth(RC.NODE_DISC_SIZE)
            btn.disc:SetHeight(RC.NODE_DISC_SIZE)
            btn.disc:SetPoint("CENTER")
            btn.disc:SetVertexColor(RC.NODE_DISC_COLOR[1], RC.NODE_DISC_COLOR[2], RC.NODE_DISC_COLOR[3])

            -- ...and over it, the ring carrying the quality's colour.
            btn.ring = btn:CreateTexture(nil, "OVERLAY")
            btn.ring:SetTexture(RC.NODE_RING_TEXTURE)
            btn.ring:SetBlendMode("ADD")
            btn.ring:SetWidth(RC.NODE_RING_SIZE)
            btn.ring:SetHeight(RC.NODE_RING_SIZE)
            btn.ring:SetPoint("CENTER")

            -- A socket: the shadowed hollow, then the setting's frame, as the game does it.
            btn.hole = btn:CreateTexture(nil, "BACKGROUND")
            btn.hole:SetTexture(RC.SOCKET_SHEET)
            btn.hole:SetTexCoord(RC.SOCKET_HOLE_COORDS[1], RC.SOCKET_HOLE_COORDS[2],
                RC.SOCKET_HOLE_COORDS[3], RC.SOCKET_HOLE_COORDS[4])
            btn.hole:SetWidth(72 * RC.SLOT_SCALE)
            btn.hole:SetHeight(74 * RC.SLOT_SCALE)
            btn.hole:SetPoint("CENTER")

            btn.socket = btn:CreateTexture(nil, "BORDER")
            btn.socket:SetTexture(RC.SOCKET_SHEET)
            btn.socket:SetTexCoord(RC.SOCKET_FRAME_COORDS[1], RC.SOCKET_FRAME_COORDS[2],
                RC.SOCKET_FRAME_COORDS[3], RC.SOCKET_FRAME_COORDS[4])
            btn.socket:SetWidth(57 * RC.SLOT_SCALE)
            btn.socket:SetHeight(52 * RC.SLOT_SCALE)
            btn.socket:SetPoint("CENTER")

            btn.icon = btn:CreateTexture(nil, "ARTWORK")
            btn.icon:SetWidth(RC.ICON_SIZE_NODE)
            btn.icon:SetHeight(RC.ICON_SIZE_NODE)
            btn.icon:SetPoint("CENTER")

            -- A frame laid over the round icon's edge (the Paragon method).
            btn.iconRim = btn:CreateTexture(nil, "OVERLAY")
            btn.iconRim:SetTexture(RC.FRAME_SHEET)
            btn.iconRim:SetTexCoord(RC.FRAME_COORDS[1], RC.FRAME_COORDS[2],
                RC.FRAME_COORDS[3], RC.FRAME_COORDS[4])
            btn.iconRim:SetWidth(RC.FRAME_SIZE)
            btn.iconRim:SetHeight(RC.FRAME_SIZE)
            btn.iconRim:SetPoint("CENTER")

            -- The spellbook's spell frame: a parchment plate under the icon, the vined
            -- frame over it (gold or brown, decided at drawing time).
            btn.sbBackground = btn:CreateTexture(nil, "BORDER")
            btn.sbBackground:SetTexture(RC.SB_SHEET)
            btn.sbBackground:SetTexCoord(RC.SB_BACKGROUND_COORDS[1], RC.SB_BACKGROUND_COORDS[2],
                RC.SB_BACKGROUND_COORDS[3], RC.SB_BACKGROUND_COORDS[4])
            btn.sbBackground:SetWidth(RC.SB_BACKGROUND_SIZE)
            btn.sbBackground:SetHeight(RC.SB_BACKGROUND_SIZE)
            btn.sbBackground:SetPoint("CENTER")

            btn.sbFrame = btn:CreateTexture(nil, "OVERLAY")
            btn.sbFrame:SetTexture(RC.SB_SHEET)
            btn.sbFrame:SetPoint("CENTER")

            -- The start marker, which serves a node as well as a socket.
            btn.startRing = btn:CreateTexture(nil, "OVERLAY")
            btn.startRing:SetTexture(RC.NODE_RING_TEXTURE)
            btn.startRing:SetBlendMode("ADD")
            btn.startRing:SetWidth(RC.START_RING_SIZE)
            btn.startRing:SetHeight(RC.START_RING_SIZE)
            btn.startRing:SetPoint("CENTER")
            btn.startRing:SetVertexColor(RC.START_COLOR[1], RC.START_COLOR[2], RC.START_COLOR[3])

            btn:SetScript("OnEnter", function(self)
                if self.node then ShowNodeTooltip(self, self.node) end
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
            btn:SetScript("OnClick", function(self, button)
                if self.node then OnNodeClick(self.node, button) end
            end)

            UI.nodeButtons[i] = btn
        end

        btn.node = n
        local x, y = ToPixels(NodePos(n))
        btn.px, btn.py = x, y
        btn.styled = false
        if Inside(vis, x, y) then
            StyleNode(btn, n, x, y)
        else
            btn:Hide()
            btn:ClearAllPoints()
            btn.visible = false
        end
    end

    -- The dressing queue: the cells not yet dressed, the nearest to the window
    -- LAST (table.remove takes from the end).
    do
        local cx, cy = (vis[1] + vis[3]) / 2, (vis[2] + vis[4]) / 2
        local queue = {}
        for i, _ in ipairs(doc.nodes) do
            local btn = UI.nodeButtons[i]
            if btn and not btn.styled then queue[#queue + 1] = i end
        end
        table.sort(queue, function(a, b)
            local ba, bb = UI.nodeButtons[a], UI.nodeButtons[b]
            local da = (ba.px - cx) * (ba.px - cx) + (ba.py - cy) * (ba.py - cy)
            local db = (bb.px - cx) * (bb.px - cx) + (bb.py - cy) * (bb.py - cy)
            return da > db
        end)
        UI.aStyler = queue
    end

    for i = #doc.nodes + 1, #UI.nodeButtons do
        UI.nodeButtons[i].node = nil
        UI.nodeButtons[i]:Hide()
    end

    -- Empty places: a cluster keeps its twenty-four places even when a cell has
    -- been removed from it. They are shown hollow, and can be clicked to put the
    -- cell back.
    local occupied = {}
    for _, n in ipairs(doc.nodes) do
        occupied[n.cluster .. ":" .. n.ring .. ":" .. n.branch] = true
    end

    UI.others = {}
    local gi = 0
    for _, c in ipairs(doc.clusters) do
        -- Ring 0: the centre place, one only (branch 1).
        for ring = 0, #session.geometry.radii do
            for branch = 1, (ring == 0 and 1 or B) do
                if not occupied[c.id .. ":" .. ring .. ":" .. branch] then
                    gi = gi + 1
                    local g = UI.ghosts[gi]
                    if not g then
                        g = CreateFrame("Button", nil, canvas)
                        g:SetWidth(RC.NODE_SIZE - 12)
                        g:SetHeight(RC.NODE_SIZE - 12)
                        g:SetBackdrop(backdrop)
                        g:SetBackdropColor(0.05, 0.05, 0.05, 0.55)
                        g:SetBackdropBorderColor(0.32, 0.32, 0.32, 0.8)
                        g:RegisterForClicks("LeftButtonUp")
                        g:SetFrameLevel(canvas:GetFrameLevel() + 3)

                        g:SetScript("OnEnter", function(self)
                            local s = self.spot
                            if not s then return end
                            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                            GameTooltip:SetText("Place vide", 0.6, 0.6, 0.6)
                            GameTooltip:AddLine(fmt("cluster %d · ring %d · branch %d",
                                s.cluster, s.ring, s.branch), 0.5, 0.5, 0.5, true)
                            GameTooltip:AddLine("Click: put a cell back here.",
                                1, 0.82, 0, true)
                            GameTooltip:Show()
                        end)
                        g:SetScript("OnLeave", function() GameTooltip:Hide() end)
                        g:SetScript("OnClick", function(self)
                            local s = self.spot
                            if not s or tool == "link" then return end
                            local n = AddNodeAt(s.cluster, s.ring, s.branch)
                            if n then
                                selNode, selCluster = n.id, n.cluster
                                SetStatus(fmt("Cell %d restored in cluster %d, ring %d, branch %d.",
                                    n.id, s.cluster, s.ring, s.branch))
                            end
                            Rebuild()
                        end)

                        UI.ghosts[gi] = g
                    end

                    g.spot = { cluster = c.id, ring = ring, branch = branch }
                    g:ClearAllPoints()
                    local gx, gy = ToPixels(PosOf(c.id, ring, branch))
                    g:SetPoint("CENTER", canvas, "BOTTOMLEFT", gx, gy)
                    g:Show()
                    UI.others[#UI.others + 1] = { f = g, px = gx, py = gy, visible = true }
                end
            end
        end
    end

    for i = gi + 1, #UI.ghosts do
        UI.ghosts[i].spot = nil
        UI.ghosts[i]:Hide()
    end

    -- cluster markers, with the same precautions as the cells
    for i, c in ipairs(doc.clusters) do
        local m = UI.markers[i]
        if not m then
            m = CreateFrame("Button", nil, canvas)
            m:SetWidth(16)
            m:SetHeight(16)
            m:SetBackdrop(backdrop)
            m:RegisterForClicks("LeftButtonUp")
            m:RegisterForDrag("LeftButton")

            m:SetScript("OnEnter", function(self)
                local cc = self.cluster
                if not cc then return end
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(fmt("Cluster %d", cc.id), 1, 0.82, 0)
                GameTooltip:AddLine(fmt("x %.2f   y %.2f   rotation %.0f°",
                    cc.x, cc.y, (cc.rot or 0) * 180 / pi), 0.8, 0.8, 0.8, true)
                GameTooltip:AddLine(tool == "cluster" and "Click: delete"
                    or "Drag: move", 1, 0.6, 0.6, true)
                GameTooltip:Show()
            end)
            m:SetScript("OnLeave", function() GameTooltip:Hide() end)

            m:SetScript("OnClick", function(self)
                local cc = self.cluster
                if not cc then return end
                if tool == "cluster" then
                    RemoveCluster(cc.id)
                    SetStatus(fmt("Cluster %d deleted.", cc.id))
                else
                    selCluster = cc.id
                end
                Rebuild()
            end)

            m:SetScript("OnDragStart", function(self)
                if tool ~= "select" or not self.cluster then return end
                UI.dragCluster = self.cluster.id
                SetStatus(fmt("Cluster %d moving - let go to put it down.",
                    self.cluster.id))
            end)
            m:SetScript("OnDragStop", function()
                UI.dragCluster = nil
                Rebuild()
            end)

            UI.markers[i] = m
        end

        m.cluster = c
        -- The level is set again on every rebuild and not only at creation: the
        -- canvas's own may have changed since, and a marker left at yesterday's level
        -- ends up UNDER the cells -- where it can be neither clicked nor dragged.
        m:SetFrameLevel(canvas:GetFrameLevel() + 9)
        m:ClearAllPoints()
        local x, y = ToPixels(c.x, c.y)
        -- The centre place can hold a cell, so the marker steps aside to stay
        -- grabbable.
        if NodeAt(c.id, 0, 1) then y = y + 28 end
        m:SetPoint("CENTER", canvas, "BOTTOMLEFT", x, y)
        m:SetBackdropColor(0.1, 0.1, 0.1, 1)
        if selCluster == c.id then
            m:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            m:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
        m:Show()
        UI.others[#UI.others + 1] = { f = m, px = x, py = y, visible = true,
                                      pinned = (UI.dragCluster == c.id) }
    end

    for i = #doc.clusters + 1, #UI.markers do
        UI.markers[i].cluster = nil
        UI.markers[i]:Hide()
    end

    -- File into buckets, filter, THEN the inspector that says "N drawn".
    LayOutInCells()
    Cull(true)
    UpdateInspector()
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

local function MakeButton(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(w)
    b:SetHeight(h or 20)
    b:SetBackdrop(UISTYLE_BACKDROPS and UISTYLE_BACKDROPS.Frame or {
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    })
    b:SetBackdropColor(0.14, 0.14, 0.14, 1)
    b:SetBackdropBorderColor(0, 0, 0, 1)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    b.label:SetAllPoints()
    b.label:SetText(text)
    b:SetScript("OnClick", onClick)
    b:SetScript("OnEnter", function(self) self:SetBackdropColor(0.22, 0.22, 0.22, 1) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropColor(0.14, 0.14, 0.14, 1) end)
    return b
end

local function SetTool(t)
    tool = t
    linkPending = nil
    for name, btn in pairs(UI.toolButtons) do
        if name == t then
            btn:SetBackdropBorderColor(1, 0.82, 0, 1)
            btn.label:SetTextColor(1, 0.82, 0)
        else
            btn:SetBackdropBorderColor(0, 0, 0, 1)
            btn.label:SetTextColor(1, 1, 1)
        end
    end

    if t == "link" then
        SetStatus("Link: left-click two cells to make or unmake the link between them. "
            .. "Right-click a cell to cut every link of its own.")
    elseif t == "cluster" then
        SetStatus("Cluster: click the background to lay one down, click a marker to delete it.")
    elseif t == "preview" then
        SetStatus("Preview: left-click to buy or hand back a cell, right-click to clear it all. "
            .. "A link turns cyan when both its ends are bought. None of this is saved.")
    else
        SetStatus("Select: left-click to change a cell, right-click to remove it, "
            .. "click an empty place to put one back. Drag a marker to move the cluster.")
    end

    Rebuild()
end

function SetStatus(text, isError)
    if not UI or not UI.status then return end
    UI.status:SetText(text or "")
    if isError then
        UI.status:SetTextColor(1, 0.35, 0.35)
    else
        UI.status:SetTextColor(0.7, 0.7, 0.7)
    end
end

-- THE "SPELLS BY CLASS" WINDOW: ten lines, one per class, each with the
-- identifier field and the spell's name as the client knows it. It follows the
-- selection: another spell cell fills it, anything else closes it.
local function UpdateSpellsFrame()
    local w = UI and UI.spellsFrame
    if not w or not w:IsShown() then return end
    local n = selNode and NodeById(selNode)
    if not n or n.kind ~= RC.KIND_SPELL then
        w:Hide()
        return
    end
    w.title:SetText(fmt("Spells of cell %d", n.id))
    for _, line in ipairs(w.lines) do
        local own = n.spells and n.spells[line.class]
        if not line.box:HasFocus() then
            line.box:SetText(own and tostring(own) or "")
        end
        local actual = SpellFor(n, line.class)
        local name = actual and GetSpellInfo(actual)
        if own then
            if name then
                line.name:SetText(name)
                line.name:SetTextColor(1, 1, 1)
            else
                line.name:SetText("identifier unknown to the client")
                line.name:SetTextColor(1, 0.4, 0.4)
            end
        elseif actual then
            line.name:SetText(fmt("fallback: %s", name or ("no. " .. actual)))
            line.name:SetTextColor(0.6, 0.6, 0.6)
        else
            line.name:SetText("invisible to this class")
            line.name:SetTextColor(0.55, 0.55, 0.55)
        end
    end
end

local function OpenSpellsFrame()
    if not UI then return end
    local w = UI.spellsFrame
    if not w then
        local backdrop = UISTYLE_BACKDROPS and UISTYLE_BACKDROPS.Frame or {
            bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
        }
        w = CreateFrame("Frame", nil, UI)
        w:SetWidth(440)
        w:SetHeight(36 + 10 * 22 + 12)
        w:SetPoint("TOPLEFT", UI.viewport, "TOPLEFT", 12, -12)
        w:SetBackdrop(backdrop)
        w:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
        w:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
        w:SetFrameLevel(UI.viewport:GetFrameLevel() + 20)
        w:EnableMouse(true)
        w.title = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        w.title:SetPoint("TOPLEFT", 12, -10)
        local close = MakeButton(w, "Fermer", 70, 20, function() w:Hide() end)
        close:SetPoint("TOPRIGHT", -10, -8)
        w.lines = {}
        local y = -36
        for _, c in ipairs(CLASSES) do
            if c[1] ~= 0 then
                local line = { class = c[1] }
                line.label = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                line.label:SetPoint("TOPLEFT", 12, y - 4)
                line.label:SetWidth(130)
                line.label:SetJustifyH("LEFT")
                line.label:SetText(c[2])
                local box = CreateFrame("EditBox", nil, w)
                box:SetPoint("TOPLEFT", 146, y)
                box:SetWidth(90)
                box:SetHeight(20)
                box:SetAutoFocus(false)
                box:SetNumeric(true)
                box:SetFontObject("GameFontHighlightSmall")
                box:SetBackdrop(backdrop)
                box:SetBackdropColor(0.03, 0.03, 0.03, 1)
                box:SetTextInsets(6, 6, 0, 0)
                box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
                box:SetScript("OnEnterPressed", function(self)
                    local n = selNode and NodeById(selNode)
                    if n and n.kind == RC.KIND_SPELL then
                        local id = tonumber(self:GetText()) or 0
                        n.spells = n.spells or {}
                        n.spells[line.class] = (id > 0) and id or nil
                        SetStatus(id > 0
                            and fmt("Cell %d: %s learns spell no. %d.", n.id, c[2], id)
                            or fmt("Cell %d: no spell of its own for %s any more.", n.id, c[2]))
                        Rebuild()
                    end
                    self:ClearFocus()
                end)
                line.box = box
                line.name = w:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                line.name:SetPoint("TOPLEFT", 244, y - 4)
                line.name:SetWidth(184)
                line.name:SetJustifyH("LEFT")
                w.lines[#w.lines + 1] = line
                y = y - 22
            end
        end
        UI.spellsFrame = w
    end
    w:Show()
    UpdateSpellsFrame()
end

function UpdateInspector()
    if not UI then return end

    local n = selNode and NodeById(selNode)
    if n then
        UI.inspTitle:SetText(fmt("Cell %d — %d link(s)", n.id, CountLinks(n.id)))
        if n.kind == RC.KIND_SLOT then
            UI.inspType:SetText("Slot")
            UI.inspStat:SetText("—")
            UI.inspQuality:SetText("—")
        elseif n.kind == RC.KIND_SPELL then
            UI.inspType:SetText("Spell")
            local nb, total = ClassesServed(n)
            UI.inspStat:SetText(fmt("%d / %d classes served", nb, total))
            local spellName = n.spell and n.spell > 0 and GetSpellInfo(n.spell)
            UI.inspQuality:SetText(spellName and fmt("repli : %s", spellName)
                or (n.spell and n.spell > 0 and fmt("fallback no. %d", n.spell)) or "no fallback")
        elseif not n.stat then
            UI.inspType:SetText("Empty node")
            UI.inspStat:SetText("—")
            UI.inspQuality:SetText("—")
        else
            UI.inspType:SetText("Node")
            local s = session.stats[n.stat]
            local qual = session.qualities[n.quality or 1]
            UI.inspStat:SetText(s and s.label or "?")
            UI.inspQuality:SetText(qual and fmt("%s (+%d)", qual.label, qual.bonus) or "?")
        end
        if UI.spellBox and not UI.spellBox:HasFocus() then
            UI.spellBox:SetText(n.kind == RC.KIND_SPELL and tostring(n.spell or 0) or "")
        end
        UpdateSpellsFrame()
    else
        UpdateSpellsFrame()
        UI.inspTitle:SetText("Nothing selected")
        UI.inspType:SetText("—")
        UI.inspStat:SetText("—")
        UI.inspQuality:SetText("—")
    end

    local slots, bought = 0, 0
    for _, nn in ipairs(doc.nodes) do
        if nn.kind == RC.KIND_SLOT then slots = slots + 1 end
        if bought[nn.id] then bought = bought + 1 end
    end

    local text = fmt("|cffffd100%d|r clusters · |cffffd100%d|r cells (%d sockets) · |cffffd100%d|r links",
        #doc.clusters, #doc.nodes, slots, #doc.edges)
    local startCount = 0
    for _ in pairs(doc.starts) do startCount = startCount + 1 end
    text = text .. (startCount > 0 and fmt(" - |cffffd100%d start(s)|r", startCount)
        or " - |cffff5555no start set|r")
    if bought > 0 then
        text = text .. fmt(" - |cff33e0f5%d bought|r", bought)
    end
    UI.counts:SetText(text)
end

-- THE SCROLL BOUNDS ARE COMPUTED HERE, not by GetHorizontalScrollRange: the
-- client derives those from the child's UNSCALED size, and a zoomed canvas could
-- no longer be walked end to end -- nor centred.
local function ScrollBounds()
    local vp, canvas = UI.viewport, UI.canvas
    local z = zoom > 0 and zoom or 1
    return max(0, canvas:GetWidth() - vp:GetWidth() / z),
           max(0, canvas:GetHeight() - vp:GetHeight() / z)
end

local function ClampScroll()
    local vp = UI.viewport
    local bh, bv = ScrollBounds()
    vp:SetHorizontalScroll(max(0, min(vp:GetHorizontalScroll(), bh)))
    vp:SetVerticalScroll(max(0, min(vp:GetVerticalScroll(), bv)))
end

local function Centre()
    local vp = UI.viewport
    local bh, bv = ScrollBounds()
    vp:SetHorizontalScroll(bh / 2)
    vp:SetVerticalScroll(bv / 2)
end

local function SetZoom(z)
    zoom = max(RC.ZOOM_MIN, min(RC.ZOOM_MAX, z))
    UI.canvas:SetScale(zoom)
    ClampScroll()
    UI.zoomLabel:SetText(fmt("Zoom %d%%", floor(zoom * 100 + 0.5)))
    -- Positions in canvas pixels do not move with the zoom: filtering is enough.
    Cull()
end

local function CursorInCanvas()
    local canvas = UI.canvas
    local scale  = canvas:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    return cx / scale - canvas:GetLeft(), cy / scale - canvas:GetBottom()
end

local function BuildUI()
    local backdrop = UISTYLE_BACKDROPS and UISTYLE_BACKDROPS.Frame or {
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    }

    local f = CreateFrame("Frame", "SphereGridEditorFrame", UIParent)
    f:SetWidth(1080)
    f:SetHeight(720)
    f:SetPoint("CENTER")
    f:SetBackdrop(backdrop)
    f:SetBackdropColor(0.06, 0.06, 0.06, 1)
    f:SetBackdropBorderColor(0, 0, 0, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetToplevel(true)
    f:Hide()
    UI = f
    UI.nodeButtons = {}
    UI.markers     = {}
    UI.ghosts      = {}
    UI.others      = {}
    UI.linePool    = { free = {}, used = {} }
    UI.toolButtons = {}

    -- ------------------------------------------------------------- bandeau
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", -1, -1)
    header:SetHeight(32)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local hBackground = header:CreateTexture(nil, "BACKGROUND")
    hBackground:SetAllPoints()
    hBackground:SetTexture(0.12, 0.12, 0.12, 1)
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 12, 0)
    title:SetText("Sphere grid - layout editor")
    title:SetTextColor(1, 0.82, 0)
    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Escape closes the editor, exactly as this button does: the layout being
    -- edited lives in module variables and outlives it, so nothing is lost.
    table.insert(UISpecialFrames, "SphereGridEditorFrame")

    -- ------------------------------------------------------- left panel
    local panel = CreateFrame("Frame", nil, f)
    panel:SetPoint("TOPLEFT", 8, -38)
    panel:SetPoint("BOTTOMLEFT", 8, 54)
    panel:SetWidth(RC.PANEL_W)
    panel:SetBackdrop(backdrop)
    panel:SetBackdropColor(0.09, 0.09, 0.09, 1)

    local y = -10
    local function section(text)
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", 10, y)
        fs:SetText(text)
        fs:SetTextColor(1, 0.82, 0)
        y = y - 18
    end
    local function row(labelText)
        local l = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        l:SetPoint("TOPLEFT", 10, y)
        l:SetText(labelText)
        local v = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        v:SetPoint("TOPLEFT", 74, y)
        v:SetText("—")
        return v
    end

    section("TOOLS")
    local tools = {
        { "select",  "Select" },
        { "cluster", "Cluster" },
        { "link",    "Lier" },
        { "preview", "Preview" },
    }
    for _, t in ipairs(tools) do
        local key, label = t[1], t[2]
        local b = MakeButton(panel, label, RC.PANEL_W - 20, 22, function() SetTool(key) end)
        b:SetPoint("TOPLEFT", 10, y)
        UI.toolButtons[key] = b
        y = y - 25
    end

    y = y - 8
    section("SELECTION")
    UI.inspTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.inspTitle:SetPoint("TOPLEFT", 10, y)
    UI.inspTitle:SetText("Nothing selected")
    y = y - 20

    UI.inspType = row("Type")
    y = y - 16
    UI.inspStat = row("Stat")
    y = y - 16
    UI.inspQuality = row("Quality")
    y = y - 20

    local function cycleNode(field, delta, maxv)
        local n = selNode and NodeById(selNode)
        if not n or n.kind == RC.KIND_SLOT then return end
        local v = (n[field] or 1) + delta
        if v < 1 then v = maxv elseif v > maxv then v = 1 end
        n[field] = v
        Rebuild()
    end

    local bType = MakeButton(panel, "Node / Socket / Spell", RC.PANEL_W - 20, 20, function()
        local n = selNode and NodeById(selNode)
        if not n then return end
        if n.kind == RC.KIND_NODE then
            MakeSlot(n)
            SetStatus(fmt("Cell %d turned into a socket: its stone was removed.", n.id))
        elseif n.kind == RC.KIND_SLOT then
            MakeSpell(n)
            SetStatus(fmt("Cell %d turned into a spell cell - type the spell identifier.", n.id))
        else
            MakeNode(n)
            SetStatus(fmt("Cell %d turned back into a node, with a stone drawn at random.", n.id))
        end
        Rebuild()
    end)
    bType:SetPoint("TOPLEFT", 10, y)
    y = y - 23

    -- An empty node: toggles the pre-filled stone on and off.
    local bStone = MakeButton(panel, "Stone: put in / take out", RC.PANEL_W - 20, 20, function()
        local n = selNode and NodeById(selNode)
        if not n or n.kind ~= RC.KIND_NODE then return end
        if n.stat then
            n.stat, n.quality = nil, nil
            SetStatus(fmt("Cell %d: an empty node, with no stone laid in.", n.id))
        else
            n.stat    = random(#session.stats)
            n.quality = random(#session.qualities)
            SetStatus(fmt("Cell %d: a stone laid in, drawn at random.", n.id))
        end
        Rebuild()
    end)
    bStone:SetPoint("TOPLEFT", 10, y)
    y = y - 23

    -- The identifier of a spell cell's own spell.
    local spellLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    spellLabel:SetPoint("TOPLEFT", 10, y - 4)
    spellLabel:SetText("Fallback no.")
    local spellBox = CreateFrame("EditBox", nil, panel)
    spellBox:SetPoint("TOPLEFT", 74, y)
    spellBox:SetWidth(70)
    spellBox:SetHeight(20)
    spellBox:SetAutoFocus(false)
    spellBox:SetNumeric(true)
    spellBox:SetFontObject("GameFontHighlightSmall")
    spellBox:SetBackdrop(backdrop)
    spellBox:SetBackdropColor(0.03, 0.03, 0.03, 1)
    spellBox:SetTextInsets(6, 6, 0, 0)
    spellBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    spellBox:SetScript("OnEnterPressed", function(self)
        local n = selNode and NodeById(selNode)
        if n and n.kind == RC.KIND_SPELL then
            n.spell = tonumber(self:GetText()) or 0
            SetStatus(fmt("Cell %d: spell no. %d.", n.id, n.spell))
            Rebuild()
        end
        self:ClearFocus()
    end)
    UI.spellBox = spellBox
    -- The ten spells, one per class: the window made for it.
    local bSpells = MakeButton(panel, "By class…", RC.PANEL_W - 160, 20, function()
        local n = selNode and NodeById(selNode)
        if not n or n.kind ~= RC.KIND_SPELL then
            SetStatus("Select a spell cell first.")
            return
        end
        if UI.spellsFrame and UI.spellsFrame:IsShown() then UI.spellsFrame:Hide() else OpenSpellsFrame() end
    end)
    bSpells:SetPoint("TOPLEFT", 150, y)
    y = y - 23

    local bs1 = MakeButton(panel, "< Stat", 88, 20, function() cycleNode("stat", -1, #session.stats) end)
    bs1:SetPoint("TOPLEFT", 10, y)
    local bs2 = MakeButton(panel, "Stat >", 88, 20, function() cycleNode("stat", 1, #session.stats) end)
    bs2:SetPoint("TOPLEFT", 108, y)
    y = y - 23

    local bq1 = MakeButton(panel, "< Quality", 88, 20, function() cycleNode("quality", -1, #session.qualities) end)
    bq1:SetPoint("TOPLEFT", 10, y)
    local bq2 = MakeButton(panel, "Quality >", 88, 20, function() cycleNode("quality", 1, #session.qualities) end)
    bq2:SetPoint("TOPLEFT", 108, y)
    y = y - 23

    local bRand = MakeButton(panel, "Tirer au hasard", RC.PANEL_W - 20, 20, function()
        local n = selNode and NodeById(selNode)
        if not n then return end
        RandomContent(n)
        Rebuild()
    end)
    bRand:SetPoint("TOPLEFT", 10, y)
    y = y - 23

    local bDelNode = MakeButton(panel, "Remove the cell", RC.PANEL_W - 20, 20, function()
        local n = selNode and NodeById(selNode)
        if not n then return end
        local id = n.id
        RemoveNode(id)
        SetStatus(fmt("Cell %d removed. Its place remains: click it to put the cell back.", id))
        Rebuild()
    end)
    bDelNode:SetPoint("TOPLEFT", 10, y)
    y = y - 23

    -- THE START'S CLASS: a button that cycles through the classes (left-click for
    -- the next, right-click for the previous). The shared grid wants one start per
    -- class; a class grid keeps "every class".
    local bClass = MakeButton(panel, "", RC.PANEL_W - 20, 20, function() end)
    bClass:SetPoint("TOPLEFT", 10, y)
    local function UpdateClass()
        bClass.label:SetText("Start: " .. CLASSES[startClass][2])
    end
    bClass:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bClass:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            startClass = (startClass - 2) % #CLASSES + 1
        else
            startClass = startClass % #CLASSES + 1
        end
        UpdateClass()
    end)
    UpdateClass()
    y = y - 23

    local bStart = MakeButton(panel, "Set as start", RC.PANEL_W - 20, 20, function()
        local n = selNode and NodeById(selNode)
        if not n then return end
        local class = CLASSES[startClass][1]
        if doc.starts[class] == n.id then
            doc.starts[class] = nil
            SetStatus(fmt("Cell %d is no longer the start (%s).", n.id, ClassName(class)))
        else
            doc.starts[class] = n.id
            SetStatus(fmt("Cell %d set as the start (%s).", n.id, ClassName(class)))
        end
        Rebuild()
    end)
    bStart:SetPoint("TOPLEFT", 10, y)
    y = y - 28

    section("SELECTED CLUSTER")
    local function rotate(delta)
        local c = selCluster and ClusterById(selCluster)
        if not c then return end
        c.rot = (c.rot or 0) + delta
        Rebuild()
    end
    local br1 = MakeButton(panel, "< Rotation", 88, 20, function() rotate(-pi / 16) end)
    br1:SetPoint("TOPLEFT", 10, y)
    local br2 = MakeButton(panel, "Rotation >", 88, 20, function() rotate(pi / 16) end)
    br2:SetPoint("TOPLEFT", 108, y)
    y = y - 23

    local bDel = MakeButton(panel, "Delete the cluster", RC.PANEL_W - 20, 20, function()
        if not selCluster then return end
        RemoveCluster(selCluster)
        SetStatus("Cluster deleted.")
        Rebuild()
    end)
    bDel:SetPoint("TOPLEFT", 10, y)
    y = y - 28

    section("FILE")
    local nameBox = CreateFrame("EditBox", nil, panel)
    nameBox:SetPoint("TOPLEFT", 10, y)
    nameBox:SetWidth(RC.PANEL_W - 20)
    nameBox:SetHeight(20)
    nameBox:SetAutoFocus(false)
    nameBox:SetFontObject("GameFontHighlightSmall")
    nameBox:SetBackdrop(backdrop)
    nameBox:SetBackdropColor(0.03, 0.03, 0.03, 1)
    nameBox:SetTextInsets(6, 6, 0, 0)
    nameBox:SetText("draft")
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    UI.nameBox = nameBox
    y = y - 24

    local bSave = MakeButton(panel, "Enregistrer", 88, 20, function()
        AIO.Handle("SphereGridEditor", "Save", nameBox:GetText(), doc.clusters, doc.nodes, doc.edges, doc.starts)
    end)
    bSave:SetPoint("TOPLEFT", 10, y)
    local bLoad = MakeButton(panel, "Charger", 88, 20, function()
        AIO.Handle("SphereGridEditor", "Load", nameBox:GetText())
    end)
    bLoad:SetPoint("TOPLEFT", 108, y)
    y = y - 23

    local bCheck = MakeButton(panel, "Verify", 88, 20, function()
        AIO.Handle("SphereGridEditor", "Verify", doc.clusters, doc.nodes, doc.edges, doc.starts)
    end)
    bCheck:SetPoint("TOPLEFT", 10, y)
    local bNew = MakeButton(panel, "Vider", 88, 20, function()
        doc.clusters, doc.nodes, doc.edges = {}, {}, {}
        doc.nextCluster, doc.nextNode = 1, 1
        doc.starts = {}
        selNode, selCluster, linkPending = nil, nil, nil
        bought = {}
        offenders = {}
        SetStatus("Layout cleared.")
        Rebuild()
    end)
    bNew:SetPoint("TOPLEFT", 108, y)
    y = y - 26

    UI.layoutList = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.layoutList:SetPoint("TOPLEFT", 10, y)
    UI.layoutList:SetWidth(RC.PANEL_W - 20)
    UI.layoutList:SetJustifyH("LEFT")
    UI.layoutList:SetText("")

    -- ------------------------------------------------------------- canevas
    local viewport = CreateFrame("ScrollFrame", "SphereGridEditorViewport", f)
    viewport:SetPoint("TOPLEFT", RC.PANEL_W + 16, -38)
    viewport:SetPoint("BOTTOMRIGHT", -8, 54)
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    UI.viewport = viewport

    local vpBackground = viewport:CreateTexture(nil, "BACKGROUND")
    vpBackground:SetAllPoints()
    vpBackground:SetTexture(0.03, 0.03, 0.03, 1)

    local canvas = CreateFrame("Frame", "SphereGridEditorCanvas", viewport)
    canvas:SetWidth(1400)
    canvas:SetHeight(1000)
    viewport:SetScrollChild(canvas)
    UI.canvas = canvas

    local dragging, startX, startY, startH, startV = false
    viewport:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        if tool == "select" then
            local scale = UIParent:GetEffectiveScale()
            startX, startY = GetCursorPosition()
            startX, startY = startX / scale, startY / scale
            startH, startV = self:GetHorizontalScroll(), self:GetVerticalScroll()
            dragging = true
        end
    end)

    viewport:SetScript("OnMouseUp", function(_, button)
        local wasDragging = dragging
        dragging = false
        if wasDragging and button == "LeftButton" and tool == "select" then Cull(true) end
        if button == "LeftButton" and tool == "cluster" then
            local lx, ly = CursorInCanvas()
            local gx, gy = ToGrid(lx, ly)
            gx = floor(gx / RC.SNAP + 0.5) * RC.SNAP
            gy = floor(gy / RC.SNAP + 0.5) * RC.SNAP
            local c = AddCluster(gx, gy)
            selCluster, selNode = c.id, nil
            SetStatus(fmt("Cluster %d laid down at %.2f, %.2f.", c.id, gx, gy))
            Rebuild()
        end
    end)
    viewport:SetScript("OnHide", function() dragging = false end)

    viewport:SetScript("OnUpdate", function(self)
        -- THE FRAME TIME itself: GetTime() is the frame's stamp, and its difference
        -- between two OnUpdate calls is how long the previous frame took. That is what
        -- tells the script apart from the engine: a visible freeze with a 2 ms filter is
        -- a freeze of the engine.
        do
            local t = GetTime()
            if UI.lastFrame then
                local dt = (t - UI.lastFrame) * 1000
                if dt > (UI.worstFrame or 0) then UI.worstFrame = dt end
                if t - (UI.sinceFrame or 0) > 0.5 then
                    if UI.imageLabel then
                        UI.imageLabel:SetText(fmt("image %.0f ms", UI.worstFrame or 0))
                    end
                    UI.worstFrame, UI.sinceFrame = 0, t
                end
            end
            UI.lastFrame = t
        end
        DressAsBackground()
        if UI.dragCluster then
            -- A safety net: OnDragStop is not relied on alone. If the button is no longer
            -- held, the cluster is put down, whatever became of the frame meanwhile.
            if not IsMouseButtonDown("LeftButton") then
                local id = UI.dragCluster
                UI.dragCluster = nil
                SetStatus(fmt("Cluster %d put down.", id))
                Rebuild()
                return
            end

            local c = ClusterById(UI.dragCluster)
            if c then
                local lx, ly = CursorInCanvas()
                local gx, gy = ToGrid(lx, ly)
                local nx = floor(gx / RC.SNAP + 0.5) * RC.SNAP
                local ny = floor(gy / RC.SNAP + 0.5) * RC.SNAP
                -- Rebuild only if the snapping actually moved it.
                if nx ~= c.x or ny ~= c.y then
                    c.x, c.y = nx, ny
                    Rebuild()
                end
            end
            return
        end

        if not dragging then return end
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        -- The cursor is measured in screen pixels, the scrolling in canvas pixels: so
        -- we divide by the zoom, as the player interface does.
        local k = (zoom > 0) and zoom or 1
        self:SetHorizontalScroll(startH - (cx - startX) / k)
        self:SetVerticalScroll(startV + (cy - startY) / k)
        ClampScroll()
        Cull()                  -- cheap: every frame, without stutter
    end)

    viewport:SetScript("OnMouseWheel", function(_, delta) SetZoom(zoom + delta * RC.ZOOM_STEP) end)

    -- ---------------------------------------------------------------- pied
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetHeight(50)
    local fBackground = footer:CreateTexture(nil, "BACKGROUND")
    fBackground:SetAllPoints()
    fBackground:SetTexture(0.09, 0.09, 0.09, 1)

    UI.counts = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.counts:SetPoint("TOPLEFT", 12, -8)
    -- What the filter shows, written by the filter itself: held on the inspector,
    -- the count stayed frozen between rebuilds.
    UI.drawnLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.drawnLabel:SetPoint("LEFT", UI.counts, "RIGHT", 8, 0)

    UI.status = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.status:SetPoint("BOTTOMLEFT", 12, 8)
    UI.status:SetWidth(820)
    UI.status:SetJustifyH("LEFT")

    UI.zoomLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.zoomLabel:SetPoint("BOTTOMRIGHT", -12, 8)
    -- What the filter costs, so it can be measured rather than assumed.
    UI.perfLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.perfLabel:SetPoint("RIGHT", UI.zoomLabel, "LEFT", -12, 0)
    UI.perfLabel:SetText("filter –")
    UI.imageLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.imageLabel:SetPoint("RIGHT", UI.perfLabel, "LEFT", -12, 0)
    UI.imageLabel:SetText("image –")

    local bFit = MakeButton(footer, "Recentrer", 86, 20, function()
        SetZoom(1)
        Centre()
        Rebuild()
    end)
    bFit:SetPoint("TOPRIGHT", -12, -8)

    -- The filter's switch. "Filter: on" draws only the window and dresses the rest
    -- in the background; "off" draws and dresses everything at once on rebuild.
    -- It is there to compare the two by eye.
    local bFilter = MakeButton(footer, "Filtre : oui", 86, 20, function() end)
    bFilter:SetPoint("RIGHT", bFit, "LEFT", -6, 0)
    bFilter:SetScript("OnClick", function(self)
        UI.noFilter = not UI.noFilter
        self.label:SetText(UI.noFilter and "Filtre : non" or "Filtre : oui")
        Rebuild()
    end)

    return f
end

-- ---------------------------------------------------------------------------
-- Handlers
-- ---------------------------------------------------------------------------

local function EnsureUI()
    if not UI then
        BuildUI()
        SetTool("select")
    end
end

function EditorHandlers.ReceiveSession(_, geometry, stats, qualities, slotIcon, layouts, minSeparation)
    session.geometry = geometry or session.geometry
    session.stats    = stats or {}
    session.qualities = qualities or {}
    session.slotIcon = slotIcon or ""
    session.layouts  = layouts or {}
    session.minSeparation   = minSeparation or 0.7

    EnsureUI()
    UI.layoutList:SetText(#session.layouts > 0
        and ("In store: " .. table.concat(session.layouts, ", "))
        or "No layout saved.")
    UI:Show()
    SetZoom(1)
    Rebuild()
    SetStatus("Take the Cluster tool, then click the background to lay a first one down.")
end

function EditorHandlers.OpenEditor(_)
    EnsureUI()
    if UI:IsShown() then
        UI:Hide()
    else
        AIO.Handle("SphereGridEditor", "RequestSession")
    end
end

function EditorHandlers.ReceiveLayoutList(_, layouts)
    session.layouts = layouts or {}
    if UI then
        UI.layoutList:SetText(#session.layouts > 0
            and ("In store: " .. table.concat(session.layouts, ", "))
            or "No layout saved.")
    end
end

local function ReportText(r)
    if not r then return "" end
    local head = fmt("%d clusters - %d cells (%d sockets) - %d links - min gap %.3f u - %d piece(s)",
        r.clusters or 0, r.nodes or 0, r.slots or 0, r.edges or 0, r.minSeparation or 0, r.groups or 0)
    if r.problems and #r.problems > 0 then
        return head .. "  |cffff5555>> " .. table.concat(r.problems, " ; ") .. "|r"
    end
    return head .. "  |cff55ff55>> no fault|r"
end

-- The report carries a LIST of identifiers, while the drawing asks by
-- identifier. A report with no list -- the one a failed read returns -- simply
-- clears the previous markers.
local function ReportMarkers(r)
    local set = {}
    if r and r.offenders then
        for _, id in ipairs(r.offenders) do set[id] = true end
    end
    return set
end

function EditorHandlers.ReceiveReport(_, report, message)
    EnsureUI()
    -- REDRAW, without which the red would only appear at the next refresh -- and the
    -- moment of the report is exactly when one is looking.
    offenders = ReportMarkers(report)
    Rebuild()
    SetStatus((message and (message .. "  ") or "") .. ReportText(report), report and not report.ok)
end

function EditorHandlers.ReceiveLayout(_, clusters, nodes, edges, name, report, start)
    EnsureUI()

    doc.clusters = clusters or {}
    doc.nodes    = nodes or {}
    doc.edges    = edges or {}
    -- A bare number is the older form: a single start, for "every class".
    if type(start) == "number" then
        doc.starts = { [0] = start }
    else
        doc.starts = {}
        for class, id in pairs(start or {}) do
            doc.starts[tonumber(class)] = tonumber(id)
        end
    end

    local maxC, maxN = 0, 0
    for _, c in ipairs(doc.clusters) do if c.id > maxC then maxC = c.id end end
    for _, n in ipairs(doc.nodes) do if n.id > maxN then maxN = n.id end end
    doc.nextCluster, doc.nextNode = maxC + 1, maxN + 1

    selNode, selCluster, linkPending = nil, nil, nil
    -- The identifiers come from the file: a preview inherited from the previous
    -- layout would name cells no report ever mentioned.
    bought = {}
    offenders = ReportMarkers(report)
    if UI.nameBox then UI.nameBox:SetText(name or "") end

    UI:Show()
    -- REBUILD FIRST: the canvas takes the layout's size, and only then does
    -- centring have its bounds. Centring before meant centring on yesterday's
    -- canvas -- the window opened on an empty corner and the foot said "0 drawn".
    SetZoom(1)
    Rebuild()
    Centre()
    Cull(true)
    SetStatus(fmt("\"%s\" loaded.  ", name or "?") .. ReportText(report), report and not report.ok)
end

-- /spheregrid belongs to the player interface (player/Player_Client.lua).
-- The editor opens with .spheregrid editor.
