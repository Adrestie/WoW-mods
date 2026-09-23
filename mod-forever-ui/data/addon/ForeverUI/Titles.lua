-- ForeverUI : la liste des titres, page du volet droit.
--
-- RELEVE -- camelot/paperdollframe.xml et paperdollframe.lua, lus en entier,
-- plus le PaperDollFrame.xml et le PaperDollFrame.lua du client 3.3.5, lus
-- dans l'archive.
--
-- PlayerTitleButtonTemplate, chez camelot   169 x 22
--   BgTop / BgBottom    Char-Stat-Top, les deux BOUTS DE LA LISTE : montres
--                       seulement sur la premiere et la derniere ligne
--   BgMiddle            Char-Stat-Middle, 169 x 8, LEFT x = 1, tuilee
--                       verticalement, rognee a 0,00390625 .. 0,66406250
--   Stripe              TOPLEFT (1, 0) a BOTTOMRIGHT (0, 0), la couleur
--                       STRIPE_COLOR = 0,9 / 0,9 / 1 a 0,1 d'alpha, UNE
--                       LIGNE SUR DEUX
--   Check               Interface/Buttons/UI-CheckBox-Check, 16 x 16,
--                       LEFT (8, 0), masquee tant que la ligne n'est pas
--                       choisie
--   SelectedBar         UI-FriendsFrame-HighlightBar, alpha 0,4, ADD
--   text                GameFontNormalSmallLeft, LEFT du RIGHT de la coche
--                       (3, 0), RIGHT (-3, 0)
--   Highlight           UI-FriendsFrame-HighlightBar-Blue, ADD
--
-- LES DONNEES. GetNumTitles, IsTitleKnown, GetTitleName, GetCurrentTitle et
-- SetCurrentTitle : les cinq sont dans le binaire de 3.3.5, verifie, et le
-- client s'en sert lui-meme dans PlayerTitleFrame_UpdateTitles.
--
--   IsTitleKnown REND UN NOMBRE, 0 OU 1. Zero est VRAI en Lua : le client
--   ecrit `if ( IsTitleKnown(i) ~= 0 )`, ligne 2605, et c'est la seule
--   ecriture juste.
--   GetTitleName rend le nom avec ses espaces -- "Private " -- d'ou le
--   strtrim que le client applique lui aussi.
--   GetCurrentTitle rend 0 quand rien n'est choisi, -1 pour "Aucun", sinon
--   l'identifiant. "Aucun" se pose par SetCurrentTitle(-1).
--
-- CE QUI DIFFERE, ET POURQUOI.
--
--   * PAS DE BOUTS DE LISTE. Char-Stat-Top est un MODELE de texture, pas un
--     fichier : il n'est ni dans camelot -- ou aucun XML ne le definit --
--     ni dans le FrameXML de 3.3.5, ni sous ce nom dans le listfile. Seul
--     Char-Stat-Middle existe. La liste n'a donc pas ses deux bouts
--     arrondis ; c'est un manque, signale, pas un choix.
--   * LA BANDE EST ETIREE, PAS TUILEE. camelot tuile une bande de 8 px sur
--     la hauteur de la ligne. Marier SetTexCoord et SetVertTile n'est pas
--     sur dans ce client ; et la bande ne varie verticalement que de deux a
--     cinq niveaux de luminance -- releve texel par texel -- ce que l'oeil
--     ne voit pas. On l'etire.
--   * L'ONGLET N'EST PAS DANS camelot. Son PAPERDOLL_SIDEBARS vaut
--     {STATS, EQUIPMENTMANAGER, PET} : pas de titres. L'onglet vient de
--     mainline/PaperDollFrameConstants.lua, PAPERDOLL_SIDEBARTAB_TITLES, et
--     il est ici A LA DEMANDE.
--   * LE PANNEAU N'EST PAS POSE OU camelot le pose. Son TitleManagerPane
--     s'ancre au TOPLEFT du volet droit (4, -4), donc SOUS la bande de
--     pierre et les onglets, qui le recouvriraient : l'ancre est restee
--     telle quelle le jour ou les titres ont quitte PAPERDOLL_SIDEBARS. On
--     prend celle de l'EquipmentManagerPane, la seule vivante de ce volet :
--     du bas de la pierre au bas du volet.
--   * LA LIGNE PREND TOUTE LA LARGEUR DU VOLET, moins la marge des
--     statistiques -- 20 de chaque cote, STAT_MARGE. camelot lui donne 169
--     sur un volet de 233 ; A LA DEMANDE, les deux pages du volet ont
--     desormais le meme bord. La bande s'etire avec la ligne.
--   * PAS DE BARRE DE DEFILEMENT, comme la reputation et les competences :
--     la molette suffit d'ici la.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

