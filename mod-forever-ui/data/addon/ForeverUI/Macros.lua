-- ForeverUI : la fenetre des macros (MacroFrame) et son choix d'icone
-- (MacroPopupFrame), Blizzard_MacroUI charge a la demande, a la DA de
-- camelot (demande de l'utilisateur, 2026-09-28 : « fait le menu et
-- reglages », etape 2).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (Blizzard_MacroUI.xml / .lua de 3.3.5) :
--   MacroFrame 384 x 512 (art de feuille de personnage, HitRectInsets 0 / 34
--     / 0 / 75), portrait MacroFrame-Icon, titre sans nom CREATE_MACROS ;
--     onglets TabButtonTemplate MacroFrameTab1 (65, -39) et Tab2 a sa droite ;
--     grille MacroButtonScrollFrame (UIPanelScrollFrameTemplate 294 x 146 a
--     (23, -76), textures UI-Character-ScrollBar) dont MacroButtonContainer
--     porte MacroButton1..36 (PopupButtonTemplate), 6 par rangee, le premier
--     a (6, -6), 13 entre deux, 10 entre deux rangees ; barre
--     MacroHorizontalBarLeft (15, -220) ; MacroFrameSelectedMacroBackground
--     (16, -228) et son bouton, son nom, MacroEditButton (51, -30 de lui) ;
--     MacroFrameEnterMacroText (8, 0 sous lui) ; MacroFrameScrollFrame (11,
--     -18 sous lui) et MacroFrameText ; MacroFrameTextBackground (18, -305,
--     fond d'infobulle) ; MacroFrameCharLimitText BOTTOM (-15, 105) ;
--     MacroDeleteButton (gris), MacroNewButton, MacroExitButton 80 x 22 ;
--     MacroFrameCloseButton (UIPanelCloseButton).
--   MacroPopupFrame 297 x 298 (art MacroPopup-*), MacroPopupEditBox,
--     MacroPopupButton1..20 en 5 par rangee, MacroPopupScrollFrame,
--     MacroPopupOkayButton / CancelButton 78 x 22. Son remplissage passe par
--     NUM_MACRO_ICONS_SHOWN, NUM_ICONS_PER_ROW, NUM_ICON_ROWS et
--     MACRO_ICON_ROW_HEIGHT, qu'on N'ECRIT PAS.
--
-- RELEVE -- CAMELOT (blizzard_macroui, fichiers communs) :
--   MacroFrame  ButtonFrameTemplate 338 x 424 ; portrait MacroFrame-Icon
--     58 x 58 a (-5, 5) ; titre CREATE_MACROS a TOP (0, -5) ; encadre
--     InsetFrameTemplate (4, -60 / -6, 26) ; MacroSelector (319 x 146 a
--     (12, -66)) : 6 par rangee, marges 5, 13 entre deux (colonnes ET
--     rangees), barre MinimalScrollBar a -14 du bord droit, -7 en haut, 3 en
--     bas ; MacroHorizontalBarLeft (2, -210) ; SelectedMacroBackground (5,
--     -218) ; MacroEditButton (55, -30) ; EnterMacroText (8, 3) ;
--     MacroFrameScrollFrame (11, -13), barre a 6, -4 / 5 ; TextBackground
--     TooltipBackdropTemplate 322 x 95 a (6, -289) ; CharLimitText BOTTOM
--     (-15, 30) ; onglets PanelTopTabButtonTemplate (51, -28), le second a
--     la suite ; Delete BOTTOMLEFT (4, 4), New BOTTOMRIGHT (-82, 4), Exit
--     BOTTOMRIGHT (-5, 4), 80 x 22, UIPanelButtonTemplate. Les boutons de
--     macro (SelectorButtonTemplate) sont ceux de 3.3.5 (PopupButtonTemplate :
--     UI-EmptySlot-Disabled 45, icone 36, ButtonHilight-Square,
--     CheckButtonHilight) : rien a changer.
--   PanelTopTabButtonTemplate : l'art des onglets du bas (uiframe-tab*,
--     uiframe-activetab*) RETOURNE en hauteur et reduit a 75 %, pose en bas
--     de l'onglet (Left -3, Right 7, actifs -1 et 8) ; 32 de haut ; largeur
--     texte + 20, entre les deux bords (72) et 140 (maxTabWidth) ; texte
--     CENTER (0, -8), choisi (0, -4) ; GameFontNormalSmall, Highlight au
--     survol et choisi, Disable quand l'onglet est grise.
--   MacroPopupFrame  IconSelectorPopupFrameTemplate 525 x 495, TOPLEFT sur
--     le TOPRIGHT de MacroFrame (0, 5) -- la fenetre du choix d'icone des
--     ensembles d'equipement, VALIDEE (IconPicker.lua) : memes nombres, meme
--     habillage (SelectionFrameTemplate, grille de 10, zone du choix
--     courant).
--
-- CE QUI DIFFERE, ET POURQUOI. Les elements restent ceux du client, poses
-- aux places de camelot. Save / Cancel de camelot n'existent pas en 3.3.5
-- (la macro s'enregistre en changeant de macro ou en fermant) : pas ajoutes.
-- Le choix d'icone garde le defilement du client (sept rangees de dix
-- entieres, la ou camelot en montre sept et demie).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits
local L = ForeverUI.L

