-- ForeverUI -- les cinematiques des ecrans d'accueil : le CinematicsMenu de
-- camelot, sur les films du client 3.3.5.
--
-- RELEVE -- blizzard_gluexml/mainline/cinematicsmenu.xml et .lua ;
-- blizzard_sharedxml : mainline/shareduipaneltemplates.xml
-- (DefaultPanelTemplate), pagedlist.xml / .lua ; blizzard_gluexmlbase/
-- mainline/gluetemplates.xml (GlueCheckButtonTemplate).
--   * fenetre   DefaultPanelTemplate 819 x 559 a CENTER (0, 50) de GlueParent,
--               titre CINEMATICS ; croix UIPanelCloseButton a TOPRIGHT (1, 0) ;
--               encart (6, -40) / (-3, 4) ;
--   * grille    trois colonnes, ecart 17, depuis (19, -19) de l'encart ; le
--               plus recent d'abord (GetMovieIndex) ;
--   * vignette  CinematicsMenuButtonTemplate 246 x 135 : StreamCinematic-
--               <extension>-Large-Up, -Down enfoncee ; bouton de lecture
--               StreamCinematic-PlayButton 43 x 43 a TOPRIGHT (-5, -5),
--               (-3, -7) enfonce ; surbrillance StreamCinematic-Highlight en
--               ADD, tournee d'un quart ; titre GlueFontNormal / Highlight de
--               230 a BOTTOM (0, 11), decale de (2, -2) enfonce ;
--   * sous-titres  case GlueCheckButtonTemplate 26 x 26 (UI-CheckBox-*) a 4 a
--               gauche du libelle CINEMATICS_SHOW_SUBTITLES (GlueFontNormal) a
--               BOTTOM (12, 27) ; CVar movieSubtitle ;
--   * la pagination (PagedListHorizontalControl) se cache quand tout tient
--               sur une page : c'est toujours le cas avec les trois films de
--               3.3.5 ;
--   * Echap ferme (OnKeyDown de camelot) ; voile noir a 0,5 derriere
--               (GlueParent_AddModalFrame, comme le menu du jeu).
--   * sous-titres des films : ceux de camelot (blizzard_subtitles,
--               SubtitlesFrame) -- texte MovieSubtitleFont de 800 x 138 a
--               BOTTOM (0, 0), en bas de l'ecran ; le client 3.3.5 les pose a
--               TOP (0, -630) d'un ecran de 768, soit au milieu de celui de
--               camelot (1200).
-- CHOIX DE L'UTILISATEUR (28/09) : la fenetre a la taille de camelot, meme
-- avec une seule rangee occupee. ECART (comme les autres fenetres, a la
-- demande) : fond noir translucide a la place de la pierre.
-- Les films sont ceux du client (GetClientExpansionLevel, 1 : World of
-- Warcraft, 2 : Burning Crusade, 3 : Wrath of the Lich King) ; la lecture
-- passe par Cinematics_PlayMovie du client, avec son bouton.

local G = ForeverUIGlue
local L = G.L

-- textes absents de 3.3.5 : G.L (ForeverUIGlueTextes)
local TEXTE = { SOUS_TITRES = L.GLUECINEMATICS_SHOW_SUBTITLES }

local FILMS = {
	{ titre = WORLD_OF_WARCRAFT, vignette = "StreamCinematic-Classic-Large" },
	{ titre = BURNING_CRUSADE, vignette = "StreamCinematic-BC-Large" },
	{ titre = WRATH_OF_THE_LICH_KING, vignette = "StreamCinematic-LK-Large" },
}
local M = { largeur = 819, hauteur = 559, y = 50, vignetteL = 246, vignetteH = 135, ecart = 17, colonnes = 3 }

local cadre = CinematicsFrame

-- ------------------------------------------------------------ la fenetre du client

CinematicsBackground:SetAlpha(0)
CinematicsBackground:Hide()
G.Accrocher(CinematicsBackground, "OnShow", function(self)
	self:Hide()
end)

-- le voile de GlueParent_AddModalFrame
local voile = cadre:CreateTexture(nil, "BACKGROUND")
voile:SetTexture(0, 0, 0, 0.5)
voile:SetAllPoints(GlueParent)

-- ------------------------------------------------------------ la fenetre

local F = CreateFrame("Frame", "ForeverUICinematicsMenu", cadre)
F:SetWidth(M.largeur)
F:SetHeight(M.hauteur)
F:SetPoint("CENTER", GlueParent, "CENTER", 0, M.y)
F:EnableMouse(true)
G.Fenetre(F, CINEMATICS, true)
local encart = CreateFrame("Frame", nil, F)
encart:SetPoint("TOPLEFT", F, "TOPLEFT", 6, -40)
encart:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", -3, 4)
G.Encart(F, encart, true)

local function fermer()
	PlaySound("igMainMenuOptionCheckBoxOff")
	cadre:Hide()
end

local croix = CreateFrame("Button", "ForeverUICinematicsMenuCloseButton", F)
croix:SetFrameLevel(F:GetFrameLevel() + 20)
G.CroixFenetre(croix, F)
croix:ClearAllPoints()
croix:SetPoint("TOPRIGHT", F, "TOPRIGHT", 1, 0)
croix:SetScript("OnClick", fermer)

