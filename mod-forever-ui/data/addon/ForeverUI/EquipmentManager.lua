-- ForeverUI : le gestionnaire d'equipement, dans le volet droit.
--
-- RELEVE -- camelot/PaperDollFrame.xml, PaperDollFrame.EquipmentManagerPane :
--   ancre       TOPLEFT sur le BOTTOMLEFT de la bande de pierre du volet,
--               BOTTOMRIGHT sur le volet lui-meme.
--   bordure     common-insideframe, TOPLEFT (1, 1) et BOTTOMRIGHT (-4, 2).
--   liste       TOPLEFT (5, -8), BOTTOMRIGHT (-20, 105).
--   trait       UI-Character-Info-ScrollLine, au TOP du BOTTOM de la liste.
--   Equip       99 x 28, BOTTOM (-50, 20), intitule EQUIPSET_EQUIP.
--   Save        99 x 28, BOTTOM (50, 20), intitule SAVE.
--   New Set     180 x 34, BOTTOM (0, 50), avec UI-Character-Info-Icon-Add
--               a LEFT (13).
--
-- RELEVE -- camelot, GearSetButtonTemplate, la carte d'un ensemble :
--   cadre       169 x 44
--   fond        UI-Character-Info-OutfitCard, 152 x 49, TOPLEFT x = 42
--   survol      UI-Character-Info-OutfitCard-Hover, meme place
--   choisi      UI-Character-Info-OutfitCard-Selected, meme place
--   coche       UI-Character-Info-Icon-Tick, RIGHT (-23, 0), montree quand
--               l'ensemble est PORTE (PaperDollEquipmentManagerPane_InitButton)
--   intitule    GameFontNormalLeft, 98 x 38, LEFT (55)
--   icone       36 x 36, LEFT (4), cerclee de
--               UI-Character-Info-OutfitIcon-Frame, centree dessus
--
-- CE QUE LE CLIENT PORTE. GearManagerDialog, une fenetre de 261 x 155 sur
-- UIPanelDialogTemplate, avec GearSetButton1..MAX_EQUIPMENT_SETS_PER_PLAYER
-- poses EN GRILLE de cinq, et trois boutons : Delete, Equip, Save. Une carte
-- y est un CheckButton de 36 sur PopupButtonTemplate -- son icone est sa
-- NormalTexture, son intitule le $parentName sous elle, et un fond
-- UI-EmptySlot-Disabled derriere.
--
-- Rien n'est recree : la fenetre du client passe dans le volet, ses cartes
-- se reposent en colonne et se rhabillent, ses boutons gardent leur clic.
-- C'est lui qui tient la liste, la selection et les infobulles.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   3.3.5 n'a pas de bouton "New Set" : on y cree un ensemble par Save, qui
--   ouvre la fenetre de nom. Le notre fait la meme chose apres avoir vide la
--   selection, ce qui est exactement "enregistrer sous un nouveau nom".
--   Le bouton Delete du client n'a pas d'equivalent chez camelot, qui efface
--   un ensemble par le menu de sa carte -- menu que 3.3.5 n'a pas. Il est
--   donc GARDE, a droite de Save, plutot que de retirer la seule facon
--   d'effacer un ensemble.
--   GetEquipmentSetInfo ne dit pas si un ensemble est porte. La coche se
--   calcule donc depuis GetEquipmentSetLocations : l'ensemble est porte
--   quand chacune de ses pieces est sur le joueur et hors des sacs.
--   La barre de defilement de camelot (MinimalScrollBar) n'est pas portee :
--   la liste defile a la molette, et le trait de camelot marque son bas.

ForeverUI = ForeverUI or {}

-- ECARTS ASSUMES, sur demande. camelot donne une carte de 169 x 44 dont le
-- fond fait 152 x 49 pose a x = 42. Ici :
--
--   * la liste glisse de 4 vers la droite (LISTE_X de 5 a 9) ;
--   * la carte est moins haute -- 40 au lieu de 44, le fond suivant a 45,
--     l'image gardant les 5 de debord de la source ;
--   * le fond est plus large, pour que l'ecart entre le separateur des
--     volets et le bord gauche d'une icone soit CELUI du bord droit de la
--     fenetre au bord droit de la carte.
--
-- Le calcul de cette largeur, en abscisses du volet (233 de large) :
--   le separateur est pose a -6 et fait 11 -> son bord droit tombe a 5
--   l'icone commence a LISTE_X + 4            -> 13, donc 8 d'ecart
--   la carte finit a LISTE_X + 42 + largeur   -> il faut 233 - 8 = 225
--   d'ou largeur = 225 - 9 - 42 = 174
-- Le bouton, lui, couvre toute la carte : 42 + 174.
local CARTE_FOND_L, CARTE_FOND_H = 174, 45
local CARTE_FOND_X = 42
local CARTE_L, CARTE_H = CARTE_FOND_X + CARTE_FOND_L, 40
local CARTE_ICONE, CARTE_ICONE_X = 36, 4
local CARTE_TEXTE_X = 55
local CARTE_TEXTE_L, CARTE_TEXTE_H = 98, 38
-- ECART ASSUME, sur demande. camelot ancre sa coche a RIGHT (-23) du
-- BOUTON, qui chez lui s'arrete 25 px avant le bord de la carte : la coche
-- tombe donc bien a l'interieur. Ici le bouton couvre toute la carte, si
-- bien que le meme -23 la ramenait trop vers la gauche. Elle est donc posee
-- par rapport au bord DROIT de la carte, qu'elle longe a 12.
local COCHE_X = -12

