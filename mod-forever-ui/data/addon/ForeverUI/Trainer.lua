-- ForeverUI : la fenetre du maitre (ClassTrainerFrame, Blizzard_TrainerUI
-- charge a la demande), a la DA de camelot (chantier des PNJ, etape 3,
-- demande de l'utilisateur du 2026-09-28).
--
-- RELEVE -- CAMELOT (blizzard_trainerui/mainline/blizzard_trainerui.xml et
-- .lua ; blizzard_trainerui_camelot.lua : TrainerUI_UseCategories = true) :
--   cadre          ButtonFrameTemplate 338 x 424, portrait du PNJ, titre =
--                  son nom ; encart (4, -60 / -6, 26) ; croix (-2, 1)
--   rang           ClassTrainerStatusBar 130 x 18 a (64, -35) (maitre de
--                  metier) : fond (0, 0, .75, .5), barre UI-Character-
--                  Skills-Bar (0, 0, 1, .5), bords GuildFrame (gauche et
--                  droite 18 a (-2, 0) / (2, 0), milieu entre eux), texte
--                  GameFontHighlightSmall au centre
--   filtre         WowStyle1FilterDropdownTemplate TOPRIGHT (-13, -35), 18
--                  de haut (Gb.MenuFiltre)
--   liste          ScrollBox 302 x 330 a (5, -5) de l'encart (Update) ; vue
--                  en arbre : retrait 10, marges haut 1, bas 1, droite 1 ;
--                  fond TrainerTextures (u .00195-.58594, v .00195-.65430)
--                  de (-3, 4) a (3, -4) de la liste ; barre MinimalScrollBar
--                  (5, -2 / 5, -2)
--   categorie      TrainerUICategoryTemplate, 25 : Professions-recipe-
--                  header-left / -right a leur taille (LEFT / RIGHT, y 2),
--                  -middle entre eux ; nom GameFontNormal_NoShadow LEFT
--                  (10, 2) sur 10 (Highlight au survol) ; -expand (repliee)
--                  / -collapse a RIGHT (-10, 2), le meme en ADD au survol
--   competence     ClassTrainerSkillButtonTemplate, 47 : plaque, survol
--                  (ADD) et choix (ADD) TrainerTextures ; icone 36 a LEFT
--                  (6, 0), desaturee indisponible ; nom GameFontNormal sur 12
--                  a (6, -1) de l'icone ; rang (PARENS_TEMPLATE)
--                  GameFontNormalSmall a (5, -1) du nom ; prerequis
--                  SystemFont_Shadow_Small 240 x 30 a (0, -19) du nom
--                  (REQUIRES_LABEL, TRAINER_REQ_*, ITEM_SPELL_KNOWN si
--                  connue) ; prix SmallMoneyFrame TOPRIGHT (5, -7), rouge
--                  si trop cher, cache si connue ; voile gris (.55) en MOD a
--                  2 du bord si indisponible ; infobulle SetTrainerService a
--                  ANCHOR_RIGHT (35)
--   bas            Former (TRAIN) 80 x 22 BOTTOMRIGHT (-6, 4) ; l'argent
--                  UI-MoneyFrame-Border 148 x 34 a BOTTOMLEFT (5, -9), la
--                  bourse a sa droite (8, 6)
--
-- RELEVE -- 3.3.5 (Blizzard_TrainerUI.xml / .lua) : 384 x 512 ; liste PLATE
-- de 11 lignes de 16 (les en-tetes dans l'index, GetTrainerServiceInfo :
-- nom, rang, type header / available / unavailable / used, deplie) ;
-- panneau de details sous la liste ; Tout replier ; Quitter ; texte
-- d'accueil ; ClassTrainerFrame_Update, ClassTrainer_SetSelection.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * La liste est a nous (lignes de camelot) ; le client en garde la
--     logique : un clic fait ce que fait sa ligne (ClassTrainerSkillButton_
--     OnClick), un en-tete se replie par Expand / CollapseTrainerSkillLine.
--     Ses lignes, sa liste et son panneau de details restent en place,
--     invisibles et sans souris (le panneau pilote le bouton Former).
--   * Pas de panneau de details ni de texte d'accueil, ni Tout replier ni
--     Quitter : camelot n'en a pas (la description est dans l'infobulle).
--     Un clic modifie sur une ligne fait ce que faisait l'icone du panneau
--     de 3.3.5 (HandleModifiedItemClick).
--   * La liste avance d'une ligne a la fois (3.3.5 ne rogne que dans une
--     ScrollFrame) ; la barre suit la regle de l'atelier : cachee si tout
--     tient, et sans elle la liste et son fond gardent a droite la marge
--     qu'ils ont a gauche (318 de large).
--   * Le rang : GetTrainerTradeskillRankValues n'existe pas en 3.3.5 ; il
--     est lu dans les competences du joueur (GetSkillLineInfo) par le nom
--     du metier du maitre (GetTrainerServiceSkillLine).
--   * Les polices sans ombre de camelot n'existent pas en 3.3.5 : creees.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits
local L = ForeverUI.L

