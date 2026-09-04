--[[----------------------------------------------------------------------------
    Amélioration d'objets (mod-item-upgrade) — côté serveur (ALE + AIO)

    L'interface client (ItemUpgrade_Client.lua, expédiée par AIO) ne décide de
    rien : elle DEMANDE, ce script VALIDE puis pilote le module C++ par ses
    commandes joueur (.item_upgrade getstats | doupgrade). Le module C++ reste la
    seule autorité sur l'état en mémoire (rangs achetés, valeurs appliquées) :
    ses réponses partent directement au client sous forme de messages d'addon
    (préfixe ITEMUPGRADE_RESP : « STATS … », « UPGRADE SUCCESS »).

    Ce script apporte ce que le C++ ne fournit pas au client : le barème
    (pourcentage par rang), les coûts de chaque rang (or, honneur, arène,
    jetons, surcharges par objet), les statistiques du gabarit de l'objet (pour
    afficher aussi celles qui sont au rang maximum) et un pré-contrôle des
    ressources avant l'achat. Tout est relu en base au chargement du script :
    après une modification du barème, `.item_upgrade reload` PUIS `.reload ale`.

    Garde-fou : la commande C++ `getstats` n'est jamais appelée sans avoir
    vérifié que l'objet existe (le module déréférence l'objet sans contrôle).
------------------------------------------------------------------------------]]
local AIO = AIO or require("AIO")
local Handlers = AIO.AddHandlers("ItemUpgrade", {})
local fmt = string.format

local CONF = "configs/modules/mod_item_upgrade.conf"
local JETONS = { 801050, 801051, 801052, 801053, 801054 }   -- Éclat, Fragment, Noyau, Gemme, Couronne
local MAX_STATS_OBJET = 10                                  -- MAX_ITEM_PROTO_STATS (3.3.5)

-- ---------------------------------------------------------------------------
-- Configuration du module, lue une fois par chargement du script
-- ---------------------------------------------------------------------------
local function LireConf()
    local actif, autorisees = true, nil
    local f = io.open(CONF, "r")
    if not f then
        return actif, autorisees
    end
    for ligne in f:lines() do
        local cle, val = ligne:match("^%s*ItemUpgrade%.(%w+)%s*=%s*([^\r\n]*)")
        if cle == "Enable" then
            actif = (tonumber(val:match("%d+") or "1") ~= 0)
        elseif cle == "AllowedStats" then
            autorisees = {}
            for n in val:gmatch("%d+") do
                autorisees[tonumber(n)] = true
            end
        end
    end
    f:close()
    return actif, autorisees
end
local ACTIF, AUTORISEES = LireConf()

-- ---------------------------------------------------------------------------
-- Barème et coûts, relus en base characters au chargement
-- ---------------------------------------------------------------------------
local BAREME = {}      -- [statType] = { pct = { [rang] = pct }, id = { [rang] = statId }, max = n }
local COUTS = {}       -- [statId] = { c = cuivre, h = honneur, a = arène, o = { {objet, nombre}, ... } }
local SURCHARGES = {}  -- [entry] = { [statId] = coût }
local RANG_MAX = 0

local function NouveauCout()
    return { c = 0, h = 0, a = 0, o = {} }
end

local function AjouterCout(table_, cle, typ, v1, v2)
    local c = table_[cle]
    if not c then
        c = NouveauCout()
        table_[cle] = c
    end
    if typ == 1 then
        c.c = c.c + math.floor(v1)
    elseif typ == 2 then
        c.h = c.h + math.floor(v1)
    elseif typ == 3 then
        c.a = c.a + math.floor(v1)
    elseif typ == 4 then
        table.insert(c.o, { math.floor(v1), math.floor(v2) })
    end
    -- typ 5 (REQ_TYPE_NONE) : rang gratuit, rien à ajouter
end

