-- ForeverUI : le cadre de cible.
--
-- RELEVE DES SOURCES -- tout ce qui suit vient du code extrait, pas d'une
-- mesure ni d'une estimation.
--
-- mainline/TargetFrame.xml
--   cadre 232 x 100, portrait 58 x 58 ancre TOPRIGHT (-26, -19), art du cadre
--   centre, bandeau de reputation UI-HUD-UnitFrame-Target-PortraitOn-Type
--   ancre TOPRIGHT (-75, -25), cercle de niveau BOTTOMRIGHT (-13, 7).
--
-- mainline/TargetFrame.lua, TargetFrameMixin:CheckClassification
--   C'est le code, et non le XML, qui pose les barres -- il les replace a
--   chaque changement de cible :
--     ordinaire et rare : barre de vie 126 x 20, BOTTOMRIGHT sur le point
--       LEFT du conteneur en (149, -10) ; le point LEFT vaut (0, 50) dans un
--       cadre de 232 x 100, donc le coin bas droit tombe en (149, 40) et le
--       haut de la barre a 40 du haut : TOPLEFT (23, -40).
--     negligeable (minus) : barre 125 x 12 en (148, -1), soit TOPLEFT
--       (23, -39), et la barre de ressource est MASQUEE.
--   La barre de ressource suit le XML : TOPRIGHT sur le BOTTOMRIGHT de la
--   barre de vie en (8, -1), soit TOPLEFT (23, -61) pour 134 x 10.
--   Art du cadre : MinusMob si negligeable, Rare si rare ou rare elite,
--   PortraitOn sinon. Lueur de menace : la variante MinusMob ou la normale.
--
-- camelot/TargetFrameUtils.lua, GetBossPortraitFrameData
--   boss        : Boss-Gold-Winged, ancre TOPRIGHT/TOPRIGHT (11, -4)
--   rare/rare elite : Boss-Rare-Silver-Winged (8, -7)
--   elite       : Boss-Gold (0, 1)
--   et ShouldShowStar rend toujours faux : pas d'etoile sur camelot.
--   NOTE : la variante ailee argentee n'existe pas dans la table d'atlas de ce
--   build du client (seulement en c60) ; on prend donc l'argente simple aux
--   memes decalages, faute de mieux.
--
-- camelot/TargetFrame.lua, TargetFrameMixin:OnLoad et CheckFaction
--   nom : largeur 117, TOPLEFT sur le TOPRIGHT du bandeau en (-133, -1),
--   soit (24, -26) dans le cadre ; niveau centre sur son cercle a (0, -0.5).
--   LA COULEUR DE REACTION VA SUR LE BANDEAU, pas sur la barre de vie :
--   ReputationColor prend UnitSelectionColor, et passe en gris (0.5) avec le
--   portrait quand la cible est verrouillee par quelqu'un d'autre.

local FRAME_WIDTH, FRAME_HEIGHT = 232, 100

local ART = {
	normal = "ui-hud-unitframe-target-portraiton",
	rare = "ui-hud-unitframe-target-rare-portraiton",
	minus = "ui-hud-unitframe-target-minusmob-portraiton",
}
local THREAT_GLOW = {
	normal = "ui-hud-unitframe-target-portraiton-incombat",
	minus = "ui-hud-unitframe-target-minusmob-portraiton-incombat",
}
local HEALTH_FILL = {
	normal = "ui-hud-unitframe-target-portraiton-bar-health",
	minus = "ui-hud-unitframe-target-minusmob-portraiton-bar-health",
}

