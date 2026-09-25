-- ForeverUI : le journal de quetes, volet LISTE de la carte du monde (etape 2
-- du chantier docs/CARTE_ET_JOURNAL.md).
--
-- CHEZ CAMELOT, LE JOURNAL N'EST PAS UNE FENETRE. blizzard_uipanels_game.toc ne
-- charge pas QuestLogFrame pour camelot : c'est mainline/QuestMapFrame, un
-- volet de 330 accroche a droite de la carte (blizzard_worldmap.lua,
-- AttachQuestLog : TOPRIGHT (-3, -25), BOTTOMRIGHT (-3, 3), strate HIGH), et L
-- ouvre la carte avec lui (questlogownermixin.lua).
--
-- RELEVE -- mainline/questmapframe.xml / .lua, camelot/questmapframeoverrides.lua,
-- camelot/questmapframeutils.lua, sharedxml/listtemplates.xml / .lua :
--   QuestsFrame        du coin haut-gauche du volet a (-22, +9) du bas-droit
--   QuestScrollFrame   TOPLEFT (0, -29), BOTTOMRIGHT ; barre MinimalScrollBar
--                      a (8, 2) / (8, -4) de son bord droit
--     Background       QuestLog-main-background, taille de l'atlas, rognee a
--                      la hauteur du cadre (ResizeBackground) ; liste vide :
--                      QuestLog-empty-quest-background + EmptyText Game16Font
--     SearchBox        200 x 20 (camelot), BOTTOMLEFT sur son TOPLEFT (6, 7)
--     QuestLogCount    100 x 20 a droite de la recherche (3, 0), texte
--                      GameFontNormalSmall a (-5, -5) du bord droit
--     SettingsDropdown 15 x 16, TOPRIGHT (19, 25) ; une case : objectifs
--     BorderFrame      questlog-frame de (-3, 7) a (3, -6), filigrane en haut,
--                      ombre questlog-frame-gradient-bottom en bas
--   Lignes, reconstruites a chaque mise a jour, empilees de haut en bas
--   (VerticalLayoutFrame) :
--     en-tete          289 x 22, a x = 9 ; ListHeaderVisualTemplate : fond
--                      common-button-list-collapseExpand, texte Game15Font_Shadow
--                      a (8, 0), bouton +/- 20 x 20 a RIGHT (-6) ; titre gris
--                      (DISABLED_FONT_COLOR), blanc au survol
--     quete            290 de large, a x = 0 ; texte GameFontNormalLeft a
--                      (31, -8) ; case de suivi 14 x 14 TOPRIGHT (0, -8) ;
--                      hauteur = 8 + texte + objectifs + 6
--     objectif         ObjectiveFont, tiret QUEST_DASH puis 205 de texte
--   Ecarts entre lignes (QuestLogQuests_UpdateButtonSpacing) : premier en-tete
--   8, en-tete apres quete 4, en-tete apres en-tete 6, quete apres en-tete 2,
--   quete apres quete -3.
--   Ce que camelot change : prefixe [niveau] ou [niveau+] toujours ; "(Elite)"
--   a droite ; compteur montre ; pas d'icone de type de quete.
--
-- CE QUE 3.3.5 DONNE : GetQuestLogTitle(i) -> title, level, questTag,
-- suggestedGroup, isHeader, isCollapsed, isComplete (>0 terminee, <0 echouee),
-- isDaily. Un en-tete REPLIE retire ses quetes de la liste : pour chercher, on
-- deplie tout, puis on rend a chaque en-tete son etat -- retenu par son NOM.
--
-- LES REPERES ET LA CARTE (demande du 2026-09-25). camelot pose devant chaque
-- quete son repere (POIButton) et, au clic, montre la quete sur la carte
-- (QuestMapFrame_ShowQuestDetails : la carte passe sur celle de la quete).
-- WotLK a tout ce qu'il faut : apres WorldMapFrame_UpdateQuests, chaque quete
-- qui a un repere sur la carte affichee a son cadre WorldMapQuestFrame<n>,
-- numerote comme sur la carte ; QuestPOI_DisplayButton pose le meme repere
-- dans n'importe quel parent -- WotLK le fait pour sa propre liste ;
-- WorldMap_OpenToQuest met la carte sur la zone de la quete et la
-- selectionne, ce qui dessine sa zone d'objectif ; le survol d'une ligne
-- allume cette zone (DrawQuestBlob), comme la liste de WotLK.
--
-- LA PAGE D'UNE QUETE (etape 3, demande du 2026-09-25) : le clic sur une
-- quete remplace la liste par sa page -- texte, objectifs, recompenses -- et
-- un bouton Retour y ramene. Releve et ecarts : en tete de la section "la
-- page d'une quete", plus bas.

ForeverUI = ForeverUI or {}

local J = {}
ForeverUI.QuestLog = J

local V = {
	largeur = 330, x = -3, haut = -25, bas = 3,
	listeDroite = -22, listeBas = 9, listeHaut = -29,
	enteteL = 289, enteteH = 22, enteteX = 9,
	queteL = 290, queteTexteX = 31, queteTexteY = -8,
	caseCote = 14, caseY = -8,
	objectifL = 220, objectifTexteL = 205,
	rechercheL = 200, rechercheH = 20, rechercheX = 6, rechercheY = 7,
	compteurL = 100, compteurH = 20, compteurX = 3,
	reglageL = 15, reglageH = 16, reglageX = 19, reglageY = 25,
	barreX = 8, barreHaut = 2, barreBas = -4,
	pas = 16,
}

-- Les ecarts de QuestLogQuests_UpdateButtonSpacing, pour les types que 3.3.5
-- connait.
local ECART = {
	enteteApresRien = 8, enteteApresEntete = 6, enteteApresQuete = 4,
	queteApresEntete = 2, queteApresQuete = -3,
}

-- Les couleurs de camelot : GlobalColor.db2 du client camelot, et
-- blizzard_framexmlbase/constants.lua pour la difficulte.
local COULEUR = {
	objectif = { 0.8, 0.8, 0.8 },               -- QUEST_OBJECTIVE_FONT_COLOR
	objectifSurvol = { 1, 1, 1 },               -- QUEST_OBJECTIVE_HIGHLIGHT_FONT_COLOR
	enteteRepos = { 0.502, 0.502, 0.502 },      -- DISABLED_FONT_COLOR
	enteteSurvol = { 1, 1, 1 },                 -- HIGHLIGHT_FONT_COLOR
	difficulte = {
		trivial = { 0.50, 0.50, 0.50 }, standard = { 0.25, 0.75, 0.25 },
		difficult = { 1.00, 0.82, 0.00 }, verydifficult = { 1.00, 0.50, 0.25 },
		impossible = { 1.00, 0.10, 0.10 },
	},
	difficulteSurvol = {
		trivial = { 0.70, 0.70, 0.70 }, standard = { 0.43, 0.93, 0.43 },
		difficult = { 1.00, 1.00, 0.10 }, verydifficult = { 1.00, 0.75, 0.44 },
		impossible = { 1.00, 0.40, 0.40 },
	},
	-- la page d'une quete : la matiere "Default" de GetMaterialTextColors
	texte = { 0.18, 0.122, 0.059 },             -- DEFAULT_MATERIAL_TEXT_COLOR
	titre = { 0, 0, 0 },                        -- DEFAULT_MATERIAL_TITLETEXT_COLOR
	ombreTitre = { 0.49, 0.35, 0.05 },          -- QuestFont_Shadow_Huge
	objectifFait = { 0.2, 0.2, 0.2 },           -- QUEST_OBJECTIVE_COMPLETED_FONT_COLOR
	recompense = { 0.902, 0.788, 0.671 },       -- QuestMapRewardsFont
	communGris = { 0.659, 0.659, 0.659 },       -- COMMON_GRAY_COLOR
}

-- Les textes : ceux de 3.3.5 quand il les a, ceux de camelot sinon
-- (GlobalStrings.db2 du client camelot).
local TEXTE = {
	recherche = "Search Quest Log",                  -- SEARCH_QUEST_LOG
	aucunResultat = "No results found",              -- QUEST_LOG_NO_RESULTS
	vide = "No quests available|n|nAccept quests by talking to characters with a |TInterface\\GossipFrame\\AvailableQuestIcon:16:16|t above their head.",
	compteur = "Quests: %s%d|r|cffffffff/%d|r",     -- QUEST_LOG_COUNT_TEMPLATE
	montrerObjectifs = "Show Quest Objectives",     -- QUEST_LOG_SHOW_OBJECTIVES
	pret = "Ready for turn-in",                      -- QUEST_WATCH_QUEST_READY
	details = "<Click to view Quest Details>",       -- CLICK_QUEST_DETAILS
	nePlusSuivre = "Untrack Quest",                  -- UNTRACK_QUEST
	partagerChat = "Share in Chat",                  -- SHARE_IN_CHAT
	toutSuivre = "Track All",                        -- QUEST_LOG_TRACK_ALL
	neRienSuivre = "Untrack All",                    -- QUEST_LOG_UNTRACK_ALL
	-- la page d'une quete
	nePlusSuivreCourt = "Untrack",                   -- UNTRACK_QUEST_ABBREV
	recompenses = "Rewards",                         -- REWARDS
	titreEchec = "%s - (Failed)",                    -- QUEST_TITLE_FORMAT_FAILED
}

local POLICE = "Fonts\\FRIZQT__.TTF"

local function couleur(t, c)
	t:SetTextColor(c[1], c[2], c[3])
end

-- ---------------------------------------------------------------- l'etat
-- ForeverUIDB n'existe qu'apres le chargement de nos variables.
local function reglages()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.journal = ForeverUIDB.journal or {}
	local r = ForeverUIDB.journal
	if r.volet == nil then r.volet = true end            -- questLogOpen
	if r.objectifs == nil then r.objectifs = true end    -- decision 4
	return r
end
J.reglages = reglages

-- -------------------------------------------------------------- la difficulte
-- Le classement de WotLK, les couleurs de camelot.
local function cleDifficulte(niveau)
	local c = GetQuestDifficultyColor and GetQuestDifficultyColor(niveau)
	if c and QuestDifficultyColors then
		for cle, valeur in pairs(QuestDifficultyColors) do
			if valeur == c and COULEUR.difficulte[cle] then
				return cle
			end
		end
	end
	return "difficult"
end

-- ------------------------------------------------------------- les donnees
-- Une entree du journal, avec ce que la ligne en affiche.
local function entree(index)
	local titre, niveau, tag, groupe, estEntete, replie, termine, quotidienne, questID = GetQuestLogTitle(index)
	if not titre then
		return nil
	end
	return {
		index = index, title = titre, level = niveau, questTag = tag,
		isHeader = estEntete and true or false, isCollapsed = replie and true or false,
		isComplete = termine, isDaily = quotidienne, questID = questID,
	}
end

local function estElite(info)
	return info.questTag == ELITE
end

-- QuestLogQuests_GetTitle + la surcharge camelot : "[" niveau ("+" si elite) "] ",
-- et devant, "[n] " si des membres du groupe ont la quete.
local function titreQuete(info)
	local titre = "[" .. tostring(info.level) .. (estElite(info) and "+" or "") .. "] " .. info.title
	local membres = 0
	for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
		if IsUnitOnQuest and IsUnitOnQuest(info.index, "party" .. i) then
			membres = membres + 1
		end
	end
	if membres > 0 then
		titre = "[" .. membres .. "] " .. titre
	end
	return titre
end

-- ------------------------------------------------------------- la recherche
-- QuestSearcher : sans motif, sur le titre, le texte d'objectif et les
-- objectifs. Un en-tete replie cache ses quetes en 3.3.5 : on deplie tout le
-- temps de la recherche, et on rend a chaque en-tete son etat par son NOM.
local R = { texte = nil, etats = nil }

