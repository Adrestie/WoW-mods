-- Cluster percé : on retire des emplacements et on verifie que le controle
-- serveur signale bien la fragmentation quand elle survient.
local H, out = {}, {}
package.preload["AIO"] = function()
    return { AddHandlers = function() return H end,
             Handle = function(_, _, name, a, b, c, d, e)
                 out[#out+1] = { name = name, a = a, b = b, c = c, d = d, e = e } end }
end
function RegisterPlayerEvent() end
local rp = print; print = function() end
dofile("lua_scripts/Spherier/Spherier_Server.lua")
print = rp

local function build(removeIds)
    local clusters, nodes, edges, ids = {}, {}, {}, {}
    clusters[1] = { id = 1, x = 0, y = 0, rot = 0 }
    local nid = 0
    for ring = 1, 3 do
        ids[ring] = {}
        for br = 1, 8 do
            nid = nid + 1
            if not removeIds[nid] then
                nodes[#nodes+1] = { id = nid, cluster = 1, ring = ring, branch = br,
                                    kind = 0, stat = 1, quality = 1 }
                ids[ring][br] = nid
            end
        end
    end
    local function link(a, b) if a and b then edges[#edges+1] = { a, b } end end
    for ring = 1, 3 do
        for br = 1, 8 do link(ids[ring][br], ids[ring][br % 8 + 1]) end
    end
    for ring = 1, 2 do
        for br = 1, 8 do link(ids[ring][br], ids[ring+1][br]) end
    end
    return clusters, nodes, edges
end

local function run(label, removeIds)
    out = {}
    local c, n, e = build(removeIds)
    H.Save({}, "test_trous", c, n, e)
    for _, o in ipairs(out) do
        if o.name == "ReceiveReport" then
            local r = o.a
            rp(string.format("%s : %d emplacements, %d liaisons, %d morceau(x) -> %s",
                label, r.nodes, r.edges, r.groups,
                (#r.problems == 0) and "aucun defaut" or table.concat(r.problems, " ; ")))
        end
    end
end

run("cluster complet          ", {})
run("3 emplacements retires   ", { [5]=true, [12]=true, [20]=true })
-- isole la branche 1 : on coupe l'anneau 3 autour d'elle et son rayon
run("anneau 2 entierement retire", { [9]=true,[10]=true,[11]=true,[12]=true,[13]=true,[14]=true,[15]=true,[16]=true })

out = {}
H.Load({}, "test_trous")
for _, o in ipairs(out) do
    if o.name == "ReceiveLayout" then
        rp(string.format("relecture                : %d clusters, %d emplacements, %d liaisons",
            #o.a, #o.b, #o.c))
    end
end
