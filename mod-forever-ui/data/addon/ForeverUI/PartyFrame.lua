-- ForeverUI : les cadres de groupe (etape 1 du chantier des groupes, memoire
-- foreverui-groupes).
--
-- RELEVE -- camelot charge pour son groupe les fichiers de blizzard_unitframe
-- shared/partyframe.* et mainline/partyframetemplates.xml, partymemberframe.lua
-- (aucun fichier camelot/ ne les remplace). Valeurs du code, pas d'estimation.
--
--   conteneur   PartyFrame, empile vertical, haut vers le bas : membre de
--               120 x 53, espacement 10 -- 26 si la CVar showPartyPets est
--               active --, donc un pas de 63 (79 avec familiers) ; ancre sur le
--               TOPRIGHT du gestionnaire de raid en (0, -7), lequel est plie a
--               (-200, -140) pour 222 de large : (22, -147) sur l'ecran.
--   membre      PartyMemberFrameTemplate, SecureUnitButtonTemplate :
--               portrait 37 x 37 (7, -6) ; art UI-HUD-UnitFrame-Party-PortraitOn
--               (1, -2) ; vie 70 x 10 (45, -19), atlas ...-Bar-Health, jamais
--               teintee (lockColor) ; ressource 74 x 7 (41, -30), atlas
--               ...-Bar-<Mana|Rage|Focus|Energy|RunicPower> ; nom
--               GameFontNormalSmall 57 x 12 (46, -6) ; textes des barres
--               TextStatusBarText au centre ; lueur de menace ...-InCombat
--               (1, -2) teinte GetThreatStatusColor ; lueur d'affaiblissement
--               ...-Status (1, -2) teinte du type ; chef / guide 16 x 16, BOTTOM
--               sur le TOP (-10, -6) ; PvP a l'echelle 0,6, centre (24, -68) a
--               cette echelle ; deconnexion Disconnect-Icon 64 x 64 LEFT (-7, -1) ;
--               role roleicon-tiny-* 12 x 12 TOPRIGHT (-5, -5) ; appel 36 x 36
--               au centre du portrait (0, -2), UI-LFG-*Mark, reste 10 s puis
--               s'efface en 1,5 s ; 4 affaiblissements de 15 x 15 a (48, -43),
--               ecart 2, bordure UI-Debuff-Overlays, pile NumberFontNormalSmall.
--   etats       mort : portrait 0,35 ; fantome 0,2 / 0,2 / 0,75 ; vie <= 20 % :
--               portrait rouge qui bat (alpha 127/255 a 1, demi-periodes de
--               0,5 s) ; deconnecte : vie pleine desaturee, portrait desature,
--               icone ; vehicule : art, lueurs, barres et nom du vehicule, le
--               cadre suit partypetN, le familier suit le joueur.
--   familier    64 x 23 a (23, -43) : portrait 18 x 18 (3, -3), art et lueur
--               a l'echelle 0,5, vie 71 x 10 a l'echelle 0,5 en (43, -18),
--               teinte (0, 1, 0), grise si deconnecte ; clic droit sans menu.
--   survol      l'infobulle de l'unite (GameTooltip_SetDefaultAnchor, SetUnit)
--               et celle des buffs, TOPLEFT sur le membre en (47, -25).
--   visible     en groupe, pas en raid (ShouldShowPartyFrames).
--
-- CE QUE 3.3.5 NE SAIT PAS FAIRE, ET CE QUI LE REMPLACE :
--   * pas de masque : les barres sont posees a nu ; le masque de la vie
--     coincide avec la barre, celui de la ressource lui retire un pixel a
--     gauche (repris) et un biseau de 1 a 3 pixels en haut a gauche (non
--     repris) ;
--   * pas de prediction de soins ni d'absorptions, ni phase, ni invocation,
--     ni "dans un autre groupe" (l'icone d'absence) ;
--   * pas d'echelle sur une texture : les tailles a 0,5 / 0,6 sont calculees ;
--   * l'appel reprend les marques de camelot, decoupees de leur feuille de
--     2048 (tools/decouper_marques.py) ;
--   * pas de ligne UNIT_POPUP_RIGHT_CLICK dans l'infobulle : la chaine
--     n'existe pas dans la langue du client ;
--   * l'infobulle des buffs est celle du client (PartyMemberBuffTooltip), a la
--     place que camelot donne a la sienne.
--
-- SECURITE. Les membres et leurs familiers sont des boutons securises, montres
-- par RegisterUnitWatch ; le conteneur est cache en raid par un pilote d'etat
-- -- les deux tiennent en combat. Les cadres de groupe du client sont tenus
-- caches par un pilote d'etat eux aussi : d'autres fonctions (le client,
-- l'addon HD) peuvent les reafficher, meme en combat.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local SEP = string.char(92)

-- une table : Lua 5.1 limite a 60 les valeurs capturees par une fonction
local P = {
	membreL = 120, membreH = 53, espacement = 10, espacementFamiliers = 26, bas = 2,
	x = 22, y = -147,
	art = "ui-hud-unitframe-party-portraiton",
	artVehicule = "ui-hud-unitframe-party-portraiton-vehicle",
	lueur = "ui-hud-unitframe-party-portraiton-incombat",
	lueurVehicule = "ui-hud-unitframe-party-portraiton-vehicle-incombat",
	statut = "ui-hud-unitframe-party-portraiton-status",
	statutVehicule = "ui-hud-unitframe-party-portraiton-vehicle-status",
	vie = "ui-hud-unitframe-party-portraiton-bar-health",
	vieVehicule = "ui-hud-unitframe-party-portraiton-vehicle-bar-health",
	chef = "ui-hud-unitframe-player-group-leadericon",
	guide = "ui-hud-unitframe-player-group-guideicon",
	pvpLibre = "ui-hud-unitframe-player-pvp-ffaicon",
	pvpHorde = "ui-hud-unitframe-player-pvp-hordeicon",
	pvpAlliance = "ui-hud-unitframe-player-pvp-allianceicon",
	pvpEchelle = 0.6,
	deconnexion = "Interface" .. SEP .. "CharacterFrame" .. SEP .. "Disconnect-Icon",
	bordureAura = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Debuff-Overlays",
	marques = {
		ready = "Interface" .. SEP .. "ForeverUI" .. SEP .. "lfgframe" .. SEP .. "ui-lfg-readymark",
		notready = "Interface" .. SEP .. "ForeverUI" .. SEP .. "lfgframe" .. SEP .. "ui-lfg-declinemark",
		waiting = "Interface" .. SEP .. "ForeverUI" .. SEP .. "lfgframe" .. SEP .. "ui-lfg-pendingmark",
	},
	appelReste = 10, appelFondu = 1.5,
	auras = 4, auraCote = 15, auraEcart = 2,
	pouls = 0.5, poulsMin = 127 / 255,
	-- normal / vehicule : ancres et largeurs posees par ToPlayerArt et
	-- ToVehicleArt
	joueur = { art = { 1, -2 }, lueur = { 1, -2 }, statut = { 1, -2 }, vie = { 45, -19, 70 },
		ressource = { 42, -30, 73 }, nom = { 46, -6, 57 } },
	vehicule = { art = { 0, 0 }, lueur = { -4, 4 }, statut = { -3, 3 }, vie = { 48, -18, 67 },
		ressource = { 45, -29, 70 }, nom = { 49, -6, 56 } },
}

-- la ressource : l'atlas se compose du jeton de la ressource
local RESSOURCE = { MANA = "Mana", RAGE = "Rage", FOCUS = "Focus", ENERGY = "Energy", RUNIC_POWER = "RunicPower" }

local function atlasRessource(jeton, vehicule)
	local nom = RESSOURCE[jeton or ""] or "Mana"
	return "ui-hud-unitframe-party-portraiton" .. (vehicule and "-vehicle" or "") .. "-bar-" .. string.lower(nom)
end

local G = {}                         -- l'etat partage
ForeverUI.PartyFrame = G

-- ----------------------------------------------------------------- le conteneur

local conteneur = CreateFrame("Frame", "ForeverUIPartyFrame", UIParent)
conteneur:SetFrameStrata("LOW")
conteneur:SetWidth(P.membreL)
G.conteneur = conteneur

local function pas()
	local familiers = GetCVarBool and GetCVarBool("showPartyPets")
	return P.membreH + (familiers and P.espacementFamiliers or P.espacement)
end

-- ------------------------------------------------------------------ les pieces

local function champ(parent, couche, police)
	local fs = parent:CreateFontString(nil, couche or "OVERLAY", police)
	return fs
end

local function creerAuras(parent, nom, x, y, unite)
	local auras = {}
	for k = 1, P.auras do
		local b = CreateFrame("Button", nom .. "Debuff" .. k, parent)
		b:SetWidth(P.auraCote)
		b:SetHeight(P.auraCote)
		b:SetPoint("TOPLEFT", parent, "TOPLEFT", x + (k - 1) * (P.auraCote + P.auraEcart), y)
		b.icone = b:CreateTexture(nil, "ARTWORK")
		b.icone:SetAllPoints(b)
		b.bordure = b:CreateTexture(nil, "OVERLAY")
		b.bordure:SetTexture(P.bordureAura)
		b.bordure:SetTexCoord(0.296875, 0.5703125, 0, 0.515625)
		b.bordure:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
		b.bordure:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
		b.pile = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
		b.pile:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 5, 0)
		b.recharge = CreateFrame("Cooldown", nil, b)
		b.recharge:SetReverse(true)
		b.recharge:SetPoint("CENTER", b, "CENTER", 0, -1)
		b.recharge:SetWidth(P.auraCote)
		b.recharge:SetHeight(P.auraCote)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetUnitDebuff(self.unite, self.indice, self.filtre)
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		b:Hide()
		auras[k] = b
	end
	return auras
