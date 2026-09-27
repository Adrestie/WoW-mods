-- ForeverUI : le socle commun des ecrans d'accueil repris de camelot.
--
-- Un ecran repris de camelot se pose ici avec LES NOMBRES DU CODE DE CAMELOT,
-- recopies tels quels : aucune taille, aucune position n'est corrigee a la
-- main. Ce qui rend cela possible tient en trois points, poses une fois :
--
--   1. L'ECHELLE. Les ecrans d'accueil de 3.3.5 font 768 unites de haut ;
--      ceux de camelot, 1200 (mesure du 2026-09-27 sur des captures des deux
--      clients en 3840 x 1600 : 1,333 px par unite -- 129 px entre deux
--      races pour 97 unites, 250 px entre les colonnes de faction pour 188).
--      GlueParent prend l'echelle 768 / 1200 : tout ce qu'il contient compte
--      alors en unites de camelot.
--   2. LA ZONE UTILE. GlueParent_OnLoad (3.3.5) la borne au 16:9 ; celle de
--      camelot mesure 2:1 (de x = 318 a 3517 px sur l'ecran de 3840 : le
--      numero de version a 10 unites du bord gauche, Quit a 24 du bord
--      droit). Elle est recadree en 2:1.
--   3. LES POLICES. 3.3.5 ignore la taille d'une police declaree par
--      heritage (<Font inherits> + <FontHeight>) : ForeverUIGlueFonts.xml
--      (tools/polices_accueil.py) porte les polices de camelot aplaties, et
--      G.Police les rend par leur nom de camelot.
--
-- Puis les gabarits de camelot, reproduits une seule fois : l'atlas avec sa
-- taille officielle (UiTextureAtlasMember, tools/atlas_accueil.py), la
-- decoupe en neuf par disposition nommee (NineSliceUtil.ApplyLayout), le
-- bouton rouge a trois morceaux (ThreeSliceButtonMixin), le cadre et
-- l'en-tete de dialogue (DialogBorderTemplate, DialogHeaderTemplate).

ForeverUIGlue = ForeverUIGlue or {}
local G = ForeverUIGlue

-- ------------------------------------------------------------ 1. l'echelle

-- les variables de 3.3.5 ne sont pas toutes enregistrees dans les ecrans
-- d'accueil : GetCVar leve alors une erreur ; la lecture est protegee
local function cvar(nom)
	if not GetCVar then
		return nil
	end
	local ok, valeur = pcall(GetCVar, nom)
	if ok then
		return valeur
	end
	return nil
end

local function hauteurEcran()
	local resolution = cvar("gxResolution")
	local hauteur = resolution and tonumber(string.match(resolution, "%d+x(%d+)"))
	return hauteur or 1080
end

-- hauteur des ecrans d'accueil de camelot, en unites : celle de l'ecran,
-- plafonnee a 1200 (mesuree a 1200 sur l'ecran de 1600 ; seule cette
-- hauteur est mesuree)
G.HAUTEUR_CAMELOT = math.min(math.max(hauteurEcran(), 768), 1200)
G.ECHELLE = 768 / G.HAUTEUR_CAMELOT
G.RAPPORT_MAX = 2

GlueParent:SetScale(G.ECHELLE)

-- ------------------------------------------------------------ 2. la zone utile

function G.Cadrer()
	local largeur = GetScreenWidth() / G.ECHELLE
	local hauteur = GetScreenHeight() / G.ECHELLE
	local bande = 0
	if largeur / hauteur > G.RAPPORT_MAX then
		bande = (largeur - hauteur * G.RAPPORT_MAX) / 2
	end
	-- la largeur de chaque bande hors de la zone, en unites de camelot
	G.BANDE = bande
	GlueParent:ClearAllPoints()
	GlueParent:SetPoint("TOPLEFT", bande, 0)
	GlueParent:SetPoint("BOTTOMRIGHT", -bande, 0)
end
G.Cadrer()

-- ------------------------------------------------------------ 3. les polices

function G.Police(nom)
	local police = _G["ForeverUIGlue_" .. nom]
	if not police then
		error("police de camelot absente : " .. tostring(nom))
	end
	return police
