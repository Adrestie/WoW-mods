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
			say("deplacement impossible en combat.")
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
		say("le mode edition n'est pas disponible en combat.")
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
		say("mode edition actif : glissez les elements, /fui pour terminer.")
	else
		say("mode edition termine, positions retenues.")
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
				say("position remise par defaut : " .. argument)
			else
				say("element inconnu : " .. argument)
			end
		else
			Layout.Reset()
			say("toutes les positions sont remises par defaut.")
		end
	elseif command == "bar" or command == "barre" then
		if ForeverUI.ActionBarDebug then
			ForeverUI.ActionBarDebug()
		else
			say("aucun diagnostic de barre disponible.")
		end
	elseif command == "bas" then
		if ForeverUI.BottomBarDebug then
			ForeverUI.BottomBarDebug()
		else
			say("aucun diagnostic du bas de l ecran disponible.")
		end
	elseif command == "barres" then
		if ForeverUI.StatusBarsDebug then
			ForeverUI.StatusBarsDebug()
		else
			say("aucun diagnostic des barres d etat disponible.")
		end
	elseif command == "sacs" then
		local cle, valeur = string.match(argument, "^(%S+)%s+(%S+)$")
		if cle and ForeverUI.BagsSet then
			ForeverUI.BagsSet(cle, valeur)
		elseif ForeverUI.BagsDebug then
			ForeverUI.BagsDebug()
		else
			say("aucun diagnostic des sacs disponible.")
		end
	elseif command == "modele" then
		if ForeverUI.CharacterModelTune then
			ForeverUI.CharacterModelTune(argument)
		else
			say("aucun reglage du modele disponible.")
		end
	elseif command == "perso" then
		if ForeverUI.CharacterSheetDebug then
			ForeverUI.CharacterSheetDebug()
		else
			say("aucun diagnostic de la feuille disponible.")
		end
	elseif command == "reput" then
		if ForeverUI.ReputationDebug then
			ForeverUI.ReputationDebug()
		else
			say("aucun diagnostic de la reputation disponible.")
		end
	elseif command == "sets" then
		if ForeverUI.EquipmentSetsDebug then
			ForeverUI.EquipmentSetsDebug()
		else
			say("aucun diagnostic des ensembles disponible.")
		end
	elseif command == "debug" then
		if ForeverUI.PlayerFrameDebug then
			ForeverUI.PlayerFrameDebug()
		else
			say("aucun diagnostic disponible.")
		end
	elseif command == "list" then
		say("elements enregistres :")
		for _, id in ipairs(Layout.order) do
			local system = Layout.systems[id]
			local saved = positions()[id]
			DEFAULT_CHAT_FRAME:AddMessage(string.format("   %s (%s)%s", id, system.label,
				saved and " - deplace" or ""))
		end
	else
		say("commandes : /fui (mode edition), /fui reset [element], /fui list, /fui debug, /fui barre, /fui bas, /fui barres, /fui sacs, /fui perso, /fui modele, /fui sets, /fui reput")
	end
end
