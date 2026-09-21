-- ForeverUI : la barre des postures (formes, auras, aspects).
--
-- RELEVE DES SOURCES -- tout vient du code extrait de camelot.
--
-- mainline/StanceBar.xml
--   StanceButtonTemplate herite de SmallActionButtonTemplate.
--   La barre : isHorizontal, numRows 1, numButtons 10, addButtonsToRight,
--   noSpacers. Position par defaut <Anchor point="BOTTOM"/>, le reste etant
--   decide par le mode edition -- qui n'existe pas ici.
--
-- mainline/ActionButtonTemplate.xml, SmallActionButtonTemplate
--   bouton 30 x 30 ; raccourci TOPRIGHT (-3, -4).
--
-- shared/ActionButton.lua, SmallActionButtonMixin
--   quantite BOTTOMRIGHT (-3, 1) ; survol, coche, bordure et eclat en
--   31,6 x 30,9 ; recharge ancree sur l'icone, TOPLEFT (1,7 ; -1,7) et
--   BOTTOMRIGHT (-1 ; 1) ; NormalTexture et PushedTexture ramenees a 35 x 35
--   (UpdateButtonArt), les autres tailles venant du grand modele.
--
-- mainline/ActionButtonOverrides.lua, BaseActionButtonMixin:UpdateButtonArt
--   cadre normal UI-HUD-ActionBar-IconFrame, enfonce -IconFrame-Down, les
--   deux en OVERLAY. L'emplacement vide montre SlotArt quand la barre porte
--   son art, SlotBackground sinon.
--
-- mainline/ActionButtonTemplate.xml -- les quatre etats sont ancres TOPLEFT,
--   le survol est -IconFrame-Mouseover, et le COCHE est ce meme survol en
--   melange ADD.
--
-- shared/ActionBar.lua
--   minButtonPadding = 2 : pas de 32 px pour des boutons de 30.
--
-- shared/StanceBar.lua, StanceBarMixin
--   Update : numForms = GetNumShapeshiftForms(), la barre ne se montre que
--   si numForms > 0.
--   UpdateState : pour chaque forme, l'icone prend sa texture, la recharge
--   est posee, le bouton est COCHE si la forme est active, et l'icone est
--   grisee a 0,4 si elle n'est pas lancable, blanche sinon.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   GetShapeshiftFormInfo ne rend pas la meme chose : le moderne donne
--   (texture, isActive, isCastable, spellID), 3.3.5 donne
--   (texture, NOM, isActive, isCastable). Lire la source au mot pres
--   inverserait ici l'etat actif et la capacite a lancer.
--   Les boutons du client sont SECURISES : on les garde et on les rhabille,
--   jamais en combat -- le client y interdit de redimensionner, deplacer ou
--   afficher un cadre protege.
--   Le mode edition n'existe pas : la position se regle par /fui, comme les
--   autres barres.

local TAILLE = 30                       -- SmallActionButtonTemplate
local ECART = 2                         -- minButtonPadding
local PAS = TAILLE + ECART              -- 32
local CADRE_L, CADRE_H = 35, 35         -- NormalTexture et PushedTexture
local ETAT_L, ETAT_H = 31.6, 30.9       -- survol, coche, bordure, eclat
local NB_BOUTONS = 10                   -- numButtons
local GRISE = 0.4                       -- icone non lancable

local ATLAS = {
	normal = "ui-hud-actionbar-iconframe",
	pushed = "ui-hud-actionbar-iconframe-down",
	highlight = "ui-hud-actionbar-iconframe-mouseover",
	slot = "ui-hud-actionbar-iconframe-slot",
	background = "ui-hud-actionbar-iconframe-background",
}

local nombreDeBoutons = NUM_SHAPESHIFT_SLOTS or NB_BOUTONS
local boutons = {}

-- Le porteur : c'est lui qui se deplace, les boutons s'y accrochent sans
-- changer de parent -- reparenter un cadre securise se paie en combat.
local porteur = CreateFrame("Frame", "ForeverUIStanceBarHolder", UIParent)
porteur:SetWidth(PAS)
porteur:SetHeight(TAILLE)
porteur:Hide()

-- Le cadre du client reecrit sa texture normale a chaque mise a jour : on la
-- neutralise et on dessine la notre, comme pour la barre d'action.
local function taireNormale(bouton)
	local normale = bouton:GetNormalTexture()
	if normale then
		normale:SetAlpha(0)
		normale:SetVertexColor(1, 1, 1, 0)
	end
