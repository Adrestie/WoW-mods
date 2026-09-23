-- ForeverUI : l'onglet de reputation.
--
-- POURQUOI NOS PROPRES LIGNES, ET NON CELLES DU CLIENT.
--
-- Premiere tentative : reposer et rhabiller les quinze ReputationBar<i> de
-- 3.3.5. Elle a echoue trois fois de suite, toujours de la meme facon --
-- ReputationFrame_Update ne se contente pas de remplir, il REPOSE son art a
-- chaque passage : SetNormalTexture sur les boutons, les AtWarHighlight
-- additifs, les traits d'arborescence, la texture de la StatusBar. Chaque
-- correction tenait jusqu'au passage suivant, et le clic en declenchait un.
--
-- Les lignes sont donc les NOTRES, baties d'apres les gabarits de camelot et
-- remplies depuis GetFactionInfo -- la seule chose que 3.3.5 apporte ici, et
-- la seule dont on ait besoin. Le ReputationFrame du client ne sert plus que
-- de support ; ses lignes sont retirees.
--
-- RELEVE -- camelot/ReputationFrame.xml et reputationframe.lua.
--
-- La liste, dans le volet gauche :
--   TOPLEFT sur CharacterFrameLeftPaneHost (10, -40)
--   BOTTOMRIGHT sur le meme (-25, 15)
--   deux traits UI-Character-Info-ScrollLine-Long, centres sur son TOP et
--   sur son BOTTOM
--
-- ReputationHeaderTemplate, hauteur 28 :
--   fond        common-button-list-collapseExpand, sans ancrage donc etire
--               sur toute la ligne
--   StateIcon   common-button-list-plus ou -minus, RIGHT (-8, -1)
--   nom         GameFontNormalLeft -- en or -- hauteur 15, LEFT x = 10
--
-- ReputationEntryTemplate, hauteur 30 :
--   barre               ReputationBarTemplate, RIGHT x = -3
--   AccountWideIcon     23 x 22, LEFT x = 2. Elle n'existe pas en 3.3.5,
--                       mais c'est son bord droit -- x = 25 -- qui donne
--                       l'origine du nom.
--   nom                 GameFontHighlight -- en blanc -- hauteur 15, aligne
--                       a gauche, de x = 25 au LEFT de la barre moins 10
--   BackgroundHighlight trois tranches, cotes larges de 6 :
--                       charactercreate-customize-dropdown-linemouseover-side
--                       -- le droit retourne -- et -middle entre les deux.
--                       RefreshBackgroundHighlightOpacity donne les alphas :
--                       au repos 0 ; au survol 0,10 ; choisie 0,20. En
--                       guerre 0,50 / 0,65 / 0,85, et teinte par
--                       FACTION_AT_WAR_COLOR -- sinon WHITE_FONT_COLOR,
--                       RefreshBackgroundHighlightColor.
--
-- ReputationBarTemplate, 160 x 29, herite de ColoredProgressBarTemplate :
--   fond          common-stat-bar-bg, sans ancrage donc etire sur la barre
--   remplissage   common-stat-bar-white, hauteur 15, ancre LEFT. SetFillPercent
--                 pose largeur = fraction x largeur de barre et rogne la
--                 texture d'autant. UpdateBarColor la TEINTE avec
--                 FACTION_BAR_COLORS[attitude].
--   texte         GameFontHighlight, LEFT et RIGHT sur la barre, donc centre.
--                 L'intitule d'attitude au repos ; au survol la progression,
--                 par TryShowBarProgressText.
--
-- InitializeBarForStandardReputation : a l'attitude maximale la barre est
-- pleine et n'a pas de texte de progression ; sinon la valeur se normalise
-- entre le seuil courant et le suivant.
--
-- CE QUI DIFFERE, ET POURQUOI :
--   * 3.3.5 n'a pas de MaskTexture : les bouts du remplissage restent carres.
--   * Ni AccountWideIcon, ni Paragon, ni amitie : ces notions n'existent pas
--     dans ce client. Seul le retrait qu'imposait la premiere est garde.
--   * La barre de defilement reste a faire ; la molette suffit d'ici la.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local LISTE_X, LISTE_Y = 10, -40
local LISTE_X2, LISTE_Y2 = -25, 15

-- LA HIERARCHIE : TROIS GABARITS, TROIS RETRAITS.
--
-- RELEVE -- camelot/ReputationFrame.lua, SetElementFactory :
--   ni en-tete                 ReputationEntryTemplate      hauteur 30
--   en-tete et pas un enfant   ReputationHeaderTemplate     hauteur 28
--   en-tete ET un enfant       ReputationSubHeaderTemplate  hauteur 22
--
-- SetElementIndentCalculator, dans le meme fichier :
--   en-tete de premier niveau            0
--   enfant qui n'est PAS un en-tete     46
--   tout le reste                        2
--
-- SetPadding : 10 de marge sur les quatre bords, et 3 entre deux lignes.
--
-- 3.3.5 donne les deux drapeaux qu'il faut : GetFactionInfo rend isHeader en
-- neuvieme position et isChild en treizieme, plus hasRep en onzieme -- un
-- sous-en-tete ne montre sa barre que s'il en a une, comme le veut
-- ReputationSubHeaderMixin:Initialize.
local ENTREE_H = 30                     -- ReputationEntryTemplate
local SOUS_ENTETE_H = 22                -- ReputationSubHeaderTemplate
local ENTETE_H = 28                     -- ReputationHeaderTemplate
local MARGE = 10                        -- SetPadding
local ECART = 3                         -- elementSpacing
local RETRAIT_ENTETE = 0
local RETRAIT_ENFANT = 46
local RETRAIT_AUTRE = 2
local BARRE_L, BARRE_H = 160, 29
local BARRE_X = -3                      -- RIGHT de la ligne
local REMPLISSAGE_H = 15
local NOM_H = 15
-- LE NOM D'UNE ENTREE. Il part du bord droit de l'AccountWideIcon, x = 25 --
-- puis ReputationEntryMixin:Initialize le decale de -10 quand cette icone
-- est masquee, ce qu'elle est toujours ici : 3.3.5 n'a pas de reputation de
-- compte. D'ou 15.
local NOM_X = 15
-- LE SOUS-EN-TETE porte un bouton de 20 ancre a LEFT du bord droit de cette
-- meme icone plus 3, donc x = 28 ; son nom suit a +4 de ce bouton.
local CHEVRON = 20
local CHEVRON_X = 28
local SOUS_NOM_ECART = 4
local NOM_ECART = -10                   -- du LEFT de la barre
local ENTETE_NOM_X = 10
local FLECHE_X, FLECHE_Y = -8, -1
local FLECHE_PLACE = 16                 -- ce que le nom lui laisse
local COTE = 6                          -- les tranches du survol

