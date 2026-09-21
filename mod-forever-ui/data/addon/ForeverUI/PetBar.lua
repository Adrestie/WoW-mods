-- ForeverUI : la barre du familier.
--
-- RELEVE DES SOURCES -- tout vient du code extrait de camelot.
--
-- mainline/PetActionBar.xml
--   PetActionButtonTemplate herite de SmallActionButtonTemplate : meme
--   bouton de 30 x 30 que les postures.
--   La barre : isHorizontal, numRows 1, numButtons 10, addButtonsToRight.
--
-- shared/ActionBar.lua -- minButtonPadding = 2, donc un pas de 32.
--
-- shared/ActionButton.lua, SmallActionButtonMixin_OnLoad
--   raccourci TOPRIGHT (-3, -4) ; quantite BOTTOMRIGHT (-3, 1) ; survol,
--   coche, bordure et eclat en 31,6 x 30,9 ; recharge sur l'icone en
--   (1,7 ; -1,7) et (-1 ; 1) ; cadre normal et enfonce ramenes a 35 x 35 ;
--   AutoCastOverlay en 31 x 31, centre a (0,5 ; -0,5).
--
-- mainline/AutoCastTemplates.xml et .lua
--   l'anneau d'autolancement : Corners (UI-HUD-ActionBar-PetAutoCast-Corners)
--   couvre tout le cadre ; Shine (UI-HUD-ActionBar-PetAutoCast-Ants) deborde
--   de 5 px de chaque cote et TOURNE de -360 degres en 4 secondes, en
--   boucle. Corners parait des que l'autolancement est POSSIBLE, Shine
--   seulement quand il est ACTIF (ShowAutoCastEnabled / UpdateShineAnim).
--
-- shared/PetActionBar.lua, PetActionButtonMixin:UpdateButtonState
--   l'icone prend la texture de l'action ; si isToken, le nom et la texture
--   sont des cles de variables GLOBALES et non des valeurs.
--   action active : le bouton est COCHE ; si c'est l'attaque, il clignote
--   et son coche tombe a 0,5 d'alpha -- "a pleine alpha on croirait une
--   capacite de plus selectionnee", dit le commentaire de la source.
--   action inutilisable : icone teintee a 0,4. Pas de texture : icone
--   masquee.
--   La barre se montre si PetHasActionBar() et UnitIsVisible("pet").
--
-- CE QUI DIFFERE, ET POURQUOI.
--   GetPetActionInfo ne rend pas la meme chose : le moderne donne
--   (nom, texture, isToken, active, autoPossible, autoActif, sort), 3.3.5
--   donne (nom, SOUS-TEXTE, texture, isToken, active, autoPossible,
--   autoActif). Un champ de plus au deuxieme rang : recopier la source au
--   mot pres prendrait le sous-texte pour la texture. Meme piege que sur la
--   barre des postures.
--   Les quatre etats sont CENTRES et non ancres TOPLEFT : un cadre de 35 sur
--   un bouton de 30 deborde de 5, et son trou sortirait de l'icone. Voir
--   StanceBar.lua, ou le calcul est detaille.
--   Le masque de l'anneau (UI-HUD-ActionBar-PetAutoCast-Mask) n'est pas
--   reproduit : ce client ne sait pas masquer une texture.
--   La marque de surbrillance (SpellHighlightTexture, atlas bags-newitem)
--   n'existe pas en 3.3.5 : HasPetActionHighlightMark n'y est pas.
--   Les boutons sont SECURISES : rhabilles, jamais recrees, et rien n'est
--   redimensionne ni deplace en combat.

