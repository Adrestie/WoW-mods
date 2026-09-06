--[[----------------------------------------------------------------------------
    Sphèrier Papota — éditeur de disposition, côté serveur

    Ce fichier ne contient AUCUNE logique de jeu. Il sert d'atelier : il fournit
    au client le catalogue et la géométrie, puis écrit, relit et contrôle les
    dispositions sous forme de fichiers XML dans lua_scripts\Spherier\layouts\.

    Le XML est volontairement lisible et modifiable à la main : c'est le format
    d'échange entre l'éditeur en jeu et tout autre outil.

    Usage en jeu : .spherier show (ou /spherier)
------------------------------------------------------------------------------]]

local AIO = require("AIO")

local SpherierHandlers = AIO.AddHandlers("Spherier", {})

local sqrt, cos, sin, pi, floor = math.sqrt, math.cos, math.sin, math.pi, math.floor
local fmt = string.format

-- ---------------------------------------------------------------------------
-- Géométrie d'un cluster
-- ---------------------------------------------------------------------------
-- Trois anneaux concentriques de huit emplacements chacun. Les huit
-- emplacements d'un anneau partagent les angles des autres anneaux : les
-- emplacements s'alignent donc en huit branches rayonnant depuis le centre,
-- comme une étoile.
--
-- Les rayons sont choisis pour qu'aucune paire d'emplacements d'un même cluster
-- ne descende sous SEP_MIN. L'écart entre anneaux est passé de 0.80 à 1.00 :
-- c'était lui, et non la corde, qui serrait le plus à l'œil.
--
--   corde intra-anneau : 2 R sin(22.5°)  ->  0.84 / 1.61 / 2.37
--   écart entre anneaux :                    1.00 / 1.00
--
-- Le point le plus serré reste donc la corde de l'anneau intérieur, à 0.84.
--
-- Attention : la position d'un emplacement se déduisant de ces rayons, les
-- modifier déplace tous les emplacements de toutes les dispositions déjà
-- enregistrées. Deux clusters voisins doivent désormais être distants d'au
-- moins 6.9 unités (3.1 + 3.1 + 0.7) au lieu de 6.1.

local GEOMETRY = {
    radii    = { 1.1, 2.1, 3.1 },
    branches = 8,
}

local SEP_MIN = 0.70            -- écart minimal toléré entre deux emplacements

-- ---------------------------------------------------------------------------
-- Catalogue
-- ---------------------------------------------------------------------------
-- La clé est ce qui est écrit dans le XML ; elle ne doit jamais changer.

local STATS = {
    { key = "endurance",          label = "Endurance",            cat = 1, icon = "Interface\\Icons\\Spell_Holy_WordFortitude" },
    { key = "intelligence",       label = "Intelligence",         cat = 1, icon = "Interface\\Icons\\Spell_Holy_MagicalSentry" },
    { key = "esprit",             label = "Esprit",               cat = 1, icon = "Interface\\Icons\\Spell_Shadow_Charm" },
    { key = "dexterite",          label = "Dextérité",            cat = 1, icon = "Interface\\Icons\\Spell_Holy_BlessingOfAgility" },
    { key = "force",              label = "Force",                cat = 1, icon = "Interface\\Icons\\Spell_Nature_Strength" },
    { key = "parade",             label = "Parade",               cat = 2, icon = "Interface\\Icons\\Ability_Parry" },
    { key = "blocage",            label = "Blocage",              cat = 2, icon = "Interface\\Icons\\Ability_Warrior_ShieldWall" },
    { key = "esquive",            label = "Esquive",              cat = 2, icon = "Interface\\Icons\\Spell_Magic_LesserInvisibilty" },
    { key = "hate",               label = "Hâte",                 cat = 2, icon = "Interface\\Icons\\Spell_Nature_BloodLust" },
    { key = "critique",           label = "Critique",             cat = 2, icon = "Interface\\Icons\\Ability_CriticalStrike" },
    { key = "touche",             label = "Touché",               cat = 2, icon = "Interface\\Icons\\Ability_Hunter_SniperShot" },
    { key = "puissance_sorts",    label = "Puissance des sorts",  cat = 2, icon = "Interface\\Icons\\Spell_Fire_FlameBolt" },
    { key = "puissance_attaque",  label = "Puissance d'attaque",  cat = 2, icon = "Interface\\Icons\\INV_Sword_04" },
    { key = "penetration_armure", label = "Pénétration d'armure", cat = 2, icon = "Interface\\Icons\\Ability_Rogue_Ambush" },
    { key = "expertise",          label = "Expertise",            cat = 2, icon = "Interface\\Icons\\Ability_Warrior_WeaponMastery" },
    { key = "bonus_soins",        label = "Bonus des soins",      cat = 2, icon = "Interface\\Icons\\Spell_Holy_HolyBolt" },
}