-- LA PLAQUE D'EN-TETE SE DECOUPE, ELLE NE S'ETIRE PAS.
--
-- Elle mesure 64 x 29 et la ligne en fait plus de trois cents : etiree telle
-- quelle, ses coins arrondis s'etalaient en ellipses. Mesure sur l'art --
-- alpha de la colonne de gauche -- l'arrondi court sur une dizaine de
-- pixels ; un coin de 12 le couvre, et reste sous la moitie de la hauteur,
-- au-dela de quoi les tranches se chevaucheraient.
local PLAQUE_COIN = 12

-- LE FOND DE JAUGE SE DECOUPE AUSSI.
--
-- common-stat-bar-bg mesure 68 x 30 et la barre en fait 160 : etire, ses
-- bouts arrondis s'allongeaient. Mesure sur l'art -- on cherche la premiere
-- colonne dont le profil vertical rejoint celui du milieu, c'est-a-dire ou
-- le bord est fini : elle tombe a 10. La hauteur ne changeant pas, seules
-- les tranches horizontales du milieu s'etirent.
--
-- LE REMPLISSAGE, LUI, NE SE DECOUPE PAS : c'est une jauge. camelot le
-- rogne a la fraction voulue -- SetFillPercent pose largeur = fraction x
-- largeur de barre et SetTexCoord(0, fraction, ...) -- et la meme
-- compression horizontale s'y applique, sa feuille faisant 240 pour une
-- barre de 160. Le decouper en ferait un cadre, pas une jauge.
local JAUGE_COIN = 10

local ATLAS_BARRE_FOND = "common-stat-bar-bg"
-- LE REMPLISSAGE EST CUIT, PAS PRIS DANS SA FEUILLE.
--
-- camelot le decoupe par common-stat-bar-Mask, une MaskTexture que 3.3.5 n'a
-- pas : sans elle, le remplissage avait des bouts carres qui ne suivaient pas
-- le contour du fond. tools/cuire_masque.py multiplie donc l'alpha du masque
-- dans celui du remplissage, une fois pour toutes -- et il le DECOUPE comme
-- notre fond, bouts de 10 px et milieu etire, pour que les deux contours se
-- superposent exactement.
--
-- Le resultat est un fichier a lui seul, calcule pour une barre de 160 : on
-- le rogne a la fraction voulue, comme SetFillPercent.
-- LA TEINTE DE LA LIGNE EN GUERRE.
--
-- camelot l'ecrit ainsi -- RefreshBackgroundHighlightColor :
--   local highlightColor = self:IsAtWar() and FACTION_AT_WAR_COLOR
--                          or WHITE_FONT_COLOR
--
-- FACTION_AT_WAR_COLOR N'EXISTE PAS EN 3.3.5, verifie dans le FrameXML du
-- client : ni Constants.lua, ni GlobalStrings.lua, ni ReputationFrame.lua ne
-- la portent. La teinte retombait donc sur le blanc, et une faction en
-- guerre se voyait recouverte d'un voile CLAIR au lieu d'etre rouge.
--
-- LA VALEUR EXACTE SE LIT DANS LE CLIENT MODERNE. Ces couleurs-la ne sont
-- plus ecrites en Lua : elles sont generees depuis GlobalColor.db2, ou
-- chaque ligne porte un nom et une couleur ARGB. Relevee dans ce fichier :
--
--   FACTION_AT_WAR_COLOR   0xFF690300   105, 3, 0
--
-- Le decodage est verifie sur deux temoins de la meme table :
-- WHITE_FONT_COLOR y vaut 0xFFFFFFFF et RED_FONT_COLOR 0xFFFF2020, les deux
-- valeurs connues.
local COULEUR_EN_GUERRE = { r = 105 / 255, g = 3 / 255, b = 0 / 255 }

local CHEMIN_REMPLISSAGE = "Interface\\ForeverUI\\Bars\\statbarfill"
local ATLAS_ENTETE = "common-button-list-collapseexpand"
local ATLAS_PLUS = "common-button-list-plus"
local ATLAS_MOINS = "common-button-list-minus"
local ATLAS_TRAIT = "ui-character-info-scrollline-long"
local ATLAS_SURVOL_COTE = "charactercreate-customize-dropdown-linemouseover-side"
local ATLAS_SURVOL_MILIEU = "charactercreate-customize-dropdown-linemouseover-middle"

-- La taille du volet, par construction : un contenu se batit a sa premiere
-- ouverture, qui peut preceder la pose de la fenetre. GetHeight rendrait
-- alors zero.
local VOLET_L, VOLET_H = 398, 464

local lignes = {}
local panneau, decalage = nil, 0
local visibles = 0                      -- combien tiennent reellement
local choisie

-- --------------------------------------------------------------- une ligne

