-- ForeverUI : positions modifiables.
--
-- POURQUOI CE FICHIER EXISTE AVANT LES CADRES. Sur camelot, aucun element
-- d'interface n'a de position figee : chacun est un "systeme" que le joueur
-- deplace, et sa position est retenue. On reprend le principe ici : tout ce que
-- ForeverUI construit s'enregistre avec une position par defaut, et c'est cette
-- table qui decide ou le cadre se pose au chargement. Un cadre qui poserait
-- lui-meme son SetPoint definitif serait le seul a ne pas etre deplacable.
--
-- Tout est ancre a UIParent, jamais a un autre cadre de ForeverUI : sinon
-- deplacer un element en entrainerait un autre, et le joueur ne pourrait plus
-- defaire l'enchainement.

ForeverUI = ForeverUI or {}

-- Neutraliser un cadre du client. Le masquer ne suffit pas : son propre code
-- le reaffiche a la premiere occasion (changement de page, sortie de vehicule,
-- mise a jour de runes). On coupe donc ses evenements, on le masque, et on
-- accroche son OnShow pour qu'il se remasque si quelque chose insiste.
function ForeverUI.Suppress(frame)
	if not frame or frame.foreverSuppressed then
		return
	end

	if frame.UnregisterAllEvents then
		frame:UnregisterAllEvents()
	end
	frame:Hide()

	if frame.HookScript then
		frame:HookScript("OnShow", function(self)
			self:Hide()
		end)
	end

	frame.foreverSuppressed = true
end

local Layout = {}
ForeverUI.Layout = Layout

Layout.systems = {}   -- id -> { frame, label, defaults }
Layout.order = {}     -- ids, dans l'ordre d'enregistrement
Layout.editing = false

local PREFIX = "|cff66ccffForeverUI|r : "
local L = ForeverUI.L

local function say(message)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

local function positions()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

-- Pose le cadre a sa position retenue, ou a sa position par defaut.
function Layout.Apply(id)
	local system = Layout.systems[id]
	if not system then
		return false
	end

	local saved = positions()[id]
	local p = saved or system.defaults

	system.frame:ClearAllPoints()
	system.frame:SetPoint(p.point, UIParent, p.relativePoint, p.x, p.y)
	return true
end

function Layout.Save(id)
	local system = Layout.systems[id]
	if not system then
		return false
	end

	local point, _relativeTo, relativePoint, x, y = system.frame:GetPoint(1)
	if not point then
		return false
	end

	positions()[id] = {
		point = point,
		relativePoint = relativePoint or point,
		x = x or 0,
		y = y or 0,
	}
	return true
end

function Layout.Reset(id)
	if id then
		if not Layout.systems[id] then
			return false
		end
		positions()[id] = nil
		Layout.Apply(id)
		return true
	end

	for _, systemID in ipairs(Layout.order) do
		positions()[systemID] = nil
		Layout.Apply(systemID)
	end
	return true
end

-- L'enregistrement fait tout : rendre le cadre deplacable, le poser, et le
-- rendre visible en mode edition.
function Layout.Register(frame, id, label, point, relativePoint, x, y)
	Layout.systems[id] = {
		frame = frame,
		label = label,
		defaults = { point = point, relativePoint = relativePoint, x = x, y = y },
	}
	table.insert(Layout.order, id)

	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	Layout.Apply(id)

	if Layout.editing then
		Layout.ShowOverlay(id)
	end
	return frame
end

-- Corriger la position par defaut d'un element deja enregistre. Le bas de
-- l'ecran est une chaine : la barre d'action et les sacs se posent de part et
-- d'autre du micro-menu, dont la largeur n'est connue qu'une fois ses boutons
-- comptes. Un element que le joueur a deja deplace garde sa position.
function Layout.SetDefaults(id, point, relativePoint, x, y)
	local system = Layout.systems[id]
	if not system then
		return false
	end

	system.defaults = { point = point, relativePoint = relativePoint, x = x, y = y }
	if not positions()[id] then
		Layout.Apply(id)
	end
	return true
end