local TAILLE = 30                       -- SmallActionButtonTemplate
local ECART = 2                         -- minButtonPadding
local PAS = TAILLE + ECART              -- 32
local CADRE_L, CADRE_H = 35, 35         -- NormalTexture et PushedTexture
local ETAT_L, ETAT_H = 31.6, 30.9       -- survol, coche, bordure, eclat
local ANNEAU = 31                       -- AutoCastOverlay
local ANNEAU_X, ANNEAU_Y = 0.5, -0.5
local ANTS_DEBORD = 5                   -- Shine : 5 px de plus de chaque cote
local ANTS_TOUR = 4                     -- une rotation complete en 4 secondes
local NB_BOUTONS = 10
local GRISE = 0.4                       -- action inutilisable
local COCHE_ATTAQUE = 0.5               -- alpha du coche sur l'attaque

-- LA PLACE PAR DEFAUT. La barre se pose juste au-dessus de la barre de
-- reputation, sur le meme bord gauche que la barre d'action. Si la barre
-- des postures est la, la barre du familier passe A SA DROITE, separee
-- d'elle par la largeur de deux de ses icones.
local BORD_GAUCHE = -587.5              -- le bord gauche de la barre d'action
local RANGEE = 84                       -- au-dessus de la reputation
local ECART_BARRES = 2 * TAILLE         -- deux icones entre les deux barres

local ATLAS = {
	normal = "ui-hud-actionbar-iconframe",
	pushed = "ui-hud-actionbar-iconframe-down",
	highlight = "ui-hud-actionbar-iconframe-mouseover",
	flash = "ui-hud-actionbar-iconframe-flash",
	slot = "ui-hud-actionbar-iconframe-slot",
	background = "ui-hud-actionbar-iconframe-background",
	coins = "ui-hud-actionbar-petautocast-corners",
	fourmis = "ui-hud-actionbar-petautocast-ants",
}

local nombreDeBoutons = NUM_PET_ACTION_SLOTS or NB_BOUTONS

local porteur = CreateFrame("Frame", "ForeverUIPetBarHolder", UIParent)
porteur:SetWidth(PAS)
porteur:SetHeight(TAILLE)
porteur:Hide()

local function taireNormale(bouton)
	local normale = bouton:GetNormalTexture()
	if normale then
		normale:SetAlpha(0)
		normale:SetVertexColor(1, 1, 1, 0)
	end
end

-- Les quatre etats sont centres : voir l'entete et StanceBar.lua.
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

-- L'anneau d'autolancement. La source le fait tourner par un groupe
-- d'animation ; 3.3.5 n'en a pas sur une texture, mais il a SetRotation :
-- on deroule l'angle nous-memes, a la meme vitesse.
local function monterAnneau(bouton)
	local anneau = CreateFrame("Frame", nil, bouton)
	anneau:SetWidth(ANNEAU)
	anneau:SetHeight(ANNEAU)
	anneau:SetPoint("CENTER", bouton, "CENTER", ANNEAU_X, ANNEAU_Y)
	anneau:SetFrameLevel(bouton:GetFrameLevel() + 1)

	local coins = anneau:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(coins, ATLAS.coins, true)
	coins:SetAllPoints(anneau)

	local fourmis = anneau:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(fourmis, ATLAS.fourmis, true)
	fourmis:SetPoint("TOPLEFT", anneau, "TOPLEFT", -ANTS_DEBORD, ANTS_DEBORD)
	fourmis:SetPoint("BOTTOMRIGHT", anneau, "BOTTOMRIGHT", ANTS_DEBORD, -ANTS_DEBORD)
	fourmis:Hide()

	anneau.angle = 0
	anneau:SetScript("OnUpdate", function(self, elapse)
		if not fourmis:IsShown() then
			return
		end
		-- -360 degres en ANTS_TOUR secondes, soit -2 pi radians.
		self.angle = self.angle - (2 * math.pi * (elapse or 0) / ANTS_TOUR)
		if self.angle < -2 * math.pi then
			self.angle = self.angle + 2 * math.pi
		end
		fourmis:SetRotation(self.angle)
	end)

	anneau:Hide()
	anneau.coins = coins
	anneau.fourmis = fourmis
	bouton.foreverAnneau = anneau
	return anneau
