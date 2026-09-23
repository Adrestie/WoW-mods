-- ForeverUI : l'onglet PvP.
--
-- RELEVE -- camelot/PVPRankFrame.xml et pvprankframe.lua, lus en entier.
--
-- PVPRankFrame         setAllPoints, parent CharacterFrame, useParentLevel
--   SeasonTimerField   GameFontNormal, aligne a DROITE, TOPRIGHT sur
--                      CharacterFrameLeftPaneHost (-46, -18)
--   MainInfoFrame      TOPLEFT sur le meme (0, -60)
--                      BOTTOMRIGHT sur son TOPRIGHT (0, -195)
--     CurrentSeasonField        GameFontNormalMed2, centre, TOP (0, -20)
--     CurrentRankField          GameFontHighlightLarge, centre, TOP du
--                               BOTTOM de la saison (0, -10)
--     CurrentRankProgressField  GameFontNormal, centre, TOP du BOTTOM du
--                               rang (0, -210)
--     Line                      UI-Character-Info-Honor-LevelBG, BOTTOM du
--                               BOTTOM du rang, y = -10
--     RankProgressBarDisplay    un Cooldown de 154 x 154, TOP (0, -95),
--                               renverse et tourne de 180 :
--       lueur        UI-Character-Info-Honor-Bar-BG-Glow, 275 x 295, centree
--       fond         115 x 115, centre : -BG-Horde ou -BG-Alliance
--       anneau       235 x 209, CENTER (0, -1)
--       badge        72 x 84, centre : -Icon-<rang>, ou -Icon-Horde /
--                    -Icon-Alliance quand le rang est nul
--       NextRewardLevel  au BOTTOM (0, -1) : l'anneau
--                    UI-Character-Info-Honor-RewardRing, et le NUMERO du
--                    rang en GameFontNormalLarge, centre
--   DetailFrame        CharacterFrameSidePaneTemplate
--
-- CE QUE 3.3.5 DONNE, ET CE QU'IL NE DONNE PAS.
--
-- camelot tire tout de C_MajorFactions -- le systeme de renom -- qui n'existe
-- pas ici. Mais les trois fonctions de l'epoque des rangs sont TOUJOURS dans
-- le binaire, verifie dans Wow.exe : UnitPVPRank, GetPVPRankInfo et
-- GetPVPRankProgress. WotLK a simplement cesse de s'en servir dans son
-- FrameXML. On s'en sert donc, et le temoin /fui pvp dit ce qu'elles rendent
-- reellement sur ce serveur.
--
-- Heureuse coincidence : la planche de camelot porte QUATORZE icones de rang,
-- exactement les quatorze rangs de l'epoque. Son art c60 EST celui des rangs
-- classiques.
--
-- Quand il n'y a pas de rang, l'ecran montre l'embleme de la faction, et le
-- volet droit porte ce que WotLK sait vraiment donner : les statistiques
-- d'honneur -- GetPVPLifetimeStats, GetPVPSessionStats, GetPVPYesterdayStats
-- et GetHonorCurrency.
--
-- CE QUI DIFFERE, ET POURQUOI :
--   * PAS DE JAUGE CIRCULAIRE ANIMEE. camelot la fait avec un Cooldown dont
--     il remplace la texture de balayage -- SetSwipeTexture, ABSENT du
--     binaire de 3.3.5, verifie. L'anneau, la lueur et le badge sont poses ;
--     la progression s'ecrit en toutes lettres, comme le fait deja
--     CurrentRankProgressField.
--   * GameFontNormalMed2 n'existe pas : GameFontNormalLarge le remplace.
--   * Le compte a rebours de fin de saison demande
--     C_SeasonInfo.GetTimeUntilCurrentPVPSeasonEnd, absent lui aussi. La
--     ligne reste, vide.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local SAISON_X, SAISON_Y = -46, -18
local BLOC_Y = -60
local BLOC_Y2 = -195
local SAISON_TITRE_Y = -20
local RANG_Y = -10
local PROGRES_Y = -210
local LIGNE_Y = -10