local LISTE_X, LISTE_Y = 9, -8
local LISTE_X2, LISTE_Y2 = -20, 105
local BOUTON_L, BOUTON_H = 99, 28
local BOUTON_Y, BOUTON_ECART = 20, 50
local NOUVEAU_L, NOUVEAU_H = 180, 34
local NOUVEAU_Y, NOUVEAU_ICONE_X = 50, 13
-- LA BORDURE SE DECOUPE, ELLE NE S'ETIRE PAS. common-insideframe fait
-- 107 x 107 et porte un MOTIF dans chaque angle : tendue sur les 233 x 379
-- du panneau, elle est multipliee par deux en largeur et par trois et demi
-- en hauteur, et tout se brouille.
--
-- Mesure sur l'art : le filet occupe 2..12 et 94..104 sur les deux axes, et
-- le motif d'angle s'arrete a 19 -- des x = 20 le profil n'est plus que le
-- filet. Le coin vaut donc 20, ce qui laisse une bande centrale de 67.
--
-- Les marges viennent de camelot, qui ancre sa bordure en TOPLEFT (1, 1) et
-- BOTTOMRIGHT (-4, 2) : converties dans la convention du decoupage -- de
-- combien l'image deborde du cadre -- cela donne -1, 1, -4, -2.
--
-- ECART ASSUME, sur demande : toute la bordure est decalee de 3 px vers la
-- droite. Les deux bords bougent ensemble -- le gauche de -1 a -4, le droit
-- de -4 a -1 -- sinon elle s'elargirait au lieu de glisser.
local BORDURE_COIN = 20
local BORDURE_MARGES = { -4, 1, -1, -2 }

local ATLAS_FOND = "ui-character-info-outfitcard"
local ATLAS_SURVOL = "ui-character-info-outfitcard-hover"
local ATLAS_CHOISI = "ui-character-info-outfitcard-selected"
local ATLAS_COCHE = "ui-character-info-icon-tick"
local ATLAS_CERCLE = "ui-character-info-outfiticon-frame"
local ATLAS_PLUS = "ui-character-info-icon-add"
local ATLAS_BORDURE = "common-insideframe"
local ATLAS_TRAIT = "ui-character-info-scrollline"

-- RELEVE -- camelot, GearSetButtonTemplate, les deux boutons de survol :
--
--   $parentDeleteButton  14 x 14, BOTTOMRIGHT (-21, 2)
--                        Interface\\Buttons\\UI-GroupLoot-Pass-Up, alpha 0,5
--                        au repos et 1 au survol ; enfonce, la texture
--                        glisse de (1, -1). Infobulle DELETE. Au clic :
--                        StaticPopup_Show("CONFIRM_DELETE_EQUIPMENT_SET").
--   $parentEditButton    16 x 16, RIGHT sur le LEFT du precedent, x = -1
--                        Interface\\WorldMap\\GEAR_64GREY, memes alphas.
--
-- Les deux ne paraissent QUE sur la carte survolee -- camelot le decide
-- dans PaperDollEquipmentManagerPane_OnUpdate, en interrogeant IsMouseOver
-- a chaque image. On fait de meme : un OnEnter ne suffirait pas, il part
-- des qu'on entre sur l'un de ces deux boutons, qui sont des cadres fils.
--
-- CE QUI DIFFERE. L'engrenage de camelot ouvre un menu d'assignation de
-- SPECIALISATION (C_EquipmentSet.AssignSpecToEquipmentSet), qui n'existe
-- pas en 3.3.5. A la demande, il rouvre ici la fenetre de creation sur
-- l'ensemble choisi : le client la remplit alors de son nom et de son
-- icone (RecalculateGearManagerDialogPopup), et son Okay voit que le nom
-- existe deja -- il demande confirmation puis ECRASE l'ensemble au lieu
-- d'en creer un.
-- EQUIPMENT_SET_SETTINGS, l'infobulle de camelot, n'existe pas ici :
-- SETTINGS est la plus proche que ce client porte.
local SUPPRIMER = 14
local SUPPRIMER_X, SUPPRIMER_Y = -21, 2
local EDITER = 16
local EDITER_X = -1
local ICONE_SUPPRIMER = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
local ICONE_EDITER = "Interface\\WorldMap\\GEAR_64GREY"
local REPOS, SURVOL = 0.5, 1.0

local panneau, decalage = nil, 0

-- MODIFIER UN ENSEMBLE : CE QUE 3.3.5 PERMET, ET COMMENT.
--
-- Ce client n'a PAS de ModifyEquipmentSet -- verifie dans Wow.exe. Il n'a
-- que SaveEquipmentSet(nom, icone), qui enregistre L'EQUIPEMENT PORTE sous
-- ce nom, et DeleteEquipmentSet(nom). Changer le nom ou l'icone sans
-- toucher a la liste d'objets est donc impossible directement.
--
-- LE CHEMIN RETENU, sur decision : equiper l'ancien ensemble -- l'equipement
-- porte DEVIENT alors sa liste -- l'enregistrer sous le nouveau nom et la
-- nouvelle icone, effacer l'ancien, et remettre le nouveau a la place de
-- l'ancien dans la liste. Les objets sont ainsi conserves a l'identique.
--
-- Deux consequences assumees :
--   * le personnage change reellement d'equipement le temps de l'operation ;
--   * elle est ASYNCHRONE -- UseEquipmentSet rend la main avant la fin, et
--     c'est EQUIPMENT_SWAP_FINISHED(termine, nom) qui l'annonce. Si
--     l'ensemble est deja porte, rien n'est a equiper et on enchaine.
--
-- L'ORDRE D'AFFICHAGE est tenu par nous : 3.3.5 n'a aucun moyen de replacer
-- un ensemble dans sa liste, l'ordre du client etant celui de creation. Le
-- notre vit dans ForeverUIDB, et c'est lui qui pose les cartes.
local edition
local fermetureVoulue                   -- on ferme la fenetre nous-memes
local EDITION_DELAI = 10                -- secondes avant d'abandonner

local function ordreRetenu()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.ordreEnsembles = ForeverUIDB.ordreEnsembles or {}
	return ForeverUIDB.ordreEnsembles
end

local function rangDe(nom)
	for rang, connu in ipairs(ordreRetenu()) do
		if connu == nom then
			return rang
		end
	end
	return nil
