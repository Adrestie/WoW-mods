-- ForeverUI : la cabine d'essayage (DressUpFrame), a la DA de camelot
-- (demande de l'utilisateur, 2026-09-28 : « fait le reste des fenetres
-- secondaires », etape 2).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (DressUpFrame.xml / .lua de 3.3.5) :
--   DressUpFrame 384 x 512, HitRectInsets (0, 30, 0, 45) ; art de la feuille
--     (UI-Character-General-Top*, SkillFrame-Bot*, quatre textures sans
--     nom) ; DressUpFramePortrait 60 x 60 a (7, -6), le joueur
--     (SetPortraitTexture a l'ouverture) ; DressUpFrameTitleText
--     (DRESSUP_FRAME) et DressUpFrameDescriptionText (les instructions) ;
--   le fond de la race : DressUpBackgroundTopLeft 256 x 255 a (22, -76),
--     TopRight 62 x 255, BotLeft 256 x 128, BotRight 62 x 128, en OVERLAY,
--     poses par SetDressUpBackground au chargement ;
--   DressUpModel 316 x 331 a BOTTOM (-11, 105), ses deux fleches 35 x 35 ;
--   DressUpFrameCloseButton ; Cancel et Reset (UIPanelButtonTemplate
--     80 x 22) a (305, -422), Reset a sa gauche.
--
-- RELEVE -- CAMELOT (blizzard_uipanels_game/mainline/dressupframes.xml,
-- blizzard_sharedxmlgame/dressupmodelframemixin.lua ; camelot/
-- dressupframesoverrides.lua : pas de fond de classe, celui de la race) :
--   DressUpFrame : ButtonFrameTemplateMinimizable 450 x 545 (agrandi),
--     portrait du joueur, titre DRESSUP_FRAME ; encart de (4, -60) a
--     (-6, 26) ;
--   ModelScene de (7, -63) a (-9, 28) ; son fond, la race :
--     BGTopLeft du TOPLEFT au TOPRIGHT (-85), 348 de haut ; BGTopRight
--     85 x 348 ; BGBottomLeft et BGBottomRight 175 de haut dessous ;
--     ControlFrame a TOP (0, -10) de la scene ;
--   DressUpFrameCancelButton 80 x 22 a BOTTOMRIGHT (-7, 4), ResetButton
--     80 x 22 a sa gauche.
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee » : le modele, ses
-- fleches, les boutons et le fond de la race sont ceux du client, reposes.
--   ECART : les deux morceaux du bas du fond sont rognes a la scene (106 des
--   175 de camelot, 106 / 175 de leur image) : poses a 175, ils sortiraient
--   de la fenetre.
--   Le controle de la scene (zoom, rotation, remise) n'existe pas en 3.3.5 :
--   ses deux fleches de rotation prennent sa place, centrees a TOP (0, -10)
--   de la scene, a 4 l'une de l'autre, et le modele tourne aussi a la souris
--   (bouton gauche maintenu), comme la feuille du personnage.
--   Portrait : la regle VALIDEE du portrait d'unite (Inspect.lua, demande du
--   28/09) -- 48 de cote a (1, 1,5), centre sur le trou de l'anneau ; en 60 a
--   (-5, 7), le disque depassait du metal.
--   Les instructions de 3.3.5 (DressUpFrameDescriptionText) s'eteignent :
--   camelot n'en montre pas.
--   Pas ajoutes, faute d'equivalent en 3.3.5 : la reduction de la fenetre,
--   les ensembles de transmogrification (menu, liste des apparences, lien).

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local D = {}
ForeverUI.Cabine = D

local SEP = string.char(92)