local T = {}
ForeverUI.Maitre = T

local SEP = string.char(92)
local TEXTURES = "Interface" .. SEP .. "ForeverUI" .. SEP .. "classtrainerframe" .. SEP .. "trainertextures"

local N = {
	fenetre = { 338, 424 },
	portrait = { cote = 48, x = 1, y = 1.5 },
	encart = { 4, -60, -6, 26 },
	rang = { 64, -35, 130, 18, bord = 18 },
	filtre = { -13, -35, 18 },
	liste = { 5, -5, 302, 330, sansBarre = 318, haut = 1, bas = 1, droite = 1, retrait = 10 },
	fondListe = { -3, 4, 3, -4 },
	barre = { 5, -2 },
	categorie = { h = 25, nom = { 10, 2, 10 }, fleche = { -10, 2 }, bout = 2 },
	competence = { h = 47, icone = { 36, 6 }, nom = { 6, -1, 12 }, rang = { 5, -1, 12 },
		prerequis = { 0, -19, 240, 30 }, prix = { 5, -7 }, voile = 2, gris = 0.55, bulle = 35 },
	former = { 80, 22, -6, 4 },
	argent = { 148, 34, 5, -9, bourse = { 8, 6 } },
}

local COORDS = {
	fond = { 0.00195313, 0.5859375, 0.00195313, 0.65429688 },
	plaque = { 0.00195313, 0.57421875, 0.65820313, 0.75 },
	survol = { 0.00195313, 0.57421875, 0.75390625, 0.84570313 },
	choix = { 0.00195313, 0.57421875, 0.84960938, 0.94140625 },
	rangG = { 0.60742188, 0.625, 0.78710938, 0.82226563 },
	rangD = { 0.60742188, 0.625, 0.82617188, 0.86132813 },
	rangM = { 0.60742188, 0.625, 0.74804688, 0.78320313 },
}

local ART = {
	marbre = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble",
	guilde = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildframe" .. SEP .. "guildframe",
	barre = "Interface" .. SEP .. "PaperDollInfoFrame" .. SEP .. "UI-Character-Skills-Bar",
	argent = "Interface" .. SEP .. "ForeverUI" .. SEP .. "moneyframe" .. SEP .. "ui-moneyframe-border",
}

-- GameFontNormal_NoShadow et GameFontHighlight_NoShadow de camelot
local function sansOmbre(nom, modele)
	local p = CreateFont(nom)
	p:SetFontObject(modele)
	p:SetShadowOffset(0, 0)
	p:SetShadowColor(0, 0, 0, 0)
	return p
