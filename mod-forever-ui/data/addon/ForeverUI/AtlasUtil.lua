-- ForeverUI : ce qu'on pose sur une feuille d'atlas.
--
-- Une feuille reste UNE texture : on ne decoupe rien en fichiers, on deplace
-- seulement le rectangle lu dedans. Un remplissage partiel (barre de vie a
-- 40 %) rogne ce rectangle au lieu d'etirer l'image, sinon l'art se deforme.

ForeverUI = ForeverUI or {}

local function entry(name)
	if not UIAtlas or not UIAtlas.data then
		return nil
	end
	return UIAtlas.data[name]
end

ForeverUI.AtlasEntry = entry

-- Regle une texture sur un element d'atlas. keepSize laisse la taille en place
-- (utile quand le cadre impose ses propres dimensions).
function ForeverUI.SetAtlas(texture, name, keepSize)
	local e = entry(name)
	if not e then
		return false
	end

	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[3], e[4], e[5])

	if not keepSize then
		texture:SetWidth(e[6])
		texture:SetHeight(e[7])
	end

	return true
end

-- Cree une texture deja reglee sur un element, a sa taille d'origine.
function ForeverUI.CreateAtlasTexture(parent, layer, name)
	local texture = parent:CreateTexture(nil, layer)
	if not ForeverUI.SetAtlas(texture, name) then
		texture:Hide()
	end
	return texture
end

-- Remplissage de gauche a droite : le rectangle est rogne a la fraction voulue.
-- Une largeur nulle est interdite par le client, donc la texture est masquee.
function ForeverUI.SetAtlasFill(texture, name, fraction, fullWidth)
	local e = entry(name)
	if not e then
		texture:Hide()
		return false
	end

	if not fraction or fraction ~= fraction or fraction < 0 then
		fraction = 0
	elseif fraction > 1 then
		fraction = 1
	end

	local width = (fullWidth or e[6]) * fraction
	if width < 1 then
		texture:Hide()
		return true
	end

	texture:SetTexture(e[1])
	texture:SetTexCoord(e[2], e[2] + (e[3] - e[2]) * fraction, e[4], e[5])
	texture:SetWidth(width)
	texture:SetHeight(e[7])
	texture:Show()
	return true
end

-- DECOUPE EN NEUF.
--
-- RELEVE -- mainline/MainActionBar.xml, camelot/MainMenuBarBagButtons.xml et
-- camelot/MainMenuBarMicroMenu.xml posent tous les trois la MEME image pour
-- encadrer leur groupe :
--     <Texture parentKey="BorderArt" atlas="UI-HUD-ActionBar-Frame">
--       <Anchor point="TOPLEFT" x="-6" y="6"/>
--       <Anchor point="BOTTOMRIGHT" x="4" y="-5"/>
-- Cette image fait 55 x 55 (110 x 110 sur une feuille 2x) : c'est un octogone
-- a bord de bronze sur fond noir. Le client moderne l'etire en neuf tranches ;
-- etiree d'une seule piece sur 560 px, ses biseaux deviendraient des rampes.
-- On la coupe donc ici, ce qui donne le meme resultat a l'ecran.
--
-- options.nom         nom de l'element d'atlas
-- options.couche      couche de dessin (BACKGROUND par defaut)
-- options.margeImage  epaisseur du coin dans l'image, en pixels
-- options.tailleImage cote de l'image, en pixels
-- options.marge       epaisseur du coin a l'ecran, en pixels
function ForeverUI.SetAtlasNineSlice(parent, options)
	local e = entry(options.nom)
	if not e then
		return nil
	end

	local couche = options.couche or "BACKGROUND"
	local marge = options.marge
	local fraction = options.margeImage / options.tailleImage
	local du = (e[3] - e[2]) * fraction
	local dv = (e[5] - e[4]) * fraction
	local u = { e[2], e[2] + du, e[3] - du, e[3] }
	local v = { e[4], e[4] + dv, e[5] - dv, e[5] }

	local function piece(cu1, cu2, cv1, cv2)
		local t = parent:CreateTexture(nil, couche)
		t:SetTexture(e[1])
		t:SetTexCoord(u[cu1], u[cu2], v[cv1], v[cv2])
		return t
	end

	local p = {}

	p.coinHautGauche = piece(1, 2, 1, 2)
	p.coinHautGauche:SetWidth(marge)
	p.coinHautGauche:SetHeight(marge)
	p.coinHautGauche:SetPoint("TOPLEFT", parent, "TOPLEFT")

	p.coinHautDroit = piece(3, 4, 1, 2)
	p.coinHautDroit:SetWidth(marge)
	p.coinHautDroit:SetHeight(marge)
	p.coinHautDroit:SetPoint("TOPRIGHT", parent, "TOPRIGHT")

	p.coinBasGauche = piece(1, 2, 3, 4)
	p.coinBasGauche:SetWidth(marge)
	p.coinBasGauche:SetHeight(marge)
	p.coinBasGauche:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT")

	p.coinBasDroit = piece(3, 4, 3, 4)
	p.coinBasDroit:SetWidth(marge)
	p.coinBasDroit:SetHeight(marge)
	p.coinBasDroit:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT")

	-- Les bords et le centre sont definis par deux coins opposes : deux points
	-- suffisent a fixer un rectangle, aucune taille a calculer.
	p.bordHaut = piece(2, 3, 1, 2)
	p.bordHaut:SetPoint("TOPLEFT", p.coinHautGauche, "TOPRIGHT")
	p.bordHaut:SetPoint("BOTTOMRIGHT", p.coinHautDroit, "BOTTOMLEFT")

	p.bordBas = piece(2, 3, 3, 4)
	p.bordBas:SetPoint("TOPLEFT", p.coinBasGauche, "TOPRIGHT")
	p.bordBas:SetPoint("BOTTOMRIGHT", p.coinBasDroit, "BOTTOMLEFT")

	p.bordGauche = piece(1, 2, 2, 3)
	p.bordGauche:SetPoint("TOPLEFT", p.coinHautGauche, "BOTTOMLEFT")
	p.bordGauche:SetPoint("BOTTOMRIGHT", p.coinBasGauche, "TOPRIGHT")

	p.bordDroit = piece(3, 4, 2, 3)
	p.bordDroit:SetPoint("TOPLEFT", p.coinHautDroit, "BOTTOMLEFT")
	p.bordDroit:SetPoint("BOTTOMRIGHT", p.coinBasDroit, "TOPRIGHT")

	p.centre = piece(2, 3, 2, 3)
	p.centre:SetPoint("TOPLEFT", p.coinHautGauche, "BOTTOMRIGHT")
	p.centre:SetPoint("BOTTOMRIGHT", p.coinBasDroit, "TOPLEFT")

	return p
