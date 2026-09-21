-- ForeverUI : les accessoires du cadre joueur.
--
-- Tout ce fichier s'accroche a ForeverUI.PlayerFrame et vit dans son porteur
-- de calques (overlayHolder), donc au-dessus de l'art. Rien n'est ancre ici a
-- UIParent : ces elements appartiennent au cadre et le suivent quand on le
-- deplace, comme dans l'editeur de camelot ou ils font partie du meme systeme.
--
-- RELEVE DES SOURCES (declaration -> ce qui la consomme -> calque) :
--   icone PvP      camelot/PlayerFrame.lua PlayerFrame_ShowPvPIcon : cercle
--                  UI-HUD-UnitFrame-SmallCircle a l'echelle 0.8, ancre TOP sur
--                  le TOPLEFT du cadre en (20, -50), icone de faction centree.
--   groupe         mainline/PlayerFrame.xml GroupIndicator : cadre 10x16 ancre
--                  BOTTOMRIGHT sur TOPLEFT (210, -29), embouts gauche/droite,
--                  piece centrale etiree, texte GameFontHighlightSmall a 0.7.
--                  Contenu : 3.3.5 PlayerFrame_UpdateGroupIndicator, GROUP..
--                  numero de sous-groupe, visible en raid seulement.
--   temps de jeu   mainline/PlayerFrame.xml PlayerPlayTime : 29x29 ancre
--                  TOPLEFT sur TOPRIGHT (-21, -24). Etat : PartialPlayTime()
--                  puis NoPlayTime(), evenement PLAYTIME_CHANGED.
--   degats recus   mainline/PlayerFrame.xml HitIndicator : texte centre sur le
--                  TOPLEFT du cadre en (54, -50), NumberFontNormalHuge. En
--                  3.3.5 c'est CombatFeedback_OnCombatEvent qui l'anime, via
--                  UNIT_COMBAT : on reutilise la fonction du client.

local frame = ForeverUI.PlayerFrame
local holder = frame.overlayHolder

local PVP_CIRCLE = "ui-hud-unitframe-smallcircle"
local PVP_FFA = "ui-hud-unitframe-player-pvp-ffaicon"
local PVP_FACTION = {
	Alliance = "ui-hud-unitframe-smallcircle-alliance",
	Horde = "ui-hud-unitframe-smallcircle-horde",
}
local GROUP_LEFT = "ui-hud-unitframe-player-groupindicatorleft"
local GROUP_RIGHT = "ui-hud-unitframe-player-groupindicatorright"
local GROUP_MID = "_ui-hud-unitframe-player-groupindicatormid"
local PLAYTIME_TIRED_ATLAS = "ui-hud-unitframe-player-playtimetired"
local PLAYTIME_UNHEALTHY_ATLAS = "ui-hud-unitframe-player-playtimeunhealthy"

-- ------------------------------------------------------------------- PvP
local pvpCircle = holder:CreateTexture(nil, "ARTWORK")
ForeverUI.SetAtlas(pvpCircle, PVP_CIRCLE)
pvpCircle:SetPoint("TOP", frame, "TOPLEFT", 20, -50)
pvpCircle:SetWidth(39 * 0.8)
pvpCircle:SetHeight(39 * 0.8)
pvpCircle:Hide()

local pvpIcon = holder:CreateTexture(nil, "OVERLAY")
pvpIcon:SetPoint("CENTER", pvpCircle, "CENTER", 0, 0)
pvpIcon:Hide()

local function updatePvP()
	local faction = UnitFactionGroup("player")

	if UnitIsPVPFreeForAll("player") then
		if ForeverUI.SetAtlas(pvpIcon, PVP_FFA) then
			pvpIcon:SetWidth(24 * 0.8)
			pvpIcon:SetHeight(27 * 0.8)
			pvpCircle:Show()
			pvpIcon:Show()
			return
		end
	elseif faction and faction ~= "Neutral" and UnitIsPVP("player") then
		local atlas = PVP_FACTION[faction]
		if atlas and ForeverUI.SetAtlas(pvpIcon, atlas) then
			pvpIcon:SetWidth(24 * 0.8)
			pvpIcon:SetHeight(27 * 0.8)
			pvpCircle:Show()
			pvpIcon:Show()
			return
		end
	end

	pvpCircle:Hide()
	pvpIcon:Hide()
end

-- --------------------------------------------------------------- groupe
local groupIndicator = CreateFrame("Frame", nil, holder)
groupIndicator:SetWidth(10)
groupIndicator:SetHeight(16)
groupIndicator:SetPoint("BOTTOMRIGHT", frame, "TOPLEFT", 210, -29)
groupIndicator:Hide()

local groupLeft = groupIndicator:CreateTexture(nil, "BACKGROUND")
ForeverUI.SetAtlas(groupLeft, GROUP_LEFT)
groupLeft:SetPoint("TOPLEFT")

