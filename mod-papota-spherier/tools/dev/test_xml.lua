-- Aller-retour XML de l'editeur, hors serveur.
local H, out = {}, {}
package.preload["AIO"] = function()
    return {
        AddHandlers = function() return H end,
        Handle = function(_, _, name, a, b, c, d, e)
            out[#out+1] = { name = name, a = a, b = b, c = c, d = d, e = e }
        end,
    }
end
function RegisterPlayerEvent() end
local realPrint = print
print = function() end
dofile("lua_scripts/Spherier/Spherier_Server.lua")
print = realPrint

-- deux clusters de 24 emplacements, avec les liaisons internes
local clusters, nodes, edges = {}, {}, {}
local nid = 0
for ci = 1, 2 do
    clusters[ci] = { id = ci, x = (ci - 1) * 6.5, y = 0, rot = (ci - 1) * 0.3 }
    local ids = {}
    for ring = 1, 3 do
        ids[ring] = {}
        for br = 1, 8 do
            nid = nid + 1
            nodes[#nodes+1] = { id = nid, cluster = ci, ring = ring, branch = br,
                kind = (br == 3) and 1 or 0, stat = (nid % 13) + 1, quality = (nid % 6) + 1 }
            ids[ring][br] = nid
        end
    end
    for ring = 1, 3 do
        for br = 1, 8 do edges[#edges+1] = { ids[ring][br], ids[ring][br % 8 + 1] } end
    end
    for ring = 1, 2 do
        for br = 1, 8 do edges[#edges+1] = { ids[ring][br], ids[ring+1][br] } end
    end
end
-- une liaison manuelle entre les deux clusters
edges[#edges+1] = { 1, 25 }

H.Save({}, "test_auto", clusters, nodes, edges)
local rep = out[#out-1] or out[#out]
for _, o in ipairs(out) do
    if o.name == "ReceiveReport" then
        local r = o.a
        print(string.format("SAUVEGARDE : %d clusters, %d emplacements (%d slots), %d liaisons, ecart min %.3f, %d morceau(x)",
            r.clusters, r.nodes, r.slots, r.edges, r.minSep, r.groups))
        if #r.problems > 0 then print("  defauts : " .. table.concat(r.problems, " ; "))
        else print("  aucun defaut") end
    end
end

out = {}
H.Load({}, "test_auto")
for _, o in ipairs(out) do
    if o.name == "ReceiveLayout" then
        print(string.format("RELECTURE : %d clusters, %d emplacements, %d liaisons",
            #o.a, #o.b, #o.c))
        local r = o.e
        print(string.format("  controle : ecart min %.3f, %d morceau(x), %s",
            r.minSep, r.groups, (#r.problems == 0) and "aucun defaut" or table.concat(r.problems, " ; ")))
        -- verification de fidelite
        local ok = (#o.a == #clusters) and (#o.b == #nodes) and (#o.c == #edges)
        print("  fidelite : " .. (ok and "identique a l'original" or "DIVERGENCE"))
    elseif o.name == "ReceiveReport" then
        print("  ECHEC : " .. table.concat(o.a.problems, " ; "))
    end
end
