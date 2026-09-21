-- ForeverUI : les runes du chevalier de la mort.
--
-- RELEVE DES SOURCES
--   art        mainline/RuneFrame.xml : un bouton de 24x24 empile, du fond
--              vers l'avant, UF-DKRunes-BGShadow (centre, y -3), BGDis ou
--              BGActive, le crane SkullDis ou <type>-SkullActive, puis la
--              lueur <type>-FilledGlwA. Toutes ces images sont sur la feuille
--              interface/hud/uideathknightrunes.blp.
--   donnees    3.3.5 RuneFrame.lua : GetRuneCooldown(i) rend debut, duree et
--              disponibilite ; GetRuneType(i) rend 1 sang, 2 impie, 3 givre,
--              4 mort. Evenements RUNE_POWER_UPDATE et RUNE_TYPE_UPDATE.
--   cadre      camelot bascule l'art du cadre sur la variante ClassResource
--              des qu'une ressource de classe s'affiche sous les barres.
--   entorse    la source habille le balayage de recharge avec l'atlas
--              UF-DKRunes-<type>-LevelBar ; 3.3.5 n'a ni SetSwipeTexture ni
--              SetTexCoordRange, le balayage reste donc celui du client.
--
-- Le type 4 (rune de mort), propre a 3.3.5, n'a pas d'art dedie sur la feuille
-- moderne : il prend le jeu "default", qui est justement le crane neutre.

local CLASS = select(2, UnitClass("player"))
if CLASS ~= "DEATHKNIGHT" then
	return
end

local frame = ForeverUI.PlayerFrame

-- RELEVE DE PLACEMENT, recopie des deux fichiers
--   mainline/PlayerFrame.xml : PlayerBottomManagedFrameContainer, largeur
--   fixe 160, TOP ancre sur le BOTTOM du cadre joueur en (30, 25).
--   mainline/RuneFrame.xml : RuneFrame 130 x 24, scale 0.95, et ses runes
--   rangees avec un espacement de -1 ; chaque bouton fait 24 x 24, la
--   minuterie 27 x 27 centree.
local RUNE_COUNT = 6
local RUNE_SIZE = 24
local RUNE_SPACING = -1
local COOLDOWN_SIZE = 27
local BAR_WIDTH, BAR_HEIGHT = 130, 24
local BAR_SCALE = 0.95
local CONTAINER_WIDTH = 160

local TYPE_PREFIX = {
	[1] = "blood",
	[2] = "unholy",
	[3] = "frost",
	[4] = "default",
}

-- Le cadre joueur prend sa variante a ressource de classe : elle est trois
-- pixels plus haute et menage la bande ou se posent les runes.
ForeverUI.PlayerFrameSetArt("ui-hud-unitframe-player-portraiton-classresource")

-- Le cadre de runes du client se superposait au notre : il faut le
-- neutraliser, et pas seulement le masquer -- RuneFrame se reaffiche a chaque
-- mise a jour de rune.
ForeverUI.Suppress(RuneFrame)

-- Le conteneur reprend la bande des ressources de classe : il n'est pas mis a
-- l'echelle, sinon son ancrage le serait aussi. C'est la barre de runes qui
-- porte le 0,95 de la source.
local container = CreateFrame("Frame", "ForeverUIClassResourceContainer", frame)
container:SetWidth(CONTAINER_WIDTH)
container:SetHeight(BAR_HEIGHT)
container:SetPoint("TOP", frame, "BOTTOM", 30, 25)
container:SetFrameLevel(frame:GetFrameLevel() + 1)

local runeBar = CreateFrame("Frame", "ForeverUIRuneBar", container)
runeBar:SetWidth(BAR_WIDTH)
runeBar:SetHeight(BAR_HEIGHT)
runeBar:SetScale(BAR_SCALE)
runeBar:SetPoint("CENTER", container, "CENTER", 0, 0)

local buttons = {}

