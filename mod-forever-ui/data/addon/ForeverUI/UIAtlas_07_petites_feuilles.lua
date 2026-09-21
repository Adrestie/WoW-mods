-- 07_petites_feuilles : des elements retailles a part.
--
-- POURQUOI. Un element qu'on fait tourner ne peut pas rester dans une
-- grande feuille partagee : la rotation balaie le carre circonscrit, et tout
-- ce qui l'entoure entre dans le cadre. Ces elements ont donc ete recoupes
-- seuls, au milieu de leur feuille, par tools/petite_feuille.py. Ce fichier
-- se charge EN DERNIER : UIAtlas.data est une table plate, sa definition
-- gagne sur celle d'origine.

UIAtlas = UIAtlas or { sheets = {}, data = {} }

local S = {
	[1] = "interface\\ForeverUI\\hud\\petautocastants", -- 128 x 128
	[2] = "interface\\ForeverUI\\hud\\petautocastcorners", -- 64 x 64
}

local D = {
	["ui-hud-actionbar-petautocast-ants"] = {1, 0.195312, 0.796875, 0.195312, 0.796875, 77, 77},
	["ui-hud-actionbar-petautocast-corners"] = {2, 0.000000, 0.718750, 0.000000, 0.718750, 46, 46},
}

for i, chemin in pairs(S) do UIAtlas.sheets[chemin] = true end
for nom, e in pairs(D) do
	UIAtlas.data[nom] = { S[e[1]], e[2], e[3], e[4], e[5], e[6], e[7] }
end
