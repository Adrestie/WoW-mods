-- ForeverUI : la page "Guild" de la fenetre Social (onglet 3 du client).
--
-- DECISION DE L'UTILISATEUR (2026-09-26) : la guilde en onglet, comme WotLK
-- (camelot la met dans Communities, une fenetre a part). La page reprend
-- GuildFrame (FriendsFrame.lua et .xml du client), ses volets -- detail d'un
-- membre, information, journal -- et garde la fenetre de controle du client.
--
-- RELEVE WotLK :
--   titre     format(GUILD_TITLE_TEMPLATE, rang, guilde) -- GetGuildInfo
--   totaux    GUILD_TOTAL (GetNumGuildMembers) et GUILD_TOTALONLINE (les
--             membres en ligne)
--   vues      FriendsFrame.playerStatusFrame : "Player Status" (NAME, ZONE,
--             LEVEL_ABBR, CLASS) ou "Guild Status" (NAME, RANK, LABEL_NOTE,
--             LASTONLINE) ; la bascule nomme la vue courante ; tri par
--             SortGuildRoster(name, zone, level, class, rank, note, online)
--   lignes    name, rank, rankIndex, level, class, zone, note, officernote,
--             online, status, classFileName = GetGuildRosterInfo(i) ; hors
--             ligne tout en gris 0,5 ; en ligne le nom en NORMAL, la classe
--             (ou le statut) teinte de sa classe ; dernier passage
--             RecentTimeDate(GetGuildRosterLastOnline(i)) ; GUILD_ONLINE_LABEL
--             ou le statut (<Away>) pour un membre en ligne
--   clics     gauche : SetGuildRosterSelection, le detail (un second clic sur
--             le meme le referme) ; droit : FriendsFrame_ShowDropdown(nom,
--             en ligne) -- rien pour un membre hors ligne
--   MOTD      GUILD_MOTD_LABEL, CURRENT_GUILD_MOTD ; blanc et cliquable
--             (SET_GUILDMOTD) si CanEditMOTD, gris 0,65 sinon
--   boutons   GUILDCONTROL (IsGuildLeader) : GuildControlPopupFrame du
--             client ; ADDMEMBER (CanGuildInvite) : ADD_GUILDMEMBER ;
--             GUILD_INFORMATION : le volet d'information
--   detail    nom, FRIENDS_LEVEL_TEMPLATE, ZONE_COLON, RANK_COLON (+ fleches
--             promouvoir / retrograder), LAST_ONLINE_COLON, NOTE_COLON
--             (SET_GUILDPLAYERNOTE si CanEditPublicNote, sinon gris),
--             OFFICER_NOTE_COLON (si CanViewOfficerNote ; SET_GUILDOFFICERNOTE
--             si CanEditOfficerNote), REMOVE (REMOVE_GUILDMEMBER), GROUP_INVITE
--   info      GetGuildInfoText / SetGuildInfoText, CanEditGuildInfo, le texte
--             retenu en attendant le GUILD_ROSTER_UPDATE ; ACCEPT, CLOSE,
--             GUILD_EVENT_LOG
--   journal   QueryGuildEventLog ; GetGuildEventInfo(i) : type, joueur1,
--             joueur2, rang, annee, mois, jour, heure ; GUILDEVENT_TYPE_* et
--             GUILD_BANK_LOG_TIME, le plus recent d'abord
--
-- LA LISTE DES MEMBRES est celle de camelot (2026-09-26, demande de
-- l'utilisateur) : Communities, vue Roster (communitiesmemberlist.xml et
-- .lua, pour une guilde). DECISION (2026-09-26) : la fenetre garde ses 385 --
-- l'elargir a 560 genait -- et la colonne Note s'en va ; Rank prend le reste
-- de la largeur. La note reste dans le detail du membre et dans l'infobulle,
-- qui s'ouvre donc aussi pour un membre qui a une note.
--   colonnes  GUILD_COLUMN_INFO : Level 40, Class 45, Name 100, Zone 100,
--             Rank 85, Note (le reste) -- ici sans Note, Rank au reste ; en-tetes ColumnDisplayButtonTemplate
--             (WhoFrame-ColumnTabs, 24), le premier a (2, 1) du bandeau, les
--             suivants a -2, le dernier jusqu'a -28 du bandeau (-6 de la
--             liste) ; un clic trie (SortGuildRoster : level, class, name,
--             zone, rank, note)
--   ligne     CommunitiesMemberListEntryTemplate, 20 de haut : bande
--             GuildFrame (0.3623-0.3818 / 0.9590-0.9980), surbrillance
--             UI-FriendsFrame-HighlightBar en ADD ; niveau (4, 40 de large),
--             icone de classe 16 (+8, CLASS_ICON_TCOORDS), le nom (+18, 95 de
--             large : presence 16, nom, icone de rang 12 -- UpdateNameFrame),
--             la zone (+8, 90), le rang (+7, 75), la note (+8 jusqu'a -4) ;
--             GameFontHighlightSmall
--   etat      en ligne : nom teinte de sa classe, le reste en blanc ; absent
--             ou occupe : FRIENDS_TEXTURE_AFK / _DND devant le nom ; hors
--             ligne : tout en gris, et la zone dit le dernier passage
--             (GetRecentTimeDate)
--   infobulle seulement si le nom, le rang, la note ou la zone sont coupes :
--             nom, rang, niveau et classe, zone, "Note: ..."
--   case      ShowOfflineButton (COMMUNITIES_MEMBER_LIST_SHOW_OFFLINE), au-
--             dessus de la liste en vue Roster
-- ECARTS : 3.3.5 n'a ni la race dans GetGuildRosterInfo (l'infobulle dit
-- FRIENDS_LEVEL_TEMPLATE, niveau et classe), ni les roles de communaute :
-- l'icone de rang ne marque que le chef de guilde (rang 0), les officiers ne
-- se reconnaissent pas. La colonne supplementaire de camelot (hauts faits,
-- metiers, score de donjon) n'a pas de donnees en 3.3.5 : la note va au bord.
-- La case prend SHOW_OFFLINE_MEMBERS, et Set/GetGuildRosterShowOffline, que
-- WotLK declare sans jamais la montrer (GuildFrameLFGButton virtuel). La
-- bascule des deux vues de WotLK s'en va : toutes les colonnes tiennent.
--
-- LE CADRE DE GUILDE DU CLIENT RESTE "MONTRE", HORS DE L'ECRAN. UnitPopup ne
-- propose "Promote to Guildmaster" et "Leave Guild" que si GuildFrame est
-- affiche, et le client ne rafraichit la liste (GuildRoster sur
-- GUILD_ROSTER_UPDATE, GuildControlPopupFrame_Initialize) que dans ce cas.
-- GuildFrame est donc garde par la fenetre, deplace loin de l'ecran,
-- transparent : ses fonctions tournent, rien ne se voit ni ne prend la
-- souris. Les popups du client s'appuient sur GuildFrame.selectedName et
-- GetGuildRosterSelection : on les tient a jour.
--
-- LA FENETRE DE CONTROLE (rangs, droits, banque) reste celle du client --
-- ses fonctions pilotent le serveur -- recollee a droite de la fenetre et
-- HABILLEE (2026-09-26) : le fond MacroPopup se tait, le metal et le fond de
-- camelot le remplacent, un titre et une croix dans la barre ; les cases
-- prennent checkbox-minimal, les champs le bord de camelot, le cadre des
-- droits de banque l'encadre de camelot. Les onglets de banque (1 a 6) et
-- les boutons +/- de rang gardent l'art du client.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local S = ForeverUI.Social
if not S or not S.inscrirePage then
	return