end

-- les affaiblissements : la regle de RefreshDebuffs (le filtre "RAID" si
-- l'option des affaiblissements dissipables est active et l'unite aidable)
local function majAuras(auras, unite)
	local filtre
	if GetCVarBool("showDispelDebuffs") and UnitCanAssist("player", unite) then
		filtre = "RAID"
	end
	local couleur
	for k, b in ipairs(auras) do
		local nom, _, icone, pile, type, duree, fin = UnitDebuff(unite, k, filtre)
		if icone then
			b.unite, b.indice, b.filtre = unite, k, filtre
			b.icone:SetTexture(icone)
			local c = DebuffTypeColor[type or "none"] or DebuffTypeColor["none"]
			b.bordure:SetVertexColor(c.r, c.g, c.b)
			if pile and pile > 1 then
				b.pile:SetText(pile > 99 and "*" or pile)
			else
				b.pile:SetText("")
			end
			if duree and duree > 0 and fin then
				CooldownFrame_SetTimer(b.recharge, fin - duree, duree, 1)
			else
				b.recharge:Hide()
			end
			b:Show()
			if type and not couleur then couleur = c end
		else
			b:Hide()
		end
	end
	return couleur
end

-- --------------------------------------------------------------- un familier

local function creerFamilier(membre, i)
	local f = CreateFrame("Button", "ForeverUIPartyMemberFrame" .. i .. "PetFrame", membre, "SecureUnitButtonTemplate")
	f:SetWidth(64)
	f:SetHeight(23)
	f:SetFrameStrata("LOW")
	f:SetPoint("TOPLEFT", membre, "TOPLEFT", 23, -43)
	f.unit = "partypet" .. i
	f:SetAttribute("unit", f.unit)
	f:SetAttribute("*type1", "target")
	f:SetAttribute("toggleForVehicle", true)
	f:RegisterForClicks("AnyUp")
	f.portrait = f:CreateTexture(nil, "BACKGROUND")
	f.portrait:SetWidth(18)
	f.portrait:SetHeight(18)
	f.portrait:SetPoint("TOPLEFT", f, "TOPLEFT", 3, -3)
	-- l'art et la lueur a l'echelle 0,5 : 120 x 49 -> 60 x 24,5 ; 114 x 47 -> 57 x 23,5
	f.art = f:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(f.art, P.art, true)
	f.art:SetWidth(60)
	f.art:SetHeight(24.5)
	f.art:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -0.5)
	local dessus = CreateFrame("Frame", nil, f)
	dessus:SetAllPoints(f)
	dessus:SetFrameLevel(f:GetFrameLevel() + 1)
	f.lueur = dessus:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(f.lueur, P.lueur, true)
	f.lueur:SetWidth(57)
	f.lueur:SetHeight(23.5)
	f.lueur:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -0.5)
	f.lueur:Hide()
	-- la vie : 71 x 10 a (43, -18), a l'echelle 0,5
	f.vie = dessus:CreateTexture(nil, "BORDER")
	f.vie:SetPoint("TOPLEFT", f, "TOPLEFT", 21.5, -9)
	f.auras = creerAuras(f, f:GetName(), 24, -16)
	f:SetScript("OnEnter", function(self)
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetUnit(self.affiche or self.unit)
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:FadeOut() end)
	return f
