-- ForeverUI : la barre d'incantation du joueur.
--
-- RELEVE DES SOURCES
--   art      interface/castingbar/uicastingbar.blp : ui-castingbar-frame
--            (214x16) pose par-dessus, ui-castingbar-background (209x11) en
--            fond, et trois remplissages de meme taille --
--            filling-standard, filling-channel, uninterruptable -- plus
--            ui-castingbar-interrupted pour l'echec et ui-castingbar-shield
--            (54x64) pour ce qui ne peut pas etre interrompu.
--   donnees  3.3.5 CastingBarFrame.lua : UnitCastingInfo et UnitChannelInfo
--            rendent nom, texture, debut et fin en millisecondes, et le
--            drapeau "non interruptible". Les evenements sont les
--            UNIT_SPELLCAST_*.
--   sens     une incantation se remplit, un canalisation se vide : c'est la
--            seule difference de calcul entre les deux.
--
-- POSITION : systeme a part entiere, comme dans l'editeur de camelot ou la
-- barre d'incantation se deplace independamment des cadres d'unite.

local BAR_WIDTH, BAR_HEIGHT = 214, 16
local FILL_WIDTH, FILL_HEIGHT = 209, 11

local FILL = {
	standard = "ui-castingbar-filling-standard",
	channel = "ui-castingbar-filling-channel",
	uninterruptible = "ui-castingbar-uninterruptable",
	interrupted = "ui-castingbar-interrupted",
}

local HOLD_AFTER_END = 1.0

local frame = CreateFrame("Frame", "ForeverUICastBar", UIParent)
frame:SetWidth(BAR_WIDTH)
frame:SetHeight(BAR_HEIGHT)
frame:SetFrameStrata("MEDIUM")
frame:Hide()

local background = frame:CreateTexture(nil, "BACKGROUND")
ForeverUI.SetAtlas(background, "ui-castingbar-background")
background:SetPoint("CENTER")

local fill = frame:CreateTexture(nil, "BORDER")
fill:SetPoint("LEFT", background, "LEFT", 0, 0)

local border = frame:CreateTexture(nil, "ARTWORK")
ForeverUI.SetAtlas(border, "ui-castingbar-frame")
border:SetPoint("CENTER")

local shield = frame:CreateTexture(nil, "OVERLAY")
ForeverUI.SetAtlas(shield, "ui-castingbar-shield")
shield:SetPoint("CENTER", frame, "LEFT", 2, -1)
shield:Hide()

local spellText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
spellText:SetPoint("CENTER", frame, "CENTER", 0, 0)

local timeText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
timeText:SetPoint("RIGHT", frame, "RIGHT", -6, 0)

frame.background = background
frame.fill = fill
frame.border = border
frame.shield = shield
frame.spellText = spellText
frame.timeText = timeText

local function stopBar()
	frame.casting = false
	frame.channeling = false
	frame.holdUntil = nil
	frame:Hide()
end

local function showFailure(atlasKey, message)
	frame.casting = false
	frame.channeling = false
	frame.holdUntil = GetTime() + HOLD_AFTER_END
	ForeverUI.SetAtlasFill(fill, FILL[atlasKey], 1, FILL_WIDTH)
	spellText:SetText(message or "")
	timeText:SetText("")
	shield:Hide()
	frame:Show()
end

local function startCast(channel)
	local name, _subtext, text, texture, startTime, endTime, _isTrade, _castID, notInterruptible
	if channel then
		name, _subtext, text, texture, startTime, endTime, _isTrade, notInterruptible = UnitChannelInfo("player")
	else
		name, _subtext, text, texture, startTime, endTime, _isTrade, _castID, notInterruptible = UnitCastingInfo("player")
	end

	if not name then
		stopBar()
		return
	end

	frame.casting = not channel
	frame.channeling = channel and true or false
	frame.startTime = startTime / 1000
	frame.endTime = endTime / 1000
	frame.holdUntil = nil
	frame.fillKey = notInterruptible and "uninterruptible" or (channel and "channel" or "standard")

	spellText:SetText(text or name)
	if notInterruptible then
		shield:Show()
	else
		shield:Hide()
	end
	frame:Show()
end

frame:SetScript("OnEvent", function(_self, event, unit)
	if event == "PLAYER_ENTERING_WORLD" then
		ForeverUI.Suppress(CastingBarFrame)
		stopBar()
		return
	end

	if unit ~= "player" then
		return
	end

	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_DELAYED" then
		startCast(false)
	elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		startCast(true)
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		stopBar()
	elseif event == "UNIT_SPELLCAST_FAILED" then
		showFailure("interrupted", FAILED or "Echec")
	elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
		showFailure("interrupted", INTERRUPTED or "Interrompu")
	elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
		shield:Hide()
		frame.fillKey = frame.channeling and "channel" or "standard"
	elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
		shield:Show()
		frame.fillKey = "uninterruptible"
	end
end)

frame:SetScript("OnUpdate", function(self)
	if self.holdUntil then
		if GetTime() > self.holdUntil then
			stopBar()
		end
		return
	end

	if not (self.casting or self.channeling) then
		return
	end

	local now = GetTime()
	local total = self.endTime - self.startTime
	if total <= 0 then
		stopBar()
		return
	end

	local elapsed = now - self.startTime
	if elapsed < 0 then
		elapsed = 0
	end

	local fraction = elapsed / total
	if fraction > 1 then
		fraction = 1
	end

	-- Une incantation se remplit, une canalisation se vide.
	if self.channeling then
		fraction = 1 - fraction
	end

	ForeverUI.SetAtlasFill(fill, FILL[self.fillKey or "standard"], fraction, FILL_WIDTH)
	timeText:SetText(string.format("%.1f", math.max(0, self.endTime - now)))

	if now >= self.endTime then
		stopBar()
	end
end)

frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("UNIT_SPELLCAST_START")
frame:RegisterEvent("UNIT_SPELLCAST_STOP")
frame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
frame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
frame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")

ForeverUI.CastBar = frame
ForeverUI.Layout.Register(frame, "castbar", "Barre d'incantation", "BOTTOM", "BOTTOM", 0, 190)