local function buildOverlay(id, system)
	local overlay = CreateFrame("Frame", nil, system.frame)
	overlay:SetAllPoints(system.frame)
	overlay:SetFrameStrata("DIALOG")
	overlay:EnableMouse(true)
	overlay:RegisterForDrag("LeftButton")

	local background = overlay:CreateTexture(nil, "BACKGROUND")
	background:SetAllPoints(overlay)
	background:SetTexture(0.1, 0.6, 1, 0.35)

	local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	text:SetPoint("CENTER")
	text:SetText(system.label)

	overlay:SetScript("OnDragStart", function()
		if InCombatLockdown() then
			say(L.LAYOUT_NO_MOVE_IN_COMBAT)
			return
		end
		system.frame:StartMoving()
	end)

	overlay:SetScript("OnDragStop", function()
		system.frame:StopMovingOrSizing()
		Layout.Save(id)
	end)

	system.overlay = overlay
	return overlay
end

function Layout.ShowOverlay(id)
	local system = Layout.systems[id]
	if not system then
		return
	end

	local overlay = system.overlay or buildOverlay(id, system)
	overlay:Show()
end

function Layout.HideOverlay(id)
	local system = Layout.systems[id]
	if system and system.overlay then
		system.overlay:Hide()
	end
end

function Layout.SetEditMode(enabled)
	if enabled and InCombatLockdown() then
		say(L.LAYOUT_EDIT_MODE_COMBAT)
		return false
	end

	Layout.editing = enabled and true or false

	for _, id in ipairs(Layout.order) do
		if Layout.editing then
			Layout.ShowOverlay(id)
		else
			Layout.HideOverlay(id)
		end
	end

	if Layout.editing then
		say(L.LAYOUT_EDIT_MODE_ON)
	else
		say(L.LAYOUT_EDIT_MODE_OFF)
	end
	return true
end

-- Le mode edition se coupe tout seul a l'entree en combat : un cadre securise
-- ne peut plus etre deplace a ce moment, et laisser les surfaces bleues
-- affichees ferait croire le contraire.
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_REGEN_DISABLED")
watcher:SetScript("OnEvent", function(_self, event)
	if event == "PLAYER_LOGIN" then
		for _, id in ipairs(Layout.order) do
			Layout.Apply(id)
		end
	elseif event == "PLAYER_REGEN_DISABLED" and Layout.editing then
		Layout.SetEditMode(false)
	end
end)

-- /fui souris : tant qu'il est actif, chaque clic dit dans le chat quel cadre
-- est sous la souris (GetMouseFocus), ses parents et ses images -- pour
-- trouver d'ou vient un element de l'ecran (2026-09-25 : les portails de la
-- carte du monde, qui ne sont pas des reperes du client)
local espion = CreateFrame("Frame")
espion:Hide()
local function decrire(cadre)
	if not cadre then return L.LAYOUT_SPY_NOTHING end
	local nom = cadre.GetName and cadre:GetName() or nil
	local type_ = cadre.GetObjectType and cadre:GetObjectType() or "?"
	return (nom or L.LAYOUT_SPY_UNNAMED) .. " [" .. type_ .. "]"
end
espion:SetScript("OnUpdate", function(self)
	local bas = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
	if bas and not self.enfonce then
		local f = GetMouseFocus and GetMouseFocus()
		say(L.LAYOUT_SPY_UNDER_MOUSE .. decrire(f))
		local p, chemin = f and f:GetParent(), {}
		while p and #chemin < 8 do
			table.insert(chemin, decrire(p))
			p = p:GetParent()
		end
		DEFAULT_CHAT_FRAME:AddMessage("   " .. L.LAYOUT_SPY_PARENTS .. table.concat(chemin, " < "))
		if f and f.GetRegions then
			for _, r in ipairs({ f:GetRegions() }) do
				if r.GetTexture and r:GetTexture() then
					DEFAULT_CHAT_FRAME:AddMessage("   " .. L.LAYOUT_SPY_TEXTURE .. tostring(r:GetTexture()))
				elseif r.GetText and r:GetText() then
					DEFAULT_CHAT_FRAME:AddMessage("   " .. L.LAYOUT_SPY_TEXT .. tostring(r:GetText()))
				end
			end
		end
		for _, k in ipairs({ "name", "mapLinkID", "description", "poiID", "instanceID", "mapID" }) do
			if f and f[k] ~= nil then
				DEFAULT_CHAT_FRAME:AddMessage("   ." .. k .. " = " .. tostring(f[k]))
			end
		end
	end
	self.enfonce = bas and true or false
end)
ForeverUI.SourisEspion = espion
ForeverUI.SourisDebug = function()
	if espion:IsShown() then
		espion:Hide()
		say(L.LAYOUT_SPY_STOPPED)
	else
		espion.enfonce = true
		espion:Show()
		say(L.LAYOUT_SPY_STARTED)
	end