local CADRAN = 154
local CADRAN_Y = -95
local LUEUR_L, LUEUR_H = 275, 295
local FOND_L, FOND_H = 115, 115
local ANNEAU_L, ANNEAU_H = 235, 209
local ANNEAU_Y = -1
local BADGE_L, BADGE_H = 72, 84
local RECOMPENSE_Y = -1

local ATLAS_LIGNE = "ui-character-info-honor-levelbg"
local ATLAS_LUEUR = "ui-character-info-honor-bar-bg-glow"
local ATLAS_ANNEAU = "ui-character-info-honor-bar-bg"
local ATLAS_FOND = "ui-character-info-honor-bar-bg-%s"
local ATLAS_BADGE_FACTION = "ui-character-info-honor-icon-%s"
local ATLAS_BADGE_RANG = "ui-character-info-honor-icon-%d"
local ATLAS_ANNEAU_RECOMPENSE = "ui-character-info-honor-rewardring"
local ATLAS_SEPARATEUR = "ui-character-info-scrollline"

local VOLET_DROIT_X, VOLET_DROIT_Y = 16, -14
local VOLET_DROIT_X2, VOLET_DROIT_Y2 = -12, 14
local TITRE_L = 195
local SOUS_TITRE_Y = -3
local SEPARATEUR_Y = -4
local DESCRIPTION_Y = -8
local DESCRIPTION_X2 = -14
local DESCRIPTION_Y2 = 6

local VOLET_L, VOLET_H = 398, 464

local bloc, detail

-- --------------------------------------------------------------- les donnees

local function faction()
	return (UnitFactionGroup and UnitFactionGroup("player")) or "Alliance"
end

-- CE QUE LE CLIENT REND, quand il rend quelque chose. UnitPVPRank donne un
-- indice ; GetPVPRankInfo le traduit en nom et en numero ; GetPVPRankProgress
-- donne la fraction jusqu'au rang suivant.
local function lireRang()
	local indice = UnitPVPRank and UnitPVPRank("player")
	local nom, numero
	if indice and GetPVPRankInfo then
		nom, numero = GetPVPRankInfo(indice, "player")
	end
	numero = numero or 0

	local progres = 0
	if GetPVPRankProgress then
		progres = GetPVPRankProgress() or 0
	end

	return {
		nom = nom,
		numero = numero,
		progres = progres,
	}
end

-- CE QUE WotLK SAIT TOUJOURS DONNER : l'honneur.
local function lireHonneur()
	local vie, deshonneur, meilleurRang = 0, 0, 0
	if GetPVPLifetimeStats then
		vie, deshonneur, meilleurRang = GetPVPLifetimeStats()
	end
	local jour, pointsJour = 0, 0
	if GetPVPSessionStats then
		jour, pointsJour = GetPVPSessionStats()
	end
	local hier, pointsHier = 0, 0
	if GetPVPYesterdayStats then
		hier, pointsHier = GetPVPYesterdayStats()
	end
	local courant = GetHonorCurrency and GetHonorCurrency() or 0

	return {
		vie = vie or 0,
		deshonneur = deshonneur or 0,
		meilleurRang = meilleurRang or 0,
		jour = jour or 0,
		pointsJour = pointsJour or 0,
		hier = hier or 0,
		pointsHier = pointsHier or 0,
		courant = courant or 0,
	}
end

-- --------------------------------------------------------------- l'affichage

local function poserBadge(rang)
	if not bloc then
		return
	end

	-- UpdateFactionBadge : sans rang, l'embleme de la faction ; avec, le
	-- badge du rang.
	local pose = false
	if rang.numero and rang.numero > 0 then
		pose = ForeverUI.SetAtlas(bloc.badge,
			string.format(ATLAS_BADGE_RANG, rang.numero), true)
	end
	if not pose then
		ForeverUI.SetAtlas(bloc.badge,
			string.format(ATLAS_BADGE_FACTION, string.lower(faction())), true)
	end
	bloc.badge:SetWidth(BADGE_L)
	bloc.badge:SetHeight(BADGE_H)
