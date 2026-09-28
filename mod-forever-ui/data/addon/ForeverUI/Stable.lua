-- ForeverUI : l'etable du chasseur (PetStableFrame), a la DA de camelot
-- (chantier des PNJ, etape 3, demande de l'utilisateur du 2026-09-28).
--
-- RELEVE -- CAMELOT (blizzard_stableui/camelot/blizzard_stableui.xml et
-- .lua, shared/blizzard_stableui_shared.lua ; [Game] = camelot) :
--   cadre          PortraitFrameTemplate 384 x 512 (roche, stries, metal) ;
--                  portrait du PNJ ; titre vide ; croix (-2, 1)
--   textes         PetStableLevelText GameFontNormal TOP (0, -34), la
--                  loyaute dessous (GameFontNormalSmall, (0, -1))
--   scene          de (7, -72) a (-10, 140), 367 x 300 : fond
--                  hunter-stable-bg-art_<specialisation> a 0,8 ; ombre
--                  perks-char-shadow 410 x 90 CENTER (-8, -80) a 0,6 ;
--                  InsetFrameTemplate (marbre, liseré) sur toute la scene ;
--                  ShadowOverlayTemplate (Interface\Common\ShadowOverlay-*)
--                  de TOPLEFT a BOTTOMRIGHT (1, -1) ; regime (Pet-
--                  FrameHappinessTemplate 24 x 23) a (4, -6)
--   commandes      ModelSceneControlFrameTemplate TOP (0, -10) : boutons 32
--                  x 32 common-button-square-gray-up / -down (enfonce
--                  (1, -1)), icones 16 x 16 common-icon-rotateleft /
--                  -rotateright / -undo, surbrillance de l'icone en ADD a
--                  0,4 ; enchaines a -6 ; caches hors de la scene, 0,5
--                  sinon, 1 au survol d'un bouton
--   experience     PetExpStatusBarTemplate 322 x 12 a BOTTOM (0, 10) de la
--                  scene : barre de 10, fond UI-HUD-ExperienceBar-
--                  Background, remplissage -Fill-Experience, deux moities
--                  161 x 13 de UI-MainMenuBar-Dwarf par-dessus (TOPLEFT
--                  (0, 2)) ; texte au survol
--   emplacements   PetStableSlotTemplate 37 x 37 (les fichiers de 3.3.5) ;
--                  le premier TOP sur le BOTTOM de la scene (-69, -23), ou
--                  (-69, -43) sans achat ; +53 puis +15 ; CURRENT_PET et
--                  STABLED_PETS au-dessus (0, 6) et (24, 6)
--   bas            STABLE_SLOT_TEXT BOTTOM (0, 55) ; COSTS_LABEL
--                  BOTTOMLEFT (70, 30), le prix a sa droite (0, 0) ;
--                  Acheter 80 x 22 BOTTOMRIGHT (-75, 25) ; l'argent du
--                  joueur de (10, 7) a (-10, 7) dans son encadre
--                  (ContainerFrameCurrencyBorderTemplate : common-coinbox-
--                  left / -right 8 x 17, _common-coinbox-center tendu)
--
-- RELEVE -- 3.3.5 (FrameXML/PetStable.xml et .lua) : meme cadre, art
-- UI-PetStable-* (deux sans nom), titre PetStableTitleLabel, modele
-- PetStableModel 313 x 223 a (23, -76) et ses fleches, regime
-- PetStablePetInfo, CINQ emplacements (courant + 4), PetStable_Update.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * Cinq emplacements contre trois : la rangee est centree sous la scene
--     (283 de large : le premier a -123 du centre), STABLED_PETS centre sur
--     les quatre (26, 6 de Pet2).
--   * Le titre STABLES reste dans la bande du titre (camelot la laisse
--     vide) ; la loyaute n'existe pas en 3.3.5 (pas d'anneau).
--   * La specialisation vient de GetStablePetInfo / GetPetTalentTree, dans
--     la langue du client : son nom se traduit par les textes de l'addon ;
--     une autre langue laisse la scene sur le marbre.
--   * L'experience n'est connue que du familier invoque (GetPetExperience) :
--     la barre ne se montre que pour lui.
--   * Les couches : fond, marbre et ombre dans un cadre sous le modele,
--     liseré, ombre du bord et regime dans un cadre au-dessus.
--   * L'argent : camelot l'ancre a la fois a 28 et a 7 du bas ; il est pose
--     a 7, en bas de la fenetre (a 28 il couvrirait le bouton Acheter).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits
local L = ForeverUI.L

