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
-- PANEL_BACKGROUND_COLOR est une couleur du client, absente du code extrait.
-- Elle est MESUREE sur la capture du vrai client (docs/reference) : le fond
-- d'un panneau y vaut (16, 14, 12) et il est OPAQUE -- le decor ne passe pas
-- au travers. Un fond translucide fait virer au bleu les ecarts entre les
-- cases d'un sac, ce qui a ete le premier ecart visible.
--
-- Les bords sont ETIRES et non paves : une texture d'atlas en pavage etale la
-- feuille entiere.
local PANNEAU_FOND = { 16 / 255, 14 / 255, 12 / 255, 1 }

-- RELEVE -- HeldBagLayout (blizzard_sharedxml/mainline/nineslicelayouts.lua) :
-- les huit morceaux sont declares en OVERLAY, et chaque coin porte son
-- decalage. Tout est recopie ici tel quel.
--
-- Ce que cela impose : en OVERLAY, le metal couvre toute region du cadre
-- lui-meme. La source s'en accommode parce qu'elle range le titre et le
-- portrait dans des CADRES FILS (TitleContainer a frameLevel 510,
-- PortraitContainer) -- un cadre fils se dessine au-dessus des regions de
-- son parent, quel que soit leur calque. Les appelants doivent donc en
-- faire autant pour tout ce qui doit rester visible.
local PANNEAU_COUCHE = "OVERLAY"

local PANNEAU_COINS = {
	{ cle = "coinHautGauche", nom = "ui-frame-portraitmetal-cornertopleftsmall",
	  point = "TOPLEFT", x = -13, y = 16 },
	{ cle = "coinHautDroit", nom = "ui-frame-metal-cornertopright",
	  point = "TOPRIGHT", x = 4, y = 16 },
	{ cle = "coinBasGauche", nom = "ui-frame-metal-cornerbottomleft",
	  point = "BOTTOMLEFT", x = -13, y = -3 },
	{ cle = "coinBasDroit", nom = "ui-frame-metal-cornerbottomright",
	  point = "BOTTOMRIGHT", x = 4, y = -3 },
}

-- OPTIONS.
--   coinHautGauche : l'atlas du coin haut gauche. Les deux mises en page
--     de la source ne different que par lui -- HeldBagLayout prend
--     ...CornerTopLeftSmall, PortraitFrameTemplate prend ...CornerTopLeft,
--     un anneau plus large pour un portrait de 62.
--   coins : { cle = { x = , y = } } -- remplace le decalage d'un coin. La
--     source elle-meme s'en sert : camelot/NineSliceLayoutOverrides.lua
--     repasse sur TOUTES les mises en page apres les avoir definies, parce
--     que son art ne fait pas la meme taille que celui du jeu moderne.
--   niveau : quand il est donne, LE METAL se pose dans un CADRE FILS de ce
--     niveau au-dessus du cadre. La source fait de meme -- son NineSlice
--     est un cadre fils -- et il le faut des que le cadre porte d'autres
--     cadres fils : ceux-ci se dessinent au-dessus de toute region de leur
--     parent, et recouvriraient le metal.
--
--     LE FOND, LUI, RESTE SUR LE CADRE. Il doit passer DERRIERE tout le
--     reste : monte avec le metal, il recouvrait les volets de la feuille
--     du personnage. Une region du cadre est sous tous ses cadres fils,
--     c'est exactement la place qu'il lui faut.
function ForeverUI.SetPanelArt(frame, options)
	if frame.foreverPanel then
		return frame.foreverPanel
	end

	options = options or {}
	-- hote : ou va le METAL. Le fond reste sur le cadre, au dernier plan.
	local hote = frame
	if options.niveau then
		hote = CreateFrame("Frame", nil, frame)
		hote:SetAllPoints(frame)
		hote:SetFrameLevel(frame:GetFrameLevel() + options.niveau)
		frame.foreverHabillage = hote
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
		local texture = hote:CreateTexture(nil, PANNEAU_COUCHE)
		local nomAtlas = coin.nom
		if coin.cle == "coinHautGauche" and options.coinHautGauche then
			nomAtlas = options.coinHautGauche
		end
		if ForeverUI.SetAtlas(texture, nomAtlas) then
			local x, y = coin.x, coin.y
			local reglage = options.coins and options.coins[coin.cle]
			if reglage then
				x = reglage.x or x
				y = reglage.y or y
			end
			texture:SetPoint(coin.point, hote, coin.point, x, y)
			p[coin.cle] = texture
			p[coin.cle .. "Atlas"] = nomAtlas
		else
			texture:Hide()
		end
	end

	local function bord(nom, point1, cible1, relatif1, point2, cible2, relatif2)
		local texture = hote:CreateTexture(nil, PANNEAU_COUCHE)
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
	ForeverUI.UpdatePanelCorners(frame)
	return p
end