local function creerLigne(index, largeur)
	local ligne = CreateFrame("Button", "ForeverUIReputationRow" .. index, panneau)
	ligne:SetWidth(largeur)
	ligne:SetHeight(ENTREE_H)

	-- LE FOND D'EN-TETE, en neuf tranches : seules celles du milieu s'etirent.
	ligne.plaque = ForeverUI.CreateNineSlice(ligne, ATLAS_ENTETE, PLAQUE_COIN,
		{ 0, 0, 0, 0 }, "BACKGROUND") or {}
	for _, tranche in ipairs(ligne.plaque) do
		tranche:Hide()
	end

	-- LE SURVOL D'UNE ENTREE : trois tranches, les cotes larges de 6.
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
		-- La source la retourne : TexCoords left = 1, right = 0.
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

	ligne.survolPieces = { gauche, droite, milieu }

	-- LA BARRE, et ce qu'elle porte.
	local barre = CreateFrame("Frame", nil, ligne)
	barre:SetWidth(BARRE_L)
	barre:SetHeight(BARRE_H)
	barre:SetPoint("RIGHT", ligne, "RIGHT", BARRE_X, 0)
	ligne.barre = barre

	ForeverUI.CreateNineSlice(barre, ATLAS_BARRE_FOND, JAUGE_COIN,
		{ 0, 0, 0, 0 }, "BACKGROUND")

	local remplissage = barre:CreateTexture(nil, "BORDER")
	remplissage:SetPoint("LEFT", barre, "LEFT", 0, 0)
	barre.remplissage = remplissage

	local texte = barre:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	texte:SetPoint("LEFT", barre, "LEFT", 0, 0)
	texte:SetPoint("RIGHT", barre, "RIGHT", 0, 0)
	texte:SetJustifyH("CENTER")
	barre.texte = texte

	-- LE NOM. Ses deux ancrages ne sont pas les memes selon le gabarit : ils
	-- se reposent donc a chaque remplissage.
	local nom = ligne:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	nom:SetHeight(NOM_H)
	nom:SetJustifyH("LEFT")
	ligne.nom = nom

	-- LA FLECHE d'un en-tete de premier niveau, a droite.
	local fleche = ligne:CreateTexture(nil, "OVERLAY")
	fleche:SetPoint("RIGHT", ligne, "RIGHT", FLECHE_X, FLECHE_Y)
	fleche:Hide()
	ligne.fleche = fleche

	-- LE BOUTON d'un sous-en-tete, a gauche.
	--
	-- ECART ASSUME : la source lui donne campaign_headericon_closed et
	-- _open, qui vivent dans interface/questframe/questmaplogatlas.blp --
	-- une grande feuille pour deux images de 22. On reprend en attendant le
	-- plus et le moins de l'en-tete, deja verses, ce qui garde la colonne
	-- coherente.
	local chevron = ligne:CreateTexture(nil, "OVERLAY")
	chevron:SetPoint("LEFT", ligne, "LEFT", CHEVRON_X, 0)
	chevron:Hide()
	ligne.chevron = chevron

	ligne:RegisterForClicks("LeftButtonUp")
	return ligne
end

-- ----------------------------------------------------------- le remplissage

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

	-- SetFillPercent : largeur = fraction x largeur de barre, et la texture
	-- rognee d'autant. Une largeur nulle est refusee par le client.
	if fraction * largeur < 1 then
		barre.remplissage:Hide()
	else
		barre.remplissage:SetTexture(CHEMIN_REMPLISSAGE)
		barre.remplissage:SetTexCoord(0, fraction, 0, 1)
		barre.remplissage:SetWidth(largeur * fraction)
		barre.remplissage:SetHeight(REMPLISSAGE_H)
		barre.remplissage:Show()
	end

	local couleur = FACTION_BAR_COLORS and FACTION_BAR_COLORS[donnees.attitude]
	if couleur then
		barre.remplissage:SetVertexColor(couleur.r, couleur.g, couleur.b)
	end

	barre.texte:SetText(donnees.intitule or "")
end

-- Une ligne de la liste : sa barre fait 160.
local function poserBarre(ligne, donnees)
	poserBarreDans(ligne.barre, donnees, BARRE_L)
end

-- L'OPACITE DU SURVOL, telle que RefreshBackgroundHighlightOpacity la donne.
local function poserSurvol(ligne)
	if ligne.entete then
		ligne.survol:SetAlpha(0)
		return
	end

	local dessus = ligne:IsMouseOver()
	local alpha
	if ligne.enGuerre then
		alpha = (ligne.choisie and 0.85) or (dessus and 0.65) or 0.50
	else
		alpha = (ligne.choisie and 0.20) or (dessus and 0.10) or 0
	end
	ligne.survol:SetAlpha(alpha)

	local teinte = ligne.enGuerre
		and (FACTION_AT_WAR_COLOR or COULEUR_EN_GUERRE)
	for _, piece in ipairs(ligne.survolPieces) do
		if teinte then
			piece:SetVertexColor(teinte.r, teinte.g, teinte.b)
		else
			piece:SetVertexColor(1, 1, 1)
		end
	end
end

