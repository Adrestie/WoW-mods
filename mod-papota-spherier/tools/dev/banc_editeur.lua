--[[----------------------------------------------------------------------------
    banc_editeur.lua — banc d'essai de l'ÉDITEUR de sphérier, hors jeu.

    Charge Spherier_Server.lua puis Spherier_Client.lua avec un AIO factice et
    un faux client WoW (cadres, textures, chaînes : tout est compté, rien n'est
    dessiné), charge une disposition exactement comme le jeu le fait, puis
    rapporte ce que la reconstruction et le filtre comptent et affichent.
    Simule ensuite un glissement de la caméra jusqu'au centre et quelques
    crans de zoom, en comptant les appels au moteur par image.

    Usage, répertoire de travail = bin\RelWithDebInfo du serveur :
      python "D:\Serveur WoW\outils_spherier\lua51.py" banc_editeur.lua . [nom] [racine client]
    (nom : disposition à charger, « commune » par défaut ; racine client : si
    donnée, les icônes demandées sont vérifiées dans les sources spherier_art)
------------------------------------------------------------------------------]]

local fmt = string.format
local nom = (arg and arg[1]) or "commune"

-- ---------------------------------------------------------------------------
-- Faux client WoW : module partage avec banc_joueur.lua (faux_client.lua)
-- ---------------------------------------------------------------------------
local F = dofile("D:/Serveur WoW/outils_spherier/faux_client.lua")
local COMPTE, TOUS, PAR_NOM, CURSEUR, razCompte = F.COMPTE, F.TOUS, F.PAR_NOM, F.CURSEUR, F.razCompte

-- ---------------------------------------------------------------------------
-- AIO factice : le serveur et le client se parlent en direct
-- ---------------------------------------------------------------------------
local SRV, CLI
local JOUEUR = {}                       -- sans GetGMRank : admin hors jeu
AIO = {
    AddAddon = function() return false end,
    AddHandlers = function(_, t)
        if not SRV then SRV = t else CLI = t end
        return t
    end,
    Handle = function(a, b, c, ...)
        if type(a) == "string" then     -- client → serveur : ("Spherier", "Nom", …)
            local h = SRV and SRV[b]
            if h then h(JOUEUR, c, ...) end
        else                            -- serveur → client : (joueur, "Spherier", "Nom", …)
            local h = CLI and CLI[c]
            if h then h(JOUEUR, ...) end
        end
    end,
}
package.preload["AIO"] = function() return AIO end
function RegisterPlayerEvent() end

local vraiPrint = print
print = function() end
dofile("lua_scripts/Spherier/Spherier_Server.lua")
dofile("lua_scripts/Spherier/Spherier_Client.lua")
print = vraiPrint
assert(SRV and CLI, "les deux jeux de handlers ne sont pas enregistrés")
-- L'interface joueur n'est pas exercée ici, mais elle est COMPILÉE par le même
-- Lua 5.1 que le client : syntaxe et limite des 60 upvalues par fonction.
assert(loadfile("lua_scripts/Spherier/Spherier_Joueur_Client.lua"))
vraiPrint("Spherier_Joueur_Client.lua : compilé (Lua 5.1, upvalues dans la limite)")