-- Geometrie posee par CheckClassification, reprise telle quelle.
local BAR_LAYOUT = {
	normal = { health = { 23, -40, 126, 20 }, power = { 23, -61, 134, 10 }, showPower = true },
	minus = { health = { 23, -39, 125, 12 }, power = nil, showPower = false },
}
local POWER_FILL = {
	normal = {
		MANA = "ui-hud-unitframe-target-portraiton-bar-mana",
		RAGE = "ui-hud-unitframe-target-portraiton-bar-rage",
		FOCUS = "ui-hud-unitframe-target-portraiton-bar-focus",
		ENERGY = "ui-hud-unitframe-target-portraiton-bar-energy",
		RUNIC_POWER = "ui-hud-unitframe-target-portraiton-bar-runicpower",
	},
	minus = {
		MANA = "ui-hud-unitframe-target-minusmob-portraiton-bar-mana",
		RAGE = "ui-hud-unitframe-target-minusmob-portraiton-bar-rage",
		FOCUS = "ui-hud-unitframe-target-minusmob-portraiton-bar-focus",
		ENERGY = "ui-hud-unitframe-target-minusmob-portraiton-bar-energy",
		RUNIC_POWER = "ui-hud-unitframe-target-minusmob-portraiton-bar-runicpower",
	},
}

-- Les couleurs de reaction du client 3.3.5 : rouge, orange, jaune, vert.
-- L'elite ne change pas le cadre mais l'anneau du portrait : un dragon dore,
-- argente pour un rare elite, aile pour un boss de monde. C'est la meme
-- logique que BossPortraitFrameTexture dans la source. Feuille :
-- interface/hud/uiunitframeboss.blp.
-- CE SONT LES VARIANTES c60 QU'IL FAUT PRENDRE. Le code camelot demande
-- Boss-Rare-Silver-Winged, un nom qui n'existe QUE sous la forme c60 dans la
-- table d'atlas du client : c'est donc ce jeu-la que camelot utilise. Les
-- variantes de base sont plus petites (80x79 contre 100x100), et comme
-- l'ancrage se fait par le coin haut droit, chacune tombait a cote d'une
-- distance differente -- exactement le defaut constate.
local CLASS_RING = {
	worldboss = { "ui-hud-unitframe-target-portraiton-boss-gold-winged-c60", 11, -4 },
	rareelite = { "ui-hud-unitframe-target-portraiton-boss-rare-silver-winged-c60", 8, -7 },
	rare = { "ui-hud-unitframe-target-portraiton-boss-rare-silver-winged-c60", 8, -7 },
	elite = { "ui-hud-unitframe-target-portraiton-boss-gold-c60", 0, 1 },
}

local REACTION_COLOR = {
	[1] = { 1.0, 0.0, 0.0 },   -- hostile
	[2] = { 1.0, 0.0, 0.0 },
	[3] = { 1.0, 0.5, 0.0 },   -- prudent
	[4] = { 1.0, 1.0, 0.0 },   -- neutre
	[5] = { 0.0, 1.0, 0.0 },   -- amical
	[6] = { 0.0, 1.0, 0.0 },
	[7] = { 0.0, 1.0, 0.0 },
	[8] = { 0.0, 1.0, 0.0 },
}

local frame = CreateFrame("Button", "ForeverUITargetFrame", UIParent, "SecureUnitButtonTemplate")
frame:SetWidth(FRAME_WIDTH)
frame:SetHeight(FRAME_HEIGHT)
frame:SetFrameStrata("LOW")
frame:SetHitRectInsets(20, 20, 16, 17)

frame.unit = "target"
frame:SetAttribute("unit", "target")
frame:SetAttribute("*type1", "target")
frame:SetAttribute("*type2", "menu")
frame:RegisterForClicks("AnyUp")
frame.menu = function(self)
	ForeverUI.MenuUnite.ouvrir(ToggleDropDownMenu, 1, nil, TargetFrameDropDown, self, 120, 10)
end

local portrait = frame:CreateTexture(nil, "BACKGROUND")
portrait:SetWidth(58)
portrait:SetHeight(58)
portrait:SetPoint("TOPRIGHT", -26, -19)

local healthFill = frame:CreateTexture(nil, "BORDER")
healthFill:SetPoint("TOPLEFT", 23, -39)

local powerFill = frame:CreateTexture(nil, "BORDER")
powerFill:SetPoint("TOPLEFT", 23, -60)

local art = frame:CreateTexture(nil, "ARTWORK")
art:SetPoint("CENTER", 0, 0)
ForeverUI.SetAtlas(art, ART.normal)