end

local function majBloc()
	if not bloc then
		return
	end

	local rang = lireRang()

	-- La saison : GetCurrentArenaSeason existe, son intitule non.
	local saison = GetCurrentArenaSeason and GetCurrentArenaSeason() or 0
	if saison and saison > 0 then
		bloc.saison:SetText(tostring(saison))
		bloc.saison:Show()
	else
		bloc.saison:SetText("")
		bloc.saison:Hide()
	end

	-- LE TITRE EN HAUT, LE NUMERO DANS L'ANNEAU.
	--
	-- A LA DEMANDE, et non d'apres la source : camelot ecrit les deux en
	-- haut -- PVP_RANK_NUMBER_AND_TITLE donne "Rang N : Nom" dans le
	-- CurrentRankField -- puis repete le numero dans l'anneau de recompense,
	-- par LevelLabel. Ici le titre reste seul en haut, et le numero n'est
	-- qu'a un endroit : dans le cercle dore.
	bloc.rang:SetText(rang.nom or "")

	poserBadge(rang)

	-- La progression, en toutes lettres : la jauge circulaire n'est pas
	-- portable.
	if rang.progres and rang.progres > 0 then
		bloc.progres:SetText(string.format("%d%%", math.floor(rang.progres * 100 + 0.5)))
	else
		bloc.progres:SetText("")
	end

	bloc.numero:SetText(rang.numero and rang.numero > 0 and tostring(rang.numero) or "")

	if ForeverUI.PvPDetail then
		ForeverUI.PvPDetail()
	end
end
ForeverUI.PvPUpdate = majBloc