local M = {}
ForeverUI.Macros = M

local SEP = string.char(92)

local N = {
	fenetre = { 338, 424 },
	portrait = { cote = 58, x = -5, y = 5 },
	encadre = { 4, -60, -6, 26 },
	grille = { x = 12, y = -66, l = 319, h = 146, marge = 5, ecart = 13, parRangee = 6 },
	barreGrille = { x = -14, haut = -7, bas = 3 },
	barre = { 16, 11 },                 -- largeur du Slider du client, hauteur d'une fleche
	barreTexte = { x = 6, haut = -4, bas = 5 },
	largeurTexte = 286,                 -- MacroFrameScrollFrame / Text / TextButton de 3.3.5
	fondTexteL = 322,                   -- MacroFrameTextBackground (3.3.5 et camelot)
	boutonMacro = 36,                   -- PopupButtonTemplate
	trait = { 2, -210 },
	choisi = { 5, -218 },
	editer = { 55, -30 },
	saisir = { 8, 3 },
	texte = { 11, -13 },
	fondTexte = { 6, -289 },
	limite = { -15, 30 },
	onglet = { x = 51, y = -28, h = 32, cotes = 72, max = 140, marge = 20, texte = -8, texteChoisi = -4, reduit = 0.75 },
	bouton = { 80, 22 },
	suppr = { 4, 4 }, nouveau = { -82, 4 }, sortir = { -5, 4 },
}

-- ------------------------------------------------------------ les onglets

local ONGLET = {
	actifG = "uiframe-activetab-left", actifM = "_uiframe-activetab-center", actifD = "uiframe-activetab-right",
	g = "uiframe-tab-left-c60", m = "_uiframe-tab-center-c60", d = "uiframe-tab-right-c60",
}