-- Cinq qualités depuis le 2026-08-23 (la « Magique » a été retirée, la
-- « Normale » devient « Commun »). Le bonus est celui qu'affiche l'infobulle
-- de l'éditeur ; en jeu il viendra de la base, comme tout le chiffré.
-- Le bonus affiche est celui d'un NOEUD (+1/+2/+3/+5/+7, decision du 2026-09-05 soir) ;
-- les pierres-objets gardent +5/+7/+10/+15/+30 (papota_sphere_stone fait foi).
local QUALITES = {
    { label = "Commun",     bonus = 1 },
    { label = "Inhabituel", bonus = 2 },
    { label = "Rare",       bonus = 3 },
    { label = "Épique",     bonus = 5 },
    { label = "Légendaire", bonus = 7 },
}

-- La châsse « prismatique » n'existe pas dans le client 3.3.5 ; la châsse
-- générique, si. Le client compose désormais le visuel du slot lui-même
-- (planche UI-ItemSockets) — cette icône ne sert plus qu'aux infobulles.
local SLOT_ICON = "Interface\\ItemSocketingFrame\\UI-EmptySocket"

local STAT_BY_KEY = {}
for i, s in ipairs(STATS) do STAT_BY_KEY[s.key] = i end

-- ---------------------------------------------------------------------------
-- Fichiers
-- ---------------------------------------------------------------------------
-- Le chemin est relatif au répertoire de travail du worldserver, celui où se
-- trouve déjà lua_scripts. Lua standard ne sait pas créer un dossier ni lister
-- un répertoire : le dossier est donc créé une fois pour toutes à la main, et
-- l'inventaire des dispositions est tenu dans un fichier d'index.

local DIR   = "lua_scripts/Spherier/layouts/"
local INDEX = DIR .. "index.txt"

local function SafeName(name)
    name = tostring(name or ""):gsub("[^%w%-_]", "")
    if name == "" then name = "sans_nom" end
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
-- Géométrie dérivée
-- ---------------------------------------------------------------------------

local function NodePosition(cluster, ring, branch)
    local r = GEOMETRY.radii[ring]
    if not r then return cluster.x, cluster.y end
    local a = (cluster.rot or 0) + (branch - 1) * 2 * pi / GEOMETRY.branches
    return cluster.x + r * cos(a), cluster.y + r * sin(a)
end

-- ---------------------------------------------------------------------------
-- Contrôle d'une disposition
-- ---------------------------------------------------------------------------
-- Trois défauts se voient mal à l'œil et se mesurent bien : deux emplacements
-- qui se chevauchent, une liaison qui pointe dans le vide, et un morceau de
-- grille qu'on ne peut pas atteindre.

-- LES DÉPARTS SONT UNE TABLE `classe → emplacement` (2026-09-05). Une grille
-- de classe n'en a qu'un, sous la clé 0 (« toutes classes ») ; la grille commune
-- en a un par classe. Un nombre nu est encore accepté — c'est l'ancienne forme,
-- et les vieilles feuilles comme les vieux appels la passent encore.
local function Departs(d)
    if type(d) == "number" then return { [0] = d } end
    if type(d) ~= "table" then return {} end
    local t = {}
    for classe, id in pairs(d) do
        classe, id = tonumber(classe), tonumber(id)
        if classe and id then t[classe] = id end
    end
    return t
