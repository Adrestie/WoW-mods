-- ForeverUI : le raid compact (etape 2 du chantier des groupes, memoire
-- foreverui-groupes).
--
-- RELEVE -- camelot : blizzard_unitframe/shared/compactunitframe.*,
-- compactraidgroup.*, blizzard_compactraidframes (conteneur),
-- blizzard_privateaurasui (auras), editmodepresetlayouts (tailles). Valeurs
-- du code, pas d'estimation.
--   cadre       98 x 44 (Mode Edition : largeur 72 + 26, hauteur 36 + 8) ;
--               componentScale = min(44 / 36, 98 / 72) = 1,2222
--   fond        raidframe-hp-bg-white, tout le cadre, teinte du fond
--   vie         RaidFrame-Hp-Fill de (1, -1) a (-1, 1 + 8), couleur de classe ;
--               grise (0,5) si deconnecte
--   ressource   8 de haut sous la vie jusqu'a (-1, 1) : _RaidFrame-Resource-Fill
--               sur _RaidFrame-Resource-Background, couleur PowerBarColor
--   nom         GameFontHighlightSmall, TOPLEFT sur le TOPRIGHT du role (0, -1)
--               jusqu'a TOPRIGHT (-3, -3), a gauche, blanc
--   role        17 x 17 a (3, -2) : vehicule, tank / assistant principal
--               (RaidFrame-Icon-MainTank / -MainAssist), ou le role de groupe
--               (UI-LFG-RoleIcon-*-Micro-GroupFinder) ; cache, il garde 1 de
--               large et le nom se colle a gauche
--   statut      GameFontDisable a 12 x 1,2222 : BOTTOMLEFT (3, 44/3 - 2) et
--               BOTTOMRIGHT (-3, idem) ; PLAYER_OFFLINE, DEAD
--   appel       20 x 1,2222 a BOTTOM (0, 44/3 - 4), UI-LFG-*Mark-Raid ; en
--               attente a la fin -> pas pret ; efface apres 11 s
--   menace      RaidFrame-AgroFrame sur tout le cadre, teinte de la menace
--   cible       RaidFrame-TargetFrame sur tout le cadre, blanc
--   portee      hors de portee (UnitInRange) : alpha 0,5, sauf cible et appel
--   auras       6 buffs et 5 affaiblissements de 11, grilles de 3 : buffs de
--               BOTTOMRIGHT (-3, 2 + 8) vers la gauche puis le haut,
--               affaiblissements de BOTTOMLEFT (3, 2 + 8) vers la droite puis
--               le haut ; 3 icones de dissipation 14 x 14 de TOPRIGHT (-3, -2)
--               vers la gauche ; bordure d'affaiblissement
--               ui-debuff-border-<type>-noicon, 11 + 5 ; pile NumberFontNormal
--               BOTTOMRIGHT (-2, 2) ; recharge inversee
--   dissipation calque sur le cadre : RaidFrame-Dispel-Fill a 0,2, degrade
--               _RaidFrame-Dispel-Highlight-Horizontal, bord
--               RaidFrame-DispelHighlight, teinte du type ; les auras s'ecartent
--               de 2 quand il est visible
--   groupes     separes, verticaux : titre de 14, cinq cadres colles, groupes
--               en colonnes collees de gauche a droite, seulement ceux qui ont
--               des membres ; conteneur sur le TOPRIGHT du gestionnaire plie
--               (0, -5), soit (22, -145) sur l'ecran
--   visible     en raid
--
-- CE QUE 3.3.5 NE SAIT PAS FAIRE, ET CE QUI LE REMPLACE :
--   * pas de prediction de soins ni d'absorptions, ni phase, ni invocation,
--     ni resurrection entrante (l'icone du centre) ;
--   * pas d'indicateur d'affaiblissement de boss (UnitAura ne le dit pas) :
--     tous en 11 ;
--   * les buffs de camelot (lances par le joueur, qu'il peut appliquer) : ici
--     le filtre "PLAYER" -- ceux que le joueur a lances ;
--   * pas d'ignoreParentAlpha : la portee estompe les elements un par un, la
--     cible et l'appel restent pleins ;
--   * GROUP_NUMBER n'existe pas dans la langue du client : le titre dit
--     GROUP suivi du numero ;
--   * les couleurs de fond, de menace et des types (constantes du client
--     moderne, absentes du relevé) : fond (0,1 ; 0,1 ; 0,1) -- A VERIFIER en
--     jeu --, menace GetThreatStatusColor, types DebuffTypeColor du client ;
--   * les contours (menace, cible, dissipation) sont decoupes en neuf, coins
--     de 10 ou 2 mesures sur l'art : etires d'un bloc, leurs bords
--     s'epaississaient.
--
-- SECURITE. Huit en-tetes SecureRaidGroupHeaderTemplate (un par groupe)
-- placent les joueurs, meme en combat. Leurs cinq boutons sont crees d'avance,
-- hors combat (startingIndex a -4 un instant) : aucun n'est cree en combat. Le
-- tassement des groupes (sans trou) se fait hors combat ; en combat, un groupe
-- qui se remplit apparait a sa place d'attente, au bout. L'addon HD "Compact
-- Raid Frames" est desactive (decision de l'utilisateur, 2026-09-26) et ses
-- cadres caches.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local SEP = string.char(92)
local LFG = "Interface" .. SEP .. "ForeverUI" .. SEP .. "lfgframe" .. SEP

local P = {
	largeur = 98, hauteur = 44, titreH = 14, groupes = 8, parGroupe = 5,
	x = 22, y = -145,
	ressourceH = 8, basAura = 2, aura = 11, auraBordure = 5, dissipation = 14,
	buffs = 6, affaiblissements = 5, dissipations = 3, parLigne = 3, ecartDissipation = 2,
	role = 17, appel = 20, statut = 12, finAppel = 11,
	fond = { 0.1, 0.1, 0.1 },
	coinMenace = 10, coinCible = 10, coinDissipation = 2,
	portee = 0.5, periodePortee = 0.5,
	marques = {
		ready = LFG .. "ui-lfg-readymark-raid",
		notready = LFG .. "ui-lfg-declinemark-raid",
		waiting = LFG .. "ui-lfg-pendingmark-raid",
	},
	roles = {
		TANK = LFG .. "ui-lfg-roleicon-tank-micro-groupfinder",
		HEALER = LFG .. "ui-lfg-roleicon-healer-micro-groupfinder",
		DAMAGER = LFG .. "ui-lfg-roleicon-dps-micro-groupfinder",
	},
	bordures = { Magic = "magic", Curse = "curse", Disease = "disease", Poison = "poison" },
}
P.echelle = math.min(P.hauteur / 36, P.largeur / 72)

local R = { boutons = {} }
ForeverUI.RaidFrame = R

-- ----------------------------------------------------------------- les pieces

local function montrer(tranches, oui)
	for _, t in ipairs(tranches) do
		if oui then t:Show() else t:Hide() end
	end
end

local function teinter(tranches, r, g, b)
	for _, t in ipairs(tranches) do t:SetVertexColor(r, g, b) end
end

-- une barre : la texture, rognee a la fraction, sur la largeur pleine
local function remplir(tex, fraction, pleine)
	if not fraction or fraction ~= fraction or fraction < 0 then fraction = 0 end
	if fraction > 1 then fraction = 1 end
	local largeur = pleine * fraction
	if largeur < 0.5 then
		tex:Hide()
		return
	end
	tex:SetWidth(largeur)
	tex:SetTexCoord(tex.u1, tex.u1 + (tex.u2 - tex.u1) * fraction, tex.v1, tex.v2)
	tex:Show()
end

local function barre(parent, couche, atlas)
	local t = parent:CreateTexture(nil, couche)
	local e = ForeverUI.AtlasEntry(atlas)
	t:SetTexture(e[1])
	t.u1, t.u2, t.v1, t.v2 = e[2], e[3], e[4], e[5]
	return t
end

local function creerAura(parent, cote, bordure)
	local a = CreateFrame("Frame", nil, parent)
	a:SetWidth(cote)
	a:SetHeight(cote)
	a:EnableMouse(false)
	a.icone = a:CreateTexture(nil, "ARTWORK")
	a.icone:SetAllPoints(a)
	if bordure then
		a.bordure = a:CreateTexture(nil, "OVERLAY")
		a.bordure:SetWidth(cote + P.auraBordure)
		a.bordure:SetHeight(cote + P.auraBordure)
		a.bordure:SetPoint("CENTER", a, "CENTER", 0, 0)
	end
	a.recharge = CreateFrame("Cooldown", nil, a)
	a.recharge:SetReverse(true)
	a.recharge:SetPoint("TOPLEFT", a, "TOPLEFT", 0, -1)
	a.recharge:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", 0, -1)
	a.pile = a:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	a.pile:SetPoint("BOTTOMRIGHT", a, "BOTTOMRIGHT", -2, 2)
	a:Hide()
	return a
end

-- les grilles de 3 (AnchorUtil.CreateGridLayout) : k-ieme case depuis le coin
local function placerGrille(auras, coin, sensX, x, y, cote)
	for k, a in ipairs(auras) do
		local col, lig = (k - 1) % P.parLigne, math.floor((k - 1) / P.parLigne)
		a:ClearAllPoints()
		a:SetPoint(coin, a:GetParent(), coin, x + sensX * col * cote, y + lig * cote)
	end
end

-- -------------------------------------------------------- le cadre d'un joueur

local function construireBouton(f)
	f.fond = f:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(f.fond, "raidframe-hp-bg-white", true)
	f.fond:SetAllPoints(f)
	f.fond:SetVertexColor(P.fond[1], P.fond[2], P.fond[3])

	f.vie = barre(f, "BORDER", "raidframe-hp-fill")
	f.vie:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.ressourceFond = barre(f, "BORDER", "_raidframe-resource-background")
	f.ressource = barre(f, "ARTWORK", "_raidframe-resource-fill")

	f.menace = ForeverUI.CreateNineSlice(f, "raidframe-agroframe", P.coinMenace, { 0, 0, 0, 0 }, "ARTWORK") or {}
	montrer(f.menace, false)

	-- le calque de dissipation
	local calque = CreateFrame("Frame", nil, f)
	calque:SetAllPoints(f)
	calque:SetFrameLevel(f:GetFrameLevel() + 1)
	calque.fond = calque:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(calque.fond, "raidframe-dispel-fill", true)
	calque.fond:SetAllPoints(calque)
	calque.fond:SetAlpha(0.2)
	calque.degrade = calque:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(calque.degrade, "_raidframe-dispel-highlight-horizontal", true)
	calque.degrade:SetAllPoints(calque)
	calque.bord = ForeverUI.CreateNineSlice(calque, "raidframe-dispelhighlight", P.coinDissipation, { 0, 0, 0, 0 }, "ARTWORK") or {}
	calque:Hide()
	f.calque = calque

	-- le texte, le role et les auras au-dessus des barres
	local dessus = CreateFrame("Frame", nil, f)
	dessus:SetAllPoints(f)
	dessus:SetFrameLevel(f:GetFrameLevel() + 2)
	f.dessus = dessus
	f.role = dessus:CreateTexture(nil, "ARTWORK")
	f.role:SetWidth(P.role)
	f.role:SetHeight(P.role)
	f.role:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -2)
	f.nom = dessus:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	f.nom:SetPoint("TOPLEFT", f.role, "TOPRIGHT", 0, -1)
	f.nom:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3, -3)
	f.nom:SetJustifyH("LEFT")
	f.nom:SetHeight(12)
	f.statut = dessus:CreateFontString(nil, "ARTWORK", "GameFontDisable")
	local police, taille, drapeaux = f.statut:GetFont()
	if police then f.statut:SetFont(police, P.statut * P.echelle, drapeaux) end
	f.statut:SetHeight(P.statut * P.echelle)
	f.statut:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 3, P.hauteur / 3 - 2)
	f.statut:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -3, P.hauteur / 3 - 2)

	f.buffs, f.affaiblissements, f.dissipations = {}, {}, {}
	for k = 1, P.buffs do f.buffs[k] = creerAura(dessus, P.aura) end
	for k = 1, P.affaiblissements do f.affaiblissements[k] = creerAura(dessus, P.aura, true) end
	for k = 1, P.dissipations do
		local t = dessus:CreateTexture(nil, "OVERLAY")
		t:SetWidth(P.dissipation)
		t:SetHeight(P.dissipation)
		t:SetPoint("TOPRIGHT", f, "TOPRIGHT", -3 - (k - 1) * P.dissipation, -2)
		t:Hide()
		f.dissipations[k] = t
	end

	-- la cible, et l'appel : pleins meme hors de portee
	local haut = CreateFrame("Frame", nil, f)
	haut:SetAllPoints(f)
	haut:SetFrameLevel(f:GetFrameLevel() + 3)
	f.cible = ForeverUI.CreateNineSlice(haut, "raidframe-targetframe", P.coinCible, { 0, 0, 0, 0 }, "OVERLAY") or {}
	montrer(f.cible, false)
	f.appel = haut:CreateTexture(nil, "OVERLAY")
	f.appel:SetWidth(P.appel * P.echelle)
	f.appel:SetHeight(P.appel * P.echelle)
	f.appel:SetPoint("BOTTOM", f, "BOTTOM", 0, P.hauteur / 3 - 4)
	f.appel:Hide()

	-- ce que la portee estompe
	f.estompes = { f.fond, f.vie, f.ressourceFond, f.ressource, f.nom, f.statut, f.role }