local groupRight = groupIndicator:CreateTexture(nil, "BACKGROUND")
ForeverUI.SetAtlas(groupRight, GROUP_RIGHT)
groupRight:SetPoint("TOPRIGHT")

local groupMid = groupIndicator:CreateTexture(nil, "BACKGROUND")
ForeverUI.SetAtlas(groupMid, GROUP_MID, true)
groupMid:SetPoint("LEFT", groupLeft, "RIGHT")
groupMid:SetPoint("RIGHT", groupRight, "LEFT")

local groupText = groupIndicator:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
groupText:SetAlpha(0.7)
groupText:SetPoint("LEFT", 20, 2)

local function updateGroup()
	local members = GetNumRaidMembers and GetNumRaidMembers() or 0
	if members == 0 then
		groupIndicator:Hide()
		return
	end

	local playerName = UnitName("player")
	for index = 1, members do
		local name, _rank, subgroup = GetRaidRosterInfo(index)
		if name == playerName and subgroup then
			groupText:SetText((GROUP or "Groupe") .. " " .. subgroup)
			groupIndicator:SetWidth(groupText:GetWidth() + 40)
			groupIndicator:Show()
			return
		end
	end

	groupIndicator:Hide()
end

-- --------------------------------------------------------- temps de jeu
local playTime = CreateFrame("Frame", nil, holder)
playTime:SetWidth(29)
playTime:SetHeight(29)
playTime:SetPoint("TOPLEFT", frame, "TOPRIGHT", -21, -24)
playTime:EnableMouse(true)
playTime:Hide()

local playTimeIcon = playTime:CreateTexture(nil, "ARTWORK")
playTimeIcon:SetAllPoints(playTime)

playTime:SetScript("OnEnter", function(self)
	if not self.tooltip then
		return
	end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	GameTooltip:SetText(self.tooltip, nil, nil, nil, nil, true)
end)
playTime:SetScript("OnLeave", function()
	GameTooltip:Hide()
end)

local function updatePlayTime()
	if PartialPlayTime and PartialPlayTime() then
		ForeverUI.SetAtlas(playTimeIcon, PLAYTIME_TIRED_ATLAS, true)
		playTime.tooltip = PLAYTIME_TIRED or "Temps de jeu"
		playTime:Show()
	elseif NoPlayTime and NoPlayTime() then
		ForeverUI.SetAtlas(playTimeIcon, PLAYTIME_UNHEALTHY_ATLAS, true)
		playTime.tooltip = PLAYTIME_UNHEALTHY or "Temps de jeu"
		playTime:Show()
	else
		playTime:Hide()
	end
end

-- -------------------------------------------------------- degats recus
local hitText = holder:CreateFontString(nil, "OVERLAY", "NumberFontNormalHuge")
hitText:SetPoint("CENTER", frame, "TOPLEFT", 54, -50)
hitText:Hide()

if CombatFeedback_Initialize then
	CombatFeedback_Initialize(frame, hitText, 30)
end

-- ------------------------------------------------------------- cablage
local extras = CreateFrame("Frame")
extras:RegisterEvent("PLAYER_ENTERING_WORLD")
extras:RegisterEvent("PLAYER_FLAGS_CHANGED")
extras:RegisterEvent("UNIT_FACTION")
extras:RegisterEvent("RAID_ROSTER_UPDATE")
extras:RegisterEvent("PARTY_MEMBERS_CHANGED")
extras:RegisterEvent("PLAYTIME_CHANGED")
extras:RegisterEvent("UNIT_COMBAT")

extras:SetScript("OnEvent", function(_self, event, unit, action, descriptor, damage, damageType)
	if event == "UNIT_COMBAT" then
		if unit == "player" and CombatFeedback_OnCombatEvent then
			CombatFeedback_OnCombatEvent(frame, action, descriptor, damage, damageType)
		end
		return
	end

	if event == "PLAYTIME_CHANGED" then
		updatePlayTime()
		return
	end

	if event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
		updateGroup()
		return
	end

	if event == "UNIT_FACTION" and unit ~= "player" then
		return
	end

	updatePvP()
	if event == "PLAYER_ENTERING_WORLD" then
		updateGroup()
		updatePlayTime()
	end
end)

-- L'animation des degats recus est celle du client : on lui passe la main a
-- chaque image, comme le fait PlayerFrame_OnUpdate.
extras:SetScript("OnUpdate", function(_self, elapsed)
	if CombatFeedback_OnUpdate then
		CombatFeedback_OnUpdate(frame, elapsed)
	end
end)

ForeverUI.PlayerFrameExtras = {
	pvpCircle = pvpCircle,
	pvpIcon = pvpIcon,
	groupIndicator = groupIndicator,
	groupText = groupText,
	playTime = playTime,
	playTimeIcon = playTimeIcon,
	hitText = hitText,
	updatePvP = updatePvP,
	updateGroup = updateGroup,
	updatePlayTime = updatePlayTime,
}