end

local Gu = {}
S.Guild = Gu

local SEP = string.char(92)
local txt = S.txt

local P = {
	encadreY1 = -60, encadreBas = 88, enteteX = 4, enteteY = -4, ecart = -2,
	ligneH = 20, texteH = 12,
	colonnes = { { "LEVEL", 40, "level" }, { "CLASS", 45, "class" }, { "NAME", 100, "name" },
		{ "ZONE", 100, "zone" }, { "RANK", 0, "rank" } },
	-- la derniere colonne va jusqu'au bord de la liste ; remplirL : sa
	-- largeur avant ancrage
	noteDroite = -6, remplirL = 60, listeX2 = -22, listeX2Seule = -4,
	bande = "Interface" .. SEP .. "ForeverUI" .. SEP .. "guildframe" .. SEP .. "guildframe",
	bandeCoords = { 0.36230469, 0.38183594, 0.95898438, 0.99804688 },
	barre = "Interface" .. SEP .. "FriendsFrame" .. SEP .. "UI-FriendsFrame-HighlightBar",
	classes = "Interface" .. SEP .. "Glues" .. SEP .. "CharacterCreate" .. SEP .. "UI-CharacterCreate-Classes",
	chef = "Interface" .. SEP .. "GroupFrame" .. SEP .. "UI-Group-LeaderIcon",
	absent = "Interface" .. SEP .. "FriendsFrame" .. SEP .. "StatusIcon-Away",
	occupe = "Interface" .. SEP .. "FriendsFrame" .. SEP .. "StatusIcon-DnD",
	nomL = 95,
	totauxX = 64, totauxY = -40, horsDroite = -12, horsY = -33,
	motdX = 14, motdBas = 32, motdH = 36,
	boutonBas = 4, boutonDroite = -6,
	gris = 0.5, grisTexte = 0.65,
}

local function actif(b, oui)
	if b.Activer then b:Activer(oui) elseif oui then b:Enable() else b:Disable() end
end

-- RecentTimeDate du client, s'il est la ; sinon la meme regle.
local function depuis(annee, mois, jour, heure)
	if RecentTimeDate then return RecentTimeDate(annee, mois, jour, heure) end
	if annee and annee > 0 then return string.format(txt("LASTONLINE_YEARS"), annee) end
	if mois and mois > 0 then return string.format(txt("LASTONLINE_MONTHS"), mois) end
	if jour and jour > 0 then return string.format(txt("LASTONLINE_DAYS"), jour) end
	if heure and heure > 0 then return string.format(txt("LASTONLINE_HOURS"), heure) end
	return txt("LASTONLINE_MINS")
end

-- IsTruncated, que 3.3.5 n'a pas : un champ de largeur fixee trop etroit
local function tronque(fs)
	local l = fs:GetWidth()
	return l and l > 0 and fs:GetStringWidth() > l + 0.5
end

local function couleurClasse(fichier)
	local c = fichier and RAID_CLASS_COLORS and RAID_CLASS_COLORS[fichier] or NORMAL_FONT_COLOR
	return c.r, c.g, c.b
end

-- ------------------------------------------------------------------ la liste