end

-- L'encadrement commun aux trois groupes du bas de l'ecran.
--
-- MESURE SUR L'IMAGE. Le coin doit contenir TOUT le biseau, pas seulement son
-- arete exterieure. Le profil du bord haut de l'image ne devient constant qu'a
-- partir de la colonne 19 sur 110, et celui du bord gauche a partir de la
-- ligne 19 : en dessous, on coupe dans la diagonale, et le morceau de
-- diagonale restant part s'etirer sur toute la longueur de la barre -- c'est
-- ce qui deformait les coins. On prend donc 20, avec un pixel de marge, soit
-- 10 px a l'ecran puisque la feuille est en double densite.
function ForeverUI.SetBarFrameArt(frame, couche)
	return ForeverUI.SetAtlasNineSlice(frame, {
		nom = "ui-hud-actionbar-frame",
		couche = couche or "BACKGROUND",
		margeImage = 20,
		tailleImage = 110,
		marge = 10,
	})
end

-- SEPARATEUR ENTRE DEUX EMPLACEMENTS.
--
-- RELEVE -- mainline/MainActionBar.xml : HorizontalDividerTemplate fait 12 de
-- large et se monte en TROIS tranches verticales sur le jeu d'images
-- ui-hud-actionbar-frame-divider. Les hauteurs tombent juste sur un bouton de
-- 45 : 14 en haut, 16 au centre, 15 en bas.
function ForeverUI.CreateDivider(parent, niveau)
	local cadre = CreateFrame("Frame", nil, parent)
	cadre:SetWidth(12)
	cadre:SetFrameLevel(niveau or parent:GetFrameLevel())

	local haut = cadre:CreateTexture(nil, "ARTWORK")
	if not ForeverUI.SetAtlas(haut, "ui-hud-actionbar-frame-divider-threeslice-edgetop", true) then
		cadre:Hide()
		return cadre
	end
	haut:SetHeight(14)
	haut:SetPoint("TOPLEFT", cadre, "TOPLEFT")
	haut:SetPoint("TOPRIGHT", cadre, "TOPRIGHT")

	local bas = cadre:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(bas, "ui-hud-actionbar-frame-divider-threeslice-edgebottom", true)
	bas:SetHeight(15)
	bas:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT")
	bas:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT")

	local centre = cadre:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(centre, "!ui-hud-actionbar-frame-divider-threeslice-center", true)
	centre:SetPoint("TOPLEFT", haut, "BOTTOMLEFT")
	centre:SetPoint("BOTTOMRIGHT", bas, "TOPRIGHT")

	cadre.haut, cadre.centre, cadre.bas = haut, centre, bas
	return cadre
end

