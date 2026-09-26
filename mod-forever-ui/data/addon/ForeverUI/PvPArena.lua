-- ForeverUI : les equipes d'arene, dans le volet gauche de l'onglet PvP.
--
-- DEMANDE du 2026-09-25 : mettre dans le volet gauche l'interface des equipes
-- d'arene et lui appliquer le theme de camelot. Choix de l'utilisateur :
-- trois CARTES portant la banniere de WotLK, et le detail d'une equipe dans
-- une FENETRE A PART, a cote de la feuille.
--
-- camelot N'A PAS D'EQUIPES D'ARENE : aucun fichier de camelot/ ni de shared/
-- n'appelle GetArenaTeam ni ArenaTeamRoster (seul cata/pvpframe le fait, une
-- autre famille). L'ecran se reprend donc de WotLK, habille de l'art de
-- camelot deja employe ailleurs.
--
-- RELEVE -- Interface\FrameXML\PVPFrame.lua, PVPFrame.xml et
-- PVPFrameTemplates.xml du client, lus dans l'archive :
--
--   PVPTeam_Update     les trois emplacements sont TRIES PAR TAILLE, 2, 3
--                      puis 5 ; une equipe absente laisse un emplacement
--                      grise (bouton 0,4, etendard 0,1, sans bord ni
--                      embleme) qui porte PVP_TEAMSIZE "(2v2)" en
--                      GameFontDisableLarge
--   une equipe         nom, ARENA_TEAM_RATING et la cote ; ARENA_THIS_WEEK,
--                      puis GAMES, WIN_LOSS et PLAYED : "joues (pct%)", en
--                      ROUGE sous 10 %
--   l'etendard         PVPTeamStandardTemplate : la hampe (Elements, 50 x 13
--                      en (-8, 6)), la banniere PVP-Banner-<taille> 45 x 90
--                      TOP sur la hampe (5, -2) et teintee, le bord
--                      PVP-Banner-<taille>-Border-<n> centre, l'embleme
--                      Icons\PVP-Banner-Emblem-<n> 24 x 24 en (-5, 17) ;
--                      -1 = pas de bord, pas d'embleme
--   l'infobulle        GameTooltip_AddNewbieTip : ARENA_TEAM, puis
--                      CLICK_FOR_DETAILS, ou ARENA_TEAM_LEAD_IN sans equipe
--   le clic            PVPTeam_OnClick : ouvre le detail de l'equipe, ou le
--                      referme si c'est deja elle
--   hors saison        GetCurrentArenaSeason() == 0 : les trois cartes s'en
--                      vont, ARENA_OFF_SEASON_TEXT les remplace
--   points d'arene     PVP_LABEL_ARENA "ARENA:" en GameFontHighlightSmall,
--                      GetArenaCurrency en GameFontNormal a +15, l'icone
--                      PVP-ArenaPoints-Icon 17 x 15 a +5 ; infobulle
--                      ARENA_POINTS / TOOLTIP_ARENA_POINTS
--
-- LA BASCULE SEMAINE / SAISON N'EST PAS SUR LES CARTES, ET C'EST WotLK.
-- PVPTeam_Update compte ses trois emplacements -- vides compris -- et cache
-- PVPFrameToggleButton quand le compte vaut trois : il le vaut toujours. Les
-- cartes montrent donc la semaine ; la saison se lit dans la fenetre de
-- detail, qui a sa propre bascule.
--
-- LA FENETRE DE DETAIL -- PVPTeamDetails, 400 x 355 :
--   en-tete    nom et taille ; ARENA_THIS_WEEK / _SEASON en capitales ;
--              GAMES, WIN_LOSS, RANK et ARENA_TEAM_RATING, colonnes
--              centrees a 170, 222, 274 et 326
--   colonnes   NAME 110, CLASS 80, PLAYED 55, WIN_LOSS 75, RATING 59,
--              chevauchees de 2, WhoFrame-ColumnTabs ; clic =
--              SortArenaTeamRoster(name, class, played|seasonplayed,
--              won|seasonwon, rating)
--   membres    dix lignes de 16, ecart 3, a (15, -115) : nom 104, classe 73,
--              joues 45 (infobulle : le pourcentage), victoires-defaites 72,
--              cote 54 ; blanc en ligne, OR pour le capitaine (rang 0), gris
--              hors ligne ; joues en rouge sous 10 % ; clic gauche =
--              SetArenaTeamRosterSelection, droit = PVPFrame_ShowDropdown
--   boutons    ADDMEMBER_TEAM 100 x 22 (StaticPopup ADD_TEAMMEMBER) ; la
--              fleche UI-SpellbookIcon-NextPage 32 x 32 a (-17, 17) et son
--              texte ARENA_THIS_SEASON_TOGGLE / _WEEK_TOGGLE a sa gauche
--   ouverture  ArenaTeamRoster(id) ; fermeture CloseArenaTeamRoster()
--
-- CE QUE LE CLIENT GARDE POUR LUI, ET CE QU'ON LUI PRETE.
-- Le menu d'un membre (UnitPopup "TEAM") et la fenetre d'ajout
-- (ADD_TEAMMEMBER) lisent PVPTeamDetails.team, et le menu ne propose
-- TEAM_PROMOTE / KICK / LEAVE que si PVPTeamDetails:IsShown(). On TIENT
-- donc ce cadre du client a jour : son equipe est la notre, et il est
-- "montre" -- son drapeau, pas son affichage : il vit sous PVPFrame, que
-- l'onglet eteint, et IsShown ne regarde que le cadre lui-meme. Il reste
-- invisible, et PVPFrame_OnEvent continue de lui redemander la liste quand
-- le serveur l'annonce.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local A = {}
ForeverUI.PvPArena = A