local function remplirLigne(ligne, donnees)
	ligne.factionIndex = donnees.index
	ligne.factionNom = donnees.nom
	ligne.entete = donnees.entete
	ligne.enfant = donnees.enfant
	ligne.replie = donnees.replie
	ligne.enGuerre = donnees.enGuerre
	ligne.progression = donnees.progression
	ligne.intitule = donnees.intitule
	ligne.dessusAvant = nil

	ligne.nom:SetText(donnees.nom or "")
	ligne.nom:ClearAllPoints()

	local plaque = donnees.entete and not donnees.enfant
	local sousEntete = donnees.entete and donnees.enfant

	for _, tranche in ipairs(ligne.plaque) do
		if plaque then tranche:Show() else tranche:Hide() end
	end

	if plaque then
		-- EN-TETE DE PREMIER NIVEAU : plaque, nom en or, fleche a droite.
		ligne:SetHeight(ENTETE_H)
		ligne.barre:Hide()
		ligne.chevron:Hide()
		ligne.nom:SetFontObject(GameFontNormalLeft or GameFontNormal)
		ligne.nom:SetPoint("LEFT", ligne, "LEFT", ENTETE_NOM_X, 0)
		ligne.nom:SetPoint("RIGHT", ligne, "RIGHT", FLECHE_X - FLECHE_PLACE, 0)

		ForeverUI.SetAtlas(ligne.fleche, donnees.replie and ATLAS_PLUS or ATLAS_MOINS)
		ligne.fleche:Show()
	elseif sousEntete then
		-- SOUS-EN-TETE : un bouton a gauche, le nom a sa suite, et une barre
		-- seulement s'il porte de la reputation.
		ligne:SetHeight(SOUS_ENTETE_H)
		ligne.fleche:Hide()
		ForeverUI.SetAtlas(ligne.chevron, donnees.replie and ATLAS_PLUS or ATLAS_MOINS)
		ligne.chevron:Show()

		ligne.nom:SetFontObject(GameFontHighlight or GameFontNormal)
		ligne.nom:SetPoint("LEFT", ligne.chevron, "RIGHT", SOUS_NOM_ECART, 0)
		ligne.nom:SetPoint("RIGHT", ligne.barre, "LEFT", NOM_ECART, 0)

		if donnees.avecRep then
			ligne.barre:Show()
			poserBarre(ligne, donnees)
		else
			ligne.barre:Hide()
		end
	else
		-- ENTREE.
		ligne:SetHeight(ENTREE_H)
		ligne.barre:Show()
		ligne.fleche:Hide()
		ligne.chevron:Hide()
		ligne.nom:SetFontObject(GameFontHighlight or GameFontNormal)
		ligne.nom:SetPoint("LEFT", ligne, "LEFT", NOM_X, 0)
		ligne.nom:SetPoint("RIGHT", ligne.barre, "LEFT", NOM_ECART, 0)
		poserBarre(ligne, donnees)
	end

	-- LA SELECTION SE RETIENT PAR LE NOM. Un indice ne survit pas a un
	-- repli : les factions se renumerotent, et la marque changerait de
	-- ligne. Le nom, lui, ne bouge pas.
	ligne.choisie = (choisie ~= nil and choisie == donnees.nom)
	poserSurvol(ligne)
	ligne:Show()
end

-- ------------------------------------------------------------- les donnees

-- CE QUE 3.3.5 DONNE. GetFactionInfo rend, dans l'ordre : nom, description,
-- attitude, seuil courant, seuil suivant, valeur, en guerre, peut declarer la
-- guerre, est un en-tete, est replie, a de la reputation, est surveillee,
-- est un enfant.
local function lireFaction(rang)
	local nom, _, attitude, seuil, suivant, valeur, enGuerre, _, entete,
		replie, avecRep, _, enfant = GetFactionInfo(rang)
	if not nom then
		return nil
	end

	local maximum, courant = 1, 1
	local plein = (attitude == (MAX_REPUTATION_REACTION or 8))
	if not plein then
		maximum = (suivant or 0) - (seuil or 0)
		courant = (valeur or 0) - (seuil or 0)
	end

	local intitule = ""
	if GetText then
		intitule = GetText("FACTION_STANDING_LABEL" .. tostring(attitude),
			UnitSex and UnitSex("player")) or ""
	end

	return {
		index = rang,
		nom = nom,
		attitude = attitude,
		valeur = courant,
		maximum = maximum,
		entete = entete,
		enfant = enfant,
		avecRep = avecRep,
		replie = replie,
		enGuerre = enGuerre,
		intitule = intitule,
		progression = (not plein)
			and (tostring(courant) .. " / " .. tostring(maximum)) or nil,
	}
end

-- LE RETRAIT, tel que SetElementIndentCalculator le donne.
local function retraitDe(donnees)
	if donnees.entete and not donnees.enfant then
		return RETRAIT_ENTETE
	end
	if not donnees.entete and donnees.enfant then
		return RETRAIT_ENFANT
	end
	return RETRAIT_AUTRE
end

local function hauteurDe(donnees)
	if donnees.entete then
		return donnees.enfant and SOUS_ENTETE_H or ENTETE_H
	end
	return ENTREE_H
end

-- L'ECRAN DU CLIENT SE TAIT EN ENTIER, A CHAQUE PASSAGE.
--
-- Deux raisons de repasser a chaque fois : ReputationFrame_Update finit par
-- factionRow:Show() sur chacune de ses quinze lignes, et il remontre son
-- art. Les masquer a la construction ne tient pas.
--
-- Et il ne s'agit pas que des lignes : ce cadre porte aussi sa liste a
-- ascenseur, ses intitules de colonne et ses traits d'arborescence. Les
-- enumerer serait une liste a tenir a jour et a oublier -- on masque donc
-- TOUT ce qu'il porte et qui n'est pas a nous. GetRegions ne rend que les
-- textures, GetChildren que les cadres fils : il faut les deux.
--
-- Le cadre de detail, lui, echappe au balayage : il a change de parent, il
-- vit desormais dans le volet DROIT.
local function etoufferEcranDuClient()
	local cadre = _G["ReputationFrame"]
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