end

local function habiller(bouton)
	if not bouton or bouton.foreverSkinned then
		return
	end

	local nom = bouton:GetName()
	bouton:SetWidth(TAILLE)
	bouton:SetHeight(TAILLE)
	taireNormale(bouton)

	-- L'art d'epoque de l'autolancement s'efface : le notre le remplace.
	for _, suffixe in ipairs({ "AutoCastable", "FloatingBG" }) do
		local texture = _G[nom .. suffixe]
		if texture then
			texture:SetAlpha(0)
		end
	end
	local brillance = _G[nom .. "Shine"]
	if brillance then
		brillance:Hide()
	end

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

	local cadre = bouton:CreateTexture(nil, "OVERLAY")
	poserEtat(cadre, ATLAS.normal, CADRE_L, CADRE_H)
	bouton.foreverCadre = cadre

	poserEtat(bouton:GetPushedTexture(), ATLAS.pushed, CADRE_L, CADRE_H)
	poserEtat(bouton:GetHighlightTexture(), ATLAS.highlight, ETAT_L, ETAT_H)
	poserEtat(bouton:GetCheckedTexture(), ATLAS.highlight, ETAT_L, ETAT_H, true)
	poserEtat(_G[nom .. "Flash"], ATLAS.flash, ETAT_L, ETAT_H)

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

	monterAnneau(bouton)
	bouton.foreverSkinned = true
end

-- L'ART D'EPOQUE DE LA BARRE. 3.3.5 encadre sa barre de familier de deux
-- morceaux glissants, SlidingActionBarTexture0 et 1. On ne se fie pas a
-- leurs noms : TOUTES les regions du cadre lui-meme s'effacent, les boutons
-- etant des cadres fils et non des regions -- ils ne sont donc pas touches.
local function effacerArtDepoque()
	local barre = PetActionBarFrame
	if not barre or not barre.GetNumRegions then
		return
	end

	local regions = { barre:GetRegions() }
	for _, region in ipairs(regions) do
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
end

local function habillerTout()
	for index = 1, nombreDeBoutons do
		habiller(_G["PetActionButton" .. index])
	end
	effacerArtDepoque()
end

-- La barre se montre si le familier a une barre ET s'il est visible.
local function familierPresent()
	if not PetHasActionBar or not PetHasActionBar() then
		return false
	end
	return UnitIsVisible and UnitIsVisible("pet") and true or false
end

-- La place par defaut se recalcule : elle depend de la barre des postures,
-- qui va et vient avec les formes du personnage. SetDefaults ne repose le
-- cadre que si l'utilisateur ne l'a pas deja deplace lui-meme.
local function posePardefaut()
	local x = BORD_GAUCHE
	local postures = ForeverUI.StanceBar and ForeverUI.StanceBar.Holder
	if postures and postures:IsShown() then
		x = x + postures:GetWidth() + ECART_BARRES
	end
	ForeverUI.Layout.SetDefaults("familier", "BOTTOMLEFT", "BOTTOM", x, RANGEE)
end

local function poser()
	if not familierPresent() then
		porteur:Hide()
		return
	end

	if InCombatLockdown() then
		return
	end

	porteur:SetWidth(nombreDeBoutons * TAILLE + (nombreDeBoutons - 1) * ECART)
	porteur:SetHeight(TAILLE)

	for index = 1, nombreDeBoutons do
		local bouton = _G["PetActionButton" .. index]
		if bouton then
			bouton:SetWidth(TAILLE)
			bouton:SetHeight(TAILLE)
			bouton:ClearAllPoints()
			bouton:SetPoint("LEFT", porteur, "LEFT", (index - 1) * PAS, 0)
			bouton:Show()
		end
	end

	porteur:Show()
	posePardefaut()
end