local function Charger()
    BAREME, COUTS, SURCHARGES, RANG_MAX = {}, {}, {}, 0
    local q = CharDBQuery("SELECT id, stat_type, stat_mod_pct, stat_rank FROM mod_item_upgrade_stats")
    if q then
        repeat
            local id, t, pct, r = q:GetUInt32(0), q:GetUInt32(1), q:GetFloat(2), q:GetUInt32(3)
            local b = BAREME[t]
            if not b then
                b = { pct = {}, id = {}, max = 0 }
                BAREME[t] = b
            end
            b.pct[r] = pct
            b.id[r] = id
            if r > b.max then b.max = r end
            if r > RANG_MAX then RANG_MAX = r end
        until not q:NextRow()
    end
    q = CharDBQuery("SELECT stat_id, req_type, IFNULL(req_val1, 0), IFNULL(req_val2, 0) FROM mod_item_upgrade_stats_req")
    if q then
        repeat
            AjouterCout(COUTS, q:GetUInt32(0), q:GetUInt32(1), q:GetFloat(2), q:GetFloat(3))
        until not q:NextRow()
    end
    q = CharDBQuery("SELECT item_entry, stat_id, req_type, IFNULL(req_val1, 0), IFNULL(req_val2, 0) FROM mod_item_upgrade_stats_req_override")
    if q then
        repeat
            local e = q:GetUInt32(0)
            SURCHARGES[e] = SURCHARGES[e] or {}
            AjouterCout(SURCHARGES[e], q:GetUInt32(1), q:GetUInt32(2), q:GetFloat(3), q:GetFloat(4))
        until not q:NextRow()
    end
    print(fmt("[ItemUpgrade] barème chargé : %d statistiques, rang maximum %d, %d surcharges d'objet",
              (function() local n = 0; for _ in pairs(BAREME) do n = n + 1 end; return n end)(),
              RANG_MAX, (function() local n = 0; for _ in pairs(SURCHARGES) do n = n + 1 end; return n end)()))
end
Charger()