end

-- Les dix classes jouables de WotLK : la grille commune veut, à chaque
-- emplacement de sort, un sort pour chacune d'elles.
local CLASSES_JEU = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11 }

-- SORTS PAR CLASSE (2026-09-05). Sur la grille commune, un emplacement de sort
-- est à tout le monde : chaque classe y apprend LE SIEN. `n.sorts` porte la
-- table classe → identifiant ; `n.sort` reste le repli « toutes classes ».
local function Sorts(t)
    local r = {}
    if type(t) ~= "table" then return r end
    for classe, id in pairs(t) do
        classe, id = tonumber(classe), tonumber(id)
        if classe and id and id > 0 then r[classe] = id end
    end
    return r
end

-- Le sort qu'une classe apprend à un emplacement : le sien, sinon le repli,
-- sinon rien.
local function SortPour(n, classe)
    local s = Sorts(n.sorts)[classe]
    if s then return s end
    if n.sort and n.sort > 0 then return n.sort end
    return nil
end

local function Verify(clusters, nodes, edges, depart)
    local departs = Departs(depart)
    local byId, cById = {}, {}
    for _, c in ipairs(clusters) do cById[c.id] = c end

    local placed = {}
    for _, n in ipairs(nodes) do
        byId[n.id] = n
        local c = cById[n.cluster]
        if c then
            local x, y = NodePosition(c, n.ring, n.branch)
            placed[#placed + 1] = { id = n.id, x = x, y = y }
        end
    end

    local problems = {}

    -- LES NŒUDS FAUTIFS, et pas seulement leur nombre. Un rapport qui dit
    -- « 3 morceaux non reliés » sur une grille de deux cents emplacements
    -- laisse l'œil chercher ; l'éditeur les peint en rouge, encore faut-il
    -- qu'on lui dise LESQUELS. On ne marque que les défauts de LIAISON —
    -- ceux dont un emplacement précis est responsable.
    local marques = {}
    local function Fautif(id)
        if id and byId[id] then marques[id] = true end
    end

    -- emplacements orphelins
    local orphans = #nodes - #placed
    if orphans > 0 then
        problems[#problems + 1] = fmt("%d emplacement(s) rattaché(s) à un cluster inexistant", orphans)
    end

    -- chevauchement
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
        problems[#problems + 1] = fmt("emplacements %d et %d trop proches (%.3f u, minimum %.2f)",
            wa or 0, wb or 0, worst, SEP_MIN)
        -- Les deux sont peints en rouge, comme tout defaut qu'un emplacement porte.
        Fautif(wa)
        Fautif(wb)
    end

    -- liaisons dans le vide et doublons
    local adj, seenEdge, dangling, dupes = {}, {}, 0, 0
    for _, n in ipairs(nodes) do adj[n.id] = {} end
    for _, e in ipairs(edges) do
        local a, b = e[1] or e.a, e[2] or e.b
        if not byId[a] or not byId[b] or a == b then
            dangling = dangling + 1
            -- L'EXTREMITE QUI EXISTE porte la marque : l'autre n'est nulle
            -- part à l'écran, la peindre n'apprendrait rien.
            Fautif(a)
            Fautif(b)
        else
            local k = (a < b) and (a .. ":" .. b) or (b .. ":" .. a)
            if seenEdge[k] then
                dupes = dupes + 1
                Fautif(a)
                Fautif(b)
            else
                seenEdge[k] = true
                table.insert(adj[a], b)
                table.insert(adj[b], a)
            end
        end
    end
    if dangling > 0 then
        problems[#problems + 1] = fmt("%d liaison(s) pointant sur un emplacement inexistant", dangling)
    end
    if dupes > 0 then
        problems[#problems + 1] = fmt("%d liaison(s) en double", dupes)
    end

    -- morceaux séparés
    --
    -- ON RETIENT LA COMPOSITION de chaque morceau, pas seulement leur nombre :
    -- c'est elle qui dit quels emplacements peindre.
    local seen, morceaux = {}, {}
    for _, n in ipairs(nodes) do
        if not seen[n.id] then
            local morceau = { n.id }
            seen[n.id] = true
            local queue = { n.id }
            while #queue > 0 do
                local cur = table.remove(queue)
                for _, nb in ipairs(adj[cur] or {}) do
                    if not seen[nb] then
                        seen[nb] = true
                        queue[#queue + 1] = nb
                        morceau[#morceau + 1] = nb
                    end
                end
            end
            morceaux[#morceaux + 1] = morceau
        end
    end
    local groups = #morceaux
    if groups > 1 then
        problems[#problems + 1] = fmt("%d morceaux non reliés entre eux", groups)

        -- LE MORCEAU DE REFERENCE est celui du point de départ — c'est lui la
        -- grille, les autres sont ce qui s'en est détaché. Sans départ posé,
        -- ou s'il désigne un emplacement retiré, on retient le plus gros :
        -- peindre les deux cents nœuds du tronc pour signaler un îlot de
        -- trois serait exactement l'inverse du service rendu.
        -- Le morceau de référence porte un départ — n'importe lequel : tous
        -- doivent être sur la même grille, et le premier trouvé fait foi.
        local ref
        local estDepart = {}
        for _, id in pairs(departs) do estDepart[id] = true end
        for i, m in ipairs(morceaux) do
            for _, id in ipairs(m) do
                if estDepart[id] and byId[id] then ref = i break end
            end
            if ref then break end
        end
        if not ref then
            ref = 1
            for i, m in ipairs(morceaux) do
                if #m > #morceaux[ref] then ref = i end
            end
        end

        for i, m in ipairs(morceaux) do
            if i ~= ref then
                for _, id in ipairs(m) do Fautif(id) end
            end
        end
    end

    -- point de départ : chaque classe en a un (§2 de la conception), l'import
    -- vers les tables du module l'exige.
    local nbDeparts = 0
    for classe, id in pairs(departs) do
        nbDeparts = nbDeparts + 1
        if not byId[id] then
            problems[#problems + 1] = fmt("le départ (classe %d) pointe sur l'emplacement retiré %d", classe, id)
            Fautif(id)
        end
    end
    if nbDeparts == 0 then
        problems[#problems + 1] = "aucun point de départ défini"
    end

    -- VISIBILITÉ PAR CLASSE (2026-09-05) : un emplacement de sort sans sort
    -- pour une classe N'EXISTE PAS pour elle, ni ses liaisons. Chaque classe
    -- doit donc atteindre, depuis SON départ, tout ce qu'elle voit — un
    -- emplacement de sort muet pour elle posé en pont lui coupe la grille.
    -- Inutile si la grille est déjà en morceaux : le défaut global suffit.
    if groups == 1 then
        for _, classe in ipairs(CLASSES_JEU) do
            local dep = departs[classe] or departs[0]
            if dep and byId[dep] then
                local function visible(id)
                    local n = byId[id]
                    return n and not (n.kind == 2 and not SortPour(n, classe))
                end
                if not visible(dep) then
                    problems[#problems + 1] = fmt(
                        "le départ de la classe %d (%d) est un emplacement de sort sans sort pour elle", classe, dep)
                    Fautif(dep)
                else
                    local vus, file = { [dep] = true }, { dep }
                    while #file > 0 do
                        local cur = table.remove(file)
                        for _, nb in ipairs(adj[cur] or {}) do
                            if not vus[nb] and visible(nb) then
                                vus[nb] = true
                                file[#file + 1] = nb
                            end
                        end
                    end
                    local perdus = {}
                    for _, n in ipairs(nodes) do
                        if visible(n.id) and not vus[n.id] then perdus[#perdus + 1] = n.id end
                    end
                    if #perdus > 0 then
                        problems[#problems + 1] = fmt(
                            "classe %d : %d emplacement(s) hors d'atteinte de son départ (un sort invisible pour elle fait pont)",
                            classe, #perdus)
                        for _, id in ipairs(perdus) do Fautif(id) end
                    end
                end
            end
        end
    end

    local slots = 0
    for _, n in ipairs(nodes) do
        if n.kind == 1 then slots = slots + 1 end
    end

    -- EN LISTE, pas en table indexée par identifiant : AIO sérialise sans
    -- broncher un tableau dense, là où une table creuse à clés numériques se
    -- transporte moins sûrement.
    local fautifs = {}
    for id in pairs(marques) do fautifs[#fautifs + 1] = id end

    return {
        fautifs  = fautifs,
        departs  = nbDeparts,
        clusters = #clusters,
        nodes    = #nodes,
        slots    = slots,
        edges    = #edges,
        minSep   = worst,
        groups   = groups,
        problems = problems,
        ok       = (#problems == 0),
    }
end

-- ---------------------------------------------------------------------------
-- Écriture XML
-- ---------------------------------------------------------------------------

local function WriteXML(name, clusters, nodes, edges, depart)
    local path = DIR .. name .. ".xml"
    local f, err = io.open(path, "w")
    if not f then
        return nil, tostring(err)
    end

    f:write('<?xml version="1.0" encoding="UTF-8"?>\n')
    f:write('<spherier version="1" nom="', name, '">\n')

    f:write('  <clusters>\n')
    for _, c in ipairs(clusters) do
        f:write(fmt('    <cluster id="%d" x="%.4f" y="%.4f" rot="%.4f"/>\n',
            c.id, c.x, c.y, c.rot or 0))
    end
    f:write('  </clusters>\n')

    f:write('  <emplacements>\n')
    for _, n in ipairs(nodes) do
        if n.kind == 1 then
            f:write(fmt('    <emplacement id="%d" cluster="%d" anneau="%d" branche="%d" type="slot"/>\n',
                n.id, n.cluster, n.ring, n.branch))
        elseif n.kind == 2 then
            f:write(fmt('    <emplacement id="%d" cluster="%d" anneau="%d" branche="%d" type="sort" sort="%d"/>\n',
                n.id, n.cluster, n.ring, n.branch, n.sort or 0))
        elseif STATS[n.stat] then
            f:write(fmt('    <emplacement id="%d" cluster="%d" anneau="%d" branche="%d" type="noeud" stat="%s" qualite="%d"/>\n',
                n.id, n.cluster, n.ring, n.branch, STATS[n.stat].key, n.quality or 1))
        else
            -- Nœud vide (révision du 2026-08-23) : pas d'attribut stat.
            f:write(fmt('    <emplacement id="%d" cluster="%d" anneau="%d" branche="%d" type="noeud"/>\n',
                n.id, n.cluster, n.ring, n.branch))
        end
    end
    f:write('  </emplacements>\n')

    f:write('  <liaisons>\n')
    for _, e in ipairs(edges) do
        f:write(fmt('    <liaison a="%d" b="%d"/>\n', e[1] or e.a, e[2] or e.b))
    end
    f:write('  </liaisons>\n')

    -- Sorts par classe des emplacements de sort : une ligne par (emplacement,
    -- classe), triée ; l'attribut sort de l'emplacement garde le repli.
    local lignesSorts = {}
    for _, n in ipairs(nodes) do
        if n.kind == 2 then
            local s = Sorts(n.sorts)
            local classes = {}
            for classe in pairs(s) do classes[#classes + 1] = classe end
            table.sort(classes)
            for _, classe in ipairs(classes) do
                lignesSorts[#lignesSorts + 1] = fmt('    <sort emplacement="%d" classe="%d" id="%d"/>\n',
                    n.id, classe, s[classe])
            end
        end
    end
    if #lignesSorts > 0 then
        f:write('  <sorts>\n')
        for _, l in ipairs(lignesSorts) do f:write(l) end
        f:write('  </sorts>\n')
    end

    -- Un départ par ligne, la classe en attribut ; la clé 0 garde l'ancienne
    -- écriture sans classe, pour que les feuilles de classe ne changent pas.
    local departs = Departs(depart)
    local classes = {}
    for classe in pairs(departs) do classes[#classes + 1] = classe end
    table.sort(classes)
    for _, classe in ipairs(classes) do
        if classe == 0 then
            f:write(fmt('  <depart id="%d"/>\n', departs[classe]))
        else
            f:write(fmt('  <depart classe="%d" id="%d"/>\n', classe, departs[classe]))
        end
    end

    f:write('</spherier>\n')
    f:close()

    return path
end

-- ---------------------------------------------------------------------------
-- Lecture XML
-- ---------------------------------------------------------------------------
-- Le format est plat et sans texte libre : une lecture par motifs suffit et
-- évite d'embarquer un analyseur complet. Tout attribut absent prend une
-- valeur par défaut plutôt que de faire échouer l'import.

local function Attr(tag, key)
    return tag:match(key .. '%s*=%s*"([^"]*)"')
end

local function ReadXML(name)
    local path = DIR .. name .. ".xml"
    local f = io.open(path, "r")
    if not f then
        return nil, "fichier introuvable : " .. path
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

    for tag in text:gmatch("<emplacement%s+[^>]->") do
        local t = Attr(tag, "type")
        local kind = (t == "slot") and 1 or (t == "sort") and 2 or 0
        local n = {
            id      = tonumber(Attr(tag, "id")) or (#nodes + 1),
            cluster = tonumber(Attr(tag, "cluster")) or 0,
            ring    = tonumber(Attr(tag, "anneau")) or 1,
            branch  = tonumber(Attr(tag, "branche")) or 1,
            kind    = kind,
        }
        if kind == 0 then
            -- La pierre est optionnelle depuis la révision du 2026-08-23 : un
            -- nœud sans attribut stat est un nœud vide.
            n.stat = STAT_BY_KEY[Attr(tag, "stat") or ""]
            if n.stat then
                -- Borné : les dispositions d'avant le passage à cinq qualités
                -- peuvent porter l'indice 6.
                n.quality = math.min(#QUALITES, math.max(1, tonumber(Attr(tag, "qualite")) or 1))
            end
        elseif kind == 2 then
            n.sort = tonumber(Attr(tag, "sort")) or 0
        end
        nodes[#nodes + 1] = n
    end

    for tag in text:gmatch("<liaison%s+[^>]->") do
        local a, b = tonumber(Attr(tag, "a")), tonumber(Attr(tag, "b"))
        if a and b then edges[#edges + 1] = { a, b } end
    end

    -- Sorts par classe : « <sort … » ne prend ni la balise <sorts> ni
    -- l'attribut type="sort" des emplacements (le motif exige un blanc).
    local parId = {}
    for _, n in ipairs(nodes) do parId[n.id] = n end
    for tag in text:gmatch("<sort%s+[^>]->") do
        local n = parId[tonumber(Attr(tag, "emplacement")) or -1]
        local classe, id = tonumber(Attr(tag, "classe")), tonumber(Attr(tag, "id"))
        if n and n.kind == 2 and classe and id and id > 0 then
            n.sorts = n.sorts or {}
            n.sorts[classe] = id
        end
    end

    local departs = {}
    for tag in text:gmatch("<depart%s+[^>]->") do
        local id = tonumber(Attr(tag, "id"))
        local classe = tonumber(Attr(tag, "classe")) or 0
        if id then departs[classe] = id end
    end

    return { clusters = clusters, nodes = nodes, edges = edges, depart = departs }
end

-- ---------------------------------------------------------------------------
-- Handlers
-- ---------------------------------------------------------------------------
-- L'éditeur est réservé aux administrateurs. La garde vit ICI, dans chaque
-- handler, et pas seulement dans la commande : le client peut appeler AIO
-- directement (c'est ce que fait /spherier), le serveur fait donc foi.

local ADMIN_RANK = 3        -- SEC_ADMINISTRATOR

local function EstAdmin(player)
    -- Les bancs d'essai hors serveur (importeur, rendu) passent un joueur
    -- factice sans methodes : hors jeu, aucune securite a appliquer.
    if not player or type(player.GetGMRank) ~= "function" then return true end
    return player:GetGMRank() >= ADMIN_RANK
end

function SpherierHandlers.RequestSession(player)
    if not EstAdmin(player) then return end
    AIO.Handle(player, "Spherier", "ReceiveSession",
        GEOMETRY, STATS, QUALITES, SLOT_ICON, ReadIndex(), SEP_MIN)
end

function SpherierHandlers.Verify(player, clusters, nodes, edges, depart)
    if not EstAdmin(player) then return end
    AIO.Handle(player, "Spherier", "ReceiveReport",
        Verify(clusters or {}, nodes or {}, edges or {}, depart), nil)
end

function SpherierHandlers.Save(player, name, clusters, nodes, edges, depart)
    if not EstAdmin(player) then return end
    name = SafeName(name)
    clusters, nodes, edges = clusters or {}, nodes or {}, edges or {}

    local report = Verify(clusters, nodes, edges, depart)
    local path, err = WriteXML(name, clusters, nodes, edges, depart)

    if not path then
        report.problems[#report.problems + 1] = "écriture impossible : " .. tostring(err)
        report.ok = false
        AIO.Handle(player, "Spherier", "ReceiveReport", report, nil)
        return
    end

    AddToIndex(name)
    AIO.Handle(player, "Spherier", "ReceiveReport", report,
        fmt("Disposition « %s » enregistrée (%d emplacements).", name, #nodes))
    AIO.Handle(player, "Spherier", "ReceiveLayoutList", ReadIndex())
end

function SpherierHandlers.Load(player, name)
    if not EstAdmin(player) then return end
    name = SafeName(name)
    local data, err = ReadXML(name)
    if not data then
        AIO.Handle(player, "Spherier", "ReceiveReport",
            { problems = { tostring(err) }, ok = false, clusters = 0, nodes = 0,
              slots = 0, edges = 0, minSep = 0, groups = 0 }, nil)
        return
    end

    local report = Verify(data.clusters, data.nodes, data.edges, data.depart)
    AIO.Handle(player, "Spherier", "ReceiveLayout",
        data.clusters, data.nodes, data.edges, name, report, data.depart)
end

function SpherierHandlers.ListLayouts(player)
    if not EstAdmin(player) then return end
    AIO.Handle(player, "Spherier", "ReceiveLayoutList", ReadIndex())
end

-- ---------------------------------------------------------------------------
-- Point d'entrée : .spherier editor (admin)
-- ---------------------------------------------------------------------------
-- .spherier nu n'est PAS intercepté : il traverse vers la commande C++ du
-- module, dont le cœur affiche la liste des sous-commandes.
-- .spherier show appartient à l'interface joueur (Spherier_Joueur.lua).

-- Messages selon la langue du client : anglais par défaut, français si frFR —
-- même règle que les chaînes module_string du module C++.
local LOCALE_FRFR = 2               -- LocaleConstant frFR

local MESSAGES = {
    editeur_ouvert  = { "[Sphere grid] Editor opened.",
                        "[Sphèrier] Éditeur ouvert." },
    editeur_reserve = { "[Sphere grid] The editor is restricted to administrators.",
                        "[Sphèrier] L'éditeur est réservé aux administrateurs." },
}

local function Dire(player, cle)
    local m = MESSAGES[cle]
    player:SendBroadcastMessage(player:GetDbLocaleIndex() == LOCALE_FRFR and m[2] or m[1])
end

-- Erreur / opération impossible : le texte rouge standard au centre de
-- l'écran, comme les refus de Blizzard.
local function DireErreur(player, cle)
    local m = MESSAGES[cle]
    player:SendNotification(player:GetDbLocaleIndex() == LOCALE_FRFR and m[2] or m[1])
end

local function OnCommand(_, player, command)
    if not player then return end
    if not command then return end

    local cmd = command:lower()

    if cmd:match("^spherier%s+editor%s*$") then
        if EstAdmin(player) then
            AIO.Handle(player, "Spherier", "OpenEditor")
            Dire(player, "editeur_ouvert")
        else
            DireErreur(player, "editeur_reserve")
        end
        return false
    end
end

RegisterPlayerEvent(42, OnCommand)          -- PLAYER_EVENT_ON_COMMAND

print(fmt("Spherier: editeur charge, %d disposition(s) en magasin.", #ReadIndex()))