-- UN PASSAGE : empiler les lignes depuis le decalage, jusqu'a la marge du
-- bas. Rend combien ont ete posees.
-- ON S'ARRETE A GetNumFactions, PAS A CE QUE GetFactionInfo REPOND.
--
-- Les deux ne coincident pas : le client annonce neuf factions et repond
-- encore a la dixieme -- l'en-tete "Inactive", hors du compte. Sa propre
-- boucle le sait et teste factionIndex <= numFactions ; la notre ne le
-- faisait pas, et posait une ligne de plus.
--
-- C'est ce qui rendait le repli incomprehensible : la liste raccourcit, mais
-- nous continuions a lire au-dela du compte, ou le client rend des entrees
-- d'un autre bloc. Un sous-en-tete paraissait alors hors de sa categorie,
-- et vide.
local function disposer()
	local total = (GetNumFactions and GetNumFactions()) or 0
	local hauteurUtile = (panneau:GetHeight() or 0)
	if hauteurUtile < 50 then
		hauteurUtile = VOLET_H + LISTE_Y - LISTE_Y2
	end
	local largeurUtile = (panneau:GetWidth() or 0)
	if largeurUtile < 50 then
		largeurUtile = VOLET_L + LISTE_X2 - LISTE_X
	end

	-- Les hauteurs changent d'un gabarit a l'autre : on ne peut pas diviser,
	-- il faut empiler.
	local y = MARGE
	local posees = 0
	for rang, ligne in ipairs(lignes) do
		local index = decalage + rang
		local donnees = (index <= total) and lireFaction(index) or nil
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

-- REPLIER RACCOURCIT LA LISTE, IL NE MASQUE PAS.
--
-- CollapseFactionHeader retire les enfants de la numerotation du client :
-- GetNumFactions diminue et tout ce qui suit remonte d'un cran. C'est ainsi
-- que 3.3.5 et camelot fonctionnent tous les deux, et c'est voulu.
--
-- CE QUI NE L'ETAIT PAS : le decalage etait borne APRES la pose. Replier en
-- bas de liste laissait donc un passage entier pose depuis un decalage
-- devenu trop grand -- des lignes vides, ou les mauvaises factions, jusqu'au
-- passage suivant. On borne donc, et on repose si cela a bouge.
local function poserListe()
	if not panneau then
		return
	end

	etoufferEcranDuClient()

	local total = (GetNumFactions and GetNumFactions()) or 0
	local posees = disposer()

	if decalage > 0 and decalage + posees > total then
		decalage = math.max(0, total - posees)
		posees = disposer()
	end

	visibles = posees

	-- Le detail suit la faction choisie. Il est ecrit plus bas : on passe
	-- par le point publie, sinon son nom se resoudrait en globale.
	if ForeverUI.ReputationDetail then
		ForeverUI.ReputationDetail()
	end
end
ForeverUI.ReputationLayout = poserListe

-- --------------------------------------------------------- la construction

local function suivreSurvol()
	for _, ligne in ipairs(lignes) do
		if ligne:IsShown() and not ligne.entete then
			poserSurvol(ligne)

			-- Au survol, la barre montre la progression ; au repos,
			-- l'attitude. C'est TryShowBarProgressText.
			local dessus = ligne:IsMouseOver()
			if dessus ~= ligne.dessusAvant then
				ligne.dessusAvant = dessus
				if dessus and ligne.progression then
					ligne.barre.texte:SetText(ligne.progression)
				else
					ligne.barre.texte:SetText(ligne.intitule or "")
				end
			end
		end
	end
end

local function monter(hote)
	local cadre = _G["ReputationFrame"]
	if not cadre or not hote then
		return nil, {}
	end

	cadre:ClearAllPoints()
	cadre:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, 0)
	cadre:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", 0, 0)

	if panneau then
		return nil, { cadre }
	end

	-- L'ART ET LES LIGNES DE 3.3.5 S'EN VONT : etoufferEcranDuClient s'en
	-- charge a chaque passage, y compris au premier. On ne garde du client
	-- que ce cadre, comme support, et ses fonctions de lecture.
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

	panneau = CreateFrame("Frame", "ForeverUIReputationList", cadre)
	panneau:SetPoint("TOPLEFT", hote, "TOPLEFT", LISTE_X, LISTE_Y)
	panneau:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", LISTE_X2, LISTE_Y2)
	panneau:SetWidth(largeur)

	-- On en cree assez pour le cas le plus dense -- que des sous-en-tetes,
	-- les plus courts -- puisque poserListe s'arrete a la marge du bas.
	local place = math.floor((hauteur + LISTE_Y - LISTE_Y2) / (SOUS_ENTETE_H + ECART))
	if place < 1 then
		place = 1
	end
	for index = 1, place do
		local ligne = creerLigne(index, largeur)
		ligne:SetScript("OnClick", function(self)
			if not self.factionIndex then
				return
			end
			-- Un en-tete comme un sous-en-tete se replie.
			if self.entete then
				if self.replie then
					ExpandFactionHeader(self.factionIndex)
				else
					CollapseFactionHeader(self.factionIndex)
				end
			else
				-- CHOISIR UNE FACTION, c'est le dire au CLIENT : c'est lui
				-- qui remplit ensuite la description et l'etat des trois
				-- cases, dans ReputationFrame_Update, et seulement si son
				-- cadre de detail est visible.
				-- CHOISIR UNE FACTION, c'est le dire au CLIENT : c'est lui
				-- qui remplit ensuite la description et l'etat des trois
				-- cases, dans ReputationFrame_Update, et seulement si son
				-- cadre de detail est visible.
				local cadre = _G["ReputationDetailFrame"]
				if cadre then
					cadre:Show()
				end
				ForeverUI.ReputationSelect(self.factionNom)
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
		local total = (GetNumFactions and GetNumFactions()) or 0
		decalage = math.max(0, math.min(decalage - sens, total - visibles))
		poserListe()
	end)

	poserListe()
	return nil, { cadre }
end