end

-- ----------------------------------------------------------------- un membre

local function creerMembre(i)
	local m = CreateFrame("Button", "ForeverUIPartyMemberFrame" .. i, conteneur, "SecureUnitButtonTemplate")
	m:SetID(i)
	m:SetWidth(P.membreL)
	m:SetHeight(P.membreH)
	m:SetFrameStrata("LOW")
	m.unite = "party" .. i
	m.unit = m.unite
	m:SetAttribute("unit", m.unite)
	m:SetAttribute("*type1", "target")
	m:SetAttribute("*type2", "menu")
	m:SetAttribute("toggleForVehicle", true)
	m:RegisterForClicks("AnyUp")
	-- le menu du client : celui de son cadre de groupe, UnitPopup "PARTY"
	m.menu = function(self)
		ToggleDropDownMenu(1, nil, _G["PartyMemberFrame" .. i .. "DropDown"], self:GetName(), 47, 15)
	end

	m.portrait = m:CreateTexture(nil, "BACKGROUND")
	m.portrait:SetWidth(37)
	m.portrait:SetHeight(37)
	m.portrait:SetPoint("TOPLEFT", m, "TOPLEFT", 7, -6)
	m.art = m:CreateTexture(nil, "ARTWORK")

	-- les barres, au-dessus de l'art (camelot les met dans un cadre fils)
	local barres = CreateFrame("Frame", nil, m)
	barres:SetAllPoints(m)
	barres:SetFrameLevel(m:GetFrameLevel() + 1)
	m.vie = barres:CreateTexture(nil, "ARTWORK")
	m.ressource = barres:CreateTexture(nil, "ARTWORK")
	m.texteVie = champ(barres, "OVERLAY", "TextStatusBarText")
	m.texteRessource = champ(barres, "OVERLAY", "TextStatusBarText")

	-- ce qui passe au-dessus de tout
	local dessus = CreateFrame("Frame", nil, m)
	dessus:SetAllPoints(m)
	dessus:SetFrameLevel(m:GetFrameLevel() + 2)
	m.dessus = dessus
	m.lueur = dessus:CreateTexture(nil, "BACKGROUND")
	m.lueur:Hide()
	m.statut = dessus:CreateTexture(nil, "BACKGROUND")
	m.statut:Hide()
	m.nom = champ(dessus, "OVERLAY", "GameFontNormalSmall")
	m.nom:SetJustifyH("LEFT")
	m.nom:SetHeight(12)
	m.chef = dessus:CreateTexture(nil, "OVERLAY")
	m.chef:SetPoint("BOTTOM", m, "TOP", -10, -6)
	m.chef:Hide()
	m.pvp = dessus:CreateTexture(nil, "OVERLAY")
	m.pvp:Hide()
	m.deconnexion = dessus:CreateTexture(nil, "OVERLAY")
	m.deconnexion:SetTexture(P.deconnexion)
	m.deconnexion:SetWidth(64)
	m.deconnexion:SetHeight(64)
	m.deconnexion:SetPoint("LEFT", m, "LEFT", -7, -1)
	m.deconnexion:Hide()
	m.role = dessus:CreateTexture(nil, "OVERLAY")
	m.role:SetWidth(12)
	m.role:SetHeight(12)
	m.role:SetPoint("TOPRIGHT", m, "TOPRIGHT", -5, -5)
	m.role:Hide()

	-- l'appel : 36 x 36, deux niveaux au-dessus (RaiseFrameLevelByTwo)
	local appel = CreateFrame("Frame", nil, m)
	appel:SetWidth(36)
	appel:SetHeight(36)
	appel:SetPoint("CENTER", m.portrait, "CENTER", 0, -2)
	appel:SetFrameLevel(m:GetFrameLevel() + 4)
	appel.icone = appel:CreateTexture(nil, "ARTWORK")
	appel.icone:SetAllPoints(appel)
	appel:Hide()
	m.appel = appel

	m.auras = creerAuras(dessus, m:GetName(), 48, -43)
	m.familier = creerFamilier(m, i)

	m:SetScript("OnEnter", function(self)
		-- le survol montre les textes des barres (CVar partyStatusText a 0)
		self.survol = true
		G.majMembre(self)
		GameTooltip_SetDefaultAnchor(GameTooltip, self)
		GameTooltip:SetUnit(self.unit)
		GameTooltip:Show()
		-- l'infobulle des buffs, a la place de celle de camelot
		if PartyMemberBuffTooltip and PartyMemberBuffTooltip_Update then
			PartyMemberBuffTooltip:ClearAllPoints()
			PartyMemberBuffTooltip:SetPoint("TOPLEFT", self, "TOPLEFT", 47, -25)
			PartyMemberBuffTooltip_Update(self)
		end
	end)
	m:SetScript("OnLeave", function(self)
		self.survol = nil
		G.majMembre(self)
		GameTooltip:FadeOut()
		if PartyMemberBuffTooltip then PartyMemberBuffTooltip:Hide() end
	end)
	return m