-- ---------------------------------------------------------------------------
-- Sondes
-- ---------------------------------------------------------------------------
local function sansCouleur(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

local function chaineContenant(motif)
    for i = #TOUS, 1, -1 do
        local o = TOUS[i]
        if o.genre == "FontString" and o.texte:find(motif, 1, true) then return sansCouleur(o.texte) end
    end
    return "(aucune chaîne contenant « " .. motif .. " »)"
end

local function montres(genre, parent)
    local m, n = 0, 0
    for _, o in ipairs(TOUS) do
        if o.genre == genre and o.parent == parent then
            n = n + 1
            if o.montre then m = m + 1 end
        end
    end
    return m, n
end

-- Les boutons du canevas par famille : emplacements (btn.node), places vides
-- (g.spot), repères de cluster (m.cluster) — les champs que le client y note.
local function familles(canvas)
    local r = { noeuds = { 0, 0 }, vides = { 0, 0 }, reperes = { 0, 0 } }
    for _, o in ipairs(TOUS) do
        if o.genre == "Button" and o.parent == canvas then
            local fam = (o.node and "noeuds") or (o.spot and "vides") or (o.cluster and "reperes")
            if fam then
                r[fam][2] = r[fam][2] + 1
                if o.montre then r[fam][1] = r[fam][1] + 1 end
            end
        end
    end
    return r
end

-- La boîte des emplacements posés (px/py sont les champs que le client note
-- sur chaque bouton) et combien tombent dans la fenêtre courante.
local function boutons(canvas, vp)
    local minx, maxx, miny, maxy, dedans, total = nil, nil, nil, nil, 0, 0
    local z = canvas.echelle
    local w, h = vp:GetWidth() / z, vp:GetHeight() / z
    local ch = canvas:GetHeight()
    local x0, x1 = vp.hs, vp.hs + w
    local y0, y1 = ch - vp.vs - h, ch - vp.vs
    for _, o in ipairs(TOUS) do
        if o.genre == "Button" and o.parent == canvas and o.px then
            total = total + 1
            minx = math.min(minx or o.px, o.px); maxx = math.max(maxx or o.px, o.px)
            miny = math.min(miny or o.py, o.py); maxy = math.max(maxy or o.py, o.py)
            if o.px >= x0 and o.px <= x1 and o.py >= y0 and o.py <= y1 then dedans = dedans + 1 end
        end
    end
    return { minx = minx or 0, miny = miny or 0, maxx = maxx or 0, maxy = maxy or 0,
             dedans = dedans, total = total, x0 = x0, y0 = y0, x1 = x1, y1 = y1 }
end

-- ---------------------------------------------------------------------------
-- Scénario
-- ---------------------------------------------------------------------------
vraiPrint(fmt("== Banc éditeur : disposition « %s » ==", nom))
SRV.RequestSession(JOUEUR)
local f, vp, canvas = PAR_NOM.SpherierEditorFrame, PAR_NOM.SpherierEditorViewport, PAR_NOM.SpherierEditorCanvas
assert(f and vp and canvas, "cadres de l'éditeur introuvables")
vraiPrint(fmt("fenêtre %dx%d · vue %dx%d · canevas initial %dx%d",
    f:GetWidth(), f:GetHeight(), vp:GetWidth(), vp:GetHeight(), canvas:GetWidth(), canvas:GetHeight()))

local function etat(titre)
    local bm, bn = montres("Button", canvas)
    local tm, tn = montres("Texture", canvas)
    local b = boutons(canvas, vp)
    local z = canvas.echelle
    vraiPrint(fmt("-- %s", titre))
    vraiPrint(fmt("   canevas %dx%d · échelle %.2f · défilement h=%.0f v=%.0f (bornes %.0f, %.0f)",
        canvas:GetWidth(), canvas:GetHeight(), z, vp.hs, vp.vs,
        math.max(0, canvas:GetWidth() - vp:GetWidth() / z), math.max(0, canvas:GetHeight() - vp:GetHeight() / z)))
    vraiPrint(fmt("   fenêtre en px de canevas : x %.0f..%.0f, y %.0f..%.0f · emplacements posés : x %.0f..%.0f, y %.0f..%.0f",
        b.x0, b.x1, b.y0, b.y1, b.minx, b.maxx, b.miny, b.maxy))
    vraiPrint(fmt("   dans la fenêtre (compte indépendant) : %d / %d · boutons montrés %d / %d · textures du canevas montrées %d / %d",
        b.dedans, b.total, bm, bn, tm, tn))
    local fa = familles(canvas)
    vraiPrint(fmt("   montrés par famille : emplacements %d / %d · places vides %d / %d · repères %d / %d",
        fa.noeuds[1], fa.noeuds[2], fa.vides[1], fa.vides[2], fa.reperes[1], fa.reperes[2]))
    vraiPrint("   pied : " .. chaineContenant("rendus"))
end

razCompte()
local t0 = os.clock()
SRV.Load(JOUEUR, nom)
vraiPrint(fmt("chargement : %.0f ms de Lua · Show %d · Hide %d · SetPoint %d · ClearAllPoints %d · SetTexture %d · cadres créés %d · textures créées %d",
    (os.clock() - t0) * 1000, COMPTE.Show, COMPTE.Hide, COMPTE.SetPoint, COMPTE.ClearAllPoints,
    COMPTE.SetTexture, COMPTE.cadres, COMPTE.textures))
vraiPrint("   statut : " .. chaineContenant("chargée"))
etat("après chargement (ce que le jeu affiche)")

-- Les chemins d'icônes posés par SetTexture sur les emplacements : distincts,
-- et, si la racine du client est donnée (2e argument), existants sur le disque.
-- C'est ce contrôle qui manquait quand l'éditeur a demandé « rond_1.tga ».
do
    local racine = arg and arg[2]
    local vus, chemins = {}, {}
    for _, o in ipairs(TOUS) do
        if o.genre == "Button" and o.parent == canvas and o.node and o.icon and o.icon.chemin then
            local c = o.icon.chemin
            if not vus[c] then vus[c] = true; chemins[#chemins + 1] = c end
        end
    end
    table.sort(chemins)
    local manquants = {}
    if racine then
        for _, c in ipairs(chemins) do
            -- Nos textures vivent dans patch-z (jalon 7) : on vérifie leur SOURCE
            -- TGA dans outils_spherier\spherier_art ; le reste (icônes Blizzard)
            -- est dans les MPQ, hors de portée du banc.
            local nomArt = c:match("^Interface\\Papota\\SpherierArt\\(.+)$")
            if nomArt then
                local f = io.open("D:/Serveur WoW/outils_spherier/spherier_art/" .. nomArt .. ".tga", "rb")
                if f then f:close() else manquants[#manquants + 1] = c end
            end
        end
    end
    vraiPrint(fmt("   icônes : %d chemin(s) distinct(s)%s", #chemins,
        racine and fmt(", %d introuvable(s) dans les sources spherier_art (racine %s)", #manquants, racine) or " (racine du client non donnée : existence non vérifiée)"))
    for _, c in ipairs(manquants) do vraiPrint("      INTROUVABLE : " .. c) end
    if #chemins > 0 and #chemins <= 20 then
        for _, c in ipairs(chemins) do vraiPrint("      " .. c) end
    end
end

-- Un glissement de la caméra en `pas` images, comme la souris le ferait.
local function glisse(versH, versV, pas)
    local h0, v0 = vp.hs, vp.vs
    CURSEUR.x, CURSEUR.y = 0, 0
    vp.scripts.OnMouseDown(vp, "LeftButton")
    local k = canvas.echelle
    local pire, total, pireLua, totalLua = 0, 0, 0, 0
    for i = 1, pas do
        CURSEUR.x = -(versH - h0) * k * i / pas
        CURSEUR.y =  (versV - v0) * k * i / pas
        razCompte()
        local t = os.clock()
        vp.scripts.OnUpdate(vp)
        local dt = (os.clock() - t) * 1000
        local appels = COMPTE.Show + COMPTE.Hide + COMPTE.SetPoint + COMPTE.ClearAllPoints
        if appels > pire then pire = appels end
        total = total + appels
        if dt > pireLua then pireLua = dt end
        totalLua = totalLua + dt
    end
    razCompte()
    vp.scripts.OnMouseUp(vp, "LeftButton")
    vraiPrint(fmt("   glissement en %d images vers h=%.0f v=%.0f : appels moteur pire %d / moyen %.0f par image · Lua pire %.1f ms / moyen %.2f ms · relâchement : %d appels",
        pas, versH, versV, pire, total / pas, pireLua, totalLua / pas,
        COMPTE.Show + COMPTE.Hide + COMPTE.SetPoint + COMPTE.ClearAllPoints))
end

-- Des images au repos : l'habillage en fond travaille, rien d'autre.
local function repos(images)
    local t = os.clock()
    razCompte()
    for _ = 1, images do vp.scripts.OnUpdate(vp) end
    vraiPrint(fmt("   %d images au repos : %.0f ms de Lua · Show %d · Hide %d · SetPoint %d · ClearAllPoints %d · SetTexture %d",
        images, (os.clock() - t) * 1000, COMPTE.Show, COMPTE.Hide, COMPTE.SetPoint, COMPTE.ClearAllPoints, COMPTE.SetTexture))
end

local bh = math.max(0, canvas:GetWidth() - vp:GetWidth() / canvas.echelle)
local bv = math.max(0, canvas:GetHeight() - vp:GetHeight() / canvas.echelle)
glisse(bh / 2, bv / 2, 60)
etat("après glissement au vrai centre du canevas")

repos(400)
etat("après 400 images au repos (habillage en fond)")

glisse(bh / 2 + 600, bv / 2 + 400, 60)
etat("après un second glissement (+600, +400)")

for _ = 1, 7 do vp.scripts.OnMouseWheel(vp, -1) end
etat("après sept crans de zoom arrière : " .. chaineContenant("Zoom"))

for _ = 1, 10 do vp.scripts.OnMouseWheel(vp, 1) end
etat("après dix crans de zoom avant : " .. chaineContenant("Zoom"))