-- un morceau retourne en hauteur, reduit a 75 % (PanelTopTabButtonMixin :
-- SetTexCoord(0, 1, 1, 0,25) de l'atlas, hauteur x 0,75)
local function morceau(b, couche, atlas)
	local t = b:CreateTexture(nil, couche)
	local e = ForeverUI.AtlasEntry(atlas)
	ForeverUI.SetAtlas(t, atlas)
	if e then
		local haut = e[4] + (e[5] - e[4]) * (1 - N.onglet.reduit)
		t:SetTexCoord(e[2], e[3], e[5], haut)
		t:SetHeight(e[7] * N.onglet.reduit)
	end
	return t
end

local function peindreOnglet(o)
	local a = o.foreverArt
	local choisi = MacroFrame and MacroFrame.selectedTab == o:GetID()
	local actif = Gb.Vrai(o:IsEnabled())
	for _, t in ipairs({ a.actifG, a.actifM, a.actifD }) do Gb.Montrer(t, choisi) end
	for _, t in ipairs({ a.g, a.m, a.d }) do Gb.Montrer(t, not choisi) end
	local police
	if choisi or (actif and o.foreverDessus) then
		police = GameFontHighlightSmall
	elseif actif then
		police = GameFontNormalSmall
	else
		police = GameFontDisableSmall
	end
	o:SetNormalFontObject(police)
	o:SetDisabledFontObject(police)
	local texte = o:GetFontString()
	if texte then
		texte:ClearAllPoints()
		texte:SetPoint("CENTER", o, "CENTER", 0, choisi and N.onglet.texteChoisi or N.onglet.texte)
		o:SetWidth(math.max(N.onglet.cotes, math.min(N.onglet.max, (texte:GetStringWidth() or 0) + N.onglet.marge)))
	end
end

local function habillerOnglet(o)
	local nom = o:GetName()
	for _, s in ipairs({ "Left", "Middle", "Right", "LeftDisabled", "MiddleDisabled", "RightDisabled" }) do
		local t = _G[nom .. s]
		if t then t:SetAlpha(0) end
	end
	local lueur = o:GetHighlightTexture()
	if lueur then
		lueur:SetTexture(nil)
		lueur:SetAlpha(0)
	end
	o:SetHeight(N.onglet.h)
	local a = {}
	a.actifG = morceau(o, "BACKGROUND", ONGLET.actifG)
	a.actifG:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", -1, 0)
	a.actifD = morceau(o, "BACKGROUND", ONGLET.actifD)
	a.actifD:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 8, 0)
	a.actifM = morceau(o, "BACKGROUND", ONGLET.actifM)
	a.actifM:SetPoint("TOPLEFT", a.actifG, "TOPRIGHT", 0, 0)
	a.actifM:SetPoint("TOPRIGHT", a.actifD, "TOPLEFT", 0, 0)
	a.g = morceau(o, "BACKGROUND", ONGLET.g)
	a.g:SetPoint("BOTTOMLEFT", o, "BOTTOMLEFT", -3, 0)
	a.d = morceau(o, "BACKGROUND", ONGLET.d)
	a.d:SetPoint("BOTTOMRIGHT", o, "BOTTOMRIGHT", 7, 0)
	a.m = morceau(o, "BACKGROUND", ONGLET.m)
	a.m:SetPoint("TOPLEFT", a.g, "TOPRIGHT", 0, 0)
	a.m:SetPoint("TOPRIGHT", a.d, "TOPLEFT", 0, 0)
	-- la surbrillance : l'inactif en ADD a 0,4
	for _, cle in ipairs({ "g", "m", "d" }) do
		local s = morceau(o, "HIGHLIGHT", ONGLET[cle])
		s:SetBlendMode("ADD")
		s:SetAlpha(0.4)
		s:SetAllPoints(a[cle])
	end
	o.foreverArt = a
	o:HookScript("OnEnter", function(self) self.foreverDessus = true; peindreOnglet(self) end)
	o:HookScript("OnLeave", function(self) self.foreverDessus = false; peindreOnglet(self) end)
	o:HookScript("OnShow", peindreOnglet)
	o:HookScript("OnEnable", peindreOnglet)
	o:HookScript("OnDisable", peindreOnglet)
	o:HookScript("OnClick", function()
		peindreOnglet(MacroFrameTab1)
		peindreOnglet(MacroFrameTab2)
	end)
	peindreOnglet(o)
end

-- ------------------------------------------------------------ la fenetre

local function poser(r, point, cible, relatif, x, y)
	r:ClearAllPoints()
	r:SetPoint(point, cible, relatif, x, y)
end

-- la barre d'une fenetre a defilement du client, a la place de camelot : le
-- Slider (16 de large) centre sur la barre de 8, ses fleches (hors de lui)
-- dans ses extremites
local function barreA(sb, cible, x, haut, bas)
	local demi = (N.barre[1] - 8) / 2
	sb:ClearAllPoints()
	sb:SetPoint("TOPLEFT", cible, "TOPRIGHT", x - demi, haut - N.barre[2])
	sb:SetPoint("BOTTOMLEFT", cible, "BOTTOMRIGHT", x - demi, bas + N.barre[2])
	Gb.Barre(sb)
end