local function creerLigne(l)
	l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	l:SetNormalTexture(P.bande)
	local n = l:GetNormalTexture()
	n:SetTexCoord(P.bandeCoords[1], P.bandeCoords[2], P.bandeCoords[3], P.bandeCoords[4])
	n:ClearAllPoints()
	n:SetAllPoints(l)
	l:SetHighlightTexture(P.barre)
	local s = l:GetHighlightTexture()
	s:SetBlendMode("ADD")
	s:ClearAllPoints()
	s:SetAllPoints(l)
	local function champ(parent, largeur)
		local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		fs:SetJustifyH("LEFT")
		fs:SetHeight(P.texteH)
		if largeur then fs:SetWidth(largeur) end
		return fs
	end
	-- le niveau CENTRE sur sa colonne : l'en-tete Level couvre -1 a 39 depuis
	-- le bord de la liste (2026-09-26, demande de l'utilisateur ; camelot le
	-- cadre a gauche a 4)
	l.niveau = champ(l, P.colonnes[1][2])
	l.niveau:SetPoint("LEFT", l, "LEFT", -1, 0)
	l.niveau:SetJustifyH("CENTER")
	-- l'icone de classe a sa place de camelot (4 + 40 + 8), centree sous Class
	l.classe = l:CreateTexture(nil, "OVERLAY")
	l.classe:SetTexture(P.classes)
	l.classe:SetWidth(16)
	l.classe:SetHeight(16)
	l.classe:SetPoint("LEFT", l, "LEFT", 52, 0)
	-- NameFrame : presence, nom, icone de rang
	local nf = CreateFrame("Frame", nil, l)
	nf:SetHeight(20)
	nf:SetWidth(P.nomL)
	nf:SetPoint("LEFT", l.classe, "RIGHT", 18, 0)
	l.cadreNom = nf
	l.presence = nf:CreateTexture(nil, "OVERLAY")
	l.presence:SetWidth(16)
	l.presence:SetHeight(16)
	l.presence:SetPoint("LEFT", nf, "LEFT", 0, 0)
	l.nom = champ(nf)
	l.rangIcone = nf:CreateTexture(nil, "OVERLAY")
	l.rangIcone:SetWidth(12)
	l.rangIcone:SetHeight(12)
	l.zone = champ(l, 90)
	l.zone:SetPoint("LEFT", nf, "RIGHT", 8, 0)
	-- le rang au reste de la ligne (plus de colonne Note)
	l.rang = champ(l)
	l.rang:SetPoint("LEFT", l.zone, "RIGHT", 7, 0)
	l.rang:SetPoint("RIGHT", l, "RIGHT", -4, 0)
	l:SetScript("OnClick", function(self, bouton) Gu.cliquer(self, bouton) end)
	-- CommunitiesMemberListEntryMixin:OnEnter, en vue Roster ; la note n'a
	-- plus de colonne : un membre qui en a une ouvre aussi l'infobulle
	l:SetScript("OnEnter", function(self)
		local nom, rang, _, niveau, classe, zone, note, _, enLigne = GetGuildRosterInfo(self.index)
		local aNote = note and note ~= ""
		if not (aNote or tronque(self.nom) or tronque(self.rang) or tronque(self.zone)) then return end
		local n = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:AddLine(nom)
		GameTooltip:AddLine(rang or "")
		if niveau and classe then
			GameTooltip:AddLine(string.format(txt("FRIENDS_LEVEL_TEMPLATE"), niveau, classe), 1, 1, 1, true)
		end
		if enLigne and zone and zone ~= "" then
			GameTooltip:AddLine(zone, 1, 1, 1, true)
		end
		if note and note ~= "" then
			GameTooltip:AddLine(txt("NOTE_COLON") .. " " .. note, n.r, n.g, n.b, true)
		end
		GameTooltip:Show()
	end)
	l:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

-- UpdateNameFrame : le nom apres la presence, l'icone de rang apres le nom
local function majCadreNom(l)
	local icones, decalage = 0, 0
	local presence = l.presence:IsShown()
	l.nom:ClearAllPoints()
	if presence then
		icones = icones + 20
		l.nom:SetPoint("LEFT", l.presence, "RIGHT", 0, 0)
		decalage = l.presence:GetWidth()
	else
		l.nom:SetPoint("LEFT", l.cadreNom, "LEFT", 0, 0)
	end
	if l.rangIcone:IsShown() then
		icones = icones + (presence and 20 or 25)
	end
	local largeurNom = P.nomL - icones
	l.nom:SetWidth(largeurNom)
	local texte = l.nom:GetStringWidth()
	l.rangIcone:ClearAllPoints()
	l.rangIcone:SetPoint("LEFT", l.cadreNom, "LEFT", math.min(texte, largeurNom) + decalage, 0)
end

-- CommunitiesMemberListEntryMixin : SetMember, UpdateRank, UpdatePresence,
-- RefreshExpandedColumns
local function remplirLigne(l, i)
	local nom, rang, rangIndex, niveau, _, zone, _, _, enLigne, statut, fichier = GetGuildRosterInfo(i)
	l.nom:SetText(nom)
	l.niveau:SetText(niveau or "")
	local tc = fichier and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[fichier]
	if tc then
		l.classe:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
		l.classe:Show()
	else
		l.classe:Hide()
	end
	local champs = { l.niveau, l.zone, l.rang }
	if enLigne then
		l.nom:SetTextColor(couleurClasse(fichier))
		for _, fs in ipairs(champs) do fs:SetTextColor(1, 1, 1) end
		if statut == CHAT_FLAG_AFK then
			l.presence:SetTexture(FRIENDS_TEXTURE_AFK or P.absent)
			l.presence:Show()
		elseif statut == CHAT_FLAG_DND then
			l.presence:SetTexture(FRIENDS_TEXTURE_DND or P.occupe)
			l.presence:Show()
		else
			l.presence:Hide()
		end
		l.zone:SetText(zone or "")
	else
		l.presence:Hide()
		l.nom:SetTextColor(P.gris, P.gris, P.gris)
		for _, fs in ipairs(champs) do fs:SetTextColor(P.gris, P.gris, P.gris) end
		l.zone:SetText(depuis(GetGuildRosterLastOnline(i)))
	end
	l.rang:SetText(rang or "")
	if rangIndex == 0 then
		l.rangIcone:SetTexture(P.chef)
		l.rangIcone:Show()
	else
		l.rangIcone:Hide()
	end
	majCadreNom(l)
	if GetGuildRosterSelection() == i then l:LockHighlight() else l:UnlockHighlight() end