-- Le bandeau de reputation : c'est LUI qui porte la couleur de reaction.
local reputation = frame:CreateTexture(nil, "BACKGROUND")
reputation:SetPoint("TOPRIGHT", -75, -25)
ForeverUI.SetAtlas(reputation, "ui-hud-unitframe-target-portraiton-type")

-- Comme pour le cadre joueur : tout ce qui doit rester au-dessus de l'art vit
-- dans un cadre fils, jamais dans le meme calque.
local overlayHolder = CreateFrame("Frame", nil, frame)
overlayHolder:SetAllPoints(frame)
overlayHolder:SetFrameLevel(frame:GetFrameLevel() + 1)

local threatGlow = overlayHolder:CreateTexture(nil, "BACKGROUND")
threatGlow:SetPoint("CENTER", frame, "CENTER", 1.5, 1)
ForeverUI.SetAtlas(threatGlow, THREAT_GLOW.normal)
threatGlow:Hide()

-- L'anneau : GetBossPortraitFrameData l'ancre TOPRIGHT sur le TOPRIGHT du
-- conteneur, avec ses propres decalages. Calque : la source le met en
-- ARTWORK sous-niveau 2 du conteneur, donc au-dessus de l'art du cadre et de
-- la lueur de menace, mais SOUS le contenu -- barres, nom et cercle de
-- niveau, qui vivent dans un cadre frere pose par-dessus. Ici : BORDER du
-- porteur, donc au-dessus de la lueur (BACKGROUND) et sous le cercle de
-- niveau (ARTWORK) et le texte (OVERLAY).
local classRing = overlayHolder:CreateTexture(nil, "BORDER")
classRing:Hide()

local levelCircle = overlayHolder:CreateTexture(nil, "ARTWORK")
levelCircle:SetPoint("BOTTOMRIGHT", -13, 7)
ForeverUI.SetAtlas(levelCircle, "ui-hud-unitframe-smallcircle")

local levelText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontNormal")
levelText:SetPoint("CENTER", levelCircle, "CENTER", 0, -0.5)

local nameText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
nameText:SetWidth(117)
nameText:SetHeight(12)
nameText:SetJustifyH("LEFT")
nameText:SetPoint("TOPLEFT", 24, -26)

local healthText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
healthText:SetPoint("CENTER", frame, "TOPLEFT", 23 + 63, -40 - 10)
healthText:Hide()

local powerText = overlayHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
powerText:SetPoint("CENTER", frame, "TOPLEFT", 23 + 67, -61 - 5)
powerText:Hide()

frame.portrait = portrait
frame.healthFill = healthFill
frame.powerFill = powerFill
frame.art = art
frame.threatGlow = threatGlow
frame.classRing = classRing
frame.reputation = reputation
frame.nameText = nameText
frame.levelText = levelText
frame.healthText = healthText
frame.powerText = powerText
frame.overlayHolder = overlayHolder

-- Quelle famille d'art pour cette cible : negligeable, rare, ou ordinaire.
-- Deux choses distinctes : la famille d'art du cadre (ordinaire, rare,
-- negligeable) et l'anneau porte par le portrait (elite, rare, boss).
local function classification()
	return (UnitClassification and UnitClassification("target")) or "normal"
end

local function artKindFor(class)
	if class == "minus" then
		return "minus"
	end
	if class == "rare" or class == "rareelite" then
		return "rare"
	end
	return "normal"
end

-- Eclaircir sans deteindre : on multiplie jusqu'a ce que la composante la
-- plus forte atteigne 1, sans depasser ce que l'image grise retire. Un simple
-- facteur commun ecreterait les couleurs claires -- le brun du guerrier
-- virerait au jaune pale.
-- CheckFaction de camelot : le bandeau prend la couleur de selection, et le
-- bandeau comme le portrait passent au gris quand la cible est verrouillee
-- par quelqu'un d'autre. En 3.3.5 "verrouillee" se lit avec UnitIsTapped et
-- UnitIsTappedByPlayer, la fonction UnitIsTapDenied n'existant pas.
local function updateFaction()
	local tapDenied = UnitIsTapped and UnitIsTapped("target")
		and not UnitIsTappedByPlayer("target") and not UnitPlayerControlled("target")

	if tapDenied then
		reputation:SetVertexColor(0.5, 0.5, 0.5)
		portrait:SetVertexColor(0.5, 0.5, 0.5)
	else
		if UnitSelectionColor then
			reputation:SetVertexColor(UnitSelectionColor("target"))
		end
		portrait:SetVertexColor(1.0, 1.0, 1.0)
	end