function M.Habiller()
	local f = MacroFrame
	if not f or f.foreverHabit then return end
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	-- l'art de 3.3.5 : les quatre morceaux de fond et le portrait
	-- s'eteignent, comme le titre sans nom ; la barre et le fond du choix
	-- restent (camelot les garde)
	local gardes = { [MacroHorizontalBarLeft] = true, [MacroFrameSelectedMacroBackground] = true }
	for _, r in ipairs({ f:GetRegions() }) do
		local genre = r:GetObjectType()
		if genre == "Texture" and not gardes[r] then
			local _, relatif = r:GetPoint(1)
			-- le second morceau de la barre s'ancre sur le premier : il reste
			if relatif ~= MacroHorizontalBarLeft then
				r:SetAlpha(0)
			end
		elseif genre == "FontString" and r:GetText() == CREATE_MACROS then
			r:SetAlpha(0)
		end
	end
	local habit = Gb.FenetrePortrait(f, {
		portrait = "Interface" .. SEP .. "MacroFrame" .. SEP .. "MacroFrame-Icon",
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = CREATE_MACROS,
	})
	f.foreverHabit = habit
	-- l'encadre de ButtonFrameTemplate : marbre et lisere, en regions de la
	-- fenetre (sous ses textes et ses boutons)
	local rect = CreateFrame("Frame", nil, f)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", N.encadre[1], N.encadre[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", N.encadre[3], N.encadre[4])
	local marbre = f:CreateTexture(nil, "BACKGROUND")
	marbre:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble", true)
	if marbre.SetHorizTile then marbre:SetHorizTile(true) marbre:SetVertTile(true) end
	marbre:SetAllPoints(rect)
	habit.encadre = Gb.NeufTranches(f, "InsetFrameTemplate", rect)
	habit.marbre = marbre
	-- la croix : au-dessus du metal (cadre fils a +20), comme celle de la
	-- fenetre Social
	Gb.Croix(MacroFrameCloseButton, f)
	MacroFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)

	-- les onglets
	poser(MacroFrameTab1, "TOPLEFT", f, "TOPLEFT", N.onglet.x, N.onglet.y)
	habillerOnglet(MacroFrameTab1)
	habillerOnglet(MacroFrameTab2)

	-- la grille : 6 par rangee, marges 5, 13 entre deux
	local G = N.grille
	local grille = MacroButtonScrollFrame
	poser(grille, "TOPLEFT", f, "TOPLEFT", G.x, G.y)
	local barreX = G.l + N.barreGrille.x
	grille:SetWidth(barreX - (N.barre[1] - 8) / 2)
	grille:SetHeight(G.h)
	for _, r in ipairs({ grille:GetRegions() }) do
		if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
	end
	for i = 1, math.max(MAX_ACCOUNT_MACROS or 36, MAX_CHARACTER_MACROS or 18) do
		local b = _G["MacroButton" .. i]
		if b then
			b:ClearAllPoints()
			if i == 1 then
				b:SetPoint("TOPLEFT", MacroButtonContainer, "TOPLEFT", G.marge, -G.marge)
			elseif math.fmod(i - 1, G.parRangee) == 0 then
				b:SetPoint("TOP", _G["MacroButton" .. (i - G.parRangee)], "BOTTOM", 0, -G.ecart)
			else
				b:SetPoint("LEFT", _G["MacroButton" .. (i - 1)], "RIGHT", G.ecart, 0)
			end
		end
	end
	-- la barre de la grille : a -14 du bord droit du selecteur, -7 / 3
	local sb = MacroButtonScrollFrameScrollBar
	local demi = (N.barre[1] - 8) / 2
	sb:ClearAllPoints()
	sb:SetPoint("TOPLEFT", f, "TOPLEFT", G.x + barreX - demi, G.y + N.barreGrille.haut - N.barre[2])
	sb:SetPoint("BOTTOMLEFT", f, "TOPLEFT", G.x + barreX - demi, G.y - G.h + N.barreGrille.bas + N.barre[2])
	Gb.Barre(sb)
	-- la barre seulement si elle sert (regle du 28/09 ; l'onglet du
	-- personnage tient en trois rangees). Les icones sont de taille fixe :
	-- sans barre, la grille se centre dans l'encadre, le meme espace a gauche
	-- et a droite (demande du 28/09) ; avec elle, sa place de camelot
	local largeurGrille = G.parRangee * N.boutonMacro + (G.parRangee - 1) * G.ecart
	local encadreG, encadreD = N.encadre[1], N.fenetre[1] + N.encadre[3]
	local centrage = ((encadreG + encadreD) - (2 * (G.x + G.marge) + largeurGrille)) / 2
	Gb.BarreSelonContenu(grille, function(avec)
		poser(MacroButton1, "TOPLEFT", MacroButtonContainer, "TOPLEFT", G.marge + (avec and 0 or centrage), -G.marge)
	end)

	-- la macro choisie
	poser(MacroHorizontalBarLeft, "TOPLEFT", f, "TOPLEFT", N.trait[1], N.trait[2])
	poser(MacroFrameSelectedMacroBackground, "TOPLEFT", f, "TOPLEFT", N.choisi[1], N.choisi[2])
	poser(MacroEditButton, "TOPLEFT", MacroFrameSelectedMacroBackground, "TOPLEFT", N.editer[1], N.editer[2])
	poser(MacroFrameEnterMacroText, "TOPLEFT", MacroFrameSelectedMacroBackground, "BOTTOMLEFT", N.saisir[1], N.saisir[2])
	poser(MacroFrameScrollFrame, "TOPLEFT", MacroFrameSelectedMacroBackground, "BOTTOMLEFT", N.texte[1], N.texte[2])
	barreA(MacroFrameScrollFrameScrollBar, MacroFrameScrollFrame, N.barreTexte.x, N.barreTexte.haut, N.barreTexte.bas)
	-- le texte : la barre seulement si elle sert, et sans elle le texte (et
	-- sa zone de clic) s'etend jusqu'a laisser a droite de son fond la marge
	-- qu'il a a gauche (fond 6 .. 328, texte a 16 : 302)
	local texteG = N.choisi[1] + N.texte[1]
	local texteSans = (N.fondTexte[1] + N.fondTexteL) - (texteG - N.fondTexte[1]) - texteG
	Gb.BarreSelonContenu(MacroFrameScrollFrame, function(avec)
		local l = avec and N.largeurTexte or texteSans
		MacroFrameScrollFrame:SetWidth(l)
		MacroFrameText:SetWidth(l)
		MacroFrameTextButton:SetWidth(l)
	end)
	poser(MacroFrameTextBackground, "TOPLEFT", f, "TOPLEFT", N.fondTexte[1], N.fondTexte[2])
	ForeverUI.Tooltips.Habiller(MacroFrameTextBackground)
	poser(MacroFrameCharLimitText, "BOTTOM", f, "BOTTOM", N.limite[1], N.limite[2])

	-- les boutons
	for _, b in ipairs({ MacroDeleteButton, MacroNewButton, MacroExitButton }) do
		b:SetWidth(N.bouton[1])
		b:SetHeight(N.bouton[2])
	end
	for _, b in ipairs({ MacroDeleteButton, MacroNewButton, MacroExitButton, MacroEditButton }) do
		Gb.BoutonPanneau(b)
	end
	poser(MacroDeleteButton, "BOTTOMLEFT", f, "BOTTOMLEFT", N.suppr[1], N.suppr[2])
	poser(MacroNewButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.nouveau[1], N.nouveau[2])
	poser(MacroExitButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.sortir[1], N.sortir[2])

	M.HabillerChoix()
