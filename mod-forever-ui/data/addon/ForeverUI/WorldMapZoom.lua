-- ForeverUI : le zoom de la carte du monde (AMELIORATIONS, 2026-09-28 :
-- « pouvoir zoomer dans la map avec la molette (juste scale de la map) » et
-- « si la map est zoomee, pouvoir pan avec un drag & drop »).
--
-- CE QUE FAIT CAMELOT (blizzard_mapcanvas/mapcanvas_scrollcontainermixin.lua) :
-- la molette zoome VERS LE CURSEUR (le point sous le curseur y reste), un
-- glisser du bouton gauche deplace la carte zoomee, un clic sans glisser
-- garde son sens. Ses paliers viennent des couches d'art de chaque carte
-- (C_Map.GetMapArtLayers), que 3.3.5 n'a pas : ici, demande de l'utilisateur,
-- c'est la carte elle-meme qu'on met a l'echelle -- x 1,25 par cran, de 1
-- (la carte entiere) a 4.
--
-- CE QUE 3.3.5 IMPOSE, ET COMMENT ON LE CONTOURNE :
--   * il ne rogne rien hors d'une ScrollFrame, et on ne reparente pas les
--     cadres du client (regle de l'atelier) : les douze tuiles sont rognees
--     une a une au rectangle de la carte (taille, place, coordonnees), les
--     reperes sortis de la vue sont eteints (alpha), et la surface cliquable
--     de WorldMapButton est bornee a la vue (SetHitRectInsets) ;
--   * les reperes, le groupe, les numeros de quete se posent en unites de
--     WorldMapButton / WorldMapPOIFrame : leur mise a l'echelle les suit.
--     La fleche du joueur, non : WorldMapButton_OnUpdate la place avec
--     l'echelle fixe de WotLK -- on la replace apres lui, x zoom ;
--   * la zone de quete (WorldMapBlobFrame) est dessinee par le moteur, d'un
--     seul morceau : zoomee, elle deborderait -- elle s'eteint tant que la
--     carte est zoomee ;
--   * WorldMapButton_OnClick navigue au RELACHEMENT du bouton (OnMouseUp) :
--     pendant un glisser, WorldMapButton ne prend plus la souris, et son
--     relachement ne navigue pas (on n'enveloppe pas le code du client : il
--     ferme les menus deroulants, et appele depuis l'addon il souillerait
--     leur etat).
-- Le zoom revient a 1 quand la carte change, change de mode ou se ferme.

local W = ForeverUI.WorldMap
local Z = { z = 1, cx = 0.5, cy = 0.5, actif = false, PAS = 1.25, MAX = 4, SEUIL = 4 }
W.zoom = Z

local CARTE_L, CARTE_H = 1002, 668
local TUILE, COLONNES, RANGEES = 256, 4, 3

local function tuile(k)
	return _G["WorldMapDetailTile" .. k]
end

local function pret()
	return W.construit and W.canevas and WorldMapDetailFrame and WorldMapButton and WORLDMAP_SETTINGS
end

-- la vue : le rectangle du canevas, en unites de WorldMapDetailFrame (et de
-- WorldMapButton, a la meme echelle et au meme coin), origine en haut a
-- gauche de la carte
local function tailleVue()
	local c, d = W.canevas, WorldMapDetailFrame
	local k = c:GetEffectiveScale() / d:GetEffectiveScale()
	return c:GetWidth() * k, c:GetHeight() * k
end

local function vue()
	local vl, vh = tailleVue()
	local x, y = Z.cx * CARTE_L, Z.cy * CARTE_H
	return x - vl / 2, y - vh / 2, x + vl / 2, y + vh / 2
end
Z.vue = vue

-- le centre reste ou la vue tient dans la carte
local function borner()
	local vl, vh = tailleVue()
	local demiX, demiY = vl / 2 / CARTE_L, vh / 2 / CARTE_H
	if demiX >= 0.5 then Z.cx = 0.5 else Z.cx = math.max(demiX, math.min(1 - demiX, Z.cx)) end
	if demiY >= 0.5 then Z.cy = 0.5 else Z.cy = math.max(demiY, math.min(1 - demiY, Z.cy)) end
end

-- ---------------------------------------------------------------- les tuiles

-- chaque tuile rognee a la vue : sa part visible, a sa place, ses coordonnees
local function rogner()
	local d = WorldMapDetailFrame
	local x0, y0, x1, y1 = vue()
	for rangee = 1, RANGEES do
		for colonne = 1, COLONNES do
			local t = tuile((rangee - 1) * COLONNES + colonne)
			if t then
				local tx, ty = (colonne - 1) * TUILE, (rangee - 1) * TUILE
				local ix0, iy0 = math.max(tx, x0), math.max(ty, y0)
				local ix1 = math.min(tx + TUILE, CARTE_L, x1)
				local iy1 = math.min(ty + TUILE, CARTE_H, y1)
				t:ClearAllPoints()
				if ix1 - ix0 < 0.01 or iy1 - iy0 < 0.01 then
					t:SetPoint("TOPLEFT", d, "TOPLEFT", tx, -ty)
					t:SetWidth(1)
					t:SetHeight(1)
					t:SetAlpha(0)
				else
					t:SetPoint("TOPLEFT", d, "TOPLEFT", ix0, -iy0)
					t:SetWidth(ix1 - ix0)
					t:SetHeight(iy1 - iy0)
					t:SetTexCoord((ix0 - tx) / TUILE, (ix1 - tx) / TUILE, (iy0 - ty) / TUILE, (iy1 - ty) / TUILE)
					t:SetAlpha(1)
				end
			end
		end
	end
end

-- les tuiles de WorldMapFrame.xml (541-636) : la premiere au coin, chacune a
-- droite de la precedente, une rangee sous la premiere de la rangee d'avant ;
-- puis le rognage de la petite fenetre (WorldMap.lua)
local function rechainer()
	for k = 1, COLONNES * RANGEES do
		local t = tuile(k)
		if t then
			t:ClearAllPoints()
			t:SetAlpha(1)
			if k == 1 then
				t:SetPoint("TOPLEFT", WorldMapDetailFrame, "TOPLEFT", 0, 0)
			elseif (k - 1) % COLONNES == 0 then
				t:SetPoint("TOPLEFT", tuile(k - COLONNES), "BOTTOMLEFT", 0, 0)
			else
				t:SetPoint("TOPLEFT", tuile(k - 1), "TOPRIGHT", 0, 0)
			end
		end
	end
	if W.rognerTuiles then W.rognerTuiles(true) end
end

-- --------------------------------------------------------------- les reperes

-- un repere sort de la vue : il s'eteint, et lache la souris (eteint, il
-- volerait encore le survol et les clics du journal ou du cadre) ; il y
-- revient : il reprend son alpha et sa souris
local function eteindre(f)
	f.foreverZoomAlpha = f:GetAlpha()
	f.foreverZoomSouris = f.IsMouseEnabled and f:IsMouseEnabled() and true or false
	f:SetAlpha(0)
	if f.foreverZoomSouris then f:EnableMouse(false) end
