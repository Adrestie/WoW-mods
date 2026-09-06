--[[----------------------------------------------------------------------------
    importe_layout.lua — disposition XML de l'editeur -> SQL des tables de
    definition du module mod-papota-spherier (papota_sphere_node / edge / start).

    Usage, repertoire de travail = bin\RelWithDebInfo du serveur :
      lua52_interpreter.exe D:\...\importe_layout.lua <disposition> <class_id>
                            [depart_xml_id] [sortie.sql]

    Regenerable a volonte : le SQL produit remplace integralement la classe
    (DELETE puis INSERT). Il s'applique a la main (mysql), puis .spherier reload.

    La lecture, le controle et la geometrie sont ceux de Spherier_Server.lua,
    charge avec un AIO factice (motif des bancs d'essai) : aucune constante
    n'est dupliquee ici.

    Allocations, aussi documentees dans SPHERIER_CONCEPTION.md :
      node_id            = class_id * 10000 + id XML
      pierre pre-allouee = 803310 + (stat - 1) * 5 + (qualite - 1)  (famille des noeuds)

    Le point de depart vient du marquage de l'editeur (balise <depart> du XML) ;
    depart_xml_id, s'il est fourni, prime. Sans ni l'un ni l'autre : refus.
------------------------------------------------------------------------------]]

local nomDisposition = arg[1]
local classId        = tonumber(arg[2] or "")
local departArg      = tonumber(arg[3] or "")
local cheminSortie   = arg[4]

assert(nomDisposition,
    "usage : importe_layout.lua <disposition> <class_id> [depart_xml_id] [sortie.sql]")
-- LA CLASSE 0 EST LA GRILLE COMMUNE (2026-09-05) : une seule grille pour tout
-- le monde, dix departs — un par classe — et des identifiants sans decalage
-- (0 x 10000 + id XML). Le module retombe sur elle quand une classe n'a pas
-- de grille propre.
assert(classId and classId >= 0 and classId <= 11 and classId ~= 10,
    "class_id invalide (0 = grille commune, classes WotLK : 1-9 et 11)")
local COMMUNE = (classId == 0)
local CLASSES = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 11 }

-- PIERRES DES NOEUDS (2026-09-05) : un emplacement pre-alloue porte une entree
-- de sa propre famille (+2/+4/+6/+8/+10, gen_pierres_noeuds.py), pas celle de
-- la pierre-objet de meme qualite (+5/+7/+10/+15/+30).
local PIERRE_BASE = 803310
local OFFSET      = classId * 10000

-- ---------------------------------------------------------------------------
-- Chargement de Spherier_Server.lua avec un AIO factice
-- ---------------------------------------------------------------------------

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

-- ---------------------------------------------------------------------------
-- Session (catalogue + geometrie) puis disposition
-- ---------------------------------------------------------------------------

H.RequestSession({})
local session = assert(Derniere("ReceiveSession"), "RequestSession sans reponse")
local GEOMETRY, STATS, QUALITES, SLOT_ICON = session[1], session[2], session[3], session[4]

H.Load({}, nomDisposition)
local charge = Derniere("ReceiveLayout")
if not charge then
    local rapport = Derniere("ReceiveReport")
    error("chargement impossible : "
        .. table.concat((rapport and rapport[1].problems) or { "raison inconnue" }, " ; "))
end
local clusters, nodes, edges, departXml = charge[1], charge[2], charge[3], charge[6]

-- LES DEPARTS SONT UNE TABLE classe -> emplacement (l'ancienne forme, un
-- nombre, est encore acceptee). Une grille de classe en a un, sous la cle 0 ;
-- la grille commune en veut un par classe.
local departs = {}
if type(departXml) == "number" then
    departs[0] = departXml
elseif type(departXml) == "table" then
    for c, id in pairs(departXml) do departs[tonumber(c)] = tonumber(id) end
end
-- L'argument de la ligne de commande prime, pour une grille de classe.
if departArg then departs = { [0] = departArg } end