end

-- ============================================================ le choix d'icone
--
-- IconSelectorPopupFrameTemplate, comme les ensembles d'equipement
-- (IconPicker.lua, VALIDE) : fenetre 525 x 495, intitule (24, -21), champ
-- (29, -35), « Choose an Icon » (24, -79), zone du choix courant 275 x 45 a
-- TOPRIGHT (-13, -13) et son bouton de 36 a (-4,5, -3,5), grille a (21,
-- -97) : 10 par rangee, icones de 36, 10 entre deux, marges 5 ; Okay /
-- Cancel 78 x 22 a BOTTOMRIGHT (-11, 13) et 2 entre eux ; cadre
-- SelectionFrameTemplate (macropopup-*) sur un fond noir a 0,8.
local P = {
	fenetre = { 525, 495 }, place = { 0, 5 },
	entete = { 24, -21 }, champ = { 29, -35 }, choisir = { 24, -79 },
	zone = { l = 275, h = 45, x = -13, y = -13 }, choix = { cote = 36, x = -4.5, y = -3.5 },
	grille = { x = 21, y = -97 }, icone = 36, parRangee = 10, rangees = 7, ecart = 10, marge = 5,
	boutonBas = { l = 78, h = 22, x = -11, y = 13, ecart = -2 },
	fond = { alpha = 0.8, marge = 7 },
	bordDroit = 17,
}

