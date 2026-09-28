-- ForeverUI : l'horloge (TimeManagerFrame), a la DA de camelot (demande de
-- l'utilisateur, 2026-09-28 : « fait le reste des fenetres secondaires »).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (Blizzard_TimeManager.xml / .lua de
-- 3.3.5, charge a la demande) :
--   TimeManagerFrame 256 x 256 a TOPRIGHT (45, -170) : art de la feuille de
--     personnage (UI-Character-General-*, quatre textures sans nom),
--     TimeManagerGlobe 64 x 64 a (6, -4), TimeManagerFrameTicker au centre
--     du globe (-2, 0), titre sans nom TIMEMANAGER_TITLE (GameFontWhite) a
--     TOP (0, -17) ; TimeManagerCloseButton a TOPRIGHT (-46, -8) ;
--   TimeManagerStopwatchFrame a TOPRIGHT (-40, -24), sur le fond
--     UI-QuestItemNameFrame ;
--   TimeManagerAlarmTimeFrame a (25, -80) : trois UIDropDownMenuTemplate
--     (heure, minutes, AM / PM ; UIDropDownMenu_SetWidth 30 ou 40) ;
--   TimeManagerAlarmMessageFrame sous l'heure, champ InputBoxTemplate
--     160 x 20 ;
--   TimeManagerAlarmEnabledButton : UIPanelButtonTemplate 160 x 20 a CENTER
--     (-20, -50), texte ALARM_ENABLED / ALARM_DISABLED et images reposes par
--     TimeManagerAlarmEnabledButton_Update ;
--   deux UICheckButtonTemplate (24 heures a (171, -203), heure locale
--     dessous) ;
--   TimeManagerAlarmAMPMDropDown_OnShow / _OnHide (langues aux AM / PM
--     longs) reancrent le menu AM / PM et ce qui le suit.
--
-- RELEVE -- CAMELOT (blizzard_timemanager/mainline, le [Family] de camelot) :
--   TimeManagerFrame : ButtonFrameTemplate 220 x 240 a TOPRIGHT (-10, -190),
--     sans barre de boutons (ButtonFrameTemplate_HideButtonBar : encart de
--     (4, -60) a (-6, 4)) ; TimeManagerGlobe 64 x 64 a (-6, 9), a la place
--     du portrait ; titre TIMEMANAGER_TITLE (GameFontWhite) a TOP (15, -5) ;
--   TimeManagerStopwatchFrame a TOPRIGHT (10, -12), sans fond ;
--   AlarmTimeFrame a (12, -65) : trois WowStyle1DropdownTemplate de 60, 60
--     et 65, a 5 l'un de l'autre, sous le libelle (0, -4) ;
--   TimeManagerAlarmMessageFrame sous l'heure (0, -5), champ de 190 x 20 ;
--   TimeManagerAlarmEnabledButton : UICheckButtonTemplate 24 x 24 a LEFT
--     (12, -45), texte TIMEMANAGER_ALARM_ENABLED ;
--   24 heures a (185, -190), heure locale dessous (inchange) ;
--   le chronometre (StopwatchFrame) : le meme XML que 3.3.5, rien a faire.
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee » : les cadres et la
-- logique du client restent. Le bouton de l'alarme devient une case : son
-- art de bouton est efface apres chaque mise a jour du client, une case
-- UI-CheckBox (l'art de UICheckButtonTemplate, identique chez camelot) est
-- dessinee dessus, cochee selon timeMgrAlarmEnabled, et son texte reste
-- TIMEMANAGER_ALARM_ENABLED. Les cases a cocher gardent l'art de 3.3.5,
-- comme chez camelot.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local H = {}
ForeverUI.Horloge = H

local SEP = string.char(92)

local N = {
	fenetre = { 220, 240 }, place = { -10, -190 },
	portrait = { cote = 64, x = -6, y = 9 },
	titre = { 15, -5 },
	encart = { 4, -60, -6, 4 },
	chrono = { 10, -12 },
	alarme = { 12, -65 },
	menus = { heure = 60, minute = 60, ampm = 65, ecart = 5, sousLibelle = -4 },
	message = { y = -5, champ = 190 },
	activer = { x = 12, y = -45, cote = 24, texte = -2 },
	militaire = { 185, -190 },
}

local function poser(r, ...)
	r:ClearAllPoints()
	r:SetPoint(...)
end

-- la place de chaque commande ; reprise apres le client, qui reancre le menu
-- AM / PM et ce qui le suit (TimeManagerAlarmAMPMDropDown_OnShow / _OnHide)
function H.Placer()
	local f = TimeManagerFrame
	local M = N.menus
	poser(TimeManagerStopwatchFrame, "TOPRIGHT", f, "TOPRIGHT", N.chrono[1], N.chrono[2])
	poser(TimeManagerAlarmTimeFrame, "TOPLEFT", f, "TOPLEFT", N.alarme[1], N.alarme[2])
	poser(TimeManagerAlarmHourDropDown, "TOPLEFT", TimeManagerAlarmTimeLabel, "BOTTOMLEFT", 0, M.sousLibelle)
	poser(TimeManagerAlarmMinuteDropDown, "LEFT", TimeManagerAlarmHourDropDown, "RIGHT", M.ecart, 0)
	poser(TimeManagerAlarmAMPMDropDown, "LEFT", TimeManagerAlarmMinuteDropDown, "RIGHT", M.ecart, 0)
	poser(TimeManagerAlarmMessageFrame, "TOPLEFT", TimeManagerAlarmHourDropDown, "BOTTOMLEFT", 0, N.message.y)
	poser(TimeManagerAlarmEnabledButton, "LEFT", f, "LEFT", N.activer.x, N.activer.y)
	poser(TimeManagerMilitaryTimeCheck, "TOPLEFT", f, "TOPLEFT", N.militaire[1], N.militaire[2])
end

-- la case de l'alarme, apres TimeManagerAlarmEnabledButton_Update : l'art de
-- bouton que le client vient de poser s'efface, la coche suit le reglage
function H.PeindreAlarme()
	local b = TimeManagerAlarmEnabledButton
	if not b or not b.foreverCase then return end
	for _, lire in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture" }) do
		local t = b[lire](b)
		if t then
			t:SetTexture(nil)
			t:SetAlpha(0)
		end
	end
	b:SetNormalFontObject(GameFontNormalSmall)
	b:SetHighlightFontObject(GameFontNormalSmall)
	b:SetText(TIMEMANAGER_ALARM_ENABLED)
	Gb.Montrer(b.foreverCoche, GetCVar("timeMgrAlarmEnabled") == "1")
end

local function habillerAlarme()
	local b = TimeManagerAlarmEnabledButton
	local A = N.activer
	b:SetWidth(A.cote)
	b:SetHeight(A.cote)
	local case = b:CreateTexture(nil, "ARTWORK")
	case:SetTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-CheckBox-Up")
	case:SetAllPoints(b)
	local coche = b:CreateTexture(nil, "OVERLAY")
	coche:SetTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-CheckBox-Check")
	coche:SetAllPoints(b)
	b.foreverCase, b.foreverCoche = case, coche
	b:SetHighlightTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-CheckBox-Highlight")
	local lueur = b:GetHighlightTexture()
	lueur:SetTexCoord(0, 1, 0, 1)
	lueur:ClearAllPoints()
	lueur:SetAllPoints(b)
	lueur:SetBlendMode("ADD")
	b:HookScript("OnMouseDown", function()
		case:SetTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-CheckBox-Down")
	end)
	b:HookScript("OnMouseUp", function()
		case:SetTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-CheckBox-Up")
	end)
	local texte = b:GetFontString()
	if texte then
		poser(texte, "LEFT", b, "RIGHT", A.texte, 0)
	end
	hooksecurefunc("TimeManagerAlarmEnabledButton_Update", H.PeindreAlarme)
	H.PeindreAlarme()
end

function H.Habiller()
	local f = TimeManagerFrame
	if not f or f.foreverHabit then return end
	f:SetWidth(N.fenetre[1])
	f:SetHeight(N.fenetre[2])
	poser(f, "TOPRIGHT", UIParent, "TOPRIGHT", N.place[1], N.place[2])
	-- l'art de 3.3.5 : les quatre morceaux sans nom, le titre sans nom, le
	-- globe (repris en portrait), le fond du chronometre
	for _, r in ipairs({ f:GetRegions() }) do
		local genre = r:GetObjectType()
		if genre == "Texture" then
			r:SetAlpha(0)
		elseif genre == "FontString" and r:GetText() == TIMEMANAGER_TITLE then
			r:SetAlpha(0)
		end
	end
	poser(TimeManagerGlobe, "TOPLEFT", f, "TOPLEFT", N.portrait.x, N.portrait.y)
	TimeManagerStopwatchFrameBackground:SetAlpha(0)
	local habit = Gb.FenetrePortrait(f, {
		portrait = "Interface" .. SEP .. "TimeManager" .. SEP .. "GlobeIcon",
		portraitCote = N.portrait.cote, portraitX = N.portrait.x, portraitY = N.portrait.y,
		titre = TIMEMANAGER_TITLE,
	})
	f.foreverHabit = habit
	habit.titre:SetFontObject(GameFontWhite)
	poser(habit.titre, "TOP", f, "TOP", N.titre[1], N.titre[2])
	-- l'heure, au-dessus du globe et du metal
	habit.heure = Gb.Recopier(TimeManagerFrameTicker, habit.metal, GameFontHighlightLarge)
	-- l'encart, sans barre de boutons
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
	-- la croix, au-dessus du metal
	Gb.Croix(TimeManagerCloseButton, f)
	TimeManagerCloseButton:SetFrameLevel(f:GetFrameLevel() + 22)
	-- les trois menus et le champ du message
	local M = N.menus
	Gb.MenuStyle1(TimeManagerAlarmHourDropDown, M.heure)
	Gb.MenuStyle1(TimeManagerAlarmMinuteDropDown, M.minute)
	Gb.MenuStyle1(TimeManagerAlarmAMPMDropDown, M.ampm)
	TimeManagerAlarmMessageEditBox:SetWidth(N.message.champ)
	ForeverUI.Social.habillerSaisie(TimeManagerAlarmMessageEditBox)
	habillerAlarme()
	H.Placer()
	f:HookScript("OnShow", H.Placer)
	TimeManagerAlarmAMPMDropDown:HookScript("OnShow", H.Placer)
	TimeManagerAlarmAMPMDropDown:HookScript("OnHide", H.Placer)
end

H.Habiller()

local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:SetScript("OnEvent", function(_, _, nom)
	if nom == "Blizzard_TimeManager" then
		H.Habiller()
	end
end)