end

-- la configuration d'un bouton neuf (initialConfigFunction) : les clics, le
-- menu, la taille (initial-width / -height, lus par l'en-tete), l'art
local function configurer(f)
	f:RegisterForClicks("AnyUp")
	f:SetAttribute("*type1", "target")
	f:SetAttribute("*type2", "menu")
	f:SetAttribute("toggleForVehicle", true)
	f:SetAttribute("initial-width", P.largeur)
	f:SetAttribute("initial-height", P.hauteur)
	f.menu = function(self) R.ouvrirMenu(self) end
	construireBouton(f)
	f:HookScript("OnAttributeChanged", function(self, nom, valeur)
		if nom == "unit" then
			self.unite = valeur
			R.majBouton(self)
		end
	end)
	f:HookScript("OnShow", function(self) R.majBouton(self) end)
	f:SetScript("OnEnter", function(self)
		if not self.affiche then return end
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetUnit(self.affiche)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:FadeOut() end)
	table.insert(R.boutons, f)
end

-- ------------------------------------------------------------ les mises a jour

local function fraction(v, m)
	if not m or m <= 0 then return 0 end
	return v / m
end

-- l'unite affichee : le vehicule s'il y en a un (CompactUnitFrame_UpdateUnitEvents)
local function affichee(unite)
	if UnitHasVehicleUI(unite) and UnitTargetsVehicleInRaidUI(unite) then
		local v = unite:gsub("^raid(%d+)$", "raidpet%1")
		if UnitExists(v) then return v, true end
	end
	return unite, false
end

local function majVie(f)
	local u = f.affiche
	local connecte = UnitIsConnected(f.unite)
	local pleine = P.largeur - 2
	remplir(f.vie, connecte and fraction(UnitHealth(u), UnitHealthMax(u)) or 1, pleine)
	-- CompactUnitFrame_UpdateHealthColor
	if not connecte then
		f.vie:SetVertexColor(0.5, 0.5, 0.5)
	else
		local _, classe = UnitClass(f.unite)
		local c = classe and RAID_CLASS_COLORS[classe]
		if c then f.vie:SetVertexColor(c.r, c.g, c.b) else f.vie:SetVertexColor(0, 1, 0) end
	end
	-- CompactUnitFrame_UpdateStatusText
	if not connecte then
		f.statut:SetText(PLAYER_OFFLINE)
		f.statut:Show()
	elseif UnitIsDeadOrGhost(u) then
		f.statut:SetText(DEAD)
		f.statut:Show()
	else
		f.statut:Hide()
	end
end

local function majRessource(f)
	local u = f.affiche
	local type, jeton = UnitPowerType(u)
	local c = (jeton and PowerBarColor[jeton]) or PowerBarColor[type] or PowerBarColor["MANA"]
	if not UnitIsConnected(f.unite) then
		f.ressource:SetVertexColor(0.5, 0.5, 0.5)
	else
		f.ressource:SetVertexColor(c.r, c.g, c.b)
	end
	remplir(f.ressource, fraction(UnitPower(u, type), UnitPowerMax(u, type)), P.largeur - 2)
end

-- la disposition verticale : vie, ressource de 8 (DefaultCompactUnitFrameSetup)
local function poserBarres(f)
	f.vie:SetHeight(P.hauteur - 2 - P.ressourceH)
	f.ressourceFond:ClearAllPoints()
	f.ressourceFond:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 1, 1 + P.ressourceH)
	f.ressourceFond:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
	f.ressource:ClearAllPoints()
	f.ressource:SetPoint("TOPLEFT", f.ressourceFond, "TOPLEFT", 0, 0)
	f.ressource:SetHeight(P.ressourceH)