local function affiches()
	return P.parRangee * P.rangees
end

local function boutonsChoix()
	local liste = {}
	for i = 1, affiches() do
		local b = _G["MacroPopupButton" .. i]
		if not b then
			b = CreateFrame("CheckButton", "MacroPopupButton" .. i, MacroPopupFrame, "MacroPopupButtonTemplate")
		end
		b:SetID(i)
		liste[i] = b
	end
	return liste
end

-- la grille de dix
local function poserGrille(popup)
	local pas = P.icone + P.ecart
	for i, b in ipairs(popup.foreverBoutons) do
		b:SetWidth(P.icone)
		b:SetHeight(P.icone)
		b:ClearAllPoints()
		if i == 1 then
			b:SetPoint("TOPLEFT", popup, "TOPLEFT", P.grille.x + P.marge, P.grille.y - P.marge)
		elseif math.fmod(i - 1, P.parRangee) == 0 then
			b:SetPoint("TOPLEFT", popup.foreverBoutons[i - P.parRangee], "BOTTOMLEFT", 0, -P.ecart)
		else
			b:SetPoint("TOPLEFT", popup.foreverBoutons[i - 1], "TOPRIGHT", P.ecart, 0)
		end
	end
	local defile = MacroPopupScrollFrame
	defile:SetWidth(P.parRangee * pas - P.ecart + 2 * P.marge)
	defile:SetHeight(P.rangees * pas - P.ecart + 2 * P.marge)
	defile:ClearAllPoints()
	defile:SetPoint("TOPLEFT", popup, "TOPLEFT", P.grille.x, P.grille.y)
	for _, r in ipairs({ defile:GetRegions() }) do
		if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
	end
	-- autant d'espace de part et d'autre de la barre (IconPicker)
	local droiteIcones = P.grille.x + P.marge + P.parRangee * pas - P.ecart
	local libre = (P.fenetre[1] - P.bordDroit) - droiteIcones
	local x = P.fenetre[1] - P.bordDroit - (libre - 8) / 2 - 8 - (N.barre[1] - 8) / 2
	local sb = MacroPopupScrollFrameScrollBar
	sb:ClearAllPoints()
	sb:SetPoint("TOPLEFT", popup, "TOPLEFT", x, P.grille.y - P.marge - N.barre[2])
	sb:SetPoint("BOTTOMLEFT", popup, "TOPLEFT", x, P.grille.y - P.marge - (P.rangees * pas - P.ecart) + N.barre[2])
	Gb.Barre(sb)
end

-- la zone du choix courant : l'icone retenue ; un clic la retrouve dans la
-- grille
local function iconeRetenue(popup)
	if popup.selectedIcon then
		return (GetMacroIconInfo(popup.selectedIcon))
	end
	return popup.selectedIconTexture
end

function M.MajChoix()
	local popup = MacroPopupFrame
	if popup and popup.foreverChoix then
		popup.foreverChoix.icone:SetTexture(iconeRetenue(popup) or "")
	end
end

local enCours = false