end

-- ------------------------------------------------------------ les accroches

-- ajoute un traitement a un script sans remplacer celui du client
function G.Accrocher(cadre, script, fonction)
	if cadre.HookScript then
		cadre:HookScript(script, fonction)
		return
	end
	local avant = cadre:GetScript(script)
	cadre:SetScript(script, function(...)
		if avant then
			avant(...)
		end
		fonction(...)
	end)
end

function G.Montrer(region, oui)
	if oui then region:Show() else region:Hide() end
end

-- ------------------------------------------------------------ l'atlas

-- pose un element d'atlas ; tailleAtlas : prend sa taille officielle
-- (SetAtlas(nom, true) de camelot). Rend l'entree.
function G.PoserAtlas(texture, nom, tailleAtlas)
	local e = G.atlas[string.lower(nom)]
	if not e then
		error("element d'atlas absent de la table d'accueil : " .. tostring(nom))
	end
	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[3], e[4], e[5])
	if tailleAtlas then
		texture:SetWidth(e[6])
		texture:SetHeight(e[7])
	end
	return e
end

-- une mosaique n'est possible, en 3.3.5, que sur une image entiere : un
-- element qui occupe toute sa feuille se repete, les autres s'etirent
local function mosaique(texture, e)
	local entiere = e[2] == 0 and e[3] == 1 and e[4] == 0 and e[5] == 1
	if entiere and (e[8] or e[9]) and texture.SetHorizTile then
		texture:SetTexture(e[1], true)
		texture:SetHorizTile(e[8] and true or false)
		texture:SetVertTile(e[9] and true or false)
	end
end

-- ------------------------------------------------------------ la decoupe en neuf

-- RELEVE -- blizzard_sharedxml/mainline/nineslicelayouts.lua (dispositions,
-- recopiees telles quelles) et nineslice.lua (ApplyLayout).
G.DISPOSITIONS = {
	TooltipMixedLayout = {
		TopRightCorner = { atlas = "Tooltip-Glues-NineSlice-CornerTopRight" },
		TopLeftCorner = { atlas = "Tooltip-Glues-NineSlice-CornerTopLeft" },
		BottomLeftCorner = { atlas = "Tooltip-Glues-NineSlice-CornerBottomLeft" },
		BottomRightCorner = { atlas = "Tooltip-Glues-NineSlice-CornerBottomRight" },
		TopEdge = { atlas = "_Tooltip-Glues-NineSlice-EdgeTop" },
		BottomEdge = { atlas = "_Tooltip-Glues-NineSlice-EdgeBottom" },
		LeftEdge = { atlas = "!Tooltip-Glues-NineSlice-EdgeLeft" },
		RightEdge = { atlas = "!Tooltip-Glues-NineSlice-EdgeRight" },
		Center = { layer = "BACKGROUND", atlas = "Tooltip-NineSlice-Center", x = -8, y = 10, x1 = 8, y1 = -7 },
	},
	TooltipDefaultLayout = {
		TopRightCorner = { atlas = "Tooltip-NineSlice-CornerTopRight" },
		TopLeftCorner = { atlas = "Tooltip-NineSlice-CornerTopLeft" },
		BottomLeftCorner = { atlas = "Tooltip-NineSlice-CornerBottomLeft" },
		BottomRightCorner = { atlas = "Tooltip-NineSlice-CornerBottomRight" },
		TopEdge = { atlas = "_Tooltip-NineSlice-EdgeTop" },
		BottomEdge = { atlas = "_Tooltip-NineSlice-EdgeBottom" },
		LeftEdge = { atlas = "!Tooltip-NineSlice-EdgeLeft" },
		RightEdge = { atlas = "!Tooltip-NineSlice-EdgeRight" },
		Center = { layer = "BACKGROUND", atlas = "Tooltip-NineSlice-Center", x = -4, y = 4, x1 = 4, y1 = -4 },
	},
	Dialog = {
		TopLeftCorner = { atlas = "UI-Frame-DiamondMetal-CornerTopLeft" },
		TopRightCorner = { atlas = "UI-Frame-DiamondMetal-CornerTopRight" },
		BottomLeftCorner = { atlas = "UI-Frame-DiamondMetal-CornerBottomLeft" },
		BottomRightCorner = { atlas = "UI-Frame-DiamondMetal-CornerBottomRight" },
		TopEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeTop" },
		BottomEdge = { atlas = "_UI-Frame-DiamondMetal-EdgeBottom" },
		LeftEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeLeft" },
		RightEdge = { atlas = "!UI-Frame-DiamondMetal-EdgeRight" },
	},
}

