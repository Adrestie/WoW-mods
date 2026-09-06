--[[----------------------------------------------------------------------------
    banc_joueur.lua — banc d'essai de l'INTERFACE JOUEUR du sphérier, hors jeu.

    Charge Spherier_Server.lua (pour lire la disposition) et
    Spherier_Joueur_Client.lua avec un AIO factice et le faux client WoW
    (faux_client.lua), fabrique le fil compact qu'enverrait Spherier_Joueur.lua
    pour une classe, l'affiche, puis simule glissements, zooms, un achat et un
    survol — en comptant boutons, textures et appels au moteur par image, et en
    vérifiant que ce qui est montré est exactement ce qui tombe dans la fenêtre.

    Usage, répertoire de travail = bin\RelWithDebInfo du serveur :
      python "D:\Serveur WoW\outils_spherier\lua51.py" banc_joueur.lua . [nom] [classe]
    (nom : disposition, « commune » par défaut ; classe : 1 par défaut)
------------------------------------------------------------------------------]]

local fmt = string.format
local nom = (arg and arg[1]) or "commune"
local CLASSE = tonumber(arg and arg[2]) or 1

local F = dofile("D:/Serveur WoW/outils_spherier/faux_client.lua")
local COMPTE, TOUS, PAR_NOM, CURSEUR, razCompte = F.COMPTE, F.TOUS, F.PAR_NOM, F.CURSEUR, F.razCompte

