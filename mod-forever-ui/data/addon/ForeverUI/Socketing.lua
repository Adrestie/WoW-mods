-- ForeverUI : la fenetre de sertissage (ItemSocketingFrame, Blizzard_Item-
-- SocketingUI charge a la demande), a la DA de camelot (chantier des PNJ,
-- etape 3, demande de l'utilisateur du 2026-09-28).
--
-- RELEVE -- CAMELOT (blizzard_itemsocketingui.xml / .lua) :
--   cadre          ButtonFrameTemplate 338 x 424 (PortraitFrameBaseTemplate),
--                  portrait = l'icone de l'objet ; titre ITEM_SOCKETING,
--                  GameFontNormal TOP (15, -5) ; encart InsetFrameTemplate
--                  (4, -60 / -6, 4 : ButtonFrameTemplate_HideButtonBar) ;
--                  croix (-2, 1)
--   parchemin      (ARTWORK) UI-ItemSocketingFrame-_tile : haut 42 de (2,
--                  -21) a (-4, -21), v .375-.703125 ; bas 22 de (2, 3) a
--                  (-4, 3), v .1875-.359375 ; UI-ItemSocketParchementFrame-
--                  Left : gauche 9 de (2, -62) a (2, 25), droite 5 de (-4,
--                  -62) a (-4, 25), u 0-.75 ;
--   plaques        UI-ItemSocketingFrame 158 x 51 : BOTTOMLEFT (11, 26) v
--                  .0039-.2031, BOTTOMRIGHT (-11, 26) v .2109-.4102, u
--                  .0039-.6211 ; cadre du bouton : bouts 4 x 21 a (-167, 4)
--                  du BOTTOMRIGHT et (-5, 4), milieu en _tile v .0078-.1719
--   or             UI-Goldborder, coins 66 x 55 : BR (-10, 79), BL (11, 79),
--                  TR (-10, -64), TL (11, -64) ; bords UI-Goldborder-!tile 9
--                  (u .0078-.0781) et -_tile 9 (v .0156-.1563) entre eux
--   panneau        (BORDER) couleur (.078, .121, .215, .4) de (20, -74) a
--                  (-20, 80), et UI-ItemSocketingFrame (u .0039-.5039, v
--                  .418-.918) par-dessus ; ombre UI-Goldborder, coins 32 (u
--                  .1289-.2539, v .0078-.2578, en miroir), bords -_tile (v
--                  .1875-.6875) et -!tile (u .34375-.59375) de 32 ; six
--                  clous NubTemplate 11 x 12 (u .6289-.6719, v .0039-.0508)
--                  a BL (6, 20), BR (-5, 20), BL (6, 72), BR (-5, 72), TL
--                  (6, -57), TR (-5, -57)
--   description    ItemSocketingScrollFrame 293 x 258 a (22, -74), enfant
--                  259 x 254, largeur minimale 240 ; barre MinimalScrollBar
--                  (-14, -5 / -14, 1), cachee si rien ne defile
--   chasses        Socket1 a BOTTOM (-75 | -35 | 0, 33) selon 3 | 2 | 1
--                  chasses, les suivantes (40, 0) ; filigrane droit 70 x 55
--                  (u .28515625-.565) ; fond socket-<kit>-background,
--                  crochets socket-<kit>-closed / -open a la taille de leur
--                  atlas, centres ; eclat CENTER (1, 0) ; kits yellow, red,
--                  blue, meta, prismatic
--   Appliquer      APPLY, 162 x 22, BOTTOMRIGHT (-5, 4)
--
-- RELEVE -- 3.3.5 (Blizzard_ItemSocketingUI.xml / .lua) : 354 x 467, une
-- seule image de 512 pour toute la fenetre (sans nom), titre sans nom TOP
-- (15, -18), portrait ItemSocketingFramePortrait ; defilement 269 x 255 a
-- (32, -89), porte a 269 + 28 et la largeur minimale a 240 + 28 sans barre
-- (ItemSocketingFrame_Update, ItemSocketingSocketButton_OnScrollRange-
-- Changed) ; chasses a BOTTOM (x, 62) ; types Yellow, Red, Blue, Meta et
-- Socket (le prismatique) ; bouton ItemSocketingSocketButton (SOCKET_GEMS)
-- BOTTOMRIGHT (-10, 33).
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * Les couches : 3.3.5 n'a pas de sous-calques. Roche (BACKGROUND),
--     marbre (BORDER), liseré et couleur du panneau (ARTWORK), son image
--     (OVERLAY) sont des regions de la fenetre ; ombre, clous, parchemin, or
--     et plaques, dans cet ordre, sont dans un cadre fils (au-dessus), et la
--     description, les chasses et le bouton un niveau plus haut encore.
--   * Les pieces « tile » de camelot se repetent ; 3.3.5 ne repete pas une
--     partie d'image (SetTexCoord) : elles s'etirent.
--   * La barre suit la regle de l'atelier (28/09) : sans elle, la
--     description va jusqu'a laisser a droite du panneau la marge qu'elle a
--     a gauche (enfant 294, largeur minimale 240 + 35) ; camelot garde 259.
--   * Le portrait suit la regle VALIDEE (48 a (1, 1,5)), l'icone arrondie.
--   * Les confirmations et le texte de couleur (daltonisme) restent ceux du
--     client ; les evenements de camelot absents de 3.3.5 (SOCKET_INFO_ACCEPT,
--     BIND_CONFIRM...) n'ont pas d'equivalent.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local SO = {}
ForeverUI.Sertissage = SO

local SEP = string.char(92)
local DOSSIER = "Interface" .. SEP .. "ForeverUI" .. SEP .. "itemsocketingframe" .. SEP
local COMMUN = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP

local ART = {
	feuille = DOSSIER .. "ui-itemsocketingframe",
	tuile = DOSSIER .. "ui-itemsocketingframe-_tile",
	parchemin = DOSSIER .. "ui-itemsocketparchementframe-left",
	or_ = COMMUN .. "ui-goldborder",
	orV = COMMUN .. "ui-goldborder-!tile",
	orH = COMMUN .. "ui-goldborder-_tile",
	marbre = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
}

local N = {
	fenetre = { 338, 424 },
	portrait = { cote = 48, x = 1, y = 1.5 },
	titre = { 15, -5 },
	encart = { 4, -60, -6, 4 },
	panneau = { 20, -74, -20, 80 },
	couleur = { 0.078125, 0.12109375, 0.21484375, 0.4 },
	defile = { 22, -74, 293, 258 },
	enfant = 259, minimum = 240,
	-- sans barre : le panneau va de 20 a 318, le defilement part de 22 ; il
	-- va a 316, la meme marge (2) qu'a gauche
	enfantSans = 294,
	barre = { -14, -5, 1 },
	chasse = { y = 33, x = { [1] = 0, [2] = -35, [3] = -75 } },
	eclat = { 1, 0 },
	appliquer = { 162, 22, -5, 4 },
	niveauHabit = 1, niveauContenu = 2, niveauCroix = 22,
}

local KITS = { Yellow = "yellow", Red = "red", Blue = "blue", Meta = "meta", Socket = "prismatic" }

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- une texture de fichier a coordonnees : { fichier, u1, u2, v1, v2 }
local function morceau(hote, couche, fichier, u1, u2, v1, v2, l, h)
	local t = hote:CreateTexture(nil, couche)
	t:SetTexture(fichier)
	t:SetTexCoord(u1, u2, v1, v2)
	if l then t:SetWidth(l) end
	if h then t:SetHeight(h) end
	return t
end

-- ------------------------------------------------------------ l'habillage

local function habillage(f)
	local d = CreateFrame("Frame", nil, f)
	d:SetAllPoints(f)
	d:SetFrameLevel(f:GetFrameLevel() + N.niveauHabit)
	d:EnableMouse(false)
	local p = {}
	-- l'ombre du panneau (BACKGROUND du cadre fils : sous tout le reste)
	local c = {
		hg = morceau(d, "BACKGROUND", ART.or_, 0.12890625, 0.25390625, 0.0078125, 0.2578125, 32, 32),
		hd = morceau(d, "BACKGROUND", ART.or_, 0.25390625, 0.12890625, 0.0078125, 0.2578125, 32, 32),
		bg = morceau(d, "BACKGROUND", ART.or_, 0.12890625, 0.25390625, 0.2578125, 0.0078125, 32, 32),
		bd = morceau(d, "BACKGROUND", ART.or_, 0.25390625, 0.12890625, 0.2578125, 0.0078125, 32, 32),
	}
	c.hg:SetPoint("TOPLEFT", f, "TOPLEFT", 20, -74)
	c.hd:SetPoint("TOPRIGHT", f, "TOPRIGHT", -20, -74)
	c.bg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 20, 88)
	c.bd:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -20, 88)
	local function entre(t, a1, c1, r1, a2, c2, r2)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
		return t
	end
	p.ombre = c
	p.ombreHaut = entre(morceau(d, "BACKGROUND", ART.orH, 0, 1, 0.1875, 0.6875, nil, 32), "TOPLEFT", c.hg, "TOPRIGHT", "TOPRIGHT", c.hd, "TOPLEFT")
	p.ombreBas = entre(morceau(d, "BACKGROUND", ART.orH, 0, 1, 0.6875, 0.1875, nil, 32), "BOTTOMLEFT", c.bg, "BOTTOMRIGHT", "BOTTOMRIGHT", c.bd, "BOTTOMLEFT")
	p.ombreGauche = entre(morceau(d, "BACKGROUND", ART.orV, 0.34375, 0.59375, 0, 1, 32, nil), "TOPLEFT", c.hg, "BOTTOMLEFT", "BOTTOMLEFT", c.bg, "TOPLEFT")
	p.ombreDroite = entre(morceau(d, "BACKGROUND", ART.orV, 0.59375, 0.34375, 0, 1, 32, nil), "TOPRIGHT", c.hd, "BOTTOMRIGHT", "BOTTOMRIGHT", c.bd, "TOPRIGHT")
	-- les clous (NubTemplate)
	p.clous = {}
	for _, v in ipairs({ { "BOTTOMLEFT", 6, 20 }, { "BOTTOMRIGHT", -5, 20 }, { "BOTTOMLEFT", 6, 72 },
		{ "BOTTOMRIGHT", -5, 72 }, { "TOPLEFT", 6, -57 }, { "TOPRIGHT", -5, -57 } }) do
		local t = morceau(d, "BORDER", ART.feuille, 0.62890625, 0.671875, 0.00390625, 0.05078125, 11, 12)
		t:SetPoint(v[1], f, v[1], v[2], v[3])
		p.clous[#p.clous + 1] = t
	end
	-- le parchemin
	local haut = morceau(d, "ARTWORK", ART.tuile, 0, 1, 0.375, 0.703125, nil, 42)
	haut:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -21)
	haut:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -21)
	local bas = morceau(d, "ARTWORK", ART.tuile, 0, 1, 0.1875, 0.359375, nil, 22)
	bas:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 3)
	bas:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 3)
	local gauche = morceau(d, "ARTWORK", ART.parchemin, 0, 0.75, 0, 1, 9, nil)
	gauche:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -62)
	gauche:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 25)
	local droite = morceau(d, "ARTWORK", ART.parchemin, 0, 0.75, 0, 1, 5, nil)
	droite:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -62)
	droite:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -4, 25)
	p.parchemin = { haut = haut, bas = bas, gauche = gauche, droite = droite }
	-- les plaques des chasses et le cadre du bouton
	local pg = morceau(d, "ARTWORK", ART.feuille, 0.00390625, 0.62109375, 0.00390625, 0.203125, 158, 51)
	pg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 11, 26)
	local pd = morceau(d, "ARTWORK", ART.feuille, 0.00390625, 0.62109375, 0.2109375, 0.41015625, 158, 51)
	pd:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -11, 26)
	local bg = morceau(d, "ARTWORK", ART.feuille, 0.62890625, 0.64453125, 0.05859375, 0.140625, 4, 21)
	bg:SetPoint("BOTTOMLEFT", f, "BOTTOMRIGHT", -167, 4)
	local bd = morceau(d, "ARTWORK", ART.feuille, 0.65234375, 0.66796875, 0.05859375, 0.140625, 4, 21)
	bd:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -5, 4)
	local bm = morceau(d, "ARTWORK", ART.tuile, 0, 1, 0.0078125, 0.171875, nil, 21)
	bm:SetPoint("TOPLEFT", bg, "TOPRIGHT")
	bm:SetPoint("TOPRIGHT", bd, "TOPLEFT")
	p.plaques = { pg, pd }
	p.cadreBouton = { bg, bm, bd }
	-- la bordure doree
	local o = {
		bd = morceau(d, "ARTWORK", ART.or_, 0.26171875, 0.51953125, 0.0078125, 0.4375, 66, 55),
		bg = morceau(d, "ARTWORK", ART.or_, 0.26171875, 0.51953125, 0.453125, 0.8828125, 66, 55),
		hd = morceau(d, "ARTWORK", ART.or_, 0.52734375, 0.78515625, 0.0078125, 0.4375, 66, 55),
		hg = morceau(d, "ARTWORK", ART.or_, 0.52734375, 0.78515625, 0.453125, 0.8828125, 66, 55),
	}
	o.bd:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 79)
	o.bg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 11, 79)
	o.hd:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -64)
	o.hg:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -64)
	p.or_ = o
	p.orGauche = entre(morceau(d, "ARTWORK", ART.orV, 0.0078125, 0.078125, 0, 1, 9, nil), "TOPLEFT", o.hg, "BOTTOMLEFT", "BOTTOMLEFT", o.bg, "TOPLEFT")
	p.orDroite = entre(morceau(d, "ARTWORK", ART.orV, 0.0078125, 0.078125, 0, 1, 9, nil), "TOPRIGHT", o.hd, "BOTTOMRIGHT", "BOTTOMRIGHT", o.bd, "TOPRIGHT")
	p.orHaut = entre(morceau(d, "ARTWORK", ART.orH, 0, 1, 0.015625, 0.15625, nil, 9), "TOPLEFT", o.hg, "TOPRIGHT", "TOPRIGHT", o.hd, "TOPLEFT")
	p.orBas = entre(morceau(d, "ARTWORK", ART.orH, 0, 1, 0.015625, 0.15625, nil, 9), "BOTTOMLEFT", o.bg, "BOTTOMRIGHT", "BOTTOMRIGHT", o.bd, "BOTTOMLEFT")
	p.cadre = d
	return p