local function majDetail()
	if not detail then
		return
	end

	local rang = lireRang()
	local honneur = lireHonneur()

	detail.titre:SetText(rang.nom or (PVP or "JcJ"))
	if rang.numero and rang.numero > 0 then
		detail.sousTitre:SetText(tostring(rang.numero))
	else
		detail.sousTitre:SetText("")
	end

	-- Ce que WotLK sait vraiment donner. Les intitules du client quand il en
	-- a un, le nom brut sinon.
	local lignes = {}
	local function ajouter(intitule, valeur)
		lignes[#lignes + 1] = tostring(intitule) .. " : " .. tostring(valeur)
	end

	ajouter(HONOR_POINTS or "Points d'honneur", honneur.courant)
	ajouter(LIFETIME_HONORABLE_KILLS or "Victoires honorables", honneur.vie)
	if honneur.meilleurRang and honneur.meilleurRang > 0 then
		ajouter(HIGHEST_RANK or "Meilleur rang", honneur.meilleurRang)
	end
	ajouter(TODAY or "Aujourd'hui",
		tostring(honneur.jour) .. " (" .. tostring(honneur.pointsJour) .. ")")
	ajouter(YESTERDAY or "Hier",
		tostring(honneur.hier) .. " (" .. tostring(honneur.pointsHier) .. ")")

	detail.description:SetText(table.concat(lignes, "\n"))
end
ForeverUI.PvPDetail = majDetail

-- ---------------------------------------------------------- la construction

-- L'ECRAN DU CLIENT SE TAIT EN ENTIER, a chaque passage : PVPParentFrame
-- porte ses onglets, ses cadres d'equipe d'arene, son bandeau de hors-saison
-- et tout leur art. Regions ET cadres fils, comme pour les competences.
local function etoufferEcranDuClient()
	local cadre = _G["PVPParentFrame"]
	if not cadre then
		return
	end

	if cadre.SetBackdrop then
		cadre:SetBackdrop(nil)
	end
	for _, region in ipairs({ cadre:GetRegions() }) do
		if region.Hide then
			region:Hide()
		end
	end
	if cadre.GetChildren then
		for _, fils in ipairs({ cadre:GetChildren() }) do
			if fils ~= bloc and fils.Hide then
				fils:Hide()
			end
		end
	end
end

local function monter(hote)
	local cadre = _G["PVPParentFrame"]
	if not cadre or not hote then
		return nil, {}
	end

	cadre:SetParent(hote)
	if cadre.SetToplevel then
		cadre:SetToplevel(false)
	end
	cadre:ClearAllPoints()
	cadre:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, 0)
	cadre:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", 0, 0)

	if bloc then
		etoufferEcranDuClient()
		majBloc()
		return nil, { cadre }
	end

	local largeur = hote:GetWidth() or 0
	if largeur < 100 then
		largeur = VOLET_L
	end

	-- LE BLOC PRINCIPAL. Ses deux ancrages donnent une bande de 135 de haut,
	-- du -60 au -195 sous le haut du volet.
	bloc = CreateFrame("Frame", "ForeverUIPvPMain", cadre)
	bloc:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, BLOC_Y)
	bloc:SetPoint("BOTTOMRIGHT", hote, "TOPRIGHT", 0, BLOC_Y2)

	-- Le compte a rebours de fin de saison : la ligne existe, vide.
	bloc.minuterie = cadre:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	bloc.minuterie:SetJustifyH("RIGHT")
	bloc.minuterie:SetPoint("TOPRIGHT", hote, "TOPRIGHT", SAISON_X, SAISON_Y)

	-- ECART ASSUME : GameFontNormalMed2 n'existe pas en 3.3.5.
	bloc.saison = bloc:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	bloc.saison:SetJustifyH("CENTER")
	bloc.saison:SetPoint("TOP", bloc, "TOP", 0, SAISON_TITRE_Y)

	bloc.rang = bloc:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	bloc.rang:SetJustifyH("CENTER")
	bloc.rang:SetPoint("TOP", bloc.saison, "BOTTOM", 0, RANG_Y)

	bloc.ligne = bloc:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(bloc.ligne, ATLAS_LIGNE)
	bloc.ligne:SetPoint("BOTTOM", bloc.rang, "BOTTOM", 0, LIGNE_Y)

	bloc.progres = bloc:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	bloc.progres:SetJustifyH("CENTER")
	bloc.progres:SetPoint("TOP", bloc.rang, "BOTTOM", 0, PROGRES_Y)

	-- LE CADRAN. Sans la jauge animee -- SetSwipeTexture n'existe pas -- mais
	-- avec sa lueur, son fond de faction, son anneau et son badge.
	local cadran = CreateFrame("Frame", "ForeverUIPvPDial", bloc)
	cadran:SetWidth(CADRAN)
	cadran:SetHeight(CADRAN)
	cadran:SetPoint("TOP", bloc, "TOP", 0, CADRAN_Y)
	bloc.cadran = cadran

	local lueur = cadran:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(lueur, ATLAS_LUEUR, true)
	lueur:SetWidth(LUEUR_L)
	lueur:SetHeight(LUEUR_H)
	lueur:SetPoint("CENTER", cadran, "CENTER", 0, 0)

	local fond = cadran:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, string.format(ATLAS_FOND, string.lower(faction())), true)
	fond:SetWidth(FOND_L)
	fond:SetHeight(FOND_H)
	fond:SetPoint("CENTER", cadran, "CENTER", 0, 0)
	bloc.fond = fond

	local anneau = cadran:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(anneau, ATLAS_ANNEAU, true)
	anneau:SetWidth(ANNEAU_L)
	anneau:SetHeight(ANNEAU_H)
	anneau:SetPoint("CENTER", cadran, "CENTER", 0, ANNEAU_Y)

	bloc.badge = cadran:CreateTexture(nil, "ARTWORK")
	bloc.badge:SetPoint("CENTER", cadran, "CENTER", 0, 0)

	-- L'anneau de recompense, en bas du cadran, avec le numero du rang.
	local recompense = cadran:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(recompense, ATLAS_ANNEAU_RECOMPENSE)
	recompense:SetPoint("BOTTOM", cadran, "BOTTOM", 0, RECOMPENSE_Y)
	bloc.recompense = recompense

	bloc.numero = cadran:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	bloc.numero:SetPoint("CENTER", recompense, "CENTER", 0, 0)
	bloc.numero:SetJustifyH("CENTER")

	etoufferEcranDuClient()
	majBloc()
	return nil, { cadre }
