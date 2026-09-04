--[[----------------------------------------------------------------------------
    Attriboost — côté serveur (ALE + AIO)

    L'interface client (Attriboost_Client.lua, expédiée par AIO) ne touche jamais
    à l'état : elle DEMANDE, ce script VALIDE puis pilote le module C++ par ses
    commandes joueur (.attriboost exchange | talents | allocate | reset), dont
    les écritures en base sont synchrones. L'état renvoyé au client est toujours
    RELU en base après l'opération : ce que le joueur voit est ce qui est écrit.

    Les plafonds et le coût de réinitialisation sont lus dans attriboost.conf,
    la même source que le module : rien à dupliquer. Un `.reload ale` relit tout.
------------------------------------------------------------------------------]]
local AIO = AIO or require("AIO")
local Handlers = AIO.AddHandlers("Attriboost", {})
local fmt = string.format

local LIVRE, LIVRE_TALENTS = 890010, 890011   -- objets customs (2026-09-04)
local POINTS_PAR_LIVRE = 3
local CONF = "configs/modules/attriboost.conf"

-- Ordre d'affichage. cle = mot de la commande, colonne = colonne SQL,
-- spell = aura (icône et infobulle côté client), conf = clé du plafond.
local STATS = {
    { cle = "stamina",     colonne = "stamina",              spell = 890007, conf = "Stamina" },
    { cle = "strength",    colonne = "strength",             spell = 890002, conf = "Strength" },
    { cle = "agility",     colonne = "agility",              spell = 890000, conf = "Agility" },
    { cle = "intellect",   colonne = "intellect",            spell = 890001, conf = "Intellect" },
    { cle = "spirit",      colonne = "spirit",               spell = 890003, conf = "Spirit" },
    { cle = "spellpower",  colonne = "spellpower",           spell = 890006, conf = "SpellPower" },
    { cle = "critdamage",  colonne = "criticalstrikedamage", spell = 890004, conf = "CriticalStrikeDamage" },
    { cle = "resists",     colonne = "allresists",           spell = 890008, conf = "AllResists" },
    { cle = "penetration", colonne = "spellpenetration",     spell = 890009, conf = "SpellPenetration" },
    { cle = "healing",     colonne = "healingpower",         spell = 890005, conf = "HealingPower" },
}
local PAR_CLE = {}
for _, s in ipairs(STATS) do PAR_CLE[s.cle] = s end

local COLONNES = "unallocated"
for _, s in ipairs(STATS) do COLONNES = COLONNES .. ", " .. s.colonne end

-- ---------------------------------------------------------------------------
-- Configuration du module, lue une fois par chargement du script
-- ---------------------------------------------------------------------------
local function LireConf()
    local plafonds, cout, actif = {}, 2500000, true
    local f = io.open(CONF, "r")
    if not f then
        return plafonds, cout, actif
    end
    for ligne in f:lines() do
        local cle, val = ligne:match("^%s*Attriboost%.([%w%.]+)%s*=%s*(%d+)")
        if cle then
            if cle == "ResetCost" then
                cout = tonumber(val)
            elseif cle == "Enable" then
                actif = (val ~= "0")
            else
                local m = cle:match("^Max%.(%w+)$")
                if m then plafonds[m] = tonumber(val) end
            end
        end
    end
    f:close()
    return plafonds, cout, actif
end
local PLAFONDS, COUT_RESET, ACTIF = LireConf()