local E = {}
ForeverUI.Etable = E

local SEP = string.char(92)
local COMMUN = "Interface" .. SEP .. "ForeverUI" .. SEP .. "common" .. SEP

local N = {
	portrait = { cote = 48, x = 1, y = 1.5 },
	niveau = { 0, -34 },
	scene = { 7, -72, -10, 140 },
	fondAlpha = 0.8,
	ombre = { 410, 90, -8, -80, 0.6 },
	regime = { 4, -6 },
	commandes = { y = -10, cote = 32, icone = 16, ecart = -6, alpha = 0.5, lueur = 0.4 },
	experience = { 322, 10, 0, 10, moitie = 161, moitieH = 13 },
	-- la rangee : 37 + 53 + 37 + 3 x (15 + 37) = 283, centree sous la scene
	rangee = { x = -123, y = -23, ySansAchat = -43, courant = 53, ecart = 15 },
	etiquetteStable = { 26, 6 },
	textePlaces = { 0, 55 },
	cout = { 70, 30 },
	acheter = { 80, 22, -75, 25 },
	argent = { 10, 7, bord = 8, h = 17 },
	niveaux = { fond = 1, modele = 2, dessus = 3, commandes = 4, croix = 22 },
}

local ART = {
	marbre = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	ombreBord = { coin = COMMUN .. "shadowoverlay-corner", haut = COMMUN .. "shadowoverlay-top",
		bas = COMMUN .. "shadowoverlay-bottom", gauche = COMMUN .. "shadowoverlay-left", droite = COMMUN .. "shadowoverlay-right" },
	nain = "Interface" .. SEP .. "MainMenuBar" .. SEP .. "UI-MainMenuBar-Dwarf",
}

