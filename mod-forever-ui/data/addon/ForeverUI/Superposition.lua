-- ForeverUI : les grandes fenetres qui se superposent (feuille, grimoire,
-- talents).
--
-- LE PROBLEME. Chaque fenetre pose ses cadres a des niveaux explicites
-- (SetFrameLevel), relatifs a sa racine. Deux racines de la meme strate dont
-- les plages de niveaux se chevauchent se melangent a l'ecran : le fond de
-- l'une passe sous les boutons de l'autre. Raise, lui, ne leve que la racine.
--
-- LA REGLE (demande du 2026-09-25) : une fenetre passe ENTIEREMENT au-dessus
-- de l'autre, et cliquer sur une fenetre la ramene au premier plan ; une
-- fenetre qui s'ouvre vient devant.
--
-- LE MOYEN. Les fenetres ouvertes sont empilees de l'arriere vers l'avant :
-- le plus bas cadre de chacune est pose un niveau au-dessus du plus haut
-- cadre de la precedente, et toute sa descendance est decalee d'autant. Le clic se voit
-- a l'image suivante (IsMouseButtonDown), sous la souris (MouseIsOver) : la
-- 3.3.5 n'a pas d'evenement de clic global, et un clic sur un bouton ne
-- remonte pas au cadre qui le porte.
--
-- La fenetre du fond reprend son niveau d'origine : les niveaux ne montent
-- pas d'un clic a l'autre.
--
-- EN COMBAT, une racine protegee (celle du grimoire porte des boutons
-- securises) ne peut pas changer de niveau : elle reste ou elle est, les
-- autres s'empilent autour.

ForeverUI = ForeverUI or {}

local P = { fenetres = {}, ordre = {} }
ForeverUI.Superposition = P

-- le plus haut niveau d'un sous-arbre
local function plusHaut(cadre)
	local n = cadre:GetFrameLevel()
	for _, enfant in ipairs({ cadre:GetChildren() }) do
		local m = plusHaut(enfant)
		if m > n then n = m end
	end
	return n
end

-- le plus bas : un cadre du client peut etre sous sa racine
local function plusBas(cadre)
	local n = cadre:GetFrameLevel()
	for _, enfant in ipairs({ cadre:GetChildren() }) do
		local m = plusBas(enfant)
		if m < n then n = m end
	end
	return n
end

-- les niveaux d'un sous-arbre, parents avant enfants
local function releve(cadre, liste)
	table.insert(liste, { cadre, cadre:GetFrameLevel() })
	for _, enfant in ipairs({ cadre:GetChildren() }) do releve(enfant, liste) end
	return liste
end

-- poser la racine a un niveau, sa descendance suit du meme ecart. Selon le
-- client, SetFrameLevel entraine deja les enfants ou non : on ne repose que
-- ceux qui ne sont pas ou ils doivent etre.
local function poserNiveau(racine, niveau)
	local ecart = niveau - racine:GetFrameLevel()
	if ecart == 0 then return end
	for _, e in ipairs(releve(racine, {})) do
		local voulu = math.max(0, e[2] + ecart)
		if e[1]:GetFrameLevel() ~= voulu then e[1]:SetFrameLevel(voulu) end
	end
end

local function bloquee(f)
	return InCombatLockdown() and f.racine.IsProtected and f.racine:IsProtected()
end

local function ouvertes()
	local l = {}
	for _, cle in ipairs(P.ordre) do
		local f = P.fenetres[cle]
		if f.racine:IsVisible() then table.insert(l, f) end
	end
	return l
end

-- empiler : l'ordre retenu, la fenetre donnee devant
function P.devant(cle)
	local f = P.fenetres[cle]
	if not f then return end
	for i, c in ipairs(P.ordre) do
		if c == cle then table.remove(P.ordre, i) break end
	end
	table.insert(P.ordre, cle)
	local niveau
	for _, g in ipairs(ouvertes()) do
		-- le plus bas cadre de celle-ci juste au-dessus du plus haut de la
		-- precedente
		if not bloquee(g) then
			if niveau then
				poserNiveau(g.racine, g.racine:GetFrameLevel() + niveau - plusBas(g.racine))
			else
				poserNiveau(g.racine, g.base)
			end
		end
		niveau = plusHaut(g.racine) + 1
	end
end

-- la fenetre de devant parmi celles sous la souris
local function sousLaSouris()
	local l = ouvertes()
	for i = #l, 1, -1 do
		for _, zone in ipairs(l[i].zones()) do
			if zone and zone:IsVisible() and MouseIsOver(zone) then return l[i] end
		end
	end
end

-- inscrire une fenetre : sa racine (le cadre dont le niveau bouge) et ses
-- zones (ce qui, a l'ecran, lui appartient -- l'art debordant, les onglets
-- dehors)
function P.inscrire(cle, racine, zones)
	if P.fenetres[cle] then return end
	P.fenetres[cle] = { cle = cle, racine = racine, zones = zones, base = racine:GetFrameLevel() }
	table.insert(P.ordre, cle)
	racine:HookScript("OnShow", function() P.devant(cle) end)
	if racine:IsVisible() then P.devant(cle) end
end

-- le clic, vu a l'image suivante ; rien a faire tant qu'une seule est ouverte
local veille = CreateFrame("Frame")
P.veille = veille
local enfonce = false
veille:SetScript("OnUpdate", function()
	local bas = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")
	if bas and not enfonce then
		local l = ouvertes()
		-- meme la fenetre de devant se repose : le Raise du client (racines
		-- toplevel) ne leve que la racine
		if #l > 1 then
			local f = sousLaSouris()
			if f then P.devant(f.cle) end
		end
	end
	enfonce = bas and true or false
end)

-- ------------------------------------------------------------ le deplacement
-- La barre du titre sert de poignee, comme pour la feuille. La fenetre est
-- reancree par le HAUT-CENTRE : sa largeur change (grimoire reduit, talents
-- du familier) autour de son milieu, comme a sa place d'origine. La place est
-- retenue dans ForeverUIDB, relue a chaque ouverture (les variables sauvees
-- arrivent apres le chargement des fichiers). Hors combat seulement : le
-- grimoire porte des boutons securises.
local function positions()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

function P.deplacable(cadre, poignee, cle)
	cadre:SetMovable(true)
	cadre:SetClampedToScreen(true)
	poignee:EnableMouse(true)
	poignee:RegisterForDrag("LeftButton")
	poignee:SetScript("OnDragStart", function()
		if not InCombatLockdown() then cadre:StartMoving() end
	end)
	poignee:SetScript("OnDragStop", function()
		cadre:StopMovingOrSizing()
		if InCombatLockdown() then return end
		local cx = cadre:GetCenter()
		local ux = UIParent:GetCenter()
		local x, y = cx - ux, cadre:GetTop() - UIParent:GetTop()
		cadre:ClearAllPoints()
		cadre:SetPoint("TOP", UIParent, "TOP", x, y)
		-- la place est a nous : le client ne la retient pas en plus
		if cadre.SetUserPlaced then cadre:SetUserPlaced(false) end
		positions()[cle] = { x = x, y = y }
	end)
	local function reposer()
		local p = positions()[cle]
		if not p or InCombatLockdown() then return end
		cadre:ClearAllPoints()
		cadre:SetPoint("TOP", UIParent, "TOP", p.x, p.y)
	end
	cadre:HookScript("OnShow", reposer)
	reposer()
end
