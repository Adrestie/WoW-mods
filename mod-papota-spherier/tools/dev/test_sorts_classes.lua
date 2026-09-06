--[[----------------------------------------------------------------------------
    test_sorts_classes.lua — banc d'essai des SORTS PAR CLASSE de l'éditeur.

    Charge Spherier_Server.lua avec un AIO factice (motif de test_departs.lua)
    et vérifie, sans jeu :
      1. qu'un emplacement de sort avec des sorts par classe s'écrit en
         balises <sort emplacement classe id/> et se relit à l'identique ;
      2. la règle de visibilité : sans sort pour une classe, l'emplacement
         n'existe pas pour elle — posé en PONT, il coupe la grille de cette
         classe (défaut nommé, emplacements perdus peints) ; en FEUILLE, il
         ne gêne personne ;
      3. qu'un repli « toutes classes » sert les classes muettes, qu'un jeu
         complet passe, qu'un zéro ne compte pas, et qu'un départ posé sur un
         emplacement muet pour sa classe est un défaut.

    Usage, répertoire de travail = bin\RelWithDebInfo du serveur :
      python "D:\Serveur WoW\outils_spherier\lua51.py" test_sorts_classes.lua .
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

local function Contient(liste, motif)
    for _, p in ipairs(liste) do
        if p:find(motif, 1, true) then return p end
    end
end

local function Peint(rapport, id)
    for _, f in ipairs(rapport.fautifs) do if f == id then return true end end
    return false
end

-- Deux clusters, quatre emplacements dont un de sort (2), dix départs sur 1.
local clusters = { { id = 1, x = 0, y = 0, rot = 0 }, { id = 2, x = 8, y = 0, rot = 0 } }
local function Grille()
    return {
        { id = 1, cluster = 1, ring = 0, branch = 1, kind = 0 },
        { id = 2, cluster = 1, ring = 3, branch = 1, kind = 2, sort = 0, sorts = { [1] = 8600000, [8] = 8600070 } },
        { id = 3, cluster = 2, ring = 3, branch = 5, kind = 0 },
        { id = 4, cluster = 2, ring = 0, branch = 1, kind = 0 },
    }
end
local pont    = { { 1, 2 }, { 2, 3 }, { 3, 4 } }      -- 2 fait pont entre 1 et 3-4
local feuille = { { 1, 3 }, { 3, 4 }, { 1, 2 } }      -- 2 est une feuille
local dix = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 1, [8] = 1, [9] = 1, [11] = 1 }

-- 1. écriture et relecture -------------------------------------------------------
local nodes = Grille()
H.Save({}, "test_sorts_classes", clusters, nodes, feuille, dix)
local texte = Lit("test_sorts_classes")
assert(texte:find('<sort emplacement="2" classe="1" id="8600000"/>', 1, true), "balise du guerrier absente :\n" .. texte)
assert(texte:find('<sort emplacement="2" classe="8" id="8600070"/>', 1, true), "balise du mage absente")
assert(texte:find('type="sort" sort="0"', 1, true), "le repli 0 doit rester écrit sur l'emplacement")
H.Load({}, "test_sorts_classes")
local charge = Derniere("ReceiveLayout")
local relu
for _, n in ipairs(charge[2]) do if n.id == 2 then relu = n end end
assert(relu and relu.kind == 2, "emplacement de sort non relu")
assert(relu.sorts and relu.sorts[1] == 8600000 and relu.sorts[8] == 8600070, "sorts par classe mal relus")
local nb = 0
for _ in pairs(relu.sorts) do nb = nb + 1 end
assert(nb == 2, "deux sorts attendus, " .. nb .. " relus")
assert(charge[5].ok, "en feuille, un sort muet pour huit classes ne gêne personne : "
    .. table.concat(charge[5].problems, " ; "))
vraiPrint("1. écriture <sort …/>, relecture à l'identique, feuille muette tolérée  OK")

-- 2. en pont : les classes muettes perdent 3 et 4 --------------------------------
H.Verify({}, clusters, Grille(), pont, dix)
local rapport = Derniere("ReceiveReport")[1]
assert(not rapport.ok, "en pont, huit classes perdent la moitié de la grille")
assert(not Contient(rapport.problems, "aucun sort pour"), "l'ancien défaut « aucun sort » ne doit plus exister")
local nbClasses = 0
for _, p in ipairs(rapport.problems) do
    if p:find("hors d'atteinte", 1, true) then
        nbClasses = nbClasses + 1
        assert(p:find("2 emplacement(s)", 1, true), "deux emplacements perdus attendus : " .. p)
    end
end
assert(nbClasses == 8, "huit classes attendues en défaut, " .. nbClasses .. " : " .. table.concat(rapport.problems, " ; "))
assert(Contient(rapport.problems, "classe 2 :") and Contient(rapport.problems, "classe 11 :"), "classes 2 et 11 attendues")
assert(not Contient(rapport.problems, "classe 1 :") and not Contient(rapport.problems, "classe 8 :"), "le guerrier et le mage voient tout")
assert(Peint(rapport, 3) and Peint(rapport, 4) and not Peint(rapport, 2), "3 et 4 perdus doivent être peints, pas le sort")
vraiPrint("2. sort muet en pont : défaut par classe, emplacements perdus peints  OK")

-- 3. repli, jeu complet, zéro, départ muet ----------------------------------------
nodes = Grille()
nodes[2].sort = 8600001
H.Verify({}, clusters, nodes, pont, dix)
rapport = Derniere("ReceiveReport")[1]
assert(rapport.ok, "avec un repli, plus aucun défaut attendu : " .. table.concat(rapport.problems, " ; "))
nodes = Grille()
nodes[2].sorts = { [1] = 8600000, [2] = 8600010, [3] = 8600020, [4] = 8600030, [5] = 8600040,
                   [6] = 8600050, [7] = 8600060, [8] = 8600070, [9] = 8600080, [11] = 8600090 }
H.Verify({}, clusters, nodes, pont, dix)
rapport = Derniere("ReceiveReport")[1]
assert(rapport.ok, "dix sorts propres : plus aucun défaut attendu : " .. table.concat(rapport.problems, " ; "))
nodes[2].sorts[5] = 0
H.Verify({}, clusters, nodes, pont, dix)
rapport = Derniere("ReceiveReport")[1]
assert(not rapport.ok and #rapport.problems == 1 and rapport.problems[1]:find("classe 5 :", 1, true),
    "le zéro du prêtre devait couper sa grille, et la sienne seulement : " .. table.concat(rapport.problems, " ; "))
-- un départ posé sur un emplacement de sort muet pour sa classe
local departs = { [1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 2, [6] = 1, [7] = 1, [8] = 1, [9] = 1, [11] = 1 }
H.Verify({}, clusters, nodes, pont, departs)
rapport = Derniere("ReceiveReport")[1]
assert(Contient(rapport.problems, "le départ de la classe 5 (2)") and Peint(rapport, 2),
    "départ muet non signalé : " .. table.concat(rapport.problems, " ; "))
vraiPrint("3. repli, jeu complet, zéro ignoré, départ muet signalé  OK")

os.remove(DIR .. "test_sorts_classes.xml")
-- L'index des dispositions (index.txt) ne doit pas garder le nom du banc :
-- l'éditeur l'afficherait « en magasin » sans fichier derrière.
do
    local f = io.open(DIR .. "index.txt", "r")
    if f then
        local garde = {}
        for l in f:lines() do
            if l ~= "test_sorts_classes" then garde[#garde + 1] = l end
        end
        f:close()
        f = assert(io.open(DIR .. "index.txt", "w"))
        f:write(table.concat(garde, "\n"), "\n")
        f:close()
    end
end
vraiPrint("test_sorts_classes : tout passe")