end

G.membres = {}
for i = 1, 4 do
	G.membres[i] = creerMembre(i)
end

-- ------------------------------------------------------------ les mises a jour

-- l'unite affichee : le vehicule s'il y en a un (le cadre suit partypetN)
local function unites(m)
	local i = m:GetID()
	if UnitHasVehicleUI("party" .. i) then
		return "partypet" .. i, "party" .. i, true
	end
	return "party" .. i, "partypet" .. i, false
end

local function poser(tex, atlas, x, y, rel)
	ForeverUI.SetAtlas(tex, atlas)
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", rel, "TOPLEFT", x, y)
end

-- ToPlayerArt / ToVehicleArt
local function majArt(m)
	local geo = m.vehicule and P.vehicule or P.joueur
	poser(m.art, m.vehicule and P.artVehicule or P.art, geo.art[1], geo.art[2], m)
	poser(m.lueur, m.vehicule and P.lueurVehicule or P.lueur, geo.lueur[1], geo.lueur[2], m)
	poser(m.statut, m.vehicule and P.statutVehicule or P.statut, geo.statut[1], geo.statut[2], m)
	m.vie:ClearAllPoints()
	m.vie:SetPoint("TOPLEFT", m, "TOPLEFT", geo.vie[1], geo.vie[2])
	m.ressource:ClearAllPoints()
	m.ressource:SetPoint("TOPLEFT", m, "TOPLEFT", geo.ressource[1], geo.ressource[2])
	m.nom:ClearAllPoints()
	m.nom:SetPoint("TOPLEFT", m, "TOPLEFT", geo.nom[1], geo.nom[2])
	m.nom:SetWidth(geo.nom[3])