-- OnKeyDown de camelot : Echap ferme, les autres touches passent
cadre:SetScript("OnKeyDown", function(_, touche)
	if touche == "PRINTSCREEN" then
		Screenshot()
	elseif touche == "ESCAPE" then
		fermer()
	end
end)

-- ------------------------------------------------------------ les vignettes

local function vignette(rang, film, id)
	local b = CreateFrame("Button", "ForeverUICinematicsMenuButton" .. rang, F)
	b:SetWidth(M.vignetteL)
	b:SetHeight(M.vignetteH)
	local colonne = (rang - 1) % M.colonnes
	local rangee = math.floor((rang - 1) / M.colonnes)
	b:SetPoint("TOPLEFT", encart, "TOPLEFT", 19 + colonne * (M.vignetteL + M.ecart),
		-(19 + rangee * (M.vignetteH + M.ecart)))
	local haut = film.vignette .. "-Up"
	local bas = film.vignette .. "-Down"
	b:SetNormalTexture(G.atlas[string.lower(haut)][1])
	G.PoserAtlas(b:GetNormalTexture(), haut)
	b:SetPushedTexture(G.atlas[string.lower(bas)][1])
	G.PoserAtlas(b:GetPushedTexture(), bas)
	-- la surbrillance, tournee d'un quart (Rect UL (1, 0), UR (1, 1),
	-- LL (0, 0), LR (0, 1))
	local e = G.atlas["streamcinematic-highlight"]
	b:SetHighlightTexture(e[1])
	local h = b:GetHighlightTexture()
	h:SetTexCoord(e[3], e[4], e[2], e[4], e[3], e[5], e[2], e[5])
	h:SetBlendMode("ADD")
	h:ClearAllPoints()
	h:SetAllPoints(b)
	b.lecture = b:CreateTexture(nil, "OVERLAY")
	G.PoserAtlas(b.lecture, "StreamCinematic-PlayButton")
	b.lecture:SetWidth(43)
	b.lecture:SetHeight(43)
	b.lecture:SetPoint("TOPRIGHT", b, "TOPRIGHT", -5, -5)
	b:SetNormalFontObject(G.Police("GlueFontNormal"))
	b:SetHighlightFontObject(G.Police("GlueFontHighlight"))
	b:SetDisabledFontObject(G.Police("GlueFontDisable"))
	b:SetText(film.titre)
	local texte = b:GetFontString()
	texte:SetWidth(230)
	texte:ClearAllPoints()
	texte:SetPoint("BOTTOM", b, "BOTTOM", 0, 11)
	b:SetPushedTextOffset(2, -2)
	b:SetScript("OnMouseDown", function(self)
		self.lecture:SetPoint("TOPRIGHT", self, "TOPRIGHT", -3, -7)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.lecture:SetPoint("TOPRIGHT", self, "TOPRIGHT", -5, -5)
	end)
	-- Cinematics_PlayMovie du client, avec son bouton (il lit son numero)
	b:SetScript("OnClick", function()
		Cinematics_PlayMovie(_G["CinematicsButton" .. id])
	end)
	return b
end

local vignettes = {}
local nombre = math.min(cadre.numMovies or GetClientExpansionLevel(), #FILMS)
for rang = 1, nombre do
	-- le plus recent d'abord
	local id = nombre - rang + 1
	vignettes[rang] = vignette(rang, FILMS[id], id)
end

-- ------------------------------------------------------------ les sous-titres

local libelle = F:CreateFontString(nil, "ARTWORK")
libelle:SetFontObject(G.Police("GlueFontNormal"))
libelle:SetPoint("BOTTOM", F, "BOTTOM", 12, 27)
libelle:SetText(TEXTE.SOUS_TITRES)
local case = CreateFrame("CheckButton", "ForeverUICinematicsMenuSubtitles", F)
case:SetWidth(26)
case:SetHeight(26)
case:SetPoint("RIGHT", libelle, "LEFT", -4, 0)
case:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
case:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
case:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
case:GetHighlightTexture():SetBlendMode("ADD")
case:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
case:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
case:SetScript("OnShow", function(self)
	self:SetChecked(GetCVarBool("movieSubtitle") and true or false)
end)
case:SetScript("OnClick", function(self)
	local oui = self:GetChecked() and self:GetChecked() ~= 0
	if oui then
		PlaySound("igMainMenuOptionCheckBoxOn")
	else
		PlaySound("igMainMenuOptionCheckBoxOff")
	end
	SetCVar("movieSubtitle", oui and "1" or "0")
end)

G.Accrocher(cadre, "OnShow", function()
	cadre:Raise()
end)

-- ------------------------------------------------------------ les sous-titres des films

MovieFrameSubtitleString:SetFontObject(G.Police("MovieSubtitleFont"))
MovieFrameSubtitleString:ClearAllPoints()
MovieFrameSubtitleString:SetWidth(800)
MovieFrameSubtitleString:SetHeight(138)
MovieFrameSubtitleString:SetPoint("BOTTOM", MovieFrame, "BOTTOM", 0, 0)