end
local POLICES = {
	categorie = sansOmbre("ForeverUIFontNormalNoShadow", GameFontNormal),
	categorieSurvol = sansOmbre("ForeverUIFontHighlightNoShadow", GameFontHighlight),
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

local function morceau(hote, couche, fichier, c)
	local t = hote:CreateTexture(nil, couche)
	t:SetTexture(fichier)
	t:SetTexCoord(c[1], c[2], c[3], c[4])
	return t
end

-- ------------------------------------------------------------ les lignes

local function creerCategorie(liste, n)
	local C = N.categorie
	local b = CreateFrame("Button", "ForeverUITrainerCategory" .. n, liste)
	b:SetHeight(C.h)
	local g = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(g, "professions-recipe-header-left")
	g:SetPoint("LEFT", b, "LEFT", 0, C.bout)
	local d = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(d, "professions-recipe-header-right")
	d:SetPoint("RIGHT", b, "RIGHT", 0, C.bout)
	local m = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(m, "professions-recipe-header-middle", true)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	local nom = b:CreateFontString(nil, "OVERLAY")
	nom:SetFontObject(POLICES.categorie)
	nom:SetJustifyH("LEFT")
	nom:SetHeight(C.nom[3])
	nom:SetPoint("LEFT", b, "LEFT", C.nom[1], C.nom[2])
	local fleche = b:CreateTexture(nil, "ARTWORK")
	fleche:SetPoint("RIGHT", b, "RIGHT", C.fleche[1], C.fleche[2])
	local lueur = b:CreateTexture(nil, "HIGHLIGHT")
	lueur:SetBlendMode("ADD")
	lueur:SetPoint("CENTER", fleche, "CENTER", 0, 0)
	b.nom, b.fleche, b.lueur = nom, fleche, lueur
	b:SetScript("OnEnter", function(self) self.nom:SetFontObject(POLICES.categorieSurvol) end)
	b:SetScript("OnLeave", function(self) self.nom:SetFontObject(POLICES.categorie) end)
	b:SetScript("OnClick", function(self)
		if self.deplie then
			CollapseTrainerSkillLine(self:GetID())
		else
			ExpandTrainerSkillLine(self:GetID())
		end
	end)
	return b
end

local function creerCompetence(liste, n)
	local C = N.competence
	local nom = "ForeverUITrainerSkill" .. n
	local b = CreateFrame("Button", nom, liste)
	b:SetHeight(C.h)
	b:RegisterForClicks("LeftButtonUp")
	b:SetNormalTexture(TEXTURES)
	local plaque = b:GetNormalTexture()
	plaque:SetTexCoord(COORDS.plaque[1], COORDS.plaque[2], COORDS.plaque[3], COORDS.plaque[4])
	plaque:ClearAllPoints()
	plaque:SetAllPoints(b)
	b:SetHighlightTexture(TEXTURES)
	local h = b:GetHighlightTexture()
	h:SetTexCoord(COORDS.survol[1], COORDS.survol[2], COORDS.survol[3], COORDS.survol[4])
	h:ClearAllPoints()
	h:SetAllPoints(b)
	h:SetBlendMode("ADD")
	local voile = b:CreateTexture(nil, "BACKGROUND")
	voile:SetTexture(C.gris, C.gris, C.gris, 1)
	voile:SetBlendMode("MOD")
	voile:SetPoint("TOPLEFT", b, "TOPLEFT", C.voile, -C.voile)
	voile:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -C.voile, C.voile)
	voile:Hide()
	local choix = morceau(b, "OVERLAY", TEXTURES, COORDS.choix)
	choix:SetBlendMode("ADD")
	choix:SetAllPoints(b)
	choix:Hide()
	local icone = b:CreateTexture(nil, "OVERLAY")
	icone:SetWidth(C.icone[1])
	icone:SetHeight(C.icone[1])
	icone:SetPoint("LEFT", b, "LEFT", C.icone[2], 0)
	local titre = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titre:SetJustifyH("LEFT")
	titre:SetHeight(C.nom[3])
	titre:SetPoint("TOPLEFT", icone, "TOPRIGHT", C.nom[1], C.nom[2])
	local prerequis = b:CreateFontString(nil, "OVERLAY")
	prerequis:SetFontObject(_G.SystemFont_Shadow_Small or GameFontHighlightSmall)
	prerequis:SetJustifyH("LEFT")
	prerequis:SetJustifyV("MIDDLE")
	prerequis:SetWidth(C.prerequis[3])
	prerequis:SetHeight(C.prerequis[4])
	prerequis:SetPoint("LEFT", titre, "LEFT", C.prerequis[1], C.prerequis[2])
	local rang = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	rang:SetJustifyH("LEFT")
	rang:SetHeight(C.rang[3])
	rang:SetPoint("BOTTOMLEFT", titre, "BOTTOMRIGHT", C.rang[1], C.rang[2])
	local prix = CreateFrame("Frame", nom .. "Money", b, "SmallMoneyFrameTemplate")
	prix:SetPoint("TOPRIGHT", b, "TOPRIGHT", C.prix[1], C.prix[2])
	if MoneyFrame_SetType then MoneyFrame_SetType(prix, "STATIC") end
	b.voile, b.choix, b.icone, b.titre, b.prerequis, b.rang, b.prix = voile, choix, icone, titre, prerequis, rang, prix
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", C.bulle)
		GameTooltip:SetTrainerService(self:GetID())
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self, bouton)
		if IsModifiedClick() then
			HandleModifiedItemClick(GetTrainerServiceItemLink(self:GetID()))
			return
		end
		ClassTrainerSkillButton_OnClick(self, bouton)
	end)
	return b