-- les specialisations : le nom du client (textes de l'addon) -> l'atlas
local SPECIALISATIONS = {
	{ L.STABLE_TALENT_FEROCITY, "hunter-stable-bg-art_ferocity" },
	{ L.STABLE_TALENT_TENACITY, "hunter-stable-bg-art_tenacity" },
	{ L.STABLE_TALENT_CUNNING, "hunter-stable-bg-art_cunning" },
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- ------------------------------------------------------------ la scene

-- ShadowOverlayTemplate (mainline/shareduipaneltemplates.xml) : coins 32,
-- bords de 32 entre eux, en fichiers
local function ombreDuBord(hote, rect)
	local A = ART.ombreBord
	local function coin(point, u1, u2, v1, v2)
		local t = hote:CreateTexture(nil, "ARTWORK")
		t:SetTexture(A.coin)
		t:SetTexCoord(u1, u2, v1, v2)
		t:SetWidth(32)
		t:SetHeight(32)
		t:SetPoint(point, rect, point)
		return t
	end
	local hg = coin("TOPLEFT", 0, 1, 0, 1)
	local hd = coin("TOPRIGHT", 1, 0, 0, 1)
	local bg = coin("BOTTOMLEFT", 0, 1, 1, 0)
	local bd = coin("BOTTOMRIGHT", 1, 0, 1, 0)
	local function bord(fichier, a1, c1, r1, a2, c2, r2, l, h)
		local t = hote:CreateTexture(nil, "ARTWORK")
		t:SetTexture(fichier)
		if l then t:SetWidth(l) end
		if h then t:SetHeight(h) end
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
		return t
	end
	return {
		hg = hg, hd = hd, bg = bg, bd = bd,
		haut = bord(A.haut, "TOPLEFT", hg, "TOPRIGHT", "TOPRIGHT", hd, "TOPLEFT", nil, 32),
		bas = bord(A.bas, "BOTTOMLEFT", bg, "BOTTOMRIGHT", "BOTTOMRIGHT", bd, "BOTTOMLEFT", nil, 32),
		gauche = bord(A.gauche, "TOPLEFT", hg, "BOTTOMLEFT", "BOTTOMLEFT", bg, "TOPLEFT", 32, nil),
		droite = bord(A.droite, "TOPRIGHT", hd, "BOTTOMRIGHT", "BOTTOMRIGHT", bd, "TOPRIGHT", 32, nil),
	}
end

-- un bouton carre de ModelSceneControlFrameTemplate sur un bouton donne
local function boutonCarre(b, icone)
	local C = N.commandes
	b:SetWidth(C.cote)
	b:SetHeight(C.cote)
	for _, lire in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture" }) do
		local t = b[lire] and b[lire](b)
		if t then t:SetAlpha(0) end
	end
	local fond = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "common-button-square-gray-up", true)
	fond:SetAllPoints(b)
	local image = b:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(image, icone, true)
	image:SetWidth(C.icone)
	image:SetHeight(C.icone)
	image:SetPoint("CENTER", b, "CENTER", 0, 0)
	local lueur = b:CreateTexture(nil, "HIGHLIGHT")
	ForeverUI.SetAtlas(lueur, icone, true)
	lueur:SetWidth(C.icone)
	lueur:SetHeight(C.icone)
	lueur:SetPoint("CENTER", image, "CENTER", 0, 0)
	lueur:SetBlendMode("ADD")
	lueur:SetAlpha(C.lueur)
	b:HookScript("OnMouseDown", function()
		ForeverUI.SetAtlas(fond, "common-button-square-gray-down", true)
		poser(image, "CENTER", b, "CENTER", 1, -1)
	end)
	b:HookScript("OnMouseUp", function()
		ForeverUI.SetAtlas(fond, "common-button-square-gray-up", true)
		poser(image, "CENTER", b, "CENTER", 0, 0)
	end)
	b.foreverCarre = { fond = fond, image = image, lueur = lueur }
	return b
end

-- ------------------------------------------------------------ l'experience

local function barreExperience(parent, scene)
	local X = N.experience
	local b = CreateFrame("Frame", "ForeverUIPetStableExpBar", parent)
	b:SetWidth(X[1])
	b:SetHeight(X[2])
	b:SetPoint("BOTTOM", scene, "BOTTOM", X[3], X[4])
	b:EnableMouse(true)
	local fond = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "ui-hud-experiencebar-background-camelot", true)
	fond:SetAllPoints(b)
	local remplissage = b:CreateTexture(nil, "ARTWORK")
	remplissage:SetPoint("LEFT", b, "LEFT", 0, 0)
	remplissage:SetHeight(X[2])
	remplissage:Hide()
	-- les deux moities de l'art du nain (PetExpStatusBarTemplate)
	local g = b:CreateTexture(nil, "OVERLAY")
	g:SetTexture(ART.nain)
	g:SetTexCoord(0.1953125, 0.8046875, 0.2890625, 0.33984375)
	g:SetWidth(X.moitie)
	g:SetHeight(X.moitieH)
	g:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 2)
	local d = b:CreateTexture(nil, "OVERLAY")
	d:SetTexture(ART.nain)
	d:SetTexCoord(0.203125, 0.8125, 0.2890625, 0.33984375)
	d:SetWidth(X.moitie)
	d:SetHeight(X.moitieH)
	d:SetPoint("LEFT", g, "RIGHT", 0, 0)
	local texte = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	texte:SetPoint("CENTER", b, "CENTER", 0, 0)
	texte:Hide()
	b:SetScript("OnEnter", function() texte:Show() end)
	b:SetScript("OnLeave", function() texte:Hide() end)
	b.remplissage, b.texte = remplissage, texte
	b:Hide()
	return b
end

-- l'experience du familier invoque (3.3.5 n'en donne pas d'autre)
function E.MajExperience(invoque)
	local b = E.experience
	if not b then return end
	local acquis, maximum
	if invoque and GetPetExperience then acquis, maximum = GetPetExperience() end
	if not maximum or maximum <= 0 then
		b:Hide()
		return
	end
	b:Show()
	local fraction = math.min(1, (acquis or 0) / maximum)
	local e = ForeverUI.AtlasEntry("ui-hud-experiencebar-fill-experience-camelot")
	local w = N.experience[1] * fraction
	if e and w >= 1 then
		b.remplissage:SetTexture(e[1])
		b.remplissage:SetTexCoord(e[2], e[2] + (e[3] - e[2]) * fraction, e[4], e[5])
		b.remplissage:SetWidth(w)
		b.remplissage:Show()
	else
		b.remplissage:Hide()
	end
	b.texte:SetText(string.format("%d / %d  (%d%%)", acquis or 0, maximum, math.floor(fraction * 100)))
end

-- ------------------------------------------------------------ apres le client

-- le fond selon la specialisation du familier choisi
local function specialisation()
	local choisi = GetSelectedStablePet and GetSelectedStablePet() or -1
	local talent
	if choisi == 0 and UnitExists("pet") then
		talent = GetPetTalentTree and GetPetTalentTree()
	elseif choisi and choisi >= 0 then
		talent = select(5, GetStablePetInfo(choisi))
	end
	for _, s in ipairs(SPECIALISATIONS) do
		if talent and s[1] and talent == s[1] then return s[2] end
	end