end

-- ECART ASSUME SUR L'ANCRAGE. La source ancre les quatre etats en TOPLEFT.
-- Sur le GRAND bouton cela tombe juste : un cadre de 46 x 45 sur un bouton
-- de 45 x 45 est centre a un demi-pixel pres. Sur le PETIT, le meme ancrage
-- met un cadre de 35 sur un bouton de 30 : il deborde de 5 a droite et en
-- bas, donc son trou se decale de 2,5 et mord l'icone d'un cote.
--
-- Le trou du cadre, mesure sur l'art (element de 47 x 46, bordure opaque de
-- 5 px a gauche et 4 a droite, 6 en haut et 5 en bas), vaut 35,2 x 34,2 a la
-- taille d'atlas, soit 26,6 une fois le cadre ramene a 35. Centre, ce trou
-- tombe dans l'icone de 30 avec 1,7 de marge partout ; decale, il en sort.
-- Les etats sont donc CENTRES sur le bouton.
local function poserEtat(texture, atlas, largeur, hauteur, add)
	if not texture then
		return
	end

	ForeverUI.SetAtlas(texture, atlas, true)
	texture:SetWidth(largeur)
	texture:SetHeight(hauteur)
	texture:ClearAllPoints()
	texture:SetPoint("CENTER", 0, 0)
	texture:SetBlendMode(add and "ADD" or "BLEND")
end

local function habiller(bouton)
	if not bouton or bouton.foreverSkinned then
		return
	end

	local nom = bouton:GetName()
	bouton:SetWidth(TAILLE)
	bouton:SetHeight(TAILLE)

	-- L'art d'epoque s'efface : le fond flottant et le cadre dore.
	local flottant = _G[nom .. "FloatingBG"]
	if flottant then
		flottant:SetAlpha(0)
	end
	taireNormale(bouton)

	-- L'emplacement vide, sous l'icone : les deux morceaux de la source.
	local fond = bouton:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, ATLAS.background, true)
	fond:SetAllPoints(bouton)

	local emplacement = bouton:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(emplacement, ATLAS.slot, true)
	emplacement:SetAllPoints(bouton)
	bouton.foreverFond = fond
	bouton.foreverEmplacement = emplacement

	local icone = _G[nom .. "Icon"]
	if icone then
		icone:ClearAllPoints()
		icone:SetAllPoints(bouton)
		icone:SetTexCoord(0, 1, 0, 1)
		icone:SetDrawLayer("BORDER")
		bouton.foreverIcone = icone
	end

	-- Notre cadre, hors d'atteinte du client, la ou la source met sa
	-- NormalTexture : en OVERLAY, 35 x 35, centre (voir poserEtat).
	local cadre = bouton:CreateTexture(nil, "OVERLAY")
	poserEtat(cadre, ATLAS.normal, CADRE_L, CADRE_H)
	bouton.foreverCadre = cadre

	local enfonce = bouton:GetPushedTexture()
	poserEtat(enfonce, ATLAS.pushed, CADRE_L, CADRE_H)
	poserEtat(bouton:GetHighlightTexture(), ATLAS.highlight, ETAT_L, ETAT_H)
	poserEtat(bouton:GetCheckedTexture(), ATLAS.highlight, ETAT_L, ETAT_H, true)

	local recharge = _G[nom .. "Cooldown"]
	if recharge and icone then
		recharge:ClearAllPoints()
		recharge:SetPoint("TOPLEFT", icone, "TOPLEFT", 1.7, -1.7)
		recharge:SetPoint("BOTTOMRIGHT", icone, "BOTTOMRIGHT", -1, 1)
		bouton.foreverRecharge = recharge
	end

	local raccourci = _G[nom .. "HotKey"]
	if raccourci then
		raccourci:ClearAllPoints()
		raccourci:SetPoint("TOPRIGHT", bouton, "TOPRIGHT", -3, -4)
	end

	local quantite = _G[nom .. "Count"]
	if quantite then
		quantite:ClearAllPoints()
		quantite:SetPoint("BOTTOMRIGHT", bouton, "BOTTOMRIGHT", -3, 1)
	end

	bouton.foreverSkinned = true
	table.insert(boutons, bouton)