end

local function fraction(valeur, maximum)
	if not maximum or maximum <= 0 then return 0 end
	return valeur / maximum
end

local function texteBarre(fs, valeur, maximum, survol)
	local toujours = GetCVar("partyStatusText") == "1"
	if not (toujours or survol) or not maximum or maximum <= 0 then
		fs:Hide()
		return
	end
	if GetCVarBool("statusTextPercentage") then
		fs:SetText(math.ceil(valeur / maximum * 100) .. "%")
	else
		fs:SetText(valeur .. " / " .. maximum)
	end
	fs:Show()
end

local function majVie(m)
	local u = m.unit
	local geo = m.vehicule and P.vehicule or P.joueur
	local atlas = m.vehicule and P.vieVehicule or P.vie
	local connecte = UnitIsConnected(m.unite)
	local vie, max = UnitHealth(u), UnitHealthMax(u)
	-- deconnecte : la barre pleine, desaturee
	ForeverUI.SetAtlasFill(m.vie, atlas, connecte and fraction(vie, max) or 1, geo.vie[3])
	m.vie:SetDesaturated(not connecte)
	m.texteVie:ClearAllPoints()
	m.texteVie:SetPoint("CENTER", m, "TOPLEFT", geo.vie[1] + geo.vie[3] / 2, geo.vie[2] - 5)
	if UnitIsDeadOrGhost(u) then
		m.texteVie:SetText(DEAD)
		m.texteVie:Show()
	else
		texteBarre(m.texteVie, vie, max, m.survol)
	end
	-- PartyMemberHealthCheck : la teinte du portrait
	m.pourcent = fraction(vie, max)
	if UnitIsDead(u) then
		m.portrait:SetVertexColor(0.35, 0.35, 0.35, 1)
	elseif UnitIsGhost(u) then
		m.portrait:SetVertexColor(0.2, 0.2, 0.75, 1)
	elseif m.pourcent > 0 and m.pourcent <= 0.2 then
		m.portrait:SetVertexColor(1, 0, 0)
	else
		m.portrait:SetVertexColor(1, 1, 1, 1)
	end
	G.majPouls()