-- LA LIGNE PREND TOUTE LA LARGEUR DU VOLET, MOINS SA MARGE.
--
-- A LA DEMANDE, et non d'apres la source : camelot donne 169 de large a son
-- PlayerTitleButtonTemplate, sur un volet qui en fait 233. Ici la liste
-- s'aligne sur les lignes de statistiques du meme volet -- STAT_MARGE, 20 de
-- chaque cote -- pour que les deux pages du volet aient le meme bord.
--
-- LA BANDE S'ETIRE AVEC ELLE. Char-Stat-Middle porte 169 px de matiere --
-- releve : x 0 a 170, transparent au-dela -- soit une barre finie avec ses
-- deux bords. Etiree a 193, ses bords passent de 1 a 1,14 px : l'oeil ne le
-- voit pas, et un decoupage en trois tranches pour si peu ne se justifie pas.
local LIGNE_H = 22
local MARGE = 20                         -- STAT_MARGE, la marge des statistiques
local LISTE_Y = -4                       -- SetPadding(4, 0, 2, 0, 0)
local COCHE = 16
local COCHE_X = 8
local TEXTE_X, TEXTE_X2 = 3, -3
local CHOISI_ALPHA = 0.4

-- LE FOND ALTERNE, LE MEME QUE LES LIGNES DE STATISTIQUES.
--
-- A LA DEMANDE. Les deux bandes de paperdollinfopart1c60, les deux seules
-- bandes horizontales de la planche dont l'alpha s'eteint aux deux bouts :
--   UI-Character-Info-ItemLevel-Bounce  204 x 21, SOMBRE  (27, 21, 16) a 255
--   UI-Character-Info-Line-Bounce       213 x 18, CLAIRE  (87, 67, 46) a 102
-- La sombre en premier, comme dans les statistiques.
--
-- L'ALTERNANCE SUIT L'ENTREE, PAS LA PLACE A L'ECRAN : c'est l'index dans
-- la liste, celui qui tient compte du defilement. camelot raye de meme --
-- PaperDollTitlesPane_InitButton, sur `index % 2`.
local ATLAS_FOND_SOMBRE = "ui-character-info-itemlevel-bounce"
local ATLAS_FOND_CLAIR = "ui-character-info-line-bounce"
local CHEMIN_COCHE = "Interface\\Buttons\\UI-CheckBox-Check"
local CHEMIN_CHOISI = "Interface\\FriendsFrame\\UI-FriendsFrame-HighlightBar"
local CHEMIN_SURVOL =
	"Interface\\ForeverUI\\FriendsFrame\\UI-FriendsFrame-HighlightBar-Blue"

-- LA TAILLE DU VOLET, PAR CONSTRUCTION.
--
-- Un contenu se batit a sa PREMIERE OUVERTURE, qui peut preceder la pose de
-- la fenetre : GetHeight rendrait alors zero, et la liste ne poserait qu'une
-- ligne. Le meme garde-fou que la reputation et les competences.
--   volet droit  233 x 464, et la bande de pierre en prend 85 par le haut.
local VOLET_L, VOLET_H, PIERRE_H = 233, 464, 85

local panneau, decalage, lignes, titres, choisi = nil, 0, {}, {}, -1

-- -------------------------------------------------------------- les donnees

local function nomAucun()
	return PLAYER_TITLE_NONE or NONE or "None"
end

