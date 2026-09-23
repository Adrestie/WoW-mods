-- ForeverUI : la barre de defilement de camelot, MinimalScrollBar.
--
-- RELEVE -- camelot/reputationframe.xml et blizzard_tokenui/camelot :
--   <EventFrame parentKey="ScrollBar" inherits="MinimalScrollBar">
--     TOPLEFT    sur le TOPRIGHT du ScrollBox    (5, -2)
--     BOTTOMLEFT sur le BOTTOMRIGHT du ScrollBox (5,  4)
--
-- MESURE SUR L'ART, et non d'apres les noms -- la regle vaut ici plus
-- qu'ailleurs, les noms de ces atlas ne disant pas ce qu'ils portent :
--
--   minimal-scrollbar-track-top / -bottom    8 x 8, noir a 60 % d'alpha,
--                                            le texel du bout transparent :
--                                            ce sont les deux embouts
--                                            arrondis de la glissiere
--   !minimal-scrollbar-track-middle          8 x 1, faite pour s'etirer
--   minimal-scrollbar-thumb-top              8 x 8, brun : l'embout du haut
--   minimal-scrollbar-thumb-middle           8 x 515, brun, etirable
--   minimal-scrollbar-thumb-bottom           8 x 36 -- et ce N'EST PAS un
--                                            embout : son alpha monte de 1 a
--                                            255 sur les 36 pixels, donc son
--                                            HAUT est transparent. Posee au
--                                            bas du curseur, elle le faisait
--                                            fondre dans le noir de la
--                                            glissiere. ELLE N'EST PAS
--                                            EMPLOYEE.
--   minimal-scrollbar-arrow-top / -bottom    17 x 11, plus larges que la
--                                            barre : elles la debordent de
--                                            4,5 de chaque cote
--
-- LES DEUX BOUTS DU CURSEUR SONT LE MEME MORCEAU, le second RETOURNE.
-- thumb-top est opaque d'un bord a l'autre, avec un filet clair sur son
-- premier texel : c'est un embout fini. On le pose en haut tel quel et en
-- bas retourne, et le milieu s'etire entre les deux -- le curseur est alors
-- plein jusqu'a ses extremites, ce que la demande veut. Ecart assume, et
-- mesure : garder le morceau nomme "bottom" donnait un degrade.
--
-- CE QUI DIFFERE, ET POURQUOI. 3.3.5 n'a pas MinimalScrollBar, ni le
-- ScrollBox qui le pilote : la barre est refaite en entier, et c'est
-- l'appelant qui lui dit combien de lignes existent, combien tiennent, et
-- ou il en est. Elle lui rend le nouveau decalage, rien de plus -- elle ne
-- touche a aucune liste.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local LARGEUR = 8
local FLECHE_L, FLECHE_H = 17, 11
local CURSEUR_BOUT = 8                  -- minimal-scrollbar-thumb-top
local CURSEUR_MIN = 2 * CURSEUR_BOUT    -- ses deux bouts, sans milieu
local TRACK_BOUT = 8

local ATLAS = {
	trackHaut = "minimal-scrollbar-track-top-c60",
	trackMilieu = "!minimal-scrollbar-track-middle-c60",
	trackBas = "minimal-scrollbar-track-bottom-c60",
	curseurBout = "minimal-scrollbar-thumb-top-c60",
	curseurMilieu = "minimal-scrollbar-thumb-middle-c60",
	flecheHaut = "minimal-scrollbar-arrow-top-c60",
	flecheHautSurvol = "minimal-scrollbar-arrow-top-over-c60",
	flecheBas = "minimal-scrollbar-arrow-bottom-c60",
	flecheBasSurvol = "minimal-scrollbar-arrow-bottom-over-c60",
}

-- OU EN EST LA SOURIS, dans le repere d'un cadre. GetCursorPosition rend des
-- coordonnees d'ECRAN : il faut les ramener a l'echelle du cadre.
local function souris(cadre)
	local _, y = GetCursorPosition()
	return y / (cadre:GetEffectiveScale() or 1)