end

-- l'icone de role : vehicule, puis MT / MA, puis le role de groupe
local function majRole(f)
	local atlas, fichier
	if f.vehicule then
		atlas = "raidframe-icon-vehicle"
	else
		local id = f.unite and tonumber(f.unite:match("^raid(%d+)$"))
		local role = id and select(10, GetRaidRosterInfo(id))
		if role == "MAINTANK" then
			atlas = "raidframe-icon-maintank"
		elseif role == "MAINASSIST" then
			atlas = "raidframe-icon-mainassist"
		else
			local tank, soins, degats = UnitGroupRolesAssigned(f.unite)
			fichier = (tank and P.roles.TANK) or (soins and P.roles.HEALER) or (degats and P.roles.DAMAGER)
		end
	end
	if atlas then
		ForeverUI.SetAtlas(f.role, atlas, true)
	elseif fichier then
		f.role:SetTexture(fichier)
		f.role:SetTexCoord(0, 1, 0, 1)
	end
	if atlas or fichier then
		f.role:SetWidth(P.role)
		f.role:Show()
	else
		-- cache, il garde 1 de large : le nom se colle a gauche
		f.role:SetWidth(1)
		f.role:Hide()
	end
end

local function majMenace(f)
	local statut = UnitThreatSituation(f.affiche)
	if statut and statut > 0 then
		teinter(f.menace, GetThreatStatusColor(statut))
		montrer(f.menace, true)
	else
		montrer(f.menace, false)
	end