end

local function majRessource(m)
	local u = m.unit
	local geo = m.vehicule and P.vehicule or P.joueur
	local type, jeton = UnitPowerType(u)
	local valeur, max = UnitPower(u, type), UnitPowerMax(u, type)
	ForeverUI.SetAtlasFill(m.ressource, atlasRessource(jeton, m.vehicule), fraction(valeur, max), geo.ressource[3])
	-- le masque de camelot retire le premier pixel de la barre : on la pose
	-- un pixel plus loin, sur 73 (voir l'en-tete)
	m.texteRessource:ClearAllPoints()
	m.texteRessource:SetPoint("CENTER", m, "TOPLEFT", geo.ressource[1] + geo.ressource[3] / 2 + 2, geo.ressource[2] - 3.5)
	texteBarre(m.texteRessource, valeur, max, m.survol)
end

local function majPortrait(m)
	SetPortraitTexture(m.portrait, m.unit)
	m.portrait:SetDesaturated(not UnitIsConnected(m.unite))
end

-- chef ou guide (HasLFGRestrictions : le groupe du chercheur de donjon)
local function majChef(m)
	if GetPartyLeaderIndex() == m:GetID() then
		ForeverUI.SetAtlas(m.chef, HasLFGRestrictions() and P.guide or P.chef)
		m.chef:Show()
	else
		m.chef:Hide()
	end
end

local function majPvP(m)
	local u = m.unite
	local atlas
	if UnitIsPVPFreeForAll(u) then
		atlas = P.pvpLibre
	elseif UnitIsPVP(u) then
		local faction = UnitFactionGroup(u)
		if faction == "Horde" then atlas = P.pvpHorde elseif faction == "Alliance" then atlas = P.pvpAlliance end
	end
	if atlas and ForeverUI.SetAtlas(m.pvp, atlas) then
		-- a l'echelle 0,6 : la taille de l'atlas et le decalage (24, -68)
		m.pvp:SetWidth(m.pvp:GetWidth() * P.pvpEchelle)
		m.pvp:SetHeight(m.pvp:GetHeight() * P.pvpEchelle)
		m.pvp:ClearAllPoints()
		m.pvp:SetPoint("CENTER", m, "TOPLEFT", 24 * P.pvpEchelle, -68 * P.pvpEchelle)
		m.pvp:Show()
	else
		m.pvp:Hide()
	end
end

-- UnitGroupRolesAssigned rend trois booleens en 3.3.5
local function majRole(m)
	local tank, soins, degats = UnitGroupRolesAssigned(m.unite)
	local atlas = (tank and "roleicon-tiny-tank") or (soins and "roleicon-tiny-healer") or (degats and "roleicon-tiny-dps")
	if atlas and ForeverUI.SetAtlas(m.role, atlas, true) then
		m.role:Show()
	else
		m.role:Hide()
	end
end

local function majMenace(m)
	local statut = UnitThreatSituation(m.unit)
	if IsThreatWarningEnabled() and statut and statut > 0 and not UnitIsDeadOrGhost(m.unit) then
		m.lueur:SetVertexColor(GetThreatStatusColor(statut))
		m.lueur:Show()
	else
		m.lueur:Hide()
	end
end

local function majAurasMembre(m)
	local couleur = majAuras(m.auras, m.unit)
	if couleur then
		m.statut:SetVertexColor(couleur.r, couleur.g, couleur.b)
		m.statut:Show()
	else
		m.statut:Hide()
	end
end

local function majFamilier(m)
	local f = m.familier
	f.affiche = m.familierUnite
	local u = f.affiche
	if not UnitExists(u) then return end
	SetPortraitTexture(f.portrait, u)
	local connecte = UnitIsConnected(m.unite)
	-- 71 x 10 a l'echelle 0,5 : 35,5 de long, teinte verte (pas de lockColor)
	ForeverUI.SetAtlasFill(f.vie, P.vie, connecte and fraction(UnitHealth(u), UnitHealthMax(u)) or 1, 35.5)
	f.vie:SetHeight(5)
	if connecte then f.vie:SetVertexColor(0, 1, 0) else f.vie:SetVertexColor(0.5, 0.5, 0.5) end
	local statut = UnitThreatSituation(u)
	if IsThreatWarningEnabled() and statut and statut > 0 then
		f.lueur:SetVertexColor(GetThreatStatusColor(statut))
		f.lueur:Show()
	else
		f.lueur:Hide()
	end
	majAuras(f.auras, u)
end

local function majDeconnexion(m)
	if UnitIsConnected(m.unite) then m.deconnexion:Hide() else m.deconnexion:Show() end
end

function G.majMembre(m)
	if not UnitExists(m.unite) then return end
	local affiche, familier, vehicule = unites(m)
	m.unit, m.familierUnite, m.vehicule = affiche, familier, vehicule
	majArt(m)
	m.nom:SetText(GetUnitName(affiche, true))
	majPortrait(m)
	majVie(m)
	majRessource(m)
	majChef(m)
	majPvP(m)
	majRole(m)
	majMenace(m)
	majAurasMembre(m)
	majDeconnexion(m)
	majFamilier(m)
end

-- LE POULS du portrait sous 20 % : l'alpha va de 127/255 a 1 et revient, par
-- demi-periodes de 0,5 s, tant qu'un membre est dans ce cas
local pouls = CreateFrame("Frame")
pouls.temps = 0
pouls:Hide()
pouls:SetScript("OnUpdate", function(self, ecoule)
	self.temps = self.temps + ecoule
	local t = (self.temps % (2 * P.pouls)) / P.pouls
	local a = t <= 1 and (1 - t * (1 - P.poulsMin)) or (P.poulsMin + (t - 1) * (1 - P.poulsMin))
	for _, m in ipairs(G.membres) do
		if m.bat then m.portrait:SetAlpha(a) end
	end
end)

function G.majPouls()
	local un = false
	for _, m in ipairs(G.membres) do
		local bat = m:IsShown() and not UnitIsDeadOrGhost(m.unit or m.unite) and m.pourcent
			and m.pourcent > 0 and m.pourcent <= 0.2
		m.bat = bat
		if not bat then m.portrait:SetAlpha(1) end
		un = un or bat
	end
	if un then pouls:Show() else pouls:Hide() end
end

-- ---------------------------------------------------------------------- l'appel

local function majAppel(m, fin)
	local etat = GetReadyCheckStatus(m.unite)
	local a = m.appel
	if not etat then
		if not fin then a:Hide() end
		return
	end
	if fin and etat == "waiting" then etat = "notready" end
	a.icone:SetTexture(P.marques[etat] or P.marques.waiting)
	a:SetAlpha(1)
	a.reste = nil
	if fin then a.reste = P.appelReste + P.appelFondu end
	a:Show()
end

local minuterie = CreateFrame("Frame")
minuterie:SetScript("OnUpdate", function(self, ecoule)
	local actif = false
	for _, m in ipairs(G.membres) do
		local a = m.appel
		if a.reste then
			a.reste = a.reste - ecoule
			if a.reste <= 0 then
				a.reste = nil
				a:Hide()
			else
				if a.reste < P.appelFondu then a:SetAlpha(a.reste / P.appelFondu) end
				actif = true
			end
		end
	end
	if not actif then self:Hide() end
end)
minuterie:Hide()

-- ------------------------------------------------------------ la disposition

-- le pas depend de l'option des familiers ; hors combat seulement
function G.disposer()
	if InCombatLockdown() then
		G.aDisposer = true
		return
	end
	G.aDisposer = nil
	local p = pas()
	for i, m in ipairs(G.membres) do
		m:ClearAllPoints()
		m:SetPoint("TOPLEFT", conteneur, "TOPLEFT", 0, -(i - 1) * p)
		local f = m.familier
		UnregisterUnitWatch(f)
		if GetCVarBool("showPartyPets") then
			RegisterUnitWatch(f)
		else
			f:Hide()
		end
	end
	conteneur:SetHeight(4 * P.membreH + 3 * (p - P.membreH) + P.bas)
end

-- les cadres de groupe du client : sans evenement, et tenus caches par un
-- pilote d'etat (un Show venu d'ailleurs, meme en combat, est defait)
local function cacherClient()
	if InCombatLockdown() or G.clientCache then return end
	for i = 1, 4 do
		local f = _G["PartyMemberFrame" .. i]
		if f then
			f:UnregisterAllEvents()
			f:Hide()
			RegisterStateDriver(f, "visibility", "hide")
		end
	end
	if PartyMemberBackground then ForeverUI.Suppress(PartyMemberBackground) end
	G.clientCache = true