end

SLASH_FOREVERUI1 = "/fui"
SLASH_FOREVERUI2 = "/foreverui"

SlashCmdList["FOREVERUI"] = function(message)
	local command, argument = string.match(message or "", "^(%S*)%s*(.*)$")
	argument = argument or ""
	command = string.lower(command or "")

	if command == "" or command == "edit" then
		Layout.SetEditMode(not Layout.editing)
	elseif command == "reset" then
		if argument ~= "" then
			if Layout.Reset(argument) then
				say(L.LAYOUT_RESET_ONE .. argument)
			else
				say(L.LAYOUT_UNKNOWN_ELEMENT .. argument)
			end
		else
			Layout.Reset()
			say(L.LAYOUT_RESET_ALL)
		end
	elseif command == "bar" or command == "barre" then
		if ForeverUI.ActionBarDebug then
			ForeverUI.ActionBarDebug()
		else
			say(L.LAYOUT_NO_DIAG_ACTIONBAR)
		end
	elseif command == "bas" then
		if ForeverUI.BottomBarDebug then
			ForeverUI.BottomBarDebug()
		else
			say(L.LAYOUT_NO_DIAG_BOTTOM)
		end
	elseif command == "barres" then
		if ForeverUI.StatusBarsDebug then
			ForeverUI.StatusBarsDebug()
		else
			say(L.LAYOUT_NO_DIAG_STATUSBARS)
		end
	elseif command == "sacs" then
		local cle, valeur = string.match(argument, "^(%S+)%s+(%S+)$")
		if cle and ForeverUI.BagsSet then
			ForeverUI.BagsSet(cle, valeur)
		elseif ForeverUI.BagsDebug then
			ForeverUI.BagsDebug()
		else
			say(L.LAYOUT_NO_DIAG_BAGS)
		end
	elseif command == "modele" then
		if ForeverUI.CharacterModelTune then
			ForeverUI.CharacterModelTune(argument)
		else
			say(L.LAYOUT_NO_MODEL_TUNE)
		end
	elseif command == "onglets" then
		if ForeverUI.CharacterTabsDebug then
			ForeverUI.CharacterTabsDebug()
		else
			say(L.LAYOUT_NO_DIAG_TABS)
		end
	elseif command == "perso" then
		if ForeverUI.CharacterSheetDebug then
			ForeverUI.CharacterSheetDebug()
		else
			say(L.LAYOUT_NO_DIAG_SHEET)
		end
	elseif command == "croix" then
		if ForeverUI.CharacterCloseDebug then
			ForeverUI.CharacterCloseDebug()
		else
			say(L.LAYOUT_NO_DIAG_SHEET)
		end
	elseif command == "minimap" then
		if ForeverUI.MinimapDebug then
			ForeverUI.MinimapDebug(argument)
		else
			say(L.LAYOUT_NO_DIAG_MINIMAP)
		end
	elseif command == "souris" then
		ForeverUI.SourisDebug()
	elseif command == "carte" then
		if ForeverUI.WorldMapDebug then
			ForeverUI.WorldMapDebug()
		else
			say(L.LAYOUT_NO_DIAG_WORLDMAP)
		end
	elseif command == "journal" then
		if ForeverUI.QuestLogDebug then
			ForeverUI.QuestLogDebug()
		else
			say(L.LAYOUT_NO_DIAG_QUESTLOG)
		end
	elseif command == "suivi" then
		if ForeverUI.ObjectiveTrackerDebug then
			ForeverUI.ObjectiveTrackerDebug()
		else
			say(L.LAYOUT_NO_DIAG_TRACKER)
		end
	elseif command == "grimoire" then
		if ForeverUI.SpellBookDebug then
			ForeverUI.SpellBookDebug()
		else
			say(L.LAYOUT_NO_DIAG_SPELLBOOK)
		end
	elseif command == "micro" then
		if ForeverUI.MicroDebug then
			ForeverUI.MicroDebug()
		else
			say(L.LAYOUT_NO_DIAG_MICROMENU)
		end
	elseif command == "titres" or command == "titles" then
		if ForeverUI.TitlesDebug then
			ForeverUI.TitlesDebug()
		else
			say(L.LAYOUT_NO_DIAG_TITLES)
		end
	elseif command == "pvp" then
		if ForeverUI.PvPDebug then
			-- /fui pvp 0.35 : la jauge circulaire se pose a 35 %, pour la
			-- voir sans avoir a gagner de l'honneur.
			ForeverUI.PvPDebug(tonumber(argument))
		else
			say(L.LAYOUT_NO_DIAG_PVP)
		end
	elseif command == "arene" or command == "arena" then
		if ForeverUI.PvPArenaDebug then
			ForeverUI.PvPArenaDebug()
		else
			say(L.LAYOUT_NO_DIAG_ARENA)
		end
	elseif command == "tabard" then
		if ForeverUI.TabardModelTune then
			ForeverUI.TabardModelTune(argument)
		end
	elseif command == "chat" then
		if ForeverUI.ChatDebug then
			ForeverUI.ChatDebug()
		else
			say(L.LAYOUT_NO_DIAG_CHAT)
		end
	elseif command == "chatlignes" then
		if ForeverUI.ChatReleveLignes then
			ForeverUI.ChatReleveLignes()
		else
			say(L.LAYOUT_NO_CHAT_LINES)
		end
	elseif command == "buffs" then
		if ForeverUI.BuffsDebug then
			ForeverUI.BuffsDebug()
		else
			say(L.LAYOUT_NO_DIAG_BUFFS)
		end
	elseif command == "chercheur" then
		if ForeverUI.GroupFinderDebug then
			ForeverUI.GroupFinderDebug()
		else
			say(L.LAYOUT_NO_DIAG_GROUPFINDER)
		end
	elseif command == "social" then
		if ForeverUI.SocialDebug then
			ForeverUI.SocialDebug()
		else
			say(L.LAYOUT_NO_DIAG_SOCIAL)
		end
	elseif command == "bg" then
		if ForeverUI.PvPBattlegroundsDebug then
			ForeverUI.PvPBattlegroundsDebug()
		else
			say(L.LAYOUT_NO_DIAG_BATTLEGROUNDS)
		end
	elseif command == "familier" then
		if ForeverUI.PetDebug then
			ForeverUI.PetDebug()
		else
			say(L.LAYOUT_NO_DIAG_PET)
		end
	elseif command == "monnaie" or command == "monnaies" then
		if ForeverUI.TokensDebug then
			ForeverUI.TokensDebug()
		else
			say(L.LAYOUT_NO_DIAG_CURRENCY)
		end
	elseif command == "skills" then
		if ForeverUI.SkillsDebug then
			ForeverUI.SkillsDebug()
		else
			say(L.LAYOUT_NO_DIAG_SKILLS)
		end
	elseif command == "reput" then
		if ForeverUI.ReputationDebug then
			-- /fui reput Alliance : ne garde que cette faction-la.
			ForeverUI.ReputationDebug(argument ~= "" and argument or nil)
		else
			say(L.LAYOUT_NO_DIAG_REPUTATION)
		end
	elseif command == "sets" then
		if ForeverUI.EquipmentSetsDebug then
			ForeverUI.EquipmentSetsDebug()
		else
			say(L.LAYOUT_NO_DIAG_SETS)
		end
	elseif command == "debug" then
		if ForeverUI.PlayerFrameDebug then
			ForeverUI.PlayerFrameDebug()
		else
			say(L.LAYOUT_NO_DIAG)
		end
	elseif command == "list" then
		say(L.LAYOUT_LIST_HEADER)
		for _, id in ipairs(Layout.order) do
			local system = Layout.systems[id]
			local saved = positions()[id]
			DEFAULT_CHAT_FRAME:AddMessage(string.format("   %s (%s)%s", id, system.label,
				saved and L.LAYOUT_LIST_MOVED or ""))
		end
	else
		say(L.LAYOUT_HELP)
	end
end
