-- ForeverUI : les gabarits de camelot reproduits une fois pour les ecrans
-- d'accueil (suite de ForeverUIGlue.lua) : l'atlas etire selon sa decoupe
-- officielle, la mosaique, le bouton a art, le bouton carre a icone, la
-- barre de defilement minimale.

local G = ForeverUIGlue

-- ajoute un traitement apres une fonction globale du client, sans la
-- remplacer quand le client sait le faire (hooksecurefunc)
function G.AccrocherFonction(nom, fonction)
	if hooksecurefunc then
		hooksecurefunc(nom, fonction)
		return
	end
	local avant = _G[nom]
	_G[nom] = function(...)
		local r1, r2, r3, r4 = avant(...)
		fonction(...)
		return r1, r2, r3, r4
	end
end

-- ------------------------------------------------------------ l'atlas etire

-- Un element d'atlas a DECOUPE (UiTextureAtlasElementSliceData, dixieme champ
-- de la table) se dessine en neuf morceaux quand on l'etire : les marges
-- gardent leur taille, le reste s'etire. 3.3.5 n'a pas cette decoupe : on
-- pose les morceaux, en regions de l'hote, autour d'un rectangle invisible
-- que l'appelant ancre comme il ancrerait la texture de camelot.
-- Rend { rect = <texture a ancrer>, Poser = function(self, nom), Montrer }.
local function decouper(obj)
	local e = obj.e
	local d = e[10]
	for _, t in ipairs(obj.pieces) do
		t:Hide()
	end
	if not d then
		obj.rect:SetTexture(e[1])
		obj.rect:SetTexCoord(e[2], e[3], e[4], e[5])
		return
	end
	obj.rect:SetTexture(nil)
	local W, H = e[6], e[7]
	local g, h, dr, b = d[1], d[2], d[3], d[4]
	local us = { e[2], e[2] + (e[3] - e[2]) * g / W, e[3] - (e[3] - e[2]) * dr / W, e[3] }
	local vs = { e[4], e[4] + (e[5] - e[4]) * h / H, e[5] - (e[5] - e[4]) * b / H, e[5] }
	local largeurs = { g, nil, dr }
	local hauteurs = { h, nil, b }
	local r = obj.rect
	local n = 0
	for ligne = 1, 3 do
		for col = 1, 3 do
			local lw, lh = largeurs[col], hauteurs[ligne]
			if (lw == nil or lw > 0) and (lh == nil or lh > 0) then
				n = n + 1
				local t = obj.pieces[n]
				if not t then
					t = obj.hote:CreateTexture(nil, obj.couche)
					obj.pieces[n] = t
				end
				t:SetTexture(e[1])
				t:SetTexCoord(us[col], us[col + 1], vs[ligne], vs[ligne + 1])
				t:ClearAllPoints()
				if col == 1 then
					t:SetPoint("LEFT", r, "LEFT")
					t:SetWidth(lw)
				elseif col == 3 then
					t:SetPoint("RIGHT", r, "RIGHT")
					t:SetWidth(lw)
				else
					t:SetPoint("LEFT", r, "LEFT", g, 0)
					t:SetPoint("RIGHT", r, "RIGHT", -dr, 0)
				end
				if ligne == 1 then
					t:SetPoint("TOP", r, "TOP")
					t:SetHeight(lh)
				elseif ligne == 3 then
					t:SetPoint("BOTTOM", r, "BOTTOM")
					t:SetHeight(lh)
				else
					t:SetPoint("TOP", r, "TOP", 0, -h)
					t:SetPoint("BOTTOM", r, "BOTTOM", 0, b)
				end
				if obj.visible ~= false then
					t:Show()
				end
			end
		end
	end
	obj.nombre = n
end

function G.AtlasEtire(hote, nom, couche)
	local obj = { hote = hote, couche = couche or "ARTWORK", pieces = {} }
	obj.rect = hote:CreateTexture(nil, obj.couche)
	function obj:Poser(n)
		self.e = G.atlas[string.lower(n)]
		if not self.e then
			error("element d'atlas absent de la table d'accueil : " .. tostring(n))
		end
		decouper(self)
	end
	function obj:Montrer(oui)
		self.visible = oui and true or false
		if self.e[10] then
			for i = 1, self.nombre or 0 do
				G.Montrer(self.pieces[i], oui)
			end
		else
			G.Montrer(self.rect, oui)
		end
	end
	obj:Poser(nom)
	return obj
