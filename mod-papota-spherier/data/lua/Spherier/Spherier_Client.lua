--[[----------------------------------------------------------------------------
    Sphèrier Papota — éditeur de disposition, côté client

    Expédié au client par AIO : rien à installer, rien à empaqueter.

    Trois outils :
      Sélection  clic sur un emplacement pour l'inspecter et le modifier ;
                 glisser le repère d'un cluster pour le déplacer ;
                 glisser le fond pour se déplacer dans la grille.
      Cluster    clic sur le vide pour poser un cluster ;
                 clic sur le repère d'un cluster pour le supprimer.
      Lier       clic sur deux emplacements pour créer ou retirer la liaison.

    Un cluster est fait de trois anneaux concentriques de huit emplacements,
    alignés en huit branches depuis le centre. Son contenu est tiré au hasard à
    la pose, puis modifiable emplacement par emplacement.

    L'enregistrement produit un XML lisible dans lua_scripts\Spherier\layouts\.
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- côté serveur : on s'arrête ici
end

local SpherierHandlers = AIO.AddHandlers("Spherier", {})

local sqrt, cos, sin, pi     = math.sqrt, math.cos, math.sin, math.pi
local floor, max, min, abs   = math.floor, math.max, math.min, math.abs
local random                 = math.random
local fmt                    = string.format

-- ---------------------------------------------------------------------------
-- Constantes de rendu
-- ---------------------------------------------------------------------------

-- Lua 5.1 (client WoW) : 60 upvalues au plus par fonction. Toutes les
-- constantes de rendu vivent donc dans UNE table - un seul upvalue.
local RC = {}

RC.SPACING    = 64       -- pixels par unité de grille
RC.NODE_SIZE  = 34
RC.EDGE_THICK = 11   -- style « conduit » : doit suivre EPAISSEURS du generateur
RC.MARGIN     = 120

-- Nœud (pierre) : assiette circulaire + anneau teinté à la couleur de qualité.
-- gradientCircle et ping4 sont des textures SANS alpha (blanc sur noir) : elles
-- ne fonctionnent qu'en fusion ADD, où le noir disparaît et le blanc se teinte
-- — c'est ce qui permet un anneau bleu ou violet, impossible avec les anneaux
-- dorés du client (multiplication des canaux : or × bleu ≈ noir).
RC.NODE_DISC_TEXTURE = "Interface\\GLUES\\MODELS\\UI_Tauren\\gradientCircle"
RC.NODE_RING_TEXTURE = "Interface\\Cooldown\\ping4"
RC.NODE_DISC_SIZE  = 78  -- cœur du dégradé ≈ 42 % de la texture → disque ≈ 33 px
RC.NODE_RING_SIZE  = 46  -- l'anneau de ping4 court à ≈ 94 % de sa texture, soit
                         -- un rayon de ≈ 21,6 : juste au-delà du cadre d'icône
RC.NODE_DISC_COLOR = { 0.05, 0.05, 0.06 }

-- Slot (rune) : la châsse de gemme de la fenêtre de sertissage, à l'identique.
-- Composition relevée dans Blizzard_ItemSocketingUI.xml (bouton de 40 px) :
-- creux ombré 72×74 + cadre 57×52 — la région générique « Socket » de la
-- planche, argentée, donc teintable pour les états de l'éditeur.
RC.SOCKET_SHEET        = "Interface\\ItemSocketingFrame\\UI-ItemSockets"
RC.SOCKET_HOLE_COORDS  = { 0.71875, 1, 0.7109375, 1 }
RC.SOCKET_FRAME_COORDS = { 0.171875, 0.3984375, 0.40234375, 0.609375 }
RC.SLOT_SCALE = 0.80     -- notre pas de grille est plus serré que le bouton Blizzard

-- L'icône d'un nœud REMPLIT le cercle : elle est découpée en rond par le
-- masque de portrait du moteur (SetPortraitToTexture), qui fait disparaître
-- les coins du carré. L'anneau étant un trait additif fin — pas un bord
-- couvrant —, le disque de l'icône doit rester en deçà : rayon 17 pour un
-- anneau à 18,8, le disque sombre comble le liseré entre les deux. Deux
-- pixels de moins que le cercle : le masque rogne ainsi la bordure blanche
-- que portent les icônes du jeu.
RC.ICON_SIZE_NODE = 34
RC.SNAP       = 0.25     -- pas de placement d'un cluster, en unités

RC.ZOOM_MIN, RC.ZOOM_MAX, RC.ZOOM_STEP = 0.30, 1.60, 0.10

RC.PANEL_W = 208

RC.KIND_NODE, RC.KIND_SLOT, RC.KIND_SORT = 0, 1, 2

-- Textures produites par outils_spherier\gen_textures_spherier.py et lues sur
-- le DISQUE du client (Interface\AddOns\SpherierArt\) — le 3.3.5 lit ce dossier
-- sans MPQ ni redémarrage. La ligne remplace UI-Taxi-Line, dont le cœur est
-- quasi noir (RGB 18, opaque) : teinté en gris, il donnait le trait sombre
-- visible au milieu de chaque segment. La texture de ligne doit toujours
-- comporter des marges TRANSPARENTES autour du trait : c'est ce qui permet à
-- la rotation par SetTexCoord de produire un segment oblique.
-- JALON 7 (2026-09-06) : les textures vivent dans patch-z, en BLP, sous un
-- chemin propre au MPQ ; les chemins se posent SANS extension.
RC.ART_DIR      = "Interface\\Papota\\SpherierArt\\"
RC.LINE_TEXTURE = RC.ART_DIR .. "line"
RC.LINEFACTOR_2 = (128 / 126) / 2

-- Arcs d'anneau cuits en texture : un fichier par rayon de cluster, l'arc de
-- 45° y est tracé une fois pour toutes — une liaison courbe devient UN quad
-- lisse au lieu d'une série de segments. Géométrie cuite : corde de 240 texels
-- entre (8,100) et (248,100) dans une image 256×128, bombée vers v décroissant.
RC.ARC_TEXTURES = { RC.ART_DIR .. "arc1", RC.ART_DIR .. "arc2", RC.ART_DIR .. "arc3" }

-- Cadre d'icône, technique du plugin Paragon (UIParagon.xml, ParagonStatItem) :
-- l'icône ronde en ARTWORK, et par-dessus, en OVERLAY, cet anneau du client —
-- centre transparent, bande opaque, extérieur transparent. C'est lui qui
-- recouvre le bord de l'icône, le masque du moteur n'étant pas réglable (et un
-- SetTexCoord posé après le détruirait). Anneau brun-doré RGB(113,99,71), rayon
-- intérieur à 0,636 du demi-côté : à 44 px il mord de 3 px sur une icône de 34.
RC.FRAME_SHEET  = "Interface\\Journeys\\JourneysFrame2x"
RC.FRAME_COORDS = { 0.762207, 0.814941, 0.124512, 0.177246 }
RC.FRAME_SIZE   = 44
RC.ARC_TEX_W, RC.ARC_TEX_H = 256, 128
RC.ARC_CHORD_U0, RC.ARC_CHORD_V, RC.ARC_CHORD_TEXELS = 8, 100, 240

-- Cinq qualités : commun, inhabituel, rare, épique, légendaire — alignées sur
-- les couleurs d'objet du client (blanc, vert, bleu, violet, orange).
RC.QUALITY_COLORS = {
    { 1.00, 1.00, 1.00 }, { 0.12, 1.00, 0.00 }, { 0.00, 0.44, 0.87 },
    { 0.64, 0.21, 0.93 }, { 1.00, 0.50, 0.00 },
}

RC.SLOT_COLOR    = { 0.31, 0.69, 0.89 }
-- Emplacement de sort : le cadre de sort du grimoire custom (NewSpellBook,
-- planche Interface\FrameXML\NewSpellBook\NewSpellbook\Spellbook-Parts,
-- régions relevées dans NewSpellBookFrame.xml) — assiette parchemin, icône
-- CARRÉE du sort, cadre orné de sarments : or (appris / édition), brun
-- (non appris). Référence Blizzard : bouton 37, cadre or 70x65 décalé de
-- +1.5, cadre brun 70x59 décalé de -3, assiette 43 — transposés ici pour
-- une icône de 30 (facteur 30/37).
RC.SORT_COLOR = { 1.00, 0.30, 0.85 }         -- couleur d'accent (infobulles)
RC.SB_SHEET       = "Interface\\FrameXML\\NewSpellBook\\NewSpellbook\\Spellbook-Parts"
RC.SB_FOND_COORDS = { 0.79296875, 0.9609375, 0.00390625, 0.171875 }
RC.SB_FOND_SIZE   = 35
RC.SB_OR_COORDS   = { 0.00390625, 0.27734375, 0.44140625, 0.6953125 }
RC.SB_OR_W, RC.SB_OR_H, RC.SB_OR_DX, RC.SB_OR_DY = 57, 53, 1.2, 0
RC.SB_BRUN_COORDS = { 0.00390625, 0.27734375, 0.703125, 0.93359375 }
RC.SB_BRUN_W, RC.SB_BRUN_H, RC.SB_BRUN_DX, RC.SB_BRUN_DY = 57, 48, 1.2, -2.4
RC.ICON_SIZE_SORT = 30    -- icône carrée, comme dans le grimoire
-- Nœud vide (sans pierre pré-allouée) : anneau gris, et le centre est bouché
-- par un disque sombre opaque (masque de portrait sur une texture unie) —
-- les liaisons ne doivent pas se voir au travers.
RC.EMPTY_NODE_COLOR = { 0.55, 0.55, 0.55 }
RC.PLUG_TEXTURE     = "Interface\\Buttons\\WHITE8X8"
RC.PLUG_COLOR       = { 0.07, 0.07, 0.08 }
-- Point de départ de la classe : second anneau doré, discret, autour de
-- l'emplacement marqué. Même texture additive que l'anneau de qualité.
RC.DEPART_COLOR     = { 1.00, 0.82, 0 }
RC.DEPART_RING_SIZE = 52
RC.EDGE_COLOR    = { 0.45, 0.45, 0.45, 1 }
RC.EDGE_ACTIVE   = { 0.20, 0.88, 0.96, 1 }   -- liaison dont les deux bouts sont achetés
RC.EDGE_OFF      = { 0.14, 0.14, 0.14, 1 }   -- liaison éteinte, en aperçu seulement
RC.SELECT_COLOR  = { 1.00, 1.00, 1.00 }
RC.PENDING_COLOR = { 1.00, 0.35, 0.35 }
-- LE ROUGE DU DEFAUT, plus franc que le saumon du lien en attente : les deux
-- se côtoient à l'écran et doivent se distinguer d'un coup d'œil.
RC.FAULT_COLOR   = { 1.00, 0.10, 0.10 }

-- ---------------------------------------------------------------------------
-- État
-- ---------------------------------------------------------------------------

local UI
-- Repli seulement : la géométrie qui fait foi est celle envoyée par le serveur.
local session = { geometry = { radii = { 1.1, 2.1, 3.1 }, branches = 8 },
                  stats = {}, qualites = {}, slotIcon = "", layouts = {}, sepMin = 0.7 }

-- doc.departs : classe → id de l'emplacement marqué point de départ. La clé 0
-- vaut « toutes classes » (grille de classe) ; la grille commune en porte un par
-- classe (1-9 et 11).
local doc = { clusters = {}, nodes = {}, edges = {}, nextCluster = 1, nextNode = 1, departs = {} }

-- Les classes de WotLK, dans l'ordre du client. Le 0 est l'ancienne marque
-- unique, gardée pour les feuilles de classe.
local CLASSES = {
    { 0, "toutes classes" }, { 1, "Guerrier" }, { 2, "Paladin" }, { 3, "Chasseur" },
    { 4, "Voleur" }, { 5, "Prêtre" }, { 6, "Chevalier de la mort" }, { 7, "Chaman" },
    { 8, "Mage" }, { 9, "Démoniste" }, { 11, "Druide" },
}
local classeDepart = 1          -- index dans CLASSES de la classe en cours

local function NomClasse(id)
    for _, c in ipairs(CLASSES) do
        if c[1] == id then return c[2] end
    end
    return "classe " .. tostring(id)
end

-- Les classes dont un emplacement est le départ (liste, souvent vide).
local function ClassesDepart(id)
    local t = {}
    for classe, d in pairs(doc.departs) do
        if d == id then t[#t + 1] = classe end
    end
    table.sort(t)
    return t
end

local function RetireDepart(id)
    for classe, d in pairs(doc.departs) do
        if d == id then doc.departs[classe] = nil end
    end
end

local tool        = "select"        -- select | cluster | link | preview

-- Emplacements marqués « achetés » dans l'aperçu. C'est un état de travail :
-- il ne décrit pas la disposition et n'est donc jamais écrit dans le XML.
local bought      = {}

local selNode     = nil
local selCluster  = nil
local linkPending = nil

-- Les emplacements que le DERNIER rapport a désignés comme fautifs. C'est un
-- état de travail, jamais écrit : il vaut jusqu'au rapport suivant. Éditer
-- entre-temps ne l'efface pas — comme tout contrôle, il dit ce qu'il a vu au
-- moment où il a regardé, et « Vérifier » le remet à jour.
local fautifs     = {}
local zoom        = 1
local bounds      = { minx = 0, miny = 0 }

-- ---------------------------------------------------------------------------
-- Modèle
-- ---------------------------------------------------------------------------

-- DES INDEX, PAS DES PARCOURS (2026-09-05). Ces deux recherches balayaient
-- toute la liste à chaque appel ; Rebuild appelle NodeById deux fois par
-- liaison et ClusterById six fois par emplacement — sur la grille commune,
-- SIX MILLIONS d'itérations par reconstruction, avant tout test de
-- visibilité. C'était cela qui ramait, et le rendu limité à la fenêtre n'y
-- pouvait rien. Les index se refont en tête de Rebuild (O(N)) ; entre deux
-- reconstructions, un identifiant absent de l'index retombe sur le parcours.
local indexNoeuds, indexClusters, indexPlaces = {}, {}, {}

-- La clé d'une place : cluster, anneau (0-3), branche (1-8).
local function ClePlace(clusterId, ring, branch)
    return clusterId * 100 + ring * 10 + branch
end

local function Reindexe()
    indexNoeuds, indexClusters, indexPlaces = {}, {}, {}
    for _, n in ipairs(doc.nodes) do
        indexNoeuds[n.id] = n
        indexPlaces[ClePlace(n.cluster, n.ring, n.branch)] = n
    end
    for _, c in ipairs(doc.clusters) do indexClusters[c.id] = c end
end

local function ClusterById(id)
    local c = indexClusters[id]
    if c then return c end
    for _, k in ipairs(doc.clusters) do
        if k.id == id then return k end
    end
end

local function NodeById(id)
    local n = indexNoeuds[id]
    if n then return n end
    for _, k in ipairs(doc.nodes) do
        if k.id == id then return k end
    end
end

-- Position d'une place du cluster, occupée ou non. Rien n'est stocké : tout se
-- déduit du cluster, de l'anneau et de la branche.
local function PosOf(clusterId, ring, branch)
    local c = ClusterById(clusterId)
    if not c then return 0, 0 end
    -- Anneau 0 : la place centrale du cluster (révision du 2026-08-23).
    local r = session.geometry.radii[ring]
    if not r then return c.x, c.y end
    local a = (c.rot or 0) + (branch - 1) * 2 * pi / session.geometry.branches
    return c.x + r * cos(a), c.y + r * sin(a)
end

local function NodePos(n)
    return PosOf(n.cluster, n.ring, n.branch)
end

local function NodeAt(clusterId, ring, branch)
    local n = indexPlaces[ClePlace(clusterId, ring, branch)]
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

-- Un slot est vide par définition : il attend une rune, il ne porte pas de
-- pierre. Passer un emplacement en slot doit donc effacer sa pierre, et non la
-- garder en sommeil.
local function MakeSlot(n)
    n.kind    = RC.KIND_SLOT
    n.stat    = nil
    n.quality = nil
    n.sort    = nil
    n.sorts   = nil
end

local function MakeNode(n)
    n.kind    = RC.KIND_NODE
    n.stat    = random(#session.stats)
    n.quality = random(#session.qualites)
    n.sort    = nil
    n.sorts   = nil
end

-- Emplacement de sort custom inédit : le sort est référencé par son
-- identifiant, saisi dans le panneau (0 = à définir).
local function MakeSort(n)
    n.kind    = RC.KIND_SORT
    n.stat    = nil
    n.quality = nil
    n.sort    = n.sort or 0
    n.sorts   = n.sorts or {}
end

-- SORTS PAR CLASSE (2026-09-05). Sur la grille commune, un emplacement de sort
-- est à tout le monde : chaque classe y apprend LE SIEN. `n.sorts` porte la
-- table classe → identifiant ; `n.sort` reste le repli « toutes classes ».
local function SortPour(n, classe)
    local s = n.sorts and n.sorts[classe]
    if s and s > 0 then return s end
    if n.sort and n.sort > 0 then return n.sort end
    return nil
end

-- Le sort qui représente l'emplacement à l'écran : le repli s'il existe,
-- sinon celui de la première classe servie.
local function SortAffiche(n)
    if n.sort and n.sort > 0 then return n.sort end
    for _, c in ipairs(CLASSES) do
        if c[1] ~= 0 and n.sorts and n.sorts[c[1]] then return n.sorts[c[1]] end
    end
    return 0
end

-- Combien de classes trouvent un sort ici, sur les dix.
local function ClassesServies(n)
    local nb, total = 0, 0
    for _, c in ipairs(CLASSES) do
        if c[1] ~= 0 then
            total = total + 1
            if SortPour(n, c[1]) then nb = nb + 1 end
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

    -- Liaisons internes par défaut : chaque anneau refermé sur lui-même, et les
    -- huit branches reliées d'un anneau au suivant. Elles sont ordinaires et se
    -- suppriment comme les autres.
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

    Reindexe()
    return c
end

-- Retirer un emplacement laisse un trou dans le cluster : la place existe
-- toujours, elle est seulement vide. C'est ce qui permet de la rétablir plus
-- tard sans avoir à refaire le cluster.
local function RemoveNode(id)
    local keep = {}
    for _, n in ipairs(doc.nodes) do
        if n.id ~= id then keep[#keep + 1] = n end
    end
    doc.nodes = keep
    Reindexe()

    local keepEdges = {}
    for _, e in ipairs(doc.edges) do
        if e[1] ~= id and e[2] ~= id then keepEdges[#keepEdges + 1] = e end
    end
    doc.edges = keepEdges

    if selNode == id then selNode = nil end
    if linkPending == id then linkPending = nil end
    RetireDepart(id)
    bought[id] = nil
end

-- Rétablissement d'une place vide. Le nouvel emplacement est relié à ses
-- voisins immédiats du cluster — les deux de son anneau, et ceux des anneaux
-- adjacents sur la même branche — pour éviter d'avoir à les recréer à la main.
local function AddNodeAt(clusterId, ring, branch)
    if NodeAt(clusterId, ring, branch) then return end

    local n = { id = doc.nextNode, cluster = clusterId, ring = ring, branch = branch }
    doc.nextNode = doc.nextNode + 1
    RandomContent(n)
    doc.nodes[#doc.nodes + 1] = n
    Reindexe()

    -- Construction sans trou : un voisin absent (place vide) ne doit pas
    -- interrompre le parcours des suivants.
    local B = session.geometry.branches
    local neighbours = {}
    local function voisin(r, b)
        local nb = NodeAt(clusterId, r, b)
        if nb then neighbours[#neighbours + 1] = nb end
    end
    if ring == 0 then
        -- La place centrale : reliée par défaut à tout le premier anneau.
        for b = 1, B do voisin(1, b) end
    else
        voisin(ring, branch % B + 1)
        voisin(ring, (branch - 2) % B + 1)
        voisin(ring - 1, branch)
        voisin(ring + 1, branch)
        -- L'anneau intérieur touche aussi la place centrale (branche unique 1).
        if ring == 1 then voisin(0, 1) end
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
    Reindexe()

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
    for classe, d in pairs(doc.departs) do
        if dropped[d] then doc.departs[classe] = nil end
    end
end

-- ---------------------------------------------------------------------------
-- Tracé d'un segment d'angle quelconque
-- ---------------------------------------------------------------------------
-- Le client 3.3.5 n'a pas de primitive de ligne : CreateLine n'apparaît qu'avec
-- Legion. On emploie la méthode des routes aériennes de Blizzard, reprise
-- depuis par LibGraph : les quatre coins d'un rectangle aligné sur les axes
-- reçoivent des coordonnées de texture pivotées, de sorte que le trait dessiné
-- DANS la texture apparaisse oblique.

local function AcquireLine(canvas, pool, col, layer, tex)
    local t = table.remove(pool.free)
    if not t then t = canvas:CreateTexture(nil, "ARTWORK") end
    t:SetTexture(tex or RC.LINE_TEXTURE)
    -- La couche est repositionnée à chaque prise : une texture rendue au
    -- réservoir peut resservir à n'importe quelle liaison.
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

-- Arc de cercle entre deux emplacements voisins d'un même anneau : un seul
-- quad, la courbe étant cuite dans la texture de l'anneau concerné. Le quad
-- posé est le rectangle englobant de l'image tournée ; les coordonnées de
-- texture appliquent la rotation inverse, et l'échantillonnage qui sort de
-- l'image retombe sur ses bords transparents (mode CLAMP du client).
local function DrawClusterArc(canvas, pool, ax, ay, bx, by, ccx, ccy, ring, col)
    local tex = RC.ARC_TEXTURES[ring]
    if not tex then return end

    local dx, dy = bx - ax, by - ay
    local L = sqrt(dx * dx + dy * dy)
    if L == 0 then return end
    local ux, uy = dx / L, dy / L
    local s = L / RC.ARC_CHORD_TEXELS          -- pixels écran par texel

    -- Normale sortante : du centre du cluster vers le milieu de la corde.
    local nx, ny = (ax + bx) / 2 - ccx, (ay + by) / 2 - ccy
    local nl = sqrt(nx * nx + ny * ny)
    if nl == 0 then nx, ny = -uy, ux else nx, ny = nx / nl, ny / nl end

    -- Un texel (tu,tv) s'affiche en A + û·(tu-U0)·s + n̂·(V-tv)·s.
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

    -- Transformation inverse, pour les coins du rectangle englobant.
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
    if n.kind == RC.KIND_SORT then
        -- Blanc : le cadre du grimoire garde son or naturel ; les états
        -- (sélection, lien en attente, aperçu) la teintent par-dessus.
        return 1, 1, 1
    end
    if not n.stat then
        return RC.EMPTY_NODE_COLOR[1], RC.EMPTY_NODE_COLOR[2], RC.EMPTY_NODE_COLOR[3]
    end
    local q = RC.QUALITY_COLORS[n.quality or 1] or RC.QUALITY_COLORS[1]
    return q[1], q[2], q[3]
end

-- Habille le cadre d'un emplacement de sort : or (appris / édition) ou brun
-- (non appris) — géométrie de NewSpellBookFrame.xml, transposée.
local function HabillerCadreSort(btn, dore, r, g, b)
    local cadre = btn.sbCadre
    if dore then
        cadre:SetTexCoord(RC.SB_OR_COORDS[1], RC.SB_OR_COORDS[2],
            RC.SB_OR_COORDS[3], RC.SB_OR_COORDS[4])
        cadre:SetWidth(RC.SB_OR_W)
        cadre:SetHeight(RC.SB_OR_H)
        cadre:ClearAllPoints()
        cadre:SetPoint("CENTER", RC.SB_OR_DX, RC.SB_OR_DY)
    else
        cadre:SetTexCoord(RC.SB_BRUN_COORDS[1], RC.SB_BRUN_COORDS[2],
            RC.SB_BRUN_COORDS[3], RC.SB_BRUN_COORDS[4])
        cadre:SetWidth(RC.SB_BRUN_W)
        cadre:SetHeight(RC.SB_BRUN_H)
        cadre:ClearAllPoints()
        cadre:SetPoint("CENTER", RC.SB_BRUN_DX, RC.SB_BRUN_DY)
    end
    cadre:SetVertexColor(r, g, b)
    btn.sbFond:SetVertexColor(r, g, b)
    btn.sbFond:Show()
    cadre:Show()
end

local function ShowNodeTooltip(btn, n)
    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    if n.kind == RC.KIND_SLOT then
        GameTooltip:SetText("Slot", 0.31, 0.69, 0.89)
        GameTooltip:AddLine("N'accueille que des runes.", 0.8, 0.8, 0.8, true)
    elseif n.kind == RC.KIND_SORT then
        GameTooltip:SetText("Sort", RC.SORT_COLOR[1], RC.SORT_COLOR[2], RC.SORT_COLOR[3])
        -- Un sort par classe : la liste dit qui apprend quoi ici.
        for _, c in ipairs(CLASSES) do
            if c[1] ~= 0 then
                local id = SortPour(n, c[1])
                if id then
                    local nom = GetSpellInfo(id)
                    GameTooltip:AddLine(fmt("%s : %s (n°%d)", c[2], nom or "?", id), 1, 1, 1, true)
                else
                    -- Sans sort, l'emplacement n'existe pas pour cette classe.
                    GameTooltip:AddLine(fmt("%s : invisible (aucun sort)", c[2]), 0.55, 0.55, 0.55, true)
                end
            end
        end
        if n.sort and n.sort > 0 then
            GameTooltip:AddLine(fmt("Repli toutes classes : n°%d", n.sort), 0.6, 0.6, 0.6, true)
        end
        GameTooltip:AddLine("Chaque classe apprend son sort à l'activation ; sans sort, elle ne voit ni l'emplacement ni ses liaisons.",
            0.8, 0.8, 0.8, true)
    elseif not n.stat then
        GameTooltip:SetText("Nœud vide", RC.EMPTY_NODE_COLOR[1], RC.EMPTY_NODE_COLOR[2], RC.EMPTY_NODE_COLOR[3])
        GameTooltip:AddLine("Sans pierre pré-allouée : recevra une pierre sertie en jeu.",
            0.8, 0.8, 0.8, true)
    else
        local s = session.stats[n.stat]
        local q = RC.QUALITY_COLORS[n.quality or 1] or RC.QUALITY_COLORS[1]
        local qual = session.qualites[n.quality or 1]
        GameTooltip:SetText("Nœud", 1, 1, 1)
        GameTooltip:AddLine(fmt("Pierre %s", qual and qual.label or "?"),
            q[1], q[2], q[3], true)
        GameTooltip:AddLine(fmt("+%d %s", qual and qual.bonus or 0, s and s.label or "?"),
            0.1, 1, 0.1, true)
    end
    local cd = ClassesDepart(n.id)
    if #cd > 0 then
        local noms = {}
        for _, c in ipairs(cd) do noms[#noms + 1] = NomClasse(c) end
        GameTooltip:AddLine("Point de départ : " .. table.concat(noms, ", "), 1, 0.82, 0, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(fmt("n°%d · cluster %d · anneau %d · branche %d",
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
            SetStatus("Aperçu remis à zéro.")
        else
            bought[n.id] = (not bought[n.id]) or nil
        end
        Rebuild()
        return
    end

    if tool == "link" then
        -- Clic droit : couper d'un coup toutes les liaisons de l'emplacement.
        -- Sans cela, défaire les liaisons internes d'un cluster demanderait
        -- quarante paires de clics.
        if button == "RightButton" then
            local cut = CutAllLinks(n.id)
            linkPending = nil
            SetStatus(cut > 0
                and fmt("Emplacement %d : %d liaison(s) coupée(s).", n.id, cut)
                or fmt("Emplacement %d n'avait aucune liaison.", n.id))
            Rebuild()
            return
        end

        if not linkPending then
            linkPending = n.id
            SetStatus(fmt("Emplacement %d retenu (%d liaison(s)). Cliquez le second pour lier ou délier.",
                n.id, CountLinks(n.id)))
        elseif linkPending == n.id then
            linkPending = nil
            SetStatus("Sélection annulée.")
        else
            local i = FindEdge(linkPending, n.id)
            if i then
                table.remove(doc.edges, i)
                SetStatus(fmt("Liaison %d — %d retirée.", linkPending, n.id))
            else
                doc.edges[#doc.edges + 1] = { linkPending, n.id }
                SetStatus(fmt("Liaison %d — %d créée.", linkPending, n.id))
            end
            linkPending = nil
        end
    elseif button == "RightButton" then
        local id = n.id
        RemoveNode(id)
        SetStatus(fmt("Emplacement %d retiré. Sa place reste disponible : cliquez-la pour le rétablir.", id))
    else
        selNode    = n.id
        selCluster = n.cluster
    end
    Rebuild()
end

-- LE RECTANGLE VISIBLE, en pixels du canevas (2026-09-05). Avec la grille
-- commune — 2 442 emplacements, 2 485 liaisons — habiller chaque emplacement
-- et tracer chaque liaison à chaque reconstruction mettait le client à genoux.
-- On ne rend donc que ce qui tombe dans la fenêtre, avec une marge : le reste
-- est masqué, et on reconstruit quand la fenêtre a bougé d'assez.
--
-- Le défilement d'un ScrollFrame se compte dans SES unités ; l'enfant est mis
-- à l'échelle par le zoom : un pixel de canevas vaut `zoom` pixels de fenêtre.
-- L'axe y du canevas MONTE (les emplacements s'ancrent en bas à gauche), celui
-- du défilement descend : d'où le retournement sur la hauteur du canevas.
local CULL_MARGE = 160

local function RectVisible()
    -- Sans filtre : tout est visible, tout s'habille à la reconstruction. C'est
    -- l'interrupteur de comparaison du pied de fenêtre.
    if UI.sansFiltre then
        return -math.huge, -math.huge, math.huge, math.huge
    end
    local vp, canvas = UI.viewport, UI.canvas
    local z = zoom > 0 and zoom or 1
    local w, h = vp:GetWidth() / z, vp:GetHeight() / z
    -- Fenêtre sans taille encore (première image après création) : tout est
    -- visible, plutôt que rien.
    if w < 1 or h < 1 then
        return -math.huge, -math.huge, math.huge, math.huge
    end
    -- LE DÉCALAGE DE DÉFILEMENT EST DÉJÀ EN PIXELS DU CANEVAS (établi
    -- empiriquement dans l'interface joueur : sans diviser le geste de la
    -- souris par le zoom, le contenu file plus vite que la main). Seule la
    -- taille de la fenêtre se convertit.
    local sx, sy = vp:GetHorizontalScroll(), vp:GetVerticalScroll()
    local ch = canvas:GetHeight()
    return sx - CULL_MARGE, ch - sy - h - CULL_MARGE,
           sx + w + CULL_MARGE, ch - sy + CULL_MARGE
end

local function Dedans(rect, x, y)
    return x >= rect[1] and x <= rect[3] and y >= rect[2] and y <= rect[4]
end

-- L'HABILLAGE D'UN EMPLACEMENT, à part (2026-09-05). Reconstruire et filtrer
-- sont deux opérations : la reconstruction place et habille, rarement ; le
-- filtre montre ou masque à chaque mouvement, et n'habille qu'un emplacement
-- qui entre dans la fenêtre pour la première fois depuis la dernière
-- reconstruction (`btn.styled`).
local function StyleNode(btn, n, x, y)
    local canvas = UI.canvas
    btn:ClearAllPoints()
    btn:SetPoint("CENTER", canvas, "BOTTOMLEFT", x, y)

    -- Couleur d'état : qualité de la pierre pour l'anneau d'un nœud ;
    -- blanc sélection, rouge lien en attente, gris éteint en aperçu.
    local r, g, b = NodeBorderColor(n)
    if tool == "preview" then
        if not bought[n.id] then r, g, b = 0.12, 0.12, 0.12 end
    elseif linkPending == n.id then
        r, g, b = RC.PENDING_COLOR[1], RC.PENDING_COLOR[2], RC.PENDING_COLOR[3]
    elseif selNode == n.id then
        r, g, b = RC.SELECT_COLOR[1], RC.SELECT_COLOR[2], RC.SELECT_COLOR[3]
    elseif fautifs[n.id] then
        r, g, b = RC.FAULT_COLOR[1], RC.FAULT_COLOR[2], RC.FAULT_COLOR[3]
    end

    -- En aperçu, ce qui n'est pas acheté s'efface, pour que le chemin
    -- parcouru se lise d'un coup d'œil. Dans les outils d'édition tout
    -- reste pleinement visible, sans quoi on éditerait à l'aveugle.
    local dim  = (tool == "preview" and not bought[n.id])
    local tint = dim and 0.15 or 1

    if n.kind == RC.KIND_SLOT then
        -- Un slot est une châsse vide : creux et cadre, pas d'icône.
        btn.disc:Hide()
        btn.ring:Hide()
        btn.icon:Hide()
        btn.iconRim:Hide()
        btn.sbFond:Hide()
        btn.sbCadre:Hide()
        btn.hole:Show()
        btn.socket:Show()

        -- La châsse reste argentée au repos — sa forme suffit à dire
        -- « rune ». Elle ne se teinte que pour signaler un état.
        local sr, sg, sb = 1, 1, 1
        if tool == "preview" then
            if not bought[n.id] then sr, sg, sb = 0.12, 0.12, 0.12 end
        elseif linkPending == n.id then
            sr, sg, sb = RC.PENDING_COLOR[1], RC.PENDING_COLOR[2], RC.PENDING_COLOR[3]
        elseif selNode == n.id then
            sr, sg, sb = 1, 0.82, 0
        elseif fautifs[n.id] then
            sr, sg, sb = RC.FAULT_COLOR[1], RC.FAULT_COLOR[2], RC.FAULT_COLOR[3]
        end
        btn.socket:SetVertexColor(sr, sg, sb)
        btn.hole:SetAlpha(dim and 0.20 or 1)
    else
        btn.hole:Hide()
        btn.socket:Hide()

        -- Icône : ronde (masque de portrait) pour les pierres, CARRÉE pour
        -- les sorts — le cadre du grimoire encadre un carré. Un nœud vide
        -- reçoit un disque opaque sombre découpé rond : les liaisons ne se
        -- voient pas au travers. Le masque est coûteux : on ne refait
        -- l'icône que si le chemin OU le mode change.
        local path, plug, carre
        if n.kind == RC.KIND_SORT then
            local _, _, icone = GetSpellInfo(SortAffiche(n))
            path, carre = icone or "Interface\\Icons\\INV_Misc_QuestionMark", true
        elseif n.stat then
            -- L'ICÔNE RONDE EST CUITE EN FICHIER (gen_icones_rondes.py) : plus de
            -- SetPortraitToTexture au vol — c'était un masque par bouton, et les
            -- à-coups du premier passage. Carrée pour le moteur : l'alpha fait le rond.
            -- n.stat est ici un INDEX dans session.stats (STAT_BY_KEY côté serveur),
            -- l'interface joueur reçoit la clé : le fichier porte la CLÉ.
            local sDef = session.stats[n.stat]
            path, carre = RC.ART_DIR .. "rond_" .. ((sDef and sDef.key) or tostring(n.stat)), true
        else
            path, plug = RC.PLUG_TEXTURE, true
        end

        btn.icon:Show()
        local mode = carre and "carre" or "rond"
        if btn.iconPath ~= path or btn.iconMode ~= mode then
            btn.iconPath, btn.iconMode = path, mode
            if carre or not SetPortraitToTexture then
                -- Diagnostic (2026-09-05) : SetTexture renvoie 1 si le client a
                -- trouve le fichier, nil sinon ; l'infobulle du noeud le montre.
                btn.iconOk = btn.icon:SetTexture(path)
                btn.icon:SetTexCoord(0, 1, 0, 1)
            else
                btn.iconOk = "portrait"
                -- Ne JAMAIS appeler SetTexCoord ensuite : le moteur perd
                -- alors son masque circulaire et l'icône redevient carrée.
                SetPortraitToTexture(btn.icon, path)
            end
        end
        btn.icon:SetAlpha(1)
        btn.iconPlug = plug

        if n.kind == RC.KIND_SORT then
            -- Le cadre du grimoire remplace entièrement le cercle. En
            -- Aperçu, le cadre brun « non appris » raconte l'état.
            btn.disc:Hide()
            btn.ring:Hide()
            btn.iconRim:Hide()
            btn.icon:SetWidth(RC.ICON_SIZE_SORT)
            btn.icon:SetHeight(RC.ICON_SIZE_SORT)
            HabillerCadreSort(btn, tool ~= "preview" or bought[n.id], r, g, b)
        else
            btn.disc:Show()
            btn.ring:Show()
            btn.iconRim:Show()
            btn.iconRim:SetVertexColor(tint, tint, tint)
            btn.icon:SetWidth(RC.ICON_SIZE_NODE)
            btn.icon:SetHeight(RC.ICON_SIZE_NODE)
            btn.ring:SetVertexColor(r, g, b)
            btn.sbFond:Hide()
            btn.sbCadre:Hide()
        end
    end

    if btn.iconPlug then
        btn.icon:SetVertexColor(RC.PLUG_COLOR[1], RC.PLUG_COLOR[2], RC.PLUG_COLOR[3])
    else
        btn.icon:SetVertexColor(tint, tint, tint)
    end
    if #ClassesDepart(n.id) > 0 then btn.departRing:Show() else btn.departRing:Hide() end
    btn:Show()
    btn.styled, btn.visible = true, true
end

-- LE FILTRE : montrer ou masquer selon la fenêtre, à partir des positions
-- mémorisées par la dernière reconstruction. Assez bon marché pour tourner à
-- chaque image pendant un glissement : quelques milliers de comparaisons et
-- une poignée de Show/Hide — ceux dont l'état change.
-- Où en était la fenêtre au dernier filtre : rien à faire si elle n'a pas bougé.
local dernierFiltre = { h = nil, v = nil, z = nil }

-- LE DÉCOUPAGE SPATIAL (2026-09-05). Le filtre parcourait TOUS les emplacements
-- et TOUTES les liaisons à chaque image de glissement — cinq mille itérations,
-- visibles ou non, et une table allouée au passage. À 160 % de zoom, vingt
-- emplacements à l'écran et pourtant des micro-gels. On range donc tout dans
-- des cases de CASE px à la reconstruction, et l'on ne parcourt que les cases
-- que la fenêtre touche, plus ce qui était montré et doit disparaître.
local CASE = 256
local visActuel = { 0, 0, 0, 0 }         -- réutilisé : rien d'alloué par image
local montresN, montresE = {}, {}         -- ce qui est montré : indices / items
local nouveauxN, nouveauxE = {}, {}       -- tampons du filtre, réutilisés
-- Les « autres » : places vides et repères de cluster. Un fond à neuf textures
-- chacun, et 886 d'entre eux montrés en permanence sur la grille commune.
local montresA, nouveauxA = {}, {}
local perf = { max = 0, depuis = 0 }

local function CleCase(x, y)
    return floor(x / CASE) * 65536 + floor(y / CASE)
end

-- Appelé en fin de reconstruction : les cases, et l'état montré de départ.
local function RangeEnCases()
    local cases = {}
    for i, _ in ipairs(doc.nodes) do
        local btn = UI.nodeButtons[i]
        if btn and btn.px then
            local k = CleCase(btn.px, btn.py)
            local c = cases[k]
            if not c then c = { n = {}, e = {}, a = {} } cases[k] = c end
            c.n[#c.n + 1] = i
        end
    end
    for _, it in ipairs(UI.autres) do
        local k = CleCase(it.px, it.py)
        local c = cases[k]
        if not c then c = { n = {}, e = {}, a = {} } cases[k] = c end
        c.a[#c.a + 1] = it
    end
    for _, it in ipairs(UI.edgeItems) do
        -- une liaison va dans chaque case que sa boîte touche
        for cx = floor(it.x0 / CASE), floor(it.x1 / CASE) do
            for cy = floor(it.y0 / CASE), floor(it.y1 / CASE) do
                local k = cx * 65536 + cy
                local c = cases[k]
                if not c then c = { n = {}, e = {}, a = {} } cases[k] = c end
                c.e[#c.e + 1] = it
            end
        end
    end
    UI.cases = cases
    for k in pairs(montresN) do montresN[k] = nil end
    for k in pairs(montresE) do montresE[k] = nil end
    for i, _ in ipairs(doc.nodes) do
        local btn = UI.nodeButtons[i]
        if btn and btn.visible then montresN[i] = true end
    end
    for _, it in ipairs(UI.edgeItems) do
        if it.visible then montresE[it] = true end
    end
    for k in pairs(montresA) do montresA[k] = nil end
    for _, it in ipairs(UI.autres) do
        if it.visible then montresA[it] = true end
    end
end

local function Cull(force)
    if not UI or not UI.cases then return end
    local vp = UI.viewport
    local h, v = vp:GetHorizontalScroll(), vp:GetVerticalScroll()
    if not force and h == dernierFiltre.h and v == dernierFiltre.v and zoom == dernierFiltre.z then
        return
    end
    dernierFiltre.h, dernierFiltre.v, dernierFiltre.z = h, v, zoom
    local t0 = debugprofilestop()

    local vis = visActuel
    vis[1], vis[2], vis[3], vis[4] = RectVisible()
    UI.visActuel = vis
    local rendus, traces = 0, 0

    -- Les cases touchées par la fenêtre (bornées : la fenêtre « infinie » du
    -- mode sans filtre parcourt simplement toutes les cases).
    for k in pairs(nouveauxN) do nouveauxN[k] = nil end
    for k in pairs(nouveauxE) do nouveauxE[k] = nil end
    for k in pairs(nouveauxA) do nouveauxA[k] = nil end
    local cases = UI.cases
    local function visite(c)
        for _, i in ipairs(c.n) do
            local btn = UI.nodeButtons[i]
            if btn and btn.px and Dedans(vis, btn.px, btn.py) then
                if not btn.styled then
                    StyleNode(btn, doc.nodes[i], btn.px, btn.py)
                elseif not btn.visible then
                    btn:SetPoint("CENTER", UI.canvas, "BOTTOMLEFT", btn.px, btn.py)
                    btn:Show()
                    btn.visible = true
                end
                nouveauxN[i] = true
                rendus = rendus + 1
            end
        end
        for _, it in ipairs(c.e) do
            if not nouveauxE[it]
               and not (it.x1 < vis[1] or it.x0 > vis[3] or it.y1 < vis[2] or it.y0 > vis[4]) then
                if not it.visible then
                    it.tex:SetPoint(it.a1[1], it.a1[2], it.a1[3], it.a1[4], it.a1[5])
                    it.tex:SetPoint(it.a2[1], it.a2[2], it.a2[3], it.a2[4], it.a2[5])
                    it.tex:Show()
                    it.visible = true
                end
                nouveauxE[it] = true
                traces = traces + 1
            end
        end
        for _, it in ipairs(c.a) do
            if Dedans(vis, it.px, it.py) then
                if not it.visible then
                    it.f:Show()
                    it.visible = true
                end
                nouveauxA[it] = true
            end
        end
    end
    if vis[1] == -math.huge then
        for _, c in pairs(cases) do visite(c) end
    else
        for cx = floor(vis[1] / CASE), floor(vis[3] / CASE) do
            for cy = floor(vis[2] / CASE), floor(vis[4] / CASE) do
                local c = cases[cx * 65536 + cy]
                if c then visite(c) end
            end
        end
    end

    -- Ce qui était montré et ne l'est plus.
    for i in pairs(montresN) do
        if not nouveauxN[i] then
            local btn = UI.nodeButtons[i]
            if btn and btn.visible then
                btn:Hide()
                btn:ClearAllPoints()            -- détaché : plus de recalcul moteur
                btn.visible = false
            end
        end
    end
    for it in pairs(montresE) do
        if not nouveauxE[it] and it.visible then
            it.tex:Hide()
            it.tex:ClearAllPoints()
            it.visible = false
        end
    end
    -- Le repère d'un cluster en cours de glissement n'est jamais masqué :
    -- masquer un cadre qu'on glisse annule le glissement.
    for it in pairs(montresA) do
        if not nouveauxA[it] and it.visible and not it.fixe then
            it.f:Hide()
            it.visible = false
        end
    end
    -- On échange les deux jeux : l'ancien devient le tampon du prochain passage.
    montresN, nouveauxN = nouveauxN, montresN
    montresE, nouveauxE = nouveauxE, montresE
    montresA, nouveauxA = nouveauxA, montresA

    if UI.rendusLabel and (rendus ~= UI.rendus or traces ~= UI.traces) then
        UI.rendusLabel:SetText(fmt("%d rendus, %d tracées", rendus, traces))
    end
    UI.rendus, UI.traces = rendus, traces
    -- La mesure : le pire filtre de la dernière demi-seconde, affiché au pied.
    local dt = debugprofilestop() - t0
    if dt > perf.max then perf.max = dt end
    local maintenant = GetTime()
    if maintenant - perf.depuis > 0.5 then
        if UI.perfLabel then
            UI.perfLabel:SetText(fmt("filtre %.1f ms", perf.max))
        end
        perf.max, perf.depuis = 0, maintenant
    end
end

-- L'HABILLAGE EN TÂCHE DE FOND (2026-09-05). Habiller un emplacement coûte
-- cher — textures, coordonnées, couleurs — et le faire à l'entrée dans la
-- fenêtre produisait des à-coups à chaque glissement vers du neuf. Après une
-- reconstruction, on habille donc TOUT, par tranches de quelques emplacements
-- par image, en partant du plus proche de la fenêtre : la grille entière est
-- prête en deux ou trois secondes, et plus rien n'est habillé en glissant.
-- LE COÛT RÉEL EST LE MASQUE ROND : SetPortraitToTexture fabrique une texture
-- par bouton la première fois, et le client charge chaque icône du disque à sa
-- première apparition. Seize par image, c'était encore trop d'un coup. On
-- habille donc sous un BUDGET DE TEMPS par image (debugprofilestop, en ms), au
-- moins un, jamais plus de STYLE_PAR_IMAGE_MAX.
local STYLE_BUDGET_MS = 2.5
local STYLE_PAR_IMAGE_MAX = 48

local function HabilleEnFond()
    local file = UI and UI.aStyler
    if not file or #file == 0 then return end
    local fait = 0
    local t0 = debugprofilestop()
    while #file > 0 and fait < STYLE_PAR_IMAGE_MAX
          and (fait == 0 or debugprofilestop() - t0 < STYLE_BUDGET_MS) do
        local i = table.remove(file)
        local btn, n = UI.nodeButtons[i], doc.nodes[i]
        if btn and n and btn.px and not btn.styled then
            StyleNode(btn, n, btn.px, btn.py)
            -- Habillé mais hors fenêtre : on le remasque aussitôt.
            local vis = UI.visActuel
            if vis and not Dedans(vis, btn.px, btn.py) then
                btn:Hide()
                btn:ClearAllPoints()
                btn.visible = false
            end
            fait = fait + 1
        end
    end
end

function Rebuild()
    if not UI then return end
    Reindexe()

    local canvas = UI.canvas
    local pool   = UI.linePool

    for _, t in ipairs(pool.used) do
        t:Hide()
        t:ClearAllPoints()
        pool.free[#pool.free + 1] = t
    end
    pool.used = {}

    -- On ne masque PAS ici les boutons et les repères pour les réafficher juste
    -- après : masquer un cadre pendant qu'on le glisse annule le glissement, et
    -- OnDragStop ne se déclenche jamais. Seul le surplus est masqué, à la fin.

    -- étendue
    -- L'étendue tient compte des clusters entiers, et pas seulement des
    -- emplacements occupés : un cluster vidé de tous ses emplacements doit
    -- rester visible, sans quoi on ne pourrait plus rien y rétablir.
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

    -- La fenêtre, une fois le canevas dimensionné : tout ce qui suit s'y limite.
    local vis = { RectVisible() }
    -- Portés par UI : la ligne d'état les lit depuis une AUTRE fonction. Une
    -- première écriture en locales de Rebuild y laissait deux nil — et un
    -- « bad argument #2 to 'i' » une fois le code réduit par LuaSrcDiet.
    UI.rendus, UI.traces = 0, 0

    -- liaisons
    local B = session.geometry.branches
    -- TOUTES les liaisons sont placées, une texture chacune, et gardent leur
    -- boîte : c'est le filtre qui les montre ou les masque ensuite.
    UI.edgeItems = {}
    for _, e in ipairs(doc.edges) do
        local a, b = NodeById(e[1]), NodeById(e[2])
        if a and b then
            local ax, ay = ToPixels(NodePos(a))
            local bx, by = ToPixels(NodePos(b))

            -- Une liaison n'est active que si ses DEUX extrémités sont achetées.
            -- En aperçu, ce qui n'est pas actif s'éteint franchement.
            local col = RC.EDGE_COLOR
            if bought[a.id] and bought[b.id] then
                col = RC.EDGE_ACTIVE
            elseif tool == "preview" then
                col = RC.EDGE_OFF
            end

            -- Deux emplacements du même anneau et de branches voisines : c'est
            -- une portion de cercle, on la dessine comme telle.
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
                -- Les deux ancres sont mémorisées : une liaison masquée est
                -- DÉTACHÉE du canevas (ClearAllPoints) pour que le moteur ne la
                -- recalcule plus à chaque déplacement, et ré-ancrée à l'apparition.
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

    -- emplacements
    local backdrop = UISTYLE_BACKDROPS and UISTYLE_BACKDROPS.Frame or {
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
    }

    -- Les scripts sont liés UNE SEULE FOIS, à la création, et lisent self.node.
    -- Les relier à chaque reconstruction cassait le glissement et rendait le
    -- second clic de l'outil Lier peu fiable.
    for i, n in ipairs(doc.nodes) do
        local btn = UI.nodeButtons[i]
        if not btn then
            btn = CreateFrame("Button", nil, canvas)
            btn:SetWidth(RC.NODE_SIZE)
            btn:SetHeight(RC.NODE_SIZE)
            btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            btn:SetFrameLevel(canvas:GetFrameLevel() + 5)

            -- Nœud : assiette circulaire sombre sous l'icône…
            btn.disc = btn:CreateTexture(nil, "BACKGROUND")
            btn.disc:SetTexture(RC.NODE_DISC_TEXTURE)
            btn.disc:SetBlendMode("ADD")
            btn.disc:SetWidth(RC.NODE_DISC_SIZE)
            btn.disc:SetHeight(RC.NODE_DISC_SIZE)
            btn.disc:SetPoint("CENTER")
            btn.disc:SetVertexColor(RC.NODE_DISC_COLOR[1], RC.NODE_DISC_COLOR[2], RC.NODE_DISC_COLOR[3])

            -- … et anneau porteur de la couleur de qualité par-dessus.
            btn.ring = btn:CreateTexture(nil, "OVERLAY")
            btn.ring:SetTexture(RC.NODE_RING_TEXTURE)
            btn.ring:SetBlendMode("ADD")
            btn.ring:SetWidth(RC.NODE_RING_SIZE)
            btn.ring:SetHeight(RC.NODE_RING_SIZE)
            btn.ring:SetPoint("CENTER")

            -- Slot : creux ombré puis cadre de châsse, comme chez Blizzard.
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

            -- Cadre posé sur le bord de l'icône ronde (méthode Paragon).
            btn.iconRim = btn:CreateTexture(nil, "OVERLAY")
            btn.iconRim:SetTexture(RC.FRAME_SHEET)
            btn.iconRim:SetTexCoord(RC.FRAME_COORDS[1], RC.FRAME_COORDS[2],
                RC.FRAME_COORDS[3], RC.FRAME_COORDS[4])
            btn.iconRim:SetWidth(RC.FRAME_SIZE)
            btn.iconRim:SetHeight(RC.FRAME_SIZE)
            btn.iconRim:SetPoint("CENTER")

            -- Le cadre de sort du grimoire : assiette parchemin sous l'icône,
            -- cadre orné par-dessus (or ou brun, posé au rendu).
            btn.sbFond = btn:CreateTexture(nil, "BORDER")
            btn.sbFond:SetTexture(RC.SB_SHEET)
            btn.sbFond:SetTexCoord(RC.SB_FOND_COORDS[1], RC.SB_FOND_COORDS[2],
                RC.SB_FOND_COORDS[3], RC.SB_FOND_COORDS[4])
            btn.sbFond:SetWidth(RC.SB_FOND_SIZE)
            btn.sbFond:SetHeight(RC.SB_FOND_SIZE)
            btn.sbFond:SetPoint("CENTER")

            btn.sbCadre = btn:CreateTexture(nil, "OVERLAY")
            btn.sbCadre:SetTexture(RC.SB_SHEET)
            btn.sbCadre:SetPoint("CENTER")

            -- Marqueur du point de départ, valable pour nœud comme pour slot.
            btn.departRing = btn:CreateTexture(nil, "OVERLAY")
            btn.departRing:SetTexture(RC.NODE_RING_TEXTURE)
            btn.departRing:SetBlendMode("ADD")
            btn.departRing:SetWidth(RC.DEPART_RING_SIZE)
            btn.departRing:SetHeight(RC.DEPART_RING_SIZE)
            btn.departRing:SetPoint("CENTER")
            btn.departRing:SetVertexColor(RC.DEPART_COLOR[1], RC.DEPART_COLOR[2], RC.DEPART_COLOR[3])

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
        if Dedans(vis, x, y) then
            StyleNode(btn, n, x, y)
        else
            btn:Hide()
            btn:ClearAllPoints()
            btn.visible = false
        end
    end

    -- La file d'habillage en fond : les emplacements pas encore habillés, les
    -- plus proches de la fenêtre en DERNIER (table.remove prend par la fin).
    do
        local cx, cy = (vis[1] + vis[3]) / 2, (vis[2] + vis[4]) / 2
        local file = {}
        for i, _ in ipairs(doc.nodes) do
            local btn = UI.nodeButtons[i]
            if btn and not btn.styled then file[#file + 1] = i end
        end
        table.sort(file, function(a, b)
            local ba, bb = UI.nodeButtons[a], UI.nodeButtons[b]
            local da = (ba.px - cx) * (ba.px - cx) + (ba.py - cy) * (ba.py - cy)
            local db = (bb.px - cx) * (bb.px - cx) + (bb.py - cy) * (bb.py - cy)
            return da > db
        end)
        UI.aStyler = file
    end

    for i = #doc.nodes + 1, #UI.nodeButtons do
        UI.nodeButtons[i].node = nil
        UI.nodeButtons[i]:Hide()
    end

    -- Places vides : un cluster garde ses vingt-quatre places même quand un
    -- emplacement en a été retiré. On les montre en creux, cliquables pour
    -- rétablir l'emplacement.
    local occupied = {}
    for _, n in ipairs(doc.nodes) do
        occupied[n.cluster .. ":" .. n.ring .. ":" .. n.branch] = true
    end

    UI.autres = {}
    local gi = 0
    for _, c in ipairs(doc.clusters) do
        -- Anneau 0 : la place centrale, unique (branche 1).
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
                            GameTooltip:AddLine(fmt("cluster %d · anneau %d · branche %d",
                                s.cluster, s.ring, s.branch), 0.5, 0.5, 0.5, true)
                            GameTooltip:AddLine("Clic : rétablir un emplacement ici.",
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
                                SetStatus(fmt("Emplacement %d rétabli en cluster %d, anneau %d, branche %d.",
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
                    UI.autres[#UI.autres + 1] = { f = g, px = gx, py = gy, visible = true }
                end
            end
        end
    end

    for i = gi + 1, #UI.ghosts do
        UI.ghosts[i].spot = nil
        UI.ghosts[i]:Hide()
    end

    -- repères de cluster, mêmes précautions que pour les emplacements
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
                GameTooltip:AddLine(tool == "cluster" and "Clic : supprimer"
                    or "Glisser : déplacer", 1, 0.6, 0.6, true)
                GameTooltip:Show()
            end)
            m:SetScript("OnLeave", function() GameTooltip:Hide() end)

            m:SetScript("OnClick", function(self)
                local cc = self.cluster
                if not cc then return end
                if tool == "cluster" then
                    RemoveCluster(cc.id)
                    SetStatus(fmt("Cluster %d supprimé.", cc.id))
                else
                    selCluster = cc.id
                end
                Rebuild()
            end)

            m:SetScript("OnDragStart", function(self)
                if tool ~= "select" or not self.cluster then return end
                UI.dragCluster = self.cluster.id
                SetStatus(fmt("Cluster %d en déplacement — relâchez pour le poser.",
                    self.cluster.id))
            end)
            m:SetScript("OnDragStop", function()
                UI.dragCluster = nil
                Rebuild()
            end)

            UI.markers[i] = m
        end

        m.cluster = c
        -- Le niveau est reposé à chaque reconstruction, et pas seulement à la
        -- création : celui du canevas peut avoir changé depuis, et un repère
        -- resté au niveau d'hier se retrouve SOUS les emplacements — on ne peut
        -- alors plus ni le cliquer ni le glisser.
        m:SetFrameLevel(canvas:GetFrameLevel() + 9)
        m:ClearAllPoints()
        local x, y = ToPixels(c.x, c.y)
        -- La place centrale peut porter un emplacement : le repère s'écarte
        -- pour rester saisissable.
        if NodeAt(c.id, 0, 1) then y = y + 28 end
        m:SetPoint("CENTER", canvas, "BOTTOMLEFT", x, y)
        m:SetBackdropColor(0.1, 0.1, 0.1, 1)
        if selCluster == c.id then
            m:SetBackdropBorderColor(1, 0.82, 0, 1)
        else
            m:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
        end
        m:Show()
        UI.autres[#UI.autres + 1] = { f = m, px = x, py = y, visible = true,
                                      fixe = (UI.dragCluster == c.id) }
    end

    for i = #doc.clusters + 1, #UI.markers do
        UI.markers[i].cluster = nil
        UI.markers[i]:Hide()
    end

    -- Ranger en cases, filtrer, PUIS l'inspecteur qui affiche « N rendus ».
    RangeEnCases()
    Cull(true)
    UpdateInspector()
end

-- ---------------------------------------------------------------------------
-- Fenêtre
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
        SetStatus("Lier : clic gauche sur deux emplacements pour créer ou retirer leur liaison. "
            .. "Clic droit sur un emplacement pour couper toutes les siennes.")
    elseif t == "cluster" then
        SetStatus("Cluster : clic sur le fond pour poser un cluster, clic sur un repère pour le supprimer.")
    elseif t == "preview" then
        SetStatus("Aperçu : clic gauche pour acheter ou rendre un emplacement, clic droit pour tout remettre à zéro. "
            .. "Une liaison passe au cyan quand ses deux extrémités sont achetées. Rien de tout cela n'est enregistré.")
    else
        SetStatus("Sélection : clic gauche pour modifier un emplacement, clic droit pour le retirer, "
            .. "clic sur une place vide pour l'y rétablir. Glisser un repère : déplacer le cluster.")
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

-- LA FENÊTRE « SORTS PAR CLASSE » (2026-09-05) : dix lignes, une par classe,
-- chacune avec le champ de l'identifiant et le nom du sort tel que le client
-- le connaît. Elle suit la sélection : un autre emplacement de sort la
-- remplit, autre chose la ferme.
local function MajSortsFrame()
    local w = UI and UI.sortsFrame
    if not w or not w:IsShown() then return end
    local n = selNode and NodeById(selNode)
    if not n or n.kind ~= RC.KIND_SORT then
        w:Hide()
        return
    end
    w.titre:SetText(fmt("Sorts de l'emplacement %d", n.id))
    for _, ligne in ipairs(w.lignes) do
        local propre = n.sorts and n.sorts[ligne.classe]
        if not ligne.box:HasFocus() then
            ligne.box:SetText(propre and tostring(propre) or "")
        end
        local effectif = SortPour(n, ligne.classe)
        local nom = effectif and GetSpellInfo(effectif)
        if propre then
            if nom then
                ligne.nom:SetText(nom)
                ligne.nom:SetTextColor(1, 1, 1)
            else
                ligne.nom:SetText("identifiant inconnu du client")
                ligne.nom:SetTextColor(1, 0.4, 0.4)
            end
        elseif effectif then
            ligne.nom:SetText(fmt("repli : %s", nom or ("n°" .. effectif)))
            ligne.nom:SetTextColor(0.6, 0.6, 0.6)
        else
            ligne.nom:SetText("invisible pour cette classe")
            ligne.nom:SetTextColor(0.55, 0.55, 0.55)
        end
    end
end

local function OuvrirSortsFrame()
    if not UI then return end
    local w = UI.sortsFrame
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
        w.titre = w:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        w.titre:SetPoint("TOPLEFT", 12, -10)
        local fermer = MakeButton(w, "Fermer", 70, 20, function() w:Hide() end)
        fermer:SetPoint("TOPRIGHT", -10, -8)
        w.lignes = {}
        local y = -36
        for _, c in ipairs(CLASSES) do
            if c[1] ~= 0 then
                local ligne = { classe = c[1] }
                ligne.label = w:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                ligne.label:SetPoint("TOPLEFT", 12, y - 4)
                ligne.label:SetWidth(130)
                ligne.label:SetJustifyH("LEFT")
                ligne.label:SetText(c[2])
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
                    if n and n.kind == RC.KIND_SORT then
                        local id = tonumber(self:GetText()) or 0
                        n.sorts = n.sorts or {}
                        n.sorts[ligne.classe] = (id > 0) and id or nil
                        SetStatus(id > 0
                            and fmt("Emplacement %d : %s apprend le sort n°%d.", n.id, c[2], id)
                            or fmt("Emplacement %d : plus de sort propre pour %s.", n.id, c[2]))
                        Rebuild()
                    end
                    self:ClearFocus()
                end)
                ligne.box = box
                ligne.nom = w:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                ligne.nom:SetPoint("TOPLEFT", 244, y - 4)
                ligne.nom:SetWidth(184)
                ligne.nom:SetJustifyH("LEFT")
                w.lignes[#w.lignes + 1] = ligne
                y = y - 22
            end
        end
        UI.sortsFrame = w
    end
    w:Show()
    MajSortsFrame()
end

function UpdateInspector()
    if not UI then return end

    local n = selNode and NodeById(selNode)
    if n then
        UI.inspTitle:SetText(fmt("Emplacement %d — %d liaison(s)", n.id, CountLinks(n.id)))
        if n.kind == RC.KIND_SLOT then
            UI.inspType:SetText("Slot")
            UI.inspStat:SetText("—")
            UI.inspQual:SetText("—")
        elseif n.kind == RC.KIND_SORT then
            UI.inspType:SetText("Sort")
            local nb, total = ClassesServies(n)
            UI.inspStat:SetText(fmt("%d / %d classes servies", nb, total))
            local nomSort = n.sort and n.sort > 0 and GetSpellInfo(n.sort)
            UI.inspQual:SetText(nomSort and fmt("repli : %s", nomSort)
                or (n.sort and n.sort > 0 and fmt("repli n°%d", n.sort)) or "sans repli")
        elseif not n.stat then
            UI.inspType:SetText("Nœud vide")
            UI.inspStat:SetText("—")
            UI.inspQual:SetText("—")
        else
            UI.inspType:SetText("Nœud")
            local s = session.stats[n.stat]
            local qual = session.qualites[n.quality or 1]
            UI.inspStat:SetText(s and s.label or "?")
            UI.inspQual:SetText(qual and fmt("%s (+%d)", qual.label, qual.bonus) or "?")
        end
        if UI.sortBox and not UI.sortBox:HasFocus() then
            UI.sortBox:SetText(n.kind == RC.KIND_SORT and tostring(n.sort or 0) or "")
        end
        MajSortsFrame()
    else
        MajSortsFrame()
        UI.inspTitle:SetText("Aucune sélection")
        UI.inspType:SetText("—")
        UI.inspStat:SetText("—")
        UI.inspQual:SetText("—")
    end

    local slots, achetes = 0, 0
    for _, nn in ipairs(doc.nodes) do
        if nn.kind == RC.KIND_SLOT then slots = slots + 1 end
        if bought[nn.id] then achetes = achetes + 1 end
    end

    local text = fmt("|cffffd100%d|r clusters · |cffffd100%d|r emplacements (%d slots) · |cffffd100%d|r liaisons",
        #doc.clusters, #doc.nodes, slots, #doc.edges)
    local nbDeparts = 0
    for _ in pairs(doc.departs) do nbDeparts = nbDeparts + 1 end
    text = text .. (nbDeparts > 0 and fmt(" · |cffffd100%d départ(s)|r", nbDeparts)
        or " · |cffff5555départ non défini|r")
    if achetes > 0 then
        text = text .. fmt(" · |cff33e0f5%d achetés|r", achetes)
    end
    UI.counts:SetText(text)
end

-- LES BORNES DU DÉFILEMENT SE CALCULENT ICI, pas par GetHorizontalScrollRange :
-- le client les rend depuis la taille NON mise à l'échelle de l'enfant, et un
-- canevas zoomé ne se parcourait plus en entier — ni ne se centrait.
local function BornesScroll()
    local vp, canvas = UI.viewport, UI.canvas
    local z = zoom > 0 and zoom or 1
    return max(0, canvas:GetWidth() - vp:GetWidth() / z),
           max(0, canvas:GetHeight() - vp:GetHeight() / z)
end

local function ClampScroll()
    local vp = UI.viewport
    local bh, bv = BornesScroll()
    vp:SetHorizontalScroll(max(0, min(vp:GetHorizontalScroll(), bh)))
    vp:SetVerticalScroll(max(0, min(vp:GetVerticalScroll(), bv)))
end

local function Centrer()
    local vp = UI.viewport
    local bh, bv = BornesScroll()
    vp:SetHorizontalScroll(bh / 2)
    vp:SetVerticalScroll(bv / 2)
end

local function SetZoom(z)
    zoom = max(RC.ZOOM_MIN, min(RC.ZOOM_MAX, z))
    UI.canvas:SetScale(zoom)
    ClampScroll()
    UI.zoomLabel:SetText(fmt("Zoom %d%%", floor(zoom * 100 + 0.5)))
    -- Les positions en pixels de canevas ne bougent pas au zoom : filtrer suffit.
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

    local f = CreateFrame("Frame", "SpherierEditorFrame", UIParent)
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
    UI.autres      = {}
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
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetTexture(0.12, 0.12, 0.12, 1)
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT", 12, 0)
    title:SetText("Sphèrier — éditeur de disposition")
    title:SetTextColor(1, 0.82, 0)
    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Échap ferme l'éditeur, exactement comme ce bouton : la disposition en
    -- cours vit dans des variables de module et lui survit, rien n'est perdu.
    table.insert(UISpecialFrames, "SpherierEditorFrame")

    -- ------------------------------------------------------ panneau gauche
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

    section("OUTILS")
    local tools = {
        { "select",  "Sélection" },
        { "cluster", "Cluster" },
        { "link",    "Lier" },
        { "preview", "Aperçu" },
    }
    for _, t in ipairs(tools) do
        local key, label = t[1], t[2]
        local b = MakeButton(panel, label, RC.PANEL_W - 20, 22, function() SetTool(key) end)
        b:SetPoint("TOPLEFT", 10, y)
        UI.toolButtons[key] = b
        y = y - 25
    end

    y = y - 8
    section("SÉLECTION")
    UI.inspTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.inspTitle:SetPoint("TOPLEFT", 10, y)
    UI.inspTitle:SetText("Aucune sélection")
    y = y - 20

    UI.inspType = row("Type")
    y = y - 16
    UI.inspStat = row("Stat")
    y = y - 16
    UI.inspQual = row("Qualité")
    y = y - 20

    local function cycleNode(field, delta, maxv)
        local n = selNode and NodeById(selNode)
        if not n or n.kind == RC.KIND_SLOT then return end
        local v = (n[field] or 1) + delta
        if v < 1 then v = maxv elseif v > maxv then v = 1 end
        n[field] = v
        Rebuild()
    end

    local bType = MakeButton(panel, "Nœud / Slot / Sort", RC.PANEL_W - 20, 20, function()
        local n = selNode and NodeById(selNode)
        if not n then return end
        if n.kind == RC.KIND_NODE then
            MakeSlot(n)
            SetStatus(fmt("Emplacement %d passé en slot : sa pierre a été retirée.", n.id))
        elseif n.kind == RC.KIND_SLOT then
            MakeSort(n)
            SetStatus(fmt("Emplacement %d passé en sort — saisissez l'identifiant du sort.", n.id))
        else
            MakeNode(n)
            SetStatus(fmt("Emplacement %d repassé en nœud, avec une pierre tirée au hasard.", n.id))
        end
        Rebuild()
    end)
    bType:SetPoint("TOPLEFT", 10, y)
    y = y - 23

    -- Nœud vide : bascule mettre / retirer la pierre pré-allouée.
    local bPierre = MakeButton(panel, "Pierre : mettre / retirer", RC.PANEL_W - 20, 20, function()
        local n = selNode and NodeById(selNode)
        if not n or n.kind ~= RC.KIND_NODE then return end
        if n.stat then
            n.stat, n.quality = nil, nil
            SetStatus(fmt("Emplacement %d : nœud vide, sans pierre pré-allouée.", n.id))
        else
            n.stat    = random(#session.stats)
            n.quality = random(#session.qualites)
            SetStatus(fmt("Emplacement %d : pierre pré-allouée tirée au hasard.", n.id))
        end
        Rebuild()
    end)
    bPierre:SetPoint("TOPLEFT", 10, y)
    y = y - 23

    -- Identifiant du sort custom d'un emplacement de sort.
    local sortLabel = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sortLabel:SetPoint("TOPLEFT", 10, y - 4)
    sortLabel:SetText("Repli n°")
    local sortBox = CreateFrame("EditBox", nil, panel)
    sortBox:SetPoint("TOPLEFT", 74, y)
    sortBox:SetWidth(70)
    sortBox:SetHeight(20)
    sortBox:SetAutoFocus(false)
    sortBox:SetNumeric(true)
    sortBox:SetFontObject("GameFontHighlightSmall")
    sortBox:SetBackdrop(backdrop)
    sortBox:SetBackdropColor(0.03, 0.03, 0.03, 1)
    sortBox:SetTextInsets(6, 6, 0, 0)
    sortBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sortBox:SetScript("OnEnterPressed", function(self)
        local n = selNode and NodeById(selNode)
        if n and n.kind == RC.KIND_SORT then
            n.sort = tonumber(self:GetText()) or 0
            SetStatus(fmt("Emplacement %d : sort n°%d.", n.id, n.sort))
            Rebuild()
        end
        self:ClearFocus()
    end)
    UI.sortBox = sortBox
    -- Les dix sorts, un par classe : la fenêtre dédiée.
    local bSorts = MakeButton(panel, "Par classe…", RC.PANEL_W - 160, 20, function()
        local n = selNode and NodeById(selNode)
        if not n or n.kind ~= RC.KIND_SORT then
            SetStatus("Sélectionnez d'abord un emplacement de sort.")
            return
        end
        if UI.sortsFrame and UI.sortsFrame:IsShown() then UI.sortsFrame:Hide() else OuvrirSortsFrame() end
    end)
    bSorts:SetPoint("TOPLEFT", 150, y)
    y = y - 23

    local bs1 = MakeButton(panel, "< Stat", 88, 20, function() cycleNode("stat", -1, #session.stats) end)
    bs1:SetPoint("TOPLEFT", 10, y)
    local bs2 = MakeButton(panel, "Stat >", 88, 20, function() cycleNode("stat", 1, #session.stats) end)
    bs2:SetPoint("TOPLEFT", 108, y)
    y = y - 23

    local bq1 = MakeButton(panel, "< Qualité", 88, 20, function() cycleNode("quality", -1, #session.qualites) end)
    bq1:SetPoint("TOPLEFT", 10, y)
    local bq2 = MakeButton(panel, "Qualité >", 88, 20, function() cycleNode("quality", 1, #session.qualites) end)
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

    local bDelNode = MakeButton(panel, "Retirer l'emplacement", RC.PANEL_W - 20, 20, function()
        local n = selNode and NodeById(selNode)
        if not n then return end
        local id = n.id
        RemoveNode(id)
        SetStatus(fmt("Emplacement %d retiré. Sa place reste disponible : cliquez-la pour le rétablir.", id))
        Rebuild()
    end)
    bDelNode:SetPoint("TOPLEFT", 10, y)
    y = y - 23

    -- LA CLASSE DU DÉPART : un bouton qui fait défiler les classes (clic gauche
    -- suivante, clic droit précédente). La grille commune veut un départ par
    -- classe ; une grille de classe garde « toutes classes ».
    local bClasse = MakeButton(panel, "", RC.PANEL_W - 20, 20, function() end)
    bClasse:SetPoint("TOPLEFT", 10, y)
    local function MajClasse()
        bClasse.label:SetText("Départ : " .. CLASSES[classeDepart][2])
    end
    bClasse:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    bClasse:SetScript("OnClick", function(_, bouton)
        if bouton == "RightButton" then
            classeDepart = (classeDepart - 2) % #CLASSES + 1
        else
            classeDepart = classeDepart % #CLASSES + 1
        end
        MajClasse()
    end)
    MajClasse()
    y = y - 23

    local bDepart = MakeButton(panel, "Définir comme départ", RC.PANEL_W - 20, 20, function()
        local n = selNode and NodeById(selNode)
        if not n then return end
        local classe = CLASSES[classeDepart][1]
        if doc.departs[classe] == n.id then
            doc.departs[classe] = nil
            SetStatus(fmt("Emplacement %d n'est plus le départ (%s).", n.id, NomClasse(classe)))
        else
            doc.departs[classe] = n.id
            SetStatus(fmt("Emplacement %d défini comme départ (%s).", n.id, NomClasse(classe)))
        end
        Rebuild()
    end)
    bDepart:SetPoint("TOPLEFT", 10, y)
    y = y - 28

    section("CLUSTER SÉLECTIONNÉ")
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

    local bDel = MakeButton(panel, "Supprimer le cluster", RC.PANEL_W - 20, 20, function()
        if not selCluster then return end
        RemoveCluster(selCluster)
        SetStatus("Cluster supprimé.")
        Rebuild()
    end)
    bDel:SetPoint("TOPLEFT", 10, y)
    y = y - 28

    section("FICHIER")
    local nameBox = CreateFrame("EditBox", nil, panel)
    nameBox:SetPoint("TOPLEFT", 10, y)
    nameBox:SetWidth(RC.PANEL_W - 20)
    nameBox:SetHeight(20)
    nameBox:SetAutoFocus(false)
    nameBox:SetFontObject("GameFontHighlightSmall")
    nameBox:SetBackdrop(backdrop)
    nameBox:SetBackdropColor(0.03, 0.03, 0.03, 1)
    nameBox:SetTextInsets(6, 6, 0, 0)
    nameBox:SetText("essai")
    nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    nameBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    UI.nameBox = nameBox
    y = y - 24

    local bSave = MakeButton(panel, "Enregistrer", 88, 20, function()
        AIO.Handle("Spherier", "Save", nameBox:GetText(), doc.clusters, doc.nodes, doc.edges, doc.departs)
    end)
    bSave:SetPoint("TOPLEFT", 10, y)
    local bLoad = MakeButton(panel, "Charger", 88, 20, function()
        AIO.Handle("Spherier", "Load", nameBox:GetText())
    end)
    bLoad:SetPoint("TOPLEFT", 108, y)
    y = y - 23

    local bCheck = MakeButton(panel, "Vérifier", 88, 20, function()
        AIO.Handle("Spherier", "Verify", doc.clusters, doc.nodes, doc.edges, doc.departs)
    end)
    bCheck:SetPoint("TOPLEFT", 10, y)
    local bNew = MakeButton(panel, "Vider", 88, 20, function()
        doc.clusters, doc.nodes, doc.edges = {}, {}, {}
        doc.nextCluster, doc.nextNode = 1, 1
        doc.departs = {}
        selNode, selCluster, linkPending = nil, nil, nil
        bought = {}
        fautifs = {}
        SetStatus("Disposition vidée.")
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
    local viewport = CreateFrame("ScrollFrame", "SpherierEditorViewport", f)
    viewport:SetPoint("TOPLEFT", RC.PANEL_W + 16, -38)
    viewport:SetPoint("BOTTOMRIGHT", -8, 54)
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    UI.viewport = viewport

    local vpbg = viewport:CreateTexture(nil, "BACKGROUND")
    vpbg:SetAllPoints()
    vpbg:SetTexture(0.03, 0.03, 0.03, 1)

    local canvas = CreateFrame("Frame", "SpherierEditorCanvas", viewport)
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
        local glissait = dragging
        dragging = false
        if glissait and button == "LeftButton" and tool == "select" then Cull(true) end
        if button == "LeftButton" and tool == "cluster" then
            local lx, ly = CursorInCanvas()
            local gx, gy = ToGrid(lx, ly)
            gx = floor(gx / RC.SNAP + 0.5) * RC.SNAP
            gy = floor(gy / RC.SNAP + 0.5) * RC.SNAP
            local c = AddCluster(gx, gy)
            selCluster, selNode = c.id, nil
            SetStatus(fmt("Cluster %d posé en %.2f, %.2f.", c.id, gx, gy))
            Rebuild()
        end
    end)
    viewport:SetScript("OnHide", function() dragging = false end)

    viewport:SetScript("OnUpdate", function(self)
        -- LE TEMPS D'IMAGE lui-même : GetTime() est le tampon de l'image, sa
        -- différence entre deux OnUpdate est la durée de l'image précédente.
        -- C'est ce qui départage le script du moteur : un gel visible avec un
        -- filtre à 2 ms est un gel du moteur.
        do
            local t = GetTime()
            if UI.derniereImage then
                local dt = (t - UI.derniereImage) * 1000
                if dt > (UI.pireImage or 0) then UI.pireImage = dt end
                if t - (UI.depuisImage or 0) > 0.5 then
                    if UI.imageLabel then
                        UI.imageLabel:SetText(fmt("image %.0f ms", UI.pireImage or 0))
                    end
                    UI.pireImage, UI.depuisImage = 0, t
                end
            end
            UI.derniereImage = t
        end
        HabilleEnFond()
        if UI.dragCluster then
            -- Filet de sécurité : on ne compte pas sur OnDragStop seul. Si le
            -- bouton n'est plus enfoncé, le cluster est reposé, quoi qu'il soit
            -- arrivé au cadre entre-temps.
            if not IsMouseButtonDown("LeftButton") then
                local id = UI.dragCluster
                UI.dragCluster = nil
                SetStatus(fmt("Cluster %d reposé.", id))
                Rebuild()
                return
            end

            local c = ClusterById(UI.dragCluster)
            if c then
                local lx, ly = CursorInCanvas()
                local gx, gy = ToGrid(lx, ly)
                local nx = floor(gx / RC.SNAP + 0.5) * RC.SNAP
                local ny = floor(gy / RC.SNAP + 0.5) * RC.SNAP
                -- On ne reconstruit que si l'aimantation a réellement bougé.
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
        -- Le curseur se mesure en pixels d'écran, le défilement en pixels de
        -- canevas : on divise par le zoom, comme l'interface joueur.
        local k = (zoom > 0) and zoom or 1
        self:SetHorizontalScroll(startH - (cx - startX) / k)
        self:SetVerticalScroll(startV + (cy - startY) / k)
        ClampScroll()
        Cull()                  -- bon marché : à chaque image, sans à-coups
    end)

    viewport:SetScript("OnMouseWheel", function(_, delta) SetZoom(zoom + delta * RC.ZOOM_STEP) end)

    -- ---------------------------------------------------------------- pied
    local footer = CreateFrame("Frame", nil, f)
    footer:SetPoint("BOTTOMLEFT", 1, 1)
    footer:SetPoint("BOTTOMRIGHT", -1, 1)
    footer:SetHeight(50)
    local fbg = footer:CreateTexture(nil, "BACKGROUND")
    fbg:SetAllPoints()
    fbg:SetTexture(0.09, 0.09, 0.09, 1)

    UI.counts = footer:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    UI.counts:SetPoint("TOPLEFT", 12, -8)
    -- Ce que le filtre montre, écrit par le filtre lui-même : porté par
    -- l'inspecteur, le compte restait figé entre deux reconstructions.
    UI.rendusLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.rendusLabel:SetPoint("LEFT", UI.counts, "RIGHT", 8, 0)

    UI.status = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.status:SetPoint("BOTTOMLEFT", 12, 8)
    UI.status:SetWidth(820)
    UI.status:SetJustifyH("LEFT")

    UI.zoomLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.zoomLabel:SetPoint("BOTTOMRIGHT", -12, 8)
    -- Le coût du filtre, pour mesurer plutôt que supposer.
    UI.perfLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.perfLabel:SetPoint("RIGHT", UI.zoomLabel, "LEFT", -12, 0)
    UI.perfLabel:SetText("filtre –")
    UI.imageLabel = footer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    UI.imageLabel:SetPoint("RIGHT", UI.perfLabel, "LEFT", -12, 0)
    UI.imageLabel:SetText("image –")

    local bFit = MakeButton(footer, "Recentrer", 86, 20, function()
        SetZoom(1)
        Centrer()
        Rebuild()
    end)
    bFit:SetPoint("TOPRIGHT", -12, -8)

    -- L'interrupteur du filtre : « Filtre : oui » rend la fenêtre seule et
    -- habille le reste en fond ; « non » rend et habille tout d'un coup à la
    -- reconstruction. Pour comparer les deux à l'œil.
    local bFiltre = MakeButton(footer, "Filtre : oui", 86, 20, function() end)
    bFiltre:SetPoint("RIGHT", bFit, "LEFT", -6, 0)
    bFiltre:SetScript("OnClick", function(self)
        UI.sansFiltre = not UI.sansFiltre
        self.label:SetText(UI.sansFiltre and "Filtre : non" or "Filtre : oui")
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

function SpherierHandlers.ReceiveSession(_, geometry, stats, qualites, slotIcon, layouts, sepMin)
    session.geometry = geometry or session.geometry
    session.stats    = stats or {}
    session.qualites = qualites or {}
    session.slotIcon = slotIcon or ""
    session.layouts  = layouts or {}
    session.sepMin   = sepMin or 0.7

    EnsureUI()
    UI.layoutList:SetText(#session.layouts > 0
        and ("En magasin : " .. table.concat(session.layouts, ", "))
        or "Aucune disposition enregistrée.")
    UI:Show()
    SetZoom(1)
    Rebuild()
    SetStatus("Outil Cluster, puis clic sur le fond pour poser un premier cluster.")
end

function SpherierHandlers.OpenEditor(_)
    EnsureUI()
    if UI:IsShown() then
        UI:Hide()
    else
        AIO.Handle("Spherier", "RequestSession")
    end
end

function SpherierHandlers.ReceiveLayoutList(_, layouts)
    session.layouts = layouts or {}
    if UI then
        UI.layoutList:SetText(#session.layouts > 0
            and ("En magasin : " .. table.concat(session.layouts, ", "))
            or "Aucune disposition enregistrée.")
    end
end

local function ReportText(r)
    if not r then return "" end
    local head = fmt("%d clusters · %d emplacements (%d slots) · %d liaisons · écart min %.3f u · %d morceau(x)",
        r.clusters or 0, r.nodes or 0, r.slots or 0, r.edges or 0, r.minSep or 0, r.groups or 0)
    if r.problems and #r.problems > 0 then
        return head .. "  |cffff5555>> " .. table.concat(r.problems, " ; ") .. "|r"
    end
    return head .. "  |cff55ff55>> aucun défaut|r"
end

-- Le rapport transporte une LISTE d'identifiants ; le rendu interroge par
-- identifiant. Un rapport sans liste — celui que renvoie un échec de lecture —
-- efface simplement les marques précédentes.
local function MarquesDuRapport(r)
    local ens = {}
    if r and r.fautifs then
        for _, id in ipairs(r.fautifs) do ens[id] = true end
    end
    return ens
end

function SpherierHandlers.ReceiveReport(_, report, message)
    EnsureUI()
    -- REDESSINER, sans quoi le rouge n'apparaîtrait qu'au prochain
    -- rafraîchissement : c'est justement à l'instant du rapport qu'on regarde.
    fautifs = MarquesDuRapport(report)
    Rebuild()
    SetStatus((message and (message .. "  ") or "") .. ReportText(report), report and not report.ok)
end

function SpherierHandlers.ReceiveLayout(_, clusters, nodes, edges, name, report, depart)
    EnsureUI()

    doc.clusters = clusters or {}
    doc.nodes    = nodes or {}
    doc.edges    = edges or {}
    -- Un nombre nu est l'ancienne forme : un seul départ, « toutes classes ».
    if type(depart) == "number" then
        doc.departs = { [0] = depart }
    else
        doc.departs = {}
        for classe, id in pairs(depart or {}) do
            doc.departs[tonumber(classe)] = tonumber(id)
        end
    end

    local maxC, maxN = 0, 0
    for _, c in ipairs(doc.clusters) do if c.id > maxC then maxC = c.id end end
    for _, n in ipairs(doc.nodes) do if n.id > maxN then maxN = n.id end end
    doc.nextCluster, doc.nextNode = maxC + 1, maxN + 1

    selNode, selCluster, linkPending = nil, nil, nil
    -- Les identifiants viennent du fichier : un aperçu hérité de la disposition
    -- précédente désignerait des emplacements sans rapport.
    bought = {}
    fautifs = MarquesDuRapport(report)
    if UI.nameBox then UI.nameBox:SetText(name or "") end

    UI:Show()
    -- RECONSTRUIRE D'ABORD : le canevas prend la taille de la disposition, le
    -- centrage a alors ses bornes. Centrer avant, c'était centrer sur le
    -- canevas d'hier — la fenêtre s'ouvrait sur un coin vide et le pied
    -- disait « 0 rendus » (banc_editeur.lua, 2026-09-05).
    SetZoom(1)
    Rebuild()
    Centrer()
    Cull(true)
    SetStatus(fmt("« %s » chargée.  ", name or "?") .. ReportText(report), report and not report.ok)
end

-- /spherier appartient désormais à l'interface joueur
-- (Spherier_Joueur_Client.lua). L'éditeur s'ouvre par .spherier editor.