end

-- Les ensembles du client, dans NOTRE ordre ; ceux qu'on ne connait pas
-- encore prennent la fin de la liste.
local function ensemblesOrdonnes()
	local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
	local parNom, dans = {}, {}
	for index = 1, total do
		local nom = GetEquipmentSetInfo(index)
		if nom then
			parNom[nom] = index
		end
	end

	-- L'ORDRE NE S'ELAGUE PAS ICI. Il l'a fait, et c'etait une faute :
	-- quand le client ne rend momentanement AUCUN ensemble -- ce qui arrive
	-- entre un enregistrement et son evenement -- l'elagage vidait la table
	-- pour de bon. Les noms revenaient ensuite un par un, d'ou une liste en
	-- retard d'une operation. Un nom inconnu est simplement saute ; il ne
	-- coute qu'une ligne de table.
	local ordre = ordreRetenu()

	local liste = {}
	for _, nom in ipairs(ordre) do
		if parNom[nom] then
			liste[#liste + 1] = parNom[nom]
			dans[nom] = true
		end
	end
	for index = 1, total do
		local nom = GetEquipmentSetInfo(index)
		if nom and not dans[nom] then
			liste[#liste + 1] = index
			ordre[#ordre + 1] = nom
		end
	end
	return liste
end
ForeverUI.EquipmentSetsOrder = ensemblesOrdonnes

-- QUEL ENSEMBLE EST PORTE. Deux questions, et je n'en avais traite
-- qu'une, mal.
--
-- 1. LA PIECE EST-ELLE DANS LE BON EMPLACEMENT ? GetEquipmentSetLocations
--    rend une table indexee par EMPLACEMENT d'equipement, et
--    EquipmentManager_UnpackLocation rend "joueur, banque, sacs, SLOT".
--    Je ne lisais que les deux premiers drapeaux : une piece portee dans un
--    AUTRE emplacement passait pour bonne, d'ou des coches sur des
--    ensembles sans rapport. Il faut comparer le slot rendu a la CLE.
--
-- 2. DEUX ENSEMBLES AUX MEMES PIECES. Si deux ensembles decrivent le meme
--    equipement, la geometrie ne peut pas les departager : tous deux sont
--    "portes". 3.3.5 n'a AUCUNE notion d'ensemble actif -- son propre
--    gestionnaire n'affiche d'ailleurs rien de tel. On retient donc le
--    dernier ensemble equipe, en se greffant sur UseEquipmentSet, et la
--    coche va a celui-la -- a condition qu'il soit encore porte, sinon
--    elle disparait des que le joueur change une piece a la main.
local function piecesEnPlace(nom)
	if not nom or not GetEquipmentSetLocations or not EquipmentManager_UnpackLocation then
		return false
	end

	local places = GetEquipmentSetLocations(nom)
	if not places then
		return false
	end

	local vu = false
	for emplacement, place in pairs(places) do
		if type(place) == "number" and place > 1 then
			local joueur, _, sacs, slot = EquipmentManager_UnpackLocation(place)
			if not joueur or sacs or slot ~= emplacement then
				return false
			end
			vu = true
		end
	end
	return vu
end

local function ensembleActif()
	ForeverUIDB = ForeverUIDB or {}
	return ForeverUIDB.ensembleEquipe
end

local function ensemblePorte(nom)
	return nom ~= nil and nom == ensembleActif() and piecesEnPlace(nom)
end
ForeverUI.EquipmentSetWorn = ensemblePorte

-- Le dernier ensemble equipe, retenu d'une session a l'autre.
if hooksecurefunc and type(UseEquipmentSet) == "function" then
	hooksecurefunc("UseEquipmentSet", function(nom)
		ForeverUIDB = ForeverUIDB or {}
		ForeverUIDB.ensembleEquipe = nom
		if ForeverUI.EquipmentSetsLayout then
			ForeverUI.EquipmentSetsLayout()
		end
	end)
end

-- Combien de cartes tiennent dans la liste, et ou elle commence.
local function hauteurListe()
	if not panneau then
		return 0
	end
	return panneau:GetHeight() - (-LISTE_Y) - LISTE_Y2
end

local function cartesVisibles()
	local place = math.floor(hauteurListe() / CARTE_H)
	if place < 1 then
		place = 1
	end
	return place
end

-- La carte : le cadre du client, rhabille une seule fois.
local function habillerCarte(bouton)
	if bouton.foreverCarte then
		return
	end

	bouton:SetWidth(CARTE_L)
	bouton:SetHeight(CARTE_H)

	-- Le fond d'emplacement vide de 3.3.5 s'en va ; l'icone, elle, est la
	-- NormalTexture du bouton et doit rester.
	local icone = bouton:GetNormalTexture()
	local regions = { bouton:GetRegions() }
	for _, region in ipairs(regions) do
		if region ~= icone and region.GetObjectType and region:GetObjectType() == "Texture" then
			local chemin = region.GetTexture and region:GetTexture()
			if type(chemin) == "string" and string.find(string.lower(chemin), "emptyslot") then
				region:SetAlpha(0)
			end
		end
	end
	if bouton:GetHighlightTexture() then
		bouton:GetHighlightTexture():SetAlpha(0)
	end
	if bouton.GetCheckedTexture and bouton:GetCheckedTexture() then
		bouton:GetCheckedTexture():SetAlpha(0)
	end

	local function carte(atlas, couche)
		local t = bouton:CreateTexture(nil, couche)
		ForeverUI.SetAtlas(t, atlas, true)
		t:SetWidth(CARTE_FOND_L)
		t:SetHeight(CARTE_FOND_H)
		t:SetPoint("TOPLEFT", bouton, "TOPLEFT", CARTE_FOND_X, 0)
		return t
	end

	-- LE CHOIX PASSE AU-DESSUS DU SURVOL. Ils etaient sur le meme calque,
	-- ou seul l'ordre de creation departage -- trop fragile pour une regle
	-- d'affichage. Le survol reste en BORDER, le choix monte en ARTWORK :
	-- l'ordre ne depend plus de rien.
	bouton.foreverFond = carte(ATLAS_FOND, "BACKGROUND")
	bouton.foreverSurvol = carte(ATLAS_SURVOL, "BORDER")
	bouton.foreverSurvol:Hide()
	bouton.foreverChoisi = carte(ATLAS_CHOISI, "ARTWORK")
	bouton.foreverChoisi:Hide()

	if icone then
		icone:ClearAllPoints()
		icone:SetWidth(CARTE_ICONE)
		icone:SetHeight(CARTE_ICONE)
		icone:SetPoint("LEFT", bouton, "LEFT", CARTE_ICONE_X, 0)
		icone:SetDrawLayer("ARTWORK")
	end

	local cercle = bouton:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(cercle, ATLAS_CERCLE)
	cercle:SetPoint("CENTER", icone or bouton, "CENTER", 0, 0)

	local coche = bouton:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(coche, ATLAS_COCHE)
	coche:SetPoint("RIGHT", bouton, "RIGHT", COCHE_X, 0)
	coche:Hide()
	bouton.foreverCoche = coche

	local texte = _G[bouton:GetName() .. "Name"]
	if texte then
		texte:ClearAllPoints()
		texte:SetFontObject(GameFontNormalLeft or GameFontNormal)
		texte:SetWidth(CARTE_TEXTE_L)
		texte:SetHeight(CARTE_TEXTE_H)
		texte:SetJustifyH("LEFT")
		texte:SetPoint("LEFT", bouton, "LEFT", CARTE_TEXTE_X, 0)
	end

	-- LES DEUX BOUTONS DE SURVOL.
	local function petitBouton(nom, cote, icone, infobulle, clic)
		local b = CreateFrame("Button", bouton:GetName() .. nom, bouton)
		b:SetWidth(cote)
		b:SetHeight(cote)
		b:SetFrameLevel(bouton:GetFrameLevel() + 2)

		local t = b:CreateTexture(nil, "ARTWORK")
		t:SetTexture(icone)
		t:SetAllPoints(b)
		t:SetAlpha(REPOS)
		b.texture = t

		b:SetScript("OnEnter", function(self)
			self.texture:SetAlpha(SURVOL)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(infobulle)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function(self)
			self.texture:SetAlpha(REPOS)
			GameTooltip:Hide()
		end)
		b:SetScript("OnMouseDown", function(self)
			self.texture:ClearAllPoints()
			self.texture:SetPoint("TOPLEFT", self, "TOPLEFT", 1, -1)
			self.texture:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 1, -1)
		end)
		b:SetScript("OnMouseUp", function(self)
			self.texture:ClearAllPoints()
			self.texture:SetAllPoints(self)
		end)
		b:SetScript("OnClick", clic)
		b:Hide()
		return b
	end

	bouton.foreverSupprimer = petitBouton("ForeverUIDelete", SUPPRIMER,
		ICONE_SUPPRIMER, DELETE or "Delete", function(self)
			local carte = self:GetParent()
			if not carte.name or carte.name == "" then
				return
			end
			local fenetre = StaticPopup_Show("CONFIRM_DELETE_EQUIPMENT_SET", carte.name)
			if fenetre then
				fenetre.data = carte.name
			elseif UIErrorsFrame then
				UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1.0, 0.1, 0.1, 1.0)
			end
		end)
	bouton.foreverSupprimer:SetPoint("BOTTOMRIGHT", bouton, "BOTTOMRIGHT",
		SUPPRIMER_X, SUPPRIMER_Y)

	bouton.foreverEditer = petitBouton("ForeverUIEdit", EDITER,
		ICONE_EDITER, SETTINGS or "Settings", function(self)
			local carte = self:GetParent()
			if not carte.name or carte.name == "" then
				return
			end
			if ForeverUI.EquipmentSetEdit then
				ForeverUI.EquipmentSetEdit(carte.name)
			end
		end)
	bouton.foreverEditer:SetPoint("RIGHT", bouton.foreverSupprimer, "LEFT",
		EDITER_X, 0)

	bouton.foreverCarte = true
end

-- LA LISTE SE SURVEILLE, ELLE NE S'ATTEND PAS.
--
-- On ne sait pas QUAND le client aura refait sa liste : ni au retour de
-- SaveEquipmentSet, ni a l'instant de EQUIPMENT_SETS_CHANGED, ni meme a
-- l'image suivante -- les ensembles vivent cote serveur. Toute hypothese de
-- delai s'est revelee fausse, et une liste posee trop tot restait vide
-- jusqu'a l'operation d'apres.
--
-- On ne parie donc plus : on compare ce que le client rend -- le nombre
-- d'ensembles et leurs noms -- a ce qui est affiche, et on repose des que
-- cela differe. La comparaison coute une poignee de chaines, et elle ne se
-- fait qu'un cinquieme de seconde et seulement panneau ouvert.
local SURVEILLANCE = 0.2
local dernierEtat, depuisControle = nil, 0

local function etatDeLaListe()
	local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
	local bouts = { tostring(total) }
	for index = 1, total do
		local nom, icone = GetEquipmentSetInfo(index)
		bouts[#bouts + 1] = tostring(nom) .. "=" .. tostring(icone)
	end
	return table.concat(bouts, "|")
end

local function surveillerListe(ecoule)
	depuisControle = depuisControle + (ecoule or 0)
	if depuisControle < SURVEILLANCE then
		return
	end
	depuisControle = 0

	local etat = etatDeLaListe()
	if etat ~= dernierEtat then
		dernierEtat = etat
		if GearManagerDialog_Update then
			GearManagerDialog_Update()
		end
		-- poserCartes est defini plus bas : on passe par le point publie.
		ForeverUI.EquipmentSetsLayout()
	end
end
ForeverUI.EquipmentSetsWatch = surveillerListe

function ForeverUI.EquipmentSetsForget()
	dernierEtat = nil
	depuisControle = SURVEILLANCE
end

-- LE SURVOL SE SUIT A CHAQUE IMAGE, PAS PAR OnEnter. Les deux boutons sont
-- des cadres fils de la carte : y entrer declencherait le OnLeave de la
-- carte, qui les masquerait aussitot. camelot interroge IsMouseOver dans
-- PaperDollEquipmentManagerPane_OnUpdate, on fait pareil.
local function suivreSurvol(self, ecoule)
	surveillerListe(ecoule)
	local dialogue = _G["GearManagerDialog"]
	if not dialogue or not dialogue.buttons then
		return
	end

	for _, bouton in ipairs(dialogue.buttons) do
		if bouton.foreverCarte and bouton:IsShown() then
			local dessus = bouton:IsMouseOver() and bouton.name and bouton.name ~= ""
			if dessus then
				bouton.foreverSurvol:Show()
				bouton.foreverSupprimer:Show()
				bouton.foreverEditer:Show()
			else
				bouton.foreverSurvol:Hide()
				bouton.foreverSupprimer:Hide()
				bouton.foreverEditer:Hide()
			end
		end
	end
end
ForeverUI.EquipmentSetsHover = suivreSurvol

-- La liste : les ensembles existants, en colonne, a partir du decalage.
local function poserCartes()
	local dialogue = _G["GearManagerDialog"]
	if not dialogue or not dialogue.buttons or not panneau then
		return
	end

	local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
	local place = cartesVisibles()
	if decalage > total - place then
		decalage = math.max(0, total - place)
	end

	-- NOTRE ORDRE, pas celui du client : le bouton d'indice i porte
	-- l'ensemble i, mais c'est nous qui decidons ou il se pose.
	local ordre = ensemblesOrdonnes()
	local rangDuBouton = {}
	for position, index in ipairs(ordre) do
		rangDuBouton[index] = position
	end

	local precedent
	local parRang = {}
	for index, bouton in ipairs(dialogue.buttons) do
		habillerCarte(bouton)
		if rangDuBouton[index] then
			parRang[rangDuBouton[index]] = bouton
		end
	end

	for position = 1, #dialogue.buttons do
		local bouton = parRang[position]
		local index = position
		local rang = position - decalage
		if bouton and index <= total and rang >= 1 and rang <= place then
			bouton:ClearAllPoints()
			if precedent then
				bouton:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, 0)
			else
				bouton:SetPoint("TOPLEFT", panneau, "TOPLEFT", LISTE_X, LISTE_Y)
			end
			precedent = bouton
			bouton:Show()

			if bouton.foreverChoisi then
				if bouton:GetChecked() then
					bouton.foreverChoisi:Show()
				else
					bouton.foreverChoisi:Hide()
				end
			end
			if bouton.foreverCoche then
				if ensemblePorte(bouton.name) then
					bouton.foreverCoche:Show()
				else
					bouton.foreverCoche:Hide()
				end
			end
		elseif bouton then
			bouton:Hide()
		end
	end

	-- Les cartes sans ensemble ne s'affichent pas.
	for index, bouton in ipairs(dialogue.buttons) do
		if not rangDuBouton[index] then
			bouton:Hide()
		end
	end
end
ForeverUI.EquipmentSetsLayout = poserCartes

local function monter(volet)
	panneau = CreateFrame("Frame", "ForeverUIEquipmentPane", volet)
	panneau:SetPoint("TOPLEFT", volet.pierre, "BOTTOMLEFT", 0, 0)
	panneau:SetPoint("BOTTOMRIGHT", volet, "BOTTOMRIGHT", 0, 0)
	panneau:SetFrameLevel(volet:GetFrameLevel() + 3)

	panneau.bordure = ForeverUI.CreateNineSlice(panneau, ATLAS_BORDURE,
		BORDURE_COIN, BORDURE_MARGES, "BORDER")

	local trait = panneau:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(trait, ATLAS_TRAIT)
	trait:SetPoint("TOP", panneau, "BOTTOM", 0, LISTE_Y2)

	-- La molette fait defiler : camelot a une barre, que nous n'avons pas.
	panneau:SetScript("OnUpdate", suivreSurvol)
	panneau:EnableMouseWheel(true)
	panneau:SetScript("OnMouseWheel", function(self, sens)
		local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
		decalage = math.max(0, math.min(decalage - sens, total - cartesVisibles()))
		poserCartes()
	end)

	return panneau
end

-- Les trois boutons du bas, plus celui que le client garde pour effacer.
local function poserBoutons()
	local equiper = _G["GearManagerDialogEquipSet"]
	local enregistrer = _G["GearManagerDialogSaveSet"]
	local effacer = _G["GearManagerDialogDeleteSet"]

	if equiper then
		equiper:SetWidth(BOUTON_L)
		equiper:SetHeight(BOUTON_H)
		equiper:ClearAllPoints()
		equiper:SetPoint("BOTTOM", panneau, "BOTTOM", -BOUTON_ECART, BOUTON_Y)
	end
	if enregistrer then
		enregistrer:SetWidth(BOUTON_L)
		enregistrer:SetHeight(BOUTON_H)
		enregistrer:ClearAllPoints()
		enregistrer:SetPoint("BOTTOM", panneau, "BOTTOM", BOUTON_ECART, BOUTON_Y)
	end
	if effacer then
		effacer:SetWidth(BOUTON_L)
		effacer:SetHeight(BOUTON_H)
		effacer:ClearAllPoints()
		effacer:SetPoint("BOTTOM", enregistrer or panneau, "TOP", 0, 0)
		effacer:Hide()
	end

	if not panneau.nouveau then
		local nouveau = CreateFrame("Button", "ForeverUIEquipmentNewSet", panneau,
			"UIPanelButtonTemplate")
		nouveau:SetWidth(NOUVEAU_L)
		nouveau:SetHeight(NOUVEAU_H)
		nouveau:SetPoint("BOTTOM", panneau, "BOTTOM", 0, NOUVEAU_Y)

		-- ECRIT EN DUR, faute de mieux : camelot ecrit
		-- PAPERDOLL_NEWEQUIPMENTSET, et ce client ne porte aucune chaine
		-- equivalente -- ni celle-la, ni "New Set" sous un autre nom. Ce
		-- libelle ne se traduira donc pas.
		nouveau:SetText("New Set")

		-- Le meme visuel que les selecteurs de statistiques : le bouton
		-- tertiaire, presse tant qu'on le tient.
		ForeverUI.SkinTertiaryButton(nouveau, true)

		local plus = nouveau:CreateTexture(nil, "OVERLAY")
		ForeverUI.SetAtlas(plus, ATLAS_PLUS)
		plus:SetPoint("LEFT", nouveau, "LEFT", NOUVEAU_ICONE_X, 0)

		nouveau:SetScript("OnClick", function()
			local dialogue = _G["GearManagerDialog"]
			if dialogue then
				dialogue.selectedSetName = nil
				dialogue.selectedSet = nil
			end
			if GearManagerDialogSaveSet_OnClick then
				GearManagerDialogSaveSet_OnClick(_G["GearManagerDialogSaveSet"])
			end
		end)
		panneau.nouveau = nouveau
	end

	-- AU-DESSUS DE LA FENETRE DU CLIENT, ET A CHAQUE PASSAGE. Elle est
	-- etalee sur tout le panneau et elle prend la souris ; un bouton fils du
	-- PANNEAU passe dessous et ne recoit plus rien. Ceux du client -- Equip,
	-- Save -- sont ses enfants a elle, donc epargnes.
	--
	-- Le niveau se calcule depuis LE SIEN, releve maintenant : elle se hisse
	-- toute seule a chaque ouverture, et cette fonction tourne justement
	-- apres son OnShow.
	local dialogue = _G["GearManagerDialog"]
	if panneau.nouveau and dialogue then
		panneau.nouveau:SetFrameLevel(dialogue:GetFrameLevel() + 5)
	end
end

-- LA FENETRE DU CLIENT PASSE DANS LE VOLET. On la vide de son art de
-- fenetre -- UIPanelDialogTemplate porte un fond, une bordure et une barre
-- de titre -- et on l'etale sur le panneau : elle n'est plus qu'un support
-- pour ses cartes et ses boutons.
local function accueillirDialogue()
	local dialogue = _G["GearManagerDialog"]
	if not dialogue or dialogue.foreverAccueilli then
		return
	end

	dialogue:SetParent(panneau)
	dialogue:ClearAllPoints()
	dialogue:SetAllPoints(panneau)
	dialogue:SetFrameLevel(panneau:GetFrameLevel() + 1)

	-- ELLE N'EST PLUS UNE FENETRE, ELLE NE DOIT PLUS SE HISSER.
	-- GearManagerDialog est declaree toplevel dans le FrameXML, et son
	-- OnShow finit par GearManagerDialog:Raise() : a chaque ouverture elle
	-- repasse au sommet de sa strate, donc au-dessus de tout ce que le
	-- panneau porte. Un niveau pose une fois pour toutes ne tenait pas.
	if dialogue.SetToplevel then
		dialogue:SetToplevel(false)
	end

	local regions = { dialogue:GetRegions() }
	for _, region in ipairs(regions) do
		if region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
	if dialogue.title then
		dialogue.title:Hide()
	end

	dialogue.foreverAccueilli = true
end

-- LA CROIX ROUGE S'EN VA. UIPanelDialogTemplate nomme son bouton
-- $parentClose -- GearManagerDialogClose -- et non $parentCloseButton : le
-- masquer sous le mauvais nom ne faisait rien. Le panneau n'est plus une
-- fenetre, il se ferme par son onglet.
--
-- A refaire a chaque passage : le client remontre ses morceaux quand il
-- rouvre sa fenetre.
local function masquerFermeture()
	for _, nom in ipairs({ "GearManagerDialogClose", "GearManagerDialogCloseButton" }) do
		local bouton = _G[nom]
		if bouton then
			bouton:Hide()
		end
	end
end

local function habiller()
	local panes = ForeverUI.CharacterPanes
	local volet = panes and panes.droit
	if not volet or not volet.pierre or InCombatLockdown() then
		return
	end

	if not panneau then
		monter(volet)
	end

	-- LE PANNEAU SUIT SON ONGLET. Ses boutons sont des cadres fils du
	-- PANNEAU, pas de la fenetre du client : masquer celle-ci ne les
	-- emportait pas, et "New" restait visible sous les statistiques.
	if volet.statsMontrees == false then
		panneau:Show()
	else
		panneau:Hide()
	end

	accueillirDialogue()
	masquerFermeture()
	poserBoutons()
	poserCartes()
end

ForeverUI.EquipmentPane = { Apply = habiller, Frame = function() return panneau end }

if hooksecurefunc then
	for _, nom in ipairs({ "GearManagerDialog_Update", "GearManagerDialog_OnShow" }) do
		if type(_G[nom]) == "function" then
			hooksecurefunc(nom, function() habiller() end)
		end
	end
end

-- ============================================== modifier un ensemble
--
-- Le flux, dans l'ordre : equiper l'ancien, enregistrer sous le nouveau nom
-- et la nouvelle icone, effacer l'ancien, le remplacer a sa place dans la
-- liste. Voir le releve en tete de fichier pour le pourquoi.
local attenteEdition = CreateFrame("Frame", "ForeverUIEquipmentEdit")
attenteEdition:Hide()

local function remplacerDansOrdre(ancien, nouveau)
    local ordre = ordreRetenu()
    for rang, connu in ipairs(ordre) do
        if connu == ancien then
            ordre[rang] = nouveau
            return
        end
    end
    ordre[#ordre + 1] = nouveau
end

local function terminerEdition()
    local e = edition
    edition = nil
    attenteEdition:Hide()
    if not e then
        return
    end

    -- Le nom est indispensable : SaveEquipmentSet le refuse vide.
    if not e.nom or e.nom == "" or not SaveEquipmentSet then
        return
    end

    -- L'INDICE D'ICONE PEUT MANQUER. La fenetre retient l'icone choisie de
    -- deux facons : selectedIcon quand le joueur en clique une,
    -- selectedTexture quand elle est seulement PRESELECTIONNEE a
    -- l'ouverture. Le passage de l'une a l'autre se fait dans
    -- GearManagerDialogPopup_Update, et seulement pour les icones de la
    -- page VISIBLE : si celle de l'ensemble est ailleurs dans la liste,
    -- selectedIcon reste vide et SaveEquipmentSet refuse. On abandonne
    -- alors, plutot que d'effacer l'ancien sans avoir cree le nouveau.
    if type(e.icone) ~= "number" then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1.0, 0.1, 0.1, 1.0)
        end
        return
    end

    local renomme = e.nom ~= e.ancien

    -- MAX_EQUIPMENT_SETS_PER_PLAYER. Un renommage cree avant d'effacer, ce
    -- qui demande une place de plus ; au plafond, il n'y en a pas et
    -- l'enregistrement echouerait en silence. L'ancien part donc d'abord --
    -- c'est sans risque, son equipement est PORTE a cet instant, c'est
    -- justement ce qu'on vient d'equiper.
    local plafond = MAX_EQUIPMENT_SETS_PER_PLAYER or 10
    local avant = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
    if renomme and avant >= plafond and DeleteEquipmentSet then
        DeleteEquipmentSet(e.ancien)
        remplacerDansOrdre(e.ancien, e.nom)
        renomme = false
    end

    SaveEquipmentSet(e.nom, e.icone)

    -- ON N'EFFACE QUE SI LE NOUVEAU EXISTE. C'est le garde-fou : tout echec
    -- de l'enregistrement -- plafond atteint, icone refusee -- laissait
    -- sinon l'ancien efface et rien a la place.
    if renomme and DeleteEquipmentSet then
        if GetEquipmentSetInfoByName and GetEquipmentSetInfoByName(e.nom) then
            DeleteEquipmentSet(e.ancien)
            remplacerDansOrdre(e.ancien, e.nom)
        elseif UIErrorsFrame then
            UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1.0, 0.1, 0.1, 1.0)
        end
    end

    ForeverUIDB = ForeverUIDB or {}
    if ForeverUIDB.ensembleEquipe == e.ancien then
        ForeverUIDB.ensembleEquipe = e.nom
    end

    local dialogue = _G["GearManagerDialog"]
    if dialogue then
        dialogue.selectedSetName = e.nom
    end
    if ForeverUI.EquipmentSetsRefresh then
        ForeverUI.EquipmentSetsRefresh()
    end