end

-- APRES PetStable_Update : portrait, fond, rangee, experience
function E.Apres()
	local h = PetStableFrame and PetStableFrame.foreverHabit
	if not h then return end
	SetPortraitTexture(h.portrait, UnitExists("npc") and "npc" or "player")
	local atlas = specialisation()
	if atlas and PetStableModel:IsShown() then
		ForeverUI.SetAtlas(h.fond, atlas, true)
		h.fond:Show()
	else
		h.fond:Hide()
	end
	local R = N.rangee
	poser(PetStableCurrentPet, "TOP", h.scene, "BOTTOM", R.x,
		PetStablePurchaseButton:IsShown() and R.y or R.ySansAchat)
	local choisi = GetSelectedStablePet and GetSelectedStablePet() or -1
	E.MajExperience(choisi == 0 and UnitExists("pet"))
end

-- les commandes : visibles tant que la souris est sur la scene
local function suivreSouris(self)
	local h = PetStableFrame.foreverHabit
	local dessus = h.scene:IsMouseOver() and PetStableModel:IsShown()
	Gb.Montrer(h.commandes, dessus)
	if dessus then
		local surBouton = false
		for _, b in ipairs(h.boutons) do
			if b:IsMouseOver() then surBouton = true end
		end
		h.commandes:SetAlpha(surBouton and 1 or N.commandes.alpha)
	end
end

