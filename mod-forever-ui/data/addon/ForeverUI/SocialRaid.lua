-- ForeverUI : la page "Raid" de la fenetre Social (onglet 5 du client).
--
-- RELEVE -- RaidFrame.lua et .xml, Blizzard_RaidUI.lua et .xml (chargement a
-- la demande), du client :
--   hors raid  RAID_DESCRIPTION (GameFontNormal, 300 de large), puis
--              RAID_BROWSER_DESCRIPTION (GameFontHighlight, centre) et
--              OPEN_RAID_BROWSER (260 x 22) : ShowUIPanel(LFRParentFrame) ;
--              CONVERT_TO_RAID (115) : ConvertToRaid, actif si GetPartyMember(1)
--              et IsPartyLeader et niveau >= 10 et pas HasLFGRestrictions ;
--              RAID_INFO (90) : les instances sauvegardees
--   en raid    LOOKING_FOR_RAID (le navigateur de raid), READY_CHECK (chef ou
--              officier : DoReadyCheck), RAID_INFO ; huit groupes de cinq,
--              "Group N" au-dessus, "Empty" pour une place libre ; nom teinte
--              de sa classe (rouge mort, gris hors ligne), niveau, classe ;
--              icone de chef / d'assistant ; clic droit : UnitPopup "RAID" ;
--              glisser (chef ou officier) : SwapRaidSubgroup vers une place
--              occupee, SetRaidSubgroup vers une place vide
--   instances  RequestRaidInfo a l'ouverture ; instanceName, instanceID,
--              instanceReset, instanceDifficulty, locked, extended,
--              instanceIDMostSig, isRaid, maxPlayers, difficultyName =
--              GetSavedInstanceInfo(i) ; INSTANCE et LOCK_EXPIRE ; reset par
--              SecondsToTime(reset, true, nil, 3), ou "Expired" en gris ;
--              EXTENDED ; le bouton EXTEND_RAID_LOCK / UNEXTEND_RAID_LOCK /
--              REACTIVATE_RAID_LOCK : SetSavedInstanceExtend(i, prolonger)
--
-- ECARTS, ASSUMES :
--   * LES PLACES NE SONT PAS SECURISEES. Celles de Blizzard_RaidUI heritent de
--     SecureUnitButtonTemplate : un clic gauche cible le joueur. Des cadres
--     securises rendraient notre fenetre -- et FriendsFrame -- proteges en
--     combat : plus moyen de l'ouvrir ou de la fermer. Le clic gauche ne
--     cible donc pas ; le clic droit ouvre le menu, le glisser deplace.
--   * LE TANK ET L'ASSISTANT PRINCIPAUX, DANS LE CLIC DROIT (2026-09-26).
--     Le menu du client ne propose RAID_MAINTANK / RAID_MAINASSIST que si
--     issecure() -- un menu ouvert par un addon ne l'est jamais -- et sa
--     ligne RAID_DEMOTE, qui retire ces roles, appelle ClearPartyAssignment,
--     protege : bloquee aussi. On ajoute donc nos deux lignes
--     "Promote to Main Tank" / "Promote to Main Assist" (SET_MAIN_TANK,
--     SET_MAIN_ASSIST) avant Cancel, et sur elles -- comme sur la ligne
--     Demote d'un tank ou assistant principal -- un bouton SECURISE du
--     client pose par-dessus (SecureActionButtonTemplate, actions
--     "maintank" / "mainassist" de SecureTemplates.lua : set, clear). Ces
--     boutons sont fils d'UIParent (un enfant securise protegerait la
--     fenetre en combat), poses hors combat seulement, caches a la
--     fermeture du menu et a l'entree en combat : en combat, les lignes
--     ne sont pas proposees.
--   * AJOUTES LE 2026-09-26 (suite du chantier) : l'etat de l'appel sur les
--     places (GetReadyCheckStatus : pret, pas pret, en attente, puis absent
--     a la fin de l'appel), les icones de tank et d'assistant principal et
--     de maitre du butin (10e et 11e valeurs de GetRaidRosterInfo), la
--     rangee des classes -- en BAS de la page, la colonne de WotLK n'ayant
--     pas la place a droite -- avec son compte et son infobulle, et les
--     fenetres detachees : on les demande aux fonctions de Blizzard_RaidUI
--     (RaidPullout_GeneratePulloutFrame, RaidPulloutButton_OnDragStart,
--     RaidPulloutStopMoving), comme ses propres boutons. Glisser un groupe
--     (son intitule), une classe, ou un joueur (Maj + glisser pour le chef
--     et les officiers, glisser simple pour les autres) les detache.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local S = ForeverUI.Social
if not S or not S.inscrirePage then
	return
end

local R = {}
S.Raid = R

local SEP = string.char(92)
local txt = S.txt

local P = {
	encadreY1 = -60, encadreBas = 30,
	icone = 10, iconePas = 11, appel = 12,
	classeCote = 18, classePas = 26, classeX = 22, classeBas = 10,
	tank = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-MainTankIcon",
	assistantPrincipal = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-MainAssistIcon",
	butin = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-MasterLooter",
	classes = "Interface" .. SEP .. "Glues" .. SEP .. "CharacterCreate" .. SEP .. "UI-CharacterCreate-Classes",
	pets = "Interface" .. SEP .. "RaidFrame" .. SEP .. "UI-RaidFrame-Pets",
	mt = "Interface" .. SEP .. "RaidFrame" .. SEP .. "UI-RaidFrame-MainTank",
	ma = "Interface" .. SEP .. "RaidFrame" .. SEP .. "UI-RaidFrame-MainAssist",
	surbrillanceCarre = "Interface" .. SEP .. "Buttons" .. SEP .. "ButtonHilight-Square",
	pret = "Interface" .. SEP .. "RaidFrame" .. SEP .. "ReadyCheck-Ready",
	pasPret = "Interface" .. SEP .. "RaidFrame" .. SEP .. "ReadyCheck-NotReady",
	attente = "Interface" .. SEP .. "RaidFrame" .. SEP .. "ReadyCheck-Waiting",
	finAppel = 10,
	groupesX = 8, groupesY = -64, groupeL = 180, groupeEcartX = 4, groupeH = 66, groupeEcartY = 16,
	placeH = 12, etiquetteH = 12,
	chef = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-LeaderIcon",
	assistant = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-AssistantIcon",
	surbrillance = "Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestTitleHighlight",
	boutonY = -34,
}

local function actif(b, oui)
	if b.Activer then b:Activer(oui) elseif oui then b:Enable() else b:Disable() end
end

local function enRaid()
	return (GetNumRaidMembers() or 0) > 0
end

local function chefOuOfficier()
	return (IsRaidLeader and IsRaidLeader()) or (IsRaidOfficer and IsRaidOfficer())
end

-- LES FENETRES DETACHEES : celles de Blizzard_RaidUI, chargees avec le raid.
local function detacher(filtre, classe)
	if not (RaidPullout_GeneratePulloutFrame and RaidPulloutButton_OnDragStart) then return false end
	local f = RaidPullout_GeneratePulloutFrame(filtre, classe)
	if not f then return false end
	RaidPulloutButton_OnDragStart(f)
	-- LE CLIENT LA POSE LOIN DE LA SOURIS sur un ecran large : il convertit
	-- le curseur par GetScreenWidthScale (= largeur / 1024), qui ne vaut
	-- que pour le 4:3. La conversion juste est l'echelle effective de la
	-- fenetre ; on la repose, en gardant le glisser deja commence.
	local x, y = GetCursorPosition()
	local e = f:GetEffectiveScale()
	if e and e > 0 then
		f:ClearAllPoints()
		f:SetPoint("TOP", UIParent, "BOTTOMLEFT", x / e, y / e)
	end
	return true
end

local function lacher()
	if RaidPulloutStopMoving then RaidPulloutStopMoving() end
end

-- ------------------------------------------------------------ les groupes

-- place[g][n] : la n-ieme place du groupe g ; son .membre est l'index de raid
local function creerPlace(parent, g, n)
	local b = CreateFrame("Button", "ForeverUIRaidSlot" .. g .. "_" .. n, parent)
	b:SetHeight(P.placeH)
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b.groupe = g
	-- rang, role, butin : trois icones qui s'enchainent depuis la gauche
	b.icones = {}
	for k = 1, 3 do
		local t = b:CreateTexture(nil, "ARTWORK")
		t:SetWidth(P.icone)
		t:SetHeight(P.icone)
		t:SetPoint("LEFT", b, "LEFT", 2 + (k - 1) * P.iconePas, 0)
		t:Hide()
		b.icones[k] = t
	end
	b.rang = b.icones[1]
	b.appel = b:CreateTexture(nil, "OVERLAY")
	b.appel:SetWidth(P.appel)
	b.appel:SetHeight(P.appel)
	b.appel:SetPoint("RIGHT", b, "RIGHT", -2, 0)
	b.appel:Hide()
	b.nom = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.nom:SetPoint("LEFT", b, "LEFT", 14, 0)
	b.nom:SetWidth(90)
	b.nom:SetJustifyH("LEFT")
	b.niveau = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.niveau:SetPoint("LEFT", b.nom, "RIGHT", 2, 0)
	b.niveau:SetWidth(20)
	b.classe = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	b.classe:SetPoint("LEFT", b.niveau, "RIGHT", 2, 0)
	b.classe:SetPoint("RIGHT", b, "RIGHT", -2, 0)
	b.classe:SetJustifyH("LEFT")
	b:SetHighlightTexture(P.surbrillance)
	local s = b:GetHighlightTexture()
	if s then s:SetBlendMode("ADD") end
	b:SetScript("OnClick", function(self, bouton)
		if bouton == "RightButton" and self.membre then
			-- RaidGroupButton_ShowMenu, sur notre menu
			local d = R.menu
			d.name = GetRaidRosterInfo(self.membre)
			d.id = self.membre
			d.unit = "raid" .. self.membre
			ForeverUI.MenuUnite.ouvrir(ToggleDropDownMenu, 1, nil, d, "cursor")
		end
	end)
	b:SetScript("OnDragStart", function(self)
		if not self.membre then return end
		-- le glisser de WotLK : Maj (chef, officier) ou toujours (les autres)
		-- detache la fenetre du joueur ; sinon on deplace
		if not chefOuOfficier() or IsShiftKeyDown() then
			self.detache = detacher(GetRaidRosterInfo(self.membre), nil)
			return
		end
		R.glisse = self
		R.fantome.texte:SetText(self.nom:GetText())
		R.fantome:Show()
	end)
	b:SetScript("OnDragStop", function(self)
		if self.detache then
			self.detache = nil
			lacher()
			return
		end
		R.fantome:Hide()
		local source = R.glisse
		R.glisse = nil
		if not source or not source.membre then return end
		-- RaidGroupButton_OnDragStop : la place sous la souris
		for gg = 1, 8 do
			for nn = 1, 5 do
				local cible = R.places[gg][nn]
				if cible ~= source and MouseIsOver(cible) then
					if cible.membre then
						SwapRaidSubgroup(source.membre, cible.membre)
					else
						SetRaidSubgroup(source.membre, gg)
					end
					return
				end
			end
		end
	end)
	return b
end

local function viderPlace(b)
	b.membre = nil
	for _, t in ipairs(b.icones) do t:Hide() end
	b.appel:Hide()
	b.nom:ClearAllPoints()
	b.nom:SetPoint("LEFT", b, "LEFT", 14, 0)
	b.nom:SetText(txt("EMPTY"))
	b.nom:SetTextColor(0.35, 0.35, 0.35)
	b.niveau:SetText("")
	b.classe:SetText("")
end

-- RaidGroupFrame_Update, pour nos places
local function majGroupes()
	local rempli = {}
	for g = 1, 8 do
		rempli[g] = 0
		for n = 1, 5 do viderPlace(R.places[g][n]) end
	end
	for i = 1, (GetNumRaidMembers() or 0) do
		local nom, rang, groupe, niveau, classe, fichier, _, enLigne, mort = GetRaidRosterInfo(i)
		if nom and groupe and groupe >= 1 and groupe <= 8 and rempli[groupe] < 5 then
			rempli[groupe] = rempli[groupe] + 1
			local b = R.places[groupe][rempli[groupe]]
			b.membre = i
			b.nom:SetText(nom)
			b.niveau:SetText(niveau)
			b.classe:SetText(classe)
			local c = fichier and RAID_CLASS_COLORS and RAID_CLASS_COLORS[fichier] or NORMAL_FONT_COLOR
			if mort then
				b.nom:SetTextColor(1, 0, 0)
			elseif not enLigne then
				b.nom:SetTextColor(0.5, 0.5, 0.5)
			else
				b.nom:SetTextColor(c.r, c.g, c.b)
			end
			local gris = enLigne and 1 or 0.5
			b.niveau:SetTextColor(gris, gris, gris)
			b.classe:SetTextColor(gris, gris, gris)
			-- les icones : rang, role, butin -- dans cet ordre, sans trou
			local role, butin = select(10, GetRaidRosterInfo(i))
			local liste = {}
			if rang == 2 then liste[#liste + 1] = P.chef elseif rang == 1 then liste[#liste + 1] = P.assistant end
			if role == "MAINTANK" then liste[#liste + 1] = P.tank elseif role == "MAINASSIST" then liste[#liste + 1] = P.assistantPrincipal end
			if butin then liste[#liste + 1] = P.butin end
			for k, t in ipairs(b.icones) do
				if liste[k] then t:SetTexture(liste[k]) t:Show() else t:Hide() end
			end
			b.nom:ClearAllPoints()
			b.nom:SetPoint("LEFT", b, "LEFT", math.max(14, 3 + #liste * P.iconePas), 0)
			-- l'appel : pret, pas pret, en attente -- absent une fois fini
			local etat = GetReadyCheckStatus and GetReadyCheckStatus("raid" .. i)
			if etat == "ready" then
				b.appel:SetTexture(READY_CHECK_READY_TEXTURE or P.pret)
				b.appel:Show()
			elseif etat == "notready" then
				b.appel:SetTexture(READY_CHECK_NOT_READY_TEXTURE or P.pasPret)
				b.appel:Show()
			elseif etat == "waiting" then
				b.appel:SetTexture((R.appelFini and READY_CHECK_AFK_TEXTURE) or READY_CHECK_WAITING_TEXTURE or P.attente)
				b.appel:Show()
			end
		end
	end
end

-- -------------------------------------------------------------- les classes

-- RAID_CLASS_BUTTONS : les dix classes dans l'ordre du client, puis les
-- familiers, le tank et l'assistant principaux
local function classes()
	local l = {}
	for _, fichier in ipairs(CLASS_SORT_ORDER or {}) do
		local c = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[fichier]
		l[#l + 1] = { fichier = fichier, icone = P.classes, coords = c,
			nom = (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[fichier]) or fichier }
	end
	l[#l + 1] = { fichier = "PETS", icone = P.pets, nom = txt("PETS") }
	l[#l + 1] = { fichier = "MAINTANK", icone = P.mt, nom = txt("MAINTANK") }
	l[#l + 1] = { fichier = "MAINASSIST", icone = P.ma, nom = txt("MAINASSIST") }
	return l
end

-- qui est dans quelle case : les membres par classe, les familiers, les
-- roles
local function membresDe(fichier)
	local noms = {}
	for i = 1, (GetNumRaidMembers() or 0) do
		local nom, _, _, _, _, f, _, _, _, role = GetRaidRosterInfo(i)
		if fichier == "PETS" then
			if UnitExists and UnitExists("raidpet" .. i) then noms[#noms + 1] = UnitName("raidpet" .. i) end
		elseif fichier == "MAINTANK" or fichier == "MAINASSIST" then
			if role == fichier then noms[#noms + 1] = nom end
		elseif f == fichier then
			noms[#noms + 1] = nom
		end
	end
	return noms
end

local function creerClasses(parent)
	R.classes = {}
	for k, def in ipairs(classes()) do
		local b = CreateFrame("Button", "ForeverUIRaidClassButton" .. k, parent)
		b:SetWidth(P.classeCote)
		b:SetHeight(P.classeCote)
		b:SetPoint("BOTTOMLEFT", S.cadre, "BOTTOMLEFT", P.classeX + (k - 1) * P.classePas, P.classeBas)
		b.icone = b:CreateTexture(nil, "ARTWORK")
		b.icone:SetAllPoints(b)
		b.icone:SetTexture(def.icone)
		if def.coords then b.icone:SetTexCoord(def.coords[1], def.coords[2], def.coords[3], def.coords[4]) end
		b.compte = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		b.compte:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -2)
		b:SetHighlightTexture(P.surbrillanceCarre)
		local h = b:GetHighlightTexture()
		if h then h:SetBlendMode("ADD") end
		b:RegisterForDrag("LeftButton")
		b.def = def
		-- RaidClassButton_OnEnter
		b:SetScript("OnEnter", function(self)
			local noms = membresDe(self.def.fichier)
			GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
			GameTooltip:SetText(string.format("%s%s (%d)|r", self.def.nom, NORMAL_FONT_COLOR_CODE or "|cffffd200", #noms), 1, 1, 1)
			if #noms > 0 then GameTooltip:AddLine(table.concat(noms, ", "), 1, 1, 1, 1) end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		b:SetScript("OnDragStart", function(self)
			if (self.nombre or 0) > 0 then detacher(self.def.fichier, self.def.nom) end
		end)
		b:SetScript("OnDragStop", lacher)
		R.classes[k] = b
	end
end

-- RaidClassButton_Update
local function majClasses()
	for _, b in ipairs(R.classes) do
		local n = #membresDe(b.def.fichier)
		b.nombre = n
		if n > 0 then
			b.icone:SetDesaturated(false)
			b.icone:SetAlpha(1)
			local seul = b.def.fichier == "MAINTANK" or b.def.fichier == "MAINASSIST"
			b.compte:SetText(seul and "" or n)
		else
			b.icone:SetDesaturated(true)
			b.icone:SetAlpha(0.5)
			b.compte:SetText("")
		end
	end
end

-- ----------------------------------------------------------- les instances

local N = {}

local function creerInstances()
	local a = S.creerAnnexe("ForeverUIRaidInfoFrame", 345, 270)
	a.titre:SetText(txt("RAID_INFORMATION"))
	N.cadre = a
	local e = ForeverUI.CreateInset(a)
	e:SetPoint("TOPLEFT", a, "TOPLEFT", 12, -30)
	e:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -12, 42)
	local h1 = S.creerEntete(e, "ForeverUIRaidInfoColumn1", 173, txt("INSTANCE"))
	h1:SetPoint("TOPLEFT", e, "TOPLEFT", 4, -4)
	local h2 = S.creerEntete(e, "ForeverUIRaidInfoColumn2", 140, txt("LOCK_EXPIRE"))
	h2:SetPoint("LEFT", h1, "RIGHT", -1, 0)
	N.liste = S.creerListe(e, "ForeverUIRaidInfoList", 30, function(l)
		l.nom = l:CreateFontString(nil, "ARTWORK", "GameFontNormal")
		l.nom:SetPoint("TOPLEFT", l, "TOPLEFT", 5, -3)
		l.nom:SetWidth(150)
		l.nom:SetJustifyH("LEFT")
		l.difficulte = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		l.difficulte:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 10, -2)
		l.reset = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		l.reset:SetPoint("TOPRIGHT", l, "TOPRIGHT", -2, -4)
		l.reset:SetJustifyH("RIGHT")
		l.prolonge = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		l.prolonge:SetPoint("TOPRIGHT", l.reset, "BOTTOMRIGHT", 0, -2)
		l.prolonge:SetText(txt("EXTENDED"))
		l:SetHighlightTexture(P.surbrillance)
		local s = l:GetHighlightTexture()
		if s then s:SetBlendMode("ADD") end
		l:SetScript("OnClick", function(self)
			N.choisi = self.longID
			N.maj()
		end)
		l:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(self.nom:GetText())
			GameTooltip:AddLine(self.difficulte:GetText(), 1, 1, 1)
			GameTooltip:AddLine(string.format(txt("INSTANCE_ID"), self.instanceID or 0), 1, 1, 1)
			GameTooltip:Show()
		end)
		l:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end, function(l, i)
		local nom, id, reset, _, verrouille, prolonge, idHaut, _, _, difficulte = GetSavedInstanceInfo(i)
		l.instanceID = id
		l.longID = string.format("%x%x", idHaut or 0, id or 0)
		l.difficulte:SetText(difficulte)
		if prolonge or verrouille then
			l.reset:SetText(SecondsToTime and SecondsToTime(reset or 0, true, nil, 3) or tostring(reset))
			l.nom:SetText(nom)
		else
			l.reset:SetText("|cff808080" .. txt("RAID_INSTANCE_EXPIRES_EXPIRED") .. "|r")
			l.nom:SetText("|cff808080" .. (nom or "") .. "|r")
		end
		if prolonge then l.prolonge:Show() else l.prolonge:Hide() end
		if N.choisi == l.longID then l:LockHighlight() else l:UnlockHighlight() end
	end)
	N.liste:SetPoint("TOPLEFT", h1, "BOTTOMLEFT", 0, -2)
	N.liste:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -18, 4)
	N.prolonger = S.bouton(a, txt("EXTEND_RAID_LOCK"), 200)
	N.prolonger:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 14, 13)
	N.prolonger:SetScript("OnClick", function(self)
		if N.index then
			SetSavedInstanceExtend(N.index, self.prolonger)
			RequestRaidInfo()
			N.maj()
		end
	end)
	local fermer = S.bouton(a, txt("CLOSE"), 90)
	fermer:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -14, 13)
	fermer:SetScript("OnClick", function() a:Hide() end)
	a:HookScript("OnShow", function() N.maj() end)
end

-- RaidInfoFrame_Update et RaidInfoFrame_UpdateSelectedIndex
function N.maj()
	if not N.cadre or not N.cadre:IsShown() then return end
	local total = GetNumSavedInstances() or 0
	N.liste:Maj(total)
	N.index = nil
	for i = 1, total do
		local _, id, _, _, verrouille, prolonge, idHaut = GetSavedInstanceInfo(i)
		if N.choisi and string.format("%x%x", idHaut or 0, id or 0) == N.choisi then
			N.index = i
			if prolonge then
				N.prolonger.prolonger = false
				N.prolonger:SetText(txt("UNEXTEND_RAID_LOCK"))
			elseif verrouille then
				N.prolonger.prolonger = true
				N.prolonger:SetText(txt("EXTEND_RAID_LOCK"))
			else
				N.prolonger.prolonger = true
				N.prolonger:SetText(txt("REACTIVATE_RAID_LOCK"))
			end
		end
	end
	actif(N.prolonger, N.index ~= nil)
end

-- ------------------------------------------------------------ la mise a jour

-- LES SURCOUCHES SECURISEES DU MENU. Elles s'effacent hors combat seulement ;
-- a l'entree en combat, l'evenement les cache avant le verrou.
function R.cacherSurcouches()
	if InCombatLockdown and InCombatLockdown() then return end
	for _, o in ipairs(R.surcouches or {}) do o:Hide() end
end

local function surcouche(k)
	R.surcouches = R.surcouches or {}
	local o = R.surcouches[k]
	if o then return o end
	o = CreateFrame("Button", "ForeverUIRaidMenuSecure" .. k, UIParent, "SecureActionButtonTemplate")
	o:RegisterForClicks("LeftButtonUp")
	o:SetHighlightTexture(P.surbrillance)
	local h = o:GetHighlightTexture()
	if h then h:SetBlendMode("ADD") end
	o:SetScript("PostClick", function(self)
		if self.apres then self.apres() end
		CloseDropDownMenus()
	end)
	o:Hide()
	R.surcouches[k] = o
	return o
end

-- Le menu du clic droit : celui du client (UnitPopup "RAID"), puis nos
-- lignes securisees pour le chef et les assistants.
function R.initialiserMenu(self)
	local menu = UIDROPDOWNMENU_OPEN_MENU or self
	if not menu or not R.menu.name then return end
	UnitPopup_ShowMenu(menu, "RAID", R.menu.unit, R.menu.name, R.menu.id)
	R.cacherSurcouches()
	if (UIDROPDOWNMENU_MENU_LEVEL or 1) ~= 1 or (InCombatLockdown and InCombatLockdown()) then return end
	local chef = IsRaidLeader and IsRaidLeader()
	local officier = IsRaidOfficer and IsRaidOfficer()
	if not (chef or officier) then return end
	local liste = DropDownList1
	local nom, role = R.menu.name, select(10, GetRaidRosterInfo(R.menu.id))
	local unite = "raid" .. R.menu.id
	local k = 0
	local function poser(bouton, type, action, apres)
		k = k + 1
		local o = surcouche(k)
		o:SetAttribute("type", type)
		o:SetAttribute("action", action)
		o:SetAttribute("unit", unite)
		o.apres = apres
		o:ClearAllPoints()
		o:SetAllPoints(bouton)
		-- AU-DESSUS DE LA LISTE, POUR DE BON. ToggleDropDownMenu remplit la
		-- liste PUIS l'affiche, et DropDownList1, toplevel, remonte alors
		-- au premier plan de sa strate : un niveau pose avant ne tient pas,
		-- et le clic tombait sur la ligne ordinaire (retour du 2026-09-26).
		-- La strate des infobulles est au-dessus de FULLSCREEN_DIALOG.
		o:SetFrameStrata("TOOLTIP")
		o:Show()
	end
	-- la ligne Demote d'un tank ou assistant principal : le retrait du role
	-- est protege ; la retrogradation d'un assistant, elle, ne l'est pas
	if role == "MAINTANK" or role == "MAINASSIST" then
		for i = 1, liste.numButtons do
			local b = _G["DropDownList1Button" .. i]
			if b and b.value == "RAID_DEMOTE" then
				poser(b, string.lower(role), "clear", function()
					if chef and UnitIsRaidOfficer and UnitIsRaidOfficer(unite) then DemoteAssistant(nom, 1) end
				end)
			end
		end
	end
	-- Cancel s'en va le temps d'ajouter nos lignes, puis revient en dernier
	local dernier = _G["DropDownList1Button" .. liste.numButtons]
	local annuler = dernier and dernier.value == "CANCEL"
	if annuler then liste.numButtons = liste.numButtons - 1 end
	local function ligne(texte, type)
		local info = UIDropDownMenu_CreateInfo()
		info.text = texte
		info.notCheckable = 1
		info.func = function() end
		UIDropDownMenu_AddButton(info, 1)
		poser(_G["DropDownList1Button" .. liste.numButtons], type, "set")
	end
	if role ~= "MAINTANK" then ligne(txt("SET_MAIN_TANK"), "maintank") end
	if role ~= "MAINASSIST" then ligne(txt("SET_MAIN_ASSIST"), "mainassist") end
	if annuler then
		local info = UIDropDownMenu_CreateInfo()
		info.text = txt("CANCEL")
		info.value = "CANCEL"
		info.owner = "RAID"
		info.notCheckable = 1
		info.func = UnitPopup_OnClick
		UIDropDownMenu_AddButton(info, 1)
	end
end

function R.maj()
	if not R.hors then return end
	local raid = enRaid()
	if raid then
		R.hors:Hide()
		R.groupes:Show()
		majGroupes()
		majClasses()
		R.convertir:Hide()
		R.navigateur:Show()
		if chefOuOfficier() then R.appel:Show() else R.appel:Hide() end
	else
		R.hors:Show()
		R.groupes:Hide()
		R.convertir:Show()
		R.navigateur:Hide()
		R.appel:Hide()
		local ok = GetPartyMember and GetPartyMember(1) and IsPartyLeader() and UnitLevel("player") >= 10
			and not (HasLFGRestrictions and HasLFGRestrictions())
		actif(R.convertir, ok and true or false)
	end
	-- le bouton des instances suit la liste (UPDATE_INSTANCE_INFO)
	actif(R.info, (GetNumSavedInstances() or 0) > 0)
	N.maj()
end

local function construire(cadre)
	-- hors raid
	local hors = ForeverUI.CreateInset(cadre, "ForeverUIRaidNotInRaid")
	hors:SetPoint("TOPLEFT", S.cadre, "TOPLEFT", 4, P.encadreY1)
	hors:SetPoint("BOTTOMRIGHT", S.cadre, "BOTTOMRIGHT", -6, P.encadreBas)
	local desc = hors:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	desc:SetPoint("TOPLEFT", hors, "TOPLEFT", 18, -16)
	desc:SetWidth(335)
	desc:SetJustifyH("LEFT")
	desc:SetText(txt("RAID_DESCRIPTION"))
	local nav = hors:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	nav:SetPoint("TOP", desc, "BOTTOM", 0, -30)
	nav:SetWidth(335)
	nav:SetText(txt("RAID_BROWSER_DESCRIPTION"))
	local ouvrir = S.bouton(hors, txt("OPEN_RAID_BROWSER"), 260)
	ouvrir:SetPoint("TOP", nav, "BOTTOM", 0, -10)
	ouvrir:SetScript("OnClick", function()
		if LFRParentFrame then ShowUIPanel(LFRParentFrame) end
	end)
	R.hors = hors

	-- en raid : huit groupes, deux colonnes de quatre
	local groupes = CreateFrame("Frame", "ForeverUIRaidGroups", cadre)
	groupes:SetAllPoints(S.cadre)
	R.groupes = groupes
	R.places = {}
	for g = 1, 8 do
		local col, rangee = (g - 1) % 2, math.floor((g - 1) / 2)
		local boite = ForeverUI.CreateInset(groupes, "ForeverUIRaidGroup" .. g)
		boite:SetWidth(P.groupeL)
		boite:SetHeight(P.groupeH)
		boite:SetPoint("TOPLEFT", S.cadre, "TOPLEFT", P.groupesX + col * (P.groupeL + P.groupeEcartX),
			P.groupesY - P.etiquetteH - rangee * (P.groupeH + P.groupeEcartY))
		-- l'intitule : glisse, il detache la fenetre du groupe
		local etiquette = CreateFrame("Button", "ForeverUIRaidGroupLabel" .. g, groupes)
		etiquette:SetHeight(P.etiquetteH)
		etiquette:SetWidth(80)
		etiquette:SetPoint("BOTTOMLEFT", boite, "TOPLEFT", 4, 1)
		local et = etiquette:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		et:SetPoint("LEFT", etiquette, "LEFT", 0, 0)
		et:SetText(txt("GROUP") .. " " .. g)
		etiquette.texte = et
		etiquette:RegisterForDrag("LeftButton")
		etiquette:SetScript("OnDragStart", function() detacher(g) end)
		etiquette:SetScript("OnDragStop", lacher)
		R.places[g] = {}
		for n = 1, 5 do
			local b = creerPlace(boite, g, n)
			b:SetPoint("TOPLEFT", boite, "TOPLEFT", 3, -3 - (n - 1) * P.placeH)
			b:SetPoint("TOPRIGHT", boite, "TOPRIGHT", -3, -3 - (n - 1) * P.placeH)
			R.places[g][n] = b
		end
	end
	-- le fantome qui suit la souris pendant un glisser
	local f = CreateFrame("Frame", "ForeverUIRaidDragGhost", UIParent)
	f:SetFrameStrata("TOOLTIP")
	f:SetWidth(120)
	f:SetHeight(14)
	f.texte = f:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	f.texte:SetAllPoints(f)
	f:Hide()
	f:SetScript("OnUpdate", function(self)
		local x, y = GetCursorPosition()
		local e = UIParent:GetEffectiveScale()
		self:ClearAllPoints()
		self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / e, y / e)
	end)
	R.fantome = f
	creerClasses(groupes)
	-- LE MENU DU CLIC DROIT : RaidGroupButton_ShowMenu pose .initialize et
	-- .displayMode, et ToggleDropDownMenu le remplit a l'ouverture. Ne pas
	-- passer par UIDropDownMenu_Initialize ici : il appelle la fonction
	-- aussitot, sans menu ouvert -- UnitPopup_ShowMenu(nil) a la connexion.
	R.menu = CreateFrame("Frame", "ForeverUIRaidDropDown", cadre, "UIDropDownMenuTemplate")
	R.menu:Hide()
	R.menu.displayMode = "MENU"
	R.menu.initialize = R.initialiserMenu
	-- la liste se ferme : nos surcouches aussi
	if DropDownList1 then DropDownList1:HookScript("OnHide", R.cacherSurcouches) end

	-- les boutons du haut
	R.info = S.bouton(cadre, txt("RAID_INFO"), 90)
	R.info:SetPoint("TOPRIGHT", S.cadre, "TOPRIGHT", -10, P.boutonY)
	R.info:SetScript("OnClick", function()
		if N.cadre:IsShown() then N.cadre:Hide() else N.cadre:Show() end
	end)
	R.convertir = S.bouton(cadre, txt("CONVERT_TO_RAID"), 115)
	R.convertir:SetPoint("RIGHT", R.info, "LEFT", -4, 0)
	R.convertir:SetScript("OnClick", function() ConvertToRaid() end)
	R.appel = S.bouton(cadre, txt("READY_CHECK"), 90)
	R.appel:SetPoint("RIGHT", R.info, "LEFT", -2, 0)
	R.appel:SetScript("OnClick", function()
		DoReadyCheck()
		PlaySound("UChatScrollButton")
	end)
	R.navigateur = S.bouton(cadre, txt("LOOKING_FOR_RAID"), 90)
	R.navigateur:SetPoint("RIGHT", R.appel, "LEFT", -2, 0)
	R.navigateur:SetScript("OnClick", function()
		if LFRParentFrame then ShowUIPanel(LFRParentFrame) end
	end)

	creerInstances()
end

S.inscrirePage(5, {
	construire = construire,
	titre = function() return txt("RAID") end,
	maj = R.maj,
	-- l'OnShow de RaidFrame
	montrer = function() RequestRaidInfo() end,
	cacher = function()
		if N.cadre then N.cadre:Hide() end
		if R.fantome then R.fantome:Hide() end
	end,
})

local veilleur = CreateFrame("Frame")
for _, ev in ipairs({ "RAID_ROSTER_UPDATE", "PARTY_MEMBERS_CHANGED", "PARTY_LEADER_CHANGED",
	"UPDATE_INSTANCE_INFO", "UNIT_LEVEL", "UNIT_NAME_UPDATE", "UNIT_PET", "PARTY_LFG_RESTRICTED",
	"READY_CHECK", "READY_CHECK_CONFIRM", "READY_CHECK_FINISHED", "PLAYER_REGEN_DISABLED",
	"PLAYER_REGEN_ENABLED" }) do
	veilleur:RegisterEvent(ev)
end
-- LA FIN DE L'APPEL : RaidGroupFrame_ReadyCheckFinished passe les absents en
-- "AFK" puis efface les icones ; ici apres P.finAppel secondes.
local minuterie = CreateFrame("Frame")
minuterie:Hide()
minuterie:SetScript("OnUpdate", function(self, ecoule)
	self.reste = (self.reste or 0) - (ecoule or 0)
	if self.reste <= 0 then
		self:Hide()
		R.appelFini = nil
		if R.places then
			for g = 1, 8 do for n = 1, 5 do R.places[g][n].appel:Hide() end end
		end
	end
end)
R.minuterie = minuterie
veilleur:SetScript("OnEvent", function(self, ev)
	-- a l'entree en combat, avant le verrou : les boutons securises s'en vont
	if ev == "PLAYER_REGEN_DISABLED" then
		for _, o in ipairs(R.surcouches or {}) do o:Hide() end
		return
	elseif ev == "PLAYER_REGEN_ENABLED" then
		return
	end
	if ev == "READY_CHECK" then
		R.appelFini = nil
		minuterie:Hide()
	elseif ev == "READY_CHECK_FINISHED" then
		R.appelFini = true
		minuterie.reste = P.finAppel
		minuterie:Show()
	end
	if R.hors and R.hors:GetParent():IsVisible() then R.maj() end
end)