end

-- -------------------------------------------------------------- le detail

local D = {}

local function champDetail(a, libelle, y)
	local l = a:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	l:SetPoint("TOPLEFT", a, "TOPLEFT", 18, y)
	l:SetText(txt(libelle))
	local v = a:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	v:SetPoint("LEFT", l, "RIGHT", 6, 0)
	v:SetPoint("RIGHT", a, "RIGHT", -18, 0)
	v:SetJustifyH("LEFT")
	v:SetHeight(12)
	return l, v
end

-- Une note : un encadre cliquable, son texte gris quand on ne peut l'ecrire.
local function noteDetail(a, libelle, popup)
	local l = a:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	l:SetText(txt(libelle))
	local e = ForeverUI.CreateInset(a)
	e:SetHeight(40)
	e:SetPoint("TOPLEFT", l, "BOTTOMLEFT", -2, -3)
	e:SetPoint("RIGHT", a, "RIGHT", -16, 0)
	e:EnableMouse(true)
	local t = e:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	t:SetPoint("TOPLEFT", e, "TOPLEFT", 6, -5)
	t:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -6, 5)
	t:SetJustifyH("LEFT")
	t:SetJustifyV("TOP")
	if t.SetWordWrap then t:SetWordWrap(true) end
	e:SetScript("OnMouseUp", function(self)
		if self.editable then StaticPopup_Show(popup) end
	end)
	return l, e, t
end

local function creerDetail()
	local a = S.creerAnnexe("ForeverUIGuildMemberDetail", 232, 290)
	D.cadre = a
	D.niveau = a:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	D.niveau:SetPoint("TOPLEFT", a, "TOPLEFT", 18, -30)
	D.zoneL, D.zone = champDetail(a, "ZONE_COLON", -48)
	D.rangL, D.rang = champDetail(a, "RANK_COLON", -64)
	D.rang:SetPoint("RIGHT", a, "RIGHT", -52, 0)
	D.vuL, D.vu = champDetail(a, "LAST_ONLINE_COLON", -80)
	-- promouvoir / retrograder : les fleches de la barre de camelot
	local function fleche(atlas, survol, clic)
		local f = CreateFrame("Button", nil, a)
		f:SetWidth(17)
		f:SetHeight(11)
		local e = ForeverUI.AtlasEntry(atlas)
		f:SetNormalTexture(e and e[1] or "")
		local n = f:GetNormalTexture()
		if n then ForeverUI.SetAtlas(n, atlas, true) n:SetAllPoints(f) end
		f:SetHighlightTexture(e and e[1] or "")
		local h = f:GetHighlightTexture()
		if h then ForeverUI.SetAtlas(h, survol, true) h:SetAllPoints(f) end
		f:SetScript("OnClick", clic)
		return f
	end
	D.promouvoir = fleche("minimal-scrollbar-arrow-top-c60", "minimal-scrollbar-arrow-top-over-c60", function(self)
		GuildPromote(GuildFrame.selectedName)
		PlaySound("UChatScrollButton")
		self:Disable()
	end)
	D.promouvoir:SetPoint("LEFT", D.rang, "RIGHT", 4, 6)
	D.retrograder = fleche("minimal-scrollbar-arrow-bottom-c60", "minimal-scrollbar-arrow-bottom-over-c60", function(self)
		GuildDemote(GuildFrame.selectedName)
		PlaySound("UChatScrollButton")
		self:Disable()
	end)
	D.retrograder:SetPoint("TOP", D.promouvoir, "BOTTOM", 0, -2)
	D.noteL, D.note, D.noteTexte = noteDetail(a, "NOTE_COLON", "SET_GUILDPLAYERNOTE")
	D.noteL:SetPoint("TOPLEFT", a, "TOPLEFT", 18, -102)
	D.officierL, D.officier, D.officierTexte = noteDetail(a, "OFFICER_NOTE_COLON", "SET_GUILDOFFICERNOTE")
	D.officierL:SetPoint("TOPLEFT", D.note, "BOTTOMLEFT", 2, -10)
	D.retirer = S.bouton(a, txt("REMOVE"), 100)
	D.retirer:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 12, 12)
	D.retirer:SetScript("OnClick", function() StaticPopup_Show("REMOVE_GUILDMEMBER") end)
	D.inviter = S.bouton(a, txt("GROUP_INVITE"), 100)
	D.inviter:SetPoint("LEFT", D.retirer, "RIGHT", 4, 0)
	D.inviter:SetScript("OnClick", function() InviteUnit(GuildFrame.selectedName) end)
	a:HookScript("OnHide", function()
		-- le detail se ferme : plus de selection (le client la remet a 0)
		if Gu.fermeture then return end
		Gu.selection(0)
	end)
end

