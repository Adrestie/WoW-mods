-- ForeverUI : l'onglet des competences.
--
-- RELEVE -- camelot/SkillsFrame.xml et skillsframe.lua, lus en entier. C'est
-- le meme ecran que la reputation, aux differences pres notees ci-dessous.
--
-- SkillsFrame          setAllPoints, parent CharacterFrame, useParentLevel
--   ScrollBox          TOPLEFT sur CharacterFrameLeftPaneHost (10, -40)
--                      BOTTOMRIGHT sur le meme (-25, 15), avec les deux
--                      traits UI-Character-Info-ScrollLine-Long centres sur
--                      son TOP et son BOTTOM
--   ScrollBar          MinimalScrollBar, TOPLEFT sur le TOPRIGHT du
--                      ScrollBox (5, -2), BOTTOMLEFT sur son BOTTOMRIGHT
--                      (5, 4)
--   SkillDetailFrame   CharacterFrameSidePaneTemplate, plus un RankBar
--
-- SetElementIndentCalculator et SetPadding : identiques a la reputation --
-- retraits 0 / 46 / 2, marges de 10, ecart de 3.
--
-- SkillsHeaderTemplate, hauteur 26 -- et non 28 comme la reputation :
--   fond        common-button-list-collapseExpand, etire sur la ligne
--   StateIcon   common-button-list-plus ou -minus, RIGHT (-8, -1)
--   nom         GameFontNormalLeft, hauteur 15, LEFT x = 10
--
-- SkillsSubHeaderTemplate, hauteur 22 :
--   son bouton  20 x 20, LEFT x = 2 -- et non ancre a une AccountWideIcon
--               comme celui de la reputation
--   nom         a +4 du bouton, jusqu'au LEFT de la barre moins 10
--
-- SkillsEntryTemplate, hauteur 30 :
--   barre       SkillsBarTemplate, RIGHT x = -3
--   nom         GameFontHighlight, hauteur 15, LEFT x = 2 -- il n'y a pas
--               d'AccountWideIcon ici, donc pas le 15 de la reputation
--   survol      les memes trois tranches, aux alphas de
--               RefreshBackgroundHighlightOpacity : 0 / 0,10 / 0,20. Pas de
--               cas "en guerre" : la teinte est toujours blanche.
--
-- SkillsBarTemplate, 160 x 29, herite de ColoredProgressBarTemplate :
--   InitializeBarForStandardSkill pose SetFillTextureByColorType(Blue) puis
--   UpdateBarColor(WHITE_FONT_COLOR). LA BARRE EST DONC BLEUE PAR SON
--   SPRITE, common-stat-bar-blue, et non par une teinte -- c'est tout ce qui
--   la distingue de celle de la reputation.
--   Son texte est TOUJOURS la progression : "rang / maximum", ou
--   "rang (+bonus) / maximum" quand il y a un bonus, celui-ci en vert.
--   TryShowBarProgressText est appele des l'initialisation, pas seulement au
--   survol.
--
-- SkillDetailFrameMixin : titre = le nom de la competence, RankBar de
-- 180 x 29 au TOP du BOTTOM du separateur (y = -6), et la description
-- reancree au TOP du BOTTOM du RankBar avec y = -8 -- et non -6 comme la
-- reputation. Sans competence choisie, le volet affiche
-- SKILL_DETAIL_SELECT_PROMPT.
--
-- SelectFirstSkillIfNoneSelected : a l'ouverture, si rien n'est choisi, la
-- premiere competence qui n'est pas un en-tete l'est -- "opening the tab
-- with an empty detail pane reads as broken", dit le commentaire de la
-- source.
--
-- CE QUE 3.3.5 DONNE. GetNumSkillLines et GetSkillLineInfo, qui rend treize
-- valeurs : nom, en-tete, deplie, rang, points temporaires, bonus, rang
-- maximal, abandonnable, cout d'un pas, cout d'un rang, niveau minimal, type
-- de cout, DESCRIPTION. ExpandSkillHeader et CollapseSkillHeader replient,
-- SetSelectedSkill et GetSelectedSkill choisissent.
--
-- CE QUI DIFFERE, ET POURQUOI :
--   * PAS DE SOUS-EN-TETE. GetSkillLineInfo ne rend pas d'indicateur
--     d'enfant : la hierarchie de 3.3.5 n'a qu'un niveau. Le gabarit existe
--     donc dans le releve mais ne sert pas ici.
--   * LES LIGNES D'ARMES ne sont pas detaillees. camelot ajoute au volet
--     droit le calcul des chances de toucher, de critique et de coup
--     glancant face a un boss ; il demande des chaines --
--     WEAPON_SKILL_DETAIL_* -- que ce client n'a pas. A faire si besoin.
--   * La description ne defile pas : ScrollingFontTemplate n'existe pas.
--   * La barre de defilement reste a faire ; la molette suffit d'ici la.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local LISTE_X, LISTE_Y = 10, -40
local LISTE_X2, LISTE_Y2 = -25, 15