local function deplierTout()
	R.etats = {}
	for i = GetNumQuestLogEntries(), 1, -1 do
		local info = entree(i)
		if info and info.isHeader then
			R.etats[info.title] = info.isCollapsed
			if info.isCollapsed then
				ExpandQuestHeader(i)
			end
		end
	end
end

local function rendreEtats()
	if not R.etats then
		return
	end
	for i = GetNumQuestLogEntries(), 1, -1 do
		local info = entree(i)
		if info and info.isHeader and R.etats[info.title] then
			CollapseQuestHeader(i)
		end
	end
	R.etats = nil
end

local function correspond(info)
	if not R.texte then
		return true
	end
	local cherche = R.texte
	if string.find(string.lower(info.title), cherche, 1, true) then
		return true
	end
	local selection = GetQuestLogSelection()
	SelectQuestLogEntry(info.index)
	local _, objectifs = GetQuestLogQuestText()
	SelectQuestLogEntry(selection)
	if objectifs and string.find(string.lower(objectifs), cherche, 1, true) then
		return true
	end
	for i = 1, GetNumQuestLeaderBoards(info.index) do
		local texte = GetQuestLogLeaderBoard(i, info.index)
		if texte and string.find(string.lower(texte), cherche, 1, true) then
			return true
		end
	end
	return false
end

function J.chercher(texte)
	if texte and texte ~= "" then
		if not R.texte then
			deplierTout()
		end
		R.texte = string.lower(texte)
	else
		if R.texte then
			rendreEtats()
		end
		R.texte = nil
	end
	J.maj()
end

-- ------------------------------------------------------ les reperes, la carte
local PARENT_REPERES = "ForeverUIQuestScrollContents"

-- La numerotation de WotLK pour la carte affichee : WorldMapFrame_GetQuestFrame
-- compte les quetes terminees a part (QUEST_POI_COMPLETE_IN) et numerote les
-- autres (QUEST_POI_NUMERIC, index - terminees).
local function reperesDeLaCarte()
	local reperes = {}
	local terminees = 0
	for i = 1, (WorldMapFrame and WorldMapFrame.numQuests or 0) do
		local f = _G["WorldMapQuestFrame" .. i]
		if f and f.questId and f.questId ~= 0 then
			if f.completed then
				terminees = terminees + 1
				reperes[f.questId] = { QUEST_POI_COMPLETE_IN, terminees }
			else
				reperes[f.questId] = { QUEST_POI_NUMERIC, i - terminees }
			end
		end
	end
	return reperes
end

local function queteSelectionnee()
	return WORLDMAP_SETTINGS and WORLDMAP_SETTINGS.selectedQuestId
end

-- Allumer ou eteindre la zone d'une quete sur la carte, comme la liste de
-- WotLK au survol (WorldMapQuestFrame_OnEnter / _OnLeave). La quete choisie
-- garde la sienne.
local function zone(info, allumer)
	if not (WorldMapBlobFrame and WorldMapBlobFrame.DrawQuestBlob and info.questID) then
		return
	end
	if info.isComplete and info.isComplete > 0 then
		return
	end
	if not allumer and queteSelectionnee() == info.questID then
		return
	end
	WorldMapBlobFrame:DrawQuestBlob(info.questID, allumer and true or false)
end

-- QuestMapFrame_ShowQuestDetails, pour sa partie carte : WorldMap_OpenToQuest
-- met la carte sur la zone de la quete et la selectionne.
local function montrerSurCarte(info)
	SelectQuestLogEntry(info.index)
	if info.questID and WorldMap_OpenToQuest then
		WorldMap_OpenToQuest(info.questID)
	end
	if J.surSelection then J.surSelection(info.index) end
end
J.montrerSurCarte = montrerSurCarte

-- ------------------------------------------------------------- les actions

-- _QuestLog_ToggleQuestWatch de QuestLogFrame.lua (locale au client : recopiee)
local function basculerSuivi(index)
	if IsQuestWatched(index) then
		RemoveQuestWatch(index)
		WatchFrame_Update()
	else
		if GetNumQuestWatches() >= MAX_WATCHABLE_QUESTS then
			UIErrorsFrame:AddMessage(format(QUEST_WATCH_TOO_MANY, MAX_WATCHABLE_QUESTS), 1.0, 0.1, 0.1, 1.0)
			return
		end
		AddQuestWatch(index)
		WatchFrame_Update()
	end
end
J.basculerSuivi = basculerSuivi

-- le bouton Abandonner de QuestLogFrame.xml
local function abandonner(index)
	SelectQuestLogEntry(index)
	SetAbandonQuest()
	local objets = GetAbandonQuestItems()
	if objets then
		StaticPopup_Hide("ABANDON_QUEST")
		StaticPopup_Show("ABANDON_QUEST_WITH_ITEMS", GetAbandonQuestName(), objets)
	else
		StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
		StaticPopup_Show("ABANDON_QUEST", GetAbandonQuestName())
	end
end

local function partager(index)
	SelectQuestLogEntry(index)
	QuestLogPushQuest()
	PlaySound("igQuestLogOpen")
end

local function enGroupe()
	return (GetNumPartyMembers and GetNumPartyMembers() > 0) or (GetNumRaidMembers and GetNumRaidMembers() > 1)
end

local function menu(ancre, liste)
	if ForeverUI.WorldMap and ForeverUI.WorldMap.ouvrirMenu then
		ForeverUI.WorldMap.ouvrirMenu(ancre, liste)
	end
end

-- QuestMapLogTitleButton_CreateContextMenu, sans le super-suivi (absent de 3.3.5)
local function menuQuete(ligne)
	local index = ligne.index
	local l = {}
	table.insert(l, {
		text = IsQuestWatched(index) and TEXTE.nePlusSuivre or TRACK_QUEST,
		func = function() basculerSuivi(index) end,
	})
	local partageable = GetQuestLogPushable and GetQuestLogPushable(index) and enGroupe()
	table.insert(l, {
		text = SHARE_QUEST,
		disabled = not partageable,
		func = function() partager(index) end,
	})
	table.insert(l, {
		text = TEXTE.partagerChat,
		func = function()
			local lien = GetQuestLink(index)
			if lien and not (ChatEdit_InsertLink and ChatEdit_InsertLink(lien)) then
				ChatFrame_OpenChat(lien)
			end
		end,
	})
	table.insert(l, {
		text = ABANDON_QUEST,
		func = function() abandonner(index) end,
	})
	menu(ligne, l)
end

-- QuestMapLogHeaderButton_CreateContextMenu : suivre ou ne plus suivre les
-- quetes d'un en-tete (SetHeaderQuestsTracked)
local function suivreEntete(nomEntete, suivre)
	local dedans = false
	for i = 1, GetNumQuestLogEntries() do
		local info = entree(i)
		if info and info.isHeader then
			dedans = (info.title == nomEntete)
		elseif info and dedans then
			local suivie = IsQuestWatched(i) and true or false
			if suivre and not suivie then
				if GetNumQuestWatches() >= MAX_WATCHABLE_QUESTS then
					UIErrorsFrame:AddMessage(format(QUEST_WATCH_TOO_MANY, MAX_WATCHABLE_QUESTS), 1.0, 0.1, 0.1, 1.0)
					break
				end
				AddQuestWatch(i)
			elseif not suivre and suivie then
				RemoveQuestWatch(i)
			end
		end
	end
	WatchFrame_Update()
	J.maj()
end

-- ------------------------------------------------------------- l'infobulle
-- QuestMapLogTitleButton_OnEnter : titre, echec, texte de rendu ou texte
-- d'objectif puis objectifs (blanc, gris si remplis), argent, le rappel du
-- clic, les membres du groupe.
local function infobulle(ligne)
	local info = ligne.info
	GameTooltip:ClearAllPoints()
	GameTooltip:SetPoint("TOPLEFT", ligne, "TOPRIGHT", 34, 0)
	GameTooltip:SetOwner(ligne, "ANCHOR_PRESERVE")
	GameTooltip:SetText(info.title)
	local largeur = 20 + math.max(231, GameTooltipTextLeft1:GetStringWidth())
	if largeur > UIParent:GetRight() - WorldMapFrame:GetRight() then
		GameTooltip:ClearAllPoints()
		GameTooltip:SetPoint("TOPRIGHT", ligne, "TOPLEFT", -5, 0)
		GameTooltip:SetOwner(ligne, "ANCHOR_PRESERVE")
		GameTooltip:SetText(info.title)
	end
	if info.isComplete and info.isComplete < 0 then
		GameTooltip:AddLine(FAILED, 1, 0.125, 0.125)
	end
	GameTooltip:AddLine(" ")
	if info.isComplete and info.isComplete > 0 then
		GameTooltip:AddLine(GetQuestLogCompletionText(info.index) or TEXTE.pret, 1, 1, 1, true)
		GameTooltip:AddLine(" ")
	else
		local selection = GetQuestLogSelection()
		SelectQuestLogEntry(info.index)
		local _, objectifs = GetQuestLogQuestText()
		SelectQuestLogEntry(selection)
		GameTooltip:AddLine(objectifs, 1, 1, 1, true)
		GameTooltip:AddLine(" ")
		local separer = false
		for i = 1, GetNumQuestLeaderBoards(info.index) do
			local texte, _, fini = GetQuestLogLeaderBoard(i, info.index)
			if texte then
				local g = fini and 0.502 or 1
				GameTooltip:AddLine(QUEST_DASH .. texte, g, g, g, true)
				separer = true
			end
		end
		local requis = GetQuestLogRequiredMoney(info.index)
		if requis and requis > 0 then
			local argent = GetMoney()
			local g = 1
			if requis <= argent then
				argent = requis
				g = 0.502
			end
			GameTooltip:AddLine(QUEST_DASH .. GetMoneyString(argent) .. " / " .. GetMoneyString(requis), g, g, g)
			separer = true
		end
		if separer then
			GameTooltip:AddLine(" ")
		end
	end
	GameTooltip:AddLine(TEXTE.details, 0.098, 1, 0.098)
	GameTooltip:Show()
end