end
ForeverUI.EquipmentSetEditFinish = terminerEdition

-- LA LISTE DU CLIENT SE MET A JOUR APRES COUP. SaveEquipmentSet et
-- DeleteEquipmentSet rendent la main avant que GetNumEquipmentSets ait
-- change : reposer les cartes dans la foulee montrait donc l'etat d'AVANT,
-- et un ensemble renomme n'apparaissait qu'a la prochaine secousse de la
-- liste -- la creation d'un autre ensemble, par exemple. C'est
-- EQUIPMENT_SETS_CHANGED qui l'annonce ; on s'y abonne nous-memes plutot
-- que de compter sur celui du client, qu'il n'ecoute que fenetre ouverte.
attenteEdition:RegisterEvent("EQUIPMENT_SETS_CHANGED")
attenteEdition:RegisterEvent("EQUIPMENT_SWAP_FINISHED")
attenteEdition:SetScript("OnEvent", function(self, evenement, termine, nom)
    if evenement == "EQUIPMENT_SETS_CHANGED" then
        -- A l'image suivante : le client n'a pas forcement fini de refaire
        -- sa liste quand il annonce qu'elle a change.
        if ForeverUI.EquipmentSetsRefresh then
            ForeverUI.EquipmentSetsRefresh()
        end
        return
    end
    if edition and termine and nom == edition.ancien then
        terminerEdition()
    end
end)