-- GuildStatus_Update, pour le volet de detail
function Gu.majDetail()
	local a = D.cadre
	if not a or not a:IsShown() then return end
	local i = GetGuildRosterSelection()
	if not i or i == 0 then a:Hide() return end
	local nom, rang, rangIndex, niveau, classe, zone, note, officier, enLigne = GetGuildRosterInfo(i)
	local _, _, monRang = GetGuildInfo("player")
	monRang = monRang or 0
	local maxRang = (GuildControlGetNumRanks and GuildControlGetNumRanks() or 1) - 1
	a.titre:SetText(nom or "")
	D.niveau:SetText(string.format(txt("FRIENDS_LEVEL_TEMPLATE"), niveau or 0, classe or ""))
	D.zone:SetText(zone)
	D.rang:SetText(rang)
	D.vu:SetText(enLigne and txt("GUILD_ONLINE_LABEL") or depuis(GetGuildRosterLastOnline(i)))
	-- la note publique
	D.note.editable = CanEditPublicNote()
	if D.note.editable then
		if not note or note == "" then note = txt("GUILD_NOTE_EDITLABEL") end
		D.noteTexte:SetTextColor(1, 1, 1)
	else
		D.noteTexte:SetTextColor(P.grisTexte, P.grisTexte, P.grisTexte)
	end
	D.noteTexte:SetText(note or "")
	-- la note d'officier
	if CanViewOfficerNote() then
		D.officier.editable = CanEditOfficerNote()
		if D.officier.editable then
			if not officier or officier == "" then officier = txt("GUILD_OFFICERNOTE_EDITLABEL") end
			D.officierTexte:SetTextColor(1, 1, 1)
		else
			D.officierTexte:SetTextColor(P.grisTexte, P.grisTexte, P.grisTexte)
		end
		D.officierTexte:SetText(officier or "")
		D.officierL:Show()
		D.officier:Show()
		a:SetHeight(290)
	else
		D.officierL:Hide()
		D.officier:Hide()
		a:SetHeight(230)
	end
	-- promouvoir, retrograder, retirer, inviter
	local peutMonter = CanGuildPromote() and rangIndex and rangIndex > 1 and rangIndex > (monRang + 1)
	local peutDescendre = CanGuildDemote() and rangIndex and rangIndex >= 1 and rangIndex > monRang and rangIndex ~= maxRang
	if peutMonter then D.promouvoir:Enable() else D.promouvoir:Disable() end
	if peutDescendre then D.retrograder:Enable() else D.retrograder:Disable() end
	if peutMonter or peutDescendre then
		D.promouvoir:Show()
		D.retrograder:Show()
	else
		D.promouvoir:Hide()
		D.retrograder:Hide()
	end
	actif(D.retirer, CanGuildRemove() and rangIndex and rangIndex >= 1 and rangIndex > monRang)
	actif(D.inviter, UnitName("player") ~= nom and enLigne and true or false)
end

-- La selection du client, et ce que ses popups lisent.
function Gu.selection(i)
	SetGuildRosterSelection(i or 0)
	if GuildFrame then
		GuildFrame.selectedGuildMember = i or 0
		GuildFrame.selectedName = (i and i > 0) and GetGuildRosterInfo(i) or nil
	end
	if Gu.liste then Gu.liste:Maj() end
end

-- FriendsFrameGuildStatusButton_OnClick
function Gu.cliquer(l, bouton)
	local i = l.index
	if bouton == "RightButton" then
		local nom, _, _, _, _, _, _, _, enLigne = GetGuildRosterInfo(i)
		FriendsFrame_ShowDropdown(nom, enLigne)
		return
	end
	PlaySound("igMainMenuOptionCheckBoxOn")
	if D.cadre:IsShown() and GetGuildRosterSelection() == i then
		Gu.selection(0)
		D.cadre:Hide()
	else
		Gu.selection(i)
		D.cadre:Show()
		Gu.majDetail()
	end
end

-- ------------------------------------------------------------ l'information

local I = {}

local function creerInfo()
	local a = S.creerAnnexe("ForeverUIGuildInfoFrame", 300, 300)
	a.titre:SetText(txt("GUILD_INFORMATION"))
	I.cadre = a
	local e = ForeverUI.CreateInset(a)
	e:SetPoint("TOPLEFT", a, "TOPLEFT", 12, -30)
	e:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -12, 44)
	local defil = CreateFrame("ScrollFrame", "ForeverUIGuildInfoScroll", e)
	defil:SetPoint("TOPLEFT", e, "TOPLEFT", 6, -6)
	defil:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -6, 6)
	local b = CreateFrame("EditBox", "ForeverUIGuildInfoEditBox", defil)
	b:SetMultiLine(true)
	b:SetAutoFocus(false)
	b:SetMaxLetters(500)
	b:SetWidth(250)
	b:SetHeight(200)
	b:SetFontObject(GameFontHighlightSmall)
	b:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	defil:SetScrollChild(b)
	defil:EnableMouse(true)
	defil:SetScript("OnMouseUp", function()
		if CanEditGuildInfo() then b:SetFocus() else b:ClearFocus() end
	end)
	I.saisie = b
	I.accepter = S.bouton(a, txt("ACCEPT"), 90)
	-- de gauche a droite : Log, puis Accept et Close contre le bord droit --
	-- ancres au centre, Accept chevauchait Log (2026-09-26)
	I.accepter:SetScript("OnClick", function()
		SetGuildInfoText(b:GetText())
		if GuildInfoFrame then GuildInfoFrame.cachedText = b:GetText() end
		I.texteRetenu = b:GetText()
		GuildRoster()
		a:Hide()
	end)
	local fermer = S.bouton(a, txt("CLOSE"), 90)
	fermer:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -12, 14)
	I.accepter:SetPoint("RIGHT", fermer, "LEFT", -4, 0)
	fermer:SetScript("OnClick", function() a:Hide() end)
	local journal = S.bouton(a, txt("GUILD_EVENT_LOG"), 70)
	journal:SetPoint("BOTTOMLEFT", a, "BOTTOMLEFT", 12, 14)
	journal:SetScript("OnClick", function() Gu.basculerJournal() end)
	Gu.infoBoutons = { journal = journal, accepter = I.accepter, fermer = fermer }
	-- l'OnShow de GuildInfoTextBackground
	a:HookScript("OnShow", function()
		local texte = I.texteRetenu or GetGuildInfoText() or ""
		if CanEditGuildInfo() then
			b:SetText(texte ~= "" and texte or txt("GUILD_INFO_EDITLABEL"))
			b:SetTextColor(1, 1, 1)
			b:EnableMouse(true)
			actif(I.accepter, true)
		else
			b:SetText(texte)
			b:SetTextColor(P.grisTexte, P.grisTexte, P.grisTexte)
			b:EnableMouse(false)
			actif(I.accepter, false)
		end
	end)