-- ------------------------------------------------------ la page d'une quete
--
-- RELEVE -- mainline/questmapframe.xml, DetailsFrame (QuestLogQuestDetailsMixin) :
--   DetailsFrame     308 x 502, TOPRIGHT (0, -1) de QuestsFrame -- donc a
--                    (-22, -1) du coin haut-droit du volet
--     Bg             QuestDetailsBackgrounds, a la largeur du cadre, la
--                    hauteur au prorata et plafonnee a 440 (rognee par
--                    SetTexCoord) -- AdjustBackgroundTexture
--     BorderFrame    QuestLogBorderFrameTemplate de (-3, 4) a (3, 17), niveau 100
--     BackFrame      307 x 52 en haut, questlog-reward-top-frame ; bouton
--                    BACK (UIPanelButtonTemplate) 90 x 22 a LEFT (11, 4)
--     ScrollFrame    298 x 430 a (5, -43), barre a (13, 17) / (13, -27)
--     RewardsFrameContainer  307 de large, BOTTOMLEFT (0, 23), niveau 50,
--                    clipChildren ; dedans RewardsFrame 307 de large :
--                    questlog-reward-header-top en haut, questlog-reward-bottom
--                    en bas, questlog-reward-tile-vertical entre les deux,
--                    "Rewards" en QuestFont_Huge a TOP (0, -22)
--     Abandon 105 x 22 BOTTOMLEFT (-3, -2), Share 103 x 22 puis Track
--                    105 x 22 a la suite ; Share porte deux separateurs
--                    UI-Frame-BtnDivMiddle, (6, 0) et (-6, 0) hors de ses bords
--   mainline/questmapframe.lua : QuestMapFrame_ShowQuestDetails,
--   _CloseQuestDetails, _ReturnFromQuestDetails, _UpdateQuestDetailsButtons,
--   SetRewardsHeight et AdjustRewardsFrameContainer.
--   mainline/questinfo.lua / .xml : QUEST_TEMPLATE_MAP_DETAILS (le texte) et
--   QUEST_TEMPLATE_MAP_REWARDS (les recompenses), MapQuestInfoRewardsFrame.
--
-- LE MOTEUR QUESTINFO N'EST PAS REPRIS : ses cadres (QuestInfoTitleHeader,
-- QuestInfoRewardsFrame...) sont uniques et partages avec la fenetre de
-- quete du PNJ, qui les re-parente a chaque affichage. La page a les siens,
-- empiles comme QuestInfo_Display les empile : chaque element en TOPLEFT
-- sur le BOTTOMLEFT du precedent, aux decalages du modele.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * clipChildren n'existe pas en 3.3.5 : le conteneur des recompenses est
--     un ScrollFrame, le seul cadre de ce client qui rogne ce qu'il porte.
--   * le fond des recompenses se repete par tuiles de 83 : SetTexCoord ne
--     repete pas une feuille d'atlas.
--   * 3.3.5 ne compte pas la hauteur d'un contenu defilant : elle est
--     additionnee element par element.
--   * absents de 3.3.5, donc absents d'ici : le portrait du donneur, les
--     boutons de chemin, le sceau de campagne, les objectifs de sort, la
--     reputation des grandes factions, les devises.
--   * 3.3.5 donne des POINTS D'ARENE en recompense, camelot n'en a plus :
--     ils prennent la forme de l'honneur, dans une section a eux.
local D = {
	largeur = 308, hauteur = 502, x = -22, y = -1, fondMax = 440,
	bordG = -3, bordH = 4, bordD = 3, bordB = 17,
	retourL = 307, retourH = 52, boutonRetourL = 90, boutonRetourX = 11, boutonRetourY = 4,
	boutonH = 22, abandonL = 105, partageL = 103, suivreL = 105, boutonsX = -3, boutonsY = -2,
	separateurX = 6,
	texteL = 298, texteH = 430, texteX = 5, texteY = -43,
	barreX = 13, barreHaut = 17, barreBas = -27,
	contenu = 289,                                   -- contentWidth
	recL = 307, recY = 23, recNiveau = 50, recMin = 124,
	recHautTuile = 56, tuile = 83, libelleY = -22,
	-- QUEST_TEMPLATE_MAP_REWARDS et questinfo.lua
	recX = 12, recY2 = -52, recSeparation = 8, recSection = 5, recRangee = 2,
	recEnPlus = 62, recSans = 59, choixL = 265,
	objetL = 134, objetH = 30, icone = 30, nomL = 92, nomH = 36,
	pas = 16,
}

-- Les modeles de texte de camelot, polices comprises (fontstyles.xml,
-- fonts.xml du client camelot) : QuestTitleFont = MORPHEUS 18 ombre
-- (1, -1) ; QuestFont = FRIZQT 13 ; QuestFontNormalSmall = FRIZQT 12 ;
-- QuestMapRewardsFont = FRIZQT 10 ; QuestFont_Huge = MORPHEUS 18.
local MORPHEUS = "Fonts\\MORPHEUS.ttf"
local POLICES = {
	titre = { MORPHEUS, 18 }, texte = { POLICE, 13 }, petit = { POLICE, 12 },
	recompense = { POLICE, 10 }, libelle = { MORPHEUS, 18 },
}

local PANNEAU = "Interface\\Buttons\\UI-Panel-Button-"
local ICONES = {
	argent = "Interface\\Icons\\INV_Misc_Coin_01",
	xp = "interface\\ForeverUI\\icons\\xp_icon",
	titre = "Interface\\Icons\\INV_Misc_Note_02",
	honneur = "interface\\ForeverUI\\icons\\pvpcurrency-honor-",
	arene = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon",
	contour = "Interface\\ForeverUI\\common\\whiteiconframe",
}

local function police(fs, modele, c)
	local p = POLICES[modele]
	fs:SetFont(p[1], p[2])
	if c then couleur(fs, c) end
end

-- UIPanelButtonTemplate de camelot : trois morceaux de UI-Panel-Button-*,
-- que le bouton de 3.3.5 etire d'une seule piece.
local function boutonPanneau(parent, nom, texte, largeur)
	local b = CreateFrame("Button", nom, parent)
	b:SetWidth(largeur)
	b:SetHeight(D.boutonH)
	local function morceau(u1, u2)
		local t = b:CreateTexture(nil, "BACKGROUND")
		t:SetTexCoord(u1, u2, 0, 0.6875)
		return t
	end
	local g = morceau(0, 0.09375)
	g:SetWidth(12)
	g:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	g:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	local d = morceau(0.53125, 0.625)
	d:SetWidth(12)
	d:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
	d:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	local m = morceau(0.09375, 0.53125)
	m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
	m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
	b.morceaux = { g, m, d }
	local function etat(suffixe)
		for _, t in ipairs(b.morceaux) do
			t:SetTexture(PANNEAU .. suffixe)
		end
	end
	etat("Up")
	local fs = b:CreateFontString(nil, "ARTWORK")
	fs:SetFontObject(GameFontNormal)
	fs:SetPoint("CENTER", b, "CENTER", 0, 0)
	b:SetFontString(fs)
	b:SetNormalFontObject(GameFontNormal)
	b:SetHighlightFontObject(GameFontHighlight)
	b:SetDisabledFontObject(GameFontDisable)
	b:SetText(texte)
	b:SetHighlightTexture(PANNEAU .. "Highlight")
	local s = b:GetHighlightTexture()
	if s then
		s:SetTexCoord(0, 0.625, 0, 0.6875)
		s:SetBlendMode("ADD")
	end
	b.actif = true
	b:SetScript("OnMouseDown", function(self)
		if self.actif then etat("Down") end
	end)
	b:SetScript("OnMouseUp", function(self)
		if self.actif then etat("Up") end
	end)
	-- UIPanelButton_OnEnable / _OnDisable
	function b:Activer(oui)
		self.actif = oui and true or false
		if oui then
			self:Enable()
			etat("Up")
		else
			self:Disable()
			etat("Disabled")
		end
	end
	return b
end

-- SmallItemButtonTemplate (+ SmallQuestRewardItemButtonTemplate) : icone
-- 30, cadre du nom QuestItemBorder a sa taille, nom 92 x 36, nombre en bas a
-- droite de l'icone, contour de qualite sur l'icone.
local function creerObjet(parent, nom)
	local b = CreateFrame("Button", nom, parent)
	b:SetWidth(D.objetL)
	b:SetHeight(D.objetH)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local icone = b:CreateTexture(nil, "BACKGROUND")
	icone:SetWidth(D.icone)
	icone:SetHeight(D.icone)
	icone:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	local cadre = b:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(cadre, "questitemborder")
	cadre:SetPoint("LEFT", icone, "RIGHT", 2, 0)
	local texte = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	texte:SetWidth(D.nomL)
	texte:SetHeight(D.nomH)
	texte:SetJustifyH("LEFT")
	texte:SetPoint("LEFT", cadre, "LEFT", 4, 0)
	local nombre = b:CreateFontString(nil, "ARTWORK", "NumberFontNormalSmall")
	nombre:SetJustifyH("RIGHT")
	nombre:SetPoint("BOTTOMRIGHT", icone, "BOTTOMRIGHT", 0, 1)
	local contour = b:CreateTexture(nil, "OVERLAY")
	contour:SetTexture(ICONES.contour)
	contour:SetAllPoints(icone)
	contour:Hide()
	b.Icon, b.NameFrame, b.Name, b.Count, b.IconBorder = icone, cadre, texte, nombre, contour
	return b
end

-- SetItemButtonCount : le nombre ne se montre qu'au-dessus de 1
local function nombreObjet(b, n)
	if n and n > 1 then
		b.Count:SetText(n)
		b.Count:Show()
	else
		b.Count:Hide()
	end
end

-- L'index d'une quete dans le journal de 3.3.5, qui n'a que des index.
local function indexDeQuete(questID)
	if not questID then return nil end
	for i = 1, GetNumQuestLogEntries() do
		local info = entree(i)
		if info and not info.isHeader and info.questID == questID then
			return i
		end
	end
	return nil
end

-- Les boutons d'une recompense : infobulle et clic de QuestInfoRewardItemMixin
-- (objet) et de QuestInfoRewardSpellCodeMixin (sort).
local function survolRecompense(self)
	local d = J.details
	if d and d.index then SelectQuestLogEntry(d.index) end
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	if self.objectType == "item" then
		GameTooltip:SetQuestLogItem(self.type, self:GetID())
		if GameTooltip_ShowCompareItem then GameTooltip_ShowCompareItem(GameTooltip) end
	elseif self.objectType == "spell" then
		GameTooltip:SetQuestLogRewardSpell()
	elseif self.infobulle then
		GameTooltip:SetText(self.infobulle, 1, 1, 1)
	else
		GameTooltip:Hide()
		return
	end
	GameTooltip:Show()
end

local function clicRecompense(self)
	if not IsModifiedClick() then return end
	local d = J.details
	if d and d.index then SelectQuestLogEntry(d.index) end
	if self.objectType == "item" then
		HandleModifiedItemClick(GetQuestLogItemLink(self.type, self:GetID()))
	elseif self.objectType == "spell" and IsModifiedClick("CHATLINK") then
		ChatEdit_InsertLink(GetQuestLogSpellLink())
	end
end

local function brancherRecompense(b)
	b:SetScript("OnEnter", survolRecompense)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnClick", clicRecompense)
	return b
end

-- Le fond des recompenses : l'en-tete, le bas, et entre les deux le motif
-- vertical, repete par tuiles de 83.
local function poserFondRecompenses(r, hauteur)
	local e = ForeverUI.AtlasEntry("questlog-reward-tile-vertical")
	local reste = hauteur - D.recHautTuile
	local n = 0
	while e and reste > 0 do
		n = n + 1
		local t = r.tuiles[n]
		if not t then
			t = r:CreateTexture(nil, "BACKGROUND")
			ForeverUI.SetAtlas(t, "questlog-reward-tile-vertical")
			r.tuiles[n] = t
		end
		local h = math.min(D.tuile, reste)
		t:SetHeight(h)
		t:SetTexCoord(e[2], e[3], e[4], e[4] + (e[5] - e[4]) * h / D.tuile)
		t:ClearAllPoints()
		t:SetPoint("TOPLEFT", r.haut, "BOTTOMLEFT", 0, -(n - 1) * D.tuile)
		t:Show()
		reste = reste - h
	end
	for i = n + 1, #r.tuiles do
		r.tuiles[i]:Hide()
	end
end

