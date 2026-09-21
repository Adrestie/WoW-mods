-- 07_petites_feuilles : des elements retailles a part.
--
-- POURQUOI. Le client rend en BRUIT une feuille de 2048 de large : toutes
-- celles qu'il affiche correctement font 1024 au plus. Les elements repris
-- ici viennent d'une trop grande feuille et ont ete recoupes dans une petite
-- par tools/petite_feuille.py. Ce fichier se charge EN DERNIER : UIAtlas.data
-- est une table plate, sa definition gagne sur celle d'origine.

UIAtlas = UIAtlas or { sheets = {}, data = {} }

local S = {
	[1] = "interface\\ForeverUI\\hud\\petautocast", -- 128 x 128
}

local D = {
	["ui-hud-actionbar-petautocast-ants"] = {1, 0.000000, 0.601562, 0.000000, 0.601562, 77, 77},
	["ui-hud-actionbar-petautocast-corners"] = {1, 0.601562, 0.960938, 0.000000, 0.359375, 46, 46},
}

for i, chemin in pairs(S) do UIAtlas.sheets[chemin] = true end
for nom, e in pairs(D) do
	UIAtlas.data[nom] = { S[e[1]], e[2], e[3], e[4], e[5], e[6], e[7] }
end