local ENTREE_H = 30                     -- SkillsEntryTemplate
local ENTETE_H = 26                     -- SkillsHeaderTemplate
local MARGE = 10                        -- SetPadding
local ECART = 3                         -- elementSpacing
local RETRAIT_ENTETE = 0
local RETRAIT_AUTRE = 2

local BARRE_L, BARRE_H = 160, 29
local BARRE_X = -3
local REMPLISSAGE_H = 15
local NOM_H = 15
local NOM_X = 2                         -- SkillsEntryTemplate
local NOM_ECART = -10
local ENTETE_NOM_X = 10
local FLECHE_X, FLECHE_Y = -8, -1
local FLECHE_PLACE = 16
local COTE = 6

local PLAQUE_COIN = 12                  -- le meme que la reputation
local JAUGE_COIN = 10

local ATLAS_BARRE_FOND = "common-stat-bar-bg"
local ATLAS_ENTETE = "common-button-list-collapseexpand"
local ATLAS_PLUS = "common-button-list-plus"
local ATLAS_MOINS = "common-button-list-minus"
local ATLAS_TRAIT = "ui-character-info-scrollline-long"
local ATLAS_SURVOL_COTE = "charactercreate-customize-dropdown-linemouseover-side"
local ATLAS_SURVOL_MILIEU = "charactercreate-customize-dropdown-linemouseover-middle"
local ATLAS_SEPARATEUR = "ui-character-info-scrollline"

-- LE REMPLISSAGE BLEU, cuit au masque comme le blanc de la reputation :
-- meme decoupe que le fond, pour que les contours se superposent.
local CHEMIN_REMPLISSAGE = "Interface\\ForeverUI\\Bars\\statbarfillblue"

-- Le volet droit, CharacterFrameSidePaneTemplate.
local VOLET_DROIT_X, VOLET_DROIT_Y = 16, -14
local VOLET_DROIT_X2, VOLET_DROIT_Y2 = -12, 14
local TITRE_L = 195
local SOUS_TITRE_Y = -3
local SEPARATEUR_Y = -4
local RANG_L, RANG_H = 180, 29
local RANG_Y = -6
local DESCRIPTION_Y = -8                -- et non -6 : SkillDetailFrameMixin
local DESCRIPTION_X2 = -14
local DESCRIPTION_Y2 = 6

-- La taille du volet, par construction.
local VOLET_L, VOLET_H = 398, 464

local lignes = {}
local panneau, decalage = nil, 0
local visibles = 0
local choisie                            -- le NOM, seule cle stable
local detail, dernieresDonnees

-- --------------------------------------------------------------- les donnees

-- GetSkillLineInfo, dans l'ordre : nom, en-tete, deplie, rang, points
-- temporaires, bonus, rang maximal, abandonnable, cout d'un pas, cout d'un
-- rang, niveau minimal, type de cout, description.
local function lireCompetence(rang)
	local nom, entete, deplie, valeur, temporaires, bonus, maximum, _, _, _,
		_, _, description = GetSkillLineInfo(rang)
	if not nom or nom == "" then
		return nil
	end

	valeur = (valeur or 0) + (temporaires or 0)
	bonus = bonus or 0
	maximum = maximum or 0

	-- InitializeBarForStandardSkill : "rang / maximum", ou "rang (+bonus) /
	-- maximum" quand il y a un bonus, celui-ci en vert.
	local texte
	if bonus == 0 then
		texte = tostring(valeur) .. " / " .. tostring(maximum)
	else
		texte = tostring(valeur) .. " |cff00ff00(+" .. tostring(bonus)
			.. ")|r / " .. tostring(maximum)
	end

	return {
		index = rang,
		nom = nom,
		entete = entete,
		replie = (entete and not deplie) or false,
		valeur = valeur,
		maximum = maximum,
		texte = texte,
		description = description or "",
	}