local function creerDetails(v)
	local d = CreateFrame("Frame", "ForeverUIQuestDetailsFrame", v)
	d:SetWidth(D.largeur)
	d:SetHeight(D.hauteur)
	d:SetPoint("TOPRIGHT", v, "TOPRIGHT", D.x, D.y)
	d:EnableMouse(true)

	-- le fond, a la largeur du cadre, plafonne a 440 (AdjustBackgroundTexture)
	local fond = d:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "questdetailsbackgrounds")
	local e = ForeverUI.AtlasEntry("questdetailsbackgrounds")
	fond:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
	fond:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 0)
	if e then
		local voulue = e[7] * D.largeur / e[6]
		if voulue > D.fondMax then
			fond:SetTexCoord(e[2], e[3], e[4], e[4] + (e[5] - e[4]) * D.fondMax / voulue)
			fond:SetHeight(D.fondMax)
		else
			fond:SetHeight(voulue)
		end
	end
	d.fond = fond

	-- le cadre (QuestLogBorderFrameTemplate), niveau 100
	local bord = CreateFrame("Frame", nil, d)
	bord:SetPoint("TOPLEFT", d, "TOPLEFT", D.bordG, D.bordH)
	bord:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", D.bordD, D.bordB)
	bord:SetFrameLevel(d:GetFrameLevel() + 100)
	if ForeverUI.CreateNineSlice then
		ForeverUI.CreateNineSlice(bord, "questlog-frame", 53, { 0, 0, 0, 0 }, "BORDER")
	end
	local filigrane = bord:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(filigrane, "questlog-frame-filigree")
	filigrane:SetPoint("TOP", bord, "TOP", 0, 1)
	d.bord = bord

	-- le bandeau du haut et le bouton Retour
	local bandeau = CreateFrame("Frame", nil, d)
	bandeau:SetWidth(D.retourL)
	bandeau:SetHeight(D.retourH)
	bandeau:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
	local image = bandeau:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(image, "questlog-reward-top-frame")
	image:SetPoint("TOPLEFT", bandeau, "TOPLEFT", 0, 0)
	local retour = boutonPanneau(bandeau, "ForeverUIQuestDetailsBackButton", BACK, D.boutonRetourL)
	retour:SetPoint("LEFT", bandeau, "LEFT", D.boutonRetourX, D.boutonRetourY)
	retour:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		J.revenirDeDetails()
	end)
	d.retour = retour

	-- le texte, qui defile
	local defile = CreateFrame("ScrollFrame", "ForeverUIQuestDetailsScrollFrame", d)
	defile:SetWidth(D.texteL)
	defile:SetHeight(D.texteH)
	defile:SetPoint("TOPLEFT", d, "TOPLEFT", D.texteX, D.texteY)
	local contenu = CreateFrame("Frame", "ForeverUIQuestDetailsContents", defile)
	contenu:SetWidth(D.texteL)
	contenu:SetHeight(1)
	defile:SetScrollChild(contenu)
	d.defile, d.contenu = defile, contenu

	local function texte(modele, c)
		local fs = contenu:CreateFontString(nil, "BACKGROUND")
		police(fs, modele, c)
		fs:SetJustifyH("LEFT")
		fs:SetWidth(D.contenu)
		return fs
	end
	d.titre = texte("titre", COULEUR.titre)
	d.titre:SetShadowOffset(1, -1)
	d.titre:SetShadowColor(COULEUR.ombreTitre[1], COULEUR.ombreTitre[2], COULEUR.ombreTitre[3], 1)
	d.texteObjectifs = texte("texte", COULEUR.texte)
	d.minuteur = texte("petit", COULEUR.texte)
	d.groupe = texte("texte", COULEUR.texte)
	d.enteteDescription = texte("titre", COULEUR.titre)
	d.enteteDescription:SetShadowOffset(1, -1)
	d.enteteDescription:SetShadowColor(COULEUR.ombreTitre[1], COULEUR.ombreTitre[2], COULEUR.ombreTitre[3], 1)
	d.enteteDescription:SetText(QUEST_DESCRIPTION)
	d.description = texte("texte", COULEUR.texte)
	d.objectifs = {}
	d.nouvelObjectif = function() return texte("petit", COULEUR.texte) end

	-- l'argent demande : le libelle et un petit porte-monnaie fige
	local argent = CreateFrame("Frame", nil, contenu)
	argent:SetWidth(285)
	argent:SetHeight(28)
	local argentTexte = argent:CreateFontString(nil, "BACKGROUND")
	police(argentTexte, "petit")
	argentTexte:SetPoint("LEFT", argent, "LEFT", 0, 0)
	argentTexte:SetText(REQUIRED_MONEY)
	local bourse = CreateFrame("Frame", "ForeverUIQuestDetailsRequiredMoney", argent, "SmallMoneyFrameTemplate")
	bourse:SetPoint("LEFT", argentTexte, "RIGHT", 10, 0)
	if MoneyFrame_SetType then MoneyFrame_SetType(bourse, "STATIC") end
	argent.texte, argent.bourse = argentTexte, bourse
	d.argent = argent

	-- le compte a rebours (QuestInfoTimerFrame_OnUpdate)
	local horloge = CreateFrame("Frame", nil, contenu)
	horloge:SetScript("OnUpdate", function(self, ecoule)
		if self.reste then
			self.reste = math.max(self.reste - ecoule, 0)
			d.minuteur:SetText(TIME_REMAINING .. " " .. SecondsToTime(self.reste))
		end
	end)
	d.horloge = horloge

	-- l'espace laisse aux recompenses, en bas du texte
	local espace = CreateFrame("Frame", nil, contenu)
	espace:SetWidth(5)
	espace:SetHeight(5)
	d.espace = espace

	local barre = ForeverUI.CreateScrollBar and ForeverUI.CreateScrollBar("ForeverUIQuestDetailsScrollBar", d, defile)
	if barre then
		barre:ClearAllPoints()
		barre:SetPoint("TOPLEFT", defile, "TOPRIGHT", D.barreX, D.barreHaut)
		barre:SetPoint("BOTTOMLEFT", defile, "BOTTOMRIGHT", D.barreX, D.barreBas)
		barre:SetFrameLevel(bord:GetFrameLevel() + 1)
		barre.surDefilement = function(pas)
			J.defilerDetails(pas * D.pas)
		end
		d.barre = barre
	end
	defile:EnableMouseWheel(true)
	defile:SetScript("OnMouseWheel", function(_, sens)
		if d.barre and d.barre:IsShown() then
			d.barre:Deplacer(d.barre.decalage - sens * 3)
		end
	end)

	-- les recompenses : un ScrollFrame immobile, qui rogne ce qui depasse
	local conteneur = CreateFrame("ScrollFrame", "ForeverUIQuestDetailsRewardsContainer", d)
	conteneur:SetWidth(D.recL)
	conteneur:SetHeight(100)
	conteneur:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, D.recY)
	conteneur:SetFrameLevel(d:GetFrameLevel() + D.recNiveau)
	local r = CreateFrame("Frame", "ForeverUIQuestDetailsRewardsFrame", conteneur)
	r:SetWidth(D.recL)
	r:SetHeight(275)
	conteneur:SetScrollChild(r)
	local bas = r:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(bas, "questlog-reward-bottom")
	bas:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
	local haut = r:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(haut, "questlog-reward-header-top")
	haut:SetPoint("TOPLEFT", r, "TOPLEFT", 0, 0)
	local libelle = r:CreateFontString(nil, "ARTWORK")
	police(libelle, "libelle", COULEUR.recompense)
	libelle:SetPoint("TOP", r, "TOP", 0, D.libelleY)
	libelle:SetText(TEXTE.recompenses)
	r.haut, r.bas, r.libelle, r.tuiles = haut, bas, libelle, {}
	d.conteneur, d.recompenses = conteneur, r

	-- MapQuestInfoRewardsFrame, a (12, -52)
	local liste = CreateFrame("Frame", nil, r)
	liste:SetWidth(285)
	liste:SetHeight(10)
	liste:SetPoint("TOPLEFT", r, "TOPLEFT", D.recX, D.recY2)
	local entete = CreateFrame("Frame", nil, liste)
	entete:SetWidth(1)
	entete:SetHeight(1)
	entete:SetPoint("TOPLEFT", liste, "TOPLEFT", 0, 0)
	local function libelleRecompense(largeur)
		local fs = liste:CreateFontString(nil, "BACKGROUND")
		police(fs, "recompense", COULEUR.recompense)
		fs:SetJustifyH("LEFT")
		if largeur then fs:SetWidth(largeur) end
		return fs
	end
	liste.entete = entete
	liste.choisir = libelleRecompense(D.choixL)
	liste.recevoir = libelleRecompense()
	liste.titreJoueur = libelleRecompense()
	liste.titreJoueur:SetText(REWARD_TITLE)
	liste.sort = libelleRecompense()
	liste.objets = {}
	liste.xp = brancherRecompense(creerObjet(liste))
	liste.xp.Icon:SetTexture(ICONES.xp)
	liste.xp.Name:SetFontObject(NumberFontNormal)
	liste.argent = brancherRecompense(creerObjet(liste))
	liste.argent.Icon:SetTexture(ICONES.argent)
	liste.argent.Name:SetFontObject(GameFontHighlight)
	liste.titre = brancherRecompense(creerObjet(liste))
	liste.titre.Icon:SetTexture(ICONES.titre)
	liste.honneur = brancherRecompense(creerObjet(liste))
	liste.arene = brancherRecompense(creerObjet(liste))
	liste.arene.Icon:SetTexture(ICONES.arene)
	liste.sortBouton = brancherRecompense(creerObjet(liste))
	liste.sortBouton.objectType = "spell"
	d.liste = liste

	-- Abandon, Share, Track
	local abandon = boutonPanneau(d, "ForeverUIQuestDetailsAbandonButton", ABANDON_QUEST_ABBREV, D.abandonL)
	abandon:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", D.boutonsX, D.boutonsY)
	abandon:SetScript("OnClick", function()
		if d.index then abandonner(d.index) end
	end)
	local partage = boutonPanneau(d, "ForeverUIQuestDetailsShareButton", SHARE_QUEST_ABBREV, D.partageL)
	partage:SetPoint("LEFT", abandon, "RIGHT", 0, 0)
	for i, cote in ipairs({ { "RIGHT", "LEFT", D.separateurX }, { "LEFT", "RIGHT", -D.separateurX } }) do
		local s = partage:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(s, "ui-frame-btndivmiddle")
		s:SetPoint(cote[1], partage, cote[2], cote[3], 0)
		partage["separateur" .. i] = s
	end
	partage:SetScript("OnClick", function()
		if d.index then partager(d.index) end
	end)
	local suivre = boutonPanneau(d, "ForeverUIQuestDetailsTrackButton", TRACK_QUEST_ABBREV, D.suivreL)
	suivre:SetPoint("LEFT", partage, "RIGHT", 0, 0)
	suivre:SetScript("OnClick", function()
		PlaySound("igMainMenuOptionCheckBoxOn")
		if d.index then
			basculerSuivi(d.index)
			J.majBoutonsDetails()
			J.maj()
		end
	end)
	d.abandon, d.partage, d.suivre = abandon, partage, suivre

	d:Hide()
	return d
end

-- QuestMapFrame_UpdateQuestDetailsButtons, avec les regles de 3.3.5
-- (QuestLogControlPanel_UpdateState)
function J.majBoutonsDetails()
	local d = J.details
	if not d or not d.index then return end
	-- QuestLog_SetSelection : la quete choisie est aussi celle qu'on
	-- abandonnerait, et GetAbandonQuestName la nomme si c'est permis
	SelectQuestLogEntry(d.index)
	SetAbandonQuest()
	d.abandon:Activer(GetAbandonQuestName() and true or false)
	if IsQuestWatched(d.index) then
		d.suivre:SetText(TEXTE.nePlusSuivreCourt)
	else
		d.suivre:SetText(TRACK_QUEST_ABBREV)
	end
	d.partage:Activer(GetQuestLogPushable() and enGroupe() and true or false)
end

