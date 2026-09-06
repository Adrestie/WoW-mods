--[[----------------------------------------------------------------------------
    test_departs.lua — banc d'essai des DIX DÉPARTS du serveur de l'éditeur.

    Charge Spherier_Server.lua avec un AIO factice (motif de importe_layout.lua)
    et vérifie, sans jeu :
      1. qu'une feuille à l'ancienne (un seul <depart id=.../>) se lit encore
         et se réécrit à l'identique ;
      2. qu'une feuille à dix départs (classe="…") fait l'aller-retour ;
      3. que Verify compte les départs et signale un départ sur un
         emplacement retiré, en le peignant en rouge.

    Usage, répertoire de travail = bin\RelWithDebInfo du serveur :
      lua52_interpreter.exe D:\...\test_departs.lua
------------------------------------------------------------------------------]]

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

local DIR = "lua_scripts/Spherier/layouts/"
local function Lit(nom)
    local f = assert(io.open(DIR .. nom .. ".xml", "r"))
    local t = f:read("*a")
    f:close()
    return t
end

-- Une petite grille : deux clusters, quatre emplacements, une chaîne.
local clusters = { { id = 1, x = 0, y = 0, rot = 0 }, { id = 2, x = 8, y = 0, rot = 0 } }
local nodes = {
    { id = 1, cluster = 1, ring = 0, branch = 1, kind = 0 },
    { id = 2, cluster = 1, ring = 3, branch = 1, kind = 0 },
    { id = 3, cluster = 2, ring = 3, branch = 5, kind = 0 },
    { id = 4, cluster = 2, ring = 0, branch = 1, kind = 0 },
}
local edges = { { 1, 2 }, { 2, 3 }, { 3, 4 } }

-- 1. l'ancienne forme : un nombre ------------------------------------------
H.Save({}, "test_departs_un", clusters, nodes, edges, 1)
local texte = Lit("test_departs_un")
assert(texte:find('<depart id="1"/>', 1, true), "forme ancienne non réécrite à l'identique :\n" .. texte)
assert(not texte:find('classe=', 1, true), "une classe est apparue sur un départ unique")
H.Load({}, "test_departs_un")
local charge = Derniere("ReceiveLayout")
assert(type(charge[6]) == "table" and charge[6][0] == 1, "relecture de la forme ancienne")
vraiPrint("1. forme ancienne : écriture identique, relue comme { [0] = 1 }  OK")

-- 2. dix départs ---------------------------------------------------------------
local dix = { [1] = 1, [2] = 2, [3] = 3, [4] = 4, [5] = 1, [6] = 2, [7] = 3, [8] = 4, [9] = 1, [11] = 2 }
H.Save({}, "test_departs_dix", clusters, nodes, edges, dix)
texte = Lit("test_departs_dix")
local n = 0
for _ in texte:gmatch('<depart classe="%d+" id="%d+"/>') do n = n + 1 end
assert(n == 10, "dix départs attendus, " .. n .. " écrits")
assert(texte:find('<depart classe="11" id="2"/>', 1, true), "le druide manque")
H.Load({}, "test_departs_dix")
charge = Derniere("ReceiveLayout")
local relus = charge[6]
for classe, id in pairs(dix) do
    assert(relus[classe] == id, "départ de la classe " .. classe .. " mal relu")
end
local rapport = charge[5]
assert(rapport.departs == 10, "le rapport compte " .. tostring(rapport.departs) .. " départs")
assert(rapport.ok, "la petite grille devrait passer : " .. table.concat(rapport.problems, " ; "))
vraiPrint("2. dix départs : aller-retour exact, rapport à 10, contrôle vert  OK")

-- 3. un départ sur un emplacement retiré ---------------------------------------
H.Verify({}, clusters, nodes, edges, { [1] = 1, [11] = 99 })
rapport = Derniere("ReceiveReport")[1]
assert(not rapport.ok, "le départ 99 aurait dû être signalé")
local trouve = false
for _, p in ipairs(rapport.problems) do
    if p:find("classe 11", 1, true) and p:find("99", 1, true) then trouve = true end
end
assert(trouve, "message attendu absent : " .. table.concat(rapport.problems, " ; "))
vraiPrint("3. départ retiré : signalé avec sa classe  OK")

-- 4. aucun départ --------------------------------------------------------------
H.Verify({}, clusters, nodes, edges, {})
rapport = Derniere("ReceiveReport")[1]
assert(not rapport.ok and rapport.departs == 0, "l'absence de départ doit être un défaut")
vraiPrint("4. aucun départ : défaut signalé  OK")

os.remove(DIR .. "test_departs_un.xml")
os.remove(DIR .. "test_departs_dix.xml")
-- L'index des dispositions (index.txt) ne doit pas garder les noms du banc :
-- l'editeur les afficherait « en magasin » sans fichier derriere.
do
    local f = io.open(DIR .. "index.txt", "r")
    if f then
        local garde = {}
        for l in f:lines() do
            if l ~= "test_departs_un" and l ~= "test_departs_dix" then garde[#garde + 1] = l end
        end
        f:close()
        f = assert(io.open(DIR .. "index.txt", "w"))
        f:write(table.concat(garde, "\n"), "\n")
        f:close()
    end
end
vraiPrint("test_departs : tout passe")