-- apres MacroPopupFrame_Update : la grille de dix, la meme numerotation que
-- le client ; chaque bouton porte l'identifiant qui, par son calcul
-- (decalage x 5 + GetID()), tombe sur l'icone qu'il montre
function M.Remplir()
	local popup = MacroPopupFrame
	local defile = MacroPopupScrollFrame
	if enCours or not (popup and popup.foreverBoutons) then return end
	enCours = true
	local decalage = FauxScrollFrame_GetOffset(defile) or 0
	local total = GetNumMacroIcons()
	local cinq = NUM_ICONS_PER_ROW or 5
	for i, b in ipairs(popup.foreverBoutons) do
		local index = decalage * P.parRangee + i
		b:SetID(decalage * (P.parRangee - cinq) + i)
		local icone = _G[b:GetName() .. "Icon"]
		if index <= total then
			local texture = GetMacroIconInfo(index)
			icone:SetTexture(texture)
			b:Show()
			if (popup.selectedIcon and index == popup.selectedIcon)
				or (not popup.selectedIcon and texture and texture == popup.selectedIconTexture) then
				b:SetChecked(1)
			else
				b:SetChecked(nil)
			end
		else
			icone:SetTexture("")
			b:Hide()
		end
	end
	FauxScrollFrame_Update(defile, math.ceil(total / P.parRangee), P.rangees, MACRO_ICON_ROW_HEIGHT)
	enCours = false
	M.MajChoix()
end

-- le clic de la zone : la rangee de l'icone retenue dans la vue
function M.Recaler()
	local popup = MacroPopupFrame
	local defile = MacroPopupScrollFrame
	local total = GetNumMacroIcons()
	local trouve = popup.selectedIcon
	if not trouve and popup.selectedIconTexture then
		for index = 1, total do
			if GetMacroIconInfo(index) == popup.selectedIconTexture then
				trouve = index
				break
			end
		end
	end
	if trouve then
		local derniere = math.floor((total - 1) / P.parRangee)
		local rangee = math.floor((trouve - 1) / P.parRangee)
		rangee = math.max(0, math.min(rangee, derniere - (P.rangees - 1)))
		FauxScrollFrame_OnVerticalScroll(defile, rangee * MACRO_ICON_ROW_HEIGHT, MACRO_ICON_ROW_HEIGHT, nil)
	end
	M.Remplir()
end

local function poserZone(popup)
	local Z = P.zone
	local zone = CreateFrame("Frame", nil, popup)
	zone:SetWidth(Z.l)
	zone:SetHeight(Z.h)
	zone:SetPoint("TOPRIGHT", popup, "TOPRIGHT", Z.x, Z.y)
	local bouton = CreateFrame("Button", "ForeverUIMacroIconChoiceButton", zone)
	bouton:SetWidth(P.choix.cote)
	bouton:SetHeight(P.choix.cote)
	bouton:SetPoint("TOPRIGHT", zone, "TOPRIGHT", P.choix.x, P.choix.y)
	local icone = bouton:CreateTexture(nil, "ARTWORK")
	icone:SetAllPoints(bouton)
	bouton.icone = icone
	local surlignage = bouton:CreateTexture(nil, "HIGHLIGHT")
	surlignage:SetTexture("Interface" .. SEP .. "Buttons" .. SEP .. "ButtonHilight-Square")
	surlignage:SetBlendMode("ADD")
	surlignage:SetAllPoints(bouton)
	local titre = zone:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	titre:SetPoint("TOPRIGHT", bouton, "TOPLEFT", -6, -2)
	titre:SetText(L.ICONPICKER_CURRENTLY_SELECTED)
	local aide = zone:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	aide:SetPoint("TOPRIGHT", titre, "BOTTOMRIGHT", 0, -2)
	aide:SetText(L.ICONPICKER_CLICK_TO_VIEW)
	bouton:SetScript("OnClick", M.Recaler)
	popup.foreverChoix = bouton
	popup.foreverZone = zone
end

