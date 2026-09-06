--[[----------------------------------------------------------------------------
    Sphèrier Papota — interface joueur, côté serveur

    Sert la définition (tables papota_sphere_* de la base world, importées
    depuis l'éditeur) et l'état du personnage (character_sphere_*), et relaie
    les achats vers la commande `.spherier activate` du module C++, exécutée
    COMME le joueur : toutes les règles du jeu s'y appliquent (départ,
    adjacence, coût, classe) et les messages localisés partent de là. Les
    écritures du module sont synchrones : l'état relu ici est toujours frais.

    Ouverture : .spherier show, /spherier, ou le bouton de la fenêtre des
    talents. Ce fichier possède l'interception de `.spherier show` ;
    Spherier_Server.lua (l'éditeur) possède celle de `.spherier editor`.
------------------------------------------------------------------------------]]

local AIO = require("AIO")

local SpherierJoueurHandlers = AIO.AddHandlers("SpherierJoueur", {})

local fmt = string.format

local PIERRE_BASE = 803100
-- PIERRES DES NŒUDS (2026-09-05) : les emplacements pré-alloués portent leur
-- propre famille d'entrées (+2/+4/+6/+8/+10, gen_pierres_noeuds.py), les
-- pierres-objets gardent la leur. Même arithmétique, autre base.
local PIERRE_NOEUD_BASE = 803310

-- Clé de stat par indice, alignée sur l'allocation des pierres (SPHERIER_CONCEPTION.md §8).
local STAT_KEYS = {
    "endurance", "intelligence", "esprit", "dexterite", "force",
    "parade", "blocage", "esquive", "hate", "critique", "touche",
    "puissance_sorts", "puissance_attaque", "penetration_armure", "expertise", "bonus_soins",
}

-- Messages selon la langue du client (même règle que module_string).
local LOCALE_FRFR = 2
local MESSAGES = {
    pas_de_grille = { "[Sphere grid] No grid is defined for your class yet.",
                      "[Sphèrier] Aucune grille n'est encore définie pour votre classe." },
    -- Ni le coût, ni ce que le joueur possède : le refus dit seulement qu'il
    -- n'a pas de quoi (demande du 2026-08-26).
    spherite_insuffisante = { "Not enough Spherite.", "Spherite insuffisante." },
}

-- Erreur / opération impossible : le texte rouge standard au centre de
-- l'écran, comme les refus de Blizzard.
local function DireErreur(player, cle, ...)
    local m = MESSAGES[cle]
    local texte = player:GetDbLocaleIndex() == LOCALE_FRFR and m[2] or m[1]
    if select("#", ...) > 0 then texte = texte:format(...) end
    player:SendNotification(texte)
end

-- ---------------------------------------------------------------------------
-- Lecture de la définition (base world) — cache par classe, rafraîchi à chaque
-- ouverture (tables petites, ouverture rare).
-- ---------------------------------------------------------------------------

local DEF_CACHE = {}

-- L'EMPREINTE DE LA GRILLE (2026-09-05) : quelques agrégats sur les tables du
-- module, bien moins chers que de relire 2 500 emplacements. Elle change dès
-- qu'un export ou un réglage touche la base ; tant qu'elle tient, la
-- définition en cache reste bonne — et le client qui la porte déjà n'a rien à
-- recevoir.
local function Empreinte()
    local parts = {}
    local function agrege(sql)
        local q = WorldDBQuery(sql)
        if not q then parts[#parts + 1] = "-" return end
        local champs = {}
        for i = 0, q:GetColumnCount() - 1 do champs[#champs + 1] = tostring(q:GetString(i)) end
        parts[#parts + 1] = table.concat(champs, ",")
    end
    agrege("SELECT COUNT(*), COALESCE(SUM(node_id), 0), COALESCE(SUM(default_stone_entry), 0), "
        .. "COALESCE(SUM(spell_id), 0), COALESCE(SUM(class_id), 0), COALESCE(SUM(cluster), 0) FROM papota_sphere_node")
    agrege("SELECT COUNT(*), COALESCE(SUM(node_a), 0), COALESCE(SUM(node_b), 0) FROM papota_sphere_edge")
    agrege("SELECT COUNT(*), COALESCE(SUM(node_id), 0), COALESCE(SUM(spell_id), 0), COALESCE(SUM(class_id), 0) FROM papota_sphere_node_spell")
    agrege("SELECT COUNT(*), COALESCE(SUM(node_id), 0), COALESCE(SUM(class_id), 0) FROM papota_sphere_start")
    agrege("SELECT COUNT(*), COALESCE(SUM(cost), 0), COALESCE(SUM(activated_min), 0) FROM papota_sphere_cost")
    agrege("SELECT COUNT(*), COALESCE(SUM(amount), 0), COALESCE(SUM(stat_id), 0) FROM papota_sphere_stone")
    agrege("SELECT COUNT(*), COALESCE(SUM(first_spell_id), 0), COALESCE(SUM(base_rank), 0), COALESCE(SUM(class_id), 0) FROM papota_sphere_rune")
    agrege("SELECT COUNT(*), COALESCE(SUM(percent), 0) FROM papota_sphere_stat_rune")
    agrege("SELECT COALESCE(GROUP_CONCAT(valeur ORDER BY cle), '') FROM papota_sphere_config")
    return table.concat(parts, "|")
end

local function Entier(x)
    return math.floor((x or 0) * 10000 + 0.5)
end

-- LE FORMAT DU FIL : ce qui part vraiment au client. Tableaux positionnels
-- (aucune clé répétée deux mille fois), coordonnées entières au dix-millième,
-- et rien qui se déduise d'autre chose — la pierre suffit à retrouver stat,
-- montant, qualité et icône. Le client déplie (`DeplierDef`).
--   n : { id, kind, cluster, ring, branch, pierre, sort, x×10000, y×10000 }
--   e : { a1, b1, a2, b2, … }     c : { { id, x, y, rot } × 10000 }
--   b : { min1, cout1, min2, cout2, … }
local function Compacter(def, empreinte)
    local fil = { v = empreinte, n = {}, e = {}, c = {}, b = {},
                  pierres = def.pierres, runes = def.runes, runesStat = def.runesStat,
                  iconeParStat = def.iconeParStat, epingle = def.epingle,
                  classe = def.classe, depart = def.depart }
    for i, n in ipairs(def.nodes) do
        fil.n[i] = { n.id, n.kind, n.cluster, n.ring, n.branch, n.pierre or 0, n.sort or 0,
                     Entier(n.x), Entier(n.y) }
    end
    for _, e in ipairs(def.edges) do
        fil.e[#fil.e + 1] = e[1]
        fil.e[#fil.e + 1] = e[2]
    end
    for i, c in ipairs(def.clusters) do
        fil.c[i] = { c.id, Entier(c.x), Entier(c.y), Entier(c.rot) }
    end
    for _, t in ipairs(def.bareme) do
        fil.b[#fil.b + 1] = t.min
        fil.b[#fil.b + 1] = t.cout
    end
    return fil
end

-- Qualité d'une pierre, déduite de l'allocation figée au §8 :
-- entrée = 803100 + (stat − 1) × 5 + (qualité − 1). C'est la seule chose que
-- l'entrée dit d'elle-même ; l'effet chiffré, lui, vient toujours de la base.
local function QualitePierre(entry)
    if entry >= PIERRE_BASE and entry < PIERRE_BASE + 80 then
        return (entry - PIERRE_BASE) % 5 + 1
    end
    if entry >= PIERRE_NOEUD_BASE and entry < PIERRE_NOEUD_BASE + 80 then
        return (entry - PIERRE_NOEUD_BASE) % 5 + 1
    end
    return 0
end

-- Effet chiffré des pierres, lu une fois par ouverture : entrée -> stat, montant.
-- C'est papota_sphere_stone qui fait foi, jamais un calcul sur l'entrée.
local function ChargerPierres()
    local pierres = {}
    local q = WorldDBQuery("SELECT item_entry, stat_id, amount FROM papota_sphere_stone")
    if q then
        repeat
            local stat = STAT_KEYS[q:GetUInt32(1)]
            if stat then
                local entry = q:GetUInt32(0)
                pierres[entry] = { stat = stat, montant = q:GetInt32(2),
                                   qualite = QualitePierre(entry) }
            end
        until not q:NextRow()
    end
    return pierres
end

-- LA GRILLE COMMUNE (2026-09-05) : une classe qui n'a aucun emplacement en
-- propre lit la grille de la classe 0, commune à tous. Le départ, lui, reste
-- celui de la classe — `papota_sphere_start` en porte un par classe, posés sur
-- la grille commune.
local function ClasseGrille(classId)
    local q = WorldDBQuery(fmt(
        "SELECT COUNT(*) FROM papota_sphere_node WHERE class_id = %d", classId))
    if q and q:GetUInt32(0) > 0 then return classId end
    return 0
end

local function ChargerDefinition(classId)
    -- Même base, même grille : la définition en cache et son fil restent bons.
    local empreinte = Empreinte()
    local enCache = DEF_CACHE[classId]
    if enCache and enCache.empreinte == empreinte then return enCache end

    local def = { nodes = {}, edges = {}, clusters = {}, depart = 0, bareme = {} }
    local pierres = ChargerPierres()
    local grille = ClasseGrille(classId)

    local q = WorldDBQuery(fmt(
        "SELECT node_id, kind, grid_x, grid_y, icon, default_stone_entry, cluster, ring, branch, spell_id "
        .. "FROM papota_sphere_node WHERE class_id = %d", grille))
    if q then
        repeat
            local pierre = q:GetUInt32(5)
            local effet = pierres[pierre]
            local qualite = QualitePierre(pierre)
            -- stat reste nil pour un noeud vide (pierre = 0) : le client s'en
            -- sert pour distinguer le rendu. `montant` sert au récapitulatif,
            -- qui somme le potentiel de la grille entière.
            def.nodes[#def.nodes + 1] = {
                id = q:GetUInt32(0), kind = q:GetUInt32(1),
                x = q:GetFloat(2), y = q:GetFloat(3),
                icon = q:GetString(4),
                stat = effet and effet.stat or nil,
                montant = effet and effet.montant or 0,
                qualite = qualite,
                pierre = pierre,
                cluster = q:GetUInt32(6), ring = q:GetUInt32(7), branch = q:GetUInt32(8),
                sort = q:GetUInt32(9),
            }
        until not q:NextRow()
    end

    -- SORTS PAR CLASSE (2026-09-05) : sur la grille commune, l'emplacement de
    -- sort apprend à chaque classe le sien ; spell_id reste le repli.
    q = WorldDBQuery(fmt("SELECT node_id, spell_id FROM papota_sphere_node_spell WHERE class_id = %d", classId))
    if q then
        local propres = {}
        repeat
            propres[q:GetUInt32(0)] = q:GetUInt32(1)
        until not q:NextRow()
        for _, n in ipairs(def.nodes) do
            if n.kind == 2 and (propres[n.id] or 0) > 0 then n.sort = propres[n.id] end
        end
    end

    -- Un emplacement de sort sans sort pour la classe N'EXISTE PAS pour elle,
    -- ni ses liaisons : la grille envoyée ne les porte pas.
    local caches, gardes = {}, {}
    for _, n in ipairs(def.nodes) do
        if n.kind == 2 and (n.sort or 0) == 0 then caches[n.id] = true else gardes[#gardes + 1] = n end
    end
    def.nodes = gardes

    q = WorldDBQuery(fmt("SELECT node_a, node_b FROM papota_sphere_edge WHERE class_id = %d", grille))
    if q then
        repeat
            local a, b = q:GetUInt32(0), q:GetUInt32(1)
            if not caches[a] and not caches[b] then def.edges[#def.edges + 1] = { a, b } end
        until not q:NextRow()
    end

    q = WorldDBQuery(fmt("SELECT cluster_id, x, y, rot FROM papota_sphere_cluster WHERE class_id = %d", grille))
    if q then
        repeat
            def.clusters[#def.clusters + 1] =
                { id = q:GetUInt32(0), x = q:GetFloat(1), y = q:GetFloat(2), rot = q:GetFloat(3) }
        until not q:NextRow()
    end

    q = WorldDBQuery(fmt("SELECT node_id FROM papota_sphere_start WHERE class_id = %d", classId))
    if q then def.depart = q:GetUInt32(0) end

    -- Catalogue complet des pierres : le client s'en sert pour reconnaître,
    -- dans les sacs du joueur, ce qui est sertissable — et pour le décrire.
    def.pierres = pierres

    -- Runes de rang : entrée -> sort amélioré, et rang que la PREMIÈRE rune
    -- accorde. Le client s'en sert pour les reconnaître dans les sacs et les
    -- décrire ; la règle des trois par sort, elle, reste au module.
    -- La classe de la grille : le client en a besoin pour écarter les runes
    -- des autres classes, `UnitClass` ne rendant pas d'identifiant numérique
    -- en 3.3.5.
    def.classe = classId

    def.runes = {}
    q = WorldDBQuery("SELECT item_entry, first_spell_id, base_rank, base_spell_id, is_talent, "
                     .. "class_id FROM papota_sphere_rune")
    if q then
        repeat
            def.runes[q:GetUInt32(0)] = {
                sort = q:GetUInt32(1),
                rang = q:GetUInt32(2) + 1,
                qualite = 4,
                -- Le rang de Blizzard qu'il faut DEJA connaitre : sans lui la
                -- rune reste inerte, c'est la regle du module. On le nomme au
                -- joueur avant qu'il sertisse, mais seulement quand le sort
                -- vient d'un talent — ailleurs le pre-requis va de soi.
                requis = q:GetUInt32(3),
                talent = q:GetUInt32(4) ~= 0 or nil,
                -- Seule cette classe peut la sertir. Une rune se loote sans
                -- condition (§6) : c'est l'établi qui la rendra utile.
                classe = q:GetUInt32(5),
            }
        until not q:NextRow()
    end

    -- Runes de statistique : elles ne donnent pas de points, elles majorent
    -- d'un pourcentage ce que la GRILLE accorde dans cette statistique. Le
    -- pourcentage vient de la base, jamais du code.
    def.runesStat = {}
    q = WorldDBQuery("SELECT item_entry, stat_id, percent FROM papota_sphere_stat_rune")
    if q then
        repeat
            local stat = STAT_KEYS[q:GetUInt32(1)]
            if stat then
                def.runesStat[q:GetUInt32(0)] = {
                    stat = stat, pct = q:GetUInt32(2), qualite = 4,
                }
            end
        until not q:NextRow()
    end

    -- L'entrée de l'épingle vit en base, comme tout le reste : le client ne
    -- fait que compter celles du sac pour l'annoncer avant de confirmer.
    q = WorldDBQuery("SELECT valeur FROM papota_sphere_config WHERE cle = 'epingle_entry'")
    def.epingle = q and q:GetUInt32(0) or 0

    -- Icône par statistique, relevée sur la grille elle-même (chaque
    -- statistique y porte partout la même). Elle sert à afficher une pierre
    -- sertie qui n'est pas celle d'origine, sans chemin codé en dur nulle part.
    def.iconeParStat = {}
    for _, n in ipairs(def.nodes) do
        if n.stat and n.icon and n.icon ~= "" and not def.iconeParStat[n.stat] then
            def.iconeParStat[n.stat] = n.icon
        end
    end

    q = WorldDBQuery("SELECT activated_min, cost FROM papota_sphere_cost ORDER BY activated_min")
    if q then
        repeat
            def.bareme[#def.bareme + 1] = { min = q:GetUInt32(0), cout = q:GetUInt32(1) }
        until not q:NextRow()
    end

    def.empreinte = empreinte
    def.fil = Compacter(def, empreinte)
    DEF_CACHE[classId] = def
    return def
end

-- ---------------------------------------------------------------------------
-- État du personnage (base characters)
-- ---------------------------------------------------------------------------

local function ProchainCout(bareme, nbActifs)
    local cout = 0
    for _, t in ipairs(bareme) do
        if t.min > nbActifs then break end
        cout = t.cout
    end
    return cout
end

local function ChargerEtat(player, def)
    local guid = player:GetGUIDLow()
    local actives, contenu, brut, nbActifs = {}, {}, {}, 0
    local earned, spent = 0, 0
    local pierres = def.pierres or ChargerPierres()

    -- LE GAGNÉ EST AU COMPTE, LA DÉPENSE AU PERSONNAGE (2026-09-04). Deux
    -- requêtes, donc, et le disponible se lit « gagné du compte moins dépensé
    -- de ce personnage-ci ».
    local q = CharDBQuery(fmt(
        "SELECT earned FROM account_sphere_points WHERE account_id = %d",
        player:GetAccountId()))
    if q then earned = q:GetUInt32(0) end
    q = CharDBQuery(fmt(
        "SELECT spent FROM character_sphere_points WHERE guid = %d", guid))
    if q then spent = q:GetUInt32(0) end

    q = CharDBQuery(fmt("SELECT node_id, content_entry FROM character_sphere_node WHERE guid = %d", guid))
    if q then
        repeat
            local node, entree = q:GetUInt32(0), q:GetUInt32(1)
            actives[node] = true
            nbActifs = nbActifs + 1
            -- `brut` dit ce que l'emplacement porte vraiment, y compris 0 : c'est
            -- lui qui distingue un emplacement actif VIDE (sertissable) d'un
            -- emplacement garni (épinglable). `contenu` n'existe que pour les
            -- pierres, dont l'effet est connu.
            brut[node] = entree
            local effet = pierres[entree]
            if effet then
                contenu[node] = { stat = effet.stat, montant = effet.montant,
                                  qualite = effet.qualite }
            end
        until not q:NextRow()
    end

    -- LE CONTENU DES NŒUDS À PIERRES APPARTIENT AU COMPTE (2026-09-06) : la
    -- ligne de compte prime, sinon la pierre d'origine du nœud — même règle
    -- que le module (SpherierPlayerMgr::Charger). Slots et sorts : personnage.
    local kindParId, pierreParId = {}, {}
    for _, n in ipairs(def.nodes) do
        kindParId[n.id], pierreParId[n.id] = n.kind, n.pierre or 0
    end
    local compte = {}
    q = CharDBQuery(fmt("SELECT node_id, content_entry FROM account_sphere_node WHERE account_id = %d",
        player:GetAccountId()))
    if q then
        repeat compte[q:GetUInt32(0)] = q:GetUInt32(1) until not q:NextRow()
    end
    for node in pairs(actives) do
        if kindParId[node] == 0 then
            local entree = compte[node]
            if entree == nil then entree = pierreParId[node] end
            brut[node] = entree
        end
    end

    -- Les pre-requis que le joueur remplit VRAIMENT, ici et maintenant : ils
    -- changent avec ses talents, donc ils suivent l'etat et non le catalogue.
    -- Seuls les vrais sont envoyes ; l'absence vaut « non rempli ».
    local requisOk = {}
    for entree, r in pairs(def.runes or {}) do
        if r.requis and r.requis > 0 and player:HasSpell(r.requis) then
            requisOk[entree] = true
        end
    end

    -- `actives` et `contenu` se déduisent de `brut` avec le catalogue des
    -- pierres : le client les reconstitue (`DeplierEtat`), le fil ne porte
    -- que l'entrée de chaque emplacement actif.
    return {
        brut         = brut,
        -- Le contenu de compte de TOUS les nœuds à pierres, achetés ou non :
        -- un nœud vidé sur un autre personnage se montre vide ici aussi.
        contenuCompte = compte,
        requisOk     = requisOk,
        nbActifs     = nbActifs,
        disponibles  = (earned > spent) and (earned - spent) or 0,
        prochainCout = ProchainCout(def.bareme, nbActifs),
    }
end

-- ---------------------------------------------------------------------------
-- Handlers
-- ---------------------------------------------------------------------------

-- Catalogue des objets du sphèrier, demandé par le client dès son chargement.
-- Sans lui, un clic droit sur une pierre AVANT la première ouverture de la
-- fenêtre ne serait pas reconnu : le client ne saurait pas que c'en est une.
function SpherierJoueurHandlers.Catalogue(player)
    local def = ChargerDefinition(player:GetClass())
    AIO.Handle(player, "SpherierJoueur", "Catalogue", {
        pierres      = def.pierres,
        runes        = def.runes,
        runesStat    = def.runesStat,
        epingle      = def.epingle,
        iconeParStat = def.iconeParStat,
    })
end

-- LA SPHERITE PEUT ARRIVER SANS QUE LE JOUEUR TOUCHE À L'INTERFACE : un Nexus
-- consommé, un boss tombé, un donjon fini. Ce crédit se fait côté C++, qui n'a
-- aucun moyen d'adresser un message AIO — c'est donc le client qui demande, et
-- seulement tant que sa fenêtre est ouverte.
--
-- DEUX HANDLERS PLUTÔT QU'UN, pour ne rien redessiner dans le vide : celui-ci
-- ne rend QUE le nombre, d'une seule requête ; le client ne réclame l'état
-- complet, plus cher, que s'il a bougé.
function SpherierJoueurHandlers.Points(player)
    local earned, spent = 0, 0
    local q = CharDBQuery(fmt(
        "SELECT earned FROM account_sphere_points WHERE account_id = %d",
        player:GetAccountId()))
    if q then earned = q:GetUInt32(0) end
    q = CharDBQuery(fmt(
        "SELECT spent FROM character_sphere_points WHERE guid = %d",
        player:GetGUIDLow()))
    if q then spent = q:GetUInt32(0) end
    AIO.Handle(player, "SpherierJoueur", "Points",
        (earned > spent) and (earned - spent) or 0)
end

-- L'état complet, sans la définition de la grille : le client l'a déjà.
function SpherierJoueurHandlers.Rafraichir(player)
    local def = ChargerDefinition(player:GetClass())
    if #def.nodes == 0 then return end
    AIO.Handle(player, "SpherierJoueur", "MettreAJour", ChargerEtat(player, def))
end

-- LA DÉFINITION NE PART QU'UNE FOIS PAR VERSION (2026-09-05) : le client dit
-- l'empreinte qu'il tient ; si c'est la bonne, seul l'état voyage (`false` à
-- la place du fil — un nil au milieu des arguments ne se transporte pas).
function SpherierJoueurHandlers.Ouvrir(player, version)
    local def = ChargerDefinition(player:GetClass())
    if #def.nodes == 0 then
        DireErreur(player, "pas_de_grille")
        return
    end
    local fil = (version == def.empreinte) and false or def.fil
    AIO.Handle(player, "SpherierJoueur", "Afficher", fil, ChargerEtat(player, def), def.empreinte)
end

function SpherierJoueurHandlers.Acheter(player, nodeId)
    if type(nodeId) ~= "number" then return end

    -- Exécutée comme le joueur (sa session, sa sécurité) : le module C++
    -- applique les règles et répond dans sa langue. Écriture synchrone.
    player:RunCommand("spherier activate " .. math.floor(nodeId))

    local def = DEF_CACHE[player:GetClass()] or ChargerDefinition(player:GetClass())
    AIO.Handle(player, "SpherierJoueur", "MettreAJour", ChargerEtat(player, def))
end

-- Achat d'un chemin entier, dans l'ordre (du domaine actif vers la cible),
-- tout ou rien : le coût total est verrouillé AVANT le premier achat — sans
-- cela un chemin trop cher s'achèterait à moitié.
function SpherierJoueurHandlers.AcheterChemin(player, chemin)
    if type(chemin) ~= "table" or #chemin == 0 or #chemin > 300 then return end

    local def = DEF_CACHE[player:GetClass()] or ChargerDefinition(player:GetClass())
    local etat = ChargerEtat(player, def)

    local total = 0
    for i = 1, #chemin do
        if type(chemin[i]) ~= "number" then return end
        total = total + ProchainCout(def.bareme, etat.nbActifs + i - 1)
    end
    if etat.disponibles < total then
        DireErreur(player, "spherite_insuffisante")
        return
    end

    -- Achat séquentiel par la commande du module : chaque étape re-vérifie
    -- toutes les règles (l'ordre du chemin satisfait l'adjacence). Les
    -- écritures étant synchrones, un échec se voit immédiatement — on
    -- s'arrête là, le module a déjà affiché son erreur au joueur.
    local guid = player:GetGUIDLow()
    for _, nodeId in ipairs(chemin) do
        nodeId = math.floor(nodeId)
        player:RunCommand("spherier activate " .. nodeId)
        if not CharDBQuery(fmt(
            "SELECT 1 FROM character_sphere_node WHERE guid = %d AND node_id = %d", guid, nodeId)) then
            break
        end
    end

    AIO.Handle(player, "SpherierJoueur", "MettreAJour", ChargerEtat(player, def))
end

-- Sertissage et épingle : mêmes principes que l'achat — la commande du module
-- porte TOUTES les règles (emplacement actif, type compatible, objet en sac,
-- destruction du contenu) et répond au joueur dans sa langue. Le Lua ne fait
-- que transmettre et rafraîchir. Les écritures du module étant synchrones,
-- l'état relu juste après est déjà le bon.
-- Le client refuse l'achat avant même de le proposer quand la Spherite manque ;
-- il passe par ici pour que le message emprunte le canal rouge habituel, avec
-- le même texte que le refus du serveur. Rien n'est modifié, rien n'est lu.
function SpherierJoueurHandlers.Refuser(player)
    DireErreur(player, "spherite_insuffisante")
end

function SpherierJoueurHandlers.Sertir(player, nodeId, itemEntry)
    if type(nodeId) ~= "number" or type(itemEntry) ~= "number" then return end
    nodeId, itemEntry = math.floor(nodeId), math.floor(itemEntry)
    if nodeId <= 0 or itemEntry <= 0 then return end

    player:RunCommand(fmt("spherier socket %d %d", nodeId, itemEntry))

    local def = DEF_CACHE[player:GetClass()] or ChargerDefinition(player:GetClass())
    AIO.Handle(player, "SpherierJoueur", "MettreAJour", ChargerEtat(player, def))
end

function SpherierJoueurHandlers.Epingler(player, nodeId)
    if type(nodeId) ~= "number" then return end
    nodeId = math.floor(nodeId)
    if nodeId <= 0 then return end

    player:RunCommand(fmt("spherier unsocket %d", nodeId))

    local def = DEF_CACHE[player:GetClass()] or ChargerDefinition(player:GetClass())
    AIO.Handle(player, "SpherierJoueur", "MettreAJour", ChargerEtat(player, def))
end

-- ---------------------------------------------------------------------------
-- Point d'entrée : .spherier show
-- ---------------------------------------------------------------------------

local function OnCommand(_, player, command)
    if not player then return end
    if not command then return end

    if command:lower():match("^spherier%s+show%s*$") then
        SpherierJoueurHandlers.Ouvrir(player)
        return false
    end
end

RegisterPlayerEvent(42, OnCommand)          -- PLAYER_EVENT_ON_COMMAND

print("Spherier: interface joueur chargee.")