local SEP = string.char(92)
local PVP = "Interface" .. SEP .. "PVPFrame" .. SEP
local ELEMENTS = PVP .. "UI-Character-PVP-Elements"
local ICONE_POINTS = PVP .. "PVP-ArenaPoints-Icon"
local ONGLETS_COLONNE = "Interface" .. SEP .. "FriendsFrame" .. SEP .. "WhoFrame-ColumnTabs"
local SURBRILLANCE_COLONNE = "Interface" .. SEP .. "PaperDollInfoFrame" .. SEP .. "UI-Character-Tab-Highlight"
local FLECHE = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-SpellbookIcon-NextPage-"
local SURVOL_CARRE = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Common-MouseHilight"

local TAILLES = { 2, 3, 5 }
local MAX_EQUIPES = 3
local MAX_MEMBRES = 10

-- L'ORDRE DU VOLET, du haut vers le bas (demande du 2026-09-25) : le titre
-- du rang, la jauge, le compteur de victoires, UN SEPARATEUR, le nombre de
-- points d'arene, puis la liste des equipes. Chaque morceau s'accroche au
-- precedent : le compteur au cadran (PvPTab.lua), le separateur au
-- compteur, les points au separateur ; les cartes, elles, se serrent
-- contre le bas du volet (voir CARTES_BAS).
--
-- L'HONNEUR ET SON SEPARATEUR ont pris place au-dessus de la jauge
-- (2026-09-26) : tout descend d'environ 45. Compte fait -- titre jusqu'a
-- -29, son trait jusqu'a -39, honneur -41 a -72, separateur -76 a -84,
-- cadran -84 a -238, compteur -239 a -251, separateur -255 a -263, points
-- -267 a -282 -- les cartes de 56 finissaient a -464, au ras du volet.
-- ELLES PASSENT A 52, ecart 3 : de -287 a -449.
local VOLET_L = 398
local CARTES_X = 16
local CARTE_L = VOLET_L - 2 * CARTES_X
local CARTE_H, CARTE_ECART = 52, 0     -- jointives (2026-09-26, "encore plus")
local ATLAS_SEPARATEUR = "ui-character-info-scrollline-long"
local SEPARATEUR_SOUS_COMPTEUR = -4
-- LES EQUIPES SONT SERREES CONTRE LE BAS DU VOLET (demande du 2026-09-26) :
-- la derniere a CARTES_BAS du bas, chacune au-dessus de la suivante ; la
-- place libre reste entre les points d'arene et la premiere.
local CARTES_BAS = 4
local HORS_SAISON_SOUS_POINTS = -10
local NIVEAU = 6                        -- au-dessus du cadran (sa lueur deborde)

-- L'ETENDARD, ramene de 90 a 48 de haut pour tenir dans une carte.
local ECHELLE = 48 / 90
local HAMPE_X, HAMPE_Y = 8, -2
local HAMPE_L, HAMPE_H = 50 * ECHELLE, 13 * ECHELLE
local BANNIERE_L, BANNIERE_H = 45 * ECHELLE, 90 * ECHELLE
local BANNIERE_X, BANNIERE_Y = 5 * ECHELLE, -2 * ECHELLE
local EMBLEME = 24 * ECHELLE
local EMBLEME_X, EMBLEME_Y = -5 * ECHELLE, 17 * ECHELLE

-- CE QUE LA CARTE ECRIT.
local TEXTE_X = 50
local NOM_Y, NOM_L = -7, 190
local COTE_X, COTE_Y = -14, -8
local TYPE_Y = -30
local ETIQUETTES_Y = -24
local VALEUR_ECART = -2
local COLONNES_CARTE = { jeux = 170, bilan = 245, joues = 320 }
local POINTS_ECART, ICONE_ECART = 15, 5
local ICONE_L, ICONE_H = 17, 15

-- La plaque de camelot et son survol, comme les lignes de la reputation.
local ATLAS_PLAQUE = "common-button-list-collapseexpand"
local PLAQUE_COIN = 12
local ATLAS_SURVOL_COTE = "charactercreate-customize-dropdown-linemouseover-side"
local ATLAS_SURVOL_MILIEU = "charactercreate-customize-dropdown-linemouseover-middle"
local SURVOL_COTE = 6
local SURVOL_ALPHA, CHOISIE_ALPHA = 0.10, 0.20

-- LA FENETRE DE DETAIL, a cote de la feuille : au-dela de ses onglets
-- lateraux (55 de large, poses a +1 de son bord) et du debord de son metal.
local FENETRE_L, FENETRE_H = 400, 372
local FENETRE_X, FENETRE_Y = 76, 0
local FENETRE_NIVEAU = 10
local COIN_HAUT_GAUCHE = "ui-frame-metal-cornertopleft"
local FERMETURE = 24
local FERMETURE_X, FERMETURE_Y = 1, 0
local TITRE_Y, TITRE_L = -6, 300
local STATS_X, STATS_Y = 20, -40
local COLONNES_STATS = { 170, 222, 274, 326 }
local STATS_VALEUR_ECART = -6
local SEPARATEUR_Y = -76
local ENTETES_X, ENTETES_Y = 15, -86
local ENTETE_H = 24
local ENTETES = {
	{ texte = "NAME", largeur = 110, tri = "name" },
	{ texte = "CLASS", largeur = 80, tri = "class" },
	{ texte = "PLAYED", largeur = 55, tri = "played", triSaison = "seasonplayed" },
	{ texte = "WIN_LOSS", largeur = 75, tri = "won", triSaison = "seasonwon" },
	{ texte = "RATING", largeur = 59, tri = "rating" },
}
local LIGNES_X, LIGNES_Y = 15, -115
local LIGNE_L, LIGNE_H, LIGNE_ECART = 380, 16, 3
local AJOUTER_L, AJOUTER_H = 100, 22
local AJOUTER_X, AJOUTER_Y = 20, 16
local BASCULE = 32
local BASCULE_X, BASCULE_Y = -17, 17

local cartes, points, horsSaison, fenetre
local hote

-- --------------------------------------------------------------- les donnees