end

-- Recopie de TargetFrameMixin:CheckClassification : l'art, la lueur, mais
-- aussi la taille ET la position des barres, que le code repose a chaque fois.
local function updateArt()
	local class = classification()
	local artKind = artKindFor(class)
	local barKind = (artKind == "minus") and "minus" or "normal"
	local layout = BAR_LAYOUT[barKind]

	ForeverUI.SetAtlas(art, ART[artKind] or ART.normal)
	ForeverUI.SetAtlas(threatGlow, THREAT_GLOW[barKind] or THREAT_GLOW.normal)

	healthFill:ClearAllPoints()
	healthFill:SetPoint("TOPLEFT", layout.health[1], layout.health[2])

	if layout.showPower then
		powerFill:ClearAllPoints()
		powerFill:SetPoint("TOPLEFT", layout.power[1], layout.power[2])
		powerFill:Show()
		powerText:Show()
	else
		powerFill:Hide()
		powerText:Hide()
	end

	frame.barKind = barKind
	frame.classification = class
	frame.layout = layout

	local ring = CLASS_RING[class]
	if ring and ForeverUI.SetAtlas(classRing, ring[1]) then
		classRing:ClearAllPoints()
		classRing:SetPoint("TOPRIGHT", frame, "TOPRIGHT", ring[2], ring[3])
		classRing:Show()
	else
		classRing:Hide()
	end
end

local function updateHealth()
	local maximum = UnitHealthMax("target")
	local fraction = 0
	if maximum and maximum > 0 then
		fraction = UnitHealth("target") / maximum
	end
	local layout = frame.layout or BAR_LAYOUT.normal
	ForeverUI.SetAtlasFill(healthFill, HEALTH_FILL[frame.barKind or "normal"], fraction, layout.health[3])
end

local function updatePower()
	local layout = frame.layout or BAR_LAYOUT.normal
	if not layout.showPower then
		powerFill:Hide()
		return
	end

	local powerType, powerToken = UnitPowerType("target")
	local set = POWER_FILL[frame.barKind or "normal"]
	local atlas = set[powerToken or ""] or set.MANA
	local maximum = UnitPowerMax("target", powerType)
	local fraction = 0
	if maximum and maximum > 0 then
		fraction = UnitPower("target", powerType) / maximum
	end
	ForeverUI.SetAtlasFill(powerFill, atlas, fraction, layout.power[3])
end

local function updateTexts()
	local always = GetCVar and GetCVar("targetStatusText") == "1"
	if not (always or frame.hovered) then
		healthText:Hide()
		powerText:Hide()
		return
	end

	local function format(value, maximum)
		if not maximum or maximum <= 0 then
			return ""
		end
		if GetCVarBool and GetCVarBool("statusTextPercentage") then
			return tostring(math.ceil(value / maximum * 100)) .. "%"
		end
		return value .. " / " .. maximum
	end

	local powerType = UnitPowerType("target")
	healthText:SetText(format(UnitHealth("target"), UnitHealthMax("target")))
	powerText:SetText(format(UnitPower("target", powerType), UnitPowerMax("target", powerType)))
	healthText:Show()
	powerText:Show()
end

local function updateName()
	nameText:SetText(UnitName("target"))
end

local function updateLevel()
	local level = UnitLevel("target")
	if level and level > 0 then
		levelText:SetText(level)
	else
		levelText:SetText("??")
	end
end

local function updatePortrait()
	SetPortraitTexture(portrait, "target")
end