-- ---------------------------------------------------------------------------
-- État relu en base
-- ---------------------------------------------------------------------------
local function Etat(player)
    local etat = {
        actif = ACTIF,
        disponibles = 0,
        stats = {},
        livres = player:GetItemCount(LIVRE),
        livresTalents = player:GetItemCount(LIVRE_TALENTS),
        pointsParLivre = POINTS_PAR_LIVRE,
        coutReset = COUT_RESET,
    }
    local q = CharDBQuery(fmt("SELECT %s FROM attriboost_attributes WHERE guid = %d",
                              COLONNES, player:GetGUIDLow()))
    if q then
        local dispo = q:GetInt32(0)
        etat.disponibles = (dispo > 0) and dispo or 0
    end
    for i, s in ipairs(STATS) do
        etat.stats[i] = {
            cle = s.cle,
            spell = s.spell,
            valeur = q and q:GetUInt32(i) or 0,
            max = PLAFONDS[s.conf] or 100,
        }
    end
    return etat
end

local function Refuser(player, texte)
    player:SendNotification(texte)
end

-- `IsBot` n'existe que sur les cœurs qui embarquent les playerbots : on ne
-- l'appelle que s'il est là, pour que le module tourne aussi sans eux.
local function Joueur(player)
    if not player then
        return false
    end
    if type(player.IsBot) == "function" and player:IsBot() then
        return false
    end
    return true
end

local function Entier(n, maxi)
    n = tonumber(n)
    if not n or n ~= math.floor(n) or n < 1 or n > maxi then
        return nil
    end
    return n
end

local function Envoyer(player, extra)
    AIO.Handle(player, "Attriboost", "Etat", Etat(player), extra)
end

-- ---------------------------------------------------------------------------
-- Handlers (appelés par le client)
-- ---------------------------------------------------------------------------
function Handlers.Ouvrir(player)
    if not Joueur(player) then return end
    Envoyer(player)
end

function Handlers.Echanger(player, n)
    if not Joueur(player) or not ACTIF then return end
    n = Entier(n, 200)
    if not n then return end
    if player:GetItemCount(LIVRE) < n then
        Refuser(player, "Vous n'avez pas assez de Livres de connaissance.")
        return
    end
    player:RunCommand(fmt("attriboost exchange %d", n))
    Envoyer(player, { echange = n * POINTS_PAR_LIVRE })
end

function Handlers.EchangerTalents(player, n)
    if not Joueur(player) or not ACTIF then return end
    n = Entier(n, 200)
    if not n then return end
    if player:GetItemCount(LIVRE_TALENTS) < n then
        Refuser(player, "Vous n'avez pas assez de Livres des talents.")
        return
    end
    player:RunCommand(fmt("attriboost talents %d", n))
    Envoyer(player, { talents = n })
end

-- demande = { [cle] = nombre de points }, validée en bloc avant la première écriture.
function Handlers.Attribuer(player, demande)
    if not Joueur(player) or not ACTIF then return end
    if type(demande) ~= "table" then return end

    local etat = Etat(player)
    local courant = {}
    for _, s in ipairs(etat.stats) do courant[s.cle] = s end

    local total, ordre = 0, {}
    for cle, n in pairs(demande) do
        local s = courant[cle]
        n = Entier(n, 250)
        if not s or not n then return end
        if s.valeur + n > s.max then
            Refuser(player, "Le plafond de cette statistique serait dépassé.")
            return
        end
        total = total + n
        table.insert(ordre, { cle = cle, n = n })
    end
    if total == 0 then return end
    if total > etat.disponibles then
        Refuser(player, "Vous n'avez pas assez de points disponibles.")
        return
    end

    -- Ordre stable (celui de l'affichage) : le module re-vérifie chaque étape.
    table.sort(ordre, function(a, b) return PAR_CLE[a.cle].spell < PAR_CLE[b.cle].spell end)
    for _, d in ipairs(ordre) do
        player:RunCommand(fmt("attriboost allocate %s %d", d.cle, d.n))
    end
    Envoyer(player, { attribue = total })
end

function Handlers.Reinitialiser(player)
    if not Joueur(player) or not ACTIF then return end
    if player:GetCoinage() < COUT_RESET then
        Refuser(player, "Vous n'avez pas assez d'argent.")
        return
    end
    player:RunCommand("attriboost reset")
    Envoyer(player, { reinitialise = true })
end