-- TEMOIN -- /fui reput. Ce que le client rend pour chaque ligne visible, et
-- ce qu'on en fait : c'est la seule facon de departager une donnee fausse
-- d'un affichage faux.
function ForeverUI.ReputationDebug()
	local dire = function(texte)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. texte)
	end

	local total = (GetNumFactions and GetNumFactions()) or 0
	dire(string.format("reputation : %d factions, decalage %d, %d lignes, %d posees",
		total, decalage, #lignes, visibles))

	-- CE QUE LE CLIENT EXPOSE, ligne par ligne, drapeaux compris : c'est lui
	-- qui decide de la hierarchie, pas nous.
	dire("ce que le client expose :")
	for rang = 1, total do
		local nom, _, attitude, seuil, suivant, valeur, _, _, entete, replie,
			avecRep, _, enfant = GetFactionInfo(rang)
		DEFAULT_CHAT_FRAME:AddMessage(string.format(
			"   %2d %-28s entete=%-5s enfant=%-5s replie=%-5s avecRep=%-5s "
			.. "attitude=%s brut=%s/%s/%s",
			rang, tostring(nom), tostring(entete), tostring(enfant),
			tostring(replie), tostring(avecRep), tostring(attitude),
			tostring(seuil), tostring(suivant), tostring(valeur)))
	end

	dire("ce que nous posons :")

	for rang, ligne in ipairs(lignes) do
		if ligne:IsShown() then
			local nom, _, attitude, seuil, suivant, valeur, enGuerre, _, entete,
				replie = GetFactionInfo(decalage + rang)
			local r, v, b = ligne.barre.remplissage:GetVertexColor()
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"   %d %s entete=%s attitude=%s brut=%s/%s/%s | barre=%s "
				.. "large=%s visible=%s teinte=%.2f,%.2f,%.2f",
				rang, tostring(nom), tostring(entete), tostring(attitude),
				tostring(seuil), tostring(suivant), tostring(valeur),
				tostring(ligne.barre:IsShown()),
				tostring(ligne.barre.remplissage:GetWidth()),
				tostring(ligne.barre.remplissage:IsShown()),
				r or -1, v or -1, b or -1))
		end
	end
end

-- ===========================================================================
-- LE VOLET DROIT : LE DETAIL DE LA FACTION CHOISIE
--
-- RELEVE -- camelot/CharacterFrame.xml, CharacterFrameSidePaneTemplate :
--   le volet     TOPLEFT sur CharacterFrameRightPaneHost (16, -14)
--                BOTTOMRIGHT sur le meme (-12, 14)
--   Title        GameFontNormalMed3, large de 195, centre, au TOP
--   Subtitle     GameFontHighlight, large de 195, centre, TOP du BOTTOM du
--                titre, y = -3
--   Divider      UI-Character-Info-ScrollLine, TOP du BOTTOM du sous-titre,
--                y = -4
--   Description  TOP du BOTTOM du separateur y = -6, LEFT, RIGHT x = -14,
--                police GameFontNormal
--   Footer       colle au bas du volet
--
-- RELEVE -- camelot/ReputationFrame.xml, ReputationDetailFrame :
--   StandingBar        ReputationBarTemplate, 180 x 29, TOP du BOTTOM du
--                      separateur, y = -6 : la description descend sous elle
--   AtWarCheckbox      26 x 26, TOPLEFT du Footer (-4, 0). Intitule AT_WAR en
--                      GameFontNormal, large de 158, a LEFT du RIGHT + 2, en
--                      ROUGE. Fond checkbox-minimal ; coche
--                      Interface/Buttons/UI-CheckBox-SwordCheck en 32 x 32
--                      posee a TOPLEFT (3, -5).
--   MakeInactiveCheckbox   sous la precedente, BOTTOMLEFT (0, -2)
--   WatchFactionCheckbox   sous celle-la, meme ecart
--
-- CE QUE 3.3.5 DONNE. ReputationDetailFrame existe, avec les memes pieces :
-- ReputationDetailFactionName, ...FactionDescription et trois cases --
-- AtWar, Inactive, MainScreen. C'est ReputationFrame_Update qui les remplit,
-- pour la faction que SetSelectedFaction designe, et SEULEMENT si le cadre
-- est visible. On garde donc ces cadres, qui portent la logique du clic, et
-- on ne fait que les reposer dans notre volet.
--
-- CE QUI DIFFERE : la description de camelot defile -- ScrollingFontTemplate,
-- que 3.3.5 n'a pas. La notre est simplement bornee au volet.

local VOLET_DROIT_X, VOLET_DROIT_Y = 16, -14
local VOLET_DROIT_X2, VOLET_DROIT_Y2 = -12, 14
local TITRE_L = 195
local SOUS_TITRE_Y = -3
local SEPARATEUR_Y = -4
local JAUGE_DETAIL_L, JAUGE_DETAIL_H = 180, 29
local JAUGE_DETAIL_Y = -6
local DESCRIPTION_Y = -6
local DESCRIPTION_X2 = -14
local DESCRIPTION_Y2 = 6                -- ce qu'elle laisse au-dessus des cases
local CASE = 26
local CASE_X, CASE_ECART = -4, -2
local CASE_INTITULE_L = 158
local CASE_INTITULE_X = 2

local ATLAS_CASE = "checkbox-minimal"
local ATLAS_COCHE = "checkmark-minimal"
local ATLAS_SEPARATEUR = "ui-character-info-scrollline"
local COCHE = "Interface\\Buttons\\UI-CheckBox-SwordCheck"
local COCHE_COTE = 32
local COCHE_X, COCHE_Y = 3, -5

local detail

-- LES TROIS CASES DU CLIENT, reposees et rhabillees. Leur logique reste la
-- leur : ce sont elles qui declarent la guerre, rangent une faction parmi
-- les inactives, ou la suivent sur la barre du bas.
-- LES EPEES N'APPARTIENNENT QU'A LA GUERRE.
--
-- RELEVE -- camelot/ReputationFrame.xml, les trois CheckButton. Toutes ont
-- le meme fond, checkbox-minimal, mais pas la meme coche :
--   AtWarCheckbox          Interface/Buttons/UI-CheckBox-SwordCheck, 32 x 32
--                          posee a TOPLEFT (3, -5) -- deux epees croisees
--   MakeInactiveCheckbox   checkmark-minimal
--   WatchFactionCheckbox   checkmark-minimal
-- Les deux dernieres ont aussi checkmark-minimal-disabled quand la case est
-- grisee ; 3.3.5 n'en grise aucune ici, on n'en a pas besoin.
local CASES = {
	{ nom = "ReputationDetailAtWarCheckBox", rouge = true, epees = true },
	{ nom = "ReputationDetailInactiveCheckBox" },
	{ nom = "ReputationDetailMainScreenCheckBox" },
}

