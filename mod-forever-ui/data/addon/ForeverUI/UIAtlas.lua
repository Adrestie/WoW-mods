-- UIAtlas : equivalent de SetAtlas pour un client 3.3.5
-- Une seule texture par feuille, adressage par SetTexCoord : aucun decoupage de fichier.
UIAtlas = UIAtlas or { sheets = {}, data = {} }

-- texture : objet Texture ; name : nom d'atlas (ex. "ui-hud-unitframe-player-portraiton-bar-health")
-- useAtlasSize : si vrai, applique aussi la taille d'origine de l'element
function UIAtlas.Apply(texture, name, useAtlasSize)
	local e = UIAtlas.data[name]
	if not e then
		return false
	end

	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[3], e[4], e[5])

	if useAtlasSize then
		texture:SetWidth(e[6])
		texture:SetHeight(e[7])
	end

	return true
end

-- Renvoie les donnees brutes : chemin, u1, u2, v1, v2, largeur, hauteur
function UIAtlas.Get(name)
	local e = UIAtlas.data[name]
	if not e then
		return nil
	end

	return e[1], e[2], e[3], e[4], e[5], e[6], e[7]
end
