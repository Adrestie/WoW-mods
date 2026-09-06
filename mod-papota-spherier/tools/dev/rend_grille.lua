--[[----------------------------------------------------------------------------
    rend_grille.lua — rendu SVG d'une disposition, pour consultation hors jeu.

    Usage, repertoire de travail = bin\RelWithDebInfo du serveur :
      lua52_interpreter.exe D:\...\rend_grille.lua <disposition> <sortie.svg>

    Meme motif que importe_layout.lua : Spherier_Server.lua est charge avec un
    AIO factice, la lecture et la geometrie sont donc celles de l'editeur.
    Noeud = cercle a la couleur de qualite, slot = carre bleu, depart = anneau
    dore, chaque emplacement porte son numero.
------------------------------------------------------------------------------]]

local nomDisposition = arg[1]
local cheminSortie   = arg[2]
assert(nomDisposition and cheminSortie,
    "usage : rend_grille.lua <disposition> <sortie.svg>")

local H, reponses = {}, {}
package.preload["AIO"] = function()
    return {
        AddHandlers = function() return H end,
        Handle = function(_, _, quoi, ...)
            reponses[#reponses + 1] = { quoi = quoi, ... }
        end,
    }
end
function RegisterPlayerEvent() end

local vraiPrint = print
print = function() end
dofile("lua_scripts/Spherier/Spherier_Server.lua")
print = vraiPrint

local function Derniere(quoi)
    for i = #reponses, 1, -1 do
        if reponses[i].quoi == quoi then return reponses[i] end
    end
end

H.RequestSession({})
local session = assert(Derniere("ReceiveSession"), "RequestSession sans reponse")
local GEOMETRY, STATS = session[1], session[2]

H.Load({}, nomDisposition)
local charge = Derniere("ReceiveLayout")
if not charge then
    local rapport = Derniere("ReceiveReport")
    error("chargement impossible : "
        .. table.concat((rapport and rapport[1].problems) or { "raison inconnue" }, " ; "))
end
local clusters, nodes, edges, depart = charge[1], charge[2], charge[3], charge[6]

-- Couleurs d'affichage (celles de l'editeur, usage purement visuel).
local QUALITY_COLORS = { "#ffffff", "#1eff00", "#0070dd", "#a335ee", "#ff8000" }
local SLOT_COLOR   = "#4fb0e3"
local DEPART_COLOR = "#ffd100"

local cParId = {}
for _, c in ipairs(clusters) do cParId[c.id] = c end

local function Position(n)
    local c = assert(cParId[n.cluster], "cluster inconnu " .. tostring(n.cluster))
    -- Un anneau SANS RAYON est la place centrale du cluster (revision du
    -- 2026-08-23) — meme regle que l'editeur et importe_layout.lua. L'assertion
    -- qui regnait ici refusait l'anneau 0 et ne rendait plus aucune grille.
    local r = GEOMETRY.radii[n.ring]
    if not r then return c.x, c.y end
    local a = (c.rot or 0) + (n.branch - 1) * 2 * math.pi / GEOMETRY.branches
    return c.x + r * math.cos(a), c.y + r * math.sin(a)
end

-- Etendue puis projection : y du jeu vers le haut, y du SVG vers le bas.
local S, MARGE = 60, 60
local minx, maxx, miny, maxy = math.huge, -math.huge, math.huge, -math.huge
local pos = {}
for _, n in ipairs(nodes) do
    local x, y = Position(n)
    pos[n.id] = { x = x, y = y }
    minx, maxx = math.min(minx, x), math.max(maxx, x)
    miny, maxy = math.min(miny, y), math.max(maxy, y)
end
assert(next(pos), "disposition vide")

local W = (maxx - minx) * S + 2 * MARGE
local Hgt = (maxy - miny) * S + 2 * MARGE
local function px(x) return (x - minx) * S + MARGE end
local function py(y) return (maxy - y) * S + MARGE end

local L = {}
L[#L + 1] = string.format(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%.0f" height="%.0f" viewBox="0 0 %.0f %.0f">',
    W, Hgt, W, Hgt)
L[#L + 1] = string.format('<rect width="%.0f" height="%.0f" fill="#101010"/>', W, Hgt)

-- liaisons (cordes droites : la precision de l'arc ne sert a rien ici)
for _, e in ipairs(edges) do
    local a, b = pos[e[1]], pos[e[2]]
    if a and b then
        L[#L + 1] = string.format(
            '<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#5a5a5a" stroke-width="2"/>',
            px(a.x), py(a.y), px(b.x), py(b.y))
    end
end

-- reperes de cluster
for _, c in ipairs(clusters) do
    L[#L + 1] = string.format(
        '<text x="%.1f" y="%.1f" fill="#808080" font-size="15" font-family="sans-serif" text-anchor="middle">C%d</text>',
        px(c.x), py(c.y) + 5, c.id)
end

-- emplacements
for _, n in ipairs(nodes) do
    local p = pos[n.id]
    local X, Y = px(p.x), py(p.y)

    if depart == n.id then
        L[#L + 1] = string.format(
            '<circle cx="%.1f" cy="%.1f" r="24" fill="none" stroke="%s" stroke-width="3"/>',
            X, Y, DEPART_COLOR)
    end

    if n.kind == 1 then
        L[#L + 1] = string.format(
            '<rect x="%.1f" y="%.1f" width="30" height="30" fill="#182430" stroke="%s" stroke-width="2.5"/>',
            X - 15, Y - 15, SLOT_COLOR)
    else
        L[#L + 1] = string.format(
            '<circle cx="%.1f" cy="%.1f" r="16" fill="#1c1c22" stroke="%s" stroke-width="3"/>',
            X, Y, QUALITY_COLORS[n.quality or 1] or QUALITY_COLORS[1])
    end

    L[#L + 1] = string.format(
        '<text x="%.1f" y="%.1f" fill="#e8e8e8" font-size="12" font-family="sans-serif" text-anchor="middle">%d</text>',
        X, Y + 4, n.id)
end

L[#L + 1] = '</svg>'

local f = assert(io.open(cheminSortie, "w"))
f:write(table.concat(L, "\n"), "\n")
f:close()

print(string.format("SVG ecrit : %s (%d emplacements, %d liaisons%s)",
    cheminSortie, #nodes, #edges,
    depart and (", depart " .. depart) or ", pas de depart"))