-- LES TITRES QUE LE PERSONNAGE POSSEDE.
--
-- camelot reserve la premiere place a "Aucun" avec un nom fait d'espaces,
-- trie, puis le renomme : l'espace passant avant les lettres, "Aucun" reste
-- en tete quel que soit son intitule. On obtient le meme resultat en triant
-- les titres connus puis en posant "Aucun" devant, et cela se lit mieux.
local function lireTitres()
	local liste = {}
	local nombre = GetNumTitles and GetNumTitles() or 0
	for identifiant = 1, nombre do
		if IsTitleKnown and IsTitleKnown(identifiant) ~= 0 then
			local nom = GetTitleName and GetTitleName(identifiant)
			if nom then
				nom = strtrim(nom)
				if nom ~= "" then
					liste[#liste + 1] = { id = identifiant, nom = nom }
				end
			end
		end
	end
	table.sort(liste, function(a, b) return a.nom < b.nom end)
	table.insert(liste, 1, { id = -1, nom = nomAucun() })
	return liste
end

-- LE TITRE PORTE, tel que camelot le retient : l'identifiant courant s'il
-- est un titre connu, "Aucun" sinon -- GetCurrentTitle rend 0 tant que rien
-- n'a ete choisi.
local function titrePorte()
	local courant = GetCurrentTitle and GetCurrentTitle() or 0
	local nombre = GetNumTitles and GetNumTitles() or 0
	if courant and courant > 0 and courant <= nombre
		and IsTitleKnown and IsTitleKnown(courant) ~= 0 then
		return courant
	end
	return -1
end

-- --------------------------------------------------------------- l'affichage

local function poserChoix(ligne, marque)
	if marque then
		ligne.coche:Show()
		ligne.choisi:Show()
	else
		ligne.coche:Hide()
		ligne.choisi:Hide()
	end
end

-- LA LARGEUR D'UNE LIGNE : celle du volet, sa marge deduite. Le meme
-- garde-fou que la hauteur -- un contenu peut se batir avant la pose de la
-- fenetre, et GetWidth rendrait alors zero.
local function largeurLigne()
	local largeur = (panneau and panneau:GetWidth()) or 0
	if largeur < 50 then
		largeur = VOLET_L
	end
	return largeur - 2 * MARGE
end

local function creerLigne(rang)
	local ligne = CreateFrame("Button", "ForeverUITitleRow" .. rang, panneau)
	ligne:SetWidth(largeurLigne())
	ligne:SetHeight(LIGNE_H)

	-- LE FOND : une seule texture, dont l'atlas change d'un passage a
	-- l'autre. Le troisieme argument dit de NE PAS toucher a la taille --
	-- elle vient des deux ancres.
	local fond = ligne:CreateTexture(nil, "BACKGROUND")
	fond:SetPoint("TOPLEFT", ligne, "TOPLEFT", 0, 0)
	fond:SetPoint("BOTTOMRIGHT", ligne, "BOTTOMRIGHT", 0, 0)
	ligne.fond = fond

	local choisiBarre = ligne:CreateTexture(nil, "OVERLAY")
	choisiBarre:SetTexture(CHEMIN_CHOISI)
	choisiBarre:SetBlendMode("ADD")
	choisiBarre:SetAlpha(CHOISI_ALPHA)
	choisiBarre:SetAllPoints(ligne)
	choisiBarre:Hide()
	ligne.choisi = choisiBarre

	local coche = ligne:CreateTexture(nil, "BORDER")
	coche:SetTexture(CHEMIN_COCHE)
	coche:SetWidth(COCHE)
	coche:SetHeight(COCHE)
	coche:SetPoint("LEFT", ligne, "LEFT", COCHE_X, 0)
	coche:Hide()
	ligne.coche = coche

	local texte = ligne:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	texte:SetJustifyH("LEFT")
	texte:SetPoint("LEFT", coche, "RIGHT", TEXTE_X, 0)
	texte:SetPoint("RIGHT", ligne, "RIGHT", TEXTE_X2, 0)
	ligne.texte = texte
	ligne:SetFontString(texte)

	-- PIEGE 3.3.5 : SetHighlightTexture prend un CHEMIN et un mode de
	-- fondu, jamais un objet texture. On ne peut donc pas la fabriquer a
	-- part, comme le XML de camelot le fait.
	ligne:SetHighlightTexture(CHEMIN_SURVOL, "ADD")
	local survol = ligne.GetHighlightTexture and ligne:GetHighlightTexture()
	if survol then
		survol:SetAllPoints(ligne)
	end

	ligne:SetScript("OnClick", function(self)
		if not self.titreId then
			return
		end
		if PlaySound then
			PlaySound("igMainMenuOptionCheckBoxOff")
		end
		if SetCurrentTitle then
			SetCurrentTitle(self.titreId)
		end
		choisi = self.titreId
		if ForeverUI.TitlesUpdate then
			ForeverUI.TitlesUpdate()
		end
	end)

	if rang == 1 then
		ligne:SetPoint("TOPLEFT", panneau, "TOPLEFT", MARGE, LISTE_Y)
	else
		ligne:SetPoint("TOPLEFT", lignes[rang - 1], "BOTTOMLEFT", 0, 0)
	end

	lignes[rang] = ligne
	return ligne
end

-- COMBIEN DE LIGNES TIENNENT dans le panneau, sa marge du haut deduite.
local function tiennent()
	local hauteur = (panneau and panneau:GetHeight()) or 0
	if hauteur < 50 then
		hauteur = VOLET_H - PIERRE_H
	end
	local compte = math.floor((hauteur + LISTE_Y) / LIGNE_H)
	if compte < 1 then
		compte = 1
	end
	return compte
end

-- UN PASSAGE : empiler les lignes depuis le decalage, jusqu'au bas du
-- panneau.
local function poser()
	if not panneau then
		return 0
	end

	local places = tiennent()
	local total = #titres
	if decalage > 0 and decalage + places > total then
		decalage = math.max(0, total - places)
	end

	local largeur = largeurLigne()
	local posees = 0
	for rang = 1, places do
		local index = decalage + rang
		local titre = titres[index]
		local ligne = lignes[rang] or creerLigne(rang)
		ligne:SetWidth(largeur)
		if titre then
			ligne.titreId = titre.id
			ligne.texte:SetText(titre.nom)
			poserChoix(ligne, titre.id == choisi)
			ForeverUI.SetAtlas(ligne.fond,
				(index % 2 == 1) and ATLAS_FOND_SOMBRE or ATLAS_FOND_CLAIR,
				true)
			ligne:Show()
			posees = posees + 1
		else
			ligne.titreId = nil
			ligne:Hide()
		end
	end
	for rang = places + 1, #lignes do
		lignes[rang]:Hide()
	end
	return posees
end

-- LE MENU DEROULANT DU CLIENT S'EFFACE, ET A CHAQUE PASSAGE.
--
-- PlayerTitleFrame_UpdateTitles le RAPPELLE -- PlayerTitleFrame:Show(),
-- ligne 2624 -- des qu'un titre change. Le masquer une fois ne suffirait
-- donc pas.
local MENU_DU_CLIENT = { "PlayerTitleFrame", "PlayerTitlePickerFrame" }

local function etoufferMenuDuClient()
	for _, nom in ipairs(MENU_DU_CLIENT) do
		local cadre = _G[nom]
		if cadre then
			cadre:Hide()
			if cadre.EnableMouse then
				cadre:EnableMouse(false)
			end
		end
	end
end

local function maj()
	etoufferMenuDuClient()
	if not panneau then
		return
	end
	titres = lireTitres()
	choisi = titrePorte()
	poser()
end
ForeverUI.TitlesUpdate = maj

-- ----------------------------------------------------------- la construction

local function monter(hote)
	if panneau then
		return panneau, {}
	end

	-- L'ancre de l'EquipmentManagerPane : du bas de la pierre au bas du
	-- volet. Voir l'entete pour le TitleManagerPane de camelot, reste sur
	-- une ancre morte.
	panneau = CreateFrame("Frame", "ForeverUITitlesPane", hote)
	if hote.pierre then
		panneau:SetPoint("TOPLEFT", hote.pierre, "BOTTOMLEFT", 0, 0)
	else
		panneau:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, 0)
	end
	panneau:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", 0, 0)

	panneau:EnableMouseWheel(true)
	panneau:SetScript("OnMouseWheel", function(_self, sens)
		decalage = math.max(0, math.min(decalage - sens, #titres - tiennent()))
		poser()
	end)

	maj()
	return panneau, {}
end

ForeverUI.TitlesPane = { Build = monter, Update = maj }

-- Le client refait sa liste dans PlayerTitleFrame_UpdateTitles : on passe
-- apres, pour reprendre la notre et taire la sienne.
if hooksecurefunc and type(_G["PlayerTitleFrame_UpdateTitles"]) == "function" then
	hooksecurefunc("PlayerTitleFrame_UpdateTitles", function()
		maj()
	end)
end

-- CE QUI FAIT BOUGER LA LISTE. KNOWN_TITLES_UPDATE annonce un titre gagne ;
-- UNIT_NAME_UPDATE sur le joueur, le titre porte qui change. camelot ecoute
-- exactement ces deux evenements.
local veilleur = CreateFrame("Frame")
veilleur:RegisterEvent("KNOWN_TITLES_UPDATE")
veilleur:RegisterEvent("UNIT_NAME_UPDATE")
veilleur:SetScript("OnEvent", function(_self, evenement, unite)
	if evenement == "UNIT_NAME_UPDATE" and unite ~= "player" then
		return
	end
	maj()
end)

-- TEMOIN -- /fui titres.
function ForeverUI.TitlesDebug()
	local dire = function(t)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. t)
	end
	local liste = lireTitres()
	dire(string.format("titres : %d connu(s) + Aucun, porte=%s, decalage=%d,"
		.. " %d ligne(s) posables", #liste - 1, tostring(titrePorte()),
		decalage, panneau and tiennent() or 0))
	local noms = {}
	for index = 1, math.min(#liste, 8) do
		noms[#noms + 1] = string.format("%s(%d)", liste[index].nom,
			liste[index].id)
	end
	dire("   " .. table.concat(noms, ", "))
	for _, nom in ipairs(MENU_DU_CLIENT) do
		local cadre = _G[nom]
		dire(string.format("   %s : %s", nom,
			cadre and (cadre:IsShown() and "VISIBLE" or "masque") or "absent"))
	end
end
