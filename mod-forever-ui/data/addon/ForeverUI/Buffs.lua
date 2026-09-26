-- ForeverUI : les barres d'ameliorations et d'affaiblissements, a la DA de
-- camelot (demande de l'utilisateur, 2026-09-26 ; memoire foreverui-buffs).
--
-- RELEVE -- blizzard_buffframe (buffframe.lua, buffframe.xml,
-- buffframetemplates.xml : pas de variante camelot/ ni mainline/, le .toc les
-- charge tels quels), blizzard_framexmlutil (aurautil.lua et
-- mainline/aurautil.lua, [Family]), blizzard_editmode (mainline/
-- editmodepresetlayouts.lua, [Family] : la disposition « moderne ») :
--   bouton       AuraButtonArtTemplate, 30 x 40 : icone 30 x 30 a TOP, duree
--                GameFontNormalSmall sous l'icone (cachee sans duree) ;
--                OVERLAY : bordure d'affaiblissement 40 x 40 et bordure
--                d'enchantement UI-TempEnchant-Border 32 x 32 centrees sur
--                l'icone, symbole TextStatusBarText TOPLEFT (2,-2) (mode
--                daltonien), piles NumberFontNormal BOTTOMRIGHT de l'icone
--                (-2,2)
--   grille       AuraContainerMixin : de droite a gauche puis vers le bas,
--                espacement 5 entre les icones -- une colonne tous les 35,
--                une rangee tous les 45 ; chaque bouton pose son TOPRIGHT sur
--                le TOPRIGHT du conteneur
--   ameliorations  TOPRIGHT de l'ecran (-255,-10), 11 par rangee, 32 au plus ;
--                le bouton de repli (15 x 30, fleche bag-arrow 10 x 16,
--                surbrillance a 0,4 en ADD) a TOPRIGHT, le conteneur sur son
--                TOPLEFT ; taille (35 x 11 + 15) x (45 x 3)
--   affaiblissements  TOPRIGHT de l'ecran (-270,-155), 8 par rangee, 16 au
--                plus, seuls les affaiblissements presents sont ranges ;
--                bordure par type AVEC son icone (ShowDispelType = 1) :
--                ui-debuff-border-<type>-icon, et -default-noicon sans type
--   clignotement AuraContainerWarningFader : sous 31 s, l'icone va et vient
--                entre 0,3 et 1 en 1,5 s (aller 0,75 s, retour 0,75 s)
--   duree        SecondsToTimeAbbrev ; blanche sous 90 s
--                (BUFF_DURATION_WARNING_TIME de camelot), jaune au-dessus ;
--                affichee si l'option « durees » est cochee
--   repli        une amelioration sans duree, ou a plus de 90 s, se cache
--                quand la barre est repliee ; elle « retombe » dans la barre
--                a 90 s (verification toutes les 0,2 s). Le bouton ne
--                paraît que s'il y a de quoi cacher ; depliee au chargement
--   regroupement si l'option « regrouper » est cochee, le repli s'efface et
--                ces memes ameliorations passent dans une icone
--                (BuffConsolidation, coordonnees de camelot) dont le survol
--                ouvre une bulle : 5 par rangee, a l'echelle 0,8, en (16,-16),
--                marges 9 a droite et 2 en bas
--   enchantements  d'arme, AVANT les ameliorations, bordure
--                UI-TempEnchant-Border ; clic droit pour annuler
--   infobulle    ANCHOR_BOTTOMLEFT, un cran au-dessus du bouton ; clic droit
--                sur une amelioration pour l'annuler
--
-- CE QUI VIENT DE 3.3.5 : les donnees (UnitAura, GetWeaponEnchantInfo), les
-- options de l'interface (SHOW_BUFF_DURATIONS, CONSOLIDATE_BUFFS,
-- ENABLE_COLORBLIND_MODE) et leurs changements (BuffFrame_UpdatePositions,
-- BuffFrame_Update, qu'on accroche), l'annulation (CancelUnitBuff,
-- CancelItemTempEnchantment -- libres en 3.3.5, ils ne deviennent proteges
-- qu'avec 4.0). Le BuffFrame du client, ses enchantements et son
-- regroupement sont etouffes. PlayerFrame est etouffe lui aussi :
-- PlayerFrame.unit ne suit plus le vehicule, on le calcule comme le cadre
-- joueur (UnitHasVehicleUI).
--
-- ABSENT DE 3.3.5, donc absent ici : les defenses externes
-- (ExternalDefensivesFrame), les affaiblissements mortels
-- (DeadlyDebuffFrame), les auras privees, le type « Bleed ». Le bouton de
-- repli n'a pas d'option dans 3.3.5 (collapseExpandBuffs) : il est actif
-- tant que le regroupement ne l'est pas, comme dans camelot. La bulle du
-- regroupement prend le fond des infobulles de 3.3.5, comme GameTooltip.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local B = {}
ForeverUI.Buffs = B

local SEP = string.char(92)

local G = {
	largeur = 30, hauteur = 40, icone = 30,
	bordure = 40, bordureEnchant = 32,
	espace = 5,
	repliL = 15, repliH = 30, flecheL = 10, flecheH = 16, surbrillance = 0.4,
	alerte = 31, alerteDuree = 90,
	periode = 1.5, alphaMin = 0.3, alphaMax = 1,
	verifier = 0.2, infobulle = 0.2,
	bulleParLigne = 5, bulleEchelle = 0.8, bulleMarge = 16, bulleDroite = 9, bulleBas = 2,
	bulleSortie = 10,
}

local BARRES = {
	buffs = { nom = "ForeverUIBuffFrame", filtre = "HELPFUL", max = 32, parLigne = 11,
		x = -255, y = -10, libelle = "Améliorations" },
	debuffs = { nom = "ForeverUIDebuffFrame", filtre = "HARMFUL", max = 16, parLigne = 8,
		x = -270, y = -155, libelle = "Affaiblissements", typeVisible = true },
}

-- la bordure par type (DEBUFF_DISPLAY_INFO de camelot)
local TYPES = {
	Magic = { "ui-debuff-border-magic-noicon", "ui-debuff-border-magic-icon", "DEBUFF_SYMBOL_MAGIC" },
	Curse = { "ui-debuff-border-curse-noicon", "ui-debuff-border-curse-icon", "DEBUFF_SYMBOL_CURSE" },
	Disease = { "ui-debuff-border-disease-noicon", "ui-debuff-border-disease-icon", "DEBUFF_SYMBOL_DISEASE" },
	Poison = { "ui-debuff-border-poison-noicon", "ui-debuff-border-poison-icon", "DEBUFF_SYMBOL_POISON" },
	None = { "ui-debuff-border-default-noicon" },
}

local ENCHANT_BORDURE = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-TempEnchant-Border"
local REGROUPEMENT = "Interface" .. SEP .. "Buttons" .. SEP .. "BuffConsolidation"

-- ------------------------------------------------------------ les options

local function durees() return SHOW_BUFF_DURATIONS == "1" end
local function regrouper() return CONSOLIDATE_BUFFS == "1" end
local function daltonien() return ENABLE_COLORBLIND_MODE == "1" end
-- camelot : repli et regroupement s'excluent
local function repliActif() return not regrouper() end

-- l'unite affichee : le vehicule quand on le pilote
function B.unite()
	if UnitHasVehicleUI and UnitHasVehicleUI("player") and UnitExists("vehicle") then
		return "vehicle"
	end
	return "player"
end

-- ------------------------------------------------------------ le clignotement

-- un aller-retour de 1,5 s entre 0,3 et 1, commun a toutes les icones
function B.alphaAlerte(reste)
	if reste and reste < G.alerte then
		local demi = G.periode / 2
		local t = (GetTime() or 0) % G.periode
		local p = (t < demi) and (t / demi) or ((G.periode - t) / demi)
		return G.alphaMin + (G.alphaMax - G.alphaMin) * p
	end
	return G.alphaMax
end

-- ------------------------------------------------------------ un bouton

local function filtreDe(b)
	if b.auraType == "Buff" or b.auraType == "TempEnchant" then return "HELPFUL" end
	if b.auraType == "Debuff" then return "HARMFUL" end
end

local function infobulle(b)
	if b.auraType == "TempEnchant" then
		GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetInventoryItem("player", b.info.ID)
		return
	end
	GameTooltip:SetOwner(b, "ANCHOR_BOTTOMLEFT")
	GameTooltip:SetFrameLevel(b:GetFrameLevel() + 2)
	GameTooltip:SetUnitAura(b.unite, b.info.index, filtreDe(b))
end

local function majDuree(b, reste)
	local montrer = reste and durees()
	if montrer then
		b.Duration:SetFormattedText(SecondsToTimeAbbrev(reste))
		local c = (reste < G.alerteDuree) and HIGHLIGHT_FONT_COLOR or NORMAL_FONT_COLOR
		b.Duration:SetVertexColor(c.r, c.g, c.b)
		b.Duration:Show()
	else
		b.Duration:Hide()
	end
end

local function surMaj(b, ecoule)
	if not b.info then return end
	if b.auraType == "TempEnchant" and B.unite() ~= "player" then
		b:Hide()
		return
	end
	b:SetAlpha(B.alphaAlerte(b.reste))
	b.reste = math.max((b.info.expirationTime or 0) - GetTime(), 0)
	majDuree(b, b.reste)
	b.tempsBulle = (b.tempsBulle or 0) - (ecoule or 0)
	if b.tempsBulle <= 0 then
		b.tempsBulle = G.infobulle
		if GameTooltip:IsOwned(b) then infobulle(b) end
	end
end

local function poserType(b, auraType)
	b.auraType = auraType
	b.Symbol:Hide()
	if auraType == "Buff" then
		b.DebuffBorder:Hide()
		b.TempEnchantBorder:Hide()
	elseif auraType == "Debuff" then
		ForeverUI.SetAtlas(b.DebuffBorder, TYPES.None[1])
		b.DebuffBorder:Show()
		b.TempEnchantBorder:Hide()
	elseif auraType == "TempEnchant" then
		b.DebuffBorder:Hide()
		b.TempEnchantBorder:Show()
	end
end

local function poserExpiration(b, info)
	if info.expirationTime and info.expirationTime > 0 then
		if durees() then b.Duration:Show() else b.Duration:Hide() end
		b.reste = info.expirationTime - GetTime()
		b:SetScript("OnUpdate", surMaj)
	else
		b.Duration:Hide()
		b:SetScript("OnUpdate", nil)
		b.reste = nil
		b:SetAlpha(1)
	end
end

-- AuraButtonMixin:Update
function B.remplir(b, info, typeVisible)
	poserType(b, info.auraType)
	b.info = info
	b.unite = B.unite()
	if info.auraType == "Debuff" then
		local t = TYPES[info.debuffType or ""] or TYPES.None
		ForeverUI.SetAtlas(b.DebuffBorder, (typeVisible and t[2]) or t[1])
		if daltonien() and t[3] then
			b.Symbol:SetText(_G[t[3]] or "")
			b.Symbol:Show()
		end
	end
	poserExpiration(b, info)
	b.Icon:SetTexture(info.texture)
	if (info.count or 0) > 1 then
		b.Count:SetText(info.count)
		b.Count:Show()
	else
		b.Count:Hide()
	end
	if GameTooltip:IsOwned(b) then infobulle(b) end
end

function B.creerBouton(parent, nom)
	local b = CreateFrame("Button", nom, parent)
	b:SetWidth(G.largeur)
	b:SetHeight(G.hauteur)
	b.Icon = b:CreateTexture(nil, "BACKGROUND")
	b.Icon:SetWidth(G.icone)
	b.Icon:SetHeight(G.icone)
	b.Icon:SetPoint("TOP", b, "TOP", 0, 0)
	b.Duration = b:CreateFontString(nil, "BACKGROUND", "GameFontNormalSmall")
	b.Duration:SetPoint("TOP", b.Icon, "BOTTOM", 0, 0)
	b.Duration:Hide()
	b.DebuffBorder = b:CreateTexture(nil, "OVERLAY")
	b.DebuffBorder:SetWidth(G.bordure)
	b.DebuffBorder:SetHeight(G.bordure)
	b.DebuffBorder:SetPoint("CENTER", b.Icon, "CENTER", 0, 0)
	b.TempEnchantBorder = b:CreateTexture(nil, "OVERLAY")
	b.TempEnchantBorder:SetTexture(ENCHANT_BORDURE)
	b.TempEnchantBorder:SetWidth(G.bordureEnchant)
	b.TempEnchantBorder:SetHeight(G.bordureEnchant)
	b.TempEnchantBorder:SetPoint("CENTER", b.Icon, "CENTER", 0, 0)
	b.Symbol = b:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
	b.Symbol:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
	b.Count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
	b.Count:SetPoint("BOTTOMRIGHT", b.Icon, "BOTTOMRIGHT", -2, 2)
	poserType(b, nil)
	b:RegisterForClicks("RightButtonUp")
	b:SetScript("OnClick", function(self, bouton)
		if bouton ~= "RightButton" or not self.info then return end
		if self.auraType == "Buff" then
			CancelUnitBuff(self.unite, self.info.index, "HELPFUL")
		elseif self.auraType == "TempEnchant" then
			CancelItemTempEnchantment(self.info.ID == 16 and 1 or 2)
		end
	end)
	b:SetScript("OnEnter", function(self) if self.info then infobulle(self) end end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:Hide()
	return b
end

-- ------------------------------------------------------------ la grille

-- de droite a gauche puis vers le bas ; ranges = les boutons a poser
local function ranger(conteneur, boutons, parLigne)
	for i, b in ipairs(boutons) do
		local col, ligne = (i - 1) % parLigne, math.floor((i - 1) / parLigne)
		b:ClearAllPoints()
		b:SetPoint("TOPRIGHT", conteneur, "TOPRIGHT",
			-col * (G.largeur + G.espace), -ligne * (G.hauteur + G.espace))
	end
end

-- ------------------------------------------------------------ une barre

local function creerBarre(cle)
	local c = BARRES[cle]
	local f = CreateFrame("Frame", c.nom, UIParent)
	f:SetFrameStrata("LOW")
	f.cle, f.c = cle, c
	f.conteneur = CreateFrame("Frame", nil, f)
	f.conteneur:SetWidth(1)
	f.conteneur:SetHeight(1)
	f.boutons = {}
	for i = 1, c.max do
		f.boutons[i] = B.creerBouton(f.conteneur, c.nom .. "Button" .. i)
	end
	local lignes = math.ceil(c.max / c.parLigne)
	local largeur = (G.largeur + G.espace) * c.parLigne
	if cle == "buffs" then largeur = largeur + G.repliL end
	f:SetWidth(largeur)
	f:SetHeight((G.hauteur + G.espace) * lignes)
	f.auras = {}
	return f
end

-- le bouton de repli : bag-arrow, retourne quand la barre est depliee
local function orienterFleche(t, retourne)
	local e = ForeverUI.AtlasEntry("bag-arrow")
	if not e then return end
	t:SetTexture(e[1])
	local u1, u2, v1, v2 = e[2], e[3], e[4], e[5]
	if retourne then
		t:SetTexCoord(u2, v2, u2, v1, u1, v2, u1, v1)
	else
		t:SetTexCoord(u1, v1, u1, v2, u2, v1, u2, v2)
	end
end

function B.orienterRepli()
	local r = B.buffs.repli
	-- les icones vont vers la gauche : depliee, la fleche est retournee (pi)
	local deplie = r:GetChecked() and true or false
	for _, t in ipairs({ r:GetNormalTexture(), r:GetPushedTexture(), r:GetHighlightTexture() }) do
		orienterFleche(t, deplie)
	end
end

local function creerRepli(f)
	local r = CreateFrame("CheckButton", f.c.nom .. "CollapseAndExpandButton", f)
	r:SetWidth(G.repliL)
	r:SetHeight(G.repliH)
	r:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
	local e = ForeverUI.AtlasEntry("bag-arrow")
	r:SetNormalTexture(e and e[1] or "")
	r:SetPushedTexture(e and e[1] or "")
	r:SetHighlightTexture(e and e[1] or "", "ADD")
	for _, t in ipairs({ r:GetNormalTexture(), r:GetPushedTexture(), r:GetHighlightTexture() }) do
		t:ClearAllPoints()
		t:SetWidth(G.flecheL)
		t:SetHeight(G.flecheH)
		t:SetPoint("CENTER", r, "CENTER", 0, 0)
	end
	r:GetHighlightTexture():SetAlpha(G.surbrillance)
	r:SetChecked(true)
	r:SetScript("OnClick", function(self)
		B.deplie = self:GetChecked() and true or false
		B.orienterRepli()
		B.maj()
	end)
	f.repli = r
	f.conteneur:SetPoint("TOPRIGHT", r, "TOPLEFT", 0, 0)
	return r
end

-- l'icone du regroupement et sa bulle
local function creerRegroupement(f)
	local b = B.creerBouton(f.conteneur, f.c.nom .. "ConsolidatedBuffs")
	poserType(b, "Buff")
	b.Icon:SetTexture(REGROUPEMENT)
	b.Icon:SetTexCoord(0.109375, 0.390625, 0.21875, 0.78125)
	b:SetScript("OnClick", nil)
	b:SetScript("OnLeave", nil)
	b.nombre = 0

	local bulle = CreateFrame("Frame", f.c.nom .. "ConsolidatedBuffsTooltip", b)
	bulle:SetFrameStrata("TOOLTIP")
	bulle:SetClampedToScreen(true)
	bulle:SetPoint("TOPLEFT", b.Icon, "BOTTOMLEFT", 0, 0)
	bulle:SetBackdrop({
		bgFile = "Interface" .. SEP .. "Tooltips" .. SEP .. "UI-Tooltip-Background",
		edgeFile = "Interface" .. SEP .. "Tooltips" .. SEP .. "UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 16,
		insets = { left = 4, right = 4, top = 4, bottom = 4 },
	})
	bulle:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
	bulle:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
	bulle:Hide()
	local auras = CreateFrame("Frame", nil, bulle)
	auras:SetScale(G.bulleEchelle)
	auras:SetPoint("TOPLEFT", bulle, "TOPLEFT", G.bulleMarge, -G.bulleMarge)
	auras:SetWidth(1)
	auras:SetHeight(1)
	bulle.auras = auras
	bulle.boutons = {}
	for i = 1, BARRES.buffs.max do
		bulle.boutons[i] = B.creerBouton(auras, f.c.nom .. "ConsolidatedBuffsTooltipButton" .. i)
	end
	bulle:SetScript("OnUpdate", function(self)
		local m = G.bulleSortie
		if not self:IsMouseOver(m, -m, -m, m) and not b:IsMouseOver(m, -m, -m, m) then
			self:Hide()
		end
	end)
	b:SetScript("OnEnter", function() B.remplirBulle(); bulle:Show() end)
	b:SetScript("OnHide", function() bulle:Hide() end)
	b.bulle = bulle
	f.regroupement = b
	return b
end

-- la bulle : les ameliorations cachees, 5 par rangee de gauche a droite
function B.remplirBulle()
	local b = B.buffs.regroupement
	local bulle = b.bulle
	local n = 0
	for _, info in ipairs(B.buffs.auras) do
		if info.cachable then
			n = n + 1
			local bouton = bulle.boutons[n]
			if not bouton then break end
			B.remplir(bouton, info)
			bouton:Show()
			local col, ligne = (n - 1) % G.bulleParLigne, math.floor((n - 1) / G.bulleParLigne)
			bouton:ClearAllPoints()
			bouton:SetPoint("TOPLEFT", bulle.auras, "TOPLEFT",
				col * (G.largeur + G.espace), -ligne * (G.hauteur + G.espace))
		end
	end
	for i = n + 1, #bulle.boutons do
		bulle.boutons[i].info = nil
		bulle.boutons[i]:Hide()
	end
	local l = (G.largeur + G.espace) * math.min(G.bulleParLigne, n)
	local h = (G.hauteur + G.espace) * math.ceil(n / G.bulleParLigne)
	bulle:SetWidth((G.bulleMarge + l) * G.bulleEchelle + G.bulleDroite)
	bulle:SetHeight((G.bulleMarge + h) * G.bulleEchelle + G.bulleBas)
end

-- ------------------------------------------------------------ les donnees

-- les enchantements d'arme : main droite, puis main gauche
local function enchantements(liste)
	local maintenant = GetTime()
	local aMain, expMain, chMain, aGauche, expGauche, chGauche = GetWeaponEnchantInfo()
	for _, e in ipairs({ { aMain, expMain, chMain, 16 }, { aGauche, expGauche, chGauche, 17 } }) do
		if e[1] then
			local reste = (e[2] or 0) / 1000
			local info = {
				auraType = "TempEnchant",
				texture = GetInventoryItemTexture("player", e[4]),
				count = e[3] or 0,
				expirationTime = maintenant + reste,
				ID = e[4],
			}
			info.cachable = reste > G.alerteDuree
			table.insert(liste, info)
		end
	end
end

local function auras(unite, filtre, max, liste)
	local maintenant = GetTime()
	for i = 1, max do
		local nom, _, icone, piles, typeDissip, duree, expiration = UnitAura(unite, i, filtre)
		if not nom then break end
		local info = {
			auraType = (filtre == "HELPFUL") and "Buff" or "Debuff",
			index = i,
			texture = icone,
			count = piles or 0,
			debuffType = typeDissip,
			duration = duree or 0,
			expirationTime = expiration or 0,
		}
		if filtre == "HELPFUL" then
			info.cachable = (info.duration == 0) or (info.expirationTime == 0)
				or ((info.expirationTime - maintenant) > G.alerteDuree)
		end
		table.insert(liste, info)
	end
end

-- ------------------------------------------------------------ la mise a jour

B.deplie = true

local function deplie()
	if repliActif() then return B.deplie end
	return false
end

function B.majBuffs()
	local f = B.buffs
	local liste = {}
	if B.unite() == "player" then enchantements(liste) end
	auras(B.unite(), "HELPFUL", f.c.max, liste)
	f.auras = liste
	local cachables = 0
	for _, info in ipairs(liste) do
		if info.cachable then cachables = cachables + 1 end
	end
	f.cachables = cachables
	-- le regroupement
	local r = f.regroupement
	r.nombre = cachables
	r.Count:SetText(cachables)
	local avecRegroupement = regrouper() and cachables > 0
	if avecRegroupement then r:Show() else r:Hide() end
	-- les boutons
	local ouvert = deplie()
	local suivant = 1
	for _, b in ipairs(f.boutons) do
		local info
		while suivant <= #liste do
			local candidat = liste[suivant]
			suivant = suivant + 1
			if ouvert or not candidat.cachable then
				info = candidat
				break
			end
		end
		if info then
			B.remplir(b, info)
			b:Show()
		else
			b.info = nil
			b:SetScript("OnUpdate", nil)
			b:Hide()
		end
	end
	local ranges = {}
	if avecRegroupement then table.insert(ranges, r) end
	for _, b in ipairs(f.boutons) do table.insert(ranges, b) end
	ranger(f.conteneur, ranges, f.c.parLigne)
	-- le repli : seulement s'il y a de quoi cacher
	if repliActif() and cachables > 0 then f.repli:Show() else f.repli:Hide() end
	f.repli:SetChecked(B.deplie)
	B.orienterRepli()
	if r.bulle:IsShown() then B.remplirBulle() end
	-- la verification des ameliorations qui retombent
	f.attente = (not ouvert and cachables > 0) and G.verifier or nil
end

function B.majDebuffs()
	local f = B.debuffs
	local liste = {}
	auras(B.unite(), "HARMFUL", f.c.max, liste)
	f.auras = liste
	local ranges = {}
	for i, b in ipairs(f.boutons) do
		local info = liste[i]
		if info then
			B.remplir(b, info, f.c.typeVisible)
			b:Show()
			table.insert(ranges, b)
		else
			b.info = nil
			b:SetScript("OnUpdate", nil)
			b:Hide()
		end
	end
	ranger(f.conteneur, ranges, f.c.parLigne)
end

function B.maj()
	B.majBuffs()
	B.majDebuffs()
end

-- ------------------------------------------------------------ la construction

B.buffs = creerBarre("buffs")
B.debuffs = creerBarre("debuffs")
creerRepli(B.buffs)
creerRegroupement(B.buffs)
B.orienterRepli()
B.debuffs.conteneur:SetPoint("TOPRIGHT", B.debuffs, "TOPRIGHT", 0, 0)

for _, cle in ipairs({ "buffs", "debuffs" }) do
	local c = BARRES[cle]
	ForeverUI.Layout.Register(B[cle], cle, c.libelle, "TOPRIGHT", "TOPRIGHT", c.x, c.y)
end

-- le BuffFrame du client, ses enchantements, son regroupement
for _, nom in ipairs({ "BuffFrame", "TemporaryEnchantFrame", "ConsolidatedBuffs", "ConsolidatedBuffsTooltip" }) do
	ForeverUI.Suppress(_G[nom])
end

-- les options de l'interface (durees, regroupement) passent par ces deux-la
if BuffFrame_UpdatePositions then hooksecurefunc("BuffFrame_UpdatePositions", function() B.maj() end) end
if BuffFrame_Update then hooksecurefunc("BuffFrame_Update", function() B.maj() end) end

local veille = CreateFrame("Frame")
veille:RegisterEvent("UNIT_AURA")
veille:RegisterEvent("PLAYER_ENTERING_WORLD")
veille:RegisterEvent("UNIT_ENTERED_VEHICLE")
veille:RegisterEvent("UNIT_EXITED_VEHICLE")
veille:SetScript("OnEvent", function(self, evenement, unite)
	if evenement == "UNIT_AURA" then
		if unite == B.unite() then B.maj() end
	elseif evenement == "PLAYER_ENTERING_WORLD" or unite == "player" then
		B.maj()
	end
end)

-- toutes les 0,2 s : les enchantements d'arme (3.3.5 n'a pas d'evenement,
-- son TemporaryEnchantFrame les lit a chaque image) et les ameliorations
-- qui retombent dans la barre repliee
local function signatureEnchants()
	if B.unite() ~= "player" then return "" end
	local a, _, ca, g, _, cg = GetWeaponEnchantInfo()
	return tostring(a) .. ":" .. tostring(ca) .. ":" .. tostring(GetInventoryItemTexture("player", 16))
		.. "|" .. tostring(g) .. ":" .. tostring(cg) .. ":" .. tostring(GetInventoryItemTexture("player", 17))
end

veille.temps = 0
veille:SetScript("OnUpdate", function(self, ecoule)
	self.temps = self.temps - (ecoule or 0)
	if self.temps > 0 then return end
	self.temps = G.verifier
	local s = signatureEnchants()
	if s ~= self.enchants then
		self.enchants = s
		B.maj()
		return
	end
	local f = B.buffs
	if f.attente then
		local maintenant = GetTime()
		for _, info in ipairs(f.auras) do
			if info.cachable and info.expirationTime and info.expirationTime > 0
				and (info.expirationTime - maintenant) <= G.alerteDuree then
				B.maj()
				return
			end
		end
	end
end)
B.veille = veille

B.maj()

-- TEMOIN -- /fui buffs
function ForeverUI.BuffsDebug()
	local dire = function(t) DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t) end
	local f = B.buffs
	local montres = 0
	for _, b in ipairs(f.boutons) do if b:IsShown() then montres = montres + 1 end end
	dire(string.format("ameliorations : unite %s, %d auras, %d cachables, %d montrees | repli %s (deplie %s) | regroupement %s (%d) | durees %s",
		B.unite(), #f.auras, f.cachables or 0, montres, f.repli:IsShown() and "visible" or "cache", tostring(B.deplie),
		f.regroupement:IsShown() and "visible" or "cache", f.regroupement.nombre or 0, tostring(durees())))
	local d = B.debuffs
	local types = {}
	for _, info in ipairs(d.auras) do table.insert(types, tostring(info.debuffType or "aucun")) end
	dire(string.format("affaiblissements : %d (%s)", #d.auras, table.concat(types, ", ")))
end