end

-- ------------------------------------------------------------ apres le client

-- la description selon la barre (regle de l'atelier) : le meme test que le
-- client (GetVerticalScrollRange), apres lui ; la fenetre a defilement et
-- son enfant a nos largeurs
function SO.Largeurs()
	local fx = ItemSocketingScrollFrame
	if not fx then return end
	local avec = (fx:GetVerticalScrollRange() or 0) ~= 0
	fx:SetWidth(avec and N.defile[3] or N.enfantSans)
	ItemSocketingScrollChild:SetWidth(avec and N.enfant or N.enfantSans)
end

-- LA LARGEUR MINIMALE SE TRADUIT AU MOMENT OU LE CLIENT LA POSE : il demande
-- 240 + 28 sans barre, puis remplit la description. La reposer APRES lui et
-- remplir a nouveau changerait la plage, et le client, rappele, la
-- reposerait a son tour : chacun renverrait la balle a l'autre. Une
-- post-accroche sur la methode de la description remplace donc sa valeur
-- sans barre par la notre (240 + 35), avant qu'il remplisse.
local function minimumSansBarre(self, largeur, force)
	if SO.dansMinimum then return end
	if largeur == (ITEM_SOCKETING_DESCRIPTION_MIN_WIDTH or N.minimum) + 28 then
		SO.dansMinimum = true
		self:SetMinimumWidth(N.minimum + N.enfantSans - N.enfant, force)
		SO.dansMinimum = false
	end
end

-- APRES ItemSocketingFrame_Update : portrait, chasses a leur place de
-- camelot, fonds et crochets de camelot
function SO.Apres()
	local h = ItemSocketingFrame and ItemSocketingFrame.foreverHabit
	if not h then return end
	local _, icone = GetSocketItemInfo()
	if icone then SetPortraitToTexture(h.portrait, icone) end
	local n = GetNumSockets() or 0
	local C = N.chasse
	poser(ItemSocketingSocket1, "BOTTOM", ItemSocketingFrame, "BOTTOM", C.x[n] or C.x[1], C.y)
	for i = 1, math.min(n, MAX_NUM_SOCKETS or 3) do
		local nom = "ItemSocketingSocket" .. i
		local kit = KITS[GetSocketTypes(i) or ""]
		if kit then
			ForeverUI.SetAtlas(_G[nom .. "Background"], "socket-" .. kit .. "-background")
			ForeverUI.SetAtlas(_G[nom .. "BracketFrameClosedBracket"], "socket-" .. kit .. "-closed")
			ForeverUI.SetAtlas(_G[nom .. "BracketFrameOpenBracket"], "socket-" .. kit .. "-open")
		end
	end
	SO.Largeurs()
end

function SO.Habiller()
	local f = ItemSocketingFrame
	if not f or f.foreverHabit then return end
	-- l'image de 512 et le titre sans nom de 3.3.5, le portrait du client
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local t = r:GetTexture()
			if type(t) == "string" and string.find(string.lower(t), "ui-itemsocketingframe", 1, true) then r:SetAlpha(0) end
		elseif r:GetObjectType() == "FontString" and r:GetText() == ITEM_SOCKETING then
			r:SetAlpha(0)
		end
	end
	ItemSocketingFramePortrait:SetAlpha(0)
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	local habit = Gb.FenetrePortrait(f, {
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = ITEM_SOCKETING,
	})
	f.foreverHabit = habit
	habit.titre:ClearAllPoints()
	habit.titre:SetPoint("TOP", f, "TOP", N.titre[1], N.titre[2])
	-- l'encart : marbre (BORDER, au-dessus de la roche), liseré en ARTWORK
	local E = N.encart
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", E[1], E[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", E[3], E[4])
	local marbre = f:CreateTexture(nil, "BORDER")
	marbre:SetTexture(ART.marbre, true)
	if marbre.SetHorizTile then marbre:SetHorizTile(true) marbre:SetVertTile(true) end
	marbre:SetAllPoints(rect)
	habit.encart = { rect = rect, marbre = marbre, lisere = Gb.NeufTranches(f, "InsetFrameTemplate", rect, "ARTWORK") }
	-- le panneau de la description : sa couleur (ARTWORK), son image (OVERLAY)
	local P = N.panneau
	local couleur = f:CreateTexture(nil, "ARTWORK")
	couleur:SetTexture(N.couleur[1], N.couleur[2], N.couleur[3], N.couleur[4])
	couleur:SetPoint("TOPLEFT", f, "TOPLEFT", P[1], P[2])
	couleur:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", P[3], P[4])
	local lumiere = morceau(f, "OVERLAY", ART.feuille, 0.00390625, 0.50390625, 0.41796875, 0.91796875)
	lumiere:SetPoint("TOPLEFT", f, "TOPLEFT", P[1], P[2])
	lumiere:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", P[3], P[4])
	habit.panneau = { couleur = couleur, lumiere = lumiere }
	habit.decor = habillage(f)
	-- le contenu au-dessus du decor
	local niveau = f:GetFrameLevel() + N.niveauContenu
	local D = N.defile
	local fx = ItemSocketingScrollFrame
	fx:SetFrameLevel(niveau)
	poser(fx, "TOPLEFT", f, "TOPLEFT", D[1], D[2])
	fx:SetWidth(D[3])
	fx:SetHeight(D[4])
	for _, s in ipairs({ "Top", "Bottom" }) do
		local t = _G["ItemSocketingScrollFrame" .. s]
		if t then t:SetAlpha(0) end
	end
	Gb.BarreA(ItemSocketingScrollFrameScrollBar, fx, N.barre[1], N.barre[2], N.barre[3])
	-- les chasses : filigrane droit de camelot, crochet ouvert centre, eclat
	for i = 1, MAX_NUM_SOCKETS or 3 do
		local nom = "ItemSocketingSocket" .. i
		local s = _G[nom]
		if s then
			s:SetFrameLevel(niveau)
			local droite = _G[nom .. "Right"]
			droite:SetWidth(70)
			droite:SetHeight(55)
			droite:SetTexCoord(0.28515625, 0.565, 0, 0.21484375)
			poser(_G[nom .. "BracketFrameOpenBracket"], "CENTER", _G[nom .. "BracketFrame"], "CENTER", 0, 0)
			poser(_G[nom .. "Shine"], "CENTER", s, "CENTER", N.eclat[1], N.eclat[2])
		end
	end
	local A = N.appliquer
	local b = ItemSocketingSocketButton
	b:SetFrameLevel(niveau)
	b:SetWidth(A[1])
	b:SetHeight(A[2])
	poser(b, "BOTTOMRIGHT", f, "BOTTOMRIGHT", A[3], A[4])
	b:SetText(APPLY)
	Gb.Croix(ItemSocketingCloseButton, f)
	ItemSocketingCloseButton:SetFrameLevel(f:GetFrameLevel() + N.niveauCroix)
	hooksecurefunc(ItemSocketingDescription, "SetMinimumWidth", minimumSansBarre)
	hooksecurefunc("ItemSocketingFrame_Update", SO.Apres)
	hooksecurefunc("ItemSocketingSocketButton_OnScrollRangeChanged", SO.Largeurs)
end

SO.Habiller()

local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:SetScript("OnEvent", function(_, _, nom)
	if nom == "Blizzard_ItemSocketingUI" then
		SO.Habiller()
	end
end)