end

local function monterDetail(hote)
	if detail then
		return detail, {}
	end

	local cadre = CreateFrame("Frame", "ForeverUIPvPDetail", hote)
	cadre:SetPoint("TOPLEFT", hote, "TOPLEFT", VOLET_DROIT_X, VOLET_DROIT_Y)
	cadre:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", VOLET_DROIT_X2, VOLET_DROIT_Y2)
	detail = cadre

	detail.titre = cadre:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	detail.titre:SetWidth(TITRE_L)
	detail.titre:SetJustifyH("CENTER")
	detail.titre:SetPoint("TOP", cadre, "TOP", 0, 0)

	detail.sousTitre = cadre:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	detail.sousTitre:SetWidth(TITRE_L)
	detail.sousTitre:SetJustifyH("CENTER")
	detail.sousTitre:SetPoint("TOP", detail.titre, "BOTTOM", 0, SOUS_TITRE_Y)

	detail.separateur = cadre:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(detail.separateur, ATLAS_SEPARATEUR)
	detail.separateur:SetPoint("TOP", detail.sousTitre, "BOTTOM", 0, SEPARATEUR_Y)

	detail.description = cadre:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	detail.description:SetPoint("TOPLEFT", detail.separateur, "BOTTOMLEFT", 0, DESCRIPTION_Y)
	detail.description:SetPoint("TOPRIGHT", detail.separateur, "BOTTOMRIGHT", 0, DESCRIPTION_Y)
	detail.description:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT", 0, DESCRIPTION_Y2)
	detail.description:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT",
		DESCRIPTION_X2, DESCRIPTION_Y2)
	detail.description:SetJustifyH("LEFT")
	detail.description:SetJustifyV("TOP")
	if detail.description.SetWordWrap then
		detail.description:SetWordWrap(true)
	end

	majDetail()
	return cadre, {}
end

ForeverUI.PvPTab = { Build = monter, BuildRight = monterDetail }

-- TEMOIN -- /fui pvp. Ce que les trois fonctions de rang rendent REELLEMENT
-- sur ce serveur : WotLK ne s'en sert plus, mais elles sont dans le binaire,
-- et c'est le serveur qui decide si elles portent une valeur.
function ForeverUI.PvPDebug()
	local dire = function(texte)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. texte)
	end

	local indice = UnitPVPRank and UnitPVPRank("player")
	local nom, numero
	if indice and GetPVPRankInfo then
		nom, numero = GetPVPRankInfo(indice, "player")
	end
	dire(string.format("pvp : UnitPVPRank=%s -> nom=%s numero=%s | progres=%s",
		tostring(indice), tostring(nom), tostring(numero),
		tostring(GetPVPRankProgress and GetPVPRankProgress())))

	local h = lireHonneur()
	dire(string.format("honneur : courant=%d vie=%d meilleurRang=%d "
		.. "aujourd'hui=%d (%d) hier=%d (%d)",
		h.courant, h.vie, h.meilleurRang, h.jour, h.pointsJour, h.hier, h.pointsHier))
	dire(string.format("saison d'arene : %s | faction : %s",
		tostring(GetCurrentArenaSeason and GetCurrentArenaSeason()), faction()))
end

-- Le client refait son ecran dans PVPFrame_Update : on passe apres.
if hooksecurefunc and type(_G["PVPFrame_Update"]) == "function" then
	hooksecurefunc("PVPFrame_Update", function()
		etoufferEcranDuClient()
		majBloc()
	end)
end