-- QuestInfo_ShowRewards, pour ce que 3.3.5 donne. Rend la hauteur de la
-- liste, ou nil s'il n'y a rien a gagner.
local function afficherRecompenses(d)
	local l = d.liste
	for _, b in ipairs(l.objets) do b:Hide() end
	for _, f in ipairs({ l.choisir, l.recevoir, l.titreJoueur, l.sort, l.xp, l.argent,
		l.titre, l.honneur, l.arene, l.sortBouton }) do
		f:ClearAllPoints()
		f:Hide()
	end
	l.lignes, l.entetes = 0, 0

	local nbObjets = GetNumQuestLogRewards() or 0
	local nbChoix = GetNumQuestLogChoices() or 0
	local argent = GetQuestLogRewardMoney() or 0
	local xp = GetQuestLogRewardXP and GetQuestLogRewardXP() or 0
	local honneur = GetQuestLogRewardHonor() or 0
	local arene = GetQuestLogRewardArenaPoints and GetQuestLogRewardArenaPoints() or 0
	local titreJoueur = GetQuestLogRewardTitle()
	local sortIcone, sortNom, sortMetier, sortAppris = GetQuestLogRewardSpell()
	if nbObjets + nbChoix == 0 and argent == 0 and xp == 0 and honneur == 0 and arene == 0
		and not titreJoueur and not sortIcone then
		return nil
	end

	-- l'agencement de camelot : deux elements par rangee, une section
	-- repart a gauche, un en-tete occupe sa rangee a lui seul
	local total = l.entete:GetHeight()
	local ancre = l.entete
	local nouvelleSection, unParRangee, droitePosee = true, false, false
	local function section(large)
		nouvelleSection = true
		unParRangee = large and true or false
	end
	local function ajouter(f, h)
		if not nouvelleSection and not droitePosee and not unParRangee then
			f:SetPoint("TOPLEFT", ancre, "TOPRIGHT", D.recSeparation, 0)
			droitePosee = true
		else
			local ecart = nouvelleSection and D.recSection or D.recRangee
			f:SetPoint("TOPLEFT", ancre, "BOTTOMLEFT", 0, -ecart)
			total = total + (h or f:GetHeight()) + ecart
			ancre = f
			droitePosee = false
			nouvelleSection = false
			l.lignes = l.lignes + 1
		end
		f:Show()
	end
	local function entete(f)
		l.entetes = l.entetes + 1
		section(true)
		ajouter(f)
	end
	local n = 0
	local function objet(type, i, lire)
		n = n + 1
		local b = l.objets[n]
		if not b then
			b = brancherRecompense(creerObjet(l, "ForeverUIQuestDetailsRewardItem" .. n))
			l.objets[n] = b
		end
		local nom, icone, nombre, qualite, utilisable = lire(i)
		b.type, b.objectType = type, "item"
		b:SetID(i)
		b.Name:SetText(nom)
		b.Icon:SetTexture(icone)
		nombreObjet(b, nombre)
		-- BAG_ITEM_QUALITY_COLORS de camelot : commun en COMMON_GRAY_COLOR,
		-- au-dessus la couleur de qualite, mediocre sans contour
		local c = qualite and qualite >= 2 and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qualite]
		if qualite == 1 then
			b.IconBorder:SetVertexColor(COULEUR.communGris[1], COULEUR.communGris[2], COULEUR.communGris[3])
			b.IconBorder:Show()
		elseif c then
			b.IconBorder:SetVertexColor(c.r, c.g, c.b)
			b.IconBorder:Show()
		else
			b.IconBorder:Hide()
		end
		if utilisable then
			b.Icon:SetVertexColor(1, 1, 1)
			b.NameFrame:SetVertexColor(1, 1, 1)
		else
			b.Icon:SetVertexColor(0.9, 0, 0)
			b.NameFrame:SetVertexColor(0.9, 0, 0)
		end
		ajouter(b, D.objetH)
	end

	-- au choix
	if nbChoix > 0 then
		l.choisir:SetText(nbChoix == 1 and REWARD_ITEMS_ONLY or REWARD_CHOICES)
		entete(l.choisir)
		section()
		for i = 1, nbChoix do
			objet("choice", i, GetQuestLogChoiceInfo)
		end
	end
	-- le sort : 3.3.5 n'en donne qu'un
	if sortIcone then
		l.sort:SetText((sortMetier and REWARD_TRADESKILL_SPELL) or (not sortAppris and REWARD_AURA) or REWARD_SPELL)
		entete(l.sort)
		section()
		l.sortBouton.Icon:SetTexture(sortIcone)
		l.sortBouton.Name:SetText(sortNom)
		nombreObjet(l.sortBouton, 0)
		ajouter(l.sortBouton, D.objetH)
	end
	-- le titre
	if titreJoueur then
		entete(l.titreJoueur)
		l.titre.Name:SetText(titreJoueur)
		nombreObjet(l.titre, 0)
		section()
		ajouter(l.titre, D.objetH)
	end
	-- ce qu'on recoit de toute facon
	if nbObjets > 0 or argent > 0 or xp > 0 or honneur > 0 or arene > 0 then
		l.recevoir:SetText((nbChoix > 0 or sortIcone or titreJoueur) and REWARD_ITEMS or REWARD_ITEMS_ONLY)
		entete(l.recevoir)
		section()
		if xp > 0 then
			l.xp.Name:SetText(xp)
			nombreObjet(l.xp, 0)
			ajouter(l.xp, D.objetH)
		end
		if argent > 0 then
			l.argent.Name:SetText(GetMoneyString(argent))
			nombreObjet(l.argent, 0)
			ajouter(l.argent, D.objetH)
		end
		section()
		for i = 1, nbObjets do
			objet("reward", i, GetQuestLogRewardInfo)
		end
		if honneur > 0 then
			local faction = UnitFactionGroup("player") == "Horde" and "horde" or "alliance"
			l.honneur.Icon:SetTexture(ICONES.honneur .. faction)
			l.honneur.Name:SetText(HONOR)
			nombreObjet(l.honneur, honneur)
			l.honneur.infobulle = HONOR_POINTS
			section()
			ajouter(l.honneur, D.objetH)
		end
		if arene > 0 then
			l.arene.Name:SetText(ARENA_POINTS)
			nombreObjet(l.arene, arene)
			l.arene.infobulle = ARENA_POINTS
			section()
			ajouter(l.arene, D.objetH)
		end
	end
	l:SetHeight(total)
	return total
end

-- AdjustRewardsFrameContainer : si tout le texte tient, ou s'il n'y a qu'une
-- rangee, les recompenses se montrent en entier ; sinon elles grandissent a
-- mesure qu'on descend, sans passer sous 124.
function J.ajusterRecompenses()
	local d = J.details
	if not d then return end
	local r = d.recompenses
	local hauteur = r:GetHeight()
	local plage = d.plage or 0
	if plage == 0 or (d.liste.lignes - d.liste.entetes) <= 1 then
		d.conteneur:SetHeight(hauteur)
		return
	end
	local h = hauteur - (plage - (d.defile:GetVerticalScroll() or 0))
	if h < D.recMin then h = D.recMin end
	d.conteneur:SetHeight(h)
end

function J.defilerDetails(y)
	local d = J.details
	if not d then return end
	d.defile:SetVerticalScroll(math.min(y, d.plage or 0))
	J.ajusterRecompenses()
end

-- QuestInfo_Display(QUEST_TEMPLATE_MAP_DETAILS) puis (..._MAP_REWARDS) :
-- rend faux si la quete n'est plus au journal.
local function afficherDetails(debut)
	local d = J.details
	local index = indexDeQuete(d.questID)
	if not index then
		return false
	end
	d.index = index
	SelectQuestLogEntry(index)
	local info = entree(index)
	local c = d.contenu

	local dernier, total = nil, 0
	local function poser(region, dx, dy, h, bas)
		region:ClearAllPoints()
		if dernier then
			region:SetPoint("TOPLEFT", dernier, "BOTTOMLEFT", dx, dy)
		else
			region:SetPoint("TOPLEFT", c, "TOPLEFT", dx, dy)
		end
		region:Show()
		dernier = bas or region
		total = total - dy + (h or region:GetHeight() or 0)
	end

	-- le titre, l'echec en plus
	local titre = info.title
	if info.isComplete and info.isComplete < 0 then
		titre = format(TEXTE.titreEchec, titre)
	end
	d.titre:SetText(titre)
	poser(d.titre, 5, -10)
	local description, objectifs = GetQuestLogQuestText()
	d.texteObjectifs:SetText(objectifs)
	poser(d.texteObjectifs, 0, -5)

	-- le compte a rebours
	local reste = GetQuestLogTimeLeft()
	d.horloge.reste = reste
	if reste then
		d.minuteur:SetText(TIME_REMAINING .. " " .. SecondsToTime(reste))
		poser(d.minuteur, 0, -10)
	else
		d.minuteur:Hide()
	end

	-- les objectifs : remplis, ils passent au gris et disent "(Complete)"
	for _, o in ipairs(d.objectifs) do o:Hide() end
	local vus = 0
	for i = 1, GetNumQuestLeaderBoards() do
		local texte, genre, fini = GetQuestLogLeaderBoard(i)
		if genre ~= "spell" and genre ~= "log" then
			vus = vus + 1
			local o = d.objectifs[vus]
			if not o then
				o = d.nouvelObjectif()
				d.objectifs[vus] = o
			end
			if not texte or texte == "" then texte = genre end
			if fini then
				couleur(o, COULEUR.objectifFait)
				texte = texte .. " (" .. COMPLETE .. ")"
			else
				couleur(o, COULEUR.texte)
			end
			o:SetText(texte)
			poser(o, 0, vus == 1 and -10 or -2)
		end
	end

	-- l'argent demande : noir s'il en manque, gris sinon
	local requis = GetQuestLogRequiredMoney() or 0
	if requis > 0 then
		MoneyFrame_Update(d.argent.bourse:GetName(), requis)
		if requis > GetMoney() then
			couleur(d.argent.texte, { 0, 0, 0 })
			if SetMoneyFrameColor then SetMoneyFrameColor(d.argent.bourse:GetName(), "red") end
		else
			couleur(d.argent.texte, { 0.2, 0.2, 0.2 })
			if SetMoneyFrameColor then SetMoneyFrameColor(d.argent.bourse:GetName(), "white") end
		end
		poser(d.argent, 0, 0, 28)
	else
		d.argent:Hide()
	end

	-- le groupe conseille
	local groupe = GetQuestLogGroupNum() or 0
	if groupe > 0 then
		d.groupe:SetText(format(QUEST_SUGGESTED_GROUP_NUM, groupe))
		poser(d.groupe, 0, -10)
	else
		d.groupe:Hide()
	end

	poser(d.enteteDescription, 0, -20)
	d.description:SetText(description)
	poser(d.description, 0, -5)

	-- les recompenses (SetRewardsHeight) : leur hauteur, plus 62, ou 59
	-- sans rien ; l'espace en bas du texte leur laisse la meme place
	local liste = afficherRecompenses(d)
	local hauteur
	if liste then
		d.liste:Show()
		hauteur = liste + D.recEnPlus
	else
		d.liste:Hide()
		hauteur = D.recSans
	end
	d.recompenses:SetHeight(hauteur)
	poserFondRecompenses(d.recompenses, hauteur)
	if d.liste.lignes - d.liste.entetes > 0 then
		d.recompenses.libelle:Show()
	else
		d.recompenses.libelle:Hide()
	end
	d.espace:SetHeight(hauteur)
	poser(d.espace, 0, 0, hauteur)

	c:SetHeight(math.max(total, 1))
	d.plage = math.max(0, total - D.texteH)
	if d.barre then
		local lignes = math.ceil(total / D.pas)
		local visibles = math.floor(D.texteH / D.pas)
		local decalage = debut and 0 or math.min(d.barre.decalage or 0, math.max(0, lignes - visibles))
		d.barre:Regler(lignes, visibles, decalage)
		d.defile:SetVerticalScroll(math.min(decalage * D.pas, d.plage))
	else
		d.defile:SetVerticalScroll(0)
	end
	J.ajusterRecompenses()
	J.majBoutonsDetails()
	return true
end

function J.detailsOuverts()
	return J.details and J.details:IsShown() and true or false
end