-- LE PANNEAU.
--
-- RELEVE -- mainline/SharedUIPanelTemplates.xml : un panneau du client moderne
-- (PortraitFrameFlatTemplate) est fait de deux couches.
--   1. le fond plat (FlatPanelBackgroundTemplate), pose entre TOPLEFT (2, -20)
--      et BOTTOMRIGHT (-2, 3) : deux coins arrondis de 16 x 16 en bas
--      (uiframebackground-nineslice-cornerbottom*), un bord entre eux, et tout
--      le reste en aplat, le tout teinte par PANEL_BACKGROUND_COLOR ;
--   2. l'encadrement de metal en neuf tranches, jeu HeldBagLayout de
--      mainline/NineSliceLayouts.lua, avec les corrections de
--      camelot/NineSliceLayoutOverrides.lua (coin haut droit x -2, coins bas
--      y = -8).
--
-- PANEL_BACKGROUND_COLOR est une couleur du client, absente du code extrait :
-- elle est MESUREE dans l'art, au point ou le fond deborde sous le coin de
-- metal (0, 0, 0, 168/255).
--
-- Les bords sont ETIRES et non paves : une texture d'atlas en pavage etale la
-- feuille entiere.
local PANNEAU_FOND = { 0, 0, 0, 168 / 255 }

local PANNEAU_COINS = {
	{ cle = "coinHautGauche", nom = "ui-frame-portraitmetal-cornertopleftsmall",
	  point = "TOPLEFT", x = -13, y = 16 },
	{ cle = "coinHautDroit", nom = "ui-frame-metal-cornertopright",
	  point = "TOPRIGHT", x = 2, y = 16 },
	{ cle = "coinBasGauche", nom = "ui-frame-metal-cornerbottomleft",
	  point = "BOTTOMLEFT", x = -13, y = -8 },
	{ cle = "coinBasDroit", nom = "ui-frame-metal-cornerbottomright",
	  point = "BOTTOMRIGHT", x = 2, y = -8 },
}

function ForeverUI.SetPanelArt(frame)
	if frame.foreverPanel then
		return frame.foreverPanel
	end

	local p = {}

	-- 1. le fond plat
	local r, v, b, a = PANNEAU_FOND[1], PANNEAU_FOND[2], PANNEAU_FOND[3], PANNEAU_FOND[4]

	local basGauche = frame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(basGauche, "uiframebackground-nineslice-cornerbottomleft")
	basGauche:SetVertexColor(r, v, b, a)
	basGauche:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 2, 3)

	local basDroit = frame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(basDroit, "uiframebackground-nineslice-cornerbottomright")
	basDroit:SetVertexColor(r, v, b, a)
	basDroit:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 3)

	local bordBas = frame:CreateTexture(nil, "BACKGROUND")
	bordBas:SetTexture(r, v, b, a)
	bordBas:SetPoint("TOPLEFT", basGauche, "TOPRIGHT")
	bordBas:SetPoint("BOTTOMRIGHT", basDroit, "BOTTOMLEFT")

	local corps = frame:CreateTexture(nil, "BACKGROUND")
	corps:SetTexture(r, v, b, a)
	corps:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -20)
	corps:SetPoint("BOTTOMRIGHT", basDroit, "TOPRIGHT")

	p.fond = { basGauche, basDroit, bordBas, corps }

	-- 2. l'encadrement de metal
	for _, coin in ipairs(PANNEAU_COINS) do
		local texture = frame:CreateTexture(nil, "OVERLAY")
		if ForeverUI.SetAtlas(texture, coin.nom) then
			texture:SetPoint(coin.point, frame, coin.point, coin.x, coin.y)
			p[coin.cle] = texture
		else
			texture:Hide()
		end
	end

	local function bord(nom, point1, cible1, relatif1, point2, cible2, relatif2)
		local texture = frame:CreateTexture(nil, "OVERLAY")
		if not ForeverUI.SetAtlas(texture, nom) then
			texture:Hide()
			return nil
		end
		texture:SetPoint(point1, cible1, relatif1)
		texture:SetPoint(point2, cible2, relatif2)
		return texture
	end

	if p.coinHautGauche and p.coinHautDroit then
		p.bordHaut = bord("_ui-frame-metal-edgetop",
			"TOPLEFT", p.coinHautGauche, "TOPRIGHT",
			"TOPRIGHT", p.coinHautDroit, "TOPLEFT")
		p.bordGauche = bord("!ui-frame-metal-edgeleft",
			"TOPLEFT", p.coinHautGauche, "BOTTOMLEFT",
			"BOTTOMLEFT", p.coinBasGauche, "TOPLEFT")
		p.bordDroit = bord("!ui-frame-metal-edgeright",
			"TOPRIGHT", p.coinHautDroit, "BOTTOMRIGHT",
			"BOTTOMRIGHT", p.coinBasDroit, "TOPRIGHT")
		p.bordBas = bord("_ui-frame-metal-edgebottom",
			"BOTTOMLEFT", p.coinBasGauche, "BOTTOMRIGHT",
			"BOTTOMRIGHT", p.coinBasDroit, "BOTTOMLEFT")
	end

	frame.foreverPanel = p
	return p
end