end

local function rendre(f)
	f:SetAlpha(f.foreverZoomAlpha)
	if f.foreverZoomSouris then f:EnableMouse(true) end
	f.foreverZoomAlpha, f.foreverZoomSouris = nil, nil
end

local function trier()
	local c = W.canevas
	local e = c:GetEffectiveScale()
	local gauche, bas, droite, haut = c:GetLeft(), c:GetBottom(), c:GetRight(), c:GetTop()
	if not (gauche and bas and droite and haut) then return end
	gauche, bas, droite, haut = gauche * e, bas * e, droite * e, haut * e
	for _, parent in ipairs({ WorldMapButton, WorldMapPOIFrame }) do
		if parent then
			for _, f in ipairs({ parent:GetChildren() }) do
				if f ~= WorldMapFrameAreaFrame and f:IsShown() then
					local x, y = f:GetCenter()
					local fe = f:GetEffectiveScale()
					local dedans = not x or (x * fe >= gauche and x * fe <= droite and y * fe >= bas and y * fe <= haut)
					if dedans then
						if f.foreverZoomAlpha then rendre(f) end
					elseif not f.foreverZoomAlpha then
						eteindre(f)
					end
				end
			end
		end
	end
end

local function rallumer()
	for _, parent in ipairs({ WorldMapButton, WorldMapPOIFrame }) do
		if parent then
			for _, f in ipairs({ parent:GetChildren() }) do
				if f.foreverZoomAlpha then rendre(f) end
			end
		end
	end
end

-- ------------------------------------------------------------- appliquer

-- la carte courante : un changement de carte ramene le zoom a 1
function Z.cleCarte()
	return tostring(GetCurrentMapAreaID and GetCurrentMapAreaID()) .. ":" ..
		tostring(GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel())