local function txt(cle, defaut)
	return _G[cle] or defaut
end

-- L'emplacement de chaque taille : l'indice de GetArenaTeam, ou nil.
local function indicesParTaille()
	local indices = {}
	for i = 1, MAX_EQUIPES do
		local nom, taille = GetArenaTeam(i)
		if nom then
			for rang, t in ipairs(TAILLES) do
				if t == taille then
					indices[rang] = i
				end
			end
		end
	end
	return indices
end

local function lireEquipe(id)
	local e = {}
	local fond, embleme, bord = {}, {}, {}
	e.nom, e.taille, e.cote, e.joues, e.victoires, e.jouesSaison,
		e.victoiresSaison, e.mesJoues, e.mesJouesSaison, e.rang, e.maCote,
		fond.r, fond.g, fond.b, e.embleme, embleme.r, embleme.g, embleme.b,
		e.bord, bord.r, bord.g, bord.b = GetArenaTeam(id)
	e.couleurFond, e.couleurEmbleme, e.couleurBord = fond, embleme, bord
	return e
end

local function pourcentage(part, total)
	if total and total ~= 0 then
		return math.floor((part / total) * 100)
	end
	return math.floor((part or 0) * 100)
end

-- ----------------------------------------------------------- les petites pieces

local function survolSur(parent)
	local survol = CreateFrame("Frame", nil, parent)
	survol:SetAllPoints(parent)
	survol:SetAlpha(0)

	local gauche = survol:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(gauche, ATLAS_SURVOL_COTE, true)
	gauche:SetWidth(SURVOL_COTE)
	gauche:SetPoint("TOPLEFT", survol, "TOPLEFT", 0, 0)
	gauche:SetPoint("BOTTOMLEFT", survol, "BOTTOMLEFT", 0, 0)

	local droite = survol:CreateTexture(nil, "BACKGROUND")
	if ForeverUI.SetAtlas(droite, ATLAS_SURVOL_COTE, true) then
		local e = ForeverUI.AtlasEntry(ATLAS_SURVOL_COTE)
		droite:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	droite:SetWidth(SURVOL_COTE)
	droite:SetPoint("TOPRIGHT", survol, "TOPRIGHT", 0, 0)
	droite:SetPoint("BOTTOMRIGHT", survol, "BOTTOMRIGHT", 0, 0)

	local milieu = survol:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(milieu, ATLAS_SURVOL_MILIEU, true)
	milieu:SetPoint("TOPLEFT", gauche, "TOPRIGHT", 0, 0)
	milieu:SetPoint("BOTTOMRIGHT", droite, "BOTTOMLEFT", 0, 0)
	return survol
end

local function texte(parent, gabarit, justif)
	local fs = parent:CreateFontString(nil, "ARTWORK", gabarit)
	if justif then
		fs:SetJustifyH(justif)
	end
	return fs
end

-- Une etiquette et sa valeur dessous, centrees sur une colonne.
local function colonne(parent, x, y, etiquette, gabaritValeur, ecart)
	local e = texte(parent, "GameFontDisableSmall", "CENTER")
	e:SetPoint("TOP", parent, "TOPLEFT", x, y)
	e:SetText(etiquette)
	local v = texte(parent, gabaritValeur or "GameFontHighlightSmall", "CENTER")
	v:SetPoint("TOP", e, "BOTTOM", 0, ecart or VALEUR_ECART)
	return e, v
end

-- UIPanelButtonTemplate de camelot : ForeverUI.CreatePanelButton (AtlasUtil).
local function boutonPanneau(parent, texteBouton, largeur, hauteur)
	return ForeverUI.CreatePanelButton(parent, texteBouton, largeur, hauteur)
end

-- Pretees au volet droit (PvPBattlegrounds.lua) : le meme survol et le meme
-- bouton de camelot.
A.survolSur = survolSur
A.boutonPanneau = boutonPanneau

-- ------------------------------------------------------------------ les cartes