-- RELEVE -- NineSliceUtil.UpdateCornerCropping et ClipNineSliceBottomCorner
-- (blizzard_sharedxml/nineslice.lua).
--
--   debord = hauteurCoinHaut + hauteurCoinBas - hauteurCadre
--            - decalageHaut - (-decalageBas)
--
-- Quand une fenetre est plus courte que ses deux coins empiles, le coin du
-- BAS est rogne PAR LE HAUT de cet excedent : ses coordonnees de texture
-- remontent d'autant et sa hauteur diminue. Sans cela les deux coins se
-- chevauchent et le bord gauche, tendu entre eux, se retrouve dessine a
-- l'envers en travers du cadre -- ce qui barrait l'anneau du trousseau.
function ForeverUI.UpdatePanelCorners(frame)
	local p = frame.foreverPanel
	if not p then
		return
	end

	local hautGauche, basGauche
	for _, coin in ipairs(PANNEAU_COINS) do
		if coin.cle == "coinHautGauche" then hautGauche = coin end
		if coin.cle == "coinBasGauche" then basGauche = coin end
	end

	local eHaut = ForeverUI.AtlasEntry(p.coinHautGaucheAtlas or hautGauche.nom)
	local eBas = ForeverUI.AtlasEntry(basGauche.nom)
	if not (eHaut and eBas) then
		return
	end

	local debord = eHaut[7] + eBas[7] - frame:GetHeight() - hautGauche.y - (-basGauche.y)

	for _, coin in ipairs(PANNEAU_COINS) do
		if coin.point == "BOTTOMLEFT" or coin.point == "BOTTOMRIGHT" then
			local texture = p[coin.cle]
			local e = ForeverUI.AtlasEntry(coin.nom)
			if texture and e then
				local rogne = math.max(0, math.min(debord, e[7]))
				local hauteurUV = e[5] - e[4]
				texture:SetTexCoord(e[2], e[3], e[4] + (rogne / e[7]) * hauteurUV, e[5])
				texture:SetWidth(e[6])
				texture:SetHeight(e[7] - rogne)
			end
		end
	end
end


-- UN SEPARATEUR VERTICAL EN TROIS TRANCHES. common-framedivider fait 11 x 50
-- et porte un EMBOUT a chaque extremite : l'etirer sur la hauteur d'un volet
-- les etale sur des dizaines de pixels. On decoupe donc l'element en trois
-- bandes par ses coordonnees de texture -- embout haut, milieu tire, embout
-- bas -- comme le ferait un neuf-tranches.
function ForeverUI.CreateVerticalDivider(parent, atlas, embout, niveau)
	local e = ForeverUI.AtlasEntry(atlas)
	local cadre = CreateFrame("Frame", nil, parent)
	if not e then
		cadre:Hide()
		return cadre
	end

	embout = embout or 4
	cadre:SetWidth(e[6])
	cadre:SetFrameLevel(niveau or parent:GetFrameLevel())

	local u1, u2, v1, v2, hauteur = e[2], e[3], e[4], e[5], e[7]
	local partV = (v2 - v1) * (embout / hauteur)

	local haut = cadre:CreateTexture(nil, "OVERLAY")
	haut:SetTexture(e[1])
	haut:SetTexCoord(u1, u2, v1, v1 + partV)
	haut:SetHeight(embout)
	haut:SetPoint("TOPLEFT", cadre, "TOPLEFT")
	haut:SetPoint("TOPRIGHT", cadre, "TOPRIGHT")

	local bas = cadre:CreateTexture(nil, "OVERLAY")
	bas:SetTexture(e[1])
	bas:SetTexCoord(u1, u2, v2 - partV, v2)
	bas:SetHeight(embout)
	bas:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT")
	bas:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT")

	local milieu = cadre:CreateTexture(nil, "OVERLAY")
	milieu:SetTexture(e[1])
	milieu:SetTexCoord(u1, u2, v1 + partV, v2 - partV)
	milieu:SetPoint("TOPLEFT", haut, "BOTTOMLEFT")
	milieu:SetPoint("BOTTOMRIGHT", bas, "TOPRIGHT")

	cadre.haut, cadre.milieu, cadre.bas = haut, milieu, bas
	return cadre
end

