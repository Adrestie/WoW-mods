-- ForeverUI : l'ecran des talents de camelot (docs/TALENTS.md, etape 1 : le
-- cadre, les trois arbres, les noeuds, les fleches, les portes, les points).
--
-- L'OSSATURE RESTE CELLE DE WOTLK. PlayerTalentFrame (Blizzard_TalentUI, charge
-- a la demande) demeure le panneau que la touche N, le micro-bouton et
-- ToggleTalentFrame ouvrent et ferment ; sa croix reste la sienne, rhabillee.
-- Son art, son arbre unique et ses onglets s'effacent ; l'ecran de camelot se
-- pose DANS PlayerTalentFrame, et s'ouvre et se ferme avec lui.
--
-- RELEVE -- blizzard_playerspells (camelot/classtalents, classtalents) et
-- blizzard_sharedtalentui :
--   cadre        PlayerSpellsFrame, page talents 1218 x 708 ; TalentsFrame
--                1212 x 681 a BOTTOM (0, 4) ; titre TALENTS ; portrait :
--                l'icone de la classe (SetTalentPortrait)
--   fond         Talents-Background-c60 (605 x 701, repete en largeur) au bas
--                de la page ; le fond de classe talent-background-<classe>
--                etire de (0, -70) a (0, 36) de ce fond ; Talents-inner-frame-c60
--                autour, a (-2, 4) / (2, -4)
--   separateurs  Talents-divider-left / -right-c60 depuis le centre, en haut
--                (-4) ; Talents-divider-vertical-c60 a (+-95, -60) de leurs centres
--   en-tetes     ClassTalentTreeHeaderTemplate 48 x 48, CENTER du TOPLEFT du
--                cadre a (140 + 400 (i - 1), -100) : icone 36 ronde a (-3, 3),
--                anneau Talents-Main-Ring-c60, nom en GameFontWhiteLarge
--                (contour) a LEFT (54, 2), points dans talents-main-ring-box-c60
--                a (14, -12), Talents-small-divider-c60 a BOTTOM (60, -20)
--   points       ClassTalentCurrencyDisplayTemplate, TOPRIGHT du cadre (-20,
--                -6) : Talents-Square-Box-c60, UNSPENT_POINTS, le nombre vert
--                (gris a zero)
--   noeuds       40 x 40, CENTER a (posX / 10 + 11, -posY / 10 - 7) de la page
--                (basePanOffset 49 / 24, moins panOffset 60 / 31) ; colonnes
--                au pas de 60, arbres a posX 1020 / 5020 / 9080 (TraitNode de
--                camelot) ; carre (sort actif) ou rond (passif) ; icone 36 ;
--                bordure talents-node-<forme>-<etat> a sa taille logique 40
--                (UiTextureAtlasMember), ombre -shadow ; rang actuel seul en
--                SystemFont16_Shadow_ThickOutline a BOTTOM (11, 4), quatre
--                ombres noires. Etats (surcharge camelot) : jaune au maximum,
--                vert achetable ou entame, verrou (locked) derriere une porte,
--                gris sinon ; texte gris / vert / jaune de meme.
--   fleches      un trait de centre a centre, sous les noeuds (6 d'epaisseur,
--                talents-arrow-line-<etat>), et sa pointe talents-arrow-head
--                (14 x 12) contre le noeud d'arrivee ; jaune si le prerequis
--                est rempli, gris sinon, verrou si l'arrivee est derriere une
--                porte
--   portes       TalentFrameGateTemplate 124 x 40 a RIGHT du premier noeud du
--                palier (-12) : talents-gate (84 x 14) et le nombre de points
--                ENCORE a depenser ; une par arbre, la premiere fermee
--   boutons      ApplyButton (UIPanelButtonNoTooltipTemplate) 164 x 22 au BOTTOM
--                du fond (+8), TALENT_FRAME_APPLY_BUTTON_TEXT, lueur jaune
--                newplayertutorial-yellowGlow-redbutton-* (-12 / +12) si des
--                changements attendent ; UndoButton 25 x 25, talents-button-undo
--                (21 x 20), au centre du ResetButton (LEFT a RIGHT d'Apply +14),
--                montre seulement s'il y a des changements, infobulle
--                TALENT_FRAME_DISCARD_CHANGES_BUTTON_TOOLTIP
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * 11 paliers (7 chez camelot) : les arbres occupent toute la hauteur libre
--     (echelle ~0,86, rangees ~48, colonnes ~52), chacun centre entre les
--     separateurs verticaux (demandes du 2026-09-25).
--   * le chevalier de la mort, que camelot n'a pas : chaque arbre prend le fond
--     moderne de sa specialisation (demande du 2026-09-25).
--   * un prerequis en diagonale : camelot trace un trait droit a tout angle,
--     3.3.5 ne sait pas tourner une texture librement ; le trait descend puis
--     tourne, comme chez WotLK.
--   * pas de nuages ni de particules animes (etape ulterieure s'il le faut).
--   * l'infobulle est celle de WotLK (SetTalent) : rangs, rang suivant.
--   * LES SPECIALISATIONS ET LE FAMILIER (etape 2, decisions du 2026-09-25) :
--     des ONGLETS LATERAUX a droite, comme la feuille de personnage (camelot :
--     des onglets de texte en haut) ; l'icone d'une specialisation est celle
--     de son arbre principal (regle de WotLK, TalentFrame_UpdateSpecInfoCache),
--     cuite avec le masque des onglets ; celle du familier, son portrait. La
--     specialisation active porte la coche de camelot (Talents-Checkmark-c60),
--     la seconde verrouillee son cadenas (Talents-lock-c60). Sur une
--     specialisation inactive, "Activate" prend la place d'"Apply" et l'on ne
--     peut que consulter (camelot : "Active" / "Activate" centres en haut).
--     Le familier : la fenetre se reduit a un arbre (celui du chasseur, a
--     paliers de 3 points), sur le fond du chasseur.
--   * LES GLYPHES (etape 3, 2026-09-25) : camelot n'en a pas. Le GlyphFrame
--     de WotLK (Blizzard_GlyphUI) garde son fonctionnement -- alveoles,
--     runes, clics, infobulles, confirmations, etincelles -- et ses montures
--     d'alveole. Son decor est REFAIT sur l'art fourni par l'utilisateur
--     (tools/cuire_glyphes.py) : parchemin, cercle trace, quatre coins dores ;
--     et ses lueurs : a chaque glyphe grave, l'anneau runique, le double
--     anneau du centre, l'anneau d'epines et trois rayons le long des
--     diametres (a la place de UI-GlyphFrame-Glow) ; l'anneau orange en
--     surbrillance d'alveole ; l'etoile pour les etincelles. Le cercle est a
--     l'echelle des alveoles, qui ne bougent pas. Son titre ("Primary
--     Glyphs") passe dans la barre de titre de la fenetre. L'onglet "Glyphs" suit les
--     specialisations ; il montre les glyphes de la specialisation affichee.
--     L'etat reste celui de WotLK : l'onglet du bas GLYPH_TALENT_TAB et
--     PlayerTalentFrame.talentGroup, pilotes par PlayerSpecTab_OnClick et
--     PlayerTalentTab_OnClick -- un glyphe utilise depuis le sac ouvre donc
--     la bonne page.
--   * LA RECHERCHE (etape 4) : TalentsSearch.lua.
--   * LA CONFIRMATION A LA FERMETURE (demande du 2026-09-25 ; camelot ne
--     demande qu'au changement de jeu de talents, CheckConfirmResetAction) :
--     fermer avec des changements en attente rouvre la fenetre et demande,
--     avec le texte de camelot, TALENT_FRAME_CONFIRM_CLOSE, CONTINUE / CANCEL.
--     Continuer annule l'attente et ferme. 3.3.5 n'offre pas d'empecher une
--     fermeture sans souiller HideUIPanel : la fenetre se ferme, puis se
--     rouvre a l'image suivante, telle qu'elle etait.
--   * LES CHANGEMENTS ATTENDENT (etape 2, decision du 2026-09-25) : l'apercu de
--     WotLK (AddPreviewTalentPoints) tient lieu des changements en attente de
--     camelot (C_Traits) ; clic gauche = un point, clic droit = un point en
--     attente retire, Maj-clic = le lien ; Apply (LearnPreviewTalents) et Undo
--     (ResetGroupPreviewTalentPoints) ; pas de menu Reset : WotLK ne
--     desapprend que chez un maitre. Ni confirmation a la fermeture ni barre
--     d'incantation (camelot les a).

ForeverUI = ForeverUI or {}

local T = {}
ForeverUI.Talents = T

local G = {
	largeur = 1218, hauteur = 708, haut = -116,
	pageL = 1212, pageH = 681, pageBas = 4,
	fondL = 605, fondH = 701, fondHaut = -70, fondBas = 36,
	cadreG = -2, cadreH = 4, cadreCoin = 24,
	-- AJUSTE a la demande (2026-09-25) : la barre horizontale remonte de 46
	-- (son trait, a 46 du haut de l'image, tombe sur le haut de l'illustration
	-- -- camelot : -4) ; les separateurs verticaux gardent leur rapport a la
	-- barre (camelot : -60 sous son centre, d'ou le degrade de leur pointe
	-- sous le trait) mais tombent EXACTEMENT sur les transitions des
	-- illustrations, aux tiers de l'image (x 404 et 808 de la page ; camelot :
	-- +-95 du centre des barres, soit 405,5 et 808,5) ; l'en-tete a 5 pixels sous le trait
	-- de la barre (trait aux rangees 46-47 de son image, donc a -4 / -6 ;
	-- anneau visible des rangees 3 a 52 sur 55) -- camelot : -100 ; son petit
	-- separateur a 5 pixels sous l'anneau (trait aux rangees 58-59 sur 64) --
	-- camelot : BOTTOM (60, -20) ; le compteur remonte de 26 (camelot : -6), son cadre
	-- passe a 0,8 et son chiffre de 32 a 24
	separateurHaut = 42, verticalY = -60, transitionsX = { 404, 808 },
	enteteX = 140, enteteEcart = 400, enteteY = -38.5, enteteCote = 48, petitSeparateurY = -8.5,
	pointsX = -20, pointsY = 20, pointsEchelle = 0.8, pointsTaille = 24,
	-- LES NOEUDS OCCUPENT LA PLACE (demande du 2026-09-25), en coordonnees de
	-- la page : les premiers a 10 pixels sous le trait du petit separateur
	-- (-67 du cadre, qui est a -46 de la page), les derniers a 40 du bas (le
	-- bottomPadding de camelot) ; chaque arbre centre dans sa colonne, entre
	-- les separateurs verticaux (x 404 et 808) ; les pas gardent les
	-- proportions de camelot (colonnes 1,5 noeud, rangees 1,4 noeud)
	premierHaut = -123, dernierBas = -641, paliers = 11,
	colonnesX = { 202, 606, 1010 },
	rapportColonne = 1.5, rapportRangee = 1.4,
	noeud = 40, icone = 36, ombreCarre = 39, ombreRond = 38,
	rangX = 11, rangY = 4, rangTaille = 16,
	trait = 6, pointeL = 14, pointeH = 12,
	porteL = 124, porteH = 40, porteIconeL = 84, porteIconeH = 14, porteX = -12,
	fermerX = -2, fermerY = 1, rougeCote = 24,
	portraitX = -5, portraitY = 7, portraitCote = 62,
	titreX1 = 58, titreX2 = -24, titreY = -1, titreH = 20,
	pointsParPalier = 5,
	pointsParPalierFamilier = 3,
	-- la fenetre reduite a un arbre (familier, glyphes) : la premiere colonne
	pageEtroite = 404,
	-- les glyphes : le centre de l'etoile des alveoles dans le GlyphFrame
	-- (Blizzard_GlyphUI.xml : alveoles a 121 de (178, -238.5)), pose au
	-- centre du cadre de l'illustration ; le centre du cercle trace dans son
	-- morceau. Le parchemin couvre ce cadre en entier (sous le cadre
	-- interieur, dont le trait finit 7 px en dedans a gauche et a droite, 5
	-- en haut et en bas : talents-inner-frame-c60, trait de 2 a 9 sur un
	-- cadre deborde de 2 et 4) ; les coins dores s'y appuient.
	glypheCentreX = 178, glypheCentreY = -238.5,
	cercleCentreX = 179.65, cercleCentreY = 202.41,
	coinRetraitX = 7, coinRetraitY = 5,
	-- la pulsation des lueurs (GlyphFramePulse : 0,1 s de montee, 1,5 de
	-- descente) ; l'etincelle agrandie, l'etoile ayant ses rais
	lueurMontee = 0.1, lueurDescente = 1.5, etincelleEchelle = 2.5,
	-- les cercles concentriques (demande du 2026-09-25) : discrets, ils
	-- tournent lentement en sens contraires et s'allument selon les alveoles
	-- garnies ; transparence au plus fort, et vitesse d'apparition par seconde
	cerclesAlpha = 0.35, cerclesFondu = 0.5,
	-- les onglets lateraux (la facture de CharacterFrame.lua, validee)
	ongletsX = 1, ongletsY = -30, ongletCote = 55, ongletEcart = -2, ongletIcone = 50,
	ongletIconeX = -3, ongletRognage = 0.03125, cocheL = 20, cocheH = 15, cadenasL = 10, cadenasH = 14,
	appliquerL = 164, appliquerH = 22, appliquerY = 8, annulerCote = 25, annulerX = 14,
	annulerIconeL = 21, annulerIconeH = 20, lueurL = 25, lueurH = 49, lueurX = 12,
}
-- l'echelle qui fait tenir les paliers : 10 pas + un noeud = la hauteur
G.echelle = (G.premierHaut - G.dernierBas) / (40 * ((G.paliers - 1) * G.rapportRangee + 1))
G.rangeePas = G.rapportRangee * 40 * G.echelle
G.colonnePas = G.rapportColonne * 40 * G.echelle

local METAL = {
	{ cle = "hg", nom = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ cle = "hd", nom = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
	{ cle = "bg", nom = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ cle = "bd", nom = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}

local SEP = string.char(92)
local POLICE = "Fonts" .. SEP .. "FRIZQT__.TTF"
local ROCHE = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock"
local PORTRAIT = "Interface" .. SEP .. "ForeverUI" .. SEP .. "talents" .. SEP .. "portrait_"
local TEXTE = {
	titre = TALENTS or "Talents",
	nonDepenses = "Unspent Talents",                                -- UNSPENT_POINTS
	porte = "Spend %d more points to unlock this row",             -- TALENT_FRAME_GATE_TOOLTIP_FORMAT
	appliquer = "Apply Changes",                                   -- TALENT_FRAME_APPLY_BUTTON_TEXT
	annuler = "Undo Pending Changes",                              -- TALENT_FRAME_DISCARD_CHANGES_BUTTON_TOOLTIP
	activer = "Activate",                                          -- TALENT_SPEC_ACTIVATE
	confirmerFermeture = "You will lose any pending changes if you continue.", -- TALENT_FRAME_CONFIRM_CLOSE
	actif = "Active",                                              -- TALENT_SPEC_ACTIVE
	verrouille = "Locked",                                         -- TALENT_SPEC_LOCKED
	primaire = "Primary",                                          -- DUAL_SPEC_PRIMARY
	secondaire = "Secondary",                                      -- DUAL_SPEC_SECONDARY
	familier = PET or "Pet",
	glyphes = GLYPHS or "Glyphs",                                  -- GLYPHS
	glyphesPrimaires = TALENT_SPEC_PRIMARY_GLYPH or "Primary Glyphs",
	glyphesSecondaires = TALENT_SPEC_SECONDARY_GLYPH or "Secondary Glyphs",
}
-- l'icone d'une specialisation (TalentFrame_UpdateSpecInfoCache) : l'arbre
-- principal, l'hybride, ou celle par defaut ; cuites (tools/cuire_masque.py)
local ICONES_ONGLET = "Interface" .. SEP .. "ForeverUI" .. SEP .. "TabIcons" .. SEP
local ICONE_HYBRIDE = "ability_dualwieldspecialization"
local ICONE_DEFAUT = "ability_marksmanship"
local ICONE_GLYPHES = "inv_inscription_tradeskill01"
-- LES GLYPHES : les deux feuilles cuites (tools/cuire_glyphes.py) et leurs
-- morceaux : feuille, x, y, largeur, hauteur en pixels ; taille affichee
local GLYPHES_DOSSIER = "Interface" .. SEP .. "ForeverUI" .. SEP .. "glyphes" .. SEP
local GLYPHES_RECTS = {
	["parchemin"] = { "glyphes-fond", 0, 0, 539, 793, 404.00, 595.00 },
	["cercle"] = { "glyphes-fond", 543, 0, 481, 550, 360.84, 412.52 },
	["coin-hg"] = { "glyphes-fond", 0, 801, 89, 94, 66.62, 70.25 },
	["coin-hd"] = { "glyphes-fond", 93, 801, 89, 94, 66.62, 70.25 },
	["coin-bg"] = { "glyphes-fond", 186, 801, 88, 90, 65.75, 67.62 },
	["coin-bd"] = { "glyphes-fond", 278, 801, 87, 90, 65.50, 67.62 },
	["anneau-runique"] = { "glyphes-lueurs", 94, 94, 444, 444, 332.72, 332.72 },
	["anneau-epines"] = { "glyphes-lueurs", 692, 56, 256, 256, 191.95, 191.95 },
	["anneau-double"] = { "glyphes-lueurs", 669, 405, 145, 145, 108.57, 108.57 },
	["anneau-orange"] = { "glyphes-lueurs", 851, 372, 145, 145, 108.87, 108.87 },
	["etoile"] = { "glyphes-lueurs", 851, 521, 64, 64, 48.00, 48.00 },
	["rayon-0"] = { "glyphes-lueurs", 0, 636, 92, 376, 68.80, 282.00 },
	["rayon-1"] = { "glyphes-lueurs", 100, 636, 372, 268, 279.00, 201.00 },
	["rayon-2"] = { "glyphes-lueurs", 480, 636, 372, 268, 279.00, 201.00 },
}
local GLYPHES_FEUILLE = 1024

-- une texture sur un morceau des feuilles des glyphes ; sa taille affichee
-- si demande
local function glyphe(t, cle, taille)
	local r = GLYPHES_RECTS[cle]
	t:SetTexture(GLYPHES_DOSSIER .. r[1])
	t:SetTexCoord(r[2] / GLYPHES_FEUILLE, (r[2] + r[4]) / GLYPHES_FEUILLE,
		r[3] / GLYPHES_FEUILLE, (r[3] + r[5]) / GLYPHES_FEUILLE)
	if taille then
		t:SetWidth(r[6])
		t:SetHeight(r[7])
	end
end

-- LES CERCLES CONCENTRIQUES : un anneau par paire d'alveoles, du centre vers
-- le bord, dans l'ordre ou WotLK les ouvre (niveaux 15/15, 30/50, 70/80) ;
-- chaque glyphe grave de la paire allume la moitie de l'anneau. Un tour en
-- tant de secondes, le signe donnant le sens.
local CERCLES = {
	{ cle = "anneau-double", alveoles = { 1, 2 }, tour = 90 },
	{ cle = "anneau-epines", alveoles = { 3, 4 }, tour = -120 },
	{ cle = "anneau-runique", alveoles = { 5, 6 }, tour = 180 },
}

-- tourner une texture d'anneau : ses coordonnees tournent autour du centre
-- de son morceau (la feuille reserve un vide autour de chaque anneau, ou
-- vont les coins du carre tourne : tools/cuire_glyphes.py)
local function tournerAnneau(t, cle, angle)
	local r = GLYPHES_RECTS[cle]
	local cx, cy = (r[2] + r[4] / 2) / GLYPHES_FEUILLE, (r[3] + r[5] / 2) / GLYPHES_FEUILLE
	local h = r[4] / 2 / GLYPHES_FEUILLE
	local c, s = math.cos(angle), math.sin(angle)
	local function p(ox, oy) return cx + ox * c - oy * s, cy + ox * s + oy * c end
	local ulx, uly = p(-h, -h)
	local llx, lly = p(-h, h)
	local urx, ury = p(h, -h)
	local lrx, lry = p(h, h)
	t:SetTexCoord(ulx, uly, llx, lly, urx, ury, lrx, lry)
end

-- les sorts d'activation (TALENT_ACTIVATION_SPELLS, Constants.lua)
local SORTS_ACTIVATION = { 63645, 63644 }
local COULEUR = {
	gris = { 0.5, 0.5, 0.5 },       -- DISABLED_FONT_COLOR
	vert = { 0.1, 1, 0.1 },         -- GREEN_FONT_COLOR
	jaune = { 1, 0.82, 0 },         -- NORMAL_FONT_COLOR
	porte = { 1, 0.64, 0.56 },
}

-- les fonds : un par classe ; le chevalier de la mort, un par arbre
local FOND_DK = { "talents-background-deathknight-blood", "talents-background-deathknight-frost",
	"talents-background-deathknight-unholy" }

local function atlas(t, nom, garder)
	return ForeverUI.SetAtlas(t, nom, garder)
end

-- une texture d'atlas a une taille donnee (les tailles LOGIQUES de
-- UiTextureAtlasMember, que la table d'atlas ne porte pas pour talents.blp)
local function atlasTaille(t, nom, l, h)
	ForeverUI.SetAtlas(t, nom, true)
	t:SetWidth(l)
	t:SetHeight(h or l)
end

local function couleur(fs, c)
	fs:SetTextColor(c[1], c[2], c[3])
end

-- ETOUFFER : image, opacite, visibilite, souris -- le code de WotLK remontre
-- ce qu'on se contente de cacher.
local function etouffer(f)
	if not f then return end
	if f.SetTexture then f:SetTexture(nil) end
	f:SetAlpha(0)
	if f.EnableMouse then f:EnableMouse(false) end
	f:Hide()
end

-- ------------------------------------------------------------ le cadre
local function boutonCroix(livre)
	local fermer = PlayerTalentFrameCloseButton
	if not fermer then return end
	fermer:SetWidth(G.rougeCote)
	fermer:SetHeight(G.rougeCote)
	fermer:SetHitRectInsets(0, 0, 0, 0)
	for _, etat in ipairs({ { "Normal", "redbutton-exit" }, { "Pushed", "redbutton-exit-pressed" },
		{ "Highlight", "redbutton-highlight" } }) do
		local e = ForeverUI.AtlasEntry(etat[2])
		local t = fermer["Get" .. etat[1] .. "Texture"](fermer)
		if not t and e then
			fermer["Set" .. etat[1] .. "Texture"](fermer, e[1])
			t = fermer["Get" .. etat[1] .. "Texture"](fermer)
		end
		if t then
			atlas(t, etat[2], true)
			t:ClearAllPoints()
			t:SetAllPoints(fermer)
		end
	end
	fermer:ClearAllPoints()
	fermer:SetPoint("TOPRIGHT", livre, "TOPRIGHT", G.fermerX, G.fermerY)
end

-- LA CROIX PAR-DESSUS LE LIVRE : sa soeur, pas sa fille ; son niveau se
-- repose a chaque ouverture.
-- LA CROIX AU-DESSUS DE TOUT : du livre et du GlyphFrame, freres d'elle.
-- Blizzard_GlyphUI, a son chargement, la repose juste au-dessus du GlyphFrame
-- (GlyphFrame_OnEvent, ADDON_LOADED) -- donc sous notre livre : elle
-- disparaissait en ouvrant les glyphes (2026-09-25). On la releve apres lui.
local function plusHaut(cadre)
	local n = cadre:GetFrameLevel()
	for _, enfant in ipairs({ cadre:GetChildren() }) do
		local m = plusHaut(enfant)
		if m > n then n = m end
	end
	return n
end

function T.leverCroix()
	local fermer, livre = PlayerTalentFrameCloseButton, T.livre
	if not fermer or not livre then return end
	fermer:SetFrameStrata(livre:GetFrameStrata())
	local haut = plusHaut(livre)
	if GlyphFrame then haut = math.max(haut, plusHaut(GlyphFrame)) end
	fermer:SetFrameLevel(haut + 1)
end

local function construireCadre(livre)
	local roche = livre:CreateTexture(nil, "BACKGROUND")
	roche:SetTexture(ROCHE, true)
	if roche.SetHorizTile then roche:SetHorizTile(true) roche:SetVertTile(true) end
	roche:SetPoint("TOPLEFT", livre, "TOPLEFT", 2, -21)
	roche:SetPoint("BOTTOMRIGHT", livre, "BOTTOMRIGHT", -2, 2)

	local metal = CreateFrame("Frame", nil, livre)
	metal:SetAllPoints(livre)
	metal:SetFrameLevel(livre:GetFrameLevel() + 20)
	local p = {}
	for _, coin in ipairs(METAL) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		atlas(t, coin.nom)
		t:SetPoint(coin.point, metal, coin.point, coin.x, coin.y)
		p[coin.cle] = t
	end
	local function bord(nom, a1, c1, r1, a2, c2, r2)
		local t = metal:CreateTexture(nil, "OVERLAY")
		atlas(t, nom)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
	end
	bord("_ui-frame-metal-edgetop", "TOPLEFT", p.hg, "TOPRIGHT", "TOPRIGHT", p.hd, "TOPLEFT")
	bord("_ui-frame-metal-edgebottom", "BOTTOMLEFT", p.bg, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bd, "BOTTOMLEFT")
	bord("!ui-frame-metal-edgeleft", "TOPLEFT", p.hg, "BOTTOMLEFT", "BOTTOMLEFT", p.bg, "TOPLEFT")
	bord("!ui-frame-metal-edgeright", "TOPRIGHT", p.hd, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bd, "TOPRIGHT")

	-- le portrait : l'icone de la classe, cuite ronde (tools/cuire_masque.py)
	local cadrePortrait = CreateFrame("Frame", nil, livre)
	cadrePortrait:SetAllPoints(livre)
	cadrePortrait:SetFrameLevel(livre:GetFrameLevel() + 19)
	local portrait = cadrePortrait:CreateTexture(nil, "OVERLAY")
	portrait:SetWidth(G.portraitCote)
	portrait:SetHeight(G.portraitCote)
	portrait:SetPoint("TOPLEFT", livre, "TOPLEFT", G.portraitX, G.portraitY)
	local _, classe = UnitClass("player")
	portrait:SetTexture(PORTRAIT .. string.lower(classe or "warrior"))
	livre.portrait = portrait

	local bandeau = CreateFrame("Frame", nil, livre)
	bandeau:SetFrameLevel(livre:GetFrameLevel() + 21)
	bandeau:SetHeight(G.titreH)
	bandeau:SetPoint("TOPLEFT", livre, "TOPLEFT", G.titreX1, G.titreY)
	bandeau:SetPoint("TOPRIGHT", livre, "TOPRIGHT", G.titreX2, G.titreY)
	local titre = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titre:SetPoint("TOP", bandeau, "TOP", 0, -5)
	titre:SetText(TEXTE.titre)
	livre.titre = titre
	livre.bandeau = bandeau

	boutonCroix(livre)
end

-- UIPanelButtonTemplate de camelot : trois morceaux de UI-Panel-Button-*
-- (la meme facture que QuestLog.lua)
local PANNEAU = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Panel-Button-"
function T.boutonPanneau(parent, nom, texte, largeur)
	local b = CreateFrame("Button", nom, parent)
	b:SetWidth(largeur)
	b:SetHeight(G.appliquerH)
	local function morceau(u1, u2)
		local t = b:CreateTexture(nil, "BACKGROUND")
		t:SetTexCoord(u1, u2, 0, 0.6875)
		return t
	end
	local g = morceau(0, 0.09375)
	g:SetWidth(12)
	g:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	g:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	local d = morceau(0.53125, 0.625)
	d:SetWidth(12)
	d:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	d:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	local m = morceau(0.09375, 0.53125)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	b.morceaux = { g, m, d }
	local function etat(suffixe)
		for _, t in ipairs(b.morceaux) do t:SetTexture(PANNEAU .. suffixe) end
	end
	etat("Up")
	local fs = b:CreateFontString(nil, "ARTWORK")
	fs:SetFontObject(GameFontNormal)
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:SetFontString(fs)
	b:SetNormalFontObject(GameFontNormal)
	b:SetHighlightFontObject(GameFontHighlight)
	b:SetDisabledFontObject(GameFontDisable)
	b:SetText(texte)
	b:SetHighlightTexture(PANNEAU .. "Highlight")
	local s = b:GetHighlightTexture()
	if s then
		s:SetTexCoord(0, 0.625, 0, 0.6875)
		s:SetBlendMode("ADD")
	end
	b.actif = true
	b:SetScript("OnMouseDown", function(self) if self.actif then etat("Down") end end)
	b:SetScript("OnMouseUp", function(self) if self.actif then etat("Up") end end)
	function b:Activer(oui)
		self.actif = oui and true or false
		if oui then
			self:Enable()
			etat("Up")
		else
			self:Disable()
			etat("Disabled")
		end
	end
	return b
end

-- la pierre, bout a bout sur la largeur de la page
local function poserPierre(largeur)
	local fond = T.fond
	local e = ForeverUI.AtlasEntry("talents-background-c60")
	local x, n = 0, 0
	while x < largeur do
		n = n + 1
		local t = fond.pierres[n] or fond:CreateTexture(nil, "BACKGROUND")
		fond.pierres[n] = t
		local l = math.min(G.fondL, largeur - x)
		if e then
			t:SetTexture(e[1])
			t:SetTexCoord(e[2], e[2] + (e[3] - e[2]) * l / G.fondL, e[4], e[5])
		end
		t:SetWidth(l)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", fond, "TOPLEFT", x, 0)
		t:SetPoint("BOTTOMLEFT", fond, "BOTTOMLEFT", x, 0)
		t:Show()
		x = x + l
	end
	for i = n + 1, #fond.pierres do fond.pierres[i]:Hide() end
end

-- ------------------------------------------------------------ la page
local function construirePage(livre)
	local page = CreateFrame("Frame", "ForeverUITalentsPage", livre)
	page:SetWidth(G.pageL)
	page:SetHeight(G.pageH)
	page:SetPoint("BOTTOM", livre, "BOTTOM", 0, G.pageBas)
	T.page = page

	-- Talents-Background-c60, repete en largeur (horizTile) : 3.3.5 ne sait
	-- pas repeter une region d'atlas, on la pose bout a bout
	local fond = CreateFrame("Frame", nil, page)
	fond:SetHeight(G.fondH)
	fond:SetPoint("BOTTOMLEFT", page, "BOTTOMLEFT", 0, 0)
	fond:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", 0, 0)
	fond.pierres = {}
	T.fond = fond

	-- le fond de la classe. UN NIVEAU AU-DESSUS DE LA PIERRE : deux cadres
	-- freres de meme niveau n'ont pas d'ordre de dessin garanti, et la pierre,
	-- opaque, passait devant l'illustration d'une session a l'autre (constate
	-- trois fois le 2026-09-25)
	fond:SetFrameLevel(page:GetFrameLevel() + 1)
	local classe = CreateFrame("Frame", nil, page)
	classe:SetFrameLevel(fond:GetFrameLevel() + 1)
	classe:SetPoint("TOPLEFT", fond, "TOPLEFT", 0, G.fondHaut)
	classe:SetPoint("BOTTOMRIGHT", fond, "BOTTOMRIGHT", 0, G.fondBas)
	classe.textures = {}
	T.classe = classe

	-- le cadre interieur, en neuf tranches (ses coins sont ornes)
	local cadre = CreateFrame("Frame", nil, page)
	cadre:SetPoint("TOPLEFT", classe, "TOPLEFT", G.cadreG, G.cadreH)
	cadre:SetPoint("BOTTOMRIGHT", classe, "BOTTOMRIGHT", -G.cadreG, -G.cadreH)
	cadre:SetFrameLevel(page:GetFrameLevel() + 2)
	ForeverUI.CreateNineSlice(cadre, "talents-inner-frame-c60", G.cadreCoin, { 0, 0, 0, 0 }, "OVERLAY")
	T.cadre = cadre

	-- les separateurs
	local gauche = cadre:CreateTexture(nil, "OVERLAY")
	atlas(gauche, "talents-divider-left-c60")
	T.barreGauche = gauche
	gauche:SetPoint("RIGHT", cadre, "CENTER", 0, 0)
	gauche:SetPoint("TOP", cadre, "TOP", 0, G.separateurHaut)
	local droite = cadre:CreateTexture(nil, "OVERLAY")
	atlas(droite, "talents-divider-right-c60")
	T.barreDroite = droite
	droite:SetPoint("LEFT", cadre, "CENTER", 0, 0)
	droite:SetPoint("TOP", cadre, "TOP", 0, G.separateurHaut)
	-- les separateurs verticaux : a -60 sous le centre des barres (camelot),
	-- sur les transitions des illustrations (le cadre commence a -2 de la page)
	local hautVertical = G.separateurHaut - 28 + G.verticalY
	local verticaux = {}
	for i, x in ipairs(G.transitionsX) do
		local v = cadre:CreateTexture(nil, "OVERLAY")
		atlas(v, "talents-divider-vertical-c60")
		v:SetPoint("TOP", cadre, "TOPLEFT", x - G.cadreG, hautVertical)
		verticaux[i] = v
	end
	T.verticaux = verticaux

	-- les points non depenses
	local points = CreateFrame("Frame", nil, cadre)
	points:SetWidth(1)
	points:SetHeight(1)
	points:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", G.pointsX, G.pointsY)
	local boite = points:CreateTexture(nil, "ARTWORK")
	atlas(boite, "talents-square-box-c60")
	local k = G.pointsEchelle
	boite:SetWidth(boite:GetWidth() * k)
	boite:SetHeight(boite:GetHeight() * k)
	boite:SetPoint("RIGHT", points, "RIGHT", 0, 0)
	local libelle = points:CreateFontString(nil, "ARTWORK", "SystemFont_Shadow_Med1")
	libelle:SetJustifyH("RIGHT")
	libelle:SetPoint("RIGHT", boite, "LEFT", 60 * k, 0)
	libelle:SetText(TEXTE.nonDepenses)
	-- la recherche s'appuie sur ce libelle : sa droite, depuis la droite du
	-- cadre
	points.libelle = libelle
	points.droiteLibelle = G.pointsX - boite:GetWidth() + 60 * k
	local nombre = points:CreateFontString(nil, "ARTWORK")
	nombre:SetFont(POLICE, G.pointsTaille)
	nombre:SetShadowOffset(2, -2)
	nombre:SetShadowColor(0, 0, 0, 1)
	nombre:SetPoint("CENTER", boite, "RIGHT", (-4 - 24) * k, 0)
	points.nombre = nombre
	T.points = points

	-- les trois en-tetes
	T.entetes = {}
	for i = 1, 3 do
		local h = CreateFrame("Frame", "ForeverUITalentsHeader" .. i, cadre)
		h:SetWidth(G.enteteCote)
		h:SetHeight(G.enteteCote)
		h:SetPoint("CENTER", cadre, "TOPLEFT", G.enteteX + (i - 1) * G.enteteEcart, G.enteteY)
		h:SetFrameLevel(cadre:GetFrameLevel() + 5)
		local icone = h:CreateTexture(nil, "BORDER")
		icone:SetWidth(36)
		icone:SetHeight(36)
		icone:SetPoint("CENTER", h, "CENTER", -3, 3)
		local anneau = h:CreateTexture(nil, "OVERLAY")
		atlas(anneau, "talents-main-ring-c60")
		anneau:SetPoint("CENTER", icone, "CENTER", 0, 0)
		local nom = h:CreateFontString(nil, "OVERLAY")
		nom:SetFont(POLICE, 16, "OUTLINE")
		nom:SetTextColor(1, 1, 1)
		nom:SetPoint("LEFT", h, "LEFT", 54, 2)
		local caseTexte = h:CreateTexture(nil, "OVERLAY")
		atlas(caseTexte, "talents-main-ring-box-c60")
		caseTexte:SetPoint("CENTER", h, "CENTER", 14, -12)
		local depenses = h:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		depenses:SetPoint("CENTER", caseTexte, "CENTER", 0, 0)
		local trait = h:CreateTexture(nil, "OVERLAY")
		atlas(trait, "talents-small-divider-c60")
		trait:SetPoint("BOTTOM", h, "BOTTOM", 60, G.petitSeparateurY)
		h.icone, h.nom, h.depenses = icone, nom, depenses
		T.entetes[i] = h
	end

	-- APPLY et UNDO, au bas du fond
	local appliquer = T.boutonPanneau(page, "ForeverUITalentsApplyButton", TEXTE.appliquer, G.appliquerL)
	appliquer:SetPoint("BOTTOM", fond, "BOTTOM", 0, G.appliquerY)
	appliquer:SetFrameLevel(cadre:GetFrameLevel() + 6)
	appliquer:SetScript("OnClick", function() T.appliquer() end)
	local lueur = CreateFrame("Frame", nil, appliquer)
	lueur:SetHeight(1)
	lueur:SetPoint("LEFT", appliquer, "LEFT", -G.lueurX, 0)
	lueur:SetPoint("RIGHT", appliquer, "RIGHT", G.lueurX, 0)
	local lg = lueur:CreateTexture(nil, "ARTWORK")
	atlasTaille(lg, "newplayertutorial-yellowglow-redbutton-left", G.lueurL, G.lueurH)
	lg:SetBlendMode("ADD")
	lg:SetPoint("LEFT", lueur, "LEFT", 0, 0)
	local ld = lueur:CreateTexture(nil, "ARTWORK")
	atlasTaille(ld, "newplayertutorial-yellowglow-redbutton-right", G.lueurL, G.lueurH)
	ld:SetBlendMode("ADD")
	ld:SetPoint("RIGHT", lueur, "RIGHT", 0, 0)
	local lm = lueur:CreateTexture(nil, "ARTWORK")
	atlas(lm, "newplayertutorial-yellowglow-redbutton-middle", true)
	lm:SetBlendMode("ADD")
	lm:SetPoint("TOPLEFT", lg, "TOPRIGHT", 0, 0)
	lm:SetPoint("BOTTOMRIGHT", ld, "BOTTOMLEFT", 0, 0)
	lueur:Hide()
	appliquer.lueur = lueur
	T.appliquerBouton = appliquer

	local annuler = CreateFrame("Button", "ForeverUITalentsUndoButton", page)
	annuler:SetWidth(G.annulerCote)
	annuler:SetHeight(G.annulerCote)
	annuler:SetPoint("CENTER", appliquer, "RIGHT", G.annulerX + G.annulerCote / 2, 0)
	annuler:SetFrameLevel(cadre:GetFrameLevel() + 6)
	local icone = annuler:CreateTexture(nil, "ARTWORK")
	atlasTaille(icone, "talents-button-undo", G.annulerIconeL, G.annulerIconeH)
	icone:SetPoint("CENTER", annuler, "CENTER", 0, 0)
	-- useIconAsHighlight : la meme icone, en ADD, au survol
	local survol = annuler:CreateTexture(nil, "HIGHLIGHT")
	atlasTaille(survol, "talents-button-undo", G.annulerIconeL, G.annulerIconeH)
	survol:SetPoint("CENTER", annuler, "CENTER", 0, 0)
	survol:SetBlendMode("ADD")
	annuler:SetScript("OnClick", function() T.annuler() end)
	annuler:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(TEXTE.annuler, 1, 1, 1)
		GameTooltip:Show()
	end)
	annuler:SetScript("OnLeave", function() GameTooltip:Hide() end)
	annuler:Hide()
	T.annulerBouton = annuler

	-- ACTIVATE, a la place d'Apply sur une specialisation inactive
	local activer = T.boutonPanneau(page, "ForeverUITalentsActivateButton", TEXTE.activer, G.appliquerL)
	activer:SetPoint("BOTTOM", fond, "BOTTOM", 0, G.appliquerY)
	activer:SetFrameLevel(cadre:GetFrameLevel() + 6)
	activer:SetScript("OnClick", function() T.activer() end)
	activer:Hide()
	T.activerBouton = activer

	-- l'arbre : noeuds, fleches et portes, a l'echelle
	local arbre = CreateFrame("Frame", "ForeverUITalentsTree", page)
	arbre:SetScale(G.echelle)
	arbre:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
	arbre:SetWidth(G.pageL / G.echelle)
	arbre:SetHeight(G.pageH / G.echelle)
	arbre:SetFrameLevel(cadre:GetFrameLevel() + 3)
	arbre.noeuds, arbre.traits, arbre.pointes, arbre.portes = {}, {}, {}, {}
	T.arbre = arbre
end

-- ------------------------------------------------------------ les noeuds
-- le centre d'un noeud, en coordonnees de l'arbre (sous l'echelle)
local function centre(onglet, palier, colonne)
	local x = G.colonnesX[onglet] + (colonne - 2.5) * G.colonnePas
	-- le familier (fenetre reduite) : l'arbre dans la seule colonne
	local y = G.premierHaut - 20 * G.echelle - (palier - 1) * G.rangeePas
	return x / G.echelle, y / G.echelle
end
T.centre = centre

local function creerNoeud(n)
	local arbre = T.arbre
	local b = CreateFrame("Button", "ForeverUITalentsNode" .. n, arbre)
	b:SetWidth(G.noeud)
	b:SetHeight(G.noeud)
	b:SetFrameLevel(arbre:GetFrameLevel() + 2)
	local ombre = b:CreateTexture(nil, "BACKGROUND")
	ombre:SetPoint("CENTER", b, "CENTER", 0, 0)
	local icone = b:CreateTexture(nil, "BORDER")
	icone:SetWidth(G.icone)
	icone:SetHeight(G.icone)
	icone:SetPoint("CENTER", b, "CENTER", 0, 0)
	local bordure = b:CreateTexture(nil, "ARTWORK")
	bordure:SetPoint("CENTER", b, "CENTER", 0, 0)
	-- le rang : SystemFont16_Shadow_ThickOutline et ses quatre ombres
	local rang = b:CreateFontString(nil, "OVERLAY")
	rang:SetFont(POLICE, G.rangTaille, "THICKOUTLINE")
	rang:SetPoint("BOTTOM", b, "BOTTOM", G.rangX, G.rangY)
	local ombres = {}
	for i, d in ipairs({ { -1, 1 }, { 1, 1 }, { -1, -1 }, { 1, -1 } }) do
		local o = b:CreateFontString(nil, "ARTWORK")
		o:SetFont(POLICE, G.rangTaille, "THICKOUTLINE")
		o:SetTextColor(0, 0, 0)
		o:SetPoint("CENTER", rang, "CENTER", d[1], d[2])
		ombres[i] = o
	end
	b.ombre, b.icone, b.bordure, b.rang, b.ombresRang = ombre, icone, bordure, rang, ombres
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:SetScript("OnEnter", function(self)
		if not self.talent then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		-- le rang en attente compte (l'apercu de WotLK)
		GameTooltip:SetTalent(self.talent.onglet, self.talent.index, false, T.pet, T.groupe, true)
		GameTooltip:Show()
	end)
	b:SetScript("OnClick", function(self, bouton) T.cliquer(self, bouton) end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	-- glisser un sort actif appris vers une barre (TalentButtonSpendMixin:
	-- OnDragStart de camelot ; WotLK n'en a pas)
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnDragStart", function(self) T.prendreSort(self) end)
	return b
end

local function ecrireRang(b, texte, c)
	b.rang:SetText(texte)
	couleur(b.rang, c)
	for _, o in ipairs(b.ombresRang) do o:SetText(texte) end
end

-- l'etat d'un talent (surcharge camelot, blizzard_sharedtalentoverrides) :
-- "maxed" jaune, "selectable" vert (achetable, ou entame), "locked" derriere
-- une porte, "disabled" gris sinon
local function etatDe(t, ouvert, points)
	if t.rang > 0 and t.rang >= t.max then return "maxed" end
	if not ouvert then return "locked" end
	if t.rang > 0 then return "selectable" end
	if t.prerequis and points > 0 then return "selectable" end
	return "disabled"
end
T.etatDe = etatDe

local BORDURE = { maxed = "yellow", selectable = "green", locked = "locked", disabled = "gray" }
local TEXTE_RANG = { maxed = COULEUR.jaune, selectable = COULEUR.vert, locked = COULEUR.gris, disabled = COULEUR.gris }

local function remplirNoeud(b, t, etat)
	b.talent = t
	local forme = t.carre and "square" or "circle"
	atlasTaille(b.ombre, "talents-node-" .. forme .. "-shadow", t.carre and G.ombreCarre or G.ombreRond)
	atlasTaille(b.bordure, "talents-node-" .. forme .. "-" .. BORDURE[etat], G.noeud)
	if t.carre then
		b.icone:SetTexture(t.icone)
		b.icone:SetTexCoord(0, 1, 0, 1)
	else
		SetPortraitToTexture(b.icone, t.icone)
		b.icone:SetTexCoord(0, 1, 0, 1)
	end
	-- DisabledOverlay : noir a 0,7 derriere une porte, 0,25 sinon grise ; 3.3.5
	-- n'a pas de masque pour le rond : l'icone s'assombrit d'autant
	local v = (etat == "locked") and 0.3 or ((etat == "disabled") and 0.75 or 1)
	b.icone:SetVertexColor(v, v, v)
	-- le rang actuel seul ; rien a zero s'il n'est pas achetable
	if t.rang == 0 and etat ~= "selectable" then
		ecrireRang(b, "", TEXTE_RANG[etat])
	else
		ecrireRang(b, tostring(t.rang), TEXTE_RANG[etat])
	end
	local x, y = centre(t.onglet, t.palier, t.colonne)
	b:ClearAllPoints()
	b:SetPoint("CENTER", T.arbre, "TOPLEFT", x, y)
	b:Show()
end

-- ------------------------------------------------------------ les fleches
-- SetClampedTextureRotation a 90 / 270 : la forme a huit arguments
local function tourner(t, nom, degres)
	local e = ForeverUI.AtlasEntry(nom)
	if not e then return end
	t:SetTexture(e[1])
	local u1, u2, v1, v2 = e[2], e[3], e[4], e[5]
	if degres == 90 then
		t:SetTexCoord(u1, v2, u2, v2, u1, v1, u2, v1)
	elseif degres == 270 then
		t:SetTexCoord(u2, v1, u1, v1, u2, v2, u1, v2)
	else
		t:SetTexCoord(u1, u2, v1, v2)
	end
end

local function prendre(liste, n, calque)
	local t = liste[n]
	if not t then
		t = T.arbre:CreateTexture(nil, calque)
		liste[n] = t
	end
	t:Show()
	return t
end

-- un trait droit, horizontal ou vertical, de (x1, y1) a (x2, y2)
local function trait(n, x1, y1, x2, y2, etat)
	local t = prendre(T.arbre.traits, n, "BACKGROUND")
	local nom = "talents-arrow-line-" .. etat
	t:ClearAllPoints()
	if x1 == x2 then
		-- la bande est horizontale dans l'image : tournee pour un trait vertical
		tourner(t, nom, 90)
		t:SetWidth(G.trait)
		t:SetHeight(math.abs(y2 - y1))
		t:SetPoint("TOP", T.arbre, "TOPLEFT", x1, math.max(y1, y2))
	else
		tourner(t, nom, 0)
		t:SetHeight(G.trait)
		t:SetWidth(math.abs(x2 - x1))
		t:SetPoint("LEFT", T.arbre, "TOPLEFT", math.min(x1, x2), y1)
	end
end

-- la pointe, contre le noeud d'arrivee ; elle regarde vers le bas dans
-- l'image
local function pointe(n, x, y, sens, etat)
	local t = prendre(T.arbre.pointes, n, "BORDER")
	local nom = "talents-arrow-head-" .. etat
	t:ClearAllPoints()
	if sens == "bas" then
		tourner(t, nom, 0)
		t:SetWidth(G.pointeL) t:SetHeight(G.pointeH)
	elseif sens == "droite" then
		tourner(t, nom, 270)
		t:SetWidth(G.pointeH) t:SetHeight(G.pointeL)
	else
		tourner(t, nom, 90)
		t:SetWidth(G.pointeH) t:SetHeight(G.pointeL)
	end
	t:SetPoint("CENTER", T.arbre, "TOPLEFT", x, y)
end

-- une fleche de prerequis : droite dans une colonne ou un palier, sinon elle
-- descend puis tourne (comme WotLK)
local function fleche(nTrait, nPointe, source, cible, etat)
	local x1, y1 = centre(source.onglet, source.palier, source.colonne)
	local x2, y2 = centre(cible.onglet, cible.palier, cible.colonne)
	local r = G.noeud / 2
	if x1 == x2 then
		local bout = y2 + r + G.pointeH / 2
		trait(nTrait, x1, y1, x1, bout, etat)
		pointe(nPointe, x2, bout, "bas", etat)
		return nTrait + 1, nPointe + 1
	end
	local sens = (x2 > x1) and "droite" or "gauche"
	local bout = (x2 > x1) and (x2 - r - G.pointeH / 2) or (x2 + r + G.pointeH / 2)
	if y1 == y2 then
		trait(nTrait, x1, y1, bout, y1, etat)
		pointe(nPointe, bout, y2, sens, etat)
		return nTrait + 1, nPointe + 1
	end
	trait(nTrait, x1, y1, x1, y2, etat)
	trait(nTrait + 1, x1, y2, bout, y2, etat)
	pointe(nPointe, bout, y2, sens, etat)
	return nTrait + 2, nPointe + 1
end

-- ------------------------------------------------------------ les portes
local function creerPorte(n)
	local p = CreateFrame("Frame", "ForeverUITalentsGate" .. n, T.arbre)
	p:SetWidth(G.porteL)
	p:SetHeight(G.porteH)
	p:SetFrameLevel(T.arbre:GetFrameLevel() + 3)
	local icone = p:CreateTexture(nil, "ARTWORK")
	atlasTaille(icone, "talents-gate", G.porteIconeL, G.porteIconeH)
	icone:SetPoint("RIGHT", p, "RIGHT", 25, 2)
	local texte = p:CreateFontString(nil, "OVERLAY")
	texte:SetFont(POLICE, 24)
	couleur(texte, COULEUR.porte)
	texte:SetPoint("RIGHT", icone, "LEFT", -10, -1)
	p.texte = texte
	p:EnableMouse(true)
	p:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT", 4, -4)
		GameTooltip:SetText(string.format(TEXTE.porte, self.reste or 0), 1, 0.125, 0.125)
		GameTooltip:Show()
	end)
	p:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return p
end

-- ------------------------------------------------------------ le remplissage
-- les talents du groupe actif, par onglet
-- LA VUE : la specialisation affichee (nil = l'active) ou le familier
T.vue = { groupe = nil, pet = false }

function T.lire()
	-- les glyphes : l'etat est celui de WotLK (GlyphFrame montre, et la
	-- specialisation que PlayerSpecTab_OnClick a choisie)
	T.glyphes = (GlyphFrame and GlyphFrame:IsShown()) and true or false
	if T.glyphes then
		T.vue.pet = false
		T.vue.groupe = PlayerTalentFrame.talentGroup or T.vue.groupe
	end
	-- le familier parti (ou sans talents), la vue revient au joueur
	if T.vue.pet and (GetNumTalentTabs(false, true) or 0) == 0 then T.vue.pet = false end
	local pet = T.vue.pet and true or false
	local actif = GetActiveTalentGroup and GetActiveTalentGroup(false, pet) or 1
	local groupe = (not pet and T.vue.groupe) or actif
	T.groupe, T.pet, T.actif = groupe, pet, (groupe == actif)
	local onglets = {}
	for o = 1, math.min(GetNumTalentTabs(false, pet) or 0, 3) do
		local nom, icone, depenses, fond, attente = GetTalentTabInfo(o, false, pet, groupe)
		local tab = { nom = nom, icone = icone, depenses = (depenses or 0) + (attente or 0), fond = fond, talents = {} }
		local carres = ForeverUI.TalentsCarres and ForeverUI.TalentsCarres[fond or ""] or {}
		for i = 1, (GetNumTalents(o, false, pet) or 0) do
			local n, ic, palier, colonne, rang, max, _, prerequis, rangApercu, prerequisApercu =
				GetTalentInfo(o, i, false, pet, groupe)
			if n then
				-- le rang MONTRE est celui de l'apercu : appris + en attente
				table.insert(tab.talents, { onglet = o, index = i, nom = n, icone = ic, palier = palier,
					colonne = colonne, rang = rangApercu or rang or 0, appris = rang or 0, max = max or 1,
					prerequis = (prerequisApercu ~= nil and prerequisApercu or prerequis) and true or false,
					carre = carres[palier .. ":" .. colonne] and true or false })
			end
		end
		onglets[o] = tab
	end
	-- les points restants : moins ceux qui attendent
	local attente = GetGroupPreviewTalentPointsSpent and GetGroupPreviewTalentPointsSpent(pet, groupe) or 0
	T.attente = attente
	return onglets, (GetUnspentTalentPoints(false, pet, groupe) or 0) - attente
end

-- ------------------------------------------------------------ le glisser
-- un talent CARRE (sort actif), APPRIS (valide, pas seulement en attente), de
-- la specialisation active : son sort, pris dans le grimoire (le joueur ou le
-- familier), au plus haut rang connu. Les sorts d'un talent viennent des DBC
-- (TalentsData.lua, ForeverUI.TalentsSorts) ; faute de mieux, le nom.
function T.sortDuTalent(t)
	local livre = T.pet and BOOKTYPE_PET or BOOKTYPE_SPELL
	local total = 0
	if T.pet then
		total = (HasPetSpells and HasPetSpells()) or 0
	else
		for i = 1, (GetNumSpellTabs() or 0) do
			local _, _, debut, nombre = GetSpellTabInfo(i)
			total = math.max(total, (debut or 0) + (nombre or 0))
		end
	end
	local o = T.onglets and T.onglets[t.onglet]
	local sorts = o and ForeverUI.TalentsSorts and ForeverUI.TalentsSorts[o.fond or ""]
	sorts = sorts and sorts[t.palier .. ":" .. t.colonne]
	local voulus = {}
	for _, id in ipairs(sorts or {}) do voulus[id] = true end
	local trouve, parNom
	for slot = 1, total do
		local lien = GetSpellLink(slot, livre)
		local id = lien and tonumber(string.match(lien, "spell:(%d+)"))
		if id and voulus[id] then trouve = slot end
		if GetSpellName(slot, livre) == t.nom then parNom = slot end
	end
	return trouve or parNom, livre
end

function T.prendreSort(b)
	local t = b.talent
	if not t or not t.carre or (t.appris or 0) == 0 or not T.actif then return end
	local slot, livre = T.sortDuTalent(t)
	if slot then PickupSpell(slot, livre) end
end

-- ------------------------------------------------------------ l'attente
-- un point de plus (clic gauche), un point en attente de moins (clic droit),
-- le lien (Maj-clic) ; le client refuse ce qui n'est pas permis
function T.cliquer(b, bouton)
	local t = b.talent
	if not t then return end
	if IsModifiedClick("CHATLINK") then
		local lien = GetTalentLink(t.onglet, t.index, false, T.pet, T.groupe)
		if lien then ChatEdit_InsertLink(lien) end
		return
	end
	-- une specialisation inactive se consulte seulement (IsLocked)
	if not T.actif then return end
	if bouton == "RightButton" then
		if t.rang > t.appris then
			AddPreviewTalentPoints(t.onglet, t.index, -1, T.pet, T.groupe)
		end
	elseif t.etat == "selectable" and t.rang < t.max then
		AddPreviewTalentPoints(t.onglet, t.index, 1, T.pet, T.groupe)
	end
	T.maj()
	if GameTooltip.IsOwned and GameTooltip:IsOwned(b) then b:GetScript("OnEnter")(b) end
end

function T.appliquer()
	if (T.attente or 0) <= 0 then return end
	LearnPreviewTalents(T.pet)
	T.maj()
end

function T.annuler()
	ResetGroupPreviewTalentPoints(T.pet, T.groupe)
	T.maj()
end

-- ActivateSpec : SetActiveTalentGroup lance un sort (63645 / 63644)
function T.activer()
	if T.pet or T.actif then return end
	SetActiveTalentGroup(T.groupe)
	T.maj()
end

-- ------------------------------------------------------------ les onglets
local function iconeDeSpecialisation(groupe)
	local points = {}
	for o = 1, math.min(GetNumTalentTabs(false, false) or 0, 3) do
		local _, icone, depenses = GetTalentTabInfo(o, false, false, groupe)
		table.insert(points, { n = depenses or 0, icone = icone })
	end
	table.sort(points, function(a, b) return a.n > b.n end)
	local haut, milieu, bas = points[1], points[2], points[3]
	if not haut or haut.n == 0 then return ICONES_ONGLET .. ICONE_DEFAUT end
	local m, b = milieu and milieu.n or 0, bas and bas.n or 0
	if 3 * (m - b) < 2 * (haut.n - b) then
		local nom = string.match(haut.icone or "", "([^" .. SEP .. "/]+)$") or ICONE_DEFAUT
		return ICONES_ONGLET .. string.lower(nom)
	end
	return ICONES_ONGLET .. ICONE_HYBRIDE
end
T.iconeDeSpecialisation = iconeDeSpecialisation

local function creerOnglet(cle, n)
	local barre = T.barreOnglets
	local b = CreateFrame("Button", "ForeverUITalentsTab" .. n, barre)
	b:SetFrameLevel(barre:GetFrameLevel() + 1)
	b:SetWidth(G.ongletCote)
	b:SetHeight(G.ongletCote)
	local fondOnglet = b:CreateTexture(nil, "BACKGROUND")
	atlas(fondOnglet, "common-sidetab", true)
	fondOnglet:SetAllPoints(b)
	local icone = b:CreateTexture(nil, "ARTWORK")
	icone:SetWidth(G.ongletIcone)
	icone:SetHeight(G.ongletIcone)
	icone:SetPoint("CENTER", b, "CENTER", G.ongletIconeX, 0)
	icone:SetTexCoord(G.ongletRognage, 1 - G.ongletRognage, G.ongletRognage, 1 - G.ongletRognage)
	local choisi = b:CreateTexture(nil, "OVERLAY")
	atlas(choisi, "common-sidetab-selected", true)
	choisi:SetAllPoints(b)
	choisi:Hide()
	local survol = b:CreateTexture(nil, "HIGHLIGHT")
	atlas(survol, "common-sidetab-hover", true)
	survol:SetAllPoints(b)
	-- la coche de la specialisation active, le cadenas de celle qui l'est
	local coche = b:CreateTexture(nil, "OVERLAY")
	atlasTaille(coche, "talents-checkmark-c60", G.cocheL, G.cocheH)
	coche:SetPoint("BOTTOMRIGHT", icone, "BOTTOMRIGHT", -2, 2)
	coche:Hide()
	local cadenas = b:CreateTexture(nil, "OVERLAY")
	atlasTaille(cadenas, "talents-lock-c60", G.cadenasL, G.cadenasH)
	cadenas:SetPoint("BOTTOMRIGHT", icone, "BOTTOMRIGHT", -4, 4)
	cadenas:Hide()
	b.icone, b.choisi, b.coche, b.cadenas, b.cle = icone, choisi, coche, cadenas, cle
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.titre or "")
		if self.verrouille then
			GameTooltip:AddLine(TEXTE.verrouille, 1, 0.125, 0.125)
		elseif self.estActive then
			GameTooltip:AddLine(TEXTE.actif, COULEUR.vert[1], COULEUR.vert[2], COULEUR.vert[3])
		end
		if self.repartition then GameTooltip:AddLine(self.repartition, 1, 1, 1) end
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", function(self)
		if self.verrouille then return end
		PlaySound("igCharacterInfoTab")
		if self.cle == "glyphes" then
			T.ouvrirGlyphes(not T.vue.pet and T.vue.groupe or nil)
		elseif self.cle == "pet" then
			T.fermerGlyphes()
			T.vue.pet = true
		else
			T.fermerGlyphes()
			T.vue.pet = false
			T.vue.groupe = self.groupe
		end
		T.maj()
	end)
	return b
end

-- la pile : premiere specialisation, seconde, glyphes (au niveau de la
-- calligraphie), familier (s'il a des talents)
function T.poserOnglets()
	local barre = T.barreOnglets
	if not barre then return end
	barre.onglets = barre.onglets or {}
	local actif = GetActiveTalentGroup and GetActiveTalentGroup(false, false) or 1
	local nbGroupes = GetNumTalentGroups and GetNumTalentGroups(false, false) or 1
	local defs = {
		{ cle = "spec1", groupe = 1, titre = TEXTE.primaire },
		{ cle = "spec2", groupe = 2, titre = TEXTE.secondaire },
	}
	-- PlayerTalentFrame_UpdateTabs : l'onglet n'existe qu'a partir de
	-- SHOW_INSCRIPTION_LEVEL ; son nom, celui de GlyphFrameTitleText
	if (UnitLevel("player") or 0) >= (SHOW_INSCRIPTION_LEVEL or 15) then
		local vu = (not T.vue.pet and T.vue.groupe) or actif
		local titre = TEXTE.glyphes
		if nbGroupes > 1 then
			titre = vu == 2 and TEXTE.glyphesSecondaires or TEXTE.glyphesPrimaires
		end
		table.insert(defs, { cle = "glyphes", titre = titre })
	end
	if (GetNumTalentTabs(false, true) or 0) > 0 then
		table.insert(defs, { cle = "pet", titre = TEXTE.familier })
	end
	local precedent
	for i, d in ipairs(defs) do
		local b = barre.onglets[i] or creerOnglet(d.cle, i)
		barre.onglets[i] = b
		b.cle, b.groupe, b.titre = d.cle, d.groupe, d.titre
		b.verrouille = (d.groupe == 2 and nbGroupes < 2) or nil
		b.estActive = (d.groupe ~= nil and d.groupe == actif) or nil
		if d.cle == "pet" then
			SetPortraitTexture(b.icone, "pet")
			b.repartition = nil
		elseif d.cle == "glyphes" then
			b.icone:SetTexture(ICONES_ONGLET .. ICONE_GLYPHES)
			b.repartition = nil
		else
			b.icone:SetTexture(iconeDeSpecialisation(d.groupe))
			local r = {}
			for o = 1, math.min(GetNumTalentTabs(false, false) or 0, 3) do
				local _, _, depenses = GetTalentTabInfo(o, false, false, d.groupe)
				table.insert(r, tostring(depenses or 0))
			end
			b.repartition = table.concat(r, " / ")
		end
		b.icone:SetDesaturated(b.verrouille and true or false)
		if b.estActive then b.coche:Show() else b.coche:Hide() end
		if b.verrouille then b.cadenas:Show() else b.cadenas:Hide() end
		local choisi
		if d.cle == "glyphes" then
			choisi = T.glyphes
		elseif T.glyphes then
			choisi = false
		elseif d.cle == "pet" then
			choisi = T.vue.pet
		else
			choisi = not T.vue.pet and d.groupe == (T.vue.groupe or actif)
		end
		if choisi then b.choisi:Show() else b.choisi:Hide() end
		b:ClearAllPoints()
		if precedent then
			b:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, G.ongletEcart)
		else
			b:SetPoint("TOPLEFT", barre, "TOPLEFT", 0, 0)
		end
		b:Show()
		precedent = b
	end
	for i = #defs + 1, #barre.onglets do barre.onglets[i]:Hide() end
end

-- ------------------------------------------------------------ les glyphes
-- WotLK garde la main : on clique ses propres onglets, caches
local function ongletDeSpecialisation(cle)
	for i = 1, 4 do
		local b = _G["PlayerSpecTab" .. i]
		if b and b.specIndex == cle then return b end
	end
end

function T.ouvrirGlyphes(groupe)
	groupe = groupe or (GetActiveTalentGroup and GetActiveTalentGroup(false, false)) or 1
	T.vue.pet, T.vue.groupe = false, groupe
	local spec = ongletDeSpecialisation("spec" .. groupe)
	if spec and PlayerSpecTab_OnClick then PlayerSpecTab_OnClick(spec) end
	local onglet = _G["PlayerTalentFrameTab" .. (GLYPH_TALENT_TAB or 4)]
	if onglet and PlayerTalentTab_OnClick then PlayerTalentTab_OnClick(onglet) end
end

function T.fermerGlyphes()
	if not (GlyphFrame and GlyphFrame:IsShown()) then return end
	local onglet = _G["PlayerTalentFrameTab1"]
	if onglet and PlayerTalentTab_OnClick then
		PlayerTalentTab_OnClick(onglet)
	else
		GlyphFrame:Hide()
	end
end

-- le GlyphFrame dans la page reduite : le parchemin centre, a sa taille.
-- PLANTAGE A LA DECONNEXION (ERROR #132, 2026-09-25) : la pile montre la
-- destruction recursive des cadres qui tombe sur un enfant deja libere. Les
-- versions qui RATTACHAIENT le GlyphFrame a nos cadres (T.cadre, puis
-- T.page) plantaient toutes deux. Il reste donc la ou WotLK le met (parent
-- PlayerTalentFrame) : on ne fait que l'ancrer sur la page et le lever
-- au-dessus d'elle.
function T.poserGlyphes()
	local g = GlyphFrame
	if not g or not T.page then return end
	T.construireDecorGlyphes()
	g:ClearAllPoints()
	g:SetPoint("TOPLEFT", T.classe, "CENTER", -G.glypheCentreX, -G.glypheCentreY)
	-- le decor (sur le cadre interieur), ses lueurs (cadre+2), puis les alveoles
	g:SetFrameLevel(T.cadre:GetFrameLevel() + 3)
	-- le decor de WotLK s'efface : son parchemin et sa lueur
	if _G.GlyphFrameBackground then _G.GlyphFrameBackground:Hide() end
	if g.glow then g.glow:Hide() end
	if _G.GlyphFrameTitleText then _G.GlyphFrameTitleText:Hide() end
	T.leverCroix()
end

-- LE DECOR : a nous (jamais le GlyphFrame a nous : voir plus haut). Ses
-- images sont posees SUR LE CADRE INTERIEUR, dans ses calques du fond : le
-- cadre (OVERLAY) passe devant elles, et un meme cadre ordonne ses calques
-- -- deux cadres de meme niveau, eux, n'ont pas d'ordre garanti.
function T.construireDecorGlyphes()
	if T.decor then return T.decor end
	local classe, cadre = T.classe, T.cadre
	local decor = { textures = {} }
	local parchemin = cadre:CreateTexture("ForeverUIGlyphParchment", "BACKGROUND")
	glyphe(parchemin, "parchemin")
	parchemin:SetAllPoints(classe)
	local cercle = cadre:CreateTexture("ForeverUIGlyphCircle", "BORDER")
	glyphe(cercle, "cercle", true)
	cercle:SetPoint("TOPLEFT", classe, "CENTER", -G.cercleCentreX, G.cercleCentreY)
	decor.textures = { parchemin, cercle }
	for _, c in ipairs({ { "coin-hg", "TOPLEFT", 1, -1 }, { "coin-hd", "TOPRIGHT", -1, -1 },
		{ "coin-bg", "BOTTOMLEFT", 1, 1 }, { "coin-bd", "BOTTOMRIGHT", -1, 1 } }) do
		local t = cadre:CreateTexture("ForeverUIGlyphCorner" .. c[1]:sub(-2), "ARTWORK")
		glyphe(t, c[1], true)
		t:SetPoint(c[2], classe, c[2], c[3] * G.coinRetraitX, c[4] * G.coinRetraitY)
		table.insert(decor.textures, t)
	end
	function decor:Show()
		for _, t in ipairs(self.textures) do t:Show() end
		if self.cercles then self.cercles:Show() end
	end
	function decor:Hide()
		for _, t in ipairs(self.textures) do t:Hide() end
		if self.cercles then self.cercles:Hide() end
	end

	-- les cercles concentriques : sur le parchemin, sous les lueurs et les
	-- alveoles, en ADD ; ils ne tournent que la page montree
	local cercles = CreateFrame("Frame", "ForeverUIGlyphRings", T.page)
	cercles:SetAllPoints(classe)
	cercles:SetFrameLevel(cadre:GetFrameLevel() + 1)
	cercles.anneaux = {}
	for i, def in ipairs(CERCLES) do
		local t = cercles:CreateTexture(nil, "ARTWORK")
		glyphe(t, def.cle, true)
		t:SetBlendMode("ADD")
		t:SetPoint("CENTER", classe, "CENTER", 0, 0)
		t:SetAlpha(0)
		cercles.anneaux[i] = { texture = t, def = def, angle = 0, alpha = 0, cible = 0 }
	end
	cercles:SetScript("OnUpdate", function(self, ecoule)
		for _, a in ipairs(self.anneaux) do
			a.angle = (a.angle + 2 * math.pi * ecoule / a.def.tour) % (2 * math.pi)
			tournerAnneau(a.texture, a.def.cle, a.angle)
			if a.alpha ~= a.cible then
				local pas = G.cerclesFondu * ecoule
				if a.alpha < a.cible then
					a.alpha = math.min(a.cible, a.alpha + pas)
				else
					a.alpha = math.max(a.cible, a.alpha - pas)
				end
				a.texture:SetAlpha(a.alpha)
			end
		end
	end)
	cercles:Hide()
	decor.cercles = cercles

	-- les lueurs : au-dessus du cadre, sous les alveoles, en ADD
	local lueurs = CreateFrame("Frame", "ForeverUIGlyphGlow", T.page)
	lueurs:SetAllPoints(classe)
	lueurs:SetFrameLevel(cadre:GetFrameLevel() + 2)
	lueurs.textures = {}
	for _, cle in ipairs({ "anneau-runique", "anneau-epines", "anneau-double", "rayon-0", "rayon-1", "rayon-2" }) do
		local t = lueurs:CreateTexture(nil, "OVERLAY")
		glyphe(t, cle, true)
		t:SetBlendMode("ADD")
		t:SetPoint("CENTER", classe, "CENTER", 0, 0)
		lueurs.textures[cle] = t
	end
	lueurs:SetAlpha(0)
	lueurs:Hide()
	lueurs:SetScript("OnUpdate", function(self, ecoule)
		self.temps = (self.temps or 0) + ecoule
		local t = self.temps
		if t < G.lueurMontee then
			self:SetAlpha(t / G.lueurMontee)
		elseif t < G.lueurMontee + G.lueurDescente then
			self:SetAlpha(1 - (t - G.lueurMontee) / G.lueurDescente)
		else
			self:SetAlpha(0)
			self:Hide()
		end
	end)
	decor.lueurs = lueurs
	decor:Hide()
	T.decor = decor
	return decor
end

-- GlyphFrame_PulseGlow : nos lueurs, a la place de UI-GlyphFrame-Glow
function T.pulserGlyphes()
	local lueurs = T.decor and T.decor.lueurs
	if not lueurs then return end
	lueurs.temps = 0
	lueurs:SetAlpha(0)
	lueurs:Show()
	if GlyphFrame and GlyphFrame.glow then GlyphFrame.glow:Hide() end
end

-- la surbrillance d'une alveole : l'anneau orange, a la taille que WotLK lui
-- donne (celle de la monture, 108 ou 86) ; GlyphFrameGlyph_SetGlyphType
-- repose ses coordonnees sur UI-GlyphFrame a chaque mise a jour
local function surbrillance(bouton)
	if bouton and bouton.highlight then glyphe(bouton.highlight, "anneau-orange") end
end

-- les alveoles garnies de la specialisation affichee : la cible de chaque
-- cercle (GetGlyphSocketInfo rend le sort du glyphe grave)
function T.compterGlyphes()
	local cercles = T.decor and T.decor.cercles
	if not cercles then return end
	local groupe = PlayerTalentFrame and PlayerTalentFrame.talentGroup
	for _, a in ipairs(cercles.anneaux) do
		local n = 0
		for _, id in ipairs(a.def.alveoles) do
			local _, _, sort = GetGlyphSocketInfo(id, groupe)
			if sort then n = n + 1 end
		end
		a.cible = G.cerclesAlpha * n / #a.def.alveoles
	end
end

-- une specialisation inactive : le decor grise, comme WotLK grise son fond
function T.griserGlyphes()
	if not T.decor then return end
	local actif = PlayerTalentFrame and not PlayerTalentFrame.pet
		and PlayerTalentFrame.talentGroup == GetActiveTalentGroup(false, false)
	for _, t in ipairs(T.decor.textures) do t:SetDesaturated(not actif) end
end

-- avant que le client ne detruise l'interface : le GlyphFrame reprend
-- l'ancrage que WotLK lui donne (ADDON_LOADED : SetAllPoints sur
-- PlayerTalentFrame) ; il revient dans la page a sa prochaine ouverture
function T.rendreGlyphes()
	local g = GlyphFrame
	if not g or not PlayerTalentFrame then return end
	g:ClearAllPoints()
	g:SetAllPoints(PlayerTalentFrame)
end

-- une fois, quand Blizzard_GlyphUI est la
function T.brancherGlyphes()
	local g = GlyphFrame
	if not g or g.foreverBranche then return end
	g.foreverBranche = true
	g:HookScript("OnShow", function()
		T.poserGlyphes()
		if T.livre and T.livre:IsVisible() then T.maj() end
	end)
	-- A LA DECONNEXION, le client detruit l'interface et cache au passage le
	-- GlyphFrame s'il etait montre : T.maj y redimensionnait et reancrait la
	-- fenetre au milieu de la destruction -- plantage du client (ERROR #132,
	-- 2026-09-25). Plus rien ne bouge apres PLAYER_LOGOUT / LEAVING_WORLD.
	g:HookScript("OnHide", function()
		if not T.fini and T.livre and T.livre:IsVisible() then T.maj() end
	end)
	-- les greffes sur le code de WotLK : lueur, surbrillance, etincelles,
	-- grisaille
	if type(GlyphFrame_PulseGlow) == "function" then
		hooksecurefunc("GlyphFrame_PulseGlow", T.pulserGlyphes)
	end
	if type(GlyphFrameGlyph_SetGlyphType) == "function" then
		hooksecurefunc("GlyphFrameGlyph_SetGlyphType", surbrillance)
	end
	for i = 1, 6 do surbrillance(_G["GlyphFrameGlyph" .. i]) end
	if type(GlyphFrame_StartSlotAnimation) == "function" then
		hooksecurefunc("GlyphFrame_StartSlotAnimation", function(id)
			local e = _G["GlyphFrameSparkle" .. id]
			if not e then return end
			local l, h = e:GetWidth(), e:GetHeight()
			glyphe(e, "etoile")
			e:SetWidth(l * G.etincelleEchelle)
			e:SetHeight(h * G.etincelleEchelle)
		end)
	end
	if type(GlyphFrame_Update) == "function" then
		hooksecurefunc("GlyphFrame_Update", function()
			T.griserGlyphes()
			T.compterGlyphes()
		end)
	end
	-- un glyphe grave ou retire (GLYPH_ADDED / _REMOVED / _UPDATED) :
	-- GlyphFrameGlyph_UpdateSlot, sans GlyphFrame_Update
	if type(GlyphFrameGlyph_UpdateSlot) == "function" then
		hooksecurefunc("GlyphFrameGlyph_UpdateSlot", T.compterGlyphes)
	end
	T.poserGlyphes()
end

-- LA LARGEUR : trois arbres, ou un seul (le familier, les glyphes)
function T.poserLargeur(etroit)
	local pageL = etroit and G.pageEtroite or G.pageL
	T.livre:SetWidth(G.largeur - G.pageL + pageL)
	T.page:SetWidth(pageL)
	poserPierre(pageL)
	-- les barres horizontales, rognees a la demi-largeur : l'ornement du bout
	-- reste, le trait rejoint le centre
	local demi = (pageL - 2 * G.cadreG) / 2
	for _, d in ipairs({ { T.barreGauche, "talents-divider-left-c60", false },
		{ T.barreDroite, "talents-divider-right-c60", true } }) do
		local t, e = d[1], ForeverUI.AtlasEntry(d[2])
		if e then
			local l = math.min(e[6], demi)
			local du = (e[3] - e[2]) * l / e[6]
			if d[3] then
				t:SetTexCoord(e[3] - du, e[3], e[4], e[5])
			else
				t:SetTexCoord(e[2], e[2] + du, e[4], e[5])
			end
			t:SetWidth(l)
		end
	end
	for _, v in ipairs(T.verticaux) do
		if etroit then v:Hide() else v:Show() end
	end
	T.etroit = etroit
end

local function poserFond(onglets)
	local classe = T.classe
	for _, t in ipairs(classe.textures) do t:Hide() end
	local _, token = UnitClass("player")
	if token == "DEATHKNIGHT" and not T.etroit then
		-- un fond par arbre : le tiers du milieu de chaque image moderne
		local l = G.pageL / 3
		for i = 1, 3 do
			local t = classe.textures[i] or classe:CreateTexture(nil, "BACKGROUND")
			classe.textures[i] = t
			local e = ForeverUI.AtlasEntry(FOND_DK[i])
			if e then
				t:SetTexture(e[1])
				local du = (e[3] - e[2]) / 3
				t:SetTexCoord(e[2] + du, e[3] - du, e[4], e[5])
			end
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", classe, "TOPLEFT", (i - 1) * l, 0)
			t:SetPoint("BOTTOMLEFT", classe, "BOTTOMLEFT", (i - 1) * l, 0)
			t:SetWidth(l)
			t:Show()
		end
		return
	end
	local t = classe.textures[1] or classe:CreateTexture(nil, "BACKGROUND")
	classe.textures[1] = t
	local nom = "talent-background-" .. string.lower(token or "warrior")
	atlas(t, nom, true)
	-- la fenetre reduite montre le premier tiers de l'illustration : celui de
	-- la colonne qu'elle garde
	if T.etroit then
		local e = ForeverUI.AtlasEntry(nom)
		if e then t:SetTexCoord(e[2], e[2] + (e[3] - e[2]) / 3, e[4], e[5]) end
	end
	t:ClearAllPoints()
	t:SetAllPoints(classe)
	t:Show()
end

function T.maj()
	if not T.livre or T.fini then return end
	local onglets, points = T.lire()
	T.onglets = onglets
	T.poserLargeur(T.pet or T.glyphes)
	poserFond(onglets)
	T.poserOnglets()
	-- les glyphes : la page ne garde que la pierre et son cadre
	local glyphes = T.glyphes
	for _, f in ipairs({ T.classe, T.arbre, T.points, T.barreGauche, T.barreDroite }) do
		if glyphes then f:Hide() else f:Show() end
	end
	T.livre.titre:SetText(glyphes and _G.GlyphFrameTitleText and _G.GlyphFrameTitleText:GetText() or TEXTE.titre)
	if T.decor then
		if glyphes then T.decor:Show() else T.decor:Hide() end
	end
	local recherche = ForeverUI.TalentsSearch
	if glyphes then
		if recherche then recherche.maj() end
		for _, h in ipairs(T.entetes) do h:Hide() end
		T.poserGlyphes()
		T.decor:Show()
		T.griserGlyphes()
		T.compterGlyphes()
		T.appliquerBouton:Hide()
		T.annulerBouton:Hide()
		if T.actif then
			T.activerBouton:Hide()
		else
			T.activerBouton:Show()
			local sort = SORTS_ACTIVATION[T.groupe]
			T.activerBouton:Activer(not (sort and IsCurrentSpell and IsCurrentSpell(sort)))
		end
		return
	end
	local parPalier = T.pet and G.pointsParPalierFamilier or G.pointsParPalier

	-- en-tetes
	for i, h in ipairs(T.entetes) do
		local o = onglets[i]
		if o then
			SetPortraitToTexture(h.icone, o.icone)
			h.nom:SetText(o.nom)
			h.depenses:SetText(tostring(o.depenses))
			h:Show()
		else
			h:Hide()
		end
	end
	-- Apply et Undo : seulement s'il y a des changements en attente ; sur une
	-- specialisation inactive, Activate a leur place
	local attente = (T.attente or 0) > 0
	if T.actif then
		T.activerBouton:Hide()
		T.appliquerBouton:Show()
		T.appliquerBouton:Activer(attente)
		if attente then T.appliquerBouton.lueur:Show() T.annulerBouton:Show()
		else T.appliquerBouton.lueur:Hide() T.annulerBouton:Hide() end
	else
		T.appliquerBouton:Hide()
		T.annulerBouton:Hide()
		T.activerBouton:Show()
		-- incantation en cours : le bouton attend (PlayerTalentFrameActivateButton)
		local sort = SORTS_ACTIVATION[T.groupe]
		T.activerBouton:Activer(not (sort and IsCurrentSpell and IsCurrentSpell(sort)))
	end

	-- les points non depenses : vert s'il en reste
	T.points.nombre:SetText(tostring(points))
	couleur(T.points.nombre, points > 0 and COULEUR.vert or COULEUR.gris)

	-- noeuds
	local arbre = T.arbre
	local n = 0
	local parPlace = {}
	for _, o in ipairs(onglets) do
		for _, t in ipairs(o.talents) do
			n = n + 1
			local b = arbre.noeuds[n] or creerNoeud(n)
			arbre.noeuds[n] = b
			local ouvert = (t.palier - 1) * parPalier <= o.depenses
			t.etat = etatDe(t, ouvert, points)
			remplirNoeud(b, t, t.etat)
			parPlace[t.onglet .. ":" .. t.palier .. ":" .. t.colonne] = t
		end
	end
	for i = n + 1, #arbre.noeuds do
		arbre.noeuds[i].talent = nil
		arbre.noeuds[i]:Hide()
	end

	-- fleches : les prerequis de chaque talent (palier, colonne, rempli)
	local nT, nP = 1, 1
	for _, o in ipairs(onglets) do
		for _, t in ipairs(o.talents) do
			local p = { GetTalentPrereqs(t.onglet, t.index, false, T.pet, T.groupe) }
			for k = 1, #p, 4 do
				local source = parPlace[t.onglet .. ":" .. p[k] .. ":" .. p[k + 1]]
				if source then
					local rempli = p[k + 3]
					if rempli == nil then rempli = p[k + 2] end
					local etat = (t.etat == "locked") and "locked" or (rempli and "yellow" or "gray")
					nT, nP = fleche(nT, nP, source, t, etat)
				end
			end
		end
	end
	for i = nT, #arbre.traits do arbre.traits[i]:Hide() end
	for i = nP, #arbre.pointes do arbre.pointes[i]:Hide() end

	-- portes : une par arbre, au premier palier ferme qui porte un talent,
	-- a gauche de son premier noeud
	local nPorte = 0
	for oi, o in ipairs(onglets) do
		local premier
		for _, t in ipairs(o.talents) do
			if t.etat == "locked" and (not premier or t.palier < premier.palier
				or (t.palier == premier.palier and t.colonne < premier.colonne)) then
				premier = t
			end
		end
		if premier then
			nPorte = nPorte + 1
			local p = arbre.portes[nPorte] or creerPorte(nPorte)
			arbre.portes[nPorte] = p
			p.reste = (premier.palier - 1) * parPalier - o.depenses
			p.texte:SetText(tostring(p.reste))
			local x, y = centre(premier.onglet, premier.palier, premier.colonne)
			p:ClearAllPoints()
			p:SetPoint("RIGHT", arbre, "TOPLEFT", x - G.noeud / 2 + G.porteX, y)
			p:Show()
		end
	end
	for i = nPorte + 1, #arbre.portes do arbre.portes[i]:Hide() end

	-- la recherche : sa largeur, et les marques des noeuds
	if recherche then
		recherche.poser(T.page:GetWidth())
		recherche.maj()
	end
end

-- ------------------------------------------------------------ l'assemblage
function T.etoufferWotLK()
	local f = PlayerTalentFrame
	if not f then return end
	for _, region in ipairs({ f:GetRegions() }) do etouffer(region) end
	for _, enfant in ipairs({ f:GetChildren() }) do
		if enfant ~= T.livre and enfant ~= PlayerTalentFrameCloseButton and enfant ~= GlyphFrame then
			etouffer(enfant)
		end
	end
end

-- ------------------------------------------------------------ la confirmation
-- des changements attendent : ceux du joueur (sa specialisation active, la
-- seule ou l'on en pose) ou ceux du familier
local function familierPresent()
	return (GetNumTalentTabs(false, true) or 0) > 0
end
function T.enAttente()
	local n = GetGroupPreviewTalentPointsSpent(false, GetActiveTalentGroup(false, false)) or 0
	if familierPresent() then
		n = n + (GetGroupPreviewTalentPointsSpent(true, GetActiveTalentGroup(false, true)) or 0)
	end
	return n > 0
end

-- CONTINUE : l'attente s'en va, la fenetre se ferme pour de bon
function T.fermerSansAttente()
	ResetGroupPreviewTalentPoints(false, GetActiveTalentGroup(false, false))
	if familierPresent() then ResetGroupPreviewTalentPoints(true, GetActiveTalentGroup(false, true)) end
	T.confirme = true
	HideUIPanel(PlayerTalentFrame)
	T.confirme = nil
end

StaticPopupDialogs = StaticPopupDialogs or {}
StaticPopupDialogs["FOREVERUI_TALENTS_CONFIRM_CLOSE"] = {
	text = TEXTE.confirmerFermeture,
	button1 = CONTINUE or "Continue",
	button2 = CANCEL or "Cancel",
	OnAccept = function() T.fermerSansAttente() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

-- la fenetre s'est fermee avec de l'attente : elle se rouvre a l'image
-- suivante, telle qu'elle etait, et demande
local rouvreur = CreateFrame("Frame")
rouvreur:Hide()
rouvreur:SetScript("OnUpdate", function(self)
	self:Hide()
	if T.fini or not T.enAttente() then return end
	T.garderVue = true
	ShowUIPanel(PlayerTalentFrame)
	T.garderVue = nil
	StaticPopup_Show("FOREVERUI_TALENTS_CONFIRM_CLOSE")
end)
T.rouvreur = rouvreur

function T.construire()
	if T.livre or not PlayerTalentFrame then return T.livre end
	PlayerTalentFrame:EnableMouse(false)
	local livre = CreateFrame("Frame", "ForeverUITalentsFrame", PlayerTalentFrame)
	livre:SetPoint("TOP", UIParent, "TOP", 0, G.haut)
	livre:SetWidth(G.largeur)
	livre:SetHeight(G.hauteur)
	livre:EnableMouse(true)
	T.livre = livre
	construireCadre(livre)
	construirePage(livre)
	-- la barre des onglets lateraux, dehors a droite (CharacterFrameModeTabs)
	local barre = CreateFrame("Frame", "ForeverUITalentsTabs", livre)
	barre:SetWidth(64)
	barre:SetHeight(384)
	barre:SetPoint("TOPLEFT", livre, "TOPRIGHT", G.ongletsX, G.ongletsY)
	barre:SetFrameLevel(livre:GetFrameLevel() + 1)
	T.barreOnglets = barre
	T.etoufferWotLK()
	T.brancherGlyphes()
	-- la recherche (TalentsSearch.lua, charge apres ce fichier : s'il ne
	-- l'est pas encore, il se construit lui-meme)
	if ForeverUI.TalentsSearch then ForeverUI.TalentsSearch.construire(T) end
	-- deplacable par son titre ; devant quand il s'ouvre ou qu'on le clique
	ForeverUI.Superposition.deplacable(livre, livre.bandeau, "talents")
	ForeverUI.Superposition.inscrire("talents", PlayerTalentFrame, function()
		return { T.livre, T.barreOnglets, _G.ForeverUITalentsSearchPreview, _G.ForeverUITalentsSearchOptionsList }
	end)

	PlayerTalentFrame:HookScript("OnShow", function()
		T.etoufferWotLK()
		T.leverCroix()
		-- a chaque ouverture, la specialisation active (SetTab(GetActiveTab())) ;
		-- pas quand elle se rouvre pour demander confirmation
		if not T.garderVue then T.vue.groupe, T.vue.pet = nil, false end
		T.maj()
	end)
	PlayerTalentFrame:HookScript("OnHide", function()
		if T.fini or T.confirme or not T.enAttente() then return end
		rouvreur:Show()
	end)
	for _, nom in ipairs({ "PlayerTalentFrame_Refresh", "PlayerTalentFrame_Update" }) do
		if type(_G[nom]) == "function" then
			hooksecurefunc(nom, function()
				T.etoufferWotLK()
				if T.livre:IsVisible() then T.maj() end
			end)
		end
	end
	return livre
end

-- Blizzard_TalentUI se charge a la demande : l'ecran se construit quand il
-- arrive (ou tout de suite s'il est deja la)
local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:RegisterEvent("PLAYER_TALENT_UPDATE")
veille:RegisterEvent("CHARACTER_POINTS_CHANGED")
veille:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
veille:RegisterEvent("PREVIEW_TALENT_POINTS_CHANGED")
veille:RegisterEvent("PREVIEW_PET_TALENT_POINTS_CHANGED")
veille:RegisterEvent("PET_TALENT_UPDATE")
veille:RegisterEvent("UNIT_PET")
veille:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
veille:RegisterEvent("PLAYER_LEVEL_UP")
veille:RegisterEvent("PLAYER_LOGOUT")
veille:RegisterEvent("PLAYER_LEAVING_WORLD")
veille:RegisterEvent("PLAYER_ENTERING_WORLD")
veille:SetScript("OnEvent", function(_, ev, arg1)
	if ev == "ADDON_LOADED" then
		if arg1 == "Blizzard_TalentUI" then T.construire() end
		if arg1 == "Blizzard_GlyphUI" and T.livre then T.brancherGlyphes() end
		return
	end
	if ev == "PLAYER_LOGOUT" or ev == "PLAYER_LEAVING_WORLD" then
		T.fini = true
		T.rendreGlyphes()
		return
	end
	if ev == "PLAYER_ENTERING_WORLD" then T.fini = false return end
	if ev == "UNIT_PET" and arg1 ~= "player" then return end
	if T.livre and T.livre:IsVisible() then T.maj() end
end)
if PlayerTalentFrame then T.construire() end