end

-- les prerequis d'une competence (ClassTrainerFrame_InitServiceButton de
-- camelot, avec les fonctions de 3.3.5)
local function prerequis(i, genre)
	local texte, sep = "", ""
	local niveau = GetTrainerServiceLevelReq(i)
	if niveau and niveau > 1 then
		if UnitLevel("player") >= niveau then
			texte = texte .. format(TRAINER_REQ_LEVEL, niveau)
		else
			texte = texte .. format(TRAINER_REQ_LEVEL_RED, niveau)
		end
		sep = PLAYER_LIST_DELIMITER
	end
	local competence, rangReq, aRang = GetTrainerServiceSkillReq(i)
	if competence then
		texte = texte .. sep .. format(aRang and TRAINER_REQ_SKILL_RANK or TRAINER_REQ_SKILL_RANK_RED, competence, rangReq)
		sep = PLAYER_LIST_DELIMITER
	end
	for j = 1, GetTrainerServiceNumAbilityReq(i) or 0 do
		local sort, aSort = GetTrainerServiceAbilityReq(i, j)
		if sort then
			texte = texte .. sep .. format(aSort and TRAINER_REQ_ABILITY or TRAINER_REQ_ABILITY_RED, sort)
			sep = PLAYER_LIST_DELIMITER
		end
	end
	if genre == "used" then
		return ITEM_SPELL_KNOWN, false
	elseif texte ~= "" then
		return REQUIRES_LABEL .. " " .. texte, true
	end
	return "", true
end

local function remplirCompetence(b, i, argent)
	local nom, sousNom, genre = GetTrainerServiceInfo(i)
	b:SetID(i)
	b.icone:SetTexture(GetTrainerServiceIcon(i))
	local texte, montrerPrix = prerequis(i, genre)
	local indisponible = genre == "unavailable"
	b.icone:SetDesaturated(indisponible)
	Gb.Montrer(b.voile, indisponible)
	b.titre:SetText(nom or UNKNOWN)
	b.prerequis:SetText(texte)
	b.rang:SetText((sousNom and sousNom ~= "") and format(PARENS_TEMPLATE, sousNom) or "")
	local cout = GetTrainerServiceCost(i)
	if montrerPrix and cout and cout > 0 then
		MoneyFrame_Update(b.prix:GetName(), cout)
		SetMoneyFrameColor(b.prix:GetName(), argent >= cout and "white" or "red")
		b.prix:Show()
	else
		b.prix:Hide()
	end
	Gb.Montrer(b.choix, ClassTrainerFrame.selectedService == i)
end

-- combien de lignes tiennent depuis la i-eme (les hauteurs different)
local function hauteurDe(i)
	local _, _, genre = GetTrainerServiceInfo(i)
	return genre == "header" and N.categorie.h or N.competence.h
end

local function tiennent(depuis, total, place)
	local y, n = N.liste.haut, 0
	for i = depuis, total do
		local h = hauteurDe(i)
		if y + h > place then break end
		y = y + h
		n = n + 1
	end
	return n
end

-- la liste (et son fond) selon la barre : sa place de camelot, ou sans
-- barre la meme marge a droite qu'a gauche
local function poserListe(avec)
	local h = ClassTrainerFrame.foreverHabit
	local Li = N.liste
	h.liste:SetWidth(avec and Li[3] or Li.sansBarre)
end