local function habillerCase(case, rouge, epees)
	if not case or case.foreverHabillee then
		return
	end

	case:SetWidth(CASE)
	case:SetHeight(CASE)

	for _, methode in ipairs({ "GetNormalTexture", "GetPushedTexture",
		"GetHighlightTexture", "GetCheckedTexture", "GetDisabledCheckedTexture" }) do
		local texture = case[methode] and case[methode](case)
		if texture then
			texture:SetAlpha(0)
		end
	end

	local fond = case:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, ATLAS_CASE)
	fond:SetPoint("CENTER", case, "CENTER", 0, 0)

	-- LA COCHE. Celle de la guerre est un FICHIER -- deux epees croisees,
	-- UI-CheckBox-SwordCheck, que 3.3.5 possede deja -- posee en 32 a
	-- (3, -5). Les deux autres sont un atlas, checkmark-minimal, centre.
	local coche = case:CreateTexture(nil, "OVERLAY")
	if epees then
		coche:SetTexture(COCHE)
		coche:SetWidth(COCHE_COTE)
		coche:SetHeight(COCHE_COTE)
		coche:SetPoint("TOPLEFT", case, "TOPLEFT", COCHE_X, COCHE_Y)
	else
		ForeverUI.SetAtlas(coche, ATLAS_COCHE)
		coche:SetPoint("CENTER", case, "CENTER", 0, 0)
	end
	case.foreverCoche = coche

	local intitule = _G[case:GetName() .. "Text"]
	if intitule then
		intitule:ClearAllPoints()
		intitule:SetPoint("LEFT", case, "RIGHT", CASE_INTITULE_X, 0)
		intitule:SetWidth(CASE_INTITULE_L)
		intitule:SetJustifyH("LEFT")
		if GameFontNormal then
			intitule:SetFontObject(GameFontNormal)
		end
		if rouge and RED_FONT_COLOR then
			intitule:SetTextColor(RED_FONT_COLOR.r, RED_FONT_COLOR.g, RED_FONT_COLOR.b)
		end
	end

	case.foreverHabillee = true
end

-- La coche suit l'etat que le client vient de poser.
local function suivreCases()
	for _, decrit in ipairs(CASES) do
		local case = _G[decrit.nom]
		if case and case.foreverCoche then
			if case:GetChecked() then
				case.foreverCoche:Show()
			else
				case.foreverCoche:Hide()
			end
		end
	end
end

local function montrerCases(etat)
	for _, decrit in ipairs(CASES) do
		local case = _G[decrit.nom]
		if case then
			if etat then case:Show() else case:Hide() end
		end
	end
end

-- LE DETAIL SUIT LE NOM, PAS L'INDICE.
--
-- Cocher "Move to Inactive" appelle SetFactionInactive(GetSelectedFaction()),
-- qui DEPLACE la faction dans le bloc des inactives. Le client renumerote
-- alors tout, et l'indice retenu designe une autre ligne -- la reputation
-- paraissait deselectionnee. Le nom, lui, ne bouge pas : c'est donc lui
-- qu'on garde, et l'indice se retrouve a chaque passage. On le repose au
-- client au passage, pour que ses trois cases agissent sur la bonne faction.
local function indiceDe(nom)
	if not nom then
		return nil
	end
	for rang = 1, (GetNumFactions and GetNumFactions()) or 0 do
		if GetFactionInfo(rang) == nom then
			return rang
		end
	end
	return nil
end

local function viderDetail()
	detail.titre:SetText("")
	detail.sousTitre:SetText("")
	detail.description:SetText("")
	detail.separateur:Hide()
	detail.jauge:Hide()
	montrerCases(false)
end

local dernieresDonnees

local function majDetail()
	if not detail then
		return
	end

	-- RIEN DE CHOISI : le volet est vide.
	if not choisie then
		dernieresDonnees = nil
		viderDetail()
		return
	end

	local index = indiceDe(choisie)
	local donnees
	if index then
		if SetSelectedFaction and GetSelectedFaction
			and GetSelectedFaction() ~= index then
			SetSelectedFaction(index)
		end
		donnees = lireFaction(index)
		dernieresDonnees = donnees
	else
		-- La faction a quitte la liste -- rangee parmi les inactives, ou son
		-- bloc replie. On garde ce qu'on montrait plutot que de vider.
		donnees = dernieresDonnees
	end

	if not donnees or donnees.entete then
		viderDetail()
		return
	end

	detail.titre:SetText(donnees.nom or "")
	detail.sousTitre:SetText(donnees.intitule or "")
	detail.separateur:Show()

	detail.jauge:Show()
	poserBarreDans(detail.jauge, donnees, JAUGE_DETAIL_L)
	detail.jauge.texte:SetText(donnees.progression or donnees.intitule or "")

	-- La description vient du client : c'est ReputationFrame_Update qui la
	-- pose, depuis GetFactionInfo, pour la faction choisie.
	local source = _G["ReputationDetailFactionDescription"]
	detail.description:SetText((source and source:GetText()) or "")

	montrerCases(true)
	suivreCases()
end
ForeverUI.ReputationDetail = majDetail

-- CHOISIR, OU NE PLUS RIEN CHOISIR. Passer nil vide le volet droit : c'est
-- l'etat de depart, et celui auquel on revient si la faction disparait.
local function choisir(nom)
	choisie = nom
	local index = indiceDe(nom)
	if index and SetSelectedFaction then
		SetSelectedFaction(index)
	end
	if ReputationFrame_Update then
		ReputationFrame_Update()
	else
		poserListe()
	end
end
ForeverUI.ReputationSelect = choisir