-- l'ordre et les ancrages de nineSliceSetup (nineslice.lua)
local MORCEAUX = {
	{ "TopLeftCorner", "TOPLEFT" },
	{ "TopRightCorner", "TOPRIGHT" },
	{ "BottomLeftCorner", "BOTTOMLEFT" },
	{ "BottomRightCorner", "BOTTOMRIGHT" },
	{ "TopEdge", "TOPLEFT", "TOPRIGHT", "TopLeftCorner", "TopRightCorner" },
	{ "BottomEdge", "BOTTOMLEFT", "BOTTOMRIGHT", "BottomLeftCorner", "BottomRightCorner" },
	{ "LeftEdge", "TOPLEFT", "BOTTOMLEFT", "TopLeftCorner", "BottomLeftCorner" },
	{ "RightEdge", "TOPRIGHT", "BOTTOMRIGHT", "TopRightCorner", "BottomRightCorner" },
	{ "Center" },
}

-- pose une disposition sur un cadre, en regions de ce cadre (en 3.3.5 un
-- cadre fils couvrirait les textes du cadre). Rend les morceaux par nom.
function G.NeufTranches(hote, nomDisposition)
	local disposition = G.DISPOSITIONS[nomDisposition]
	local p = {}
	for _, m in ipairs(MORCEAUX) do
		local nom = m[1]
		local l = disposition[nom]
		if l then
			local t = hote:CreateTexture(nil, l.layer or "BORDER")
			p[nom] = t
			if nom == "Center" then
				local e = G.PoserAtlas(t, l.atlas, true)
				t:SetPoint("TOPLEFT", p.TopLeftCorner, "BOTTOMRIGHT", l.x or 0, l.y or 0)
				t:SetPoint("BOTTOMRIGHT", p.BottomRightCorner, "TOPLEFT", l.x1 or 0, l.y1 or 0)
				mosaique(t, e)
			elseif m[3] then
				local e = G.PoserAtlas(t, l.atlas, true)
				t:SetPoint(m[2], p[m[4]], m[3], l.x or 0, l.y or 0)
				t:SetPoint(m[3], p[m[5]], m[2], l.x1 or 0, l.y1 or 0)
				mosaique(t, e)
			else
				G.PoserAtlas(t, l.atlas, true)
				t:SetPoint(l.point or m[2], hote, l.relativePoint or l.point or m[2], l.x or 0, l.y or 0)
			end
		end
	end
	return p
end

-- SetCenterColor / SetBorderColor du NineSlicePanel
function G.CouleursNeufTranches(p, centre, bord)
	for nom, t in pairs(p) do
		local c = (nom == "Center") and centre or bord
		if c then
			t:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
		end
	end
end

-- TooltipBackdropTemplate : disposition, puis couleur du fond (backdropColor,
-- a defaut TOOLTIP_DEFAULT_BACKGROUND_COLOR) et du bord
G.GLUE_BACKDROP_COLOR = { 0.09, 0.09, 0.09 }
G.GLUE_BACKDROP_BORDER_COLOR = { 0.8, 0.8, 0.8 }

function G.FondInfobulle(hote, nomDisposition, fond, bord)
	local p = G.NeufTranches(hote, nomDisposition)
	G.CouleursNeufTranches(p, fond, bord)
	return p
end

-- ------------------------------------------------------------ le bouton rouge