-- Si le remplacement n'aboutit pas -- combat, piece verrouillee -- on
-- abandonne plutot que de laisser une edition en suspens.
attenteEdition:SetScript("OnUpdate", function(self, ecoule)
    if not edition then
        self:Hide()
        return
    end
    edition.reste = (edition.reste or EDITION_DELAI) - (ecoule or 0)
    if edition.reste <= 0 then
        edition = nil
        self:Hide()
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage(ERR_CLIENT_LOCKED_OUT, 1.0, 0.1, 0.1, 1.0)
        end
    end
end)

local function lancerEdition(nom, icone)
    if not edition or not nom or nom == "" then
        edition = nil
        return
    end
    edition.nom = nom
    edition.icone = icone

    -- Deja porte : rien a equiper, on enchaine.
    if piecesEnPlace(edition.ancien) then
        terminerEdition()
        return
    end

    if UseEquipmentSet then
        UseEquipmentSet(edition.ancien)
    end
    edition.reste = EDITION_DELAI
    attenteEdition:Show()
end

-- LE OKAY DE LA FENETRE EST REPRIS, pas greffe. Un greffon passerait APRES
-- le client, qui aurait deja enregistre l'equipement porte sous ce nom --
-- c'est-a-dire tout sauf ce qu'on veut. Hors edition, on lui rend la main
-- telle quelle.
local function reprendreOkay()
    local okay = _G["GearManagerDialogPopupOkay"]
    if not okay or okay.foreverOkay then
        return
    end

    okay:SetScript("OnClick", function(self, bouton, enfonce)
        local popup = _G["GearManagerDialogPopup"]
        if edition and popup and popup.name and popup.name ~= "" then
            -- LIRE AVANT DE FERMER. GearManagerDialogPopup_OnHide remet
            -- popup.name a nil : lire le nom apres l'avoir cachee le rendait
            -- vide, et SaveEquipmentSet refusait. Le meme OnHide abandonne
            -- l'edition, d'ou le drapeau qui dit que la fermeture vient de
            -- nous.
            local nom = popup.name
            local _, indiceIcone = GetEquipmentSetIconInfo(popup.selectedIcon)
            local enCours = edition

            fermetureVoulue = true
            popup:Hide()
            fermetureVoulue = nil

            edition = enCours
            lancerEdition(nom, indiceIcone)
            return
        end
        if GearManagerDialogPopupOkay_OnClick then
            GearManagerDialogPopupOkay_OnClick(self, bouton, enfonce)
        end
    end)
    okay.foreverOkay = true