local function monterDetail(hote)
	if detail then
		return detail, {}
	end

	local cadre = _G["ReputationDetailFrame"]
	if not cadre or not hote then
		return nil, {}
	end

	-- Le cadre du client devient notre volet : vide de son art de fenetre, et
	-- etale sur la surface que camelot donne au sien.
	cadre:SetParent(hote)
	if cadre.SetToplevel then
		cadre:SetToplevel(false)
	end
	cadre:ClearAllPoints()
	cadre:SetPoint("TOPLEFT", hote, "TOPLEFT", VOLET_DROIT_X, VOLET_DROIT_Y)
	cadre:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", VOLET_DROIT_X2, VOLET_DROIT_Y2)
	-- LE FOND DE FENETRE N'EST PAS UNE REGION.
	--
	-- ReputationDetailFrame porte un <Backdrop> -- UI-DialogBox-Background et
	-- UI-DialogBox-Border, avec ses marges et sa taille de tuile. Un fond de
	-- ce type ne figure pas dans GetRegions : le balayage des textures ne
	-- l'atteignait pas, et son cadre gris restait a l'ecran. Il s'enleve par
	-- SetBackdrop(nil), comme celui des listes de menu.
	if cadre.SetBackdrop then
		cadre:SetBackdrop(nil)
	end

	for _, region in ipairs({ cadre:GetRegions() }) do
		if region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
	local fermer = _G["ReputationDetailCloseButton"]
	if fermer then
		fermer:Hide()
	end

	detail = cadre

	-- ECART ASSUME : camelot ecrit le titre en GameFontNormalMed3, un objet
	-- de police que 3.3.5 n'a pas. GameFontNormalLarge est le plus proche
	-- qu'il porte.
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

	-- LA JAUGE du volet : le meme gabarit que celles de la liste, en 180.
	local jauge = CreateFrame("Frame", "ForeverUIReputationStanding", cadre)
	jauge:SetWidth(JAUGE_DETAIL_L)
	jauge:SetHeight(JAUGE_DETAIL_H)
	jauge:SetPoint("TOP", detail.separateur, "BOTTOM", 0, JAUGE_DETAIL_Y)
	ForeverUI.CreateNineSlice(jauge, ATLAS_BARRE_FOND, JAUGE_COIN,
		{ 0, 0, 0, 0 }, "BACKGROUND")
	jauge.remplissage = jauge:CreateTexture(nil, "BORDER")
	jauge.remplissage:SetPoint("LEFT", jauge, "LEFT", 0, 0)
	jauge.texte = jauge:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	jauge.texte:SetPoint("LEFT", jauge, "LEFT", 0, 0)
	jauge.texte:SetPoint("RIGHT", jauge, "RIGHT", 0, 0)
	jauge.texte:SetJustifyH("CENTER")
	detail.jauge = jauge

	-- La hauteur du pied : trois cases et leurs deux ecarts. La description
	-- s'arrete juste au-dessus.
	local pied = 3 * CASE + 2 * (-CASE_ECART)

	-- LA DESCRIPTION. Celle du client sert de SOURCE : on la masque et on
	-- ecrit la notre, bornee au volet.
	for _, nom in ipairs({ "ReputationDetailFactionDescription",
		"ReputationDetailFactionName" }) do
		local piece = _G[nom]
		if piece then
			piece:Hide()
		end
	end

	-- LA DESCRIPTION SE REPLIE DANS UNE BOITE, ET ELLE EST BLANCHE.
	--
	-- Deux corrections d'un meme geste.
	--
	-- LA COULEUR : camelot declare fontName = GameFontNormal sur son
	-- ScrollingFontTemplate, mais cet objet de police est DORE en 3.3.5 --
	-- c'est celui des titres. Le blanc y est GameFontHighlight, et c'est ce
	-- que la reference montre.
	--
	-- LE REPLI : un texte n'a de quoi revenir a la ligne que s'il a une
	-- BOITE. Ancre par son seul haut et ses deux cotes, il n'a pas de bas :
	-- une description un peu longue n'avait nulle part ou aller et
	-- disparaissait. On lui donne donc ses quatre bords -- du bas de la
	-- jauge au haut des trois cases -- et il se replie dedans.
	detail.description = cadre:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	detail.description:SetPoint("TOPLEFT", jauge, "BOTTOMLEFT", 0, DESCRIPTION_Y)
	detail.description:SetPoint("TOPRIGHT", jauge, "BOTTOMRIGHT", 0, DESCRIPTION_Y)
	detail.description:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT", 0, pied + DESCRIPTION_Y2)
	detail.description:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT",
		DESCRIPTION_X2, pied + DESCRIPTION_Y2)
	detail.description:SetJustifyH("LEFT")
	detail.description:SetJustifyV("TOP")
	if detail.description.SetWordWrap then
		detail.description:SetWordWrap(true)
	end

	-- LE PIED : les trois cases, empilees depuis le bas du volet.
	local precedente
	for _, decrit in ipairs(CASES) do
		local case = _G[decrit.nom]
		if case then
			habillerCase(case, decrit.rouge, decrit.epees)
			case:SetParent(cadre)
			case:ClearAllPoints()
			if precedente then
				case:SetPoint("TOPLEFT", precedente, "BOTTOMLEFT", 0, CASE_ECART)
			else
				case:SetPoint("TOPLEFT", cadre, "BOTTOMLEFT", CASE_X, pied)
			end
			precedente = case
		end
	end

	cadre:Show()
	majDetail()
	return cadre, {}
end

ForeverUI.ReputationTab = { Build = monter, BuildRight = monterDetail, Rows = lignes }

-- Le client annonce ses changements par UPDATE_FACTION et les traite dans
-- ReputationFrame_Update : on se greffe dessus, ses donnees etant les notres.
if hooksecurefunc and type(_G["ReputationFrame_Update"]) == "function" then
	hooksecurefunc("ReputationFrame_Update", poserListe)
end