end

local function majCible(f)
	montrer(f.cible, f.affiche and UnitIsUnit(f.affiche, "target"))
end

local function poserAura(a, icone, pile, duree, fin)
	a.icone:SetTexture(icone)
	if pile and pile > 1 then a.pile:SetText(pile >= 100 and "*" or pile) else a.pile:SetText("") end
	if duree and duree > 0 and fin then
		CooldownFrame_SetTimer(a.recharge, fin - duree, duree, 1)
	else
		a.recharge:Hide()
	end
	a:Show()
end

local function majAuras(f)
	local u = f.affiche
	-- la dissipation : le premier affaiblissement qui a un type
	local types, premier = {}, nil
	for i = 1, 40 do
		local nom, _, _, _, type = UnitDebuff(u, i)
		if not nom then break end
		if type and P.bordures[type] and not types[type] then
			types[type] = true
			types[#types + 1] = type
			premier = premier or type
		end
	end
	local d = premier and P.ecartDissipation or 0
	if premier then
		local c = DebuffTypeColor[premier] or DebuffTypeColor["none"]
		teinter({ f.calque.fond, f.calque.degrade }, c.r, c.g, c.b)
		teinter(f.calque.bord, c.r, c.g, c.b)
		f.calque:Show()
	else
		f.calque:Hide()
	end
	for k, t in ipairs(f.dissipations) do
		local type = types[k]
		if type and ForeverUI.SetAtlas(t, "raidframe-icon-debuff" .. P.bordures[type], true) then
			t:Show()
		else
			t:Hide()
		end
	end
	-- les buffs (le filtre PLAYER), de BOTTOMRIGHT vers la gauche
	placerGrille(f.buffs, "BOTTOMRIGHT", -1, -3 - d, P.basAura + P.ressourceH + d, P.aura)
	for k, a in ipairs(f.buffs) do
		local nom, _, icone, pile, _, duree, fin = UnitBuff(u, k, "PLAYER")
		if nom then poserAura(a, icone, pile, duree, fin) else a:Hide() end
	end
	-- les affaiblissements, de BOTTOMLEFT vers la droite
	placerGrille(f.affaiblissements, "BOTTOMLEFT", 1, 3 + d, P.basAura + P.ressourceH + d, P.aura)
	for k, a in ipairs(f.affaiblissements) do
		local nom, _, icone, pile, type, duree, fin = UnitDebuff(u, k)
		if nom then
			ForeverUI.SetAtlas(a.bordure, "ui-debuff-border-" .. (P.bordures[type or ""] or "default") .. "-noicon", true)
			poserAura(a, icone, pile, duree, fin)
		else
			a:Hide()
		end
	end
end

local function majAppel(f, fin)
	local etat = f.unite and GetReadyCheckStatus(f.unite)
	if not etat then
		if not fin then f.appel:Hide() end
		return
	end
	if fin and etat == "waiting" then etat = "notready" end
	f.appel:SetTexture(P.marques[etat] or P.marques.waiting)
	f.appel:Show()
end

local function majPortee(f)
	local dans = UnitInRange(f.affiche)
	local a = (dans or UnitIsUnit(f.affiche, "player")) and 1 or P.portee
	if f.alphaPortee ~= a then
		f.alphaPortee = a
		for _, r in ipairs(f.estompes) do r:SetAlpha(a) end
		for _, g in ipairs({ f.buffs, f.affaiblissements }) do
			for _, x in ipairs(g) do x:SetAlpha(a) end
		end
		for _, t in ipairs(f.menace) do t:SetAlpha(a) end
		f.calque:SetAlpha(a)
	end
end

function R.majBouton(f)
	if not f.unite or not UnitExists(f.unite) then
		f.affiche = nil
		return
	end
	f.affiche, f.vehicule = affichee(f.unite)
	poserBarres(f)
	f.nom:SetText(GetUnitName(f.unite, false))
	majVie(f)
	majRessource(f)
	majRole(f)
	majMenace(f)
	majCible(f)
	majAuras(f)
	majAppel(f)
	majPortee(f)
end

local function boutonsDe(unite)
	local l = {}
	for _, f in ipairs(R.boutons) do
		if f.unite and (f.unite == unite or f.affiche == unite) then l[#l + 1] = f end
	end
	return l
end

-- --------------------------------------------------------------------- le menu

local menu = CreateFrame("Frame", "ForeverUICompactRaidFrameDropDown", UIParent, "UIDropDownMenuTemplate")
menu:Hide()
menu.displayMode = "MENU"
-- CompactUnitFrame_OpenMenu : SELF, VEHICLE ou RAID_PLAYER ; le menu se
-- remplit a l'ouverture (ToggleDropDownMenu), jamais a la construction
menu.initialize = function(self)
	local m = UIDROPDOWNMENU_OPEN_MENU or self
	if not m or not m.unit then return end
	UnitPopup_ShowMenu(m, m.which, m.unit, m.name, m.id)
end

function R.ouvrirMenu(f)
	if not f.unite then return end
	local id = tonumber(f.unite:match("^raid(%d+)$"))
	if UnitIsUnit(f.unite, "player") then
		menu.which = "SELF"
	elseif f.vehicule then
		menu.which = "VEHICLE"
	else
		menu.which = "RAID_PLAYER"
	end
	menu.unit = f.vehicule and f.affiche or f.unite
	menu.name = UnitName(f.unite)
	menu.id = id
	ToggleDropDownMenu(1, nil, menu, "cursor")
end

-- ------------------------------------------------------ le conteneur et les groupes

local conteneur = CreateFrame("Frame", "ForeverUICompactRaidFrameContainer", UIParent)
conteneur:SetFrameStrata("LOW")
conteneur:SetWidth(P.largeur)
conteneur:SetHeight(P.titreH + P.parGroupe * P.hauteur)
R.conteneur = conteneur

R.entetes, R.titres = {}, {}
for g = 1, P.groupes do
	local h = CreateFrame("Frame", "ForeverUICompactRaidGroup" .. g, conteneur, "SecureRaidGroupHeaderTemplate")
	h:SetAttribute("groupFilter", tostring(g))
	h:SetAttribute("point", "TOP")
	h:SetAttribute("yOffset", 0)
	h:SetAttribute("template", "SecureUnitButtonTemplate")
	h:SetAttribute("templateType", "Button")
	h:SetAttribute("unitsPerColumn", P.parGroupe)
	h:SetAttribute("maxColumns", 1)
	h:SetAttribute("sortMethod", "INDEX")
	h.initialConfigFunction = configurer
	h:SetWidth(P.largeur)
	h:SetHeight(P.parGroupe * P.hauteur)
	R.entetes[g] = h

	-- le titre (CompactRaidGroup : 14 de haut, GameFontNormalSmall) : un cadre
	-- ordinaire, qu'on peut montrer ou cacher meme en combat
	local t = CreateFrame("Frame", nil, conteneur)
	t:SetWidth(P.largeur)
	t:SetHeight(P.titreH)
	t.texte = t:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	t.texte:SetPoint("TOP", t, "TOP", 0, 0)
	t.texte:SetText(GROUP .. " " .. g)
	t:Hide()
	R.titres[g] = t
end

-- les groupes utilises, en colonnes collees ; les autres au bout, dans
-- l'ordre (un groupe qui se remplit en combat y apparait sans rien chevaucher)
local function groupesUtilises()
	local utilise = {}
	for i = 1, (GetNumRaidMembers() or 0) do
		local _, _, groupe = GetRaidRosterInfo(i)
		if groupe then utilise[groupe] = true end
	end
	return utilise
end

function R.disposer()
	if InCombatLockdown() then
		R.aDisposer = true
		return
	end
	R.aDisposer = nil
	local utilise = groupesUtilises()
	local ordre = {}
	for g = 1, P.groupes do if utilise[g] then ordre[#ordre + 1] = g end end
	local n = #ordre
	for g = 1, P.groupes do if not utilise[g] then ordre[#ordre + 1] = g end end
	for k, g in ipairs(ordre) do
		local x = (k - 1) * P.largeur
		R.titres[g]:ClearAllPoints()
		R.titres[g]:SetPoint("TOPLEFT", conteneur, "TOPLEFT", x, 0)
		R.entetes[g]:ClearAllPoints()
		R.entetes[g]:SetPoint("TOPLEFT", conteneur, "TOPLEFT", x, -P.titreH)
	end
	conteneur:SetWidth(P.largeur * math.max(n, 1))
	R.majTitres()
end

-- un titre par groupe qui a des membres (ce n'est pas un cadre protege)
function R.majTitres()
	local utilise = groupesUtilises()
	for g = 1, P.groupes do
		if utilise[g] then R.titres[g]:Show() else R.titres[g]:Hide() end
	end
end

-- les cinq boutons de chaque groupe, crees d'avance hors combat
local function creerBoutons()
	conteneur:Show()
	for _, h in ipairs(R.entetes) do
		h:Show()
		h:SetAttribute("startingIndex", -(P.parGroupe - 1))
		h:SetAttribute("startingIndex", 1)
	end
end

-- ------------------------------------------------------------------ l'addon HD

-- "Compact Raid Frames - HD client" (patch-5.mpq) : desactive pour la
-- prochaine session, ses cadres caches pour celle-ci
local function eteindreAddonHD()
	if not (IsAddOnLoaded and IsAddOnLoaded("CompactRaidFrame")) then return end
	if DisableAddOn then DisableAddOn("CompactRaidFrame") end
	if InCombatLockdown() then return end
	for _, nom in ipairs({ "CompactRaidFrameManager", "CompactRaidFrameContainer" }) do
		local f = _G[nom]
		if f then RegisterStateDriver(f, "visibility", "hide") end
	end
end

-- --------------------------------------------------------------- les evenements

local veilleur = CreateFrame("Frame")
R.veilleur = veilleur
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "RAID_ROSTER_UPDATE", "PLAYER_REGEN_ENABLED",
	"PLAYER_TARGET_CHANGED", "PLAYER_ROLES_ASSIGNED", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_DISPLAYPOWER",
	"UNIT_MANA", "UNIT_RAGE", "UNIT_FOCUS", "UNIT_ENERGY", "UNIT_RUNIC_POWER", "UNIT_MAXMANA",
	"UNIT_MAXRAGE", "UNIT_MAXFOCUS", "UNIT_MAXENERGY", "UNIT_MAXRUNIC_POWER", "UNIT_NAME_UPDATE",
	"UNIT_AURA", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE",
	"PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE", "READY_CHECK", "READY_CHECK_CONFIRM",
	"READY_CHECK_FINISHED" }) do
	veilleur:RegisterEvent(ev)
end

local function tous()
	for _, f in ipairs(R.boutons) do
		if f:IsShown() then R.majBouton(f) end
	end
end

veilleur:SetScript("OnEvent", function(self, ev, unite)
	if ev == "PLAYER_ENTERING_WORLD" then
		eteindreAddonHD()
		R.disposer()
		tous()
	elseif ev == "RAID_ROSTER_UPDATE" then
		R.disposer()
		R.majTitres()
		tous()
	elseif ev == "PLAYER_REGEN_ENABLED" then
		if R.aDisposer then R.disposer() end
		eteindreAddonHD()
	elseif ev == "PLAYER_TARGET_CHANGED" then
		for _, f in ipairs(R.boutons) do if f.affiche then majCible(f) end end
	elseif ev == "PLAYER_ROLES_ASSIGNED" or ev == "PARTY_MEMBER_ENABLE" or ev == "PARTY_MEMBER_DISABLE" then
		tous()
	elseif ev == "READY_CHECK" or ev == "READY_CHECK_CONFIRM" then
		for _, f in ipairs(R.boutons) do majAppel(f) end
	elseif ev == "READY_CHECK_FINISHED" then
		for _, f in ipairs(R.boutons) do majAppel(f, true) end
		R.finAppel = P.finAppel
		R.minuterie:Show()
	else
		for _, f in ipairs(boutonsDe(unite)) do R.majBouton(f) end
	end
end)

-- la portee (UnitInRange n'a pas d'evenement en 3.3.5), et la fin de l'appel
local minuterie = CreateFrame("Frame")
minuterie.temps = 0
minuterie:SetScript("OnUpdate", function(self, ecoule)
	self.temps = self.temps + ecoule
	if self.temps >= P.periodePortee then
		self.temps = 0
		for _, f in ipairs(R.boutons) do
			if f.affiche and f:IsVisible() then majPortee(f) end
		end
	end
	if R.finAppel then
		R.finAppel = R.finAppel - ecoule
		if R.finAppel <= 0 then
			R.finAppel = nil
			for _, f in ipairs(R.boutons) do f.appel:Hide() end
		end
	end
end)
R.minuterie = minuterie

creerBoutons()
RegisterStateDriver(conteneur, "visibility", "[group:raid] show; hide")
R.disposer()
ForeverUI.Layout.Register(conteneur, "raidframe", "Cadres de raid", "TOPLEFT", "TOPLEFT", P.x, P.y)