end
ForeverUI.EquipmentSetEditReclaim = reprendreOkay

-- Ouvrir la fenetre sur un ensemble : c'est l'engrenage qui appelle.
function ForeverUI.EquipmentSetEdit(nom)
    if not nom or nom == "" then
        return
    end

    local dialogue = _G["GearManagerDialog"]
    if dialogue then
        dialogue.selectedSetName = nom
        if GearManagerDialog_Update then
            GearManagerDialog_Update()
        end
    end

    edition = { ancien = nom }
    reprendreOkay()

    if GearManagerDialogSaveSet_OnClick then
        GearManagerDialogSaveSet_OnClick(_G["GearManagerDialogSaveSet"])
    end

    -- Le nom est pose explicitement : le client ne remplit son champ que
    -- dans RecalculateGearManagerDialogPopup, appele par le seul OnShow.
    local champ = _G["GearManagerDialogPopupEditBox"]
    if champ then
        champ:SetText(nom)
    end
end

-- Fermee autrement -- Annuler, Echap -- l'edition est abandonnee.
if hooksecurefunc and type(GearManagerDialogPopup_OnHide) == "function" then
    hooksecurefunc("GearManagerDialogPopup_OnHide", function()
        if edition and not fermetureVoulue and not attenteEdition:IsShown() then
            edition = nil
        end
    end)