end

-- ------------------------------------------------------------ la mosaique

-- Un element en mosaique (drapeaux de UiTextureAtlasMember) se repete a sa
-- taille native au lieu de s'etirer. En 3.3.5 l'element doit occuper toute
-- sa feuille ; on lit la part de l'image que couvre le cadre, depuis son coin
-- haut gauche.
function G.Mosaique(texture, nom, largeur, hauteur)
	local e = G.atlas[string.lower(nom)]
	texture:SetTexture(e[1], true)
	texture:SetTexCoord(0, largeur / e[6], 0, hauteur / e[7])
end

-- ------------------------------------------------------------ le bouton a art

-- UIButtonTemplate (blizzard_sharedxml/shared/button/uibuttontemplate.lua,
-- SetButtonArtKit) : l'element artKit et ses variantes -Pressed, -Disabled,
-- -Highlight, sur tout le bouton ; lueur en ADD. Survit a
-- CharacterSelect_DeathKnightSwap (qui repose l'art du client).
local function poserArt(b)
	local kit = b.foreverArt
	for _, v in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "" },
		{ "SetPushedTexture", "GetPushedTexture", "-Pressed" },
		{ "SetDisabledTexture", "GetDisabledTexture", "-Disabled" },
		{ "SetHighlightTexture", "GetHighlightTexture", "-Highlight" },
	}) do
		local nom = kit .. v[3]
		b[v[1]](b, G.atlas[string.lower(nom)][1])
		local t = b[v[2]](b)
		G.PoserAtlas(t, nom)
		t:ClearAllPoints()
		t:SetAllPoints(b)
		if v[3] == "-Highlight" then
			t:SetBlendMode("ADD")
		end
	end
	b.foreverArtFichier = b:GetNormalTexture():GetTexture()
end

function G.BoutonArt(b, artKit)
	b.foreverArt = artKit
	poserArt(b)
	local texte = b:GetFontString()
	if texte then
		texte:SetText("")
	end
	if not b.foreverArtAccroche then
		b.foreverArtAccroche = true
		G.Accrocher(b, "OnUpdate", function(self)
			local n = self:GetNormalTexture()
			if not n or n:GetTexture() ~= self.foreverArtFichier then
				poserArt(self)
			end
		end)
	end
	return b
end

-- ------------------------------------------------------------ le bouton carre

