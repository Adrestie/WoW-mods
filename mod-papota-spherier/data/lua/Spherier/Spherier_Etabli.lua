--[[----------------------------------------------------------------------------
    Sphèrier Papota — l'établi, côté serveur

    Trois recettes (§9, révision du 2026-08-27) :

      fusion    3 pierres identiques        -> 1 pierre de la qualité au-dessus
      relance   2 pierres de même qualité   -> 1 pierre, même qualité, autre effet
      refonte   3 runes quelconques         -> 1 rune tirée dans tout le catalogue

    Ce fichier ne décide de rien : il relaie vers les commandes du module, qui
    portent TOUTES les règles et répondent au joueur dans sa langue — même
    partage que le sertissage. Il sert par ailleurs le catalogue dont le client
    a besoin pour reconnaître, dans les sacs, ce qui peut entrer dans quelle
    recette.

    Ouverture : l'objet de monde 803700, « Établi du sphèrier ». Le gabarit
    vient du SQL du module ; les apparitions se posent en jeu, à la main.
------------------------------------------------------------------------------]]

local AIO = require("AIO")

local SpherierEtabliHandlers = AIO.AddHandlers("SpherierEtabli", {})

local fmt = string.format

local ETABLI_ENTRY = 803700
local GAMEOBJECT_EVENT_ON_USE = 14

-- Clé de stat par indice, alignée sur l'allocation des pierres (§8). Même table
-- que l'interface joueur : c'est le catalogue qui fait foi, pas une formule.
local STAT_KEYS = {
    "endurance", "intelligence", "esprit", "dexterite", "force",
    "parade", "blocage", "esquive", "hate", "critique", "touche",
    "puissance_sorts", "puissance_attaque", "penetration_armure", "expertise", "bonus_soins",
}

local CATALOGUE = nil

-- Le catalogue est le même pour tout le monde et ne bouge qu'à un
-- `.spherier reload` : on le construit une fois.
local function Catalogue()
    if CATALOGUE then return CATALOGUE end

    local cat = { pierres = {}, runes = {}, runesStat = {} }

    -- La qualite vient d'item_template : c'est la seule source qui fasse foi.
    -- La deduire du montant marcherait pour les pierres, et pour elles seules.
    local q = WorldDBQuery(
        "SELECT s.item_entry, s.stat_id, s.amount, t.Quality FROM papota_sphere_stone s "
        .. "JOIN item_template t ON t.entry = s.item_entry")
    if q then
        repeat
            local stat = STAT_KEYS[q:GetUInt32(1)]
            if stat then
                cat.pierres[q:GetUInt32(0)] = { stat = stat, montant = q:GetInt32(2),
                                                qualite = q:GetUInt32(3) }
            end
        until not q:NextRow()
    end

    q = WorldDBQuery(
        "SELECT r.item_entry, r.first_spell_id, r.base_rank, t.Quality FROM papota_sphere_rune r "
        .. "JOIN item_template t ON t.entry = r.item_entry")
    if q then
        repeat
            cat.runes[q:GetUInt32(0)] = { sort = q:GetUInt32(1), rang = q:GetUInt32(2) + 1,
                                          qualite = q:GetUInt32(3) }
        until not q:NextRow()
    end

    q = WorldDBQuery(
        "SELECT r.item_entry, r.stat_id, r.percent, t.Quality FROM papota_sphere_stat_rune r "
        .. "JOIN item_template t ON t.entry = r.item_entry")
    if q then
        repeat
            local stat = STAT_KEYS[q:GetUInt32(1)]
            if stat then
                cat.runesStat[q:GetUInt32(0)] = { stat = stat, pct = q:GetUInt32(2),
                                                  qualite = q:GetUInt32(3) }
            end
        until not q:NextRow()
    end

    CATALOGUE = cat
    return cat
end

function SpherierEtabliHandlers.Catalogue(player)
    AIO.Handle(player, "SpherierEtabli", "Catalogue", Catalogue())
end

function SpherierEtabliHandlers.Ouvrir(player)
    AIO.Handle(player, "SpherierEtabli", "Afficher", Catalogue())
end

-- Les trois recettes. Le module vérifie tout — nature des objets, qualités,
-- possession, place en sac — et parle au joueur ; on se contente de transmettre
-- et de laisser le client rafraîchir ses sacs de lui-même.
local function Nombre(v)
    return type(v) == "number" and math.floor(v) or 0
end

function SpherierEtabliHandlers.Fusion(player, entree)
    entree = Nombre(entree)
    if entree <= 0 then return end
    player:RunCommand(fmt("spherier fusion %d", entree))
end

function SpherierEtabliHandlers.Relance(player, a, b)
    a, b = Nombre(a), Nombre(b)
    if a <= 0 or b <= 0 then return end
    player:RunCommand(fmt("spherier relance %d %d", a, b))
end

function SpherierEtabliHandlers.Refonte(player, a, b, c)
    a, b, c = Nombre(a), Nombre(b), Nombre(c)
    if a <= 0 or b <= 0 or c <= 0 then return end
    player:RunCommand(fmt("spherier refonte %d %d %d", a, b, c))
end

-- L'objet de monde ouvre la fenêtre. Même montage que le coffre hebdomadaire du
-- mythique+, dont on sait qu'il répond bien à cet événement sur ce serveur.
local function OnUseEtabli(_, _, player)
    if not player then return end
    AIO.Handle(player, "SpherierEtabli", "Afficher", Catalogue())
    return true                             -- rien d'autre ne doit se produire
end

RegisterGameObjectEvent(ETABLI_ENTRY, GAMEOBJECT_EVENT_ON_USE, OnUseEtabli)

print("Spherier: etabli charge.")