local function creerCarte(bloc, rang)
	local c = CreateFrame("Button", "ForeverUIArenaTeam" .. rang, bloc)
	c:SetWidth(CARTE_L)
	c:SetHeight(CARTE_H)
	c:SetFrameLevel(bloc:GetFrameLevel() + NIVEAU)
	c:RegisterForClicks("LeftButtonUp")
	c.taille = TAILLES[rang]

	c.plaque = ForeverUI.CreateNineSlice(c, ATLAS_PLAQUE, PLAQUE_COIN,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	c.survol = survolSur(c)

	-- L'ETENDARD : la hampe, la banniere teintee, son bord et l'embleme.
	local etendard = CreateFrame("Frame", nil, c)
	etendard:SetAllPoints(c)
	c.etendard = etendard
	local hampe = etendard:CreateTexture(nil, "BACKGROUND")
	hampe:SetTexture(ELEMENTS)
	hampe:SetTexCoord(0, 0.099609375, 0.91015625, 0.935546875)
	hampe:SetWidth(HAMPE_L)
	hampe:SetHeight(HAMPE_H)
	hampe:SetPoint("TOPLEFT", c, "TOPLEFT", HAMPE_X, HAMPE_Y)
	local banniere = etendard:CreateTexture(nil, "BORDER")
	banniere:SetWidth(BANNIERE_L)
	banniere:SetHeight(BANNIERE_H)
	banniere:SetPoint("TOP", hampe, "TOP", BANNIERE_X, BANNIERE_Y)
	local bord = etendard:CreateTexture(nil, "ARTWORK")
	bord:SetWidth(BANNIERE_L)
	bord:SetHeight(BANNIERE_H)
	bord:SetPoint("CENTER", banniere, "CENTER", 0, 0)
	local embleme = etendard:CreateTexture(nil, "OVERLAY")
	embleme:SetWidth(EMBLEME)
	embleme:SetHeight(EMBLEME)
	embleme:SetPoint("CENTER", bord, "CENTER", EMBLEME_X, EMBLEME_Y)
	c.banniere, c.bord, c.embleme = banniere, bord, embleme

	-- LES DONNEES, dans un cadre a part : l'emplacement vide les cache d'un
	-- geste, comme PVPTeam<n>Data.
	local d = CreateFrame("Frame", nil, c)
	d:SetAllPoints(c)
	c.donnees = d
	d.nom = texte(d, "GameFontNormal", "LEFT")
	d.nom:SetWidth(NOM_L)
	d.nom:SetPoint("TOPLEFT", c, "TOPLEFT", TEXTE_X, NOM_Y)
	d.cote = texte(d, "GameFontNormalSmall", "RIGHT")
	d.cote:SetPoint("TOPRIGHT", c, "TOPRIGHT", COTE_X, COTE_Y)
	d.coteEtiquette = texte(d, "GameFontDisableSmall", "RIGHT")
	d.coteEtiquette:SetPoint("RIGHT", d.cote, "LEFT", -4, 0)
	d.coteEtiquette:SetText(txt("ARENA_TEAM_RATING", "Team Rating"))
	d.type = texte(d, "GameFontHighlightSmall", "LEFT")
	d.type:SetPoint("TOPLEFT", c, "TOPLEFT", TEXTE_X, TYPE_Y)
	d.jeuxEtiquette, d.jeux = colonne(d, COLONNES_CARTE.jeux, ETIQUETTES_Y, txt("GAMES", "Games"))
	d.bilanEtiquette, d.bilan = colonne(d, COLONNES_CARTE.bilan, ETIQUETTES_Y, txt("WIN_LOSS", "Win - Loss"))
	d.jouesEtiquette, d.joues = colonne(d, COLONNES_CARTE.joues, ETIQUETTES_Y, txt("PLAYED", "Played"))

	-- L'emplacement vide : "(2v2)", en GameFontDisableLarge.
	c.vide = c:CreateFontString(nil, "ARTWORK", "GameFontDisableLarge")
	c.vide:SetPoint("CENTER", c, "CENTER", 0, 0)
	c.vide:Hide()

	c:SetScript("OnEnter", function(self)
		if not self.choisie then
			self.survol:SetAlpha(self.equipe and SURVOL_ALPHA or 0)
		end
		if GameTooltip_AddNewbieTip then
			GameTooltip_AddNewbieTip(self, txt("ARENA_TEAM", "Arena Team"), 1.0, 1.0, 1.0,
				self.equipe and txt("CLICK_FOR_DETAILS", "") or txt("ARENA_TEAM_LEAD_IN", ""), 1)
		end
	end)
	c:SetScript("OnLeave", function(self)
		if not self.choisie then
			self.survol:SetAlpha(0)
		end
		if GameTooltip then
			GameTooltip:Hide()
		end
	end)
	c:SetScript("OnClick", function(self)
		A.basculer(self.equipe)
	end)
	return c
end

local function remplirCarte(c, id)
	c.equipe = id
	local d = c.donnees
	if not id then
		c:SetID(0)
		c:SetAlpha(0.4)
		c.banniere:SetTexture(PVP .. "PVP-Banner-" .. c.taille)
		c.banniere:SetVertexColor(1, 1, 1)
		c.etendard:SetAlpha(0.1)
		c.bord:Hide()
		c.embleme:Hide()
		d:Hide()
		c.vide:SetText(string.format(txt("PVP_TEAMSIZE", "(%dv%d)"), c.taille, c.taille))
		c.vide:Show()
		return
	end

	local e = lireEquipe(id)
	c:SetID(id)
	c:SetAlpha(1)
	c.etendard:SetAlpha(1)

	-- PVPTeam_Update : la semaine seulement (voir l'en-tete).
	local joues, victoires, mesJoues = e.joues or 0, e.victoires or 0, e.mesJoues or 0
	local pct = pourcentage(mesJoues, joues)
	d.nom:SetText(e.nom)
	d.cote:SetText(e.cote)
	d.type:SetText(txt("ARENA_THIS_WEEK", "This Week"))
	d.jeux:SetText(joues)
	d.bilan:SetText(tostring(victoires) .. " - " .. tostring(joues - victoires))
	d.joues:SetText(tostring(mesJoues) .. " (" .. string.format("%d", pct) .. "%)")
	if pct < 10 then
		d.joues:SetVertexColor(1.0, 0, 0)
	else
		d.joues:SetVertexColor(1.0, 1.0, 1.0)
	end

	c.banniere:SetTexture(PVP .. "PVP-Banner-" .. tostring(e.taille))
	c.banniere:SetVertexColor(e.couleurFond.r or 1, e.couleurFond.g or 1, e.couleurFond.b or 1)
	c.bord:SetVertexColor(e.couleurBord.r or 1, e.couleurBord.g or 1, e.couleurBord.b or 1)
	c.embleme:SetVertexColor(e.couleurEmbleme.r or 1, e.couleurEmbleme.g or 1, e.couleurEmbleme.b or 1)
	if e.bord and e.bord ~= -1 then
		c.bord:SetTexture(PVP .. "PVP-Banner-" .. tostring(e.taille) .. "-Border-" .. tostring(e.bord))
	end
	if e.embleme and e.embleme ~= -1 then
		c.embleme:SetTexture(PVP .. "Icons" .. SEP .. "PVP-Banner-Emblem-" .. tostring(e.embleme))
	end
	c.bord:Show()
	c.embleme:Show()
	d:Show()
	c.vide:Hide()
end

local function marquerCartes()
	if not cartes then
		return
	end
	local ouverte = fenetre and fenetre:IsShown() and fenetre.equipe
	for _, c in ipairs(cartes) do
		local avant = c.choisie
		c.choisie = (c.equipe ~= nil and c.equipe == ouverte) or nil
		if c.choisie then
			c.survol:SetAlpha(CHOISIE_ALPHA)
		elseif avant then
			c.survol:SetAlpha(0)
		end
	end
end

local function majPoints()
	if not points then
		return
	end
	points.valeur:SetText(GetArenaCurrency and GetArenaCurrency() or 0)
	-- La ligne se centre sur le volet : sa largeur est celle de ce qu'elle
	-- porte.
	local largeur = points.etiquette:GetStringWidth() + POINTS_ECART
		+ points.valeur:GetStringWidth() + ICONE_ECART + ICONE_L
	points:SetWidth(math.max(1, largeur))
end

function A.maj()
	if not cartes then
		return
	end
	local saison = GetCurrentArenaSeason and GetCurrentArenaSeason() or 0
	if saison == 0 then
		for _, c in ipairs(cartes) do
			c:Hide()
		end
		local precedente = GetPreviousArenaSeason and GetPreviousArenaSeason() or 0
		horsSaison:SetText(string.format(txt("ARENA_OFF_SEASON_TEXT", "%d %d"),
			precedente, precedente + 1))
		horsSaison:Show()
	else
		horsSaison:Hide()
		local indices = indicesParTaille()
		for rang, c in ipairs(cartes) do
			remplirCarte(c, indices[rang])
			c:Show()
		end
	end
	majPoints()
	marquerCartes()
end

-- -------------------------------------------------------- la fenetre de detail

-- Le cadre du client, tenu a jour pour UnitPopup et ADD_TEAMMEMBER.
local function preter(id)
	local client = _G["PVPTeamDetails"]
	if not client then
		return
	end
	client.team = id
	if id then
		client:Show()
	else
		client:Hide()
	end
end

local function croixRouge(parent)
	local b = CreateFrame("Button", nil, parent)
	b:SetWidth(FERMETURE)
	b:SetHeight(FERMETURE)
	for _, etat in ipairs({
		{ "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
		{ "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
		{ "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
	}) do
		local e = ForeverUI.AtlasEntry(etat[3])
		b[etat[1]](b, e and e[1] or "")
		local t = b[etat[2]](b)
		if t then
			ForeverUI.SetAtlas(t, etat[3], true)
			t:ClearAllPoints()
			t:SetAllPoints(b)
			if etat[3] == "redbutton-highlight" then
				t:SetBlendMode("ADD")
			end
		end
	end
	b:SetScript("OnClick", function() parent:Hide() end)
	return b
end

local function creerEntete(f, n, precedent)
	local def = ENTETES[n]
	local b = CreateFrame("Button", "ForeverUIArenaTeamDetailsHeader" .. n, f)
	b:SetHeight(ENTETE_H)
	b:SetWidth(def.largeur)
	if precedent then
		b:SetPoint("LEFT", precedent, "RIGHT", -2, 0)
	else
		b:SetPoint("TOPLEFT", f, "TOPLEFT", ENTETES_X, ENTETES_Y)
	end
	-- WhoFrameColumn_SetWidth : le milieu prend la largeur moins les bouts.
	local g = b:CreateTexture(nil, "BACKGROUND")
	g:SetTexture(ONGLETS_COLONNE)
	g:SetTexCoord(0, 0.078125, 0, 0.75)
	g:SetWidth(5)
	g:SetHeight(ENTETE_H)
	g:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	local m = b:CreateTexture(nil, "BACKGROUND")
	m:SetTexture(ONGLETS_COLONNE)
	m:SetTexCoord(0.078125, 0.90625, 0, 0.75)
	m:SetWidth(def.largeur - 9)
	m:SetHeight(ENTETE_H)
	m:SetPoint("LEFT", g, "RIGHT", 0, 0)
	local d = b:CreateTexture(nil, "BACKGROUND")
	d:SetTexture(ONGLETS_COLONNE)
	d:SetTexCoord(0.90625, 0.96875, 0, 0.75)
	d:SetWidth(4)
	d:SetHeight(ENTETE_H)
	d:SetPoint("LEFT", m, "RIGHT", 0, 0)
	local fs = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	fs:SetPoint("CENTER", m, "CENTER", 0, 0)
	b:SetFontString(fs)
	b:SetText(txt(def.texte, def.texte))
	b:SetHighlightTexture(SURBRILLANCE_COLONNE)
	local s = b:GetHighlightTexture()
	if s then
		s:SetBlendMode("ADD")
		s:ClearAllPoints()
		s:SetPoint("TOPLEFT", g, "TOPLEFT", -2, 5)
		s:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 2, -7)
	end
	b.def = def
	b:SetScript("OnClick", function(self)
		local tri = (fenetre.saison and self.def.triSaison) or self.def.tri
		if tri and SortArenaTeamRoster then
			SortArenaTeamRoster(tri)
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	return b
end

-- Une cellule de la ligne : une FontString posee a sa place. La cellule
-- "joues" est un cadre, pour porter son infobulle.
local function creerLigne(f, n)
	local l = CreateFrame("Button", "ForeverUIArenaTeamDetailsRow" .. n, f)
	l:SetWidth(LIGNE_L)
	l:SetHeight(LIGNE_H)
	l:SetPoint("TOPLEFT", f, "TOPLEFT", LIGNES_X, LIGNES_Y - (n - 1) * (LIGNE_H + LIGNE_ECART))
	l:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	l.survol = survolSur(l)

	local function cellule(x, largeur, gabarit, justif)
		local fs = texte(l, gabarit, justif)
		fs:SetWidth(largeur)
		fs:SetHeight(14)
		fs:SetPoint("TOPLEFT", l, "TOPLEFT", x, -1)
		return fs
	end
	-- nom 104 a 10 ; classe 73 a +4 ; joues 45 a +4 ; bilan 72 a +0 ;
	-- cote 54 a +4 (PVPTeamMemberButtonTemplate)
	l.nom = cellule(10, 104, "GameFontNormalSmall", "LEFT")
	l.classe = cellule(118, 70, "GameFontNormalSmall", "LEFT")
	local joues = CreateFrame("Frame", nil, l)
	joues:SetWidth(45)
	joues:SetHeight(14)
	joues:SetPoint("TOPLEFT", l, "TOPLEFT", 195, -1)
	joues:EnableMouse(true)
	l.jouesCadre = joues
	l.joues = texte(joues, "GameFontNormalSmall", "CENTER")
	l.joues:SetAllPoints(joues)
	l.victoires = cellule(240, 30, "GameFontHighlightSmall", "RIGHT")
	l.tiret = cellule(269, 12, "GameFontHighlightSmall", "LEFT")
	l.tiret:SetText(" - ")
	l.defaites = cellule(281, 30, "GameFontHighlightSmall", "LEFT")
	l.cote = cellule(316, 54, "GameFontNormalSmall", "CENTER")

	local function allumer(self)
		if not l.choisie then
			l.survol:SetAlpha(SURVOL_ALPHA)
		end
	end
	local function eteindre(self)
		if not l.choisie then
			l.survol:SetAlpha(0)
		end
	end
	l:SetScript("OnEnter", allumer)
	l:SetScript("OnLeave", eteindre)
	joues:SetScript("OnEnter", function(self)
		allumer()
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		if l.pct then
			GameTooltip:SetText(l.pct)
		end
	end)
	joues:SetScript("OnLeave", function()
		eteindre()
		GameTooltip:Hide()
	end)

	-- PVPTeamDetailsButton_OnClick
	l:SetScript("OnClick", function(self, bouton)
		if bouton == "RightButton" then
			local nom, _, _, _, enLigne = GetArenaTeamRosterInfo(fenetre.equipe, self.membre)
			if PVPFrame_ShowDropdown then
				PVPFrame_ShowDropdown(nom, enLigne)
			end
		else
			SetArenaTeamRosterSelection(fenetre.equipe, self.membre)
			A.majDetail()
		end
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	return l
end

local function creerFenetre(bloc)
	local f = CreateFrame("Frame", "ForeverUIArenaTeamDetails", bloc)
	f:SetWidth(FENETRE_L)
	f:SetHeight(FENETRE_H)
	f:SetPoint("TOPLEFT", _G["CharacterFrame"] or hote, "TOPRIGHT", FENETRE_X, FENETRE_Y)
	f:SetFrameLevel(bloc:GetFrameLevel() + FENETRE_NIVEAU)
	f:EnableMouse(true)
	f:Hide()
	ForeverUI.SetPanelArt(f, { coinHautGauche = COIN_HAUT_GAUCHE, niveau = 5 })
	local metal = f.foreverHabillage or f

	-- le titre dans la barre de metal : le nom, puis la taille
	local bandeau = CreateFrame("Frame", nil, f)
	bandeau:SetAllPoints(f)
	bandeau:SetFrameLevel(metal:GetFrameLevel() + 1)
	f.titre = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	f.titre:SetPoint("TOP", f, "TOP", 0, TITRE_Y)
	f.titre:SetWidth(TITRE_L)

	f.fermer = croixRouge(f)
	f.fermer:SetFrameLevel(metal:GetFrameLevel() + 2)
	f.fermer:SetPoint("TOPRIGHT", f, "TOPRIGHT", FERMETURE_X, FERMETURE_Y)

	-- l'en-tete des statistiques
	f.type = texte(f, "GameFontHighlightSmall", "LEFT")
	f.type:SetPoint("TOPLEFT", f, "TOPLEFT", STATS_X, STATS_Y - 8)
	local _
	_, f.jeux = colonne(f, COLONNES_STATS[1], STATS_Y, txt("GAMES", "Games"), nil, STATS_VALEUR_ECART)
	_, f.bilan = colonne(f, COLONNES_STATS[2], STATS_Y, txt("WIN_LOSS", "Win - Loss"), nil, STATS_VALEUR_ECART)
	_, f.rang = colonne(f, COLONNES_STATS[3], STATS_Y, txt("RANK", "Rank"), nil, STATS_VALEUR_ECART)
	_, f.cote = colonne(f, COLONNES_STATS[4], STATS_Y, txt("ARENA_TEAM_RATING", "Team Rating"),
		"GameFontNormalSmall", STATS_VALEUR_ECART)

	local trait = f:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(trait, "ui-character-info-scrollline-long")
	trait:SetHeight(3)
	trait:SetPoint("TOPLEFT", f, "TOPLEFT", ENTETES_X, SEPARATEUR_Y)
	trait:SetPoint("TOPRIGHT", f, "TOPRIGHT", -ENTETES_X, SEPARATEUR_Y)

	f.entetes = {}
	local precedent
	for n = 1, #ENTETES do
		precedent = creerEntete(f, n, precedent)
		f.entetes[n] = precedent
	end
	f.lignes = {}
	for n = 1, MAX_MEMBRES do
		f.lignes[n] = creerLigne(f, n)
	end

	f.ajouter = boutonPanneau(f, txt("ADDMEMBER_TEAM", "Add Member"), AJOUTER_L, AJOUTER_H)
	f.ajouter:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", AJOUTER_X, AJOUTER_Y)
	f.ajouter:SetScript("OnClick", function()
		StaticPopup_Show("ADD_TEAMMEMBER")
	end)
	f.ajouter:SetScript("OnEnter", function(self)
		if GameTooltip_AddNewbieTip then
			GameTooltip_AddNewbieTip(self, txt("ADDMEMBER", "Add Member"), 1.0, 1.0, 1.0,
				txt("NEWBIE_TOOLTIP_ADDTEAMMEMBER", ""), 1)
		end
	end)
	f.ajouter:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- la bascule semaine / saison : la fleche du grimoire, son texte a gauche
	local bascule = CreateFrame("Button", "ForeverUIArenaTeamDetailsToggle", f)
	bascule:SetWidth(BASCULE)
	bascule:SetHeight(BASCULE)
	bascule:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", BASCULE_X, BASCULE_Y)
	bascule:SetNormalTexture(FLECHE .. "Up")
	bascule:SetPushedTexture(FLECHE .. "Down")
	bascule:SetHighlightTexture(SURVOL_CARRE)
	local s = bascule:GetHighlightTexture()
	if s then
		s:SetBlendMode("ADD")
	end
	bascule.texte = texte(bascule, "GameFontNormalSmall", "RIGHT")
	bascule.texte:SetWidth(180)
	bascule.texte:SetPoint("RIGHT", bascule, "LEFT", 0, 0)
	bascule:SetScript("OnClick", function()
		f.saison = not f.saison or nil
		A.majDetail()
		PlaySound("igMainMenuOptionCheckBoxOn")
	end)
	f.bascule = bascule

	f:SetScript("OnShow", function()
		PlaySound("igSpellBookOpen")
	end)
	-- PVPTeamDetails_OnHide, et PVPFrame_OnHide : quitter l'onglet referme
	-- le detail -- il ne revient pas tout seul au retour.
	f:SetScript("OnHide", function(self)
		if self.equipe then
			self.equipe = nil
			CloseArenaTeamRoster()
			preter(nil)
			PlaySound("igSpellBookClose")
		end
		if self:IsShown() then
			self:Hide()
		end
		marquerCartes()
	end)
	return f
end

-- PVPTeamDetails_Update
function A.majDetail()
	local f = fenetre
	if not f or not f.equipe then
		return
	end
	local id = f.equipe
	local e = lireEquipe(id)
	if not e.nom then
		f:Hide()
		return
	end

	f.titre:SetText(tostring(e.nom) .. " |cffffffff"
		.. string.format(txt("PVP_TEAMSIZE", "(%dv%d)"), e.taille, e.taille) .. "|r")
	f.rang:SetText(e.rang)
	f.cote:SetText(e.cote)

	local jouesEquipe, victoires
	if f.saison then
		jouesEquipe, victoires = e.jouesSaison or 0, e.victoiresSaison or 0
		f.type:SetText(string.upper(txt("ARENA_THIS_SEASON", "This Season")))
		f.bascule.texte:SetText(txt("ARENA_THIS_WEEK_TOGGLE", ""))
	else
		jouesEquipe, victoires = e.joues or 0, e.victoires or 0
		f.type:SetText(string.upper(txt("ARENA_THIS_WEEK", "This Week")))
		f.bascule.texte:SetText(txt("ARENA_THIS_SEASON_TOGGLE", ""))
	end
	f.jeux:SetText(jouesEquipe)
	f.bilan:SetText(tostring(victoires) .. " - " .. tostring(jouesEquipe - victoires))

	local nombre = GetNumArenaTeamMembers(id, 1) or 0
	local choisi = GetArenaTeamRosterSelection and GetArenaTeamRosterSelection(id)
	for n, l in ipairs(f.lignes) do
		if n > nombre then
			l:Hide()
		else
			local nom, rang, niveau, classe, enLigne, joues, gagnes, jouesSaison,
				gagnesSaison, cote = GetArenaTeamRosterInfo(id, n)
			local valeurJoues, valeurGagnes = joues or 0, gagnes or 0
			if f.saison then
				valeurJoues, valeurGagnes = jouesSaison or 0, gagnesSaison or 0
			end
			local pct = pourcentage(valeurJoues, jouesEquipe)
			l.membre = n
			l.pct = string.format("%d", pct) .. "%"
			l.nom:SetText(nom)
			l.classe:SetText(classe)
			l.joues:SetText(valeurJoues)
			l.victoires:SetText(valeurGagnes)
			l.defaites:SetText(valeurJoues - valeurGagnes)
			l.cote:SetText(cote)

			-- blanc en ligne, or pour le capitaine, gris hors ligne
			local r, v, b = 0.5, 0.5, 0.5
			if enLigne then
				if rang and rang > 0 then
					r, v, b = 1.0, 1.0, 1.0
				else
					r, v, b = 1.0, 0.82, 0.0
				end
			end
			for _, fs in ipairs({ l.nom, l.classe, l.joues, l.victoires, l.tiret, l.defaites, l.cote }) do
				fs:SetTextColor(r, v, b)
			end
			-- PVPTeamDetails_Update pose le rouge PAR-DESSUS, en teinte
			if pct < 10 then
				l.joues:SetVertexColor(1.0, 0, 0)
			else
				l.joues:SetVertexColor(1.0, 1.0, 1.0)
			end

			l.choisie = (choisi == n) or nil
			l.survol:SetAlpha(l.choisie and CHOISIE_ALPHA or 0)
			l:Show()
		end
	end
end

-- PVPTeam_OnClick : ouvrir le detail d'une equipe, ou le refermer si c'est
-- deja elle.
function A.basculer(id)
	if not id or not fenetre or not GetArenaTeam(id) then
		return
	end
	if fenetre:IsShown() and fenetre.equipe == id then
		fenetre:Hide()
		return
	end
	if fenetre.equipe and fenetre.equipe ~= id then
		CloseArenaTeamRoster()
	end
	fenetre.equipe = id
	preter(id)
	ArenaTeamRoster(id)
	fenetre:Show()
	A.majDetail()
	marquerCartes()
end

-- ------------------------------------------------------------ la construction

function A.monter(bloc, volet)
	if cartes or not bloc or not volet then
		return
	end
	hote = volet

	-- LE SEPARATEUR, sous le compteur de victoires, A LA TAILLE DE SON
	-- ELEMENT (384 x 8). Pose avec keepSize, il n'en avait aucune et prenait
	-- celle de la feuille d'atlas entiere : une texture immense.
	local separateur = bloc:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(separateur, ATLAS_SEPARATEUR)
	separateur:SetPoint("TOP", bloc.progres, "BOTTOM", 0, SEPARATEUR_SOUS_COMPTEUR)
	A.separateur = separateur

	-- LES POINTS D'ARENE, centres sous le separateur.
	points = CreateFrame("Frame", "ForeverUIArenaPoints", bloc)
	points:SetHeight(ICONE_H)
	points:SetFrameLevel(bloc:GetFrameLevel() + NIVEAU)
	points:EnableMouse(true)
	points.etiquette = texte(points, "GameFontHighlightSmall", "LEFT")
	points.etiquette:SetPoint("LEFT", points, "LEFT", 0, 0)
	points.etiquette:SetText(txt("PVP_LABEL_ARENA", "ARENA:"))
	points.valeur = texte(points, "GameFontNormal", "RIGHT")
	points.valeur:SetPoint("LEFT", points.etiquette, "RIGHT", POINTS_ECART, 0)
	points.icone = points:CreateTexture(nil, "ARTWORK")
	points.icone:SetTexture(ICONE_POINTS)
	points.icone:SetWidth(ICONE_L)
	points.icone:SetHeight(ICONE_H)
	points.icone:SetPoint("LEFT", points.valeur, "RIGHT", ICONE_ECART, 0)
	points:SetScript("OnEnter", function(self)
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetText(txt("ARENA_POINTS", "Arena Points"), 1.0, 1.0, 1.0)
		GameTooltip:AddLine(txt("TOOLTIP_ARENA_POINTS", ""), nil, nil, nil, 1)
		GameTooltip:Show()
	end)
	points:SetScript("OnLeave", function() GameTooltip:Hide() end)

	-- LA LISTE DES EQUIPES, sous les points.
	cartes = {}
	for rang = 1, MAX_EQUIPES do
		cartes[rang] = creerCarte(bloc, rang)
	end
	-- empilees depuis le bas du volet, centrees
	for rang = MAX_EQUIPES, 1, -1 do
		if rang == MAX_EQUIPES then
			cartes[rang]:SetPoint("BOTTOM", hote, "BOTTOM", 0, CARTES_BAS)
		else
			cartes[rang]:SetPoint("BOTTOM", cartes[rang + 1], "TOP", 0, CARTE_ECART)
		end
	end

	-- LES POINTS D'ARENE, CENTRES ENTRE LE SEPARATEUR ET LA PREMIERE CARTE
	-- (demande du 2026-09-26). Une zone sans souris couvre l'intervalle ; la
	-- ligne se centre sur elle, et garde sa petite surface pour l'infobulle.
	local zone = CreateFrame("Frame", "ForeverUIArenaPointsZone", bloc)
	zone:SetPoint("TOP", separateur, "BOTTOM", 0, 0)
	zone:SetPoint("BOTTOM", cartes[1], "TOP", 0, 0)
	zone:SetWidth(CARTE_L)
	points:SetPoint("CENTER", zone, "CENTER", 0, 0)

	horsSaison = bloc:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	horsSaison:SetJustifyH("LEFT")
	horsSaison:SetWidth(CARTE_L - 16)
	horsSaison:SetPoint("TOP", points, "BOTTOM", 0, HORS_SAISON_SOUS_POINTS)
	horsSaison:Hide()

	fenetre = creerFenetre(bloc)
	A.maj()
end

-- CE QUI FAIT BOUGER LES EQUIPES. PVPFrame_OnEvent, relu : ARENA_TEAM_UPDATE
-- refait les cartes et le detail (ou le ferme si l'equipe n'est plus) ;
-- ARENA_TEAM_ROSTER_UPDATE avec un argument redemande la liste, sans
-- argument la liste est la. PVPFrame, qui ecoute toujours, redemande deja
-- pour PVPTeamDetails ; on ne le fait nous-memes que s'il manque.
local veilleur = CreateFrame("Frame")
veilleur:RegisterEvent("ARENA_TEAM_UPDATE")
veilleur:RegisterEvent("ARENA_TEAM_ROSTER_UPDATE")
veilleur:RegisterEvent("HONOR_CURRENCY_UPDATE")
veilleur:SetScript("OnEvent", function(self, evenement, arg1)
	if not cartes then
		return
	end
	if evenement == "ARENA_TEAM_ROSTER_UPDATE" then
		if arg1 then
			if fenetre:IsShown() and fenetre.equipe and not _G["PVPTeamDetails"] then
				ArenaTeamRoster(fenetre.equipe)
			end
		else
			A.majDetail()
			A.maj()
		end
		return
	end
	A.maj()
	if evenement == "ARENA_TEAM_UPDATE" and fenetre:IsShown() then
		if fenetre.equipe and not GetArenaTeam(fenetre.equipe) then
			fenetre:Hide()
		else
			A.majDetail()
		end
	end
end)

-- TEMOIN -- /fui arene. Ce que le client rend pour les trois emplacements.
function ForeverUI.PvPArenaDebug()
	local dire = function(t)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t)
	end
	dire(string.format("saison %s (precedente %s) | points d'arene %s",
		tostring(GetCurrentArenaSeason and GetCurrentArenaSeason()),
		tostring(GetPreviousArenaSeason and GetPreviousArenaSeason()),
		tostring(GetArenaCurrency and GetArenaCurrency())))
	for i = 1, MAX_EQUIPES do
		local e = lireEquipe(i)
		if e.nom then
			dire(string.format("equipe %d : %s (%dv%d) cote %s | semaine %s/%s, moi %s"
				.. " | saison %s/%s | banniere bord %s embleme %s",
				i, e.nom, e.taille or 0, e.taille or 0, tostring(e.cote),
				tostring(e.victoires), tostring(e.joues), tostring(e.mesJoues),
				tostring(e.victoiresSaison), tostring(e.jouesSaison),
				tostring(e.bord), tostring(e.embleme)))
		else
			dire(string.format("equipe %d : aucune", i))
		end
	end
	if fenetre then
		dire(string.format("detail : ouvert=%s equipe=%s saison=%s",
			tostring(fenetre:IsShown()), tostring(fenetre.equipe), tostring(fenetre.saison)))
	end
end