-- QuestMapFrame_ShowQuestDetails : la carte passe sur la quete (en gardant
-- celle qu'on quitte), la liste s'efface, la page se montre.
function J.ouvrirDetails(info)
	local d = J.details
	if not d or not info or not info.questID then
		montrerSurCarte(info)
		return
	end
	d.retourCarte = GetCurrentMapAreaID and GetCurrentMapAreaID()
	d.retourEtage = GetCurrentMapDungeonLevel and GetCurrentMapDungeonLevel()
	d.carte = nil
	d.questID = info.questID
	montrerSurCarte(info)
	d.carte = GetCurrentMapAreaID and GetCurrentMapAreaID()
	StaticPopup_Hide("ABANDON_QUEST")
	StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
	-- montree AVANT d'etre remplie : les textes se mesurent visibles
	J.volet.liste:Hide()
	if J.volet.barre then J.volet.barre:Hide() end
	d:Show()
	if not afficherDetails(true) then
		J.fermerDetails()
	end
end

-- QuestMapFrame_CloseQuestDetails
function J.fermerDetails()
	local d = J.details
	if not d then return end
	d:Hide()
	d.questID, d.index, d.carte, d.retourCarte, d.retourEtage = nil, nil, nil, nil, nil
	d.horloge.reste = nil
	J.volet.liste:Show()
	StaticPopup_Hide("ABANDON_QUEST")
	StaticPopup_Hide("ABANDON_QUEST_WITH_ITEMS")
	J.maj()
end

-- QuestMapFrame_ReturnFromQuestDetails : la carte revient ou elle etait
function J.revenirDeDetails()
	local d = J.details
	if not d then return end
	local carte, etage = d.retourCarte, d.retourEtage
	if carte and SetMapByID then
		SetMapByID(carte)
		if etage and etage > 0 and SetDungeonMapLevel then
			SetDungeonMapLevel(etage)
		end
	end
	J.fermerDetails()
end

-- QuestLogMixin:Refresh et QuestMapFrame_UpdateAll : la page suit le
-- journal ; une quete qui en sort ramene a la liste ; une carte qui n'est
-- plus celle de la quete referme la page.
function J.majDetails()
	local d = J.details
	if not J.detailsOuverts() then return end
	if d.carte and GetCurrentMapAreaID and GetCurrentMapAreaID() ~= d.carte then
		J.fermerDetails()
		return
	end
	if not afficherDetails(false) then
		J.revenirDeDetails()
	end
end

-- ------------------------------------------------------------- le volet

local function creerVolet(carte)
	local v = CreateFrame("Frame", "ForeverUIQuestLogPanel", carte)
	v:SetFrameStrata("HIGH")
	v:EnableMouse(true)
	v:SetWidth(V.largeur)
	v:SetPoint("TOPRIGHT", carte, "TOPRIGHT", V.x, V.haut)
	v:SetPoint("BOTTOMRIGHT", carte, "BOTTOMRIGHT", V.x, V.bas)

	-- QuestsFrame, puis QuestScrollFrame
	local liste = CreateFrame("ScrollFrame", "ForeverUIQuestScrollFrame", v)
	liste:SetPoint("TOPLEFT", v, "TOPLEFT", 0, V.listeHaut)
	liste:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", V.listeDroite, V.listeBas)
	v.liste = liste

	local fond = liste:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, "questlog-main-background-2x")
	fond:SetPoint("TOPLEFT", liste, "TOPLEFT", 0, 0)
	v.fond = fond

	local vide = liste:CreateFontString(nil, "ARTWORK")
	vide:SetFont(POLICE, 16)
	vide:SetWidth(250)
	vide:SetPoint("CENTER", liste, "CENTER", 0, 50)
	vide:SetText(TEXTE.vide)
	vide:Hide()
	v.vide = vide
	local aucun = liste:CreateFontString(nil, "ARTWORK")
	aucun:SetFont(POLICE, 14)
	aucun:SetWidth(250)
	aucun:SetPoint("TOP", liste, "TOP", 0, -30)
	aucun:SetText(TEXTE.aucunResultat)
	aucun:Hide()
	v.aucun = aucun

	local contenu = CreateFrame("Frame", "ForeverUIQuestScrollContents", liste)
	contenu:SetWidth(304)
	contenu:SetHeight(454)
	liste:SetScrollChild(contenu)
	v.contenu = contenu

	-- le cadre : questlog-frame etire, le filigrane en haut, l'ombre en bas
	local bord = CreateFrame("Frame", nil, liste)
	bord:SetPoint("TOPLEFT", liste, "TOPLEFT", -3, 7)
	bord:SetPoint("BOTTOMRIGHT", liste, "BOTTOMRIGHT", 3, -6)
	v.bord = bord
	bord:SetFrameLevel(liste:GetFrameLevel() + 20)
	-- questlog-frame est DECOUPE EN NEUF par le moteur de camelot : ses marges
	-- sont dans UiTextureAtlasElementSliceData.db2 du client camelot --
	-- 53 / 53 / 53 / 53 pour un element de 107 x 107 (mode 1). Etire d'une
	-- seule piece, il deformait ses moulures (constate le 2026-09-25).
	if ForeverUI.CreateNineSlice then
		ForeverUI.CreateNineSlice(bord, "questlog-frame", 53, { 0, 0, 0, 0 }, "BORDER")
	end
	local filigrane = bord:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(filigrane, "questlog-frame-filigree")
	filigrane:SetPoint("TOP", bord, "TOP", 0, 1)
	local ombre = bord:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(ombre, "questlog-frame-gradient-bottom")
	ombre:SetPoint("BOTTOM", bord, "BOTTOM", 0, 4)
	v.ombre = ombre

	-- la barre de defilement, par pas de 16
	local barre = ForeverUI.CreateScrollBar and ForeverUI.CreateScrollBar("ForeverUIQuestScrollBar", v, liste)
	if barre then
		barre:ClearAllPoints()
		barre:SetPoint("TOPLEFT", liste, "TOPRIGHT", V.barreX, V.barreHaut)
		barre:SetPoint("BOTTOMLEFT", liste, "BOTTOMRIGHT", V.barreX, V.barreBas)
		barre:SetFrameLevel(bord:GetFrameLevel() + 1)
		barre.surDefilement = function(pas)
			liste:SetVerticalScroll(pas * V.pas)
			J.majOmbre()
		end
		v.barre = barre
	end
	liste:EnableMouseWheel(true)
	liste:SetScript("OnMouseWheel", function(_, sens)
		if v.barre and v.barre:IsShown() then
			v.barre:Deplacer(v.barre.decalage - sens * 3)
		end
	end)

	-- la recherche (SearchBoxTemplate)
	local r = CreateFrame("EditBox", "ForeverUIQuestSearchBox", liste)
	r:SetWidth(V.rechercheL)
	r:SetHeight(V.rechercheH)
	r:SetPoint("BOTTOMLEFT", liste, "TOPLEFT", V.rechercheX, V.rechercheY)
	r:SetAutoFocus(false)
	r:SetMaxLetters(60)
	r:SetFontObject("GameFontHighlightSmall")
	r:SetTextInsets(16, 20, 0, 0)
	local function bordure(parent, prefixe)
		local g = parent:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(g, prefixe .. "-left", true)
		g:SetWidth(8) g:SetHeight(20)
		g:SetPoint("LEFT", parent, "LEFT", -5, 0)
		local d = parent:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(d, prefixe .. "-right", true)
		d:SetWidth(8) d:SetHeight(20)
		d:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
		local m = parent:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(m, prefixe .. "-middle", true)
		m:SetPoint("TOPLEFT", g, "TOPRIGHT")
		m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
		return g, m, d
	end
	bordure(r, "common-search-border")
	local loupe = r:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(loupe, "common-search-magnifyingglass", true)
	loupe:SetWidth(10) loupe:SetHeight(10)
	loupe:SetPoint("LEFT", r, "LEFT", 1, -1)
	local consigne = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	consigne:SetPoint("TOPLEFT", r, "TOPLEFT", 16, 0)
	consigne:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -20, 0)
	consigne:SetJustifyH("LEFT")
	consigne:SetTextColor(0.35, 0.35, 0.35)
	consigne:SetText(TEXTE.recherche)
	local effacer = CreateFrame("Button", nil, r)
	effacer:SetWidth(17) effacer:SetHeight(17)
	effacer:SetPoint("RIGHT", r, "RIGHT", -3, 0)
	local croix = effacer:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(croix, "common-search-clearbutton", true)
	croix:SetWidth(10) croix:SetHeight(10)
	croix:SetPoint("CENTER", effacer, "CENTER", 0, 0)
	croix:SetAlpha(0.5)
	effacer:SetScript("OnEnter", function() croix:SetAlpha(1) end)
	effacer:SetScript("OnLeave", function() croix:SetAlpha(0.5) end)
	effacer:SetScript("OnClick", function()
		r:SetText("")
		r:ClearFocus()
	end)
	effacer:Hide()
	r:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	r:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	r:SetScript("OnEditFocusGained", function() consigne:Hide() end)
	r:SetScript("OnEditFocusLost", function(self)
		if self:GetText() == "" then consigne:Show() end
	end)
	r:SetScript("OnTextChanged", function(self)
		local t = self:GetText()
		if t == "" then effacer:Hide() else effacer:Show() consigne:Hide() end
		J.chercher(t)
	end)
	v.recherche = r

	-- le compteur (InputBoxVisualTemplate)
	local compteur = CreateFrame("Frame", "ForeverUIQuestLogCount", liste)
	compteur:SetWidth(V.compteurL)
	compteur:SetHeight(V.compteurH)
	compteur:SetPoint("TOPLEFT", r, "TOPRIGHT", V.compteurX, 0)
	local _, _, droite = bordure(compteur, "common-search-border")
	local texteCompteur = compteur:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	texteCompteur:SetPoint("TOPRIGHT", droite, "TOPRIGHT", -5, -5)
	compteur.texte = texteCompteur
	-- LE COMPTEUR DE QUOTIDIENNES (WotLK seul, conserve par decision) : camelot
	-- n'a pas de place pour lui ; il vit dans l'infobulle du compteur.
	compteur:EnableMouse(true)
	compteur:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
		GameTooltip:SetText(format(QUEST_LOG_DAILY_COUNT_TEMPLATE, GetDailyQuestsCompleted(), GetMaxDailyQuests()))
		if QUEST_LOG_DAILY_TOOLTIP then
			GameTooltip:AddLine(format(QUEST_LOG_DAILY_TOOLTIP, GetMaxDailyQuests(), SecondsToTime(GetQuestResetTime(), nil, 1)), 1, 1, 1, true)
		end
		GameTooltip:Show()
	end)
	compteur:SetScript("OnLeave", function() GameTooltip:Hide() end)
	v.compteur = compteur

	-- les reglages : une case, les objectifs
	local reglage = CreateFrame("Button", "ForeverUIQuestSettingsButton", liste)
	reglage:SetWidth(V.reglageL)
	reglage:SetHeight(V.reglageH)
	reglage:SetPoint("TOPRIGHT", liste, "TOPRIGHT", V.reglageX, V.reglageY)
	local icone = reglage:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(icone, "questlog-icon-setting")
	icone:SetPoint("CENTER", reglage, "CENTER", 0, 0)
	local survol = reglage:CreateTexture(nil, "HIGHLIGHT")
	ForeverUI.SetAtlas(survol, "questlog-icon-setting")
	survol:SetPoint("CENTER", reglage, "CENTER", 0, 0)
	survol:SetBlendMode("ADD")
	survol:SetAlpha(0.4)
	reglage:SetScript("OnMouseDown", function() icone:SetPoint("CENTER", reglage, "CENTER", 1, -1) end)
	reglage:SetScript("OnMouseUp", function() icone:SetPoint("CENTER", reglage, "CENTER", 0, 0) end)
	reglage:SetScript("OnClick", function(self)
		menu(self, { {
			text = TEXTE.montrerObjectifs,
			checked = reglages().objectifs,
			keepShownOnClick = 1,
			func = function()
				reglages().objectifs = not reglages().objectifs
				J.maj()
			end,
		} })
	end)
	v.reglage = reglage

	v.entetes, v.quetes, v.objectifs = {}, {}, {}
	J.details = creerDetails(v)
	v:Hide()
	return v
end