end

local function habillerTout()
	for index = 1, nombreDeBoutons do
		habiller(_G["ShapeshiftButton" .. index])
	end

	-- La barre d'epoque a son propre habillage en trois morceaux.
	for _, suffixe in ipairs({ "Left", "Middle", "Right" }) do
		local texture = _G["ShapeshiftBar" .. suffixe]
		if texture then
			texture:SetAlpha(0)
		end
	end
end

-- RELEVE -- StanceBarMixin:Update et ActionBarMixin:UpdateGridLayout : une
-- rangee, les boutons ajoutes vers la droite avec minButtonPadding entre
-- eux, et la barre masquee tant qu'il n'y a aucune forme.
local function poser()
	local formes = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0

	if formes <= 0 then
		porteur:Hide()
		return
	end

	if InCombatLockdown() then
		return                  -- le client interdit d'y toucher en combat
	end

	porteur:SetWidth(formes * TAILLE + (formes - 1) * ECART)
	porteur:SetHeight(TAILLE)

	for index = 1, nombreDeBoutons do
		local bouton = _G["ShapeshiftButton" .. index]
		if bouton then
			if index <= formes then
				bouton:SetWidth(TAILLE)
				bouton:SetHeight(TAILLE)
				bouton:ClearAllPoints()
				bouton:SetPoint("LEFT", porteur, "LEFT", (index - 1) * PAS, 0)
				bouton:Show()
			else
				bouton:Hide()
			end
		end
	end

	porteur:Show()
end

-- RELEVE -- StanceBarMixin:UpdateState.
local function majEtat()
	local formes = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0

	for index = 1, nombreDeBoutons do
		local bouton = _G["ShapeshiftButton" .. index]
		if bouton and bouton.foreverSkinned and index <= formes then
			-- 3.3.5 : (texture, nom, active, lancable), pas la meme chose
			-- que le moderne.
			local texture, _, active, lancable = GetShapeshiftFormInfo(index)
			local icone = bouton.foreverIcone

			if icone then
				icone:SetTexture(texture)
				if lancable then
					icone:SetVertexColor(1, 1, 1)
				else
					icone:SetVertexColor(GRISE, GRISE, GRISE)
				end
			end

			local recharge = bouton.foreverRecharge
			if recharge then
				if texture then
					recharge:Show()
				else
					recharge:Hide()
				end
				local debut, duree, actif = GetShapeshiftFormCooldown(index)
				if CooldownFrame_SetTimer then
					CooldownFrame_SetTimer(recharge, debut, duree, actif)
				elseif CooldownFrame_Set then
					CooldownFrame_Set(recharge, debut, duree, actif)
				end
			end

			bouton:SetChecked(active and 1 or nil)
			taireNormale(bouton)
		end
	end
end

local function tout()
	habillerTout()
	poser()
	majEtat()
end

ForeverUI.StanceBar = { Apply = tout, Holder = porteur }

-- Le client repose ses propres morceaux a chaque mise a jour.
if hooksecurefunc then
	for _, nomFonction in ipairs({ "ShapeshiftBar_Update", "ShapeshiftBar_UpdateState",
		"ShapeshiftBar_ChangeForm" }) do
		if type(_G[nomFonction]) == "function" then
			hooksecurefunc(nomFonction, function()
				poser()
				majEtat()
			end)
		end
	end
end

local veilleur = CreateFrame("Frame", "ForeverUIStanceBarWatcher")
veilleur:RegisterEvent("PLAYER_ENTERING_WORLD")
veilleur:RegisterEvent("PLAYER_REGEN_ENABLED")
veilleur:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
veilleur:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
veilleur:RegisterEvent("UPDATE_SHAPESHIFT_USABLE")
veilleur:RegisterEvent("UPDATE_SHAPESHIFT_COOLDOWN")
veilleur:SetScript("OnEvent", tout)

tout()

-- Aucun cadre ne pose sa position definitive : elle s'enregistre, se retient
-- et se deplace par /fui. Par defaut la barre s'aligne sur le bord gauche de
-- la barre d'action (-25,5 - 562 = -587,5 du centre) et se pose au-dessus
-- des barres d'experience et de reputation.
ForeverUI.Layout.Register(porteur, "postures", "Barre des postures",
	"BOTTOMLEFT", "BOTTOM", -587.5, 84)