-- CommonSquareIconButtonTemplate (iconbuttontemplate.xml / .lua) : 48 x 48,
-- zone cliquable retrecie de 6 ; fond common-button-square-gray-up, enfonce
-- -down decale de (1, -1) ; icone de iconSize (24) au centre, qui descend de
-- (1, -1) quand on appuie ; lueur = l'icone en ADD a 0,4, calee sur elle.
-- couche : celle de l'icone ; OVERLAY chez camelot (IconButtonTemplate,
-- CustomizationSmallButtonTemplate), au-dessus du fond gris dont le centre est
-- opaque a 67 %. ARTWORK par defaut ; A EVITER : le fond (NormalTexture)
-- est aussi en ARTWORK, et deux textures d'un meme calque se dessinent dans
-- un ordre que le moteur peut changer -- l'icone passait tantot sous le fond,
-- ternie (rotation de la selection, 28/09). Passer "OVERLAY".
function G.BoutonCarreIcone(b, icone, tailleIcone, couche)
	G.EffacerArtClient(b)
	b:SetWidth(48)
	b:SetHeight(48)
	b:SetHitRectInsets(6, 6, 6, 6)
	local function fond(poser, lire, nom)
		b[poser](b, G.atlas[nom][1])
		local t = b[lire](b)
		G.PoserAtlas(t, nom)
		t:ClearAllPoints()
		return t
	end
	fond("SetNormalTexture", "GetNormalTexture", "common-button-square-gray-up"):SetAllPoints(b)
	local p = fond("SetPushedTexture", "GetPushedTexture", "common-button-square-gray-down")
	p:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
	p:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
	fond("SetDisabledTexture", "GetDisabledTexture", "common-button-square-gray-up"):SetAllPoints(b)

	local ic = b:CreateTexture(nil, couche or "ARTWORK")
	G.PoserAtlas(ic, icone)
	ic:SetWidth(tailleIcone or 24)
	ic:SetHeight(tailleIcone or 24)
	ic:SetPoint("CENTER", b, "CENTER")
	b.foreverIcone = ic

	b:SetHighlightTexture(G.atlas[string.lower(icone)][1])
	local h = b:GetHighlightTexture()
	G.PoserAtlas(h, icone)
	h:SetBlendMode("ADD")
	h:SetAlpha(0.4)
	h:ClearAllPoints()
	h:SetPoint("TOPLEFT", ic, "TOPLEFT")
	h:SetPoint("BOTTOMRIGHT", ic, "BOTTOMRIGHT")

	G.Accrocher(b, "OnMouseDown", function(self)
		if self:IsEnabled() then
			ic:SetPoint("CENTER", self, "CENTER", 1, -1)
		end
	end)
	G.Accrocher(b, "OnMouseUp", function(self)
		ic:SetPoint("CENTER", self, "CENTER")
	end)
	return b
end

-- ------------------------------------------------------------ la barre de defilement