if COMMUNE then
    local manquantes = {}
    for _, c in ipairs(CLASSES) do
        if not departs[c] then manquantes[#manquantes + 1] = c end
    end
    if #manquantes > 0 then
        error("grille commune : depart manquant pour la ou les classes "
            .. table.concat(manquantes, ", ")
            .. " — marquez-les dans l'editeur (bouton « Depart : <classe> »)")
    end
else
    local depart = departs[0] or departs[classId]
    if not depart then
        error("aucun point de depart : marquez-le dans l'editeur (bouton « Definir comme depart »)"
            .. " ou passez depart_xml_id en 3e argument")
    end
    departs = { [classId] = depart }
end

-- Controle complet avec les departs resolus — c'est le Verify de l'editeur.
H.Verify({}, clusters, nodes, edges, departs)
local verif = Derniere("ReceiveReport")
local report = verif and verif[1]
if not report or #report.problems > 0 then
    error("la disposition a des defauts, a corriger dans l'editeur : "
        .. table.concat((report and report.problems) or { "verification muette" }, " ; "))
end

-- ---------------------------------------------------------------------------
-- Positions (formule de l'editeur, rayons venus de la session)
-- ---------------------------------------------------------------------------

local cParId = {}
for _, c in ipairs(clusters) do cParId[c.id] = c end

-- Même formule que NodePosition dans Spherier_Server.lua, y compris son cas
-- particulier : un anneau SANS RAYON est la place centrale du cluster, ajoutée
-- à la révision du 2026-08-23. L'assertion qui régnait ici refusait l'anneau 0
-- et bloquait l'import de toute disposition en contenant une.
local function Position(n)
    local c = assert(cParId[n.cluster], "cluster inconnu " .. tostring(n.cluster))
    local r = GEOMETRY.radii[n.ring]
    if not r then return c.x, c.y end
    local a = (c.rot or 0) + (n.branch - 1) * 2 * math.pi / GEOMETRY.branches
    return c.x + r * math.cos(a), c.y + r * math.sin(a)
end

-- ---------------------------------------------------------------------------
-- Emission SQL
-- ---------------------------------------------------------------------------

local function Sql(s)
    return (tostring(s):gsub("\\", "\\\\"):gsub("'", "''"))
end

local L = {}
local function Ligne(s, ...)
    L[#L + 1] = select("#", ...) > 0 and string.format(s, ...) or s
end

Ligne("-- Genere par importe_layout.lua — disposition « %s », classe %d.", nomDisposition, classId)
Ligne("-- Regenerable : remplace integralement la classe %d (DELETE puis INSERT).", classId)
Ligne("-- node_id = class_id * 10000 + id XML ; pierre de noeud = 803310 + (stat-1)*5 + (qualite-1).")
Ligne("")
if COMMUNE then
    -- LA GRILLE COMMUNE REMPLACE TOUTES LES GRILLES DE CLASSE : le module ne
    -- retombe sur la classe 0 que si la classe du joueur n'a rien. On efface
    -- donc tout, et l'on pose les dix departs sur la grille commune.
    Ligne("-- Grille COMMUNE : remplace les dix grilles de classe (le module retombe")
    Ligne("-- sur la classe 0 quand une classe n'a pas de grille propre).")
    Ligne("DELETE FROM `papota_sphere_node_spell`;")
    Ligne("DELETE FROM `papota_sphere_edge`;")
    Ligne("DELETE FROM `papota_sphere_start`;")
    Ligne("DELETE FROM `papota_sphere_node`;")
    Ligne("DELETE FROM `papota_sphere_cluster`;")
else
    -- La table des sorts par classe n'a pas de class_id de grille : sa classe
    -- est celle du SORT. On efface par plage d'identifiants d'emplacement.
    Ligne("DELETE FROM `papota_sphere_node_spell` WHERE `node_id` BETWEEN %d AND %d;", OFFSET, OFFSET + 9999)
    Ligne("DELETE FROM `papota_sphere_edge` WHERE `class_id` = %d;", classId)
    Ligne("DELETE FROM `papota_sphere_start` WHERE `class_id` = %d;", classId)
    Ligne("DELETE FROM `papota_sphere_node` WHERE `class_id` = %d;", classId)
    Ligne("DELETE FROM `papota_sphere_cluster` WHERE `class_id` = %d;", classId)
end
Ligne("")

-- Geometrie des clusters, pour le rendu des arcs par l'interface joueur.
Ligne("INSERT INTO `papota_sphere_cluster` (`class_id`, `cluster_id`, `x`, `y`, `rot`) VALUES")
for i, c in ipairs(clusters) do
    Ligne("(%d, %d, %.4f, %.4f, %.4f)%s", classId, c.id, c.x, c.y, c.rot or 0,
        (i == #clusters) and ";" or ",")
end
Ligne("")

local nbNoeuds, nbVides, nbSlots, nbSorts = 0, 0, 0, 0
Ligne("INSERT INTO `papota_sphere_node` (`node_id`, `class_id`, `kind`, `grid_x`, `grid_y`, `icon`, `name`, `default_stone_entry`, `spell_id`, `cluster`, `ring`, `branch`) VALUES")
for i, n in ipairs(nodes) do
    assert(n.id < 10000, "id XML " .. n.id .. " >= 10000, hors plage de l'offset")
    local x, y = Position(n)
    local icone, nom, pierre, sortId = "", "", 0, 0
    if n.kind == 1 then
        nbSlots = nbSlots + 1
        icone, nom = SLOT_ICON, "Slot de rune"
    elseif n.kind == 2 then
        nbSorts = nbSorts + 1
        nom, sortId = "Sort", n.sort or 0
    elseif n.stat then
        nbNoeuds = nbNoeuds + 1
        local s = assert(STATS[n.stat], "stat inconnue " .. tostring(n.stat))
        local q = assert(QUALITES[n.quality], "qualite inconnue " .. tostring(n.quality))
        icone = s.icon
        nom   = string.format("%s (%s)", s.label, q.label)
        pierre = PIERRE_BASE + (n.stat - 1) * 5 + (n.quality - 1)
    else
        -- Noeud vide (revision du 2026-08-23) : legal, sans pierre pre-allouee.
        nbNoeuds = nbNoeuds + 1
        nbVides  = nbVides + 1
        nom = "Noeud vide"
    end
    Ligne("(%d, %d, %d, %.4f, %.4f, '%s', '%s', %d, %d, %d, %d, %d)%s",
        OFFSET + n.id, classId, n.kind, x, y, Sql(icone), Sql(nom), pierre, sortId,
        n.cluster, n.ring, n.branch,
        (i == #nodes) and ";" or ",")
end
Ligne("")

-- Sorts par classe des emplacements de sort (grille commune, 2026-09-05) :
-- une ligne par (emplacement, classe) ; spell_id de l'emplacement reste le
-- repli « toutes classes », lu par le module quand la classe n'a rien ici.
local lignesSorts = {}
for _, n in ipairs(nodes) do
    if n.kind == 2 and type(n.sorts) == "table" then
        local classes = {}
        for c in pairs(n.sorts) do classes[#classes + 1] = tonumber(c) end
        table.sort(classes)
        for _, c in ipairs(classes) do
            local id = tonumber(n.sorts[c]) or 0
            if id > 0 then
                lignesSorts[#lignesSorts + 1] = string.format("(%d, %d, %d)", OFFSET + n.id, c, id)
            end
        end
    end
end
if #lignesSorts > 0 then
    Ligne("INSERT INTO `papota_sphere_node_spell` (`node_id`, `class_id`, `spell_id`) VALUES")
    for i, l in ipairs(lignesSorts) do
        Ligne("%s%s", l, (i == #lignesSorts) and ";" or ",")
    end
    Ligne("")
end

if #edges > 0 then
    Ligne("INSERT INTO `papota_sphere_edge` (`class_id`, `node_a`, `node_b`) VALUES")
    for i, e in ipairs(edges) do
        local a, b = e[1] or e.a, e[2] or e.b
        Ligne("(%d, %d, %d)%s", classId, OFFSET + a, OFFSET + b,
            (i == #edges) and ";" or ",")
    end
    Ligne("")
end

local classesTriees = {}
for c in pairs(departs) do classesTriees[#classesTriees + 1] = c end
table.sort(classesTriees)
local lignesDepart = {}
for _, c in ipairs(classesTriees) do
    lignesDepart[#lignesDepart + 1] = string.format("(%d, %d)", c, OFFSET + departs[c])
end
Ligne("INSERT INTO `papota_sphere_start` (`class_id`, `node_id`) VALUES %s;",
    table.concat(lignesDepart, ", "))
local depart = departs[classesTriees[1]]

cheminSortie = cheminSortie
    or string.format("D:\\Serveur WoW\\outils_spherier\\sql\\spherier_classe_%d.sql", classId)
local f = assert(io.open(cheminSortie, "w"))
f:write(table.concat(L, "\n"), "\n")
f:close()

print(string.format(
    "SQL ecrit : %s\n  classe %d, %d emplacements (%d noeuds dont %d vides, %d slots, %d sorts), %d liaisons, %d sorts par classe, depart %d (XML %d).",
    cheminSortie, classId, #nodes, nbNoeuds, nbVides, nbSlots, nbSorts, #edges, #lignesSorts, OFFSET + depart, depart))