-- Menace : la cible tient-elle l'aggro sur quelqu'un. Meme lecture de secours
-- que sur le cadre joueur, les donnees de menace n'etant pas garanties.
local function updateThreat()
	if not UnitExists("target") then
		threatGlow:Hide()
		return
	end

	local status = UnitThreatSituation and UnitThreatSituation("target")
	local engaged = UnitAffectingCombat("target")

	if status and status >= 2 then
		threatGlow:SetVertexColor(1.0, 0.0, 0.0)
		threatGlow:SetAlpha(1.0)
		threatGlow:Show()
	elseif engaged or (status and status > 0) then
		threatGlow:SetVertexColor(1.0, 0.0, 0.0)
		threatGlow:SetAlpha(0.45)
		threatGlow:Show()
	else
		threatGlow:Hide()
	end
end

local function updateAll()
	if not UnitExists("target") then
		return
	end
	updateArt()
	updateFaction()
	updateHealth()
	updatePower()
	updateName()
	updateLevel()
	updatePortrait()
	updateThreat()
	updateTexts()
end

local function hideDefaultTargetFrame()
	if InCombatLockdown() or not TargetFrame then
		return
	end
	ForeverUI.Suppress(TargetFrame)
	ForeverUI.Suppress(ComboFrame)
end

frame:SetScript("OnEnter", function(self)
	self.hovered = true
	updateTexts()
end)

frame:SetScript("OnLeave", function(self)
	self.hovered = false
	updateTexts()
end)

frame:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_ENTERING_WORLD" then
		hideDefaultTargetFrame()
		updateAll()
		return
	end

	if event == "PLAYER_TARGET_CHANGED" then
		updateAll()
		return
	end

	if event == "CVAR_UPDATE" then
		updateTexts()
		return
	end

	if unit ~= "target" then
		return
	end

	if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
		updateHealth()
		updateTexts()
	elseif event == "UNIT_NAME_UPDATE" then
		updateName()
	elseif event == "UNIT_PORTRAIT_UPDATE" then
		updatePortrait()
	elseif event == "UNIT_LEVEL" then
		updateLevel()
	elseif event == "UNIT_CLASSIFICATION_CHANGED" then
		updateArt()
		updateHealth()
		updatePower()
	elseif event == "UNIT_FACTION" then
		updateFaction()
	elseif event == "UNIT_THREAT_SITUATION_UPDATE" then
		updateThreat()
	else
		updatePower()
		updateTexts()
	end
end)

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("CVAR_UPDATE")
frame:RegisterEvent("UNIT_HEALTH")
frame:RegisterEvent("UNIT_MAXHEALTH")
frame:RegisterEvent("UNIT_NAME_UPDATE")
frame:RegisterEvent("UNIT_PORTRAIT_UPDATE")
frame:RegisterEvent("UNIT_LEVEL")
frame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
frame:RegisterEvent("UNIT_FACTION")
frame:RegisterEvent("UNIT_DISPLAYPOWER")
frame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
frame:RegisterEvent("UNIT_MANA")
frame:RegisterEvent("UNIT_RAGE")
frame:RegisterEvent("UNIT_FOCUS")
frame:RegisterEvent("UNIT_ENERGY")
frame:RegisterEvent("UNIT_RUNIC_POWER")
frame:RegisterEvent("UNIT_MAXMANA")
frame:RegisterEvent("UNIT_MAXRAGE")
frame:RegisterEvent("UNIT_MAXFOCUS")
frame:RegisterEvent("UNIT_MAXENERGY")
frame:RegisterEvent("UNIT_MAXRUNIC_POWER")

-- Le cadre n'existe que quand une cible existe : c'est le client qui le
-- montre et le cache, comme pour n'importe quel cadre d'unite securise.
if RegisterUnitWatch then
	RegisterUnitWatch(frame)
end


