-- ForeverUI : les textes, dans la langue du client (demande de l'utilisateur,
-- 2026-09-28 : « il ne faut aucun texte en dur. anglais en base, francais
-- supporte et doit etre extensible a d'autres langues »).
--
-- LA REGLE. Un texte que le client 3.3.5 connait (GlobalStrings.lua) se lit
-- dans sa globale : il suit deja la langue du client. Tout autre texte
-- affiche -- ceux de camelot absents de 3.3.5, ceux de ForeverUI -- se lit
-- ici, ForeverUI.L.CLE, jamais en dur dans un fichier.
--
-- LES LANGUES. Chaque langue est un fichier Textes_<code>.lua qui appelle
-- ForeverUI.AjouterTextes("<code>", { CLE = "texte", ... }) ; l'anglais
-- (enUS) est la base : une cle absente d'une langue prend le texte anglais,
-- et un client dont la langue n'a pas de fichier (enGB, deDE...) lit
-- l'anglais. AJOUTER UNE LANGUE : copier Textes_enUS.lua en
-- Textes_<code>.lua (code de GetLocale : deDE, esES, ruRU...), traduire les
-- valeurs sans toucher aux cles ni aux %s / %d (meme nombre, meme ordre :
-- le string.format de Lua 5.1 ne sait pas les reordonner), et ajouter le
-- fichier au .toc apres Textes_enUS.lua.
--
-- Une cle que l'anglais ne connait pas s'affiche telle quelle et reste
-- notee dans ForeverUI.textesManquants (le banc d'essai la refuse).

ForeverUI = ForeverUI or {}

local langues = {}
local BASE = "enUS"

function ForeverUI.AjouterTextes(langue, textes)
	local t = langues[langue] or {}
	for cle, texte in pairs(textes) do t[cle] = texte end
	langues[langue] = t
end

ForeverUI.textesManquants = {}

ForeverUI.L = setmetatable({}, {
	__index = function(_, cle)
		local t = langues[GetLocale()]
		local texte = t and t[cle]
		if texte == nil and langues[BASE] then texte = langues[BASE][cle] end
		if texte == nil then
			ForeverUI.textesManquants[cle] = true
			texte = tostring(cle)
		end
		return texte
	end,
})

-- les cles d'une langue (pour le banc d'essai)
function ForeverUI.TextesDe(langue)
	return langues[langue]
end