end

-- ---------------------------------------------------------------- les evenements

local function membreDe(unite)
	if not unite then return nil end
	local i = unite:match("^party(%d)$") or unite:match("^partypet(%d)$")
	return i and G.membres[tonumber(i)]
end

local veilleur = CreateFrame("Frame")
G.veilleur = veilleur
for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "PARTY_MEMBERS_CHANGED", "PARTY_LEADER_CHANGED",
	"PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_DISPLAYPOWER",
	"UNIT_MANA", "UNIT_RAGE", "UNIT_FOCUS", "UNIT_ENERGY", "UNIT_RUNIC_POWER", "UNIT_MAXMANA",
	"UNIT_MAXRAGE", "UNIT_MAXFOCUS", "UNIT_MAXENERGY", "UNIT_MAXRUNIC_POWER", "UNIT_NAME_UPDATE",
	"UNIT_PORTRAIT_UPDATE", "UNIT_AURA", "UNIT_PET", "UNIT_FACTION", "UNIT_THREAT_SITUATION_UPDATE",
	"UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "READY_CHECK", "READY_CHECK_CONFIRM",
	"READY_CHECK_FINISHED", "PLAYER_ROLES_ASSIGNED", "CVAR_UPDATE", "PLAYER_REGEN_ENABLED" }) do
	veilleur:RegisterEvent(ev)