-- ---------------------------------------------------------------------------
-- AIO factice : les handlers par nom, les envois enregistrés
-- ---------------------------------------------------------------------------
local HANDLERS, APPELS = {}, {}
local JOUEUR = {}
AIO = {
    AddAddon = function() return false end,
    AddHandlers = function(nomAddon, t) HANDLERS[nomAddon] = t return t end,
    Handle = function(a, b, c, ...)
        if type(a) == "string" then
            APPELS[#APPELS + 1] = { vers = "serveur", addon = a, quoi = b, ... }
        else
            APPELS[#APPELS + 1] = { vers = "client", addon = b, quoi = c, ... }
        end
    end,
}
package.preload["AIO"] = function() return AIO end
function RegisterPlayerEvent() end

local vraiPrint = print
print = function() end
dofile("lua_scripts/Spherier/Spherier_Server.lua")
dofile("lua_scripts/Spherier/Spherier_Joueur_Client.lua")
print = vraiPrint
local SRV, CLI = HANDLERS.Spherier, HANDLERS.SpherierJoueur
assert(SRV and CLI, "handlers manquants")

local function Dernier(quoi)
    for i = #APPELS, 1, -1 do
        if APPELS[i].quoi == quoi then return APPELS[i] end
    end
end

-- ---------------------------------------------------------------------------
-- Le fil compact, tel que Spherier_Joueur.lua le fabriquerait pour CLASSE
-- ---------------------------------------------------------------------------
SRV.RequestSession(JOUEUR)
local session = assert(Dernier("ReceiveSession"), "pas de session")
local GEOMETRIE, STATS = session[1], session[2]
SRV.Load(JOUEUR, nom)
local charge = assert(Dernier("ReceiveLayout"), "disposition non chargée")
local clusters, nodes, edges, departs = charge[1], charge[2], charge[3], charge[6]
if type(departs) == "number" then departs = { [0] = departs } end

local cParId = {}
for _, c in ipairs(clusters) do cParId[c.id] = c end

local function Position(n)
    local c = cParId[n.cluster]
    if not c then return 0, 0 end
    if n.ring == 0 then return c.x, c.y end
    local r = GEOMETRIE.radii[n.ring] or 0
    local a = (c.rot or 0) + (n.branch - 1) * 2 * math.pi / GEOMETRIE.branches
    return c.x + r * math.cos(a), c.y + r * math.sin(a)
end

local NOEUD_BASE, OBJET_BASE = 803310, 803100
local MONTANTS_NOEUD, MONTANTS_OBJET = { 1, 2, 3, 5, 7 }, { 5, 7, 10, 15, 30 }
local function Entier(x) return math.floor(x * 10000 + 0.5) end

local fil = { v = "banc", n = {}, e = {}, c = {}, b = {}, pierres = {}, runes = {}, runesStat = {},
              iconeParStat = {}, epingle = 803300, classe = CLASSE, depart = departs[CLASSE] or departs[0] or 0 }
for i, st in ipairs(STATS) do
    fil.iconeParStat[st.key] = st.icon
    for q = 1, 5 do
        fil.pierres[NOEUD_BASE + (i - 1) * 5 + (q - 1)] = { stat = st.key, montant = MONTANTS_NOEUD[q], qualite = q }
        fil.pierres[OBJET_BASE + (i - 1) * 5 + (q - 1)] = { stat = st.key, montant = MONTANTS_OBJET[q], qualite = q }
    end
end
local visible, pierreDe, pos = {}, {}, {}
for _, n in ipairs(nodes) do
    local sort = 0
    if n.kind == 2 then
        sort = (n.sorts and n.sorts[CLASSE]) or ((n.sort or 0) > 0 and n.sort) or 0
    end
    if n.kind ~= 2 or sort > 0 then
        visible[n.id] = true
        local pierre = 0
        if n.kind == 0 and n.stat then
            pierre = NOEUD_BASE + (n.stat - 1) * 5 + ((n.quality or 1) - 1)
        end
        pierreDe[n.id] = pierre
        local x, y = Position(n)
        pos[n.id] = { x = x, y = y }
        fil.n[#fil.n + 1] = { n.id, n.kind, n.cluster, n.ring, n.branch, pierre, sort, Entier(x), Entier(y) }
    end
end
local adj = {}
for _, e in ipairs(edges) do
    if visible[e[1]] and visible[e[2]] then
        fil.e[#fil.e + 1] = e[1]
        fil.e[#fil.e + 1] = e[2]
        adj[e[1]] = adj[e[1]] or {}
        adj[e[2]] = adj[e[2]] or {}
        table.insert(adj[e[1]], e[2])
        table.insert(adj[e[2]], e[1])
    end
end
for _, c in ipairs(clusters) do
    fil.c[#fil.c + 1] = { c.id, Entier(c.x), Entier(c.y), Entier(c.rot or 0) }
end
fil.b[1], fil.b[2] = 0, 0
for i = 1, 253 do
    fil.b[#fil.b + 1] = i
    fil.b[#fil.b + 1] = 50 + i * 20
end

local depart = fil.depart
local etat = { brut = { [depart] = pierreDe[depart] or 0 }, requisOk = {}, nbActifs = 1,
               disponibles = 100000, prochainCout = 70 }

vraiPrint(fmt("== Banc joueur : « %s », classe %d — %d emplacements visibles sur %d, %d liaisons, départ %d ==",
    nom, CLASSE, #fil.n, #nodes, #fil.e / 2, depart))

-- ---------------------------------------------------------------------------
-- Sondes
-- ---------------------------------------------------------------------------
local f, vp, canvas

local function boutons()
    local crees, montres, hors = 0, 0, 0
    for _, o in ipairs(TOUS) do
        if o.genre == "Button" and o.parent == canvas then
            crees = crees + 1
            if o.montre then
                montres = montres + 1
                if not o.node then hors = hors + 1 end
            end
        end
    end
    return crees, montres, hors
end

local function textures()
    local total, montrees, etincelles = 0, 0, 0
    for _, o in ipairs(TOUS) do
        if o.genre == "Texture" and o.parent == canvas then
            total = total + 1
            if o.montre then
                montrees = montrees + 1
                if o.chemin and o.chemin:find("spark", 1, true) then etincelles = etincelles + 1 end
            end
        end
    end
    return total, montrees, etincelles
end

-- Ce qui DEVRAIT être montré : les emplacements dans la fenêtre plus la marge
-- de 160 px, calculés depuis nos propres données (même formule que le client).
local function attendus()
    local minx, maxx, miny, maxy
    for _, p in pairs(pos) do
        minx = math.min(minx or p.x, p.x); maxx = math.max(maxx or p.x, p.x)
        miny = math.min(miny or p.y, p.y); maxy = math.max(maxy or p.y, p.y)
    end
    local W, H = canvas:GetWidth(), canvas:GetHeight()
    local offsetX = (W - (maxx - minx) * 64) / 2 - 120
    local offsetY = (H - (maxy - miny) * 64) / 2 - 120
    local z = canvas.echelle
    local w, h = vp:GetWidth() / z, vp:GetHeight() / z
    local x0, x1 = vp.hs - 160, vp.hs + w + 160
    local y0, y1 = H - vp.vs - h - 160, H - vp.vs + 160
    local n = 0
    for _, p in pairs(pos) do
        local px = (p.x - minx) * 64 + 120 + offsetX
        local py = (p.y - miny) * 64 + 120 + offsetY
        if px >= x0 and px <= x1 and py >= y0 and py <= y1 then n = n + 1 end
    end
    return n
end

local function etat_(titre)
    local crees, montres, hors = boutons()
    local total, montrees, etincelles = textures()
    local att = attendus()
    vraiPrint(fmt("-- %s", titre))
    vraiPrint(fmt("   canevas %dx%d · échelle %.2f · défilement h=%.0f v=%.0f", canvas:GetWidth(), canvas:GetHeight(), canvas.echelle, vp.hs, vp.vs))
    vraiPrint(fmt("   boutons : %d créés, %d montrés (%d sans emplacement) · attendus dans la fenêtre+marge : %d%s",
        crees, montres, hors, att, (montres == att and hors == 0) and "  OK" or "  <-- ÉCART"))
    vraiPrint(fmt("   textures du canevas : %d créées, %d montrées dont %d étincelles", total, montrees, etincelles))
end

local function glisse(dh, dv, pas)
    local h0, v0 = vp.hs, vp.vs
    CURSEUR.x, CURSEUR.y = 0, 0
    vp.scripts.OnMouseDown(vp, "LeftButton")
    local k = canvas.echelle
    local pire, total, pireLua, totalLua = 0, 0, 0, 0
    for i = 1, pas do
        CURSEUR.x = -dh * k * i / pas
        CURSEUR.y =  dv * k * i / pas
        razCompte()
        local t = os.clock()
        vp.scripts.OnUpdate(vp)
        local dt = (os.clock() - t) * 1000
        local appels = COMPTE.Show + COMPTE.Hide + COMPTE.SetPoint + COMPTE.ClearAllPoints + COMPTE.SetTexture + COMPTE.SetTexCoord + COMPTE.SetVertexColor
        if appels > pire then pire = appels end
        total = total + appels
        if dt > pireLua then pireLua = dt end
        totalLua = totalLua + dt
    end
    vp.scripts.OnMouseUp(vp, "LeftButton")
    vraiPrint(fmt("   glissement (%+d, %+d) en %d images : appels moteur pire %d / moyen %.0f par image · Lua pire %.1f ms / moyen %.2f ms",
        dh, dv, pas, pire, total / pas, pireLua, totalLua / pas))
end

local function lignesRecap(texte)
    for _, o in ipairs(TOUS) do
        if o.genre == "FontString" and o.texte == texte and o.parent and o.parent.scripts.OnEnter then
            return o.parent
        end
    end
end

-- ---------------------------------------------------------------------------
-- Scénario
-- ---------------------------------------------------------------------------
razCompte()
local t0 = os.clock()
CLI.Catalogue(JOUEUR, fil)
CLI.Afficher(JOUEUR, fil, etat, "banc")
f, vp, canvas = PAR_NOM.SpherierJoueurFrame, PAR_NOM.SpherierJoueurViewport, PAR_NOM.SpherierJoueurCanvas
assert(f and vp and canvas, "cadres de l'interface introuvables")
vraiPrint(fmt("ouverture : %.0f ms de Lua · fenêtre %dx%d · vue %dx%d · cadres créés %d · textures créées %d",
    (os.clock() - t0) * 1000, f:GetWidth(), f:GetHeight(), vp:GetWidth(), vp:GetHeight(), COMPTE.cadres, COMPTE.textures))
etat_("après ouverture (centrée sur la grille)")

-- rouvrir sans nouvelle définition : seul l'état voyage
razCompte()
t0 = os.clock()
CLI.Afficher(JOUEUR, false, etat, "banc")
vraiPrint(fmt("réouverture (définition tenue) : %.0f ms de Lua · Show %d · Hide %d · SetPoint %d", (os.clock() - t0) * 1000, COMPTE.Show, COMPTE.Hide, COMPTE.SetPoint))

glisse(600, 400, 60)
etat_("après glissement (+600, +400)")

-- un achat : le départ et ses voisins deviennent actifs → étincelles
local etat2 = { brut = {}, requisOk = {}, nbActifs = 0, disponibles = 90000, prochainCout = 90 }
etat2.brut[depart] = pierreDe[depart] or 0
for _, v in ipairs(adj[depart] or {}) do
    etat2.brut[v] = pierreDe[v] or 0
    for _, w in ipairs(adj[v] or {}) do etat2.brut[w] = pierreDe[w] or 0 end
end
for _ in pairs(etat2.brut) do etat2.nbActifs = etat2.nbActifs + 1 end
-- revenir sur le départ pour voir les étincelles
local p = pos[depart]
razCompte()
t0 = os.clock()
CLI.MettreAJour(JOUEUR, etat2)
vraiPrint(fmt("achat (%d actifs) : %.0f ms de Lua · appels moteur %d", etat2.nbActifs,
    (os.clock() - t0) * 1000, COMPTE.Show + COMPTE.Hide + COMPTE.SetPoint + COMPTE.SetTexture + COMPTE.SetVertexColor))
glisse(-600, -400, 30)
etat_("retour sur le départ, après l'achat")

-- le contenu de COMPTE sur un nœud NON acheté : un voisin du départ vidé par
-- un autre personnage doit se montrer vide (bouchon), et un autre regarni doit
-- montrer la pierre sertie.
do
    -- deux nœuds à pierre parmi ceux AFFICHÉS, non achetés
    local proches = {}
    for _, o in ipairs(TOUS) do
        if #proches < 2 and o.genre == "Button" and o.parent == canvas and o.montre and o.node
           and o.node.kind == 0 and (pierreDe[o.node.id] or 0) > 0 and o.node.id ~= depart then
            proches[#proches + 1] = o.node.id
        end
    end
    local vide, garni = proches[1], proches[2]
    assert(vide and garni, "pas assez de nœuds à pierre affichés")
    local etat3 = { brut = { [depart] = pierreDe[depart] or 0 }, requisOk = {}, nbActifs = 1,
                    disponibles = 100000, prochainCout = 70,
                    contenuCompte = { [vide] = 0, [garni] = OBJET_BASE + 2 } }   -- Endurance rare (objet)
    CLI.MettreAJour(JOUEUR, etat3)
    local function bouton(id)
        for _, o in ipairs(TOUS) do
            if o.genre == "Button" and o.parent == canvas and o.montre and o.node and o.node.id == id then return o end
        end
    end
    local bv, bg = bouton(vide), bouton(garni)
    local function ou(id)
        local p = pos[id]
        return p and fmt("(grille %.1f, %.1f)", p.x, p.y) or "(position inconnue)"
    end
    if not bv then vraiPrint("   " .. vide .. " non montré " .. ou(vide) .. " — départ " .. ou(depart)) end
    if not bg then vraiPrint("   " .. garni .. " non montré " .. ou(garni)) end
    local cheminVide = bv and bv.icon and bv.icon.chemin or "?"
    local cheminGarni = bg and bg.icon and bg.icon.chemin or "?"
    vraiPrint(fmt("contenu de compte sur nœuds non achetés : %d vidé → icône %s%s · %d regarni → icône %s%s",
        vide, cheminVide, cheminVide == "Interface\\Buttons\\WHITE8X8" and "  OK" or "  <-- ÉCART",
        garni, cheminGarni, cheminGarni:find("rond_endurance", 1, true) and "  OK" or "  <-- ÉCART"))
    CLI.MettreAJour(JOUEUR, etat2)
end

-- survol d'une ligne de statistique
local ligne = lignesRecap("Endurance") or lignesRecap("Stamina")
if ligne then
    razCompte()
    t0 = os.clock()
    ligne.scripts.OnEnter(ligne)
    vraiPrint(fmt("survol « Endurance » : %.0f ms de Lua · appels moteur %d", (os.clock() - t0) * 1000,
        COMPTE.Show + COMPTE.Hide + COMPTE.SetPoint + COMPTE.SetTexture + COMPTE.SetVertexColor))
    ligne.scripts.OnLeave(ligne)
else
    vraiPrint("   (ligne Endurance introuvable dans la barre latérale)")
end

for _ = 1, 7 do vp.scripts.OnMouseWheel(vp, -1) end
etat_("après sept crans de zoom arrière")
glisse(800, 500, 60)
etat_("glissement dézoomé")
for _ = 1, 7 do vp.scripts.OnMouseWheel(vp, 1) end
etat_("retour au zoom 100 %")

local crees = boutons()
vraiPrint(fmt("réservoir : %d boutons créés en tout pour %d emplacements", crees, #fil.n))