-- APRES ClassTrainerFrame_Update : la liste de camelot, sur les donnees du
-- client ; portrait, titre, rang
function T.Maj()
	local f = ClassTrainerFrame
	local h = f and f.foreverHabit
	if not h then return end
	SetPortraitTexture(h.portrait, "npc")
	T.MajRang()
	local total = GetNumTrainerServices() or 0
	local place = N.liste[4] - N.liste.bas
	-- le plus grand decalage : celui d'ou la fin tient
	local maxi = 0
	for d = 0, total do
		if tiennent(d + 1, total, place) >= total - d then
			maxi = d
			break
		end
	end
	h.maxi = maxi
	-- la selection en vue quand elle change (le client choisit la premiere
	-- competence apprenable a l'ouverture)
	local choisi = f.selectedService
	if choisi and choisi ~= h.dernierChoix then
		h.dernierChoix = choisi
		if choisi <= h.decalage then
			h.decalage = choisi - 1
		elseif choisi > h.decalage + tiennent(h.decalage + 1, total, place) then
			local d = choisi - 1
			while d > 0 and tiennent(d, total, place) >= choisi - d + 1 do d = d - 1 end
			h.decalage = d
		end
	end
	h.decalage = math.max(0, math.min(h.decalage or 0, maxi))
	local avec = maxi > 0
	if avec ~= h.avecBarre then
		h.avecBarre = avec
		poserListe(avec)
	end
	local largeur = h.liste:GetWidth() - N.liste.droite
	local argent = GetMoney()
	local y, nc, ns = N.liste.haut, 0, 0
	local sousCategorie = false
	-- un en-tete avant le decalage met les competences suivantes en retrait
	for i = 1, h.decalage do
		local _, _, genre = GetTrainerServiceInfo(i)
		if genre == "header" then sousCategorie = true end
	end
	for i = h.decalage + 1, total do
		local nom, _, genre, deplie = GetTrainerServiceInfo(i)
		local ht = (genre == "header") and N.categorie.h or N.competence.h
		if y + ht > place then break end
		local ligne
		if genre == "header" then
			sousCategorie = true
			nc = nc + 1
			ligne = h.categories[nc] or creerCategorie(h.liste, nc)
			h.categories[nc] = ligne
			ligne:SetID(i)
			ligne.deplie = deplie and true or false
			ligne.nom:SetText(nom or "")
			local atlas = deplie and "professions-recipe-header-collapse" or "professions-recipe-header-expand"
			ForeverUI.SetAtlas(ligne.fleche, atlas)
			ForeverUI.SetAtlas(ligne.lueur, atlas)
			poser(ligne, "TOPLEFT", h.liste, "TOPLEFT", 0, -y)
			ligne:SetWidth(largeur)
		else
			ns = ns + 1
			ligne = h.competences[ns] or creerCompetence(h.liste, ns)
			h.competences[ns] = ligne
			remplirCompetence(ligne, i, argent)
			local retrait = sousCategorie and N.liste.retrait or 0
			poser(ligne, "TOPLEFT", h.liste, "TOPLEFT", retrait, -y)
			ligne:SetWidth(largeur - retrait)
		end
		ligne:Show()
		y = y + ht
	end
	for i = nc + 1, #h.categories do h.categories[i]:Hide() end
	for i = ns + 1, #h.competences do h.competences[i]:Hide() end
	h.barre:Regler(maxi + 1, 1, h.decalage)
end

-- le rang du metier du maitre (camelot : GetTrainerTradeskillRankValues)
function T.MajRang()
	local h = ClassTrainerFrame.foreverHabit
	local barre = h.rang
	local metier
	if IsTradeskillTrainer() then
		for i = 1, GetNumTrainerServices() or 0 do
			metier = GetTrainerServiceSkillLine(i)
			if metier then break end
		end
	end
	local rang, maxi, bonus
	if metier then
		for j = 1, GetNumSkillLines() or 0 do
			local nom, entete, _, r, _, b, m = GetSkillLineInfo(j)
			if not entete and nom == metier then
				rang, bonus, maxi = r, b, m
				break
			end
		end
	end
	if not rang or not maxi or maxi <= 0 then
		barre:Hide()
		return
	end
	barre:SetMinMaxValues(0, maxi)
	barre:SetValue(rang)
	if bonus and bonus > 0 then
		barre.texte:SetFormattedText(L.TRAINER_RANK_BONUS, rang, bonus, maxi)
	else
		barre.texte:SetFormattedText(L.TRAINER_RANK, rang, maxi)
	end
	barre:Show()
end

-- ------------------------------------------------------------ la fenetre

-- l'ecran du client, sans souris et invisible : lignes, listes, details
local function etouffer()
	for i = 1, CLASS_TRAINER_SKILLS_DISPLAYED or 11 do
		local b = _G["ClassTrainerSkill" .. i]
		if b then b:SetAlpha(0) b:EnableMouse(false) end
	end
	for _, nom in ipairs({ "ClassTrainerListScrollFrame", "ClassTrainerDetailScrollFrame" }) do
		local fx = _G[nom]
		if fx then
			fx:SetAlpha(0)
			fx:EnableMouse(false)
			if fx.EnableMouseWheel then fx:EnableMouseWheel(false) end
			for _, s in ipairs({ "ScrollBar", "ScrollBarScrollUpButton", "ScrollBarScrollDownButton" }) do
				local c = _G[nom .. s]
				if c then c:EnableMouse(false) end
			end
		end
	end
	if ClassTrainerSkillIcon then ClassTrainerSkillIcon:EnableMouse(false) end
	for _, r in ipairs({ ClassTrainerSkillHighlightFrame, ClassTrainerGreetingText, ClassTrainerHorizontalBarLeft,
		ClassTrainerNameText, ClassTrainerFramePortrait }) do
		if r then r:SetAlpha(0) end
	end
	for _, c in ipairs({ ClassTrainerExpandButtonFrame, ClassTrainerCancelButton }) do
		if c then ForeverUI.Suppress(c) end
	end
end

function T.Habiller()
	local f = ClassTrainerFrame
	if not f or f.foreverHabit then return end
	-- l'art de 3.3.5 : les quatre UI-ClassTrainer-* (deux sans nom) et le
	-- morceau droit sans nom de la barre horizontale
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			local t = r:GetTexture()
			if type(t) == "string" then
				t = string.lower(t)
				if string.find(t, "ui-classtrainer-", 1, true) or string.find(t, "horizontalbar", 1, true) then
					r:SetAlpha(0)
				end
			end
		end
	end
	etouffer()
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	local habit = Gb.FenetrePortrait(f, {
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = ClassTrainerNameText:GetText(),
	})
	f.foreverHabit = habit
	local function suivre() habit.titre:SetText(ClassTrainerNameText:GetText() or "") end
	hooksecurefunc(ClassTrainerNameText, "SetText", suivre)
	-- l'encart : marbre (BORDER) ; fond de la liste (ARTWORK) ; liseré
	-- (OVERLAY, au-dessus du fond qu'il borde, comme chez camelot)
	local E = N.encart
	local rect = CreateFrame("Frame", nil, f)
	rect:EnableMouse(false)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", E[1], E[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", E[3], E[4])
	local marbre = f:CreateTexture(nil, "BORDER")
	marbre:SetTexture(ART.marbre, true)
	if marbre.SetHorizTile then marbre:SetHorizTile(true) marbre:SetVertTile(true) end
	marbre:SetAllPoints(rect)
	habit.encart = { rect = rect, marbre = marbre, lisere = Gb.NeufTranches(f, "InsetFrameTemplate", rect, "OVERLAY") }
	-- la liste et son fond
	local Li = N.liste
	local liste = CreateFrame("Frame", "ForeverUITrainerList", f)
	liste:SetPoint("TOPLEFT", rect, "TOPLEFT", Li[1], Li[2])
	liste:SetWidth(Li[3])
	liste:SetHeight(Li[4])
	habit.liste = liste
	habit.categories, habit.competences, habit.decalage = {}, {}, 0
	local F = N.fondListe
	local fond = morceau(f, "ARTWORK", TEXTURES, COORDS.fond)
	fond:SetPoint("TOPLEFT", liste, "TOPLEFT", F[1], F[2])
	fond:SetPoint("BOTTOMRIGHT", liste, "BOTTOMRIGHT", F[3], F[4])
	habit.fondListe = fond
	-- la barre de camelot, a droite de la liste
	local barre = ForeverUI.CreateScrollBar("ForeverUITrainerScrollBar", f, liste)
	barre:ClearAllPoints()
	barre:SetPoint("TOPLEFT", liste, "TOPRIGHT", N.barre[1], N.barre[2])
	barre:SetPoint("BOTTOMLEFT", liste, "BOTTOMRIGHT", N.barre[1], N.barre[2])
	barre.surDefilement = function(nouveau)
		habit.decalage = nouveau
		T.Maj()
	end
	habit.barre = barre
	liste:EnableMouseWheel(true)
	liste:SetScript("OnMouseWheel", function(_, sens)
		habit.decalage = math.max(0, math.min((habit.decalage or 0) - sens, habit.maxi or 0))
		T.Maj()
	end)
	-- le rang (maitre de metier)
	local R = N.rang
	local rang = CreateFrame("StatusBar", "ForeverUITrainerRankBar", f)
	rang:SetWidth(R[3])
	rang:SetHeight(R[4])
	rang:SetPoint("TOPLEFT", f, "TOPLEFT", R[1], R[2])
	rang:SetStatusBarTexture(ART.barre)
	rang:SetStatusBarColor(0, 0, 1, 0.5)
	local fondRang = rang:CreateTexture(nil, "BACKGROUND")
	fondRang:SetAllPoints(rang)
	fondRang:SetTexture(0, 0, 0.75, 0.5)
	local rg = morceau(rang, "ARTWORK", ART.guilde, COORDS.rangG)
	rg:SetWidth(R.bord)
	rg:SetPoint("TOPLEFT", rang, "TOPLEFT", -2, 0)
	rg:SetPoint("BOTTOMLEFT", rang, "BOTTOMLEFT", -2, 0)
	local rd = morceau(rang, "ARTWORK", ART.guilde, COORDS.rangD)
	rd:SetWidth(R.bord)
	rd:SetPoint("TOPRIGHT", rang, "TOPRIGHT", 2, 0)
	rd:SetPoint("BOTTOMRIGHT", rang, "BOTTOMRIGHT", 2, 0)
	local rm = morceau(rang, "ARTWORK", ART.guilde, COORDS.rangM)
	rm:SetPoint("TOPLEFT", rg, "TOPRIGHT", 0, 0)
	rm:SetPoint("BOTTOMRIGHT", rd, "BOTTOMLEFT", 0, 0)
	rang.texte = rang:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	rang.texte:SetPoint("CENTER", rang, "CENTER", 0, 0)
	rang:Hide()
	habit.rang = rang
	-- le filtre
	local Fi = N.filtre
	local dd = ClassTrainerFrameFilterDropDown
	Gb.MenuFiltre(dd, Fi[3])
	poser(dd, "TOPRIGHT", f, "TOPRIGHT", Fi[1], Fi[2])
	-- Former, l'argent
	local Fo = N.former
	local b = ClassTrainerTrainButton
	b:SetWidth(Fo[1])
	b:SetHeight(Fo[2])
	poser(b, "BOTTOMRIGHT", f, "BOTTOMRIGHT", Fo[3], Fo[4])
	Gb.BoutonPanneau(b)
	local A = N.argent
	local cadreArgent = f:CreateTexture(nil, "ARTWORK")
	cadreArgent:SetTexture(ART.argent)
	cadreArgent:SetWidth(A[1])
	cadreArgent:SetHeight(A[2])
	cadreArgent:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", A[3], A[4])
	habit.cadreArgent = cadreArgent
	poser(ClassTrainerMoneyFrame, "RIGHT", cadreArgent, "RIGHT", A.bourse[1], A.bourse[2])
	Gb.Croix(ClassTrainerFrameCloseButton, f)
	ClassTrainerFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	hooksecurefunc("ClassTrainerFrame_Update", T.Maj)
end

T.Habiller()

local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:SetScript("OnEvent", function(_, _, nom)
	if nom == "Blizzard_TrainerUI" then
		T.Habiller()
	end
end)
