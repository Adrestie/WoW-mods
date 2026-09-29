--[[----------------------------------------------------------------------------
    Attriboost — côté serveur (ALE + AIO)

    L'interface client (Attriboost_Client.lua, expédiée par AIO) ne touche jamais
    à l'état : elle DEMANDE, ce script VALIDE puis pilote le module C++ par ses
    commandes joueur (.attriboost exchange | talents | allocate | reset), dont
    les écritures en base sont synchrones. L'état renvoyé au client est toujours
    RELU en base après l'opération : ce que le joueur voit est ce qui est écrit.

    Les plafonds et le coût de réinitialisation sont lus dans attriboost.conf,
    la même source que le module : rien à dupliquer. Un `.reload ale` relit tout.

    Les textes aussi n'ont qu'une source : les tables `module_string` (anglais)
    et `module_string_locale` (autres langues) du cœur, module 'mod-attriboost'.
    Le C++ y lit ses messages, ce script les siens, et l'interface reçoit les
    siens d'ici, dans la langue du client du joueur.
------------------------------------------------------------------------------]]
local AIO = AIO or require("AIO")
local Handlers = AIO.AddHandlers("Attriboost", {})
local fmt = string.format

local LIVRE, LIVRE_TALENTS = 82010, 82011   -- objets customs (2026-09-04)
local POINTS_PAR_LIVRE = 3
local CONF = "configs/modules/attriboost.conf"

-- Ordre d'affichage. cle = mot de la commande, colonne = colonne SQL,
-- spell = aura (icône et infobulle côté client), conf = clé du plafond.
local STATS = {
    { cle = "stamina",     colonne = "stamina",              spell = 82007, conf = "Stamina" },
    { cle = "strength",    colonne = "strength",             spell = 82002, conf = "Strength" },
    { cle = "agility",     colonne = "agility",              spell = 82000, conf = "Agility" },
    { cle = "intellect",   colonne = "intellect",            spell = 82001, conf = "Intellect" },
    { cle = "spirit",      colonne = "spirit",               spell = 82003, conf = "Spirit" },
    { cle = "spellpower",  colonne = "spellpower",           spell = 82006, conf = "SpellPower" },
    { cle = "critdamage",  colonne = "criticalstrikedamage", spell = 82004, conf = "CriticalStrikeDamage" },
    { cle = "resists",     colonne = "allresists",           spell = 82008, conf = "AllResists" },
    { cle = "penetration", colonne = "spellpenetration",     spell = 82009, conf = "SpellPenetration" },
    { cle = "healing",     colonne = "healingpower",         spell = 82005, conf = "HealingPower" },
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
-- Textes, lus une fois par chargement du script
-- ---------------------------------------------------------------------------
-- Numéros : 1-99 messages (module C++ et ce script), 101 et au-delà interface.
-- `{}` marque une valeur, comme dans les messages du module C++.
local MODULE = "mod-attriboost"
local LANGUES = { [0] = "enUS", [1] = "koKR", [2] = "frFR", [3] = "deDE", [4] = "zhCN",
                  [5] = "zhTW", [6] = "esES", [7] = "esMX", [8] = "ruRU" }
local TEXTES = {}   -- TEXTES[langue][numéro] ; l'anglais vient de module_string

local function ChargerTextes()
    TEXTES = { enUS = {} }
    local q = WorldDBQuery(fmt("SELECT id, string FROM module_string WHERE module = '%s'", MODULE))
    if q then
        repeat
            TEXTES.enUS[q:GetUInt32(0)] = q:GetString(1)
        until not q:NextRow()
    end
    q = WorldDBQuery(fmt("SELECT id, locale, string FROM module_string_locale WHERE module = '%s'", MODULE))
    if q then
        repeat
            local langue = q:GetString(1)
            TEXTES[langue] = TEXTES[langue] or {}
            TEXTES[langue][q:GetUInt32(0)] = q:GetString(2)
        until not q:NextRow()
    end
end
ChargerTextes()

local function Langue(player)
    return LANGUES[player:GetDbLocaleIndex()] or "enUS"
end

-- Tous les textes du module dans la langue du joueur, l'anglais à défaut.
local function TextesDe(player)
    local propres = TEXTES[Langue(player)] or {}
    local t = {}
    for id, texte in pairs(TEXTES.enUS) do
        t[id] = propres[id] or texte
    end
    return t
end

-- Un texte dans la langue du joueur, ses `{}` remplis dans l'ordre.
local function Texte(player, id, ...)
    local propres = TEXTES[Langue(player)] or {}
    local texte = propres[id] or TEXTES.enUS[id] or ("#" .. id)
    local valeurs, n = { ... }, 0
    return (texte:gsub("{}", function()
        n = n + 1
        return tostring(valeurs[n])
    end))
end

-- Les messages de ce script. 3, 5, 9 et 13 sont ceux du module C++ (enum
-- AttriboostStrings) : le même refus a le même texte des deux côtés.
local MSG = {
    PAS_ASSEZ_TOMES = 3,
    PAS_ASSEZ_LIVRES_TALENTS = 5,
    PAS_ASSEZ_POINTS = 9,
    PAS_ASSEZ_ARGENT = 13,
    PLAFOND_DEPASSE = 15,
}

-- L'interface reçoit ses textes avec son code, dans le message d'ouverture
-- qu'AIO envoie au joueur : ils sont là avant qu'elle ne s'affiche.
AIO.AddOnInit(function(msg, player)
    if player then
        msg:Add("Attriboost", "Textes", TextesDe(player))
    end
    return msg
end)

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

local function Refuser(player, id, ...)
    player:SendNotification(Texte(player, id, ...))
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

-- L'état des points, pour l'infobulle de l'aura « Attributs » (la seule aura
-- du module que le joueur voit, qui liste les bonus) : envoyé à l'ouverture
-- de session, puis redemandé par le client quand il montre cette infobulle,
-- les commandes de discussion changeant les points sans passer par ce script.
AIO.AddOnInit(function(msg, player)
    if Joueur(player) then
        msg:Add("Attriboost", "Resume", Etat(player))
    end
    return msg
end)

-- ---------------------------------------------------------------------------
-- Handlers (appelés par le client)
-- ---------------------------------------------------------------------------
function Handlers.Ouvrir(player)
    if not Joueur(player) then return end
    Envoyer(player)
end

function Handlers.Resume(player)
    if not Joueur(player) then return end
    AIO.Handle(player, "Attriboost", "Resume", Etat(player))
end

function Handlers.Echanger(player, n)
    if not Joueur(player) or not ACTIF then return end
    n = Entier(n, 200)
    if not n then return end
    if player:GetItemCount(LIVRE) < n then
        Refuser(player, MSG.PAS_ASSEZ_TOMES)
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
        Refuser(player, MSG.PAS_ASSEZ_LIVRES_TALENTS)
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
            Refuser(player, MSG.PLAFOND_DEPASSE)
            return
        end
        total = total + n
        table.insert(ordre, { cle = cle, n = n })
    end
    if total == 0 then return end
    if total > etat.disponibles then
        Refuser(player, MSG.PAS_ASSEZ_POINTS)
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
        Refuser(player, MSG.PAS_ASSEZ_ARGENT)
        return
    end
    player:RunCommand("attriboost reset")
    Envoyer(player, { reinitialise = true })
end
