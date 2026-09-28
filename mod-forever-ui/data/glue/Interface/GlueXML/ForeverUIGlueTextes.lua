-- ForeverUI : les textes des ecrans d'accueil, dans la langue du client
-- (demande de l'utilisateur, 2026-09-28 : « il ne faut aucun texte en dur.
-- anglais en base, francais supporte et doit etre extensible a d'autres
-- langues »).
--
-- LA REGLE. Un texte que le client 3.3.5 connait (GlueStrings.lua) se lit
-- dans sa globale. Tout autre texte affiche se lit ici, G.L.CLE (G =
-- ForeverUIGlue), jamais en dur dans un fichier.
--
-- LES LANGUES. Chaque langue est un fichier ForeverUIGlueTextes_<code>.lua
-- qui appelle ForeverUIGlue.AjouterTextes("<code>", { CLE = "texte" }) ;
-- l'anglais (enUS) est la base, pour les cles absentes comme pour les
-- langues sans fichier. AJOUTER UNE LANGUE : copier
-- ForeverUIGlueTextes_enUS.lua en ForeverUIGlueTextes_<code>.lua (code de
-- GetLocale), traduire les valeurs sans toucher aux cles ni aux %s / %d
-- (meme nombre, meme ordre), et l'ajouter a ForeverUIGlue.xml apres
-- ForeverUIGlueTextes_enUS.lua.

ForeverUIGlue = ForeverUIGlue or {}
local G = ForeverUIGlue

local langues = {}
local BASE = "enUS"

function G.AjouterTextes(langue, textes)
	local t = langues[langue] or {}
	for cle, texte in pairs(textes) do t[cle] = texte end
	langues[langue] = t
end

G.textesManquants = {}

G.L = setmetatable({}, {
	__index = function(_, cle)
		local t = langues[GetLocale()]
		local texte = t and t[cle]
		if texte == nil and langues[BASE] then texte = langues[BASE][cle] end
		if texte == nil then
			G.textesManquants[cle] = true
			texte = tostring(cle)
		end
		return texte
	end,
})

function G.TextesDe(langue)
	return langues[langue]
end