-- RELEVE -- PetActionButtonMixin:UpdateButtonState.
local function majEtat()
	for index = 1, nombreDeBoutons do
		local bouton = _G["PetActionButton" .. index]
		if bouton and bouton.foreverSkinned then
			-- 3.3.5 : (nom, SOUS-TEXTE, texture, isToken, active,
			-- autoPossible, autoActif). Le moderne n'a pas le sous-texte.
			local nomAction, _, texture, estCle, active, autoPossible, autoActif =
				GetPetActionInfo(index)
			local icone = bouton.foreverIcone

			if icone then
				-- isToken : le nom et la texture sont des CLES de variables
				-- globales, pas des valeurs.
				icone:SetTexture(estCle and _G[texture] or texture)
				if texture then
					local utilisable = not GetPetActionSlotUsable
						or GetPetActionSlotUsable(index)
					if utilisable then
						icone:SetVertexColor(1, 1, 1)
					else
						icone:SetVertexColor(GRISE, GRISE, GRISE)
					end
					icone:Show()
				else
					icone:Hide()
				end
			end

			local coche = bouton:GetCheckedTexture()
			if active then
				-- L'attaque clignote, et son coche est a demi transparent :
				-- a pleine alpha on croirait une capacite selectionnee.
				local attaque = IsPetAttackAction and IsPetAttackAction(index)
				if coche then
					coche:SetAlpha(attaque and COCHE_ATTAQUE or 1)
				end
				bouton:SetChecked(1)
			else
				bouton:SetChecked(nil)
			end

			local anneau = bouton.foreverAnneau
			if anneau then
				if autoPossible then
					anneau:Show()
				else
					anneau:Hide()
				end
				if autoActif and autoPossible then
					anneau.fourmis:Show()
				else
					anneau.fourmis:Hide()
				end
			end

			local recharge = bouton.foreverRecharge
			if recharge and GetPetActionCooldown then
				local debut, duree, actif = GetPetActionCooldown(index)
				if CooldownFrame_SetTimer then
					CooldownFrame_SetTimer(recharge, debut, duree, actif)
				elseif CooldownFrame_Set then
					CooldownFrame_Set(recharge, debut, duree, actif)
				end
			end

			taireNormale(bouton)
		end
	end
end

local function tout()
	habillerTout()
	poser()
	majEtat()
end

ForeverUI.PetBar = { Apply = tout, Holder = porteur }

if hooksecurefunc then
	for _, nomFonction in ipairs({ "PetActionBar_Update", "PetActionBar_UpdateCooldowns" }) do
		if type(_G[nomFonction]) == "function" then
			hooksecurefunc(nomFonction, function()
				poser()
				majEtat()
			end)
		end
	end
end

local veilleur = CreateFrame("Frame", "ForeverUIPetBarWatcher")
veilleur:RegisterEvent("PLAYER_ENTERING_WORLD")
veilleur:RegisterEvent("PLAYER_REGEN_ENABLED")
veilleur:RegisterEvent("UNIT_PET")
veilleur:RegisterEvent("PET_BAR_UPDATE")
veilleur:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
veilleur:RegisterEvent("PET_BAR_UPDATE_USABLE")
veilleur:RegisterEvent("PET_UI_UPDATE")
veilleur:RegisterEvent("PLAYER_CONTROL_LOST")
veilleur:RegisterEvent("PLAYER_CONTROL_GAINED")
-- Les formes changent la largeur de la barre des postures, donc la place
-- de celle-ci. StanceBar.lua est charge avant : son gestionnaire passe en
-- premier, et la largeur est deja bonne quand on la lit.
veilleur:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
veilleur:SetScript("OnEvent", tout)

tout()

-- Comme les autres barres : aucune position definitive ici, tout passe par
-- /fui. Par defaut la barre du familier se pose au-dessus de celle des
-- postures, sur le meme bord gauche.
ForeverUI.Layout.Register(porteur, "familier", "Barre du familier",
	"BOTTOMLEFT", "BOTTOM", BORD_GAUCHE, RANGEE)
posePardefaut()