end

local function echelles()
	local base = WORLDMAP_SETTINGS.size
	return {
		{ WorldMapDetailFrame, base * Z.z, base },
		{ WorldMapButton, base * Z.z, base },
		{ WorldMapBlobFrame, base * Z.z, base },
		{ WorldMapPOIFrame, Z.z, 1 },
		{ WorldMapFrameAreaFrame, (Z.aireEchelle or 1) / Z.z, Z.aireEchelle or 1 },
	}
end

function Z.appliquer()
	local d = WorldMapDetailFrame
	if not Z.actif then
		Z.actif = true
		Z.points = {}
		for i = 1, d:GetNumPoints() do
			Z.points[i] = { d:GetPoint(i) }
		end
		Z.aireEchelle = WorldMapFrameAreaFrame and WorldMapFrameAreaFrame:GetScale() or 1
		Z.cle = Z.cleCarte()
	end
	for _, e in ipairs(echelles()) do
		if e[1] then e[1]:SetScale(e[2]) end
	end
	borner()
	d:ClearAllPoints()
	d:SetPoint("CENTER", W.canevas, "CENTER", (0.5 - Z.cx) * CARTE_L, (Z.cy - 0.5) * CARTE_H)
	if WorldMapBlobFrame then
		WorldMapBlobFrame:SetAlpha(0)
		if WorldMapBlobFrame_CalculateHitTranslations then WorldMapBlobFrame_CalculateHitTranslations() end
	end
	local a = WorldMapFrameAreaFrame
	if a then
		a:ClearAllPoints()
		a:SetPoint("TOP", W.canevas, "TOP", 0, -10)
	end
	local x0, y0, x1, y1 = vue()
	WorldMapButton:SetHitRectInsets(math.max(0, x0), math.max(0, CARTE_L - x1),
		math.max(0, y0), math.max(0, CARTE_H - y1))
	rogner()
	trier()
end

-- retour a la carte entiere. Apres un changement de mode, le client et
-- WorldMap.lua viennent de poser leurs propres echelles et ancres : on ne
-- rend que ce qui porte encore notre marque.
function Z.retablir(changementDeMode)
	if not Z.actif then
		Z.z = 1
		return
	end
	local zoome = echelles()
	Z.z = 1
	local rendre = echelles()
	for i, e in ipairs(zoome) do
		if e[1] and math.abs(e[1]:GetScale() - e[2]) < 1e-6 then
			e[1]:SetScale(rendre[i][3])
		end
	end
	Z.actif = false
	local d = WorldMapDetailFrame
	if not changementDeMode and Z.points then
		d:ClearAllPoints()
		for _, p in ipairs(Z.points) do
			d:SetPoint(p[1], p[2], p[3], p[4], p[5])
		end
	end
	if WorldMapBlobFrame then
		WorldMapBlobFrame:SetAlpha(1)
		if WorldMapBlobFrame_CalculateHitTranslations then WorldMapBlobFrame_CalculateHitTranslations() end
	end
	local a = WorldMapFrameAreaFrame
	if a then
		a:ClearAllPoints()
		a:SetPoint("TOP", WorldMapButton, "TOP", 0, -10)
	end
	WorldMapButton:SetHitRectInsets(0, 0, 0, 0)
	WorldMapButton:EnableMouse(true)
	Z.appui, Z.glisse = nil, false
	rechainer()
	rallumer()
	Z.cx, Z.cy = 0.5, 0.5
end

-- ------------------------------------------------------------- la molette

-- le point de la carte sous le curseur, et l'ecart du curseur au centre du
-- canevas, en pixels d'ecran
local function sousCurseur()
	local x, y = GetCursorPosition()
	local c = W.canevas
	local cx, cy = c:GetCenter()
	if not cx then return nil end
	local ce = c:GetEffectiveScale()
	local dx, dy = x - cx * ce, y - cy * ce
	local de = WorldMapDetailFrame:GetEffectiveScale()
	return Z.cx + dx / (CARTE_L * de), Z.cy - dy / (CARTE_H * de), dx, dy, de
end