end

-- LE RATTRAPAGE D'UNE IMAGE.
--
-- GetNumEquipmentSets et GetEquipmentSetInfo ne rendent pas le nouvel etat
-- dans la foulee d'un enregistrement ou d'un effacement : reposer les cartes
-- au meme instant les calculait sur l'etat d'AVANT, et la liste restait en
-- retard d'une operation -- renommer AAA en AAB ne montrait plus rien, creer
-- AZE faisait apparaitre AAB, et ainsi de suite.
--
-- On repose donc a l'IMAGE SUIVANTE, comme pour la hauteur des sacs : c'est
-- le seul moment ou l'on est sur que le client a fini. La demande vient des
-- evenements et de la fin d'une modification ; le rattrapage se rendort tout
-- seul et ne se redemande jamais lui-meme.
local rattrapageListe = CreateFrame("Frame", "ForeverUIEquipmentRecheck")
rattrapageListe:Hide()
rattrapageListe:SetScript("OnUpdate", function(self)
    self:Hide()
    if GearManagerDialog_Update then
        GearManagerDialog_Update()
    end
    ForeverUI.EquipmentSetsLayout()
end)

-- TEMOIN -- /fui sets. La liste des ensembles se decide en trois endroits :
-- ce que le client publie, l'ordre que nous retenons, et ce que les cartes
-- affichent. Quand les trois ne disent pas la meme chose, c'est ce rapport
-- qui le montre, au lieu d'avoir a le deviner.
function ForeverUI.EquipmentSetsDebug()
	local dire = function(texte)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. texte)
	end

	local total = (GetNumEquipmentSets and GetNumEquipmentSets()) or 0
	local noms = {}
	for index = 1, total do
		local nom, icone = GetEquipmentSetInfo(index)
		noms[#noms + 1] = string.format("%d=%s(%s)", index, tostring(nom), tostring(icone))
	end
	dire(string.format("ensembles : le client en publie %d : %s", total,
		table.concat(noms, ", ")))

	dire("ordre retenu : " .. table.concat(ordreRetenu(), ", "))

	local rangs = {}
	for position, index in ipairs(ensemblesOrdonnes()) do
		rangs[#rangs + 1] = string.format("%d<-%d", position, index)
	end
	dire("ordre pose : " .. table.concat(rangs, ", "))
	dire(string.format("defilement = %d, cartes qui tiennent = %d, panneau %s",
		decalage, cartesVisibles(), (panneau and panneau:IsShown()) and "ouvert" or "ferme"))
	dire(string.format("porte = %s, edition = %s",
		tostring(ForeverUIDB and ForeverUIDB.ensembleEquipe), tostring(edition and edition.ancien)))

	local dialogue = _G["GearManagerDialog"]
	if not dialogue or not dialogue.buttons then
		dire("aucune carte : le dialogue du client n'est pas la.")
		return
	end
	for index, bouton in ipairs(dialogue.buttons) do
		if bouton.name and bouton.name ~= "" or bouton:IsShown() then
			local ancre = bouton:GetPoint(1)
			DEFAULT_CHAT_FRAME:AddMessage(string.format(
				"   carte %d : nom=%s visible=%s ancre=%s coche=%s",
				index, tostring(bouton.name), tostring(bouton:IsShown()),
				tostring(ancre),
				tostring(bouton.foreverCoche and bouton.foreverCoche:IsShown())))
		end
	end
end

function ForeverUI.EquipmentSetsRefresh()
    -- On oublie l'etat connu : le prochain controle reposera la liste, quel
    -- que soit le moment ou le client aura fini.
    ForeverUI.EquipmentSetsForget()
    rattrapageListe:Show()
end