end

local function creerFleche(barre, nom, atlas, atlasSurvol, pas)
	local bouton = CreateFrame("Button", nom, barre)
	bouton:SetWidth(FLECHE_L)
	bouton:SetHeight(FLECHE_H)

	local image = bouton:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(image, atlas, true)
	image:SetAllPoints(bouton)
	bouton.image = image

	bouton:SetScript("OnEnter", function(self)
		ForeverUI.SetAtlas(self.image, atlasSurvol, true)
	end)
	bouton:SetScript("OnLeave", function(self)
		ForeverUI.SetAtlas(self.image, atlas, true)
	end)
	bouton:SetScript("OnClick", function()
		barre:Deplacer(barre.decalage + pas)
	end)

	return bouton
end

-- LA BARRE. `parent` la porte, `liste` est ce qu'elle fait defiler : on
-- s'ancre sur lui comme camelot le fait sur son ScrollBox.
function ForeverUI.CreateScrollBar(nom, parent, liste)
	local barre = CreateFrame("Frame", nom, parent)
	barre:SetWidth(LARGEUR)
	barre:SetPoint("TOPLEFT", liste, "TOPRIGHT", 5, -2)
	barre:SetPoint("BOTTOMLEFT", liste, "BOTTOMRIGHT", 5, 4)

	barre.total = 0
	barre.visibles = 0
	barre.decalage = 0

	local haut = creerFleche(barre, nom .. "Up", ATLAS.flecheHaut,
		ATLAS.flecheHautSurvol, -1)
	haut:SetPoint("TOP", barre, "TOP", 0, 0)
	barre.flecheHaut = haut

	local bas = creerFleche(barre, nom .. "Down", ATLAS.flecheBas,
		ATLAS.flecheBasSurvol, 1)
	bas:SetPoint("BOTTOM", barre, "BOTTOM", 0, 0)
	barre.flecheBas = bas

	-- LA GLISSIERE, entre les deux fleches : deux embouts et un milieu tendu.
	local piste = CreateFrame("Frame", nil, barre)
	piste:SetPoint("TOPLEFT", haut, "BOTTOMLEFT", 0, 0)
	piste:SetPoint("BOTTOMRIGHT", bas, "TOPRIGHT", 0, 0)
	piste:SetWidth(LARGEUR)
	barre.piste = piste

	local function tranche(cadre, atlas, couche)
		local t = cadre:CreateTexture(nil, couche or "BACKGROUND")
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetWidth(LARGEUR)
		return t
	end

	local pisteHaut = tranche(piste, ATLAS.trackHaut)
	pisteHaut:SetHeight(TRACK_BOUT)
	pisteHaut:SetPoint("TOP", piste, "TOP", 0, 0)
	local pisteBas = tranche(piste, ATLAS.trackBas)
	pisteBas:SetHeight(TRACK_BOUT)
	pisteBas:SetPoint("BOTTOM", piste, "BOTTOM", 0, 0)
	local pisteMilieu = tranche(piste, ATLAS.trackMilieu)
	pisteMilieu:SetPoint("TOPLEFT", pisteHaut, "BOTTOMLEFT", 0, 0)
	pisteMilieu:SetPoint("BOTTOMRIGHT", pisteBas, "TOPRIGHT", 0, 0)

	-- LE CURSEUR : ses trois tranches, dans un cadre qu'on deplace.
	local curseur = CreateFrame("Frame", nom .. "Thumb", piste)
	curseur:SetWidth(LARGEUR)
	curseur:SetHeight(CURSEUR_MIN)
	curseur:EnableMouse(true)
	barre.curseur = curseur

	local cHaut = tranche(curseur, ATLAS.curseurBout, "ARTWORK")
	cHaut:SetHeight(CURSEUR_BOUT)
	cHaut:SetPoint("TOP", curseur, "TOP", 0, 0)

	-- LE MEME MORCEAU, RETOURNE : on echange le haut et le bas de son
	-- rectangle d'atlas.
	local cBas = tranche(curseur, ATLAS.curseurBout, "ARTWORK")
	local e = ForeverUI.AtlasEntry(ATLAS.curseurBout)
	if e then
		cBas:SetTexCoord(e[2], e[3], e[5], e[4])
	end
	cBas:SetHeight(CURSEUR_BOUT)
	cBas:SetPoint("BOTTOM", curseur, "BOTTOM", 0, 0)

	local cMilieu = tranche(curseur, ATLAS.curseurMilieu, "ARTWORK")
	cMilieu:SetPoint("TOPLEFT", cHaut, "BOTTOMLEFT", 0, 0)
	cMilieu:SetPoint("BOTTOMRIGHT", cBas, "TOPRIGHT", 0, 0)

	-- CE QUE LA BARRE SAIT FAIRE.

	-- Deplacer d'un cran, en bornant : elle ne connait pas la liste, elle
	-- ne connait que ses trois nombres.
	function barre:Deplacer(vers)
		local maximum = math.max(0, self.total - self.visibles)
		vers = math.max(0, math.min(math.floor(vers + 0.5), maximum))
		if vers == self.decalage then
			return
		end
		self.decalage = vers
		self:Repositionner()
		if self.surDefilement then
			self.surDefilement(vers)
		end
	end

	-- Poser le curseur : sa hauteur dit la part visible, sa place le
	-- decalage.
	function barre:Repositionner()
		local hauteur = self.piste:GetHeight() or 0
		local maximum = math.max(0, self.total - self.visibles)

		if hauteur <= 0 or maximum <= 0 then
			self.curseur:Hide()
			return
		end

		local part = self.visibles / self.total
		local taille = math.max(CURSEUR_MIN, math.floor(hauteur * part + 0.5))
		if taille > hauteur then
			taille = hauteur
		end
		local course = hauteur - taille

		self.curseur:SetHeight(taille)
		self.curseur:ClearAllPoints()
		self.curseur:SetPoint("TOP", self.piste, "TOP", 0,
			-course * (self.decalage / maximum))
		self.curseur:Show()
	end

	-- CE QUE L'APPELANT LUI DIT : combien de lignes, combien tiennent, ou il
	-- en est. La barre s'efface quand tout tient.
	function barre:Regler(total, visibles, decalage)
		self.total = total or 0
		self.visibles = visibles or 0
		self.decalage = decalage or 0
		if self.total <= self.visibles then
			self:Hide()
			return
		end
		self:Show()
		self:Repositionner()
	end

	-- GLISSER LE CURSEUR. Un OnUpdate le suit tant que le bouton est tenu :
	-- 3.3.5 n'a pas de suivi de souris sur un cadre.
	curseur:SetScript("OnMouseDown", function(self)
		self.prise = souris(self)
		self.priseDecalage = barre.decalage
		self:SetScript("OnUpdate", function(soi)
			local hauteur = barre.piste:GetHeight() or 0
			local course = hauteur - (soi:GetHeight() or 0)
			local maximum = math.max(0, barre.total - barre.visibles)
			if course <= 0 or maximum <= 0 then
				return
			end
			local parcouru = soi.prise - souris(soi)
			barre:Deplacer(soi.priseDecalage + parcouru / course * maximum)
		end)
	end)
	curseur:SetScript("OnMouseUp", function(self)
		self:SetScript("OnUpdate", nil)
	end)

	-- CLIQUER LA GLISSIERE saute d'une page, du cote ou l'on a clique.
	piste:EnableMouse(true)
	piste:SetScript("OnMouseDown", function(self)
		local y = souris(self)
		local dessus = barre.curseur:GetTop() or 0
		local dessous = barre.curseur:GetBottom() or 0
		if y > dessus then
			barre:Deplacer(barre.decalage - barre.visibles)
		elseif y < dessous then
			barre:Deplacer(barre.decalage + barre.visibles)
		end
	end)

	barre:Hide()
	return barre
end
