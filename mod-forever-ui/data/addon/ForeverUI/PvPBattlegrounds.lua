-- ForeverUI : les champs de bataille, dans le volet droit de l'onglet PvP.
--
-- DEMANDE du 2026-09-26 : dans le volet droit, la liste des champs de
-- bataille en haut, les recompenses en cas de victoire ou de defaite en bas,
-- et les boutons "Join as Party" et "Join Battle" -- PAS le bouton "Cancel".
--
-- camelot N'A PAS CET ECRAN : aucun fichier de camelot/ ni de shared/
-- n'appelle JoinBattlefield (seuls mainline/ et cata/ le font). Il se reprend
-- donc de WotLK, habille comme les equipes d'arene (PvPArena.lua).
--
-- RELEVE -- Interface\FrameXML\PVPBattlegroundFrame.lua et .xml, et
-- BattlefieldFrame.lua et .xml (PVPQueue_UpdateRandomInfo et le gabarit
-- PVPQueueInfoScrollFrameTemplate), lus dans l'archive du client :
--
--   la liste     GetBattlegroundInfo(i) pour i = 1..GetNumBattlegroundTypes :
--                nom, canEnter, isHoliday, isRandom, BattleGroundID ; seuls
--                ceux ou l'on peut entrer ; " (BATTLEGROUND_HOLIDAY)" apres le
--                nom d'un appel aux armes ; le premier est choisi d'office
--   l'etat       GetBattlefieldStatus(1..MAX_BATTLEFIELD_QUEUES) : "queued"
--                -> PVP-Currency-<faction> (BATTLEFIELD_QUEUE_STATUS),
--                "confirm" -> UI-StateIcon (0.45, 0.95, 0, 0.5)
--                (BATTLEFIELD_CONFIRM_STATUS), sur la ligne du meme nom
--   le choix     RequestBattlegroundInstanceInfo(i) : le serveur repond par
--                PVPQUEUE_ANYWHERE_SHOW, et GetBattlefieldInfo() donne alors
--                le nombre maximal du groupe
--   recompenses  SEULEMENT pour l'aleatoire et l'appel aux armes :
--                GetRandomBGHonorCurrencyBonuses() /
--                GetHolidayBGHonorCurrencyBonuses() -> hasWin, winHonor,
--                winArena, lossHonor, lossArena ; WIN et LOSS (WotLK les
--                pose sur des bandes verte et rouge ; ici, des plaques, voir
--                ATLAS_PLAQUE) ; symbole d'honneur PVP-Currency-<faction>, d'arene
--                PVP-ArenaPoints-Icon ; un montant nul et son symbole
--                s'effacent. Pour un champ ordinaire, WotLK montre la
--                description de la carte a la place : ICI, RIEN.
--   les boutons  BATTLEFIELD_GROUP_JOIN, dont le texte devient JOIN_AS_PARTY
--                si le groupe maximal vaut 5 et JOIN_AS_GROUP sinon -- ce
--                maximal est la colonne MaxGroupSize de BattlemasterList.dbc
--                du client : 5 pour Alterac, Isle of Conquest et l'aleatoire
--                (un groupe seulement), 10 pour Warsong, 15 pour Arathi, Eye
--                of the Storm et Strand (un raid peut s'inscrire) --, actif
--                seulement en groupe ou en raid ET chef ; BATTLEFIELD_JOIN.
--                Tous deux : JoinBattlefield(0[, true]).
--   la session   ouverte a l'affichage (SortBGList puis la demande), fermee
--                au masquage (CloseBattlefield).
--
-- LA DEMANDE PART A L'IMAGE SUIVANTE. Les ecrans du client que l'onglet
-- eteint -- PVPFrame et PVPBattlegroundFrame -- appellent CloseBattlefield
-- dans leur OnHide ; eteints apres notre demande, ils fermeraient notre
-- session.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local B = {}
ForeverUI.PvPBattlegrounds = B

local SEP = string.char(92)
local PVP = "Interface" .. SEP .. "PVPFrame" .. SEP
local ICONE_ETAT = "Interface" .. SEP .. "CharacterFrame" .. SEP .. "UI-StateIcon"

-- LES ENCADRES (demande du 2026-09-26 : un encadre, style camelot, pour la
-- liste et pour les recompenses). C'est l'InsetFrameTemplate de camelot --
-- shareduipaneltemplates.xml et nineslicelayouts.lua : fond
-- UI-Background-Marble en mosaique ; lisere UI-Frame-InnerTopLeft /
-- TopRight / BotLeftCorner / BotRight (6 x 6, les deux du bas a y = -1) et
-- _UI-Frame-InnerTopTile / BotTile, !UI-Frame-InnerLeftTile / RightTile
-- (3 d'epaisseur) entre eux.
local MARGE = 12                        -- de l'encadre au bord du volet
local ENCADRE_HAUT = -12
local INTERIEUR = 4                     -- des lignes au bord de l'encadre
local MAX_LIGNES = 8
local LIGNE_H = 20
local ETAT_COTE, ETAT_X = 16, 2
local NOM_X = 22
local SURVOL_ALPHA, CHOISIE_ALPHA = 0.10, 0.20

local BOUTON_H, BOUTON_ECART, BOUTONS_BAS = 22, 4, 14

local RECOMPENSE_H, RECOMPENSES_ECART, RECOMPENSES_SUR_BOUTONS = 36, 2, 8
-- LE CONTENU D'UNE PLAQUE NE SE TRONQUE PLUS (demande du 2026-09-26).
-- Rien n'y a de largeur fixe : les colonnes se calculent sur ce que les
-- textes mesurent (GetStringWidth), les memes pour les deux plaques pour
-- que symboles et montants s'alignent. Si l'ensemble depasse la plaque --
-- un intitule long dans une autre langue, de gros montants --, on passe a
-- la police suivante, plus petite.
local BORD_PLAQUE = 8                   -- du bord de la plaque au texte
local ECART_COLONNE = 8                 -- entre deux colonnes
local ECART_SYMBOLE = 3                 -- du symbole a son montant
local SYMBOLE = 20
local POLICES = {
	{ etiquette = "GameFontNormal", montant = "NumberFontNormal" },
	{ etiquette = "GameFontNormalSmall", montant = "NumberFontNormalSmall" },
}
-- LES RECOMPENSES NE SONT PLUS DES BANDES DE COULEUR (demande du
-- 2026-09-26) : chaque ligne est la plaque des listes de camelot
-- (common-button-list-collapseexpand, decoupee en neuf, coin 12 -- celle des
-- cartes d'arene), et la couleur passe au mot : "Win" dans le vert,
-- "Loss" dans le rouge du client (GREEN_FONT_COLOR, RED_FONT_COLOR).
local ATLAS_PLAQUE = "common-button-list-collapseexpand"
local PLAQUE_COIN = 12
local VERT = { 0.1, 1.0, 0.1 }
local ROUGE = { 1.0, 0.1, 0.1 }

local cadre, lignes, recompenses, rejoindre, rejoindreGroupe
local choisi

local function txt(cle, defaut)
	return _G[cle] or defaut
end

local function faction()
	return (UnitFactionGroup and UnitFactionGroup("player")) or "Alliance"
end

-- --------------------------------------------------------------- la session

local differe = CreateFrame("Frame")
differe:Hide()
differe:SetScript("OnUpdate", function(self)
	self:Hide()
	if cadre and cadre:IsVisible() and choisi then
		RequestBattlegroundInstanceInfo(choisi)
	end
end)

local function demander()
	differe:Show()
end
B.differe = differe

-- --------------------------------------------------------------- l'encadre

-- l'InsetFrameTemplate de camelot : ForeverUI.CreateInset (AtlasUtil)
local function encadre(nom)
	return ForeverUI.CreateInset(cadre, nom)
end

-- ------------------------------------------------------------------ la liste

local function creerLigne(n)
	local liste = B.liste
	local l = CreateFrame("Button", "ForeverUIBattlegroundRow" .. n, liste)
	l:SetHeight(LIGNE_H)
	l:SetPoint("TOPLEFT", liste, "TOPLEFT", INTERIEUR, -INTERIEUR - (n - 1) * LIGNE_H)
	l:SetPoint("TOPRIGHT", liste, "TOPRIGHT", -INTERIEUR, -INTERIEUR - (n - 1) * LIGNE_H)
	l.survol = ForeverUI.PvPArena.survolSur(l)

	local etat = CreateFrame("Frame", nil, l)
	etat:SetWidth(ETAT_COTE)
	etat:SetHeight(ETAT_COTE)
	etat:SetPoint("LEFT", l, "LEFT", ETAT_X, 0)
	etat:EnableMouse(true)
	etat.texture = etat:CreateTexture(nil, "ARTWORK")
	etat.texture:SetAllPoints(etat)
	etat:SetScript("OnEnter", function(self)
		if self.tooltip then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.tooltip)
			GameTooltip:Show()
		end
	end)
	etat:SetScript("OnLeave", function() GameTooltip:Hide() end)
	etat:Hide()
	l.etat = etat

	l.nom = l:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	l.nom:SetJustifyH("LEFT")
	l.nom:SetPoint("LEFT", l, "LEFT", NOM_X, 0)
	l.nom:SetPoint("RIGHT", l, "RIGHT", -4, 0)

	l:SetScript("OnEnter", function(self)
		if self.indice ~= choisi then
			self.survol:SetAlpha(SURVOL_ALPHA)
		end
	end)
	l:SetScript("OnLeave", function(self)
		if self.indice ~= choisi then
			self.survol:SetAlpha(0)
		end
	end)
	-- PVPBattlegroundButton_OnClick
	l:SetScript("OnClick", function(self)
		if not self.indice or self.indice == choisi then
			return
		end
		choisi = self.indice
		B.maj()
		RequestBattlegroundInstanceInfo(choisi)
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	return l
end

-- PVPBattleground_UpdateQueueStatus
local function majEtats()
	for _, l in ipairs(lignes) do
		l.etat:Hide()
	end
	local maxFiles = MAX_BATTLEFIELD_QUEUES or 3
	for i = 1, maxFiles do
		local statut, nomCarte = GetBattlefieldStatus(i)
		if statut and statut ~= "none" then
			for _, l in ipairs(lignes) do
				if l:IsShown() and l.nomCarte == nomCarte then
					if statut == "queued" then
						l.etat.texture:SetTexture(PVP .. "PVP-Currency-" .. faction())
						l.etat.texture:SetTexCoord(0, 1, 0, 1)
						l.etat.tooltip = txt("BATTLEFIELD_QUEUE_STATUS", "In Queue")
						l.etat:Show()
					elseif statut == "confirm" then
						l.etat.texture:SetTexture(ICONE_ETAT)
						l.etat.texture:SetTexCoord(0.45, 0.95, 0.0, 0.5)
						l.etat.tooltip = txt("BATTLEFIELD_CONFIRM_STATUS", "Ready to Enter")
						l.etat:Show()
					end
				end
			end
		end
	end
end

-- PVPBattleground_UpdateBattlegrounds
local function majListe()
	local rang = 0
	for i = 1, GetNumBattlegroundTypes() do
		local nom, peutEntrer, fete = GetBattlegroundInfo(i)
		if nom and peutEntrer and rang < MAX_LIGNES then
			rang = rang + 1
			local l = lignes[rang]
			l.indice = i
			l.nomCarte = nom
			if not choisi then
				choisi = i
			end
			if fete then
				l.nom:SetText(nom .. " (" .. txt("BATTLEGROUND_HOLIDAY", "Call to Arms") .. ")")
			else
				l.nom:SetText(nom)
			end
			l.survol:SetAlpha(i == choisi and CHOISIE_ALPHA or 0)
			l:Show()
		end
	end
	for n = rang + 1, MAX_LIGNES do
		lignes[n].indice = nil
		lignes[n].nomCarte = nil
		lignes[n]:Hide()
	end
	majEtats()
end

-- ------------------------------------------------------------ les recompenses

local function creerRecompense(etiquette, couleurClient, couleur)
	local r = CreateFrame("Frame", nil, B.recompensesCadre)
	r:SetHeight(RECOMPENSE_H)
	r.plaque = ForeverUI.CreateNineSlice(r, ATLAS_PLAQUE, PLAQUE_COIN,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	r.etiquette = r:CreateFontString(nil, "ARTWORK", POLICES[1].etiquette)
	r.etiquette:SetJustifyH("LEFT")
	r.etiquette:SetPoint("LEFT", r, "LEFT", BORD_PLAQUE, 0)
	r.etiquette:SetText(etiquette)
	local c = _G[couleurClient]
	if c then
		r.etiquette:SetTextColor(c.r, c.g, c.b)
	else
		r.etiquette:SetTextColor(couleur[1], couleur[2], couleur[3])
	end
	r.honneurSymbole = r:CreateTexture(nil, "ARTWORK")
	r.honneurSymbole:SetWidth(SYMBOLE)
	r.honneurSymbole:SetHeight(SYMBOLE)
	r.honneur = r:CreateFontString(nil, "ARTWORK", POLICES[1].montant)
	r.honneur:SetJustifyH("LEFT")
	r.honneur:SetPoint("LEFT", r.honneurSymbole, "RIGHT", ECART_SYMBOLE, 0)
	r.areneSymbole = r:CreateTexture(nil, "ARTWORK")
	r.areneSymbole:SetTexture(PVP .. "PVP-ArenaPoints-Icon")
	r.areneSymbole:SetWidth(SYMBOLE)
	r.areneSymbole:SetHeight(SYMBOLE)
	r.arene = r:CreateFontString(nil, "ARTWORK", POLICES[1].montant)
	r.arene:SetJustifyH("LEFT")
	r.arene:SetPoint("LEFT", r.areneSymbole, "RIGHT", ECART_SYMBOLE, 0)
	return r
end

local function poserMontant(symbole, texte, montant)
	if montant and montant ~= 0 then
		texte:SetText(montant)
		symbole:Show()
		texte:Show()
	else
		symbole:Hide()
		texte:Hide()
	end
end

-- LES COLONNES DES DEUX PLAQUES, sur ce que leurs textes mesurent.
local function largeurMontree(fs)
	return fs:IsShown() and (fs:GetStringWidth() or 0) or 0
end

local function placerColonnes()
	local plaques = { recompenses.victoire, recompenses.defaite }
	local largeur = (cadre:GetWidth() or 0) - 2 * MARGE - 2 * INTERIEUR
	if largeur <= 0 then
		largeur = 233 - 2 * MARGE - 2 * INTERIEUR
	end
	local etiquette, honneur, arene, total
	for rang, police in ipairs(POLICES) do
		for _, r in ipairs(plaques) do
			r.etiquette:SetFontObject(_G[police.etiquette] or police.etiquette)
			r.honneur:SetFontObject(_G[police.montant] or police.montant)
			r.arene:SetFontObject(_G[police.montant] or police.montant)
		end
		etiquette, honneur, arene = 0, 0, 0
		for _, r in ipairs(plaques) do
			etiquette = math.max(etiquette, r.etiquette:GetStringWidth() or 0)
			honneur = math.max(honneur, largeurMontree(r.honneur))
			arene = math.max(arene, largeurMontree(r.arene))
		end
		total = BORD_PLAQUE + etiquette + ECART_COLONNE + SYMBOLE + ECART_SYMBOLE
			+ honneur + ECART_COLONNE + SYMBOLE + ECART_SYMBOLE + arene + BORD_PLAQUE
		B.police = rang
		if total <= largeur then
			break
		end
	end
	local xHonneur = BORD_PLAQUE + etiquette + ECART_COLONNE
	local xArene = xHonneur + SYMBOLE + ECART_SYMBOLE + honneur + ECART_COLONNE
	for _, r in ipairs(plaques) do
		r.honneurSymbole:ClearAllPoints()
		r.honneurSymbole:SetPoint("LEFT", r, "LEFT", xHonneur, 0)
		r.areneSymbole:ClearAllPoints()
		r.areneSymbole:SetPoint("LEFT", r, "LEFT", xArene, 0)
	end
	B.largeurRecompenses = total
end

-- PVPQueue_UpdateRandomInfo
local function majRecompenses()
	local _, _, fete, aleatoire = GetBattlegroundInfo(choisi or 0)
	if not (aleatoire or fete) then
		B.recompensesCadre:Hide()
		return
	end
	local _, gainHonneur, gainArene, perteHonneur, perteArene
	if aleatoire then
		_, gainHonneur, gainArene, perteHonneur, perteArene = GetRandomBGHonorCurrencyBonuses()
	else
		_, gainHonneur, gainArene, perteHonneur, perteArene = GetHolidayBGHonorCurrencyBonuses()
	end
	local symbole = PVP .. "PVP-Currency-" .. faction()
	recompenses.victoire.honneurSymbole:SetTexture(symbole)
	recompenses.defaite.honneurSymbole:SetTexture(symbole)
	poserMontant(recompenses.victoire.honneurSymbole, recompenses.victoire.honneur, gainHonneur)
	poserMontant(recompenses.victoire.areneSymbole, recompenses.victoire.arene, gainArene)
	poserMontant(recompenses.defaite.honneurSymbole, recompenses.defaite.honneur, perteHonneur)
	poserMontant(recompenses.defaite.areneSymbole, recompenses.defaite.arene, perteArene)
	placerColonnes()
	B.recompensesCadre:Show()
end

-- ---------------------------------------------------------------- les boutons

-- PVPBattleground_UpdateJoinButton et PVPBattlegroundFrame_UpdateGroupAvailable
local function majBoutons()
	local _, _, groupeMax = GetBattlefieldInfo()
	if groupeMax and groupeMax == 5 then
		rejoindreGroupe:SetText(txt("JOIN_AS_PARTY", "Join as Party"))
	else
		rejoindreGroupe:SetText(txt("JOIN_AS_GROUP", "Join as Group"))
	end
	if ((GetNumPartyMembers() > 0) or (GetNumRaidMembers() > 0)) and IsPartyLeader() then
		rejoindreGroupe:Enable()
		rejoindreGroupe:SetAlpha(1)
	else
		rejoindreGroupe:Disable()
		rejoindreGroupe:SetAlpha(0.5)
	end
end

function B.maj()
	if not cadre then
		return
	end
	majListe()
	majRecompenses()
	majBoutons()
end

-- ------------------------------------------------------------ la construction

function B.monter(volet)
	if cadre or not volet then
		return
	end
	cadre = volet

	-- L'ENCADRE DE LA LISTE, en haut du volet : de quoi tenir huit lignes.
	B.liste = encadre("ForeverUIBattlegroundList")
	B.liste:SetPoint("TOPLEFT", cadre, "TOPLEFT", MARGE, ENCADRE_HAUT)
	B.liste:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", -MARGE, ENCADRE_HAUT)
	B.liste:SetHeight(MAX_LIGNES * LIGNE_H + 2 * INTERIEUR)
	lignes = {}
	for n = 1, MAX_LIGNES do
		lignes[n] = creerLigne(n)
	end

	local largeur = (volet:GetWidth() or 0)
	if largeur < 100 then
		largeur = 233
	end
	local boutonL = math.floor((largeur - 2 * MARGE - BOUTON_ECART) / 2)
	rejoindreGroupe = ForeverUI.PvPArena.boutonPanneau(cadre,
		txt("BATTLEFIELD_GROUP_JOIN", "Join as Group"), boutonL, BOUTON_H)
	rejoindreGroupe:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT", MARGE, BOUTONS_BAS)
	rejoindreGroupe:SetScript("OnClick", function()
		if choisi then
			JoinBattlefield(0, true)
		end
	end)
	rejoindre = ForeverUI.PvPArena.boutonPanneau(cadre,
		txt("BATTLEFIELD_JOIN", "Join Battle"), boutonL, BOUTON_H)
	rejoindre:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", -MARGE, BOUTONS_BAS)
	rejoindre:SetScript("OnClick", function()
		if choisi then
			JoinBattlefield(0)
		end
	end)
	B.rejoindre, B.rejoindreGroupe = rejoindre, rejoindreGroupe

	-- L'ENCADRE DES RECOMPENSES, au-dessus des boutons : deux plaques.
	B.recompensesCadre = encadre("ForeverUIBattlegroundRewards")
	B.recompensesCadre:SetPoint("BOTTOMLEFT", rejoindreGroupe, "TOPLEFT", 0, RECOMPENSES_SUR_BOUTONS)
	B.recompensesCadre:SetPoint("BOTTOMRIGHT", rejoindre, "TOPRIGHT", 0, RECOMPENSES_SUR_BOUTONS)
	B.recompensesCadre:SetHeight(2 * RECOMPENSE_H + RECOMPENSES_ECART + 2 * INTERIEUR)
	recompenses = {}
	recompenses.victoire = creerRecompense(txt("WIN", "Win"), "GREEN_FONT_COLOR", VERT)
	recompenses.victoire:SetPoint("TOPLEFT", B.recompensesCadre, "TOPLEFT", INTERIEUR, -INTERIEUR)
	recompenses.victoire:SetPoint("TOPRIGHT", B.recompensesCadre, "TOPRIGHT", -INTERIEUR, -INTERIEUR)
	recompenses.defaite = creerRecompense(txt("LOSS", "Loss"), "RED_FONT_COLOR", ROUGE)
	recompenses.defaite:SetPoint("TOPLEFT", recompenses.victoire, "BOTTOMLEFT", 0, -RECOMPENSES_ECART)
	recompenses.defaite:SetPoint("TOPRIGHT", recompenses.victoire, "BOTTOMRIGHT", 0, -RECOMPENSES_ECART)
	B.recompenses = recompenses

	-- PVPBattlegroundFrame_OnShow / _OnHide
	cadre:HookScript("OnShow", function()
		if SortBGList then
			SortBGList()
		end
		B.maj()
		demander()
	end)
	cadre:HookScript("OnHide", function()
		differe:Hide()
		CloseBattlefield()
	end)

	B.maj()
	if cadre:IsVisible() then
		demander()
	end
end

-- PVPBattlegroundFrame_OnEvent
local veilleur = CreateFrame("Frame")
veilleur:RegisterEvent("PVPQUEUE_ANYWHERE_SHOW")
veilleur:RegisterEvent("UPDATE_BATTLEFIELD_STATUS")
veilleur:RegisterEvent("PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE")
veilleur:RegisterEvent("PARTY_MEMBERS_CHANGED")
veilleur:RegisterEvent("RAID_ROSTER_UPDATE")
veilleur:SetScript("OnEvent", function(self, evenement)
	if not cadre then
		return
	end
	if evenement == "UPDATE_BATTLEFIELD_STATUS" then
		majEtats()
	elseif evenement == "PARTY_MEMBERS_CHANGED" or evenement == "RAID_ROSTER_UPDATE" then
		majBoutons()
	elseif evenement == "PVPQUEUE_ANYWHERE_UPDATE_AVAILABLE" then
		-- les tranches de niveau ont pu changer : la liste se refait
		choisi = nil
		B.maj()
		demander()
	else
		B.maj()
	end
end)

-- TEMOIN -- /fui bg. Ce que le client rend pour la liste et la file.
function ForeverUI.PvPBattlegroundsDebug()
	local dire = function(t)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t)
	end
	for i = 1, GetNumBattlegroundTypes() do
		local nom, peutEntrer, fete, aleatoire, id = GetBattlegroundInfo(i)
		dire(string.format("%d : %s entrer=%s fete=%s aleatoire=%s id=%s%s", i,
			tostring(nom), tostring(peutEntrer), tostring(fete), tostring(aleatoire),
			tostring(id), (i == choisi) and " <- choisi" or ""))
	end
	local nomCarte, _, groupeMax = GetBattlefieldInfo()
	dire(string.format("GetBattlefieldInfo : %s, groupe max %s", tostring(nomCarte), tostring(groupeMax)))
	dire(string.format("aleatoire : %s | appel aux armes : %s",
		table.concat({ tostring((select(2, GetRandomBGHonorCurrencyBonuses()))),
			tostring((select(3, GetRandomBGHonorCurrencyBonuses()))),
			tostring((select(4, GetRandomBGHonorCurrencyBonuses()))),
			tostring((select(5, GetRandomBGHonorCurrencyBonuses()))) }, "/"),
		table.concat({ tostring((select(2, GetHolidayBGHonorCurrencyBonuses()))),
			tostring((select(3, GetHolidayBGHonorCurrencyBonuses()))),
			tostring((select(4, GetHolidayBGHonorCurrencyBonuses()))),
			tostring((select(5, GetHolidayBGHonorCurrencyBonuses()))) }, "/")))
	for i = 1, (MAX_BATTLEFIELD_QUEUES or 3) do
		local statut, nomFile = GetBattlefieldStatus(i)
		dire(string.format("file %d : %s %s", i, tostring(statut), tostring(nomFile)))
	end
end