-- ------------------------------------------------- cible de la cible
-- RELEVE : mainline/TargetFrame.xml TargetofTargetFrameTemplate -- 120 x 49,
-- ancre TOPRIGHT sur le BOTTOMRIGHT du cadre de cible en (12, 10), portrait
-- 37 x 37 en (5, -5), nom a droite du portrait, barre de vie 70 x 10 ancree
-- BOTTOMRIGHT sur le point RIGHT du cadre en (-6, -2.5), soit TOPLEFT (44, -17).

local tot = CreateFrame("Button", "ForeverUITargetOfTarget", frame, "SecureUnitButtonTemplate")
tot:SetWidth(120)
tot:SetHeight(49)
tot:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 12, 10)
tot:SetAttribute("unit", "targettarget")
tot:SetAttribute("*type1", "target")
tot:RegisterForClicks("AnyUp")
tot.unit = "targettarget"

local totPortrait = tot:CreateTexture(nil, "BACKGROUND")
totPortrait:SetWidth(37)
totPortrait:SetHeight(37)
totPortrait:SetPoint("TOPLEFT", 5, -5)

local totHealth = tot:CreateTexture(nil, "BORDER")
totHealth:SetPoint("TOPLEFT", 44, -17)

local totPower = tot:CreateTexture(nil, "BORDER")
totPower:SetPoint("TOPLEFT", 44, -29)

local totArt = tot:CreateTexture(nil, "ARTWORK")
totArt:SetPoint("CENTER")
ForeverUI.SetAtlas(totArt, "ui-hud-unitframe-targetoftarget-portraiton")

local totName = tot:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
totName:SetWidth(68)
totName:SetHeight(10)
totName:SetJustifyH("LEFT")
totName:SetPoint("TOPLEFT", totPortrait, "TOPRIGHT", 2, 0)

local TOT_POWER = {
	MANA = "ui-hud-unitframe-targetoftarget-portraiton-bar-mana",
	RAGE = "ui-hud-unitframe-targetoftarget-portraiton-bar-rage",
	FOCUS = "ui-hud-unitframe-targetoftarget-portraiton-bar-focus",
	ENERGY = "ui-hud-unitframe-targetoftarget-portraiton-bar-energy",
	RUNIC_POWER = "ui-hud-unitframe-targetoftarget-portraiton-bar-runicpower",
}

local function updateTargetOfTarget()
	if not UnitExists("targettarget") then
		return
	end

	local maximum = UnitHealthMax("targettarget")
	local fraction = 0
	if maximum and maximum > 0 then
		fraction = UnitHealth("targettarget") / maximum
	end
	ForeverUI.SetAtlasFill(totHealth, "ui-hud-unitframe-targetoftarget-portraiton-bar-health", fraction)

	local powerType, powerToken = UnitPowerType("targettarget")
	local powerMax = UnitPowerMax("targettarget", powerType)
	local powerFraction = 0
	if powerMax and powerMax > 0 then
		powerFraction = UnitPower("targettarget", powerType) / powerMax
	end
	ForeverUI.SetAtlasFill(totPower, TOT_POWER[powerToken or ""] or TOT_POWER.MANA, powerFraction)

	totName:SetText(UnitName("targettarget"))
	SetPortraitTexture(totPortrait, "targettarget")
end

tot:SetScript("OnEvent", function(_self, event, unit)
	if event == "PLAYER_TARGET_CHANGED" or unit == "target" or unit == "targettarget" then
		updateTargetOfTarget()
	end
end)

tot:RegisterEvent("PLAYER_TARGET_CHANGED")
tot:RegisterEvent("UNIT_TARGET")
tot:RegisterEvent("UNIT_HEALTH")
tot:RegisterEvent("UNIT_MAXHEALTH")

if RegisterUnitWatch then
	RegisterUnitWatch(tot)
end

tot.portrait = totPortrait
tot.healthFill = totHealth
tot.powerFill = totPower
tot.art = totArt
tot.nameText = totName
ForeverUI.TargetOfTarget = tot
ForeverUI.TargetOfTargetUpdate = updateTargetOfTarget

ForeverUI.TargetFrame = frame
ForeverUI.Layout.Register(frame, "targetframe", "Cadre de cible", "TOPLEFT", "TOPLEFT", 250, -10)