end

local function tout()
	for _, m in ipairs(G.membres) do G.majMembre(m) end
end

veilleur:SetScript("OnEvent", function(self, ev, unite)
	if ev == "PLAYER_ENTERING_WORLD" then
		cacherClient()
		G.disposer()
		tout()
	elseif ev == "PLAYER_REGEN_ENABLED" then
		cacherClient()
		if G.aDisposer then G.disposer() end
	elseif ev == "PARTY_MEMBERS_CHANGED" or ev == "PARTY_LEADER_CHANGED" or ev == "PLAYER_ROLES_ASSIGNED" then
		tout()
	elseif ev == "CVAR_UPDATE" then
		G.disposer()
		tout()
	elseif ev == "READY_CHECK" or ev == "READY_CHECK_CONFIRM" then
		for _, m in ipairs(G.membres) do majAppel(m) end
	elseif ev == "READY_CHECK_FINISHED" then
		for _, m in ipairs(G.membres) do majAppel(m, true) end
		minuterie:Show()
	else
		local m = membreDe(unite)
		if m then G.majMembre(m) end
	end
end)

for _, m in ipairs(G.membres) do
	RegisterUnitWatch(m)
end

-- en groupe, pas en raid (ShouldShowPartyFrames)
RegisterStateDriver(conteneur, "visibility", "[group:raid] hide; [group] show; hide")

G.disposer()
ForeverUI.Layout.Register(conteneur, "partyframe", "Cadres de groupe", "TOPLEFT", "TOPLEFT", P.x, P.y)