-- --------------------------------------------------------------- les lignes

local function creerEntete(v, i)
	local b = CreateFrame("Button", "ForeverUIQuestLogHeader" .. i, v.contenu)
	b:SetWidth(V.enteteL)
	b:SetHeight(V.enteteH)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	local fondNom = ForeverUI.AtlasEntry("common-button-list-collapseexpand")
	b:SetNormalTexture(fondNom[1])
	ForeverUI.SetAtlas(b:GetNormalTexture(), "common-button-list-collapseexpand", true)
	b:SetHighlightTexture(fondNom[1])
	local s = b:GetHighlightTexture()
	ForeverUI.SetAtlas(s, "common-button-list-collapseexpand", true)
	s:SetBlendMode("ADD")
	s:SetAlpha(0.4)

	local plus = CreateFrame("Button", nil, b)
	plus:SetWidth(20) plus:SetHeight(20)
	plus:SetPoint("RIGHT", b, "RIGHT", -6, 0)
	plus:EnableMouse(false)
	plus.Icon = plus:CreateTexture(nil, "ARTWORK")
	plus.Icon:SetPoint("CENTER", plus, "CENTER", 0, 0)
	b.plus = plus

	local texte = b:CreateFontString(nil, "OVERLAY")
	texte:SetFont(POLICE, 15)
	texte:SetShadowOffset(1, -1)
	texte:SetShadowColor(0, 0, 0, 1)
	texte:SetJustifyH("LEFT")
	texte:SetPoint("LEFT", b, "LEFT", 8, 0)
	texte:SetPoint("RIGHT", plus, "LEFT", -4, 0)
	b.texte = texte

	b:SetScript("OnEnter", function(self) couleur(self.texte, COULEUR.enteteSurvol) end)
	b:SetScript("OnLeave", function(self) couleur(self.texte, COULEUR.enteteRepos) end)
	b:SetScript("OnMouseDown", function(self)
		self.texte:SetPoint("LEFT", self, "LEFT", 9, -1)
		self.plus.Icon:SetPoint("CENTER", self.plus, "CENTER", 1, -1)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.texte:SetPoint("LEFT", self, "LEFT", 8, 0)
		self.plus.Icon:SetPoint("CENTER", self.plus, "CENTER", 0, 0)
	end)
	b:SetScript("OnClick", function(self, bouton)
		PlaySound("igMainMenuOptionCheckBoxOn")
		if bouton == "RightButton" then
			local nom = self.info.title
			menu(self, {
				{ text = TEXTE.toutSuivre, func = function() suivreEntete(nom, true) end },
				{ text = TEXTE.neRienSuivre, func = function() suivreEntete(nom, false) end },
			})
		elseif self.info.isCollapsed then
			ExpandQuestHeader(self.info.index)
		else
			CollapseQuestHeader(self.info.index)
		end
	end)
	return b
end

local function creerQuete(v, i)
	local b = CreateFrame("Button", "ForeverUIQuestLogTitle" .. i, v.contenu)
	b:SetWidth(V.queteL)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	-- la case de suivi, 14 x 14, marges de souris -10
	local case = CreateFrame("Button", nil, b)
	case:SetWidth(V.caseCote) case:SetHeight(V.caseCote)
	case:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, V.caseY)
	case:SetHitRectInsets(-10, -10, -10, -10)
	local carre = case:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(carre, "questlog-icon-ticksquare")
	carre:SetPoint("CENTER", case, "CENTER", 0, 0)
	local coche = case:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(coche, "questlog-icon-checkmark-yellow")
	coche:SetPoint("CENTER", case, "CENTER", 1, 1)
	local survolCase = case:CreateTexture(nil, "HIGHLIGHT")
	ForeverUI.SetAtlas(survolCase, "questlog-icon-ticksquare")
	survolCase:SetPoint("CENTER", case, "CENTER", 0, 0)
	survolCase:SetBlendMode("ADD")
	survolCase:SetAlpha(0.4)
	case:SetScript("OnClick", function()
		PlaySound(IsQuestWatched(b.index) and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOn")
		basculerSuivi(b.index)
	end)
	b.case, b.coche = case, coche

	-- la surbrillance, sous le texte (couche BORDER)
	local lueur = b:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(lueur, "questlog-quest-glow-yellow")
	lueur:Hide()
	b.lueur = lueur

	local texte = b:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
	texte:SetPoint("TOPLEFT", b, "TOPLEFT", V.queteTexteX, V.queteTexteY)
	texte:SetJustifyH("LEFT")
	b.texte = texte
	local tag = b:CreateFontString(nil, "ARTWORK", "GameFontNormalLeft")
	tag:SetPoint("RIGHT", case, "LEFT", -4, 0)
	tag:SetPoint("TOP", texte, "TOP", 0, 0)
	tag:Hide()
	b.tag = tag
	lueur:SetPoint("TOP", texte, "TOP", 0, 4)
	lueur:SetPoint("BOTTOM", texte, "BOTTOM", 0, -4)

	b:SetScript("OnEnter", function(self)
		local c = COULEUR.difficulteSurvol[self.difficulte]
		couleur(self.texte, c)
		couleur(self.tag, c)
		for _, o in ipairs(self.lignesObjectif) do
			couleur(o.texte, COULEUR.objectifSurvol)
			couleur(o.tiret, COULEUR.objectifSurvol)
		end
		self.lueur:Show()
		zone(self.info, true)
		infobulle(self)
	end)
	b:SetScript("OnLeave", function(self)
		local c = COULEUR.difficulte[self.difficulte]
		couleur(self.texte, c)
		couleur(self.tag, c)
		for _, o in ipairs(self.lignesObjectif) do
			couleur(o.texte, COULEUR.objectif)
			couleur(o.tiret, COULEUR.objectif)
		end
		self.lueur:Hide()
		zone(self.info, false)
		GameTooltip:Hide()
	end)
	b:SetScript("OnMouseDown", function(self)
		self.texte:SetPoint("TOPLEFT", self, "TOPLEFT", V.queteTexteX + 1, V.queteTexteY - 1)
	end)
	b:SetScript("OnMouseUp", function(self)
		self.texte:SetPoint("TOPLEFT", self, "TOPLEFT", V.queteTexteX, V.queteTexteY)
	end)
	b:SetScript("OnClick", function(self, bouton)
		if IsModifiedClick("CHATLINK") and ChatEdit_InsertLink and ChatEdit_InsertLink(GetQuestLink(self.index)) then
			return
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
		if IsShiftKeyDown() then
			basculerSuivi(self.index)
		elseif bouton == "RightButton" then
			menuQuete(self)
		else
			J.ouvrirDetails(self.info)
		end
	end)
	b.lignesObjectif = {}
	return b
end

local function creerObjectif(v, i)
	local o = CreateFrame("Frame", nil, v.contenu)
	o:SetWidth(V.objectifL)
	local tiret = o:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	tiret:SetPoint("TOPLEFT", o, "TOPLEFT", 0, 0)
	tiret:SetHeight(16)
	tiret:SetText(QUEST_DASH)
	local texte = o:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	texte:SetWidth(V.objectifTexteL)
	texte:SetJustifyH("LEFT")
	texte:SetJustifyV("TOP")
	texte:SetPoint("TOPLEFT", tiret, "TOPRIGHT", 0, 0)
	o.tiret, o.texte = tiret, texte
	return o
end

local function prendre(v, liste, n, fabrique)
	local f = liste[n]
	if not f then
		f = fabrique(v, n)
		liste[n] = f
	end
	f:ClearAllPoints()
	f:Show()
	return f
end

-- QuestLogQuests_AddQuestButton, pour 3.3.5
local function remplirQuete(v, b, info, compte)
	b.info, b.index = info, info.index
	b.difficulte = cleDifficulte(info.level)
	local c = COULEUR.difficulte[b.difficulte]
	b.texte:SetText(titreQuete(info))
	couleur(b.texte, c)
	couleur(b.tag, c)
	if estElite(info) then
		b.tag:SetText(format(PARENS_TEMPLATE, ELITE))
		b.tag:Show()
		b.texte:SetPoint("RIGHT", b.tag, "LEFT", -4, 0)
	else
		b.tag:Hide()
		b.texte:SetPoint("RIGHT", b.case, "LEFT", -4, 0)
	end
	if IsQuestWatched(info.index) then b.coche:Show() else b.coche:Hide() end
	b.lueur:Hide()

	local hauteur = 8 + b.texte:GetHeight()
	for _, o in ipairs(b.lignesObjectif) do o:Hide() end
	b.lignesObjectif = {}
	local function objectif(texte, precedent)
		compte.o = compte.o + 1
		local o = prendre(v, v.objectifs, compte.o, creerObjectif)
		o.texte:SetText(texte)
		couleur(o.texte, COULEUR.objectif)
		couleur(o.tiret, COULEUR.objectif)
		local h = o.texte:GetHeight()
		o:SetHeight(h)
		if precedent then
			o:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, -2)
			h = h + 2
		else
			o:SetPoint("TOPLEFT", b.texte, "BOTTOMLEFT", 0, -3)
			h = h + 3
		end
		table.insert(b.lignesObjectif, o)
		hauteur = hauteur + h
		return o
	end

	if not reglages().objectifs then
		hauteur = hauteur + 4
	elseif info.isComplete and info.isComplete > 0 then
		objectif(GetQuestLogCompletionText(info.index) or TEXTE.pret)
	else
		local precedent
		for i = 1, GetNumQuestLeaderBoards(info.index) do
			local texte, _, fini = GetQuestLogLeaderBoard(i, info.index)
			if texte and not fini then
				precedent = objectif(texte, precedent)
			end
		end
		local requis = GetQuestLogRequiredMoney(info.index)
		local argent = GetMoney()
		if requis and requis > argent then
			objectif(GetMoneyString(argent) .. " / " .. GetMoneyString(requis), precedent)
		end
	end
	-- le repere : celui de la carte affichee, s'il y en a un. POIButton de
	-- camelot : 20 x 20 a (6, -4) ; celui de WotLK fait 32 x 32 : on le centre
	-- au meme endroit.
	local r = compte.reperes and info.questID and compte.reperes[info.questID]
	if r and QuestPOI_DisplayButton then
		local poi = QuestPOI_DisplayButton(PARENT_REPERES, r[1], r[2], info.questID)
		poi:ClearAllPoints()
		poi:SetPoint("CENTER", b, "TOPLEFT", 6 + 10, -4 - 10)
		poi:SetFrameLevel(b:GetFrameLevel() + 2)
		poi.info = info
		poi:SetScript("OnClick", function(self)
			PlaySound("igMainMenuOptionCheckBoxOn")
			montrerSurCarte(self.info)
		end)
		if queteSelectionnee() == info.questID and QuestPOI_SelectButton then
			QuestPOI_SelectButton(poi)
		end
	end
	-- la place du repere de quete (+6 dans la source)
	hauteur = hauteur + 6
	b:SetHeight(hauteur)
end