end

local function indiceDe(nom)
	if not nom then
		return nil
	end
	for rang = 1, (GetNumSkillLines and GetNumSkillLines()) or 0 do
		if GetSkillLineInfo(rang) == nom then
			return rang
		end
	end
	return nil
end

-- --------------------------------------------------------------- une ligne

local function creerLigne(index, largeur)
	local ligne = CreateFrame("Button", "ForeverUISkillRow" .. index, panneau)
	ligne:SetWidth(largeur)
	ligne:SetHeight(ENTREE_H)

	ligne.plaque = ForeverUI.CreateNineSlice(ligne, ATLAS_ENTETE, PLAQUE_COIN,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	for _, tranche in ipairs(ligne.plaque) do
		tranche:Hide()
	end

	local survol = CreateFrame("Frame", nil, ligne)
	survol:SetAllPoints(ligne)
	survol:SetAlpha(0)
	ligne.survol = survol

	local gauche = survol:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(gauche, ATLAS_SURVOL_COTE, true)
	gauche:SetWidth(COTE)
	gauche:SetPoint("TOPLEFT", survol, "TOPLEFT", 0, 0)
	gauche:SetPoint("BOTTOMLEFT", survol, "BOTTOMLEFT", 0, 0)

	local droite = survol:CreateTexture(nil, "BACKGROUND")
	if ForeverUI.SetAtlas(droite, ATLAS_SURVOL_COTE, true) then
		local e = ForeverUI.AtlasEntry(ATLAS_SURVOL_COTE)
		droite:SetTexCoord(e[3], e[2], e[4], e[5])
	end
	droite:SetWidth(COTE)
	droite:SetPoint("TOPRIGHT", survol, "TOPRIGHT", 0, 0)
	droite:SetPoint("BOTTOMRIGHT", survol, "BOTTOMRIGHT", 0, 0)

	local milieu = survol:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(milieu, ATLAS_SURVOL_MILIEU, true)
	milieu:SetPoint("TOPLEFT", gauche, "TOPRIGHT", 0, 0)
	milieu:SetPoint("BOTTOMRIGHT", droite, "BOTTOMLEFT", 0, 0)

	local barre = CreateFrame("Frame", nil, ligne)
	barre:SetWidth(BARRE_L)
	barre:SetHeight(BARRE_H)
	barre:SetPoint("RIGHT", ligne, "RIGHT", BARRE_X, 0)
	ligne.barre = barre

	ForeverUI.CreateNineSlice(barre, ATLAS_BARRE_FOND, JAUGE_COIN,
		{ 0, 0, 0, 0 }, "BACKGROUND")

	barre.remplissage = barre:CreateTexture(nil, "BORDER")
	barre.remplissage:SetPoint("LEFT", barre, "LEFT", 0, 0)

	barre.texte = barre:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	barre.texte:SetPoint("LEFT", barre, "LEFT", 0, 0)
	barre.texte:SetPoint("RIGHT", barre, "RIGHT", 0, 0)
	barre.texte:SetJustifyH("CENTER")

	local nom = ligne:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	nom:SetHeight(NOM_H)
	nom:SetJustifyH("LEFT")
	ligne.nom = nom

	local fleche = ligne:CreateTexture(nil, "OVERLAY")
	fleche:SetPoint("RIGHT", ligne, "RIGHT", FLECHE_X, FLECHE_Y)
	fleche:Hide()
	ligne.fleche = fleche

	ligne:RegisterForClicks("LeftButtonUp")
	return ligne
end

-- ----------------------------------------------------------- le remplissage

-- SetFillPercent : largeur = fraction x largeur de barre, et la texture
-- rognee d'autant.
local function poserBarreDans(barre, donnees, largeur)
	local fraction = 0
	if donnees.maximum and donnees.maximum > 0 then
		fraction = donnees.valeur / donnees.maximum
	end
	if fraction < 0 then
		fraction = 0
	elseif fraction > 1 then
		fraction = 1
	end

	if fraction * largeur < 1 then
		barre.remplissage:Hide()
	else
		barre.remplissage:SetTexture(CHEMIN_REMPLISSAGE)
		barre.remplissage:SetTexCoord(0, fraction, 0, 1)
		barre.remplissage:SetWidth(largeur * fraction)
		barre.remplissage:SetHeight(REMPLISSAGE_H)
		barre.remplissage:Show()
	end

	barre.texte:SetText(donnees.texte or "")
end

-- RefreshBackgroundHighlightOpacity : ici sans le cas "en guerre", et la
-- teinte est toujours blanche.
local function poserSurvol(ligne)
	if ligne.entete then
		ligne.survol:SetAlpha(0)
		return
	end

	local dessus = ligne:IsMouseOver()
	ligne.survol:SetAlpha((ligne.choisie and 0.20) or (dessus and 0.10) or 0)
end

local function remplirLigne(ligne, donnees)
	ligne.skillIndex = donnees.index
	ligne.skillNom = donnees.nom
	ligne.entete = donnees.entete
	ligne.replie = donnees.replie

	ligne.nom:SetText(donnees.nom or "")
	ligne.nom:ClearAllPoints()

	for _, tranche in ipairs(ligne.plaque) do
		if donnees.entete then tranche:Show() else tranche:Hide() end
	end

	if donnees.entete then
		ligne:SetHeight(ENTETE_H)
		ligne.barre:Hide()
		ligne.nom:SetFontObject(GameFontNormalLeft or GameFontNormal)
		ligne.nom:SetPoint("LEFT", ligne, "LEFT", ENTETE_NOM_X, 0)
		ligne.nom:SetPoint("RIGHT", ligne, "RIGHT", FLECHE_X - FLECHE_PLACE, 0)

		ForeverUI.SetAtlas(ligne.fleche, donnees.replie and ATLAS_PLUS or ATLAS_MOINS)
		ligne.fleche:Show()
	else
		ligne:SetHeight(ENTREE_H)
		ligne.barre:Show()
		ligne.fleche:Hide()
		ligne.nom:SetFontObject(GameFontHighlight or GameFontNormal)
		ligne.nom:SetPoint("LEFT", ligne, "LEFT", NOM_X, 0)
		ligne.nom:SetPoint("RIGHT", ligne.barre, "LEFT", NOM_ECART, 0)
		poserBarreDans(ligne.barre, donnees, BARRE_L)
	end

	ligne.choisie = (choisie ~= nil and choisie == donnees.nom)
	poserSurvol(ligne)
	ligne:Show()
end

-- ------------------------------------------------------------- la mise en place

local function retraitDe(donnees)
	return donnees.entete and RETRAIT_ENTETE or RETRAIT_AUTRE
end

local function hauteurDe(donnees)
	return donnees.entete and ENTETE_H or ENTREE_H
end

-- L'ECRAN DU CLIENT SE TAIT EN ENTIER, A CHAQUE PASSAGE.
--
-- Il ne s'agit pas que de ses lignes. SkillFrame declare aussi un bouton de
-- tri, un bouton "tout replier", son cadre de depliage et ses trois tuiles,
-- deux boutons accepter / annuler, sa liste a ascenseur, et tout un cadre de
-- detail -- ScrollFrame, ScrollChildFrame, StatusBar. Les enumerer serait
-- une liste a tenir a jour et a oublier.
--
-- On masque donc TOUT ce que ce cadre porte et qui n'est pas a nous : ses
-- regions, et ses cadres fils sauf notre panneau. GetRegions ne rend que les
-- premieres, GetChildren que les seconds -- il faut les deux.
--
-- Et a chaque passage, parce que SkillFrame_UpdateSkills remontre les
-- siennes : les masquer une fois ne tient pas.
local function etoufferEcranDuClient()
	local cadre = _G["SkillFrame"]
	if not cadre then
		return
	end

	for _, region in ipairs({ cadre:GetRegions() }) do
		if region.Hide then
			region:Hide()
		end
	end

	if cadre.GetChildren then
		for _, fils in ipairs({ cadre:GetChildren() }) do
			if fils ~= panneau and fils.Hide then
				fils:Hide()
			end
		end
	end
end

local function disposer()
	local total = (GetNumSkillLines and GetNumSkillLines()) or 0

	local hauteurUtile = (panneau:GetHeight() or 0)
	if hauteurUtile < 50 then
		hauteurUtile = VOLET_H + LISTE_Y - LISTE_Y2
	end
	local largeurUtile = (panneau:GetWidth() or 0)
	if largeurUtile < 50 then
		largeurUtile = VOLET_L + LISTE_X2 - LISTE_X
	end

	local y = MARGE
	local posees = 0
	for rang, ligne in ipairs(lignes) do
		local index = decalage + rang
		local donnees = (index <= total) and lireCompetence(index) or nil
		local hauteur = donnees and hauteurDe(donnees) or 0
		if donnees and y + hauteur <= hauteurUtile - MARGE then
			local retrait = retraitDe(donnees)
			ligne:SetWidth(largeurUtile - 2 * MARGE - retrait)
			remplirLigne(ligne, donnees)
			ligne:ClearAllPoints()
			ligne:SetPoint("TOPLEFT", panneau, "TOPLEFT", MARGE + retrait, -y)
			y = y + hauteur + ECART
			posees = posees + 1
		else
			ligne:Hide()
		end
	end
	return posees
end

local function poserListe()
	if not panneau then
		return
	end

	etoufferEcranDuClient()

	local total = (GetNumSkillLines and GetNumSkillLines()) or 0
	local posees = disposer()

	if decalage > 0 and decalage + posees > total then
		decalage = math.max(0, total - posees)
		posees = disposer()
	end

	visibles = posees

	if ForeverUI.SkillsDetail then
		ForeverUI.SkillsDetail()
	end
end
ForeverUI.SkillsLayout = poserListe

-- --------------------------------------------------------------- le detail

local function viderDetail()
	detail.titre:SetText("")
	detail.sousTitre:SetText("")
	-- SKILL_DETAIL_SELECT_PROMPT n'existe pas en 3.3.5 : on laisse vide.
	detail.description:SetText("")
	detail.separateur:Hide()
	detail.jauge:Hide()
end

local function majDetail()
	if not detail then
		return
	end

	if not choisie then
		dernieresDonnees = nil
		viderDetail()
		return
	end

	local index = indiceDe(choisie)
	local donnees
	if index then
		if SetSelectedSkill and GetSelectedSkill and GetSelectedSkill() ~= index then
			SetSelectedSkill(index)
		end
		donnees = lireCompetence(index)
		dernieresDonnees = donnees
	else
		donnees = dernieresDonnees
	end

	if not donnees or donnees.entete then
		viderDetail()
		return
	end

	detail.titre:SetText(donnees.nom or "")
	detail.sousTitre:SetText("")
	detail.separateur:Show()
	detail.jauge:Show()
	poserBarreDans(detail.jauge, donnees, RANG_L)
	detail.description:SetText(donnees.description or "")
end
ForeverUI.SkillsDetail = majDetail

local function choisir(nom)
	choisie = nom
	local index = indiceDe(nom)
	if index and SetSelectedSkill then
		SetSelectedSkill(index)
	end
	poserListe()
end
ForeverUI.SkillsSelect = choisir

-- SelectFirstSkillIfNoneSelected : a l'ouverture, la premiere competence qui
-- n'est pas un en-tete est choisie -- un volet droit vide "reads as broken",
-- dit la source.
local function choisirLaPremiere()
	if choisie then
		return
	end
	for rang = 1, (GetNumSkillLines and GetNumSkillLines()) or 0 do
		local donnees = lireCompetence(rang)
		if donnees and not donnees.entete then
			choisir(donnees.nom)
			return
		end
	end
end

local function monterDetail(hote)
	if detail then
		return detail, {}
	end

	local cadre = CreateFrame("Frame", "ForeverUISkillDetail", hote)
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

	local jauge = CreateFrame("Frame", "ForeverUISkillRank", cadre)
	jauge:SetWidth(RANG_L)
	jauge:SetHeight(RANG_H)
	jauge:SetPoint("TOP", detail.separateur, "BOTTOM", 0, RANG_Y)
	ForeverUI.CreateNineSlice(jauge, ATLAS_BARRE_FOND, JAUGE_COIN,
		{ 0, 0, 0, 0 }, "BACKGROUND")
	jauge.remplissage = jauge:CreateTexture(nil, "BORDER")
	jauge.remplissage:SetPoint("LEFT", jauge, "LEFT", 0, 0)
	jauge.texte = jauge:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	jauge.texte:SetPoint("LEFT", jauge, "LEFT", 0, 0)
	jauge.texte:SetPoint("RIGHT", jauge, "RIGHT", 0, 0)
	jauge.texte:SetJustifyH("CENTER")
	detail.jauge = jauge

	-- La description, dans une boite : sans bas, un texte long disparait.
	detail.description = cadre:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	detail.description:SetPoint("TOPLEFT", jauge, "BOTTOMLEFT", 0, DESCRIPTION_Y)
	detail.description:SetPoint("TOPRIGHT", jauge, "BOTTOMRIGHT", 0, DESCRIPTION_Y)
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

-- --------------------------------------------------------- la construction

local function suivreSurvol()
	for _, ligne in ipairs(lignes) do
		if ligne:IsShown() and not ligne.entete then
			poserSurvol(ligne)
		end
	end
end

local function monter(hote)
	local cadre = _G["SkillFrame"]
	if not cadre or not hote then
		return nil, {}
	end

	cadre:ClearAllPoints()
	cadre:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, 0)
	cadre:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", 0, 0)

	if panneau then
		choisirLaPremiere()
		return nil, { cadre }
	end

	-- L'art et les lignes de 3.3.5 s'en vont : on ne garde que le cadre.
	if cadre.SetBackdrop then
		cadre:SetBackdrop(nil)
	end

	local hauteur = hote:GetHeight() or 0
	if hauteur < 100 then
		hauteur = VOLET_H
	end
	local largeur = hote:GetWidth() or 0
	if largeur < 100 then
		largeur = VOLET_L
	end
	largeur = largeur + LISTE_X2 - LISTE_X

	panneau = CreateFrame("Frame", "ForeverUISkillList", cadre)
	panneau:SetPoint("TOPLEFT", hote, "TOPLEFT", LISTE_X, LISTE_Y)
	panneau:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", LISTE_X2, LISTE_Y2)
	panneau:SetWidth(largeur)

	local place = math.floor((hauteur + LISTE_Y - LISTE_Y2) / (ENTETE_H + ECART))
	if place < 1 then
		place = 1
	end
	for index = 1, place do
		local ligne = creerLigne(index, largeur)
		ligne:SetScript("OnClick", function(self)
			if not self.skillIndex then
				return
			end
			if self.entete then
				if self.replie then
					ExpandSkillHeader(self.skillIndex)
				else
					CollapseSkillHeader(self.skillIndex)
				end
				poserListe()
			else
				ForeverUI.SkillsSelect(self.skillNom)
			end
		end)
		lignes[index] = ligne
	end

	-- LES DEUX TRAITS VIVENT SUR NOTRE PANNEAU, et non sur le cadre du
	-- client : celui-ci voit toutes ses regions masquees a chaque passage,
	-- sans condition, et les notres y auraient disparu avec.
	local haut = panneau:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(haut, ATLAS_TRAIT)
	haut:SetPoint("CENTER", panneau, "TOP", 0, 0)

	local bas = panneau:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(bas, ATLAS_TRAIT)
	bas:SetPoint("CENTER", panneau, "BOTTOM", 0, 0)

	panneau:SetScript("OnUpdate", suivreSurvol)
	panneau:EnableMouseWheel(true)
	panneau:SetScript("OnMouseWheel", function(self, sens)
		local total = (GetNumSkillLines and GetNumSkillLines()) or 0
		decalage = math.max(0, math.min(decalage - sens, total - visibles))
		poserListe()
	end)

	poserListe()
	choisirLaPremiere()
	return nil, { cadre }
end

ForeverUI.SkillsTab = { Build = monter, BuildRight = monterDetail, Rows = lignes }

-- TEMOIN -- /fui skills.
function ForeverUI.SkillsDebug()
	local dire = function(texte)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. texte)
	end

	local total = (GetNumSkillLines and GetNumSkillLines()) or 0
	dire(string.format("competences : %d lignes du client, decalage %d, %d posees, choisie=%s",
		total, decalage, visibles, tostring(choisie)))
	for rang = 1, total do
		local d = lireCompetence(rang)
		if d then
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"   %2d %-28s entete=%-5s replie=%-5s %s",
				rang, d.nom, tostring(d.entete), tostring(d.replie), d.texte))
		end
	end
end

-- Le client refait sa liste dans SkillFrame_UpdateSkills : on passe apres.
if hooksecurefunc and type(_G["SkillFrame_UpdateSkills"]) == "function" then
	hooksecurefunc("SkillFrame_UpdateSkills", poserListe)
end