function Z.molette(sens)
	if not pret() then return end
	local ancien = Z.z
	local nouveau = sens > 0 and ancien * Z.PAS or ancien / Z.PAS
	if nouveau > Z.MAX then nouveau = Z.MAX end
	if nouveau < 1.0001 then nouveau = 1 end
	if nouveau == ancien then return end
	if nouveau == 1 then
		Z.retablir(false)
		return
	end
	if not Z.actif then Z.cx, Z.cy = 0.5, 0.5 end
	-- le point sous le curseur y reste (SetPanTarget de camelot)
	local fx, fy, dx, dy, de = sousCurseur()
	Z.z = nouveau
	if fx then
		local de2 = de * nouveau / ancien
		Z.cx = fx - dx / (CARTE_L * de2)
		Z.cy = fy + dy / (CARTE_H * de2)
	end
	Z.appliquer()
end

-- --------------------------------------------------------------- la veille

local cleCarte = Z.cleCarte

-- fille de la carte : elle ne tourne que carte ouverte
local veille = CreateFrame("Frame", nil, WorldMapFrame)
veille:SetScript("OnUpdate", function()
	if not (Z.actif and pret()) then
		Z.cle = pret() and cleCarte() or nil
		return
	end
	if cleCarte() ~= Z.cle then
		Z.retablir(false)
		Z.cle = cleCarte()
		return
	end
	-- LE GLISSER : au-dela de SEUIL pixels, la carte suit le curseur ;
	-- WorldMapButton lache la souris jusqu'au relachement
	local appui = Z.appui
	if appui then
		local x, y = GetCursorPosition()
		if not IsMouseButtonDown("LeftButton") then
			Z.appui = nil
			if Z.glisse then
				Z.glisse = false
				WorldMapButton:EnableMouse(true)
			end
		else
			if not Z.glisse and math.abs(x - appui.x) + math.abs(y - appui.y) > Z.SEUIL then
				Z.glisse = true
				WorldMapButton:EnableMouse(false)
			end
			if Z.glisse then
				local de = WorldMapDetailFrame:GetEffectiveScale()
				Z.cx = appui.cx - (x - appui.x) / (CARTE_L * de)
				Z.cy = appui.cy + (y - appui.y) / (CARTE_H * de)
				Z.appliquer()
				return
			end
		end
	end
	trier()
end)
Z.veille = veille

-- ------------------------------------------------------------ le branchement

if WorldMapButton then
	WorldMapButton:EnableMouseWheel(true)
	WorldMapButton:SetScript("OnMouseWheel", function(_, sens)
		Z.molette(sens)
	end)
	WorldMapButton:HookScript("OnMouseDown", function(_, bouton)
		if bouton == "LeftButton" and Z.actif then
			local x, y = GetCursorPosition()
			Z.appui = { x = x, y = y, cx = Z.cx, cy = Z.cy }
			Z.glisse = false
		end
	end)
	-- la fleche du joueur : WorldMapButton_OnUpdate la pose a l'echelle de
	-- WotLK (position x WORLDMAP_SETTINGS.size) ; on la repose x zoom, ou on
	-- l'eteint hors de la vue
	WorldMapButton:HookScript("OnUpdate", function()
		if not Z.actif then return end
		local x, y = GetPlayerMapPosition("player")
		if not x or (x == 0 and y == 0) then return end
		local px, py = x * CARTE_L, y * CARTE_H
		local x0, y0, x1, y1 = vue()
		if px < x0 or px > x1 or py < y0 or py > y1 then
			if ShowWorldMapArrowFrame then ShowWorldMapArrowFrame(nil) end
		elseif PositionWorldMapArrowFrame then
			local s = WORLDMAP_SETTINGS.size * Z.z
			PositionWorldMapArrowFrame("CENTER", "WorldMapDetailFrame", "TOPLEFT", px * s, -py * s)
		end
	end)
end

if WorldMapFrame then
	WorldMapFrame:HookScript("OnHide", function() Z.retablir(false) end)
end

-- WorldMapFrame_Update recharge les tuiles (WORLD_MAP_UPDATE) : zoomee, la
-- carte les rogne de nouveau
if WorldMapFrame_Update then
	hooksecurefunc("WorldMapFrame_Update", function()
		if Z.actif then rogner() end
	end)
end

-- un changement de mode ou de vue : retour a 1, sans reprendre ce que le
-- client vient de poser
for _, nom in ipairs({ "WorldMap_ToggleSizeDown", "WorldMap_ToggleSizeUp", "WorldMapFrame_SetMiniMode",
	"WorldMapFrame_SetQuestMapView", "WorldMapFrame_SetFullMapView" }) do
	if _G[nom] then
		hooksecurefunc(nom, function() Z.retablir(true) end)
	end
end