function E.Habiller()
	local f = PetStableFrame
	if not f or f.foreverHabit then return end
	-- l'art de 3.3.5 (deux pieces sans nom, deux nommees) et son portrait
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local t = r:GetTexture()
			if type(t) == "string" and string.find(string.lower(t), "ui-petstable-", 1, true) then r:SetAlpha(0) end
		end
	end
	PetStableFramePortrait:SetAlpha(0)
	PetStableTitleLabel:SetAlpha(0)
	f:SetHitRectInsets(0, 0, 0, 0)
	local habit = Gb.FenetrePortrait(f, {
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = STABLES,
	})
	f.foreverHabit = habit
	local base = f:GetFrameLevel()
	local NV = N.niveaux
	-- la scene : un repere, et sous le modele le marbre, le fond de la
	-- specialisation et l'ombre du familier
	local S = N.scene
	local scene = CreateFrame("Frame", "ForeverUIPetStableScene", f)
	scene:SetPoint("TOPLEFT", f, "TOPLEFT", S[1], S[2])
	scene:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", S[3], S[4])
	scene:SetFrameLevel(base + NV.fond)
	scene:EnableMouse(false)
	habit.scene = scene
	local marbre = scene:CreateTexture(nil, "BACKGROUND")
	marbre:SetTexture(ART.marbre, true)
	if marbre.SetHorizTile then marbre:SetHorizTile(true) marbre:SetVertTile(true) end
	marbre:SetAllPoints(scene)
	local fond = scene:CreateTexture(nil, "BORDER")
	fond:SetAllPoints(scene)
	fond:SetAlpha(N.fondAlpha)
	fond:Hide()
	habit.marbre, habit.fond = marbre, fond
	local O = N.ombre
	local ombre = scene:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(ombre, "perks-char-shadow", true)
	ombre:SetWidth(O[1])
	ombre:SetHeight(O[2])
	ombre:SetPoint("CENTER", scene, "CENTER", O[3], O[4])
	ombre:SetAlpha(O[5])
	habit.ombreFamilier = ombre
	-- le modele du client, sur toute la scene, et tourne a la souris
	poser(PetStableModel, "TOPLEFT", scene, "TOPLEFT", 0, 0)
	PetStableModel:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT", 0, 0)
	PetStableModel:SetFrameLevel(base + NV.modele)
	if ForeverUI.TournerALaSouris then ForeverUI.TournerALaSouris(PetStableModel) end
	-- au-dessus : liseré de l'encart et ombre du bord
	local dessus = CreateFrame("Frame", nil, f)
	dessus:SetAllPoints(scene)
	dessus:SetFrameLevel(base + NV.dessus)
	dessus:EnableMouse(false)
	habit.lisere = Gb.NeufTranches(dessus, "InsetFrameTemplate", scene)
	local cadreOmbre = CreateFrame("Frame", nil, dessus)
	cadreOmbre:SetPoint("TOPLEFT", scene, "TOPLEFT", 0, 0)
	cadreOmbre:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT", 1, -1)
	habit.ombreBord = ombreDuBord(dessus, cadreOmbre)
	-- le regime, en haut a gauche de la scene
	PetStablePetInfo:SetParent(dessus)
	poser(PetStablePetInfo, "TOPLEFT", scene, "TOPLEFT", N.regime[1], N.regime[2])
	PetStablePetInfo:SetFrameLevel(base + NV.commandes)
	-- les commandes : tourner a gauche, a droite, revenir
	local C = N.commandes
	local commandes = CreateFrame("Frame", nil, f)
	commandes:SetFrameLevel(base + NV.commandes)
	commandes:SetHeight(C.cote)
	commandes:SetPoint("TOP", scene, "TOP", 0, C.y)
	local gauche = boutonCarre(PetStableModelRotateLeftButton, "common-icon-rotateleft")
	local droite = boutonCarre(PetStableModelRotateRightButton, "common-icon-rotateright")
	local retour = boutonCarre(CreateFrame("Button", "ForeverUIPetStableResetButton", commandes), "common-icon-undo")
	retour:SetScript("OnClick", function()
		PetStableModel.rotation = MODELFRAME_DEFAULT_ROTATION or 0.61
		PetStableModel:SetRotation(PetStableModel.rotation)
	end)
	for i, b in ipairs({ gauche, droite, retour }) do
		b:SetParent(commandes)
		b:SetFrameLevel(base + NV.commandes + 1)
		if i == 1 then
			poser(b, "LEFT", commandes, "LEFT", 0, 0)
		else
			poser(b, "LEFT", i == 2 and gauche or droite, "RIGHT", C.ecart, 0)
		end
	end
	commandes:SetWidth(3 * C.cote + 2 * C.ecart)
	habit.commandes, habit.boutons = commandes, { gauche, droite, retour }
	commandes:Hide()
	dessus:SetScript("OnUpdate", suivreSouris)
	-- l'experience du familier invoque
	E.experience = barreExperience(dessus, scene)
	-- les textes du haut
	poser(PetStableLevelText, "TOP", f, "TOP", N.niveau[1], N.niveau[2])
	-- les emplacements : centres sous la scene ; STABLED_PETS sur les quatre
	local R = N.rangee
	poser(PetStableCurrentPet, "TOP", scene, "BOTTOM", R.x, R.y)
	for _, r in ipairs({ PetStableStabledPet2:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == STABLED_PETS then
			poser(r, "BOTTOM", PetStableStabledPet2, "TOP", N.etiquetteStable[1], N.etiquetteStable[2])
		end
	end
	-- le bas
	poser(PetStableSlotText, "BOTTOM", f, "BOTTOM", N.textePlaces[1], N.textePlaces[2])
	poser(PetStableCostLabel, "BOTTOMLEFT", f, "BOTTOMLEFT", N.cout[1], N.cout[2])
	poser(PetStableCostMoneyFrame, "LEFT", PetStableCostLabel, "RIGHT", 0, 0)
	local A = N.acheter
	PetStablePurchaseButton:SetWidth(A[1])
	PetStablePurchaseButton:SetHeight(A[2])
	poser(PetStablePurchaseButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", A[3], A[4])
	Gb.BoutonPanneau(PetStablePurchaseButton)
	-- l'argent du joueur dans son encadre
	local M = N.argent
	poser(PetStableMoneyFrame, "BOTTOMLEFT", f, "BOTTOMLEFT", M[1], M[2])
	PetStableMoneyFrame:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -M[1], M[2])
	local bg = PetStableMoneyFrame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(bg, "common-coinbox-left", true)
	bg:SetWidth(M.bord)
	bg:SetHeight(M.h)
	bg:SetPoint("LEFT", PetStableMoneyFrame, "LEFT", 0, 0)
	local bd = PetStableMoneyFrame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(bd, "common-coinbox-right", true)
	bd:SetWidth(M.bord)
	bd:SetHeight(M.h)
	bd:SetPoint("RIGHT", PetStableMoneyFrame, "RIGHT", 0, 0)
	local bm = PetStableMoneyFrame:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(bm, "_common-coinbox-center", true)
	bm:SetPoint("TOPLEFT", bg, "TOPRIGHT")
	bm:SetPoint("BOTTOMRIGHT", bd, "BOTTOMLEFT")
	habit.bourse = { bg, bm, bd }
	Gb.Croix(PetStableFrameCloseButton, f)
	PetStableFrameCloseButton:SetFrameLevel(base + NV.croix)
	hooksecurefunc("PetStable_Update", E.Apres)
end

E.Habiller()