-- RELEVE -- blizzard_sharedxml/shared/button/threeslicebuttontemplate.xml et
-- .lua : Left et Right a leur taille d'atlas mise a l'echelle de la hauteur
-- du bouton (hauteur / hauteur de Left) ; Center tendu entre eux ; si Left et
-- Right ne tiennent pas dans la largeur, on les rogne (UpdateScale) ; etats
-- -Pressed et -Disabled ; lueur atlasName-Highlight ; texte enfonce de
-- (-2, -1) (BigRedThreeSliceButtonTemplate).

local function rogner(t, e, gaucheVersDroite, part)
	-- ne garder qu'une part de la largeur de l'element
	local u1, u2 = e[2], e[3]
	if gaucheVersDroite then
		t:SetTexCoord(u1, u1 + (u2 - u1) * part, e[4], e[5])
	else
		t:SetTexCoord(u2 - (u2 - u1) * part, u2, e[4], e[5])
	end
end

local function peindreTroisTranches(b, etat)
	local r = b.foreverTrois
	if not b:IsEnabled() then
		etat = "DISABLED"
	end
	local suffixe = ""
	if etat == "DISABLED" then
		suffixe = "-Disabled"
	elseif etat == "PUSHED" then
		suffixe = "-Pressed"
	end
	local eg = G.PoserAtlas(r.gauche, r.atlas .. "-Left" .. suffixe)
	local ec = G.PoserAtlas(r.centre, "_" .. r.atlas .. "-Center" .. suffixe)
	local ed = G.PoserAtlas(r.droite, r.atlas .. "-Right" .. suffixe)

	-- UpdateScale
	local hauteur, largeur = b:GetHeight(), b:GetWidth()
	local echelle = hauteur / eg[7]
	local lg, ld = eg[6] * echelle, ed[6] * echelle
	if lg + ld > largeur then
		local surplus = lg + ld - largeur
		local ng, nd = lg, ld
		if (lg - surplus) > ld then
			ng = lg - surplus
		elseif (ld - surplus) > lg then
			nd = ld - surplus
		else
			if lg ~= ld then
				surplus = surplus - math.abs(lg - ld)
				ng = math.min(lg, ld)
				nd = ng
			end
			ng = ng - surplus / 2
			nd = nd - surplus / 2
		end
		rogner(r.gauche, eg, true, ng / lg)
		rogner(r.droite, ed, false, nd / ld)
		lg, ld = ng, nd
	end
	r.gauche:SetWidth(lg)
	r.gauche:SetHeight(hauteur)
	r.droite:SetWidth(ld)
	r.droite:SetHeight(hauteur)
	r.actif = b:IsEnabled() and true or false
end

-- efface l'art que le client 3.3.5 pose sur ses propres boutons
function G.EffacerArtClient(b)
	for _, lire in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
		local t = b[lire] and b[lire](b)
		if t then
			t:SetTexture(nil)
		end
	end
end