-- NEUF TRANCHES DECOUPEES DANS UNE SEULE IMAGE.
--
-- POURQUOI. Une image de panneau porte une ombre et des coins arrondis de
-- taille fixe. L'etirer d'un bord a l'autre multiplie cette ombre par le
-- facteur d'echelle : sur une liste trois fois plus large que l'image, le
-- filet du bord rentre de vingt pixels et les angles se deforment. Les
-- coins doivent donc garder leur taille, les bords ne s'etirer que dans un
-- sens, et le centre seul dans les deux.
--
-- marges = { gauche, haut, droite, bas } : de combien le rectangle de
-- l'image deborde du cadre. C'est ainsi qu'on fait tomber le filet de
-- l'image exactement sur le bord du cadre : on donne l'epaisseur de
-- l'ombre, mesuree sur l'image.
function ForeverUI.CreateNineSlice(parent, atlas, coin, marges, niveau)
	local e = ForeverUI.AtlasEntry(atlas)
	if not e then
		return nil
	end

	local chemin, u1, u2, v1, v2, largeur, hauteur = e[1], e[2], e[3], e[4], e[5], e[6], e[7]
	local du = (u2 - u1) * coin / largeur
	local dv = (v2 - v1) * coin / hauteur
	local us = { u1, u1 + du, u2 - du, u2 }
	local vs = { v1, v1 + dv, v2 - dv, v2 }

	local tranches = {}
	local function tranche(colonne, ligne)
		local t = parent:CreateTexture(nil, niveau or "BACKGROUND")
		t:SetTexture(chemin)
		t:SetTexCoord(us[colonne], us[colonne + 1], vs[ligne], vs[ligne + 1])
		tranches[#tranches + 1] = t
		return t
	end

	local hg, hd = tranche(1, 1), tranche(3, 1)
	local bg, bd = tranche(1, 3), tranche(3, 3)
	local haut, bas = tranche(2, 1), tranche(2, 3)
	local gauche, droite = tranche(1, 2), tranche(3, 2)
	local centre = tranche(2, 2)

	for _, c in ipairs({ hg, hd, bg, bd }) do
		c:SetWidth(coin)
		c:SetHeight(coin)
	end
	haut:SetHeight(coin)
	bas:SetHeight(coin)
	gauche:SetWidth(coin)
	droite:SetWidth(coin)

	local G, H, D, B = marges[1], marges[2], marges[3], marges[4]
	hg:SetPoint("TOPLEFT", parent, "TOPLEFT", -G, H)
	hd:SetPoint("TOPRIGHT", parent, "TOPRIGHT", D, H)
	bg:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -G, -B)
	bd:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", D, -B)

	haut:SetPoint("TOPLEFT", hg, "TOPRIGHT")
	haut:SetPoint("TOPRIGHT", hd, "TOPLEFT")
	bas:SetPoint("BOTTOMLEFT", bg, "BOTTOMRIGHT")
	bas:SetPoint("BOTTOMRIGHT", bd, "BOTTOMLEFT")
	gauche:SetPoint("TOPLEFT", hg, "BOTTOMLEFT")
	gauche:SetPoint("BOTTOMRIGHT", bg, "TOPRIGHT")
	droite:SetPoint("TOPLEFT", hd, "BOTTOMLEFT")
	droite:SetPoint("BOTTOMRIGHT", bd, "TOPRIGHT")
	centre:SetPoint("TOPLEFT", hg, "BOTTOMRIGHT")
	centre:SetPoint("BOTTOMRIGHT", bd, "TOPLEFT")

	return tranches
end

-- LE BOUTON TERTIAIRE, EN DEUX ETATS.
--
-- common-button-tertiary-normal et ...-pressed, 46 x 34 chacun, sur la
-- feuille commonbuttontertiaryc60. Mesure sur l'art : a partir de x = 11 le
-- profil d'une colonne ne change plus -- l'about arrondi fait 11 px, d'ou un
-- coin de 11 sur les deux axes (11 + 24 + 11 en largeur, 11 + 12 + 11 en
-- hauteur). Etire au lieu d'etre decoupe, il ecraserait ses angles des qu'il
-- depasse 46 de large.
--
-- Le bouton garde ses propres textures, simplement effacees : elles portent
-- encore son etat pour le client, et certaines fonctions les lisent.
--
-- auto : l'etat presse suit le bouton de la souris. Sans lui, c'est a
-- l'appelant de commander, par bouton.foreverPresser(vrai ou faux) -- ce que
-- font les selecteurs de statistiques, dont l'etat tient tant que leur liste
-- est ouverte.
local TERTIAIRE_NORMAL = "common-button-tertiary-normal"
local TERTIAIRE_PRESSE = "common-button-tertiary-pressed"
local TERTIAIRE_COIN = 11
local TERTIAIRE_MARGES = { 0, 0, 0, 0 }

function ForeverUI.SkinTertiaryButton(bouton, auto)
	if bouton.foreverPresser then
		return bouton
	end

	for _, methode in ipairs({ "GetNormalTexture", "GetPushedTexture",
		"GetHighlightTexture", "GetDisabledTexture" }) do
		local texture = bouton[methode] and bouton[methode](bouton)
		if texture then
			texture:SetAlpha(0)
		end
	end

	bouton.foreverNormal = ForeverUI.CreateNineSlice(bouton, TERTIAIRE_NORMAL,
		TERTIAIRE_COIN, TERTIAIRE_MARGES, "BACKGROUND")
	bouton.foreverPresse = ForeverUI.CreateNineSlice(bouton, TERTIAIRE_PRESSE,
		TERTIAIRE_COIN, TERTIAIRE_MARGES, "BACKGROUND")

	bouton.foreverPresser = function(etat)
		for _, tranche in ipairs(bouton.foreverPresse or {}) do
			if etat then tranche:Show() else tranche:Hide() end
		end
		for _, tranche in ipairs(bouton.foreverNormal or {}) do
			if etat then tranche:Hide() else tranche:Show() end
		end
	end
	bouton.foreverPresser(false)

	if auto then
		bouton:HookScript("OnMouseDown", function() bouton.foreverPresser(true) end)
		bouton:HookScript("OnMouseUp", function() bouton.foreverPresser(false) end)
	end

	return bouton
end