-- SelectionFrameTemplate : huit morceaux macropopup-* sur un fond noir
local function habillerCadre(popup)
	for _, r in ipairs({ popup:GetRegions() }) do
		if r:GetObjectType() == "Texture" then r:SetAlpha(0) end
	end
	local fond = popup:CreateTexture(nil, "BACKGROUND")
	fond:SetTexture(0, 0, 0, P.fond.alpha)
	fond:SetPoint("TOPLEFT", popup, "TOPLEFT", P.fond.marge, -P.fond.marge)
	fond:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -P.fond.marge, P.fond.marge)
	local function piece(atlas, point)
		local t = popup:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(t, atlas)
		if point then t:SetPoint(point, popup, point, 0, 0) end
		return t
	end
	local hg = piece("macropopup-topleft-c60", "TOPLEFT")
	local hd = piece("macropopup-topright-c60", "TOPRIGHT")
	local bg = piece("macropopup-bottomleft-c60", "BOTTOMLEFT")
	local bd = piece("macropopup-bottomright-c60", "BOTTOMRIGHT")
	local haut = piece("_macropopup-top-c60")
	haut:SetPoint("TOPLEFT", hg, "TOPRIGHT")
	haut:SetPoint("TOPRIGHT", hd, "TOPLEFT")
	local bas = piece("_macropopup-bottom-c60")
	bas:SetPoint("BOTTOMLEFT", bg, "BOTTOMRIGHT")
	bas:SetPoint("BOTTOMRIGHT", bd, "BOTTOMLEFT")
	-- les bandes laterales gardent leur largeur d'atlas (IconPicker) : deux
	-- points du meme cote
	local gauche = piece("!macropopup-left-c60")
	gauche:SetPoint("TOPLEFT", hg, "BOTTOMLEFT")
	gauche:SetPoint("BOTTOMLEFT", bg, "TOPLEFT")
	local droite = piece("!macropopup-right-c60")
	droite:SetPoint("TOPRIGHT", hd, "BOTTOMRIGHT")
	droite:SetPoint("BOTTOMRIGHT", bd, "TOPRIGHT")
	popup.foreverCadre = { hg, hd, bg, bd, haut, bas, gauche, droite }
	popup.foreverFond = fond
end

function M.HabillerChoix()
	local popup = MacroPopupFrame
	if not popup or popup.foreverBoutons then return end
	popup:SetWidth(P.fenetre[1])
	popup:SetHeight(P.fenetre[2])
	popup:ClearAllPoints()
	popup:SetPoint("TOPLEFT", MacroFrame, "TOPRIGHT", P.place[1], P.place[2])
	popup.foreverBoutons = boutonsChoix()
	habillerCadre(popup)
	-- les deux intitules sans nom : par leur texte
	for _, r in ipairs({ popup:GetRegions() }) do
		if r:GetObjectType() == "FontString" then
			local t = r:GetText()
			if t == MACRO_POPUP_CHOOSE_ICON then
				poser(r, "TOPLEFT", popup, "TOPLEFT", P.choisir[1], P.choisir[2])
			elseif t == MACRO_POPUP_TEXT then
				poser(r, "TOPLEFT", popup, "TOPLEFT", P.entete[1], P.entete[2])
			end
		end
	end
	poser(MacroPopupEditBox, "TOPLEFT", popup, "TOPLEFT", P.champ[1], P.champ[2])
	poserGrille(popup)
	poserZone(popup)
	local B = P.boutonBas
	for _, b in ipairs({ MacroPopupCancelButton, MacroPopupOkayButton }) do
		b:SetWidth(B.l)
		b:SetHeight(B.h)
		Gb.BoutonPanneau(b)
	end
	poser(MacroPopupCancelButton, "BOTTOMRIGHT", popup, "BOTTOMRIGHT", B.x, B.y)
	poser(MacroPopupOkayButton, "RIGHT", MacroPopupCancelButton, "LEFT", B.ecart, 0)
	hooksecurefunc("MacroPopupFrame_Update", M.Remplir)
	hooksecurefunc("MacroPopupButton_SelectTexture", M.MajChoix)
	popup:HookScript("OnShow", M.Remplir)
end

-- chargee a la demande : a son arrivee, ou tout de suite si elle est la
if MacroFrame then
	M.Habiller()
end
local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:SetScript("OnEvent", function(self, _, nom)
	if nom == "Blizzard_MacroUI" then
		M.Habiller()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
M.veille = veille