-- polices : { normale, survol, grisee } -- des noms de polices de camelot
function G.BoutonTroisTranches(b, atlas, polices)
	G.EffacerArtClient(b)
	local r = { atlas = atlas }
	r.gauche = b:CreateTexture(nil, "BACKGROUND")
	r.gauche:SetPoint("TOPLEFT", b, "TOPLEFT")
	r.droite = b:CreateTexture(nil, "BACKGROUND")
	r.droite:SetPoint("TOPRIGHT", b, "TOPRIGHT")
	r.centre = b:CreateTexture(nil, "BACKGROUND")
	r.centre:SetPoint("TOPLEFT", r.gauche, "TOPRIGHT")
	r.centre:SetPoint("BOTTOMRIGHT", r.droite, "BOTTOMLEFT")
	b.foreverTrois = r

	-- la lueur : SetHighlightAtlas, sur tout le bouton, en ADD
	local function lueur()
		b:SetHighlightTexture(G.atlas[string.lower(atlas .. "-Highlight")][1])
		local h = b:GetHighlightTexture()
		G.PoserAtlas(h, atlas .. "-Highlight")
		h:ClearAllPoints()
		h:SetAllPoints(b)
		h:SetBlendMode("ADD")
	end
	lueur()
	r.lueur = lueur

	if polices then
		b:SetNormalFontObject(G.Police(polices[1]))
		b:SetHighlightFontObject(G.Police(polices[2] or polices[1]))
		b:SetDisabledFontObject(G.Police(polices[3] or polices[1]))
	end
	local texte = b:GetFontString()
	if texte then
		texte:ClearAllPoints()
		texte:SetPoint("CENTER", b, "CENTER", 0, 0)
	end
	b:SetPushedTextOffset(-2, -1)

	G.Accrocher(b, "OnMouseDown", function(self)
		if self:IsEnabled() then
			peindreTroisTranches(self, "PUSHED")
		end
	end)
	G.Accrocher(b, "OnMouseUp", function(self) peindreTroisTranches(self, "NORMAL") end)
	G.Accrocher(b, "OnShow", function(self) peindreTroisTranches(self, "NORMAL") end)
	G.Accrocher(b, "OnSizeChanged", function(self) peindreTroisTranches(self, "NORMAL") end)
	-- 3.3.5 n'avertit pas d'un Enable / Disable : on relit l'etat ; et
	-- CharacterSelect_DeathKnightSwap repose l'art du client (fond ET lueur)
	-- sur certains de ses boutons : on l'efface et on repose la lueur
	G.Accrocher(b, "OnUpdate", function(self)
		local n = self:GetNormalTexture()
		if n and n:GetTexture() then
			G.EffacerArtClient(self)
			self.foreverTrois.lueur()
		end
		if (self:IsEnabled() and true or false) ~= self.foreverTrois.actif then
			peindreTroisTranches(self, "NORMAL")
		end
	end)
	peindreTroisTranches(b, "NORMAL")
	return b
end

function G.CreerBoutonTroisTranches(nom, parent, largeur, hauteur, atlas, polices, texte)
	local b = CreateFrame("Button", nom, parent)
	b:SetWidth(largeur)
	b:SetHeight(hauteur)
	b:SetText(texte or "")
	G.BoutonTroisTranches(b, atlas, polices)
	return b
end

-- ------------------------------------------------------------ le dialogue

-- DialogBorderTemplate : fond UI-DialogBox-Background en mosaique a 7 du
-- bord, disposition Dialog (DialogBorderNoCenterTemplate)
function G.CadreDialogue(hote)
	local fond = hote:CreateTexture(nil, "BACKGROUND")
	fond:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Background", true)
	if fond.SetHorizTile then
		fond:SetHorizTile(true)
		fond:SetVertTile(true)
	end
	fond:SetPoint("TOPLEFT", hote, "TOPLEFT", 7, -7)
	fond:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", -7, 7)
	return G.NeufTranches(hote, "Dialog"), fond
end

-- DialogHeaderTemplate : 200 x 39 a TOP (0, 11) ; coins 32 x 39, tuile entre
-- eux ; texte TOP (0, -13) ; largeur = texte + headerTextPadding (64)
function G.EnTeteDialogue(parent, texte, police)
	local f = CreateFrame("Frame", nil, parent)
	f:SetWidth(200)
	f:SetHeight(39)
	f:SetPoint("TOP", parent, "TOP", 0, 11)
	local g = f:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(g, "UI-Frame-DiamondMetal-Header-CornerLeft")
	g:SetWidth(32)
	g:SetHeight(39)
	g:SetPoint("LEFT", f, "LEFT")
	local d = f:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(d, "UI-Frame-DiamondMetal-Header-CornerRight")
	d:SetWidth(32)
	d:SetHeight(39)
	d:SetPoint("RIGHT", f, "RIGHT")
	local c = f:CreateTexture(nil, "ARTWORK")
	G.PoserAtlas(c, "_UI-Frame-DiamondMetal-Header-Tile")
	c:SetPoint("TOPLEFT", g, "TOPRIGHT")
	c:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
	local t = f:CreateFontString(nil, "ARTWORK")
	t:SetFontObject(G.Police(police or "GameFontNormal"))
	t:SetPoint("TOP", f, "TOP", 0, -13)
	t:SetText(texte)
	f.Text = t
	f:SetWidth(t:GetStringWidth() + 64)
	return f
end