end

-- -------------------------------------------------------------- le journal

local J = {}

local function ligneJournal(i)
	local type, j1, j2, rang, annee, mois, jour, heure = GetGuildEventInfo(i)
	j1 = j1 or txt("UNKNOWN")
	j2 = j2 or txt("UNKNOWN")
	local msg
	if type == "invite" then msg = string.format(txt("GUILDEVENT_TYPE_INVITE"), j1, j2)
	elseif type == "join" then msg = string.format(txt("GUILDEVENT_TYPE_JOIN"), j1)
	elseif type == "promote" then msg = string.format(txt("GUILDEVENT_TYPE_PROMOTE"), j1, j2, rang)
	elseif type == "demote" then msg = string.format(txt("GUILDEVENT_TYPE_DEMOTE"), j1, j2, rang)
	elseif type == "remove" then msg = string.format(txt("GUILDEVENT_TYPE_REMOVE"), j1, j2)
	elseif type == "quit" then msg = string.format(txt("GUILDEVENT_TYPE_QUIT"), j1)
	end
	if not msg then return "" end
	return msg .. "|cff009999   " .. string.format(txt("GUILD_BANK_LOG_TIME"), depuis(annee, mois, jour, heure)) .. "|r"
end

local function creerJournal()
	local a = S.creerAnnexe("ForeverUIGuildEventLog", 400, 420)
	a.titre:SetText(txt("GUILD_EVENT_LOG"))
	J.cadre = a
	local e = ForeverUI.CreateInset(a)
	e:SetPoint("TOPLEFT", a, "TOPLEFT", 12, -30)
	e:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -12, 44)
	J.liste = S.creerListe(e, "ForeverUIGuildEventList", 14, function(l)
		l.texte = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		l.texte:SetPoint("LEFT", l, "LEFT", 4, 0)
		l.texte:SetPoint("RIGHT", l, "RIGHT", -4, 0)
		l.texte:SetJustifyH("LEFT")
		l.texte:SetHeight(12)
	end, function(l, n)
		-- le plus recent d'abord, comme la boucle du client
		l.texte:SetText(ligneJournal((GetNumGuildEvents() or 0) - n + 1))
	end)
	J.liste:SetPoint("TOPLEFT", e, "TOPLEFT", 4, -4)
	J.liste:SetPoint("BOTTOMRIGHT", e, "BOTTOMRIGHT", -16, 4)
	local fermer = S.bouton(a, txt("CLOSE"), 140)
	fermer:SetPoint("BOTTOM", a, "BOTTOM", 0, 14)
	fermer:SetScript("OnClick", function() a:Hide() end)
	a:HookScript("OnShow", function()
		QueryGuildEventLog()
		J.liste:Maj(GetNumGuildEvents() or 0)
	end)
end

function Gu.basculerJournal()
	if J.cadre:IsShown() then J.cadre:Hide() else J.cadre:Show() end
end

-- ------------------------------------------------------------ la mise a jour

function Gu.maj()
	if not Gu.liste then return end
	-- la liste : les membres montres (sans les hors ligne si la case est
	-- decochee) ; le total : tous les membres
	local montres = GetNumGuildMembers() or 0
	local total = GetNumGuildMembers(true) or montres
	local enLigne = 0
	for i = 1, montres do
		if select(9, GetGuildRosterInfo(i)) then enLigne = enLigne + 1 end
	end
	Gu.totaux:SetText(string.format(txt("GUILD_TOTAL"), total) .. " " .. string.format(txt("GUILD_TOTALONLINE"), enLigne))
	Gu.horsLigne:SetChecked(GetGuildRosterShowOffline() and true or false)
	Gu.liste:Maj(montres)
	-- le message du jour
	Gu.motd:SetText(CURRENT_GUILD_MOTD or (GetGuildRosterMOTD and GetGuildRosterMOTD()) or "")
	if CanEditMOTD() then
		Gu.motd:SetTextColor(1, 1, 1)
		Gu.motdZone:EnableMouse(true)
	else
		Gu.motd:SetTextColor(P.grisTexte, P.grisTexte, P.grisTexte)
		Gu.motdZone:EnableMouse(false)
	end
	actif(Gu.controle, IsGuildLeader() and true or false)
	actif(Gu.ajouter, CanGuildInvite() and true or false)
	Gu.majDetail()
end

local function titre()
	local guilde, rang = GetGuildInfo("player")
	if guilde then return string.format(txt("GUILD_TITLE_TEMPLATE"), rang or "", guilde) end
	return ""
end

-- ------------------------------------------------------ la fenetre de controle

local CASES_CONTROLE = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17 }
Gu.CONTROLE_HAUT = 24