-- QuestLogQuests_Update : tout est reconstruit a chaque passage.
function J.maj()
	local v = J.volet
	if not v or not v:IsShown() then
		return
	end
	for _, f in ipairs(v.entetes) do f:Hide() end
	for _, f in ipairs(v.quetes) do f:Hide() end
	for _, f in ipairs(v.objectifs) do f:Hide() end

	local compte = { e = 0, q = 0, o = 0, reperes = reperesDeLaCarte() }
	if QuestPOI_HideAllButtons then
		QuestPOI_HideAllButtons(PARENT_REPERES)
	end
	local haut = 0
	local precedent = nil          -- "entete", "quete" ou nil
	local enteteCourant = nil
	local enteteAffiche = false
	local enAttente = nil          -- un en-tete qui attend sa premiere quete

	local function poser(f, type, gauche)
		local ecart
		if type == "entete" then
			ecart = (precedent == nil and ECART.enteteApresRien)
				or (precedent == "entete" and ECART.enteteApresEntete)
				or ECART.enteteApresQuete
		else
			ecart = (precedent == "entete" and ECART.queteApresEntete) or ECART.queteApresQuete
		end
		haut = haut + ecart
		f:SetPoint("TOPLEFT", v.contenu, "TOPLEFT", gauche, -haut)
		haut = haut + f:GetHeight()
		precedent = type
	end

	local function poserEntete(info)
		compte.e = compte.e + 1
		local e = prendre(v, v.entetes, compte.e, creerEntete)
		e.info = info
		e.texte:SetText(info.title)
		couleur(e.texte, COULEUR.enteteRepos)
		ForeverUI.SetAtlas(e.plus.Icon, info.isCollapsed and "common-button-list-plus" or "common-button-list-minus")
		poser(e, "entete", V.enteteX)
	end

	local numQuetes = 0
	for i = 1, GetNumQuestLogEntries() do
		local info = entree(i)
		if info and info.isHeader then
			enteteCourant = info
			-- un en-tete replie cache ses quetes : on le montre tel quel ;
			-- deplie, il attend une quete a montrer (QuestLogQuests_ShouldShowHeaderButton)
			if info.isCollapsed and not R.texte then
				poserEntete(info)
				enAttente = nil
			else
				enAttente = info
			end
		elseif info then
			numQuetes = numQuetes + 1
			if correspond(info) then
				if enAttente then
					poserEntete(enAttente)
					enAttente = nil
				end
				compte.q = compte.q + 1
				local b = prendre(v, v.quetes, compte.q, creerQuete)
				remplirQuete(v, b, info, compte)
				poser(b, "quete", 0)
			end
		end
	end

	v.contenu:SetHeight(math.max(haut, 1))

	-- le fond : vide, ou normal ; rogne a la hauteur du cadre
	local rien = (compte.q == 0 and compte.e == 0)
	-- En double densite : sur l'ecran de l'utilisateur (echelle 0,64 en
	-- 3840 x 1600), la variante 1x etait agrandie et se voyait pixelisee.
	local atlas = (rien and not R.texte) and "questlog-empty-quest-background-2x" or "questlog-main-background-2x"
	ForeverUI.SetAtlas(v.fond, atlas)
	local e = ForeverUI.AtlasEntry(atlas)
	local hFrame = v.liste:GetHeight() or 0
	if e and hFrame > 0 and hFrame < e[7] then
		v.fond:SetHeight(hFrame)
		v.fond:SetTexCoord(e[2], e[3], e[4], e[4] + (e[5] - e[4]) * hFrame / e[7])
	end
	if rien and not R.texte then v.vide:Show() else v.vide:Hide() end
	if rien and R.texte then v.aucun:Show() else v.aucun:Hide() end
	if rien and not R.texte then
		v.recherche:EnableMouse(false)
	else
		v.recherche:EnableMouse(true)
	end

	-- le compteur de camelot, avec le maximum de WotLK
	local _, quetes = GetNumQuestLogEntries()
	quetes = quetes or numQuetes
	local rouge = quetes > MAX_QUESTLOG_QUESTS
	v.compteur.texte:SetText(format(TEXTE.compteur, rouge and RED_FONT_COLOR_CODE or "|cffffffff", quetes, MAX_QUESTLOG_QUESTS))

	-- la barre
	if v.barre then
		local total = math.ceil(haut / V.pas)
		local visibles = math.floor(hFrame / V.pas)
		local decalage = math.min(v.barre.decalage or 0, math.max(0, total - visibles))
		v.barre:Regler(total, visibles, decalage)
		v.liste:SetVerticalScroll(decalage * V.pas)
	end
	-- LE CADRE ET LE FOND SUIVENT LA BARRE (demande du 2026-09-25) : barre
	-- masquee, ils s'etendent sur les 22 de sa place, jusqu'au bord du volet
	-- -- le bord droit du cadre deborde alors de 3, en miroir de son bord
	-- gauche ; barre montree, ils gardent la taille de camelot.
	local place = (v.barre and v.barre:IsShown()) and 0 or -V.listeDroite
	v.bord:ClearAllPoints()
	v.bord:SetPoint("TOPLEFT", v.liste, "TOPLEFT", -3, 7)
	v.bord:SetPoint("BOTTOMRIGHT", v.liste, "BOTTOMRIGHT", 3 + place, -6)
	if e then
		v.fond:SetWidth(e[6] + place)
	end
	J.majOmbre()
	-- la page d'une quete est ouverte : la liste reste cachee, sa barre aussi
	if J.detailsOuverts() and v.barre then
		v.barre:Hide()
	end
end

-- l'ombre du bas s'efface a mesure qu'on approche de la fin
function J.majOmbre()
	local v = J.volet
	if not v then return end
	local plage = math.max(0, v.contenu:GetHeight() - (v.liste:GetHeight() or 0))
	local defile = v.liste:GetVerticalScroll() or 0
	local h = v.ombre:GetHeight() or 1
	local alpha = (plage - defile) / (h > 0 and h or 1)
	if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
	v.ombre:SetAlpha(alpha)
end

-- ------------------------------------------------------ montrer, cacher

function J.estOuvert()
	return J.volet and J.volet:IsShown()
end

-- Appele par WorldMap.lua quand il pose la petite fenetre : le volet suit
-- l'etat retenu (questLogOpen).
function J.poser()
	local v = J.volet
	if not v then return end
	if reglages().volet then v:Show() else v:Hide() end
	J.maj()
end

function J.cacher()
	if J.volet then J.volet:Hide() end
end

-- HandleUserActionToggleSidePanel
function J.basculerVolet()
	reglages().volet = not reglages().volet
	if ForeverUI.WorldMap and ForeverUI.WorldMap.poserReduit then
		ForeverUI.WorldMap.poserReduit()
	end
end

-- L : HandleUserActionToggleQuestLog. Carte ouverte avec le volet -> on la
-- ferme ; sinon on l'ouvre en petite fenetre, volet ouvert. WotLK garde son
-- mode de taille d'une ouverture a l'autre ; en plein ecran, on repasse en
-- petite fenetre par sa propre fonction.
function J.basculerJournal()
	if WorldMapFrame:IsShown() and J.estOuvert() then
		HideUIPanel(WorldMapFrame)
		return
	end
	-- Montrer QuestLogFrame a pu fermer la carte avant nous : en mode
	-- deplacable elle est un panneau "center" qui cede sa place
	-- (UIParent.lua:1355). Fermee dans cette meme image avec son volet, c'est
	-- que L voulait la fermer.
	if J.fermeeA and J.fermeeA == GetTime() and J.fermeeAvecVolet then
		J.fermeeA = nil
		return
	end
	reglages().volet = true
	if WORLDMAP_SETTINGS.size ~= WORLDMAP_WINDOWED_SIZE then
		if WorldMapFrame:IsShown() then
			WorldMapFrame_ToggleWindowSize()
			return
		end
		WorldMap_ToggleSizeDown()
	end
	if WorldMapFrame:IsShown() then
		if ForeverUI.WorldMap and ForeverUI.WorldMap.poserReduit then
			ForeverUI.WorldMap.poserReduit()
		end
	else
		ShowUIPanel(WorldMapFrame)
	end
end

-- QuestMapFrame_OpenToQuestDetails, appele par le suivi de quetes : la carte
-- en petite fenetre, le volet ouvert, puis la page de la quete.
function J.ouvrirPage(index)
	local info = entree(index)
	if not info or info.isHeader then
		return
	end
	reglages().volet = true
	if WORLDMAP_SETTINGS.size ~= WORLDMAP_WINDOWED_SIZE then
		if WorldMapFrame:IsShown() then
			WorldMapFrame_ToggleWindowSize()
		else
			WorldMap_ToggleSizeDown()
		end
	end
	if WorldMapFrame:IsShown() then
		if ForeverUI.WorldMap and ForeverUI.WorldMap.poserReduit then
			ForeverUI.WorldMap.poserReduit()
		end
	else
		ShowUIPanel(WorldMapFrame)
	end
	J.ouvrirDetails(info)
end

-- -------------------------------------------------------------- l'assemblage

local function construire()
	if J.volet or not WorldMapFrame then
		return J.volet
	end
	J.volet = creerVolet(WorldMapFrame)
	return J.volet
end
J.construire = construire

-- QuestLogFrame reste en place, invisible (decision 3) : ses fonctions et son
-- OnShow marchent pour les addons, mais le montrer ouvre le volet. Le greffon
-- passe APRES ShowUIPanel : on le referme dans la meme image, il n'est jamais
-- dessine.
if hooksecurefunc then
	hooksecurefunc("ShowUIPanel", function(cadre)
		if cadre and cadre == QuestLogFrame and QuestLogFrame:IsShown() then
			HideUIPanel(QuestLogFrame)
			J.basculerJournal()
		end
	end)
end

-- A l'entree en jeu, camelot deplie la zone ou l'on est et replie les autres
-- (QuestMapFrame_ResetFilters). 3.3.5 ne dit pas quel en-tete est "sur la
-- carte" : c'est celui qui porte le nom de la zone.
local function replierSelonZone()
	local zone = GetRealZoneText and GetRealZoneText()
	if not zone or zone == "" then
		return
	end
	for i = GetNumQuestLogEntries(), 1, -1 do
		local info = entree(i)
		if info and info.isHeader then
			if info.title == zone then
				if info.isCollapsed then ExpandQuestHeader(i) end
			elseif not info.isCollapsed then
				CollapseQuestHeader(i)
			end
		end
	end
end
J.replierSelonZone = replierSelonZone

-- WotLK refait ses reperes a chaque changement de carte ou de quete : la liste
-- reprend leurs numeros.
if hooksecurefunc and WorldMapFrame_UpdateQuests then
	hooksecurefunc("WorldMapFrame_UpdateQuests", function()
		if J.estOuvert() then
			J.maj()
			J.majDetails()
		end
	end)
end

if WorldMapFrame and WorldMapFrame.HookScript then
	WorldMapFrame:HookScript("OnHide", function()
		J.fermeeA = GetTime()
		J.fermeeAvecVolet = J.estOuvert() and true or false
	end)
end

local veilleur = CreateFrame("Frame")
veilleur:RegisterEvent("QUEST_LOG_UPDATE")
veilleur:RegisterEvent("UNIT_QUEST_LOG_CHANGED")
veilleur:RegisterEvent("PARTY_MEMBERS_CHANGED")
veilleur:RegisterEvent("QUEST_WATCH_UPDATE")
veilleur:RegisterEvent("PLAYER_ENTERING_WORLD")
veilleur:SetScript("OnEvent", function(_, evenement)
	if evenement == "PLAYER_ENTERING_WORLD" then
		if not J.dejaReplie then
			J.dejaReplie = true
			replierSelonZone()
		end
	end
	if J.estOuvert() then
		J.maj()
		J.majDetails()
	end
end)

construire()

ForeverUI.QuestLogDebug = function()
	local v = J.volet
	local prefixe = "|cff66ccffForeverUI|r "
	if not v then
		DEFAULT_CHAT_FRAME:AddMessage(prefixe .. "journal : pas construit.")
		return
	end
	local entetes, quetes = 0, 0
	for _, f in ipairs(v.entetes) do if f:IsShown() then entetes = entetes + 1 end end
	for _, f in ipairs(v.quetes) do if f:IsShown() then quetes = quetes + 1 end end
	DEFAULT_CHAT_FRAME:AddMessage(prefixe .. string.format(
		"journal : volet %s (%.0f x %.0f) | %d en-tete(s), %d quete(s) | recherche '%s' | objectifs %s",
		v:IsShown() and "ouvert" or "ferme", v:GetWidth(), v:GetHeight(), entetes, quetes,
		tostring(R.texte), tostring(reglages().objectifs)))
end
