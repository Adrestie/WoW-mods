-- ForeverUI : la fenetre des hauts faits, deplacable (demande de
-- l'utilisateur, 2026-09-28 : « Hauts faits : ils n'existent pas dans
-- Camelot, rend juste la fenetre deplacable »).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (Blizzard_AchievementUI.xml / .lua de
-- 3.3.5, charge a la demande) :
--   AchievementFrame 768 x 500, non deplacable ; AchievementFrameHeader
--     726 x 106 (souris active), pose au-dessus de la fenetre ;
--   Blizzard_AchievementUI.lua, ligne 1 : UIPanelWindows["AchievementFrame"]
--     = { area = "doublewide", pushable = 0, width = 840, xoffset = 80,
--     whileDead = 1 } -- le systeme de panneaux la repose a gauche
--     (FramePositionDelegate:UpdateUIPanelPositions, UIParent.lua) a chaque
--     ouverture ou fermeture d'un panneau.
--
-- RELEVE -- CAMELOT : blizzard_achievementui.toc ne charge ses fichiers que
-- pour mainline, tbc, wrath, cata et mists -- pas camelot.
--
-- CE QUI EST FAIT. La fenetre garde l'allure de 3.3.5 et reste un panneau
-- (Echap la ferme, elle pousse les autres comme avant). Son en-tete sert de
-- poignee ; la place est retenue dans ForeverUIDB.positions (cle
-- « hautsfaits », haut-centre de la fenetre, comme Superposition.lua) et
-- reposee apres le systeme de panneaux (UpdateUIPanelPositions) et a
-- l'ouverture. Rien n'y est securise : le deplacement marche aussi en
-- combat.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local A = {}
ForeverUI.HautsFaits = A

local CLE = "hautsfaits"

local function positions()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

function A.Reposer()
	local f = AchievementFrame
	local p = positions()[CLE]
	if not f or not p then return end
	f:ClearAllPoints()
	f:SetPoint("TOP", UIParent, "TOP", p.x, p.y)
end

function A.Habiller()
	local f = AchievementFrame
	local poignee = AchievementFrameHeader
	if not f or not poignee or f.foreverDeplacable then return end
	f.foreverDeplacable = true
	f:SetMovable(true)
	f:SetClampedToScreen(true)
	poignee:EnableMouse(true)
	poignee:RegisterForDrag("LeftButton")
	poignee:SetScript("OnDragStart", function()
		f:StartMoving()
	end)
	poignee:SetScript("OnDragStop", function()
		f:StopMovingOrSizing()
		local cx = f:GetCenter()
		local ux = UIParent:GetCenter()
		local x, y = cx - ux, f:GetTop() - UIParent:GetTop()
		f:ClearAllPoints()
		f:SetPoint("TOP", UIParent, "TOP", x, y)
		-- la place est a nous : le client ne la retient pas en plus
		if f.SetUserPlaced then f:SetUserPlaced(false) end
		positions()[CLE] = { x = x, y = y }
	end)
	f:HookScript("OnShow", A.Reposer)
	hooksecurefunc("UpdateUIPanelPositions", function()
		if f:IsShown() then A.Reposer() end
	end)
	A.Reposer()
end

A.Habiller()

local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:SetScript("OnEvent", function(_, _, nom)
	if nom == "Blizzard_AchievementUI" then
		A.Habiller()
	end
end)
