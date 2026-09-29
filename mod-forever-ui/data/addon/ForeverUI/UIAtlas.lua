-- UIAtlas: SetAtlas for the 3.3.5 client.
-- One texture per sheet, addressed with SetTexCoord; no file slicing.
UIAtlas = UIAtlas or { sheets = {}, data = {} }

-- texture: Texture object; name: atlas name (e.g. "ui-hud-unitframe-player-portraiton-bar-health")
-- useAtlasSize: if true, also applies the element's original size
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

-- Returns the raw data: path, u1, u2, v1, v2, width, height
function UIAtlas.Get(name)
	local e = UIAtlas.data[name]
	if not e then
		return nil
	end

	return e[1], e[2], e[3], e[4], e[5], e[6], e[7]
end