-- MinimalScrollBar (blizzard_sharedxml/shared/scroll/minimalscrollbar.xml et
-- .lua, scrollbar.lua) : 8 de large ; glissiere de (0, -19) a (0, 19)
-- (track-top 8 x 8, !track-middle etiree, track-bottom) ; curseur
-- small-thumb (haut, milieu lu a sa taille et non etire, bas ; -over au
-- survol, -down enfonce), proportionnel a la part visible, au moins 23 ;
-- fleches arrow-top / -bottom (17 x 11, -over, -down) decalees de (1, -1)
-- enfoncees, desaturees quand elles ne peuvent plus rien. Quand tout tient :
-- plus de curseur, glissiere seule, fleches desactivees ; ou la barre entiere
-- cachee si barre.cacherSiInutile (hideIfUnscrollable de ScrollBarMixin).
-- En unites d'affichage : barre:Regler(total, visible, position),
-- barre.surDefilement(position) ; une fleche avance de barre.pas.
function G.BarreMinimale(parent, nom)
	local barre = CreateFrame("Frame", nom, parent)
	barre:SetWidth(8)
	barre.total, barre.visible, barre.position, barre.pas = 0, 0, 0, 0

	local piste = CreateFrame("Frame", nil, barre)
	piste:SetWidth(8)
	piste:SetPoint("TOP", barre, "TOP", 0, -19)
	piste:SetPoint("BOTTOM", barre, "BOTTOM", 0, 19)
	piste:EnableMouse(true)
	local ph = piste:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(ph, "minimal-scrollbar-track-top", true)
	ph:SetPoint("TOPLEFT", piste, "TOPLEFT")
	local pb = piste:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(pb, "minimal-scrollbar-track-bottom", true)
	pb:SetPoint("BOTTOMLEFT", piste, "BOTTOMLEFT")
	local pm = piste:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(pm, "!minimal-scrollbar-track-middle", true)
	pm:SetPoint("TOPLEFT", ph, "BOTTOMLEFT")
	pm:SetPoint("BOTTOMRIGHT", pb, "TOPRIGHT")

	local curseur = CreateFrame("Button", nil, piste)
	curseur:SetWidth(8)
	curseur:SetHitRectInsets(-4, -4, -4, -4)
	local ch = curseur:CreateTexture(nil, "ARTWORK")
	ch:SetPoint("TOPLEFT", curseur, "TOPLEFT")
	local cb = curseur:CreateTexture(nil, "ARTWORK")
	cb:SetPoint("BOTTOMLEFT", curseur, "BOTTOMLEFT")
	local cm = curseur:CreateTexture(nil, "ARTWORK")
	cm:SetPoint("TOPLEFT", ch, "BOTTOMLEFT")
	cm:SetPoint("BOTTOMRIGHT", cb, "TOPRIGHT")
	local function peindreCurseur(etat)
		local s = etat and ("-" .. etat) or ""
		G.PoserAtlas(ch, "minimal-scrollbar-small-thumb-top" .. s, true)
		G.PoserAtlas(cb, "minimal-scrollbar-small-thumb-bottom" .. s, true)
		local e = G.PoserAtlas(cm, "minimal-scrollbar-small-thumb-middle" .. s, true)
		-- le milieu se lit a sa taille, sans s'etirer (OnSizeChanged du curseur)
		local h = math.max(0, (curseur:GetHeight() or 0) - ch:GetHeight() - cb:GetHeight())
		cm:SetTexCoord(e[2], e[3], e[4], e[4] + (e[5] - e[4]) * math.min(1, h / e[7]))
	end
	barre.curseur = curseur

	local function fleche(haut)
		local base = haut and "minimal-scrollbar-arrow-top" or "minimal-scrollbar-arrow-bottom"
		local f = CreateFrame("Button", nil, barre)
		local t = f:CreateTexture(nil, "ARTWORK")
		local e = G.PoserAtlas(t, base, true)
		f:SetWidth(e[6])
		f:SetHeight(e[7])
		t:SetPoint("CENTER", f, "CENTER")
		f:SetPoint(haut and "TOP" or "BOTTOM", barre, haut and "TOP" or "BOTTOM")
		local function peindre()
			local n = base
			if f:IsEnabled() then
				if f.bas then n = base .. "-down" elseif f.dessus then n = base .. "-over" end
			end
			G.PoserAtlas(t, n, true)
			t:SetDesaturated(not f:IsEnabled())
			t:ClearAllPoints()
			if f.bas and f:IsEnabled() then
				t:SetPoint("CENTER", f, "CENTER", 1, -1)
			else
				t:SetPoint("CENTER", f, "CENTER")
			end
		end
		f:SetScript("OnEnter", function() f.dessus = true; peindre() end)
		f:SetScript("OnLeave", function() f.dessus = false; peindre() end)
		f:SetScript("OnMouseDown", function() f.bas = true; peindre() end)
		f:SetScript("OnMouseUp", function() f.bas = false; peindre() end)
		f:SetScript("OnClick", function()
			barre:Deplacer(barre.position + (haut and -barre.pas or barre.pas))
		end)
		f.peindre = peindre
		return f
	end
	local monter, descendre = fleche(true), fleche(false)

	local function maximum()
		return math.max(0, barre.total - barre.visible)
	end

	function barre:Replacer()
		local course = piste:GetHeight() or 0
		local maxi = maximum()
		if self.cacherSiInutile then
			G.Montrer(self, maxi > 0)
		end
		if maxi <= 0 or course <= 0 then
			curseur:Hide()
			monter:Disable()
			descendre:Disable()
		else
			local h = math.max(23, course * self.visible / self.total)
			if h > course then h = course end
			curseur:SetHeight(h)
			curseur:ClearAllPoints()
			curseur:SetPoint("TOP", piste, "TOP", 0, -(course - h) * self.position / maxi)
			curseur:Show()
			peindreCurseur(curseur.bas and "down" or (curseur.dessus and "over" or nil))
			if self.position > 0 then monter:Enable() else monter:Disable() end
			if self.position < maxi then descendre:Enable() else descendre:Disable() end
		end
		monter.peindre()
		descendre.peindre()
	end

	function barre:Deplacer(vers)
		vers = math.max(0, math.min(vers, maximum()))
		if vers == self.position then return end
		self.position = vers
		self:Replacer()
		if self.surDefilement then self.surDefilement(vers) end
	end

	function barre:Regler(total, visible, position)
		self.total, self.visible = total, visible
		self.position = math.max(0, math.min(position or 0, maximum()))
		self:Replacer()
	end

	-- glisser le curseur (3.3.5 n'a pas de suivi de la souris : une horloge)
	local function sourisY()
		local _, y = GetCursorPosition()
		return y / (piste:GetEffectiveScale() or 1)
	end
	curseur:SetScript("OnEnter", function(self) self.dessus = true; barre:Replacer() end)
	curseur:SetScript("OnLeave", function(self) self.dessus = false; barre:Replacer() end)
	curseur:SetScript("OnMouseDown", function(self)
		self.bas = true
		self.prise, self.priseP = sourisY(), barre.position
		self:SetScript("OnUpdate", function(soi)
			local course = (piste:GetHeight() or 0) - (soi:GetHeight() or 0)
			if course > 0 then
				barre:Deplacer(soi.priseP + (soi.prise - sourisY()) / course * maximum())
			end
		end)
		barre:Replacer()
	end)
	curseur:SetScript("OnMouseUp", function(self)
		self.bas = false
		self:SetScript("OnUpdate", nil)
		barre:Replacer()
	end)
	-- cliquer la glissiere avance d'une page vers le clic
	piste:SetScript("OnMouseDown", function()
		local y = sourisY()
		if curseur:IsShown() then
			if y > (curseur:GetTop() or 0) then
				barre:Deplacer(barre.position - barre.visible)
			elseif y < (curseur:GetBottom() or 0) then
				barre:Deplacer(barre.position + barre.visible)
			end
		end
	end)
	G.Accrocher(barre, "OnSizeChanged", function() barre:Replacer() end)
	return barre
end

-- ------------------------------------------------------------ le bouton de panneau

-- 3.3.5 rend 1 / nil, parfois 0 / 1 : zero est vrai en Lua
local function vrai(v)
	return v and v ~= 0 and true or false
end

-- UIPanelButtonTemplate : trois morceaux de UI-Panel-Button-Up (12 / reste /
-- 12), -Down enfonce, -Disabled grise ; lueur UI-Panel-Button-Highlight en
-- ADD ; texte au centre
local PANNEAU = "Interface\\Buttons\\UI-Panel-Button-"
function G.BoutonPanneau(b)
	G.EffacerArtClient(b)
	local g = b:CreateTexture(nil, "BACKGROUND")
	g:SetWidth(12)
	g:SetPoint("TOPLEFT", b, "TOPLEFT")
	g:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT")
	local d = b:CreateTexture(nil, "BACKGROUND")
	d:SetWidth(12)
	d:SetPoint("TOPRIGHT", b, "TOPRIGHT")
	d:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT")
	local m = b:CreateTexture(nil, "BACKGROUND")
	m:SetPoint("TOPLEFT", g, "TOPRIGHT")
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	local morceaux = { { g, 0, 0.09375 }, { m, 0.09375, 0.53125 }, { d, 0.53125, 0.625 } }
	local function fichier(nom)
		for _, v in ipairs(morceaux) do
			v[1]:SetTexture(PANNEAU .. nom)
			v[1]:SetTexCoord(v[2], v[3], 0, 0.6875)
		end
	end
	local function repos()
		fichier(vrai(b:IsEnabled()) and "Up" or "Disabled")
	end
	repos()
	G.Accrocher(b, "OnMouseDown", function()
		if vrai(b:IsEnabled()) then fichier("Down") end
	end)
	G.Accrocher(b, "OnMouseUp", repos)
	G.Accrocher(b, "OnShow", repos)
	G.Accrocher(b, "OnDisable", repos)
	G.Accrocher(b, "OnEnable", repos)
	b:SetHighlightTexture(PANNEAU .. "Highlight")
	local h = b:GetHighlightTexture()
	h:SetTexCoord(0, 0.625, 0, 0.6875)
	h:SetBlendMode("ADD")
	h:ClearAllPoints()
	h:SetAllPoints(b)
	b:SetNormalFontObject(G.Police("GameFontNormal"))
	b:SetHighlightFontObject(G.Police("GameFontHighlight"))
	b:SetDisabledFontObject(G.Police("GameFontDisable"))
	local texte = b:GetFontString()
	if texte then
		texte:ClearAllPoints()
		texte:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
end