-- Les calques, dans l'ordre et avec les melanges du XML : tous en BLEND, pas
-- un seul en additif. Les calques Mid, Eyes, Glow, Glow2 et Smoke ne servent
-- qu'aux transitions et finissent tous a 0 : ils ne sont pas construits.
for index = 1, RUNE_COUNT do
	local button = CreateFrame("Frame", nil, runeBar)
	button:SetWidth(RUNE_SIZE)
	button:SetHeight(RUNE_SIZE)
	-- six boutons de 24 espaces de -1 : 139 de large, centres dans les 130
	-- declares par la source.
	button:SetPoint("LEFT", runeBar, "LEFT",
		(BAR_WIDTH - (RUNE_COUNT * RUNE_SIZE + (RUNE_COUNT - 1) * RUNE_SPACING)) / 2
		+ (index - 1) * (RUNE_SIZE + RUNE_SPACING), 0)

	button.shadow = button:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(button.shadow, "uf-dkrunes-bgshadow")
	button.shadow:SetPoint("CENTER", 0, -3)

	button.bgInactive = button:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(button.bgInactive, "uf-dkrunes-bgdis")
	button.bgInactive:SetPoint("CENTER")

	button.bgActive = button:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(button.bgActive, "uf-dkrunes-bgactive")
	button.bgActive:SetPoint("CENTER")

	button.runeInactive = button:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(button.runeInactive, "uf-dkrunes-skulldis")
	button.runeInactive:SetPoint("CENTER")

	button.runeGrad = button:CreateTexture(nil, "ARTWORK")
	button.runeGrad:SetPoint("CENTER")

	button.runeLines = button:CreateTexture(nil, "ARTWORK")
	button.runeLines:SetPoint("CENTER")

	button.runeActive = button:CreateTexture(nil, "ARTWORK")
	button.runeActive:SetPoint("CENTER")

	button.cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	button.cooldown:SetWidth(COOLDOWN_SIZE)
	button.cooldown:SetHeight(COOLDOWN_SIZE)
	button.cooldown:SetPoint("CENTER")

	buttons[index] = button
end

-- ALPHAS FINAUX, releves dans les groupes d'animation du XML (setToFinalAlpha) :
--   pret (CooldownEndingAnim) : BG_Active 1, BG_Inactive 0, Rune_Active 1,
--     Rune_Inactive 0, et tout le reste -- lueurs comprises -- a 0.
--   vide (EmptyAnim) : BG_Active 0, BG_Inactive 1, Rune_Active 0,
--     Rune_Inactive 0.4, Rune_Lines 0.
--   en recharge (CooldownFillAnim) : par-dessus l'etat vide, Rune_Grad 0.3 et
--     Rune_Lines 0.3. Rien d'autre ne s'allume.
local function updateRune(index)
	local button = buttons[index]
	if not button then
		return
	end

	local start, duration, ready = GetRuneCooldown(index)
	local prefix = TYPE_PREFIX[GetRuneType(index) or 1] or "default"

	ForeverUI.SetAtlas(button.runeGrad, "uf-dkrunes-" .. prefix .. "-skullgrad")
	ForeverUI.SetAtlas(button.runeLines, "uf-dkrunes-" .. prefix .. "-skulllines")
	ForeverUI.SetAtlas(button.runeActive, "uf-dkrunes-" .. prefix .. "-skullactive")

	if ready then
		button.bgActive:SetAlpha(1)
		button.bgInactive:SetAlpha(0)
		button.runeActive:SetAlpha(1)
		button.runeInactive:SetAlpha(0)
		button.runeGrad:SetAlpha(0)
		button.runeLines:SetAlpha(0)
	else
		button.bgActive:SetAlpha(0)
		button.bgInactive:SetAlpha(1)
		button.runeActive:SetAlpha(0)
		button.runeInactive:SetAlpha(0.4)

		local recharge = (start and duration and duration > 0) and 0.3 or 0
		button.runeGrad:SetAlpha(recharge)
		button.runeLines:SetAlpha(recharge)
	end

	if start and duration and duration > 0 and CooldownFrame_SetTimer then
		CooldownFrame_SetTimer(button.cooldown, start, duration, ready and 0 or 1)
	end

	button.ready = ready and true or false
end

local function updateAllRunes()
	for index = 1, RUNE_COUNT do
		updateRune(index)
	end
end

runeBar:RegisterEvent("PLAYER_ENTERING_WORLD")
runeBar:RegisterEvent("RUNE_POWER_UPDATE")
runeBar:RegisterEvent("RUNE_TYPE_UPDATE")

runeBar:SetScript("OnEvent", function(_self, event, rune)
	if event == "PLAYER_ENTERING_WORLD" then
		ForeverUI.Suppress(RuneFrame)
		updateAllRunes()
	elseif rune then
		updateRune(rune)
	else
		updateAllRunes()
	end
end)

-- La fin d'une recharge ne previent pas toujours : tant qu'une rune tourne, on
-- relit dix fois par seconde. Rien ne tourne quand tout est pret.
runeBar:SetScript("OnUpdate", function(self, elapsed)
	self.elapsed = (self.elapsed or 0) + elapsed
	if self.elapsed < 0.1 then
		return
	end
	self.elapsed = 0

	for index = 1, RUNE_COUNT do
		if not buttons[index].ready then
			updateAllRunes()
			return
		end
	end
end)

updateAllRunes()

ForeverUI.RuneBar = runeBar
ForeverUI.ClassResourceContainer = container
ForeverUI.RuneButtons = buttons
