--[[----------------------------------------------------------------------------
    Amélioration d'objets (mod-item-upgrade) — côté serveur (ALE + AIO)

    Ce script ne décide de rien et ne lit aucun barème : toutes les règles sont
    dans le module C++. La fenêtre (ItemUpgrade_Client.lua, expédiée par AIO)
    l'interroge directement, par le canal de commandes des addons du cœur
    (.item_upgrade state | upgrade) ; le module lui répond ligne par ligne.

    Il n'apporte que les textes de la fenêtre. Leur seule source est la base :
    tables `module_string` (anglais) et `module_string_locale` (autres langues)
    du cœur, module 'mod-item-upgrade', partagées avec le module C++. Ils
    partent avec le code de la fenêtre, dans la langue du client du joueur.
    Un `.reload ale` les relit.
------------------------------------------------------------------------------]]
local AIO = AIO or require("AIO")
local fmt = string.format

-- ---------------------------------------------------------------------------
-- Textes, lus une fois par chargement du script
-- ---------------------------------------------------------------------------
-- Numéros : 1-99 messages du module C++, 101-199 la fenêtre, 1000 + n le nom
-- de la statistique n, 1100 + n celui de l'emplacement d'équipement n.
local MODULE = "mod-item-upgrade"
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

-- La fenêtre reçoit ses textes avec son code, dans le message d'ouverture
-- qu'AIO envoie au joueur : ils sont là avant qu'elle ne s'affiche.
AIO.AddOnInit(function(msg, player)
    if player then
        msg:Add("ItemUpgrade", "Textes", TextesDe(player))
    end
    return msg
end)