-- Coût du rang `rang` de la statistique `statType` pour l'objet `entry`
-- (surcharge par objet d'abord, comme ItemUpgrade::GetStatRequirements).
local function Cout(entry, statType, rang)
    local b = BAREME[statType]
    if not b then return nil end
    local id = b.id[rang]
    if not id then return nil end
    local s = SURCHARGES[entry]
    return (s and s[id]) or COUTS[id] or NouveauCout()
end

-- ---------------------------------------------------------------------------
-- Objet : recherche, statistiques du gabarit (base world), barème des types
-- ---------------------------------------------------------------------------
-- Player:GetItemByEntry ne regarde QUE les sacs (PlayerStorage.cpp) : l'objet
-- équipé, cas d'usage principal, lui échappe. On balaie donc l'équipement
-- d'abord — le même ordre que FindItemInInventory du module C++, pour que
-- l'exemplaire lu ici soit celui que la commande améliorera.
local EQUIPMENT_SLOT_END = 19

local function TrouverObjet(player, entry)
    for slot = 0, EQUIPMENT_SLOT_END - 1 do
        local item = player:GetEquippedItemBySlot(slot)
        if item and item:GetEntry() == entry then
            return item
        end
    end
    return player:GetItemByEntry(entry)
end

-- item_template ne porte pas de colonne de comptage : les dix paires sont
-- lues telles quelles et seules les valeurs positives comptent, exactement
-- comme ItemUpgrade::LoadItemStatInfo.
local COLONNES_STATS = "stat_type1, stat_value1"
for i = 2, MAX_STATS_OBJET do
    COLONNES_STATS = COLONNES_STATS .. fmt(", stat_type%d, stat_value%d", i, i)
end

local function StatsGabarit(entry)
    local stats = {}
    local q = WorldDBQuery(fmt("SELECT %s FROM item_template WHERE entry = %d", COLONNES_STATS, entry))
    if not q then return stats end
    for i = 1, MAX_STATS_OBJET do
        local t, v = q:GetUInt32(2 * i - 2), q:GetInt32(2 * i - 1)
        if v > 0 and BAREME[t] and (not AUTORISEES or AUTORISEES[t]) then
            table.insert(stats, { type = t, base = v })
        end
    end
    return stats
end

local function Objet(player, entry)
    local item = TrouverObjet(player, entry)
    if not item then return nil end
    local objet = {
        entry = entry,
        lien = item:GetItemLink(),
        stats = StatsGabarit(entry),
        bareme = {},
        rangMax = RANG_MAX,
        actif = ACTIF,
    }
    for _, s in ipairs(objet.stats) do
        local b = BAREME[s.type]
        local couts = {}
        for r = 1, b.max do
            couts[r] = Cout(entry, s.type, r) or NouveauCout()
        end
        objet.bareme[s.type] = { pct = b.pct, max = b.max, couts = couts }
    end
    return objet
end

-- Rangs déjà achetés sur cet exemplaire (base characters). Sert au pré-contrôle
-- des ressources seulement : le module C++ re-vérifie chaque achat.
local function RangsEnBase(player, item)
    local rangs = {}
    local q = CharDBQuery(fmt(
        "SELECT s.stat_type, s.stat_rank FROM character_item_upgrade u " ..
        "JOIN mod_item_upgrade_stats s ON s.id = u.stat_id WHERE u.guid = %d AND u.item_guid = %d",
        player:GetGUIDLow(), item:GetGUIDLow()))
    if q then
        repeat
            rangs[q:GetUInt32(0)] = q:GetUInt32(1)
        until not q:NextRow()
    end
    return rangs
end

-- ---------------------------------------------------------------------------
-- Aides
-- ---------------------------------------------------------------------------
local function Joueur(player)
    return player and not player:IsBot()
end

local function Entier(n, maxi)
    n = tonumber(n)
    if not n or n ~= math.floor(n) or n < 1 or (maxi and n > maxi) then
        return nil
    end
    return n
end

local function Refuser(player, texte)
    player:SendNotification(texte)
end

local function Additionner(total, cout)
    total.c = total.c + (cout.c or 0)
    total.h = total.h + (cout.h or 0)
    total.a = total.a + (cout.a or 0)
    for _, o in ipairs(cout.o or {}) do
        total.o[o[1]] = (total.o[o[1]] or 0) + o[2]
    end
end

-- ---------------------------------------------------------------------------
-- Handlers (appelés par le client)
-- ---------------------------------------------------------------------------
function Handlers.Ouvrir(player)
    if not Joueur(player) then return end
    AIO.Handle(player, "ItemUpgrade", "Etat", { actif = ACTIF, rangMax = RANG_MAX, jetons = JETONS })
end

function Handlers.Selectionner(player, entry)
    if not Joueur(player) then return end
    entry = Entier(entry)
    if not entry then return end
    local objet = Objet(player, entry)
    if not objet then
        AIO.Handle(player, "ItemUpgrade", "Objet", { entry = entry, absent = true })
        return
    end
    AIO.Handle(player, "ItemUpgrade", "Objet", objet)
    -- Rangs et valeurs courants : réponse « STATS » du module C++ au client.
    -- L'objet existe (vérifié par Objet), condition indispensable à cet appel.
    player:RunCommand(fmt("item_upgrade getstats %d", entry))
end

-- types = liste des types de statistique à monter d'un rang.
function Handlers.Ameliorer(player, entry, types)
    if not Joueur(player) then return end
    if not ACTIF then
        Refuser(player, "Le système d'amélioration est désactivé.")
        return
    end
    entry = Entier(entry)
    if not entry or type(types) ~= "table" then return end
    local item = TrouverObjet(player, entry)
    if not item then
        Refuser(player, "Objet introuvable dans vos sacs ou votre équipement.")
        return
    end

    local rangs = RangsEnBase(player, item)
    local total, liste, vus = NouveauCout(), {}, {}
    for _, t in ipairs(types) do
        t = Entier(t)
        if not t or not BAREME[t] or (AUTORISEES and not AUTORISEES[t]) then return end
        if not vus[t] and #liste < MAX_STATS_OBJET then
            vus[t] = true
            local cout = Cout(entry, t, (rangs[t] or 0) + 1)
            if cout then
                Additionner(total, cout)
                table.insert(liste, t)
            end
        end
    end
    if #liste == 0 then return end

    if player:GetCoinage() < total.c then
        Refuser(player, "Vous n'avez pas assez d'argent.")
        return
    end
    if total.h > 0 and player:GetHonorPoints() < total.h then
        Refuser(player, "Vous n'avez pas assez de points d'honneur.")
        return
    end
    if total.a > 0 and player:GetArenaPoints() < total.a then
        Refuser(player, "Vous n'avez pas assez de points d'arène.")
        return
    end
    for id, n in pairs(total.o) do
        if player:GetItemCount(id) < n then
            Refuser(player, "Il vous manque des jetons de puissance.")
            return
        end
    end

    -- Le module C++ vérifie et prélève chaque rang, puis répond « UPGRADE SUCCESS »
    -- au client pour chaque réussite ; « getstats » clôt par l'état à jour.
    for _, t in ipairs(liste) do
        player:RunCommand(fmt("item_upgrade doupgrade %d %d", entry, t))
    end
    if TrouverObjet(player, entry) then
        player:RunCommand(fmt("item_upgrade getstats %d", entry))
    end
end