function Gu.habillerControle(gc)
	if gc.foreverHabille then return end
	gc.foreverHabille = true
	-- le fond MacroPopup : six textures sans nom
	for _, r in ipairs({ gc:GetRegions() }) do
		local f = r.GetTexture and r:GetTexture()
		if type(f) == "string" and string.find(string.lower(f), "macropopup", 1, true) then
			r:SetAlpha(0)
			r:Hide()
		end
	end
	-- L'HABIT DEPASSE DE 24 VERS LE HAUT. Le contenu du client commence 15
	-- sous le bord (GUILDCONTROL_SELECTRANK) : la barre de metal passerait
	-- dessus. L'habit porte la barre au-dessus, et se dessine SOUS le
	-- contenu (un niveau de moins que la fenetre) ; son metal, lui, passe
	-- devant. Taille posee a la main : UpdatePanelCorners la lit.
	local habit = CreateFrame("Frame", nil, gc)
	habit:SetWidth(gc:GetWidth() > 0 and gc:GetWidth() or 320)
	habit:SetHeight((gc:GetHeight() > 0 and gc:GetHeight() or 457) + Gu.CONTROLE_HAUT)
	habit:SetPoint("TOPLEFT", gc, "TOPLEFT", 0, Gu.CONTROLE_HAUT)
	habit:SetFrameLevel(math.max(0, gc:GetFrameLevel() - 1))
	ForeverUI.SetPanelArt(habit, { coinHautGauche = "ui-frame-metal-cornertopleft", niveau = 25 })
	gc.foreverHabit = habit
	local metal = habit.foreverHabillage or habit
	local bandeau = CreateFrame("Frame", nil, gc)
	bandeau:SetAllPoints(habit)
	bandeau:SetFrameLevel(metal:GetFrameLevel() + 1)
	local titre = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titre:SetPoint("TOP", habit, "TOP", 0, -6)
	titre:SetText(txt("GUILDCONTROL"))
	gc.foreverTitre = titre
	local croix = CreateFrame("Button", nil, gc)
	croix:SetWidth(24)
	croix:SetHeight(24)
	croix:SetFrameLevel(metal:GetFrameLevel() + 2)
	croix:SetPoint("TOPRIGHT", habit, "TOPRIGHT", 1, 0)
	for _, etat in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		local e = ForeverUI.AtlasEntry(etat[3])
		croix[etat[1]](croix, e and e[1] or "")
		local t = croix[etat[2]](croix)
		if t then
			ForeverUI.SetAtlas(t, etat[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(croix)
			if etat[3] == "redbutton-highlight" then t:SetBlendMode("ADD") end
		end
	end
	croix:SetScript("OnClick", function() gc:Hide() end)
	gc.foreverCroix = croix
	-- les cases
	for _, i in ipairs(CASES_CONTROLE) do
		local c = _G["GuildControlPopupFrameCheckbox" .. i]
		if c then S.habillerCase(c) end
	end
	for _, n in ipairs({ "GuildControlTabPermissionsViewTab", "GuildControlTabPermissionsDepositItems",
		"GuildControlTabPermissionsUpdateText" }) do
		if _G[n] then S.habillerCase(_G[n]) end
	end
	-- les champs
	for _, n in ipairs({ "GuildControlPopupFrameEditBox", "GuildControlWithdrawGoldEditBox",
		"GuildControlWithdrawItemsEditBox" }) do
		if _G[n] then S.habillerSaisie(_G[n]) end
	end
	-- le cadre des droits de banque : l'encadre de camelot a la place du
	-- fond d'infobulle
	local tp = _G["GuildControlPopupFrameTabPermissions"]
	if tp then
		if tp.SetBackdrop then tp:SetBackdrop(nil) end
		ForeverUI.DecorateInset(tp)
	end
end

-- ------------------------------------------------------------ la construction

local function construire(cadre)
	local encadre = ForeverUI.CreateInset(cadre, "ForeverUIGuildInset")
	encadre:SetPoint("TOPLEFT", S.cadre, "TOPLEFT", 4, P.encadreY1)
	encadre:SetPoint("BOTTOMRIGHT", S.cadre, "BOTTOMRIGHT", -6, P.encadreBas)

	-- LES EN-TETES : GUILD_COLUMN_INFO sans la note, Rank jusqu'au bord
	Gu.entetes = {}
	local precedent
	for i, col in ipairs(P.colonnes) do
		local h = S.creerEntete(encadre, "ForeverUIGuildColumn" .. i, col[2] > 0 and col[2] or P.remplirL, txt(col[1]), function(self)
			SortGuildRoster(self.tri)
		end)
		h.tri = col[3]
		if precedent then
			h:SetPoint("LEFT", precedent, "RIGHT", P.ecart, 0)
		else
			h:SetPoint("TOPLEFT", encadre, "TOPLEFT", P.enteteX, P.enteteY)
		end
		Gu.entetes[i] = h
		precedent = h
	end
	Gu.liste = S.creerListe(encadre, "ForeverUIGuildList", P.ligneH, creerLigne, remplirLigne)
	-- sans barre, la liste et la colonne Rank vont jusqu'au bord
	Gu.liste:SuivreBarre({ "TOPLEFT", Gu.entetes[1], "BOTTOMLEFT", 1, -1 },
		{ "BOTTOMRIGHT", encadre, "BOTTOMRIGHT", P.listeX2, 4 }, P.listeX2Seule)
	Gu.entetes[#P.colonnes]:SetPoint("BOTTOMRIGHT", Gu.liste, "TOPRIGHT", P.noteDroite, 1)

	Gu.totaux = cadre:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	Gu.totaux:SetPoint("TOPLEFT", S.cadre, "TOPLEFT", P.totauxX, P.totauxY)

	-- LA CASE DES HORS LIGNE (ShowOfflineButton), en haut a droite
	local hors = S.creerCase(cadre, "ForeverUIGuildShowOffline", txt("SHOW_OFFLINE_MEMBERS"))
	hors:SetPoint("TOPRIGHT", S.cadre, "TOPRIGHT", P.horsDroite - hors.texte:GetStringWidth() - 2, P.horsY)
	-- l'OnClick de GuildFrameLFGButton : la selection s'efface -- les index
	-- du roster changent avec le filtre --, le filtre bascule, et la liste se
	-- refait tout de suite (GuildStatus_Update) ; sans cela elle attendait le
	-- prochain GUILD_ROSTER_UPDATE, et le detail pouvait montrer un autre
	-- membre (2026-09-26)
	hors:SetScript("OnClick", function(self)
		Gu.selection(0)
		if self:GetChecked() then
			PlaySound("igMainMenuOptionCheckBoxOff")
		else
			PlaySound("igMainMenuOptionCheckBoxOn")
		end
		SetGuildRosterShowOffline(self:GetChecked() and true or false)
		Gu.maj()
	end)
	Gu.horsLigne = hors

	-- le message du jour
	local lib = cadre:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	lib:SetPoint("BOTTOMLEFT", S.cadre, "BOTTOMLEFT", P.motdX, P.motdBas + P.motdH + 2)
	lib:SetText(txt("GUILD_MOTD_LABEL"))
	local zone = CreateFrame("Button", "ForeverUIGuildMOTD", cadre)
	zone:SetPoint("BOTTOMLEFT", S.cadre, "BOTTOMLEFT", P.motdX, P.motdBas)
	zone:SetPoint("BOTTOMRIGHT", S.cadre, "BOTTOMRIGHT", -P.motdX, P.motdBas)
	zone:SetHeight(P.motdH)
	local motd = zone:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	motd:SetAllPoints(zone)
	motd:SetJustifyH("LEFT")
	motd:SetJustifyV("TOP")
	if motd.SetWordWrap then motd:SetWordWrap(true) end
	zone:SetScript("OnClick", function() StaticPopup_Show("SET_GUILDMOTD") end)
	Gu.motd, Gu.motdZone = motd, zone

	-- les trois boutons du bas
	Gu.info = S.bouton(cadre, txt("GUILD_INFORMATION"), 130)
	Gu.info:SetPoint("BOTTOMRIGHT", S.cadre, "BOTTOMRIGHT", P.boutonDroite, P.boutonBas)
	Gu.info:SetScript("OnClick", function()
		if I.cadre:IsShown() then I.cadre:Hide() else I.cadre:Show() end
	end)
	Gu.ajouter = S.bouton(cadre, txt("ADDMEMBER"), 110)
	Gu.ajouter:SetPoint("RIGHT", Gu.info, "LEFT", -2, 0)
	Gu.ajouter:SetScript("OnClick", function() StaticPopup_Show("ADD_GUILDMEMBER") end)
	Gu.controle = S.bouton(cadre, txt("GUILDCONTROL"), 120)
	Gu.controle:SetPoint("RIGHT", Gu.ajouter, "LEFT", -2, 0)
	Gu.controle:SetScript("OnClick", function()
		local gc = GuildControlPopupFrame
		if not gc then return end
		if gc:IsShown() then
			gc:Hide()
		else
			if S.annexe then S.annexe:Hide() end
			if GuildControlPopupFrame_Initialize and not gc.initialized then
				GuildControlPopupFrame_Initialize()
			end
			gc:Show()
		end
	end)

	creerDetail()
	creerInfo()
	creerJournal()

	-- LA FENETRE DE CONTROLE DU CLIENT (parent UIParent), recollee a droite
	-- de notre fenetre a chaque ouverture ; ancree sur GuildFrame, elle
	-- partirait hors de l'ecran avec lui.
	if GuildControlPopupFrame then
		Gu.habillerControle(GuildControlPopupFrame)
		GuildControlPopupFrame:HookScript("OnShow", function(self)
			if S.annexe then S.annexe:Hide() end
			self:ClearAllPoints()
			self:SetPoint("TOPLEFT", S.cadre, "TOPRIGHT", 12, -Gu.CONTROLE_HAUT)
		end)
	end

	-- LE CADRE DE GUILDE DU CLIENT : garde, loin de l'ecran, transparent.
	if GuildFrame then
		S.garder("GuildFrame")
		GuildFrame:ClearAllPoints()
		GuildFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -5000, 5000)
		GuildFrame:SetWidth(384)
		GuildFrame:SetHeight(512)
		GuildFrame:SetAlpha(0)
		if GuildFrame.EnableMouse then GuildFrame:EnableMouse(false) end
	end
end

S.inscrirePage(3, {
	construire = construire,
	titre = titre,
	maj = Gu.maj,
	montrer = function(premiere)
		if premiere then GuildRoster() end
	end,
	cacher = function()
		Gu.fermeture = true
		for _, a in ipairs({ D.cadre, I.cadre, J.cadre }) do
			if a then a:Hide() end
		end
		if GuildControlPopupFrame then GuildControlPopupFrame:Hide() end
		Gu.fermeture = nil
	end,
})

local veilleur = CreateFrame("Frame")
for _, ev in ipairs({ "GUILD_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "GUILD_MOTD", "GUILD_EVENT_LOG_UPDATE" }) do
	veilleur:RegisterEvent(ev)
end
veilleur:SetScript("OnEvent", function(self, ev)
	if ev == "GUILD_ROSTER_UPDATE" then I.texteRetenu = nil end
	if ev == "GUILD_EVENT_LOG_UPDATE" then
		if J.cadre and J.cadre:IsShown() then J.liste:Maj(GetNumGuildEvents() or 0) end
		return
	end
	if Gu.liste and Gu.liste:IsVisible() then Gu.maj() end
end)
