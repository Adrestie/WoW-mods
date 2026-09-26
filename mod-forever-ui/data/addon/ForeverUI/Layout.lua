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

-- /fui souris : tant qu'il est actif, chaque clic dit dans le chat quel cadre
-- est sous la souris (GetMouseFocus), ses parents et ses images -- pour
-- trouver d'ou vient un element de l'ecran (2026-09-25 : les portails de la
-- carte du monde, qui ne sont pas des reperes du client)
local espion = CreateFrame("Frame")
espion:Hide()
local function decrire(cadre)
	if not cadre then return "rien" end
	local nom = cadre.GetName and cadre:GetName() or nil
	local type_ = cadre.GetObjectType and cadre:GetObjectType() or "?"
	return (nom or "(sans nom)") .. " [" .. type_ .. "]"
end
espion:SetScript("OnUpdate", function(self)
	local bas = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
	if bas and not self.enfonce then
		local f = GetMouseFocus and GetMouseFocus()
		say("sous la souris : " .. decrire(f))
		local p, chemin = f and f:GetParent(), {}
		while p and #chemin < 8 do
			table.insert(chemin, decrire(p))
			p = p:GetParent()
		end
		DEFAULT_CHAT_FRAME:AddMessage("   parents : " .. table.concat(chemin, " < "))
		if f and f.GetRegions then
			for _, r in ipairs({ f:GetRegions() }) do
				if r.GetTexture and r:GetTexture() then
					DEFAULT_CHAT_FRAME:AddMessage("   image : " .. tostring(r:GetTexture()))
				elseif r.GetText and r:GetText() then
					DEFAULT_CHAT_FRAME:AddMessage("   texte : " .. tostring(r:GetText()))
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
		say("espion de souris arrete.")
	else
		espion.enfonce = true
		espion:Show()
		say("espion de souris : cliquez sur l'element voulu ; /fui souris pour arreter.")
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
	elseif command == "onglets" then
		if ForeverUI.CharacterTabsDebug then
			ForeverUI.CharacterTabsDebug()
		else
			say("aucun diagnostic des onglets disponible.")
		end
	elseif command == "perso" then
		if ForeverUI.CharacterSheetDebug then
			ForeverUI.CharacterSheetDebug()
		else
			say("aucun diagnostic de la feuille disponible.")
		end
	elseif command == "minimap" then
		if ForeverUI.MinimapDebug then
			ForeverUI.MinimapDebug(argument)
		else
			say("aucun diagnostic de la minimap disponible.")
		end
	elseif command == "souris" then
		ForeverUI.SourisDebug()
	elseif command == "carte" then
		if ForeverUI.WorldMapDebug then
			ForeverUI.WorldMapDebug()
		else
			say("aucun diagnostic de la carte du monde disponible.")
		end
	elseif command == "journal" then
		if ForeverUI.QuestLogDebug then
			ForeverUI.QuestLogDebug()
		else
			say("aucun diagnostic du journal de quetes disponible.")
		end
	elseif command == "suivi" then
		if ForeverUI.ObjectiveTrackerDebug then
			ForeverUI.ObjectiveTrackerDebug()
		else
			say("aucun diagnostic du suivi de quetes disponible.")
		end
	elseif command == "grimoire" then
		if ForeverUI.SpellBookDebug then
			ForeverUI.SpellBookDebug()
		else
			say("aucun diagnostic du grimoire disponible.")
		end
	elseif command == "micro" then
		if ForeverUI.MicroDebug then
			ForeverUI.MicroDebug()
		else
			say("aucun diagnostic du micro-menu disponible.")
		end
	elseif command == "titres" or command == "titles" then
		if ForeverUI.TitlesDebug then
			ForeverUI.TitlesDebug()
		else
			say("aucun diagnostic des titres disponible.")
		end
	elseif command == "pvp" then
		if ForeverUI.PvPDebug then
			-- /fui pvp 0.35 : la jauge circulaire se pose a 35 %, pour la
			-- voir sans avoir a gagner de l'honneur.
			ForeverUI.PvPDebug(tonumber(argument))
		else
			say("aucun diagnostic PvP disponible.")
		end
	elseif command == "arene" or command == "arena" then
		if ForeverUI.PvPArenaDebug then
			ForeverUI.PvPArenaDebug()
		else
			say("aucun diagnostic des equipes d'arene disponible.")
		end
	elseif command == "tabard" then
		if ForeverUI.TabardModelTune then
			ForeverUI.TabardModelTune(argument)
		end
	elseif command == "social" then
		if ForeverUI.SocialDebug then
			ForeverUI.SocialDebug()
		else
			say("aucun diagnostic de la fenetre Social disponible.")
		end
	elseif command == "bg" then
		if ForeverUI.PvPBattlegroundsDebug then
			ForeverUI.PvPBattlegroundsDebug()
		else
			say("aucun diagnostic des champs de bataille disponible.")
		end
	elseif command == "familier" then
		if ForeverUI.PetDebug then
			ForeverUI.PetDebug()
		else
			say("aucun diagnostic du familier disponible.")
		end
	elseif command == "monnaie" or command == "monnaies" then
		if ForeverUI.TokensDebug then
			ForeverUI.TokensDebug()
		else
			say("aucun diagnostic des monnaies disponible.")
		end
	elseif command == "skills" then
		if ForeverUI.SkillsDebug then
			ForeverUI.SkillsDebug()
		else
			say("aucun diagnostic des competences disponible.")
		end
	elseif command == "reput" then
		if ForeverUI.ReputationDebug then
			-- /fui reput Alliance : ne garde que cette faction-la.
			ForeverUI.ReputationDebug(argument ~= "" and argument or nil)
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
		say("commandes : /fui (mode edition), /fui reset [element], /fui list, /fui debug, /fui barre, /fui bas, /fui barres, /fui sacs, /fui perso, /fui onglets, /fui modele, /fui sets, /fui reput [faction], /fui skills, /fui monnaie, /fui familier, /fui pvp [0..1], /fui arene, /fui bg, /fui social, /fui titres, /fui minimap [echelle k], /fui carte, /fui souris, /fui journal, /fui suivi, /fui grimoire, /fui micro")
	end
end