local N = {
	fenetre = { 450, 545 },
	portrait = { cote = 48, x = 1, y = 1.5 },
	encart = { 4, -60, -6, 26 },
	scene = { 7, -63, -9, 28 },
	fond = { droite = 85, haut = 348, bas = 175 },
	fleches = { y = -10, ecart = 4 },
	bouton = { 80, 22 }, annuler = { -7, 4 },
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

function D.Portrait()
	local habit = DressUpFrame and DressUpFrame.foreverHabit
	if habit then SetPortraitTexture(habit.portrait, "player") end
end

function D.Habiller()
	local f = DressUpFrame
	if not f or f.foreverHabit then return end
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	-- l'art de 3.3.5 : les quatre morceaux sans nom, le portrait, les textes
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" and not r:GetName() then
			r:SetAlpha(0)
		end
	end
	for _, r in ipairs({ DressUpFramePortrait, DressUpFrameTitleText, DressUpFrameDescriptionText }) do
		r:SetAlpha(0)
	end
	local habit = Gb.FenetrePortrait(f, {
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = DRESSUP_FRAME,
	})
	f.foreverHabit = habit
	-- l'encart de ButtonFrameTemplate : marbre et lisere, en regions
	local E = N.encart
	local rect = CreateFrame("Frame", nil, f)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", E[1], E[2])
	rect:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", E[3], E[4])
	local marbre = f:CreateTexture(nil, "BACKGROUND")
	marbre:SetTexture("interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-marble", true)
	if marbre.SetHorizTile then marbre:SetHorizTile(true) marbre:SetVertTile(true) end
	marbre:SetAllPoints(rect)
	habit.encadre = Gb.NeufTranches(f, "InsetFrameTemplate", rect)
	habit.marbre = marbre
	-- la scene : le modele, et le fond de la race dessous
	local S = N.scene
	local scene = CreateFrame("Frame", nil, f)
	scene:SetPoint("TOPLEFT", f, "TOPLEFT", S[1], S[2])
	scene:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", S[3], S[4])
	habit.scene = scene
	local F = N.fond
	local visible = (N.fenetre[2] + S[2] - S[4]) - F.haut
	poser(DressUpBackgroundTopLeft, "TOPLEFT", scene, "TOPLEFT", 0, 0)
	DressUpBackgroundTopLeft:SetPoint("TOPRIGHT", scene, "TOPRIGHT", -F.droite, 0)
	DressUpBackgroundTopLeft:SetHeight(F.haut)
	poser(DressUpBackgroundTopRight, "TOPRIGHT", scene, "TOPRIGHT", 0, 0)
	DressUpBackgroundTopRight:SetWidth(F.droite)
	DressUpBackgroundTopRight:SetHeight(F.haut)
	poser(DressUpBackgroundBotLeft, "TOPLEFT", DressUpBackgroundTopLeft, "BOTTOMLEFT", 0, 0)
	DressUpBackgroundBotLeft:SetPoint("TOPRIGHT", DressUpBackgroundTopLeft, "BOTTOMRIGHT", 0, 0)
	poser(DressUpBackgroundBotRight, "TOPRIGHT", DressUpBackgroundTopRight, "BOTTOMRIGHT", 0, 0)
	DressUpBackgroundBotRight:SetWidth(F.droite)
	for _, t in ipairs({ DressUpBackgroundBotLeft, DressUpBackgroundBotRight }) do
		t:SetHeight(visible)
		t:SetTexCoord(0, 1, 0, visible / F.bas)
	end
	poser(DressUpModel, "TOPLEFT", scene, "TOPLEFT", 0, 0)
	DressUpModel:SetPoint("BOTTOMRIGHT", scene, "BOTTOMRIGHT", 0, 0)
	local gauche, droite = DressUpModelRotateLeftButton, DressUpModelRotateRightButton
	local demi = gauche:GetWidth() / 2 + N.fleches.ecart / 2
	poser(gauche, "TOP", scene, "TOP", -demi, N.fleches.y)
	poser(droite, "TOP", scene, "TOP", demi, N.fleches.y)
	ForeverUI.TournerALaSouris(DressUpModel)
	-- la croix, au-dessus du metal ; les deux boutons de camelot
	Gb.Croix(DressUpFrameCloseButton, f)
	DressUpFrameCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	for _, b in ipairs({ DressUpFrameCancelButton, DressUpFrameResetButton }) do
		b:SetWidth(N.bouton[1])
		b:SetHeight(N.bouton[2])
		Gb.BoutonPanneau(b)
	end
	poser(DressUpFrameCancelButton, "BOTTOMRIGHT", f, "BOTTOMRIGHT", N.annuler[1], N.annuler[2])
	poser(DressUpFrameResetButton, "RIGHT", DressUpFrameCancelButton, "LEFT", 0, 0)
	f:HookScript("OnShow", D.Portrait)
	D.Portrait()
end

D.Habiller()
