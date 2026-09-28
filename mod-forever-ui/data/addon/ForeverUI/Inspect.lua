-- ForeverUI : l'inspection d'un joueur (InspectFrame), a la DA de camelot
-- (demande de l'utilisateur, 2026-09-28 : « fait le reste des fenetres
-- secondaires », etape 2 ; decision du 2026-09-28 : le bouton Talents de
-- camelot, qui ouvre la fenetre des talents sur l'inspecte, et le JcJ en
-- onglet lateral).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (Blizzard_InspectUI de 3.3.5, charge a
-- la demande) :
--   InspectFrame 384 x 512, HitRectInsets (0, 30, 0, 45) ; panneau "left"
--     (UIPanelWindows, pushable 0) ; InspectFramePortrait 60 x 60 a (7, -6)
--     (SetPortraitTexture a l'ouverture, au changement d'unite, a
--     UNIT_PORTRAIT_UPDATE) ; InspectNameFrame / InspectNameText (le nom) ;
--     trois onglets du bas InspectFrameTab1..3 (personnage, JcJ, talents),
--     InspectSwitchTabs(id) montre INSPECTFRAME_SUBFRAMES[id] ;
--   InspectPaperDollFrame : art UI-Character-CharacterTab-* (quatre textures
--     sans nom), InspectLevelText (PLAYER_LEVEL) sous le nom ;
--     InspectModelFrame 233 x 300 a (65, -78) et ses deux fleches 35 x 35 ;
--     emplacements ItemButtonTemplate 37 x 37 (UI-Quickslot2 64 x 64 a
--     CENTER (0, -1)) : colonne gauche a (21, -74), droite a (305, -74),
--     ecart 4 ; armes a BOTTOMLEFT (122, 127), ecart 5 ;
--   InspectPVPFrame : honneur (GetInspectHonorData : aujourd'hui, hier, a
--     vie) et trois equipes d'arene (GetInspectArenaTeamData, triees 2, 3,
--     5) ; RequestInspectHonorData a l'ouverture, INSPECT_HONOR_UPDATE ;
--   InspectTalentFrame : l'arbre de talents de 3.3.5 (argument inspect).
--
-- RELEVE -- CAMELOT (blizzard_inspectui/camelot : blizzard_inspectui.xml,
-- .lua, _overrides.lua, inspectpaperdollframe.xml ; mainline/
-- inspectpaperdollframe.lua pour le bouton des talents) :
--   InspectFrame : ButtonFrameTemplate (338 x 424, portrait de l'unite,
--     titre GetUnitName en GameFontHighlight) ; encart (4, -60) a (-6, 4)
--     (ButtonFrameTemplate_HideButtonBar a l'ouverture de la page) ;
--     onglets du bas caches ; onglets LATERAUX (LargeSideTabButtonTemplate,
--     ModeTabs 64 x 384 a TOPLEFT du TOPRIGHT, y -30) : personnage (le
--     portrait de l'unite, rogne a 0,03125) et guilde ;
--   la page du personnage : InspectLevelText a TOP (0, -27), 220 de large,
--     GameFontNormalSmall ; bouton InspectTalents (UIPanelButtonTemplate
--     102 x 20 a TOP (0, -39), INSPECT_TALENTS_BUTTON) ; InspectModelFrame
--     231 x 320 a (52, -66) (ModelWithControlsTemplate : controles a TOP
--     (0, -2)) ; fond de la race desature (SetPaperDollBackground) :
--     BackgroundTopLeft 212 x 245 (u 0,171875 / 1, v 0,0392 / 1), TopRight
--     19 x 245 (u 0 / 0,296875), BotLeft 212 x 128, BotRight 19 x 128 ;
--     BackgroundOverlay noir du TopLeft au BotRight (0, 52) ; cadre
--     Char-Paperdoll-* (coins 7 x 7 a (46, -4), (-47, -4), (46, 31),
--     (-47, 31) de l'encart, filets de 5 entre eux, un second filet bas a
--     27 du bas de l'encart) ; emplacements 37 x 37 (UI-Quickslot2 garde,
--     UI-Character-Info-GearSlot a sa taille derriere) : colonne gauche a
--     TOPLEFT (4, -2) de l'encart, droite a TOPRIGHT (-4, -2), ecart 4 ;
--     armes a BOTTOMLEFT (116, 16), ecart 5.
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee » : les cadres, les
-- emplacements, le modele et la logique du client restent.
--   * Les onglets lateraux : personnage et JcJ. La page JcJ n'existe pas
--     chez camelot (son InspectPVPFrame n'y est pas accessible) : c'est celle
--     de 3.3.5, refaite ici avec l'art deja valide de l'onglet JcJ de la
--     feuille (cartes d'equipes, separateur) ; le cadre du client reste
--     montre (sa demande de donnees, ses evenements), a alpha 0 et sans
--     souris. L'icone du JcJ suit la faction de l'inspecte, comme celle de la
--     feuille. Pas de page de guilde : 3.3.5 n'a pas les donnees
--     (GetInspectGuildInfo).
--   * Les talents : le bouton de camelot ouvre la fenetre des talents
--     (Talents.lua, T.inspecter) sur l'inspecte ; l'onglet des talents de
--     3.3.5 n'est plus accessible. Actif des le niveau 10, comme cet onglet
--     (InspectFrame_UpdateTalentTab) ; desactive, son survol dit UNAVAILABLE.
--   * Les controles du modele n'existent pas en 3.3.5 : les deux fleches
--     prennent leur place, centrees a TOP (0, -2) du modele, a 4 l'une de
--     l'autre ; le modele tourne aussi a la souris, comme la feuille.
--   * ECART : les deux morceaux du bas du fond de la race sont rognes au bas
--     de l'encart (109 des 128) : poses entiers, ils sortiraient de la
--     fenetre ; le voile noir garde sa place (76 au-dessus de leur bas
--     d'origine).
--   * ECART (retour du 2026-09-28, « un contour gris en trop en bas de la
--     fenetre ») : le second filet bas de camelot (BorderBottom2, sur toute
--     la largeur de l'encart, a 27 de son bas) n'est pas pose ; il doublait
--     le filet du bas du cadre, 3 px plus haut. Et les emplacements passent
--     au-dessus du cadre, comme chez camelot (frameLevel 100) : le filet du
--     bas ne traverse plus les armes.
--   * Portrait (retour du 2026-09-28, « le portrait depasse du cercle ») :
--     celui de la feuille, VALIDE (CharacterFrame.lua) -- 48 de cote, centre
--     sur le trou de l'anneau (38 ; -38,5 du coin, pose a (-13, 16)). En 60
--     a (-5, 7), le bord du disque tombait a 30 du centre, au-dela du metal
--     opaque (26 a 29). Le nom passe dans la barre de titre (InspectNameFrame
--     s'eteint).
--   * Pas de logo de faction quand le modele ne peut pas s'afficher :
--     3.3.5 ne le dit pas (SetUnit ne rend rien).
--   * Le rang JcJ de l'inspecte (retours du 2026-09-28), en tete de la page
--     JcJ : le nom du rang et le trait de la feuille, puis l'embleme de SA
--     faction (lion / Horde) -- a 50 % sous l'insigne de son rang s'il en a
--     un ; plein, sous « Civilian », s'il n'en a pas. Ses
--     titres ne se lisent pas (IsTitleKnown ne parle que du joueur) : le rang
--     se deduit de ses victoires honorables a vie, aux seuils de la feuille
--     (PvPTab.lua, ForeverUI.PvPRangs) -- c'est la regle du module du serveur.
--   * Deplacable par la barre du titre (retour du 2026-09-28) : voir « le
--     deplacement », plus bas.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local I = {}
ForeverUI.Inspection = I

local SEP = string.char(92)
local ONGLETS = "Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP
local PARTS = "Interface" .. SEP .. "ForeverUI" .. SEP .. "characterframe" .. SEP .. "char-paperdoll-"
local PVP = "Interface" .. SEP .. "PVPFrame" .. SEP

local N = {
	fenetre = { 338, 424 },
	-- 48, centre sur le trou de l'anneau : (-13 + 38 - 24, 16 - 38,5 + 24)
	portrait = { cote = 48, x = 1, y = 1.5 },
	encart = { 4, -60, -6, 4 },
	onglets = { x = 1, y = -30, l = 64, h = 384, cote = 55, ecart = -2, icone = 50, iconeX = -3, rognage = 0.03125 },
	niveau = { y = -27, l = 220 },
	talents = { l = 102, h = 20, y = -39, niveauMin = 10 },
	modele = { x = 52, y = -66, l = 231, h = 320, flechesY = -2, flechesEcart = 4 },
	fond = { l = 212, h = 245, droite = 19, bas = 128, voile = 52,
		uG = { 0.171875, 1 }, uD = { 0, 0.296875 }, vHaut = 0.0392156862745098 },
	bords = { coin = 7, filet = 5, x = 46, xd = -47, y = -4, yb = 31 },
	emplacement = 37, ecart = 4, gauche = { 4, -2 }, droite = { -4, -2 },
	armes = { 116, 16 }, armesEcart = 5,
}

-- Char-Paperdoll-* (camelot/characterframe.xml) : fichier, u1, u2, v1, v2
local PIECES = {
	coinHG = { "parts", 0.40625, 0.43359375, 0.8046875, 0.859375 },
	coinHD = { "parts", 0.40625, 0.43359375, 0.734375, 0.7890625 },
	coinBG = { "parts", 0.40625, 0.43359375, 0.6640625, 0.71875 },
	coinBD = { "parts", 0.40625, 0.43359375, 0.59375, 0.6484375 },
	gauche = { "vertical", 0.0625, 0.375, 0, 1 },
	droite = { "vertical", 0.5, 0.8125, 0, 1 },
	haut = { "horizontal", 0, 1, 0.5, 0.8125 },
	bas = { "horizontal", 0, 1, 0.0625, 0.375 },
}

local COLONNE_GAUCHE = { "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist" }
local COLONNE_DROITE = { "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1" }
local ARMES = { "MainHand", "SecondaryHand", "Ranged" }

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- ------------------------------------------------------------ les onglets lateraux
-- LargeSideTabButtonTemplate, comme ceux de la feuille : fond
-- common-sidetab, icone 50 a (-3, 0) rognee, common-sidetab-selected pour
-- l'onglet ouvert, common-sidetab-hover au survol
local function creerOnglet(barre, id, infobulle)
	local O = N.onglets
	local b = CreateFrame("Button", "ForeverUIInspectTab" .. id, barre)
	b:SetWidth(O.cote)
	b:SetHeight(O.cote)
	b:SetID(id)
	local fond = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "common-sidetab", true)
	fond:SetAllPoints(b)
	local icone = b:CreateTexture(nil, "ARTWORK")
	icone:SetWidth(O.icone)
	icone:SetHeight(O.icone)
	icone:SetPoint("CENTER", b, "CENTER", O.iconeX, 0)
	icone:SetTexCoord(O.rognage, 1 - O.rognage, O.rognage, 1 - O.rognage)
	local choisi = b:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(choisi, "common-sidetab-selected", true)
	choisi:SetAllPoints(b)
	choisi:Hide()
	local survol = b:CreateTexture(nil, "HIGHLIGHT")
	ForeverUI.SetAtlas(survol, "common-sidetab-hover", true)
	survol:SetAllPoints(b)
	b.icone, b.choisi = icone, choisi
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(infobulle, 1.0, 1.0, 1.0)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self)
		PlaySound("igCharacterInfoTab")
		InspectSwitchTabs(self:GetID())
	end)
	return b
end

function I.MajOnglets()
	local choisi = PanelTemplates_GetSelectedTab(InspectFrame)
	for id, b in ipairs(I.onglets or {}) do
		Gb.Montrer(b.choisi, id == choisi)
	end
end

-- ------------------------------------------------------------ la page du personnage
-- DressUpTexturePath de 3.3.5, pour une autre unite : le meme detour pour
-- les fonds qui manquent (gnome, troll)
local function cheminFond(unite)
	local _, fichier = UnitRace(unite)
	local haut = string.upper(fichier or "")
	if haut == "GNOME" then
		fichier = "Dwarf"
	elseif haut == "TROLL" then
		fichier = "Orc"
	end
	return "Interface" .. SEP .. "DressUpFrame" .. SEP .. "DressUpBackground-" .. (fichier or "Orc")
end

local function morceau(parent, calque, cle)
	local d = PIECES[cle]
	local t = parent:CreateTexture(nil, calque)
	t:SetTexture(PARTS .. d[1])
	t:SetTexCoord(d[2], d[3], d[4], d[5])
	return t
end

local function habillerEmplacement(nom)
	local b = _G["Inspect" .. nom .. "Slot"]
	if not b or b.foreverCadre then return b end
	b:SetWidth(N.emplacement)
	b:SetHeight(N.emplacement)
	local cadre = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(cadre, "ui-character-info-gearslot")
	cadre:SetPoint("CENTER", b, "CENTER", 0, 0)
	b.foreverCadre = cadre
	return b
end

local function habillerPersonnage(encart)
	local p = InspectPaperDollFrame
	for _, r in ipairs({ p:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then r:SetAlpha(0) end
	end
	poser(InspectLevelText, "TOP", p, "TOP", 0, N.niveau.y)
	InspectLevelText:SetWidth(N.niveau.l)
	-- le bouton des talents
	local TB = N.talents
	local b = ForeverUI.CreatePanelButton(p, TALENTS, TB.l, TB.h, "ForeverUIInspectTalentsButton", "GameFontNormal")
	b:SetPoint("TOP", p, "TOP", 0, TB.y)
	b:SetMotionScriptsWhileDisabled(true)
	b:SetScript("OnClick", function()
		PlaySound("igCharacterInfoTab")
		if ForeverUI.Talents and InspectFrame.unit then ForeverUI.Talents.inspecter(InspectFrame.unit) end
	end)
	b:SetScript("OnEnter", function(self)
		if Gb.Vrai(self:IsEnabled()) then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(UNAVAILABLE, 1.0, 0.125, 0.125)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	I.talents = b
	-- le modele
	local M = N.modele
	local modele = InspectModelFrame
	poser(modele, "TOPLEFT", p, "TOPLEFT", M.x, M.y)
	modele:SetWidth(M.l)
	modele:SetHeight(M.h)
	local gauche, droite = InspectModelRotateLeftButton, InspectModelRotateRightButton
	local demi = gauche:GetWidth() / 2 + M.flechesEcart / 2
	poser(gauche, "TOP", modele, "TOP", -demi, M.flechesY)
	poser(droite, "TOP", modele, "TOP", demi, M.flechesY)
	ForeverUI.TournerALaSouris(modele)
	-- le fond de la race, sous le modele (regions de la page) ; le voile
	local F = N.fond
	local fond = {}
	local function piece(u, v1, v2, l, h)
		local t = p:CreateTexture(nil, "BACKGROUND")
		t:SetTexCoord(u[1], u[2], v1, v2)
		t:SetWidth(l)
		t:SetHeight(h)
		t:SetDesaturated(true)
		fond[#fond + 1] = t
		return t
	end
	-- le bas rogne au bas de l'encart
	local basVisible = (N.fenetre[2] - N.encart[4]) - (-M.y + F.h)
	local hg = piece(F.uG, F.vHaut, 1, F.l, F.h)
	hg:SetPoint("TOPLEFT", modele, "TOPLEFT", 0, 0)
	local hd = piece(F.uD, F.vHaut, 1, F.droite, F.h)
	hd:SetPoint("TOPLEFT", hg, "TOPRIGHT", 0, 0)
	local bg = piece(F.uG, 0, basVisible / F.bas, F.l, basVisible)
	bg:SetPoint("TOPLEFT", hg, "BOTTOMLEFT", 0, 0)
	local bd = piece(F.uD, 0, basVisible / F.bas, F.droite, basVisible)
	bd:SetPoint("TOPLEFT", hg, "BOTTOMRIGHT", 0, 0)
	local voile = p:CreateTexture(nil, "BORDER")
	voile:SetTexture(0, 0, 0, 1)
	voile:SetPoint("TOPLEFT", hg, "TOPLEFT", 0, 0)
	voile:SetPoint("BOTTOMRIGHT", hd, "BOTTOMRIGHT", 0, -(F.bas - F.voile))
	I.fond, I.voile = fond, voile
	-- le cadre Char-Paperdoll, au-dessus du modele
	local B = N.bords
	local cadre = CreateFrame("Frame", nil, p)
	cadre:SetAllPoints(encart)
	cadre:SetFrameLevel(modele:GetFrameLevel() + 1)
	local c = {}
	for _, d in ipairs({ { "coinHG", "TOPLEFT", B.x, B.y }, { "coinHD", "TOPRIGHT", B.xd, B.y },
		{ "coinBG", "BOTTOMLEFT", B.x, B.yb }, { "coinBD", "BOTTOMRIGHT", B.xd, B.yb } }) do
		local t = morceau(cadre, "OVERLAY", d[1])
		t:SetWidth(B.coin)
		t:SetHeight(B.coin)
		t:SetPoint(d[2], encart, d[2], d[3], d[4])
		c[d[1]] = t
	end
	local function filet(cle, a1, r1, p1, x1, y1, a2, r2, p2, x2, y2)
		local t = morceau(cadre, "OVERLAY", cle)
		t:SetPoint(a1, r1, p1, x1, y1)
		t:SetPoint(a2, r2, p2, x2, y2)
		return t
	end
	local g = filet("gauche", "TOPLEFT", c.coinHG, "BOTTOMLEFT", -1, 0, "BOTTOMLEFT", c.coinBG, "TOPLEFT", -1, 0)
	local d = filet("droite", "TOPRIGHT", c.coinHD, "BOTTOMRIGHT", 1, 0, "BOTTOMRIGHT", c.coinBD, "TOPRIGHT", 1, 0)
	local h = filet("haut", "TOPLEFT", c.coinHG, "TOPRIGHT", 0, 1, "TOPRIGHT", c.coinHD, "TOPLEFT", 0, 1)
	local bas = filet("bas", "BOTTOMLEFT", c.coinBG, "BOTTOMRIGHT", 0, -1, "BOTTOMRIGHT", c.coinBD, "BOTTOMLEFT", 0, -1)
	g:SetWidth(B.filet)
	d:SetWidth(B.filet)
	h:SetHeight(B.filet)
	bas:SetHeight(B.filet)
	c.gauche, c.droite, c.haut, c.bas = g, d, h, bas
	I.cadre = c
	-- les emplacements, au-dessus du cadre (camelot : frameLevel 100)
	local function habillerAuDessus(nom)
		local s = habillerEmplacement(nom)
		s:SetFrameLevel(cadre:GetFrameLevel() + 1)
		return s
	end
	local precedent
	for i, nom in ipairs(COLONNE_GAUCHE) do
		local s = habillerAuDessus(nom)
		if i == 1 then
			poser(s, "TOPLEFT", encart, "TOPLEFT", N.gauche[1], N.gauche[2])
		else
			poser(s, "TOPLEFT", precedent, "BOTTOMLEFT", 0, -N.ecart)
		end
		precedent = s
	end
	for i, nom in ipairs(COLONNE_DROITE) do
		local s = habillerAuDessus(nom)
		if i == 1 then
			poser(s, "TOPRIGHT", encart, "TOPRIGHT", N.droite[1], N.droite[2])
		else
			poser(s, "TOPLEFT", precedent, "BOTTOMLEFT", 0, -N.ecart)
		end
		precedent = s
	end
	for i, nom in ipairs(ARMES) do
		local s = habillerAuDessus(nom)
		if i == 1 then
			poser(s, "BOTTOMLEFT", p, "BOTTOMLEFT", N.armes[1], N.armes[2])
		else
			poser(s, "TOPLEFT", precedent, "TOPRIGHT", N.armesEcart, 0)
		end
		precedent = s
	end
end

-- ------------------------------------------------------------ la page JcJ
-- en tete, le rang (retours du 2026-09-28) : le nom du rang et le trait
-- ui-character-info-honor-levelbg de la feuille (PvPTab.lua, valide : nom en
-- GameFontHighlightLarge a -12, trait pose par son BAS a 10 sous celui du
-- nom) ; dessous, l'embleme de la faction de l'inspecte -- a 50 % sous
-- l'insigne de son rang s'il en a un, plein sinon (« Civilian ») -- a la
-- taille des insignes de la feuille ramenee de 72 x 84 a 36 x 42 ; sous la
-- tete, l'honneur en tableau
-- (colonnes aujourd'hui / hier / a vie, rangees victoires honorables /
-- honneur, comme InspectPVPHonor), le separateur de la feuille, puis les
-- trois equipes en cartes jointives, comme l'onglet JcJ de la feuille
-- (PvPArena.lua, valide) ramene a la largeur de l'encart. Les hauteurs
-- ci-dessous comptent depuis le bas de la tete.
local J = {
	tete = { h = 90, nomY = -12, ligneY = -10, emblemeEcart = -4, badgeL = 36, badgeH = 42, alphaSousRang = 0.5 },
	haut = -12, etiquetteX = 14, colonnes = { 150, 215, 280 }, rangees = { -30, -48 },
	separateur = -64, cartesY = -74, carteX = 8, carteH = 52,
	texteX = 50, nomY = -7, nomL = 160, coteX = -14, coteY = -8, typeY = -30,
	etiquettesY = -24, valeurEcart = -2, cartesColonnes = { 145, 209, 273 },
	-- l'etendard ramene de 90 a 48 de haut (PvPArena.lua)
	echelle = 48 / 90,
}
local TAILLES = { 2, 3, 5 }

local function texte(parent, gabarit, justif)
	local fs = parent:CreateFontString(nil, "ARTWORK", gabarit)
	if justif then fs:SetJustifyH(justif) end
	return fs
end

local function colonne(parent, x, y, etiquette)
	local e = texte(parent, "GameFontDisableSmall", "CENTER")
	e:SetPoint("TOP", parent, "TOPLEFT", x, y)
	e:SetText(etiquette)
	local v = texte(parent, "GameFontHighlightSmall", "CENTER")
	v:SetPoint("TOP", e, "BOTTOM", 0, J.valeurEcart)
	return v
end

local function creerCarte(page, rang, largeur)
	local c = CreateFrame("Frame", "ForeverUIInspectArenaTeam" .. rang, page)
	c:SetWidth(largeur)
	c:SetHeight(J.carteH)
	c.taille = TAILLES[rang]
	c.plaque = ForeverUI.CreateNineSlice(c, "common-button-list-collapseexpand", 12, { 0, 0, 0, 0 }, "BACKGROUND") or {}
	local E = J.echelle
	local etendard = CreateFrame("Frame", nil, c)
	etendard:SetAllPoints(c)
	c.etendard = etendard
	local hampe = etendard:CreateTexture(nil, "BACKGROUND")
	hampe:SetTexture(PVP .. "UI-Character-PVP-Elements")
	hampe:SetTexCoord(0, 0.099609375, 0.91015625, 0.935546875)
	hampe:SetWidth(50 * E)
	hampe:SetHeight(13 * E)
	hampe:SetPoint("TOPLEFT", c, "TOPLEFT", 8, -2)
	local banniere = etendard:CreateTexture(nil, "BORDER")
	banniere:SetWidth(45 * E)
	banniere:SetHeight(90 * E)
	banniere:SetPoint("TOP", hampe, "TOP", 5 * E, -2 * E)
	local bord = etendard:CreateTexture(nil, "ARTWORK")
	bord:SetWidth(45 * E)
	bord:SetHeight(90 * E)
	bord:SetPoint("CENTER", banniere, "CENTER", 0, 0)
	local embleme = etendard:CreateTexture(nil, "OVERLAY")
	embleme:SetWidth(24 * E)
	embleme:SetHeight(24 * E)
	embleme:SetPoint("CENTER", bord, "CENTER", -5 * E, 17 * E)
	c.banniere, c.bord, c.embleme = banniere, bord, embleme
	local d = CreateFrame("Frame", nil, c)
	d:SetAllPoints(c)
	c.donnees = d
	d.nom = texte(d, "GameFontNormal", "LEFT")
	d.nom:SetWidth(J.nomL)
	d.nom:SetPoint("TOPLEFT", c, "TOPLEFT", J.texteX, J.nomY)
	d.cote = texte(d, "GameFontNormalSmall", "RIGHT")
	d.cote:SetPoint("TOPRIGHT", c, "TOPRIGHT", J.coteX, J.coteY)
	d.coteEtiquette = texte(d, "GameFontDisableSmall", "RIGHT")
	d.coteEtiquette:SetPoint("RIGHT", d.cote, "LEFT", -4, 0)
	d.coteEtiquette:SetText(ARENA_TEAM_RATING)
	d.type = texte(d, "GameFontHighlightSmall", "LEFT")
	d.type:SetPoint("TOPLEFT", c, "TOPLEFT", J.texteX, J.typeY)
	d.type:SetText(ARENA_THIS_SEASON)
	local K = J.cartesColonnes
	d.jeux = colonne(d, K[1], J.etiquettesY, GAMES)
	d.bilan = colonne(d, K[2], J.etiquettesY, WIN_LOSS)
	d.perso = colonne(d, K[3], J.etiquettesY, RATING)
	c.vide = c:CreateFontString(nil, "ARTWORK", "GameFontDisableLarge")
	c.vide:SetPoint("CENTER", c, "CENTER", 0, 0)
	c.vide:Hide()
	return c
end

-- une carte : l'equipe de cette taille, ou l'emplacement vide, comme
-- InspectPVPTeam_Update (la saison, et la cote de l'inspecte)
local function remplirCarte(c, id)
	local d = c.donnees
	if not id then
		c:SetAlpha(0.4)
		c.banniere:SetTexture(PVP .. "PVP-Banner-" .. c.taille)
		c.banniere:SetVertexColor(1, 1, 1)
		c.etendard:SetAlpha(0.1)
		c.bord:Hide()
		c.embleme:Hide()
		d:Hide()
		c.vide:SetText(string.format(PVP_TEAMSIZE, c.taille, c.taille))
		c.vide:Show()
		return
	end
	local nom, taille, cote, joues, victoires, _, perso, fr, fg, fb, embleme, er, eg, eb, bord, br, bgc, bb =
		GetInspectArenaTeamData(id)
	c:SetAlpha(1)
	c.etendard:SetAlpha(1)
	d.nom:SetText(nom)
	d.cote:SetText(cote)
	d.jeux:SetText(joues)
	d.bilan:SetText(tostring(victoires or 0) .. " - " .. tostring((joues or 0) - (victoires or 0)))
	d.perso:SetText(perso)
	c.banniere:SetTexture(PVP .. "PVP-Banner-" .. tostring(taille))
	c.banniere:SetVertexColor(fr or 1, fg or 1, fb or 1)
	c.bord:SetVertexColor(br or 1, bgc or 1, bb or 1)
	c.embleme:SetVertexColor(er or 1, eg or 1, eb or 1)
	if bord and bord ~= -1 then
		c.bord:SetTexture(PVP .. "PVP-Banner-" .. tostring(taille) .. "-Border-" .. tostring(bord))
	end
	if embleme and embleme ~= -1 then
		c.embleme:SetTexture(PVP .. "Icons" .. SEP .. "PVP-Banner-Emblem-" .. tostring(embleme))
	end
	c.bord:Show()
	c.embleme:Show()
	d:Show()
	c.vide:Hide()
end

-- le rang de l'inspecte : ses victoires a vie aux seuils de la feuille.
-- SANS SES DONNEES, LE CAS SANS RANG (retour du 2026-09-28 : la tete restait
-- vide). Le serveur ne les envoie pas pour un inspecte hors de portee
-- d'inspection ou attaquable -- autre faction, duel
-- (MiscHandler.cpp, HandleInspectHonorStatsOpcode) : GetInspectHonorData
-- rend alors des zeros, donc « Civilian » et l'embleme de sa faction.
local function majRang(page, victoires)
	local R = ForeverUI.PvPRangs
	local unite = InspectFrame and InspectFrame.unit
	local faction = unite and UnitFactionGroup(unite)
	if not R or not faction then
		page.badge:Hide()
		page.insigne:Hide()
		page.rang:SetText("")
		return
	end
	-- seuils inconnus (le serveur ne les a pas dits) : le rang ne se deduit
	-- pas, l'embleme reste seul
	local numero = R.parVictoires(victoires)
	page.rang:SetText(numero and R.nom(numero, faction) or "")
	numero = numero or 0
	ForeverUI.SetAtlas(page.badge, string.format(R.badgeFaction, string.lower(faction)), true)
	page.badge:Show()
	-- un rang : son insigne par-dessus l'embleme, a moitie efface
	if numero > 0 and ForeverUI.SetAtlas(page.insigne, string.format(R.badgeRang, numero), true) then
		page.badge:SetAlpha(J.tete.alphaSousRang)
		page.insigne:Show()
	else
		page.badge:SetAlpha(1)
		page.insigne:Hide()
	end
end

function I.MajJcJ()
	local page = I.pageJcJ
	if not page then return end
	local aujK, aujH, hierK, hierH, vieK = GetInspectHonorData()
	majRang(page, vieK)
	local v = page.valeurs
	v[1]:SetText(aujK)
	v[2]:SetText(hierK)
	v[3]:SetText(vieK)
	v[4]:SetText(aujH)
	v[5]:SetText(hierH)
	v[6]:SetText("-")
	local indices = {}
	for i = 1, (MAX_ARENA_TEAMS or 3) do
		local _, taille = GetInspectArenaTeamData(i)
		for rang, t in ipairs(TAILLES) do
			if taille == t then indices[rang] = i end
		end
	end
	for rang, c in ipairs(page.cartes) do
		remplirCarte(c, indices[rang])
	end
end

local function construireJcJ(f, encart)
	-- le cadre du client : montre (sa demande, ses evenements), invisible
	InspectPVPFrame:SetAlpha(0)
	InspectPVPFrame:EnableMouse(false)
	for i = 1, 3 do
		local b = _G["InspectPVPTeam" .. i]
		if b then b:EnableMouse(false) end
	end
	local page = CreateFrame("Frame", "ForeverUIInspectPvP", f)
	page:SetAllPoints(encart)
	page:SetFrameLevel(InspectPVPFrame:GetFrameLevel() + 10)
	page:Hide()
	local largeur = N.fenetre[1] + N.encart[3] - N.encart[1] - 2 * J.carteX
	-- la tete : le nom du rang et son trait, puis l'embleme et l'insigne
	local R = J.tete
	local tete = CreateFrame("Frame", nil, page)
	tete:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	tete:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, 0)
	tete:SetHeight(R.h)
	local nomRang = texte(tete, "GameFontHighlightLarge", "CENTER")
	nomRang:SetPoint("TOP", tete, "TOP", 0, R.nomY)
	local ligne = tete:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(ligne, "ui-character-info-honor-levelbg")
	ligne:SetWidth(largeur)
	ligne:SetPoint("BOTTOM", nomRang, "BOTTOM", 0, R.ligneY)
	local badge = tete:CreateTexture(nil, "ARTWORK")
	badge:SetWidth(R.badgeL)
	badge:SetHeight(R.badgeH)
	badge:SetPoint("TOP", ligne, "BOTTOM", 0, R.emblemeEcart)
	badge:Hide()
	local insigne = tete:CreateTexture(nil, "OVERLAY")
	insigne:SetWidth(R.badgeL)
	insigne:SetHeight(R.badgeH)
	insigne:SetPoint("CENTER", badge, "CENTER", 0, 0)
	insigne:Hide()
	page.tete, page.badge, page.insigne, page.rang, page.ligne = tete, badge, insigne, nomRang, ligne
	-- l'honneur, sous la tete
	for i, t in ipairs({ HONOR_TODAY, HONOR_YESTERDAY, HONOR_LIFETIME }) do
		local e = texte(page, "GameFontDisableSmall", "CENTER")
		e:SetPoint("TOP", tete, "BOTTOMLEFT", J.colonnes[i], J.haut)
		e:SetText(t)
	end
	page.valeurs = {}
	for r, t in ipairs({ KILLS, HONOR }) do
		local e = texte(page, "GameFontDisableSmall", "LEFT")
		e:SetPoint("TOPLEFT", tete, "BOTTOMLEFT", J.etiquetteX, J.rangees[r])
		e:SetText(t)
		for i = 1, 3 do
			local v = texte(page, "GameFontHighlightSmall", "CENTER")
			v:SetPoint("TOP", tete, "BOTTOMLEFT", J.colonnes[i], J.rangees[r])
			page.valeurs[#page.valeurs + 1] = v
		end
	end
	local separateur = page:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(separateur, "ui-character-info-scrollline-long")
	separateur:SetWidth(largeur)
	separateur:SetPoint("TOP", tete, "BOTTOM", 0, J.separateur)
	page.separateur = separateur
	page.cartes = {}
	for rang = 1, #TAILLES do
		local c = creerCarte(page, rang, largeur)
		if rang == 1 then
			c:SetPoint("TOPLEFT", tete, "BOTTOMLEFT", J.carteX, J.cartesY)
		else
			c:SetPoint("TOPLEFT", page.cartes[rang - 1], "BOTTOMLEFT", 0, 0)
		end
		page.cartes[rang] = c
	end
	I.pageJcJ = page
	InspectPVPFrame:HookScript("OnShow", function()
		page:Show()
		I.MajJcJ()
	end)
	InspectPVPFrame:HookScript("OnHide", function() page:Hide() end)
end

-- ------------------------------------------------------------ le deplacement
-- (retour du 2026-09-28 : « je dois pouvoir deplacer la fenetre
-- d'inspection ») Comme les hauts faits (Achievements.lua, valide) : la
-- barre du titre sert de poignee ; la place est retenue dans
-- ForeverUIDB.positions (cle « inspection », haut-centre de la fenetre,
-- comme Superposition.lua) et reposee a l'ouverture et apres le systeme de
-- panneaux -- InspectFrame est un panneau « left » que
-- UpdateUIPanelPositions repose a chaque ouverture ou fermeture d'un
-- panneau. Rien n'y est securise : le deplacement marche aussi en combat.
-- La fenetre des talents de l'inspecte ne suit pas (retour du 2026-09-28 :
-- « bouger la fenetre d'inspection ne doit pas faire bouger la fenetre de
-- talents inspectes »).
local CLE = "inspection"

local function positions()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

function I.Reposer()
	local f = InspectFrame
	local p = positions()[CLE]
	if not f or not p then return end
	f:ClearAllPoints()
	f:SetPoint("TOP", UIParent, "TOP", p.x, p.y)
end

-- le haut-centre d'un cadre, depuis celui d'UIParent (nil tant que le
-- cadre n'est pas place)
local function hautCentre(cadre)
	local cx, ux = cadre:GetCenter(), UIParent:GetCenter()
	local haut, uHaut = cadre:GetTop(), UIParent:GetTop()
	if not cx or not ux or not haut or not uHaut then return end
	return cx - ux, haut - uHaut
end

local function rendreDeplacable(f, poignee)
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	poignee:EnableMouse(true)
	poignee:RegisterForDrag("LeftButton")
	poignee:SetScript("OnDragStart", function()
		f:StartMoving()
	end)
	poignee:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local x, y = hautCentre(f)
		if not x then return end
		f:ClearAllPoints()
		f:SetPoint("TOP", UIParent, "TOP", x, y)
		-- la place est a nous : le client ne la retient pas en plus
		if f.SetUserPlaced then f:SetUserPlaced(false) end
		positions()[CLE] = { x = x, y = y }
	end)
	f:HookScript("OnShow", I.Reposer)
	hooksecurefunc("UpdateUIPanelPositions", function()
		if f:IsShown() then I.Reposer() end
	end)
end

-- ------------------------------------------------------------ l'ouverture
function I.Maj()
	local f = InspectFrame
	local habit = f and f.foreverHabit
	local unite = f and f.unit
	if not habit or not unite then return end
	SetPortraitTexture(habit.portrait, unite)
	local o = I.onglets
	-- UpdateCharacterModeTabPortrait : le portrait, rogne a nouveau
	local R = N.onglets.rognage
	SetPortraitTexture(o[1].icone, unite)
	o[1].icone:SetTexCoord(R, 1 - R, R, 1 - R)
	local faction = UnitFactionGroup(unite) or UnitFactionGroup("player") or "Alliance"
	o[2].icone:SetTexture(ONGLETS .. "Inv_SideTab_Honor_" .. faction .. "_c60")
	local fichier = cheminFond(unite)
	for i, t in ipairs(I.fond) do t:SetTexture(fichier .. i) end
	local niveau = UnitLevel(unite) or 0
	I.talents:Activer(not (niveau > 0 and niveau < N.talents.niveauMin))
	I.MajOnglets()
end

function I.Habiller()
	local f = InspectFrame
	if not f or f.foreverHabit then return end
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	f:SetHitRectInsets(0, 0, 0, 0)
	InspectFramePortrait:SetAlpha(0)
	InspectNameFrame:SetAlpha(0)
	local habit = Gb.FenetrePortrait(f, {
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = InspectNameText:GetText(),
	})
	f.foreverHabit = habit
	rendreDeplacable(f, habit.bandeau)
	habit.titre:SetFontObject(GameFontHighlight)
	hooksecurefunc(InspectNameText, "SetText", function()
		habit.titre:SetText(InspectNameText:GetText() or "")
	end)
	-- l'encart, sans barre de boutons
	local E = N.encart
	local encart = CreateFrame("Frame", "ForeverUIInspectInset", f)
	encart:SetPoint("TOPLEFT", f, "TOPLEFT", E[1], E[2])
	encart:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", E[3], E[4])
	local marbre = f:CreateTexture(nil, "BACKGROUND")
	marbre:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble", true)
	if marbre.SetHorizTile then marbre:SetHorizTile(true) marbre:SetVertTile(true) end
	marbre:SetAllPoints(encart)
	habit.encadre = Gb.NeufTranches(f, "InsetFrameTemplate", encart)
	habit.marbre, habit.encart = marbre, encart
	Gb.Croix(InspectFrameCloseButton, f)
	InspectFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	-- les onglets du bas s'en vont ; les lateraux les remplacent
	for i = 1, 3 do
		local t = _G["InspectFrameTab" .. i]
		t:SetAlpha(0)
		t:EnableMouse(false)
		t:Hide()
	end
	local O = N.onglets
	local barre = CreateFrame("Frame", nil, f)
	barre:SetWidth(O.l)
	barre:SetHeight(O.h)
	barre:SetPoint("TOPLEFT", f, "TOPRIGHT", O.x, O.y)
	barre:SetFrameLevel(f:GetFrameLevel() + 1)
	I.onglets = { creerOnglet(barre, 1, CHARACTER_INFO), creerOnglet(barre, 2, PLAYER_V_PLAYER) }
	I.onglets[1]:SetPoint("TOPLEFT", barre, "TOPLEFT", 0, 0)
	I.onglets[2]:SetPoint("TOPLEFT", I.onglets[1], "BOTTOMLEFT", 0, O.ecart)
	habillerPersonnage(encart)
	construireJcJ(f, encart)
	f:HookScript("OnShow", I.Maj)
	-- la fenetre des talents suit l'inspection : elle se referme avec elle
	f:HookScript("OnHide", function()
		if ForeverUI.Talents and ForeverUI.Talents.inspection and PlayerTalentFrame then
			HideUIPanel(PlayerTalentFrame)
		end
	end)
	hooksecurefunc("InspectSwitchTabs", I.MajOnglets)
	hooksecurefunc("InspectFrame_UnitChanged", I.Maj)
	I.Maj()
	I.Reposer()
end

I.Habiller()

local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:RegisterEvent("UNIT_PORTRAIT_UPDATE")
veille:RegisterEvent("INSPECT_HONOR_UPDATE")
veille:SetScript("OnEvent", function(_, evenement, arg1)
	if evenement == "ADDON_LOADED" then
		if arg1 == "Blizzard_InspectUI" then I.Habiller() end
	elseif evenement == "UNIT_PORTRAIT_UPDATE" then
		if InspectFrame and InspectFrame:IsShown() and arg1 == InspectFrame.unit then I.Maj() end
	elseif I.pageJcJ and I.pageJcJ:IsShown() then
		I.MajJcJ()
	end
end)
