-- ForeverUI : la minimap.
--
-- RELEVE DES SOURCES -- blizzard_minimap de camelot, lu en entier avant
-- d'ecrire une ligne.
--
-- blizzard_minimap.toc
--   `[Family]\Minimap.lua` et `[Family]\Minimap.xml` se chargent pour TOUS
--   les types de jeu, et camelot appartient a la famille mainline : le
--   gabarit de la minimap de camelot EST celui de mainline. camelot n'y
--   ajoute que deux fichiers, `[Game]\Skin.lua` et `[Game]\Diel.lua`.
--
-- camelot/Skin.lua -- ce qui change, et c'est peu :
--   le cadre devient `UI-HUD-Minimap-Frame`, le masque
--   `ui-hud-minimap-frame-generic-mask`, et le CONTENEUR, le fond et la
--   texture de boussole prennent LA TAILLE DE L'ATLAS -- 253 x 253 dans la
--   variante c60, la ou mainline en donne 215 x 226. La carte, elle, garde
--   ses 198 du gabarit : Skin.lua n'y touche pas.
--
-- camelot/Diel.lua -- l'anneau du cycle jour/nuit :
--   bord `UI-HUD-Minimap-Frame-Cycle`, astre `UI-HUD-Minimap-DayCycle` ou
--   `UI-HUD-Minimap-NightCycle`, pose au CENTRE du cluster decale de
--   (63, 72), niveau de cadre 5.
--
-- mainline/Minimap.xml -- le gabarit, releve au chiffre pres :
--   MinimapCluster        256 x 256, TOPRIGHT, marges de souris 30/10/0/30
--     BorderTop           175 x 16 en TOP (15, -4), decoupe en neuf sur le
--                         kit `ui-hud-minimap-button`
--     ZoneTextButton      135 x 12, a GAUCHE du BorderTop (4, 0)
--       MinimapZoneText   130 x 12, CENTER (0, 1), GameFontNormal, a gauche
--     Tracking            17 x 17, sa DROITE sur la GAUCHE du BorderTop (-2)
--       Button            13 x 14 au centre, jumelles up/down/mouseover
--     IndicatorFrame      son TOPRIGHT sur le BOTTOMRIGHT du suivi
--       MailFrame         20 x 15, icone `ui-hud-minimap-mail-up`
--     MinimapContainer    215 x 226 -- donc 253 x 253 apres Skin.lua
--       Minimap           198 x 198 au centre
--         ZoomHitArea     40 x 40, CENTER (77, -77)
--         ZoomIn          17 x 17, CENTER (88, -68), MASQUE au repos
--         ZoomOut         17 x  9, CENTER (72, -84), MASQUE au repos
--         MinimapBackdrop 215 x 226 -- donc 253 -- centre sur la carte
--       PlayerCoords      90 x 10, sous la carte (0, -18)
--     InstanceDifficulty  TOPRIGHT du BorderTop (0, -15)
--
-- mainline/GameTime.xml -- le calendrier, que le .toc charge aussi pour
-- camelot (`[Family]\GameTime.xml`, famille mainline) :
--   GameTimeFrame         19 x 18, son TOPLEFT sur le TOPRIGHT du BorderTop
--                         (1, 0), images `ui-hud-calendar-<jour>-up`, -down,
--                         -mouseover. GameTimeFrame_SetDate n'ecrit PLUS le
--                         jour en texte : il est dans l'image.
--
-- blizzard_timemanager/mainline/Blizzard_TimeManager.xml -- l'horloge :
--   TimeManagerClockButton 40 x 16, TOPRIGHT du BorderTop (-4, 0), marges de
--                         souris 8/5/3/3, AUCUN fond ; le texte
--                         TimeManagerClockTicker en WhiteNormalNumberFont,
--                         CENTER (3, 1).
--
-- mainline/Minimap.lua, MinimapPlayerCoordsMixin -- les coordonnees :
--   relues toutes les 0,1 s, format MINIMAP_PLAYER_COORDS_INTEGER (`%d, %d`)
--   ou MINIMAP_PLAYER_COORDS (`%.1f, %.1f`) selon le CVar coordsByTenths.
--   Les deux chaines sont relevees dans la table GlobalStrings du client
--   camelot : 3.3.5 ne les a pas.
--
-- mainline/Minimap.lua -- le seul comportement qui ne se lit pas dans le XML :
--   les deux boutons de zoom sont MASQUES tant que la souris n'est ni sur la
--   carte, ni sur eux, ni sur la ZoomHitArea (MinimapMixin:OnEnter /
--   :OnLeave), et ils s'eteignent aux deux bouts de la course de zoom.
--
-- CE QUE 3.3.5 DONNE, ET COMMENT ON S'EN SERT.
--
-- Contrairement aux ecrans de la feuille de personnage, on NE REFAIT PAS la
-- carte : `Minimap` est un type de cadre a part que seul le client sait
-- fabriquer, et c'est lui qui dessine le terrain, les points et la fleche du
-- joueur. On le garde donc, on le retaille, on le masque, et on remplace tout
-- ce qui l'entoure. C'est l'exception que la regle du coeur d'abord commande.
--
-- LE MASQUE. `Minimap:SetMaskTexture` existe en 3.3.5 -- releve dans Wow.exe,
-- avec GetZoom, GetZoomLevels, SetBlipTexture -- mais il y prend un CHEMIN de
-- fichier, pas un nom d'atlas. La feuille du masque entre donc telle quelle
-- dans patch-Z, et c'est son chemin qu'on donne.
--
-- CE QU'IL FAUT ETOUFFER, et pourquoi le masquer ne suffit pas :
--   MinimapBorderTop      la barre du haut, texture du cluster
--   MinimapBorder         l'anneau dore, texture du fond
--   MinimapNorthTag       la fleche du nord
--   MinimapCompassTexture l'anneau de boussole, 365 x 365 -- ATTENTION, ce
--                         nom existe DES DEUX COTES : chez camelot c'est le
--                         cadre lui-meme, ici c'est la boussole a jeter
--   Minimap_UpdateRotationSetting REMONTRE les deux dernieres a chaque bascule
--   du CVar rotateMinimap, et MiniMapTracking_Update REND SON FICHIER a
--   l'icone de suivi. On leur retire donc l'image ET l'opacite, pas seulement
--   la visibilite.
--
-- LE CYCLE JOUR/NUIT est le SEUL chiffre de cet ecran que le client ne peut
-- pas confirmer : camelot ecoute `DIEL_CYCLE_CHANGED` et interroge
-- `C_DateAndTime.IsDayTime()`, et 3.3.5 n'a ni l'un ni l'autre. Il n'a que
-- `GetGameTime()`, l'heure du serveur. Le partage est donc le notre : jour de
-- 6 h a 18 h.
--
-- LES QUATRE BOUTONS QUE CAMELOT N'A PAS -- carte du monde, oeil du groupe,
-- champ de bataille, enregistrement -- n'ont AUCUNE place dans la source :
-- camelot les a ranges ailleurs. Les laisser ou 3.3.5 les met les
-- poserait dans le vide, leurs decalages ayant ete calcules pour une carte de
-- 140 dans un cluster de 192. On les repose donc sur l'anneau, a des angles
-- qui sont les NOTRES, et sans les rhabiller.

ForeverUI = ForeverUI or {}

-- LE CLUSTER ET SON CONTENEUR
local CLUSTER_L, CLUSTER_H = 256, 256
local MARGES_SOURIS = { 30, 10, 0, 30 }   -- gauche, droite, haut, bas

local ATLAS_CADRE = "ui-hud-minimap-frame-c60"
local CADRE_L, CADRE_H = 253, 253
local CHEMIN_MASQUE = "interface\\ForeverUI\\hud\\uiminimapmaskgeneralc60"

local CONTENEUR_X, CONTENEUR_Y = 10, -30
local CARTE_COTE = 198

-- L'ECHELLE DE LA CARTE. Le moteur pose les fleches des points hors de portee
-- (cadavre, quete, POI) a un rayon FIXE dans les unites de la carte -- celui
-- de la carte de 140 de Minimap.xml en 3.3.5 -- et aucune methode ne le
-- regle. Constate en jeu le 2026-09-24 avec `/fui minimap echelle` :
--   - la carte agrandie par sa TAILLE (198) : fleches A L'INTERIEUR ;
--   - un aller-retour de zoom n'y change rien ;
--   - la carte a l'echelle 1,4 et de taille 141 : fleches au bord du trou,
--     comme chez camelot, mais grossies d'autant.
-- La carte garde donc sa taille de 3.3.5 et prend l'echelle 198 / 140 : a
-- l'ecran elle fait toujours 198, et le rayon des fleches suit.
local CARTE_CLIENT = 140
local ECHELLE_CARTE = CARTE_COTE / CARTE_CLIENT

-- LES IMAGES DES FLECHES, motif reduit de 140 / 198 par
-- tools/reduire_fleches.py pour annuler le grossissement. La methode de
-- chaque image est relevee dans Wow.exe (voir l'outil). La fleche de GROUPE
-- n'a aucune methode : sa version reduite REMPLACE le fichier d'origine dans
-- patch-Z (exception a la regle du prefixe, accordee le 2026-09-24).
local FLECHES = {
	chemin = "interface\\ForeverUI\\minimap\\",
	{ methode = "SetStaticPOIArrowTexture", fichier = "rotating-minimaparrow" },
	{ methode = "SetPOIArrowTexture", fichier = "rotating-minimapguidearrow" },
	{ methode = "SetCorpsePOIArrowTexture", fichier = "rotating-minimapcorpsearrow" },
}

-- LA BARRE DU NOM DE ZONE
local KIT_BARRE = "ui-hud-minimap-button"
local BARRE_L, BARRE_H = 175, 16
local BARRE_X, BARRE_Y = 15, -4
local ZONE_L, ZONE_H = 135, 12
local ZONE_X = 4
local TEXTE_L, TEXTE_H = 130, 12
local TEXTE_Y = 1

-- LE SUIVI ET LE COURRIER
local SUIVI_COTE = 17
local SUIVI_X = -2
local SUIVI_BOUTON_L, SUIVI_BOUTON_H = 13, 14
local COURRIER_L, COURRIER_H = 20, 15

-- LE ZOOM
local ZOOM_ZONE = 40
local ZOOM_ZONE_X, ZOOM_ZONE_Y = 77, -77
local ZOOM_PLUS_L, ZOOM_PLUS_H = 17, 17
local ZOOM_PLUS_X, ZOOM_PLUS_Y = 88, -68
local ZOOM_MOINS_L, ZOOM_MOINS_H = 17, 9
local ZOOM_MOINS_X, ZOOM_MOINS_Y = 72, -84

-- L'ANNEAU DU CYCLE
local ATLAS_CYCLE = "ui-hud-minimap-frame-cycle-c60"
local ATLAS_JOUR = "ui-hud-minimap-daycycle-c60"
local ATLAS_NUIT = "ui-hud-minimap-nightcycle-c60"
local CYCLE_COTE = 42
local ASTRE_COTE = 33
local CYCLE_X, CYCLE_Y = 63, 72
local CYCLE_NIVEAU = 5
local AUBE, CREPUSCULE = 6, 18
local CYCLE_PERIODE = 60          -- une relecture de l'heure par minute

local DIFFICULTE_Y = -15

-- UNE TABLE PAR ELEMENT, et non une locale par chiffre : le Lua 5.1 du client
-- refuse plus de 60 upvalues dans une fonction, et `construire` les depassait
-- (Logs/FrameXML.log, 2026-09-24 -- le fichier entier ne se chargeait plus).

-- LE CALENDRIER, a droite de la barre
local CALENDRIER = { L = 19, H = 18, X = 1, ATLAS = "ui-hud-calendar-%d-%s" }

-- L'HORLOGE, dans la barre
local HORLOGE = {
	L = 40, H = 16, X = -4,
	MARGES = { 8, 5, 3, 3 },
	TEXTE_X = 3, TEXTE_Y = 1,
-- WhiteNormalNumberFont (blizzard_fonts_shared/shared/GameFontStyles.xml) :
-- NumberFont_GameNormal, FRIZQT__ de 10, ombre noire (1, -1), en blanc.
-- 3.3.5 n'a pas cet objet de police : on pose ses reglages un a un.
	POLICE = "Fonts\\FRIZQT__.TTF", TAILLE = 10,
}

-- LES COORDONNEES, sous la carte
local COORD = {
	L = 90, H = 10, Y = -18,
	PERIODE = 0.1,
	ENTIER = "%d, %d",          -- MINIMAP_PLAYER_COORDS_INTEGER
	DIXIEMES = "%.1f, %.1f",    -- MINIMAP_PLAYER_COORDS
}

-- LES CINQ BOUTONS DE 3.3.5, poses sur l'anneau. MESURE SUR L'ART : le trou
-- du cadre fait 185 et le metal 15 de part et d'autre, donc le milieu du
-- metal est a 100 du centre.
local ANNEAU_RAYON = 100
local AUTOUR = {
	{ nom = "MiniMapWorldMapButton", angle = 180 },
	{ nom = "MiniMapLFGFrame", angle = 215 },
	{ nom = "MiniMapBattlefieldFrame", angle = 250 },
	{ nom = "MiniMapRecordingButton", angle = 285 },
}

local PREFIX = "|cff66ccffForeverUI|r "

local function dire(message)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. message)
end

-- ETOUFFER UNE REGION DU CLIENT. La masquer ne suffit pas : son propre code
-- la remontre, et lui rend parfois son fichier. On lui retire donc les trois
-- a la fois -- image, opacite, visibilite -- pour qu'aucun des trois chemins
-- ne la ramene.
local function etouffer(region)
	if not region then
		return
	end
	if region.SetTexture then
		region:SetTexture(nil)
	end
	if region.SetAlpha then
		region:SetAlpha(0)
	end
	if region.Hide then
		region:Hide()
	end
end

-- UN ETAT DE BOUTON SUR UN ATLAS. En 3.3.5, un bouton n'a que les etats que
-- son XML declare : MiniMapTrackingButton n'a qu'une HighlightTexture, et
-- GetNormalTexture y rend nil -- c'est ce qui arretait `construire` au
-- chargement. Et SetNormalTexture n'accepte qu'un CHEMIN : on pose donc la
-- feuille, puis le rectangle sur la texture que le bouton vient de creer.
-- etat : "Normal", "Pushed", "Highlight" ou "Disabled".
local function etatBouton(bouton, etat, nom)
	local e = ForeverUI.AtlasEntry(nom)
	if not e then
		return nil
	end
	local texture = bouton["Get" .. etat .. "Texture"](bouton)
	if not texture then
		bouton["Set" .. etat .. "Texture"](bouton, e[1])
		texture = bouton["Get" .. etat .. "Texture"](bouton)
	end
	if texture then
		ForeverUI.SetAtlas(texture, nom, true)
	end
	return texture
end

-- LE DECOUPAGE EN NEUF A NEUF ATLAS.
--
-- Ce n'est pas celui de ForeverUI.SetAtlasNineSlice, qui taille ses neuf
-- morceaux dans UNE image. camelot appelle celui-ci UniqueCornersLayout :
-- chaque morceau est un atlas a lui, et les neuf ne sont meme pas sur la meme
-- feuille -- les coins et les bords horizontaux dans uiminimap, les bords
-- verticaux dans uiminimapvertical, le centre dans uiminimapbackground. Les
-- prefixes `_` et `!` font partie du nom : ils disent au client moderne de
-- repeter le morceau au lieu de l'etirer. 3.3.5 ne sait pas repeter un
-- rectangle pris dans un atlas -- il faudrait le fichier entier -- donc on
-- etire, comme partout ailleurs dans ce projet. Ces quatre bords sont des
-- degrades : l'etirement ne se voit pas.
local function decouperEnNeuf(cadre, kit, couche)
	local p = {}

	local function morceau(nom, garderTaille)
		local t = cadre:CreateTexture(nil, couche or "BACKGROUND")
		if not ForeverUI.SetAtlas(t, nom, garderTaille) then
			t:Hide()
		end
		return t
	end

	p.coinHautGauche = morceau(kit .. "-nineslice-cornertopleft")
	p.coinHautGauche:SetPoint("TOPLEFT", cadre, "TOPLEFT")

	p.coinHautDroit = morceau(kit .. "-nineslice-cornertopright")
	p.coinHautDroit:SetPoint("TOPRIGHT", cadre, "TOPRIGHT")

	p.coinBasGauche = morceau(kit .. "-nineslice-cornerbottomleft")
	p.coinBasGauche:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT")

	p.coinBasDroit = morceau(kit .. "-nineslice-cornerbottomright")
	p.coinBasDroit:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT")

	-- Les quatre bords et le centre sont tenus par deux coins opposes : deux
	-- points suffisent a fixer un rectangle, aucune taille a calculer.
	p.bordHaut = morceau("_" .. kit .. "-nineslice-edgetop", true)
	p.bordHaut:SetPoint("TOPLEFT", p.coinHautGauche, "TOPRIGHT")
	p.bordHaut:SetPoint("BOTTOMRIGHT", p.coinHautDroit, "BOTTOMLEFT")

	p.bordBas = morceau("_" .. kit .. "-nineslice-edgebottom", true)
	p.bordBas:SetPoint("TOPLEFT", p.coinBasGauche, "TOPRIGHT")
	p.bordBas:SetPoint("BOTTOMRIGHT", p.coinBasDroit, "BOTTOMLEFT")

	p.bordGauche = morceau("!" .. kit .. "-nineslice-edgeleft", true)
	p.bordGauche:SetPoint("TOPLEFT", p.coinHautGauche, "BOTTOMLEFT")
	p.bordGauche:SetPoint("BOTTOMRIGHT", p.coinBasGauche, "TOPRIGHT")

	p.bordDroit = morceau("!" .. kit .. "-nineslice-edgeright", true)
	p.bordDroit:SetPoint("TOPLEFT", p.coinHautDroit, "BOTTOMLEFT")
	p.bordDroit:SetPoint("BOTTOMRIGHT", p.coinBasDroit, "TOPRIGHT")

	p.centre = morceau(kit .. "-nineslice-center", true)
	p.centre:SetPoint("TOPLEFT", p.coinHautGauche, "BOTTOMRIGHT")
	p.centre:SetPoint("BOTTOMRIGHT", p.coinBasDroit, "TOPLEFT")

	return p
end

-- Poser un cadre sur l'anneau, a l'angle voulu. Zero pointe a l'est, les
-- degres tournent dans le sens direct.
local function poserSurAnneau(cadre, carte, angle)
	local radians = angle * math.pi / 180
	cadre:ClearAllPoints()
	cadre:SetPoint("CENTER", carte, "CENTER",
		ANNEAU_RAYON * math.cos(radians), ANNEAU_RAYON * math.sin(radians))
end

local M = {}
ForeverUI.Minimap = M

-- LE JOUR DU MOIS dans l'image du calendrier. GameTimeFrame_SetDate de 3.3.5
-- ecrit le jour en TEXTE sur son bouton ; celui de camelot change d'image.
-- On garde son appel -- il suit le changement de jour -- et on fait comme
-- camelot par-dessus.
function M.majCalendrier()
	local bouton = _G["GameTimeFrame"]
	if not bouton then
		return
	end
	local jour = 1
	if CalendarGetDate then
		local _, _, j = CalendarGetDate()
		jour = j or jour
	end
	etatBouton(bouton, "Normal", string.format(CALENDRIER.ATLAS, jour, "up"))
	etatBouton(bouton, "Pushed", string.format(CALENDRIER.ATLAS, jour, "down"))
	local survol = etatBouton(bouton, "Highlight", string.format(CALENDRIER.ATLAS, jour, "mouseover"))
	if survol then
		survol:SetBlendMode("BLEND")
	end
	local texte = bouton.GetFontString and bouton:GetFontString()
	if texte then
		texte:SetAlpha(0)
	end
end

-- L'HORLOGE. Son fond de 3.3.5 est une texture SANS NOM (ClockBackground) :
-- on la retrouve parmi les regions, en epargnant le texte et la lueur de
-- l'alarme, que camelot garde telle quelle.
function M.habillerHorloge()
	local horloge = _G["TimeManagerClockButton"]
	local barre = M.barre
	if not horloge or not barre then
		return
	end
	local texte = _G["TimeManagerClockTicker"]
	local alarme = _G["TimeManagerAlarmFiredTexture"]
	for _, region in ipairs({ horloge:GetRegions() }) do
		if region ~= texte and region ~= alarme then
			etouffer(region)
		end
	end
	horloge:SetParent(M.cluster)
	horloge:SetWidth(HORLOGE.L)
	horloge:SetHeight(HORLOGE.H)
	horloge:ClearAllPoints()
	horloge:SetPoint("TOPRIGHT", barre, "TOPRIGHT", HORLOGE.X, 0)
	horloge:SetFrameLevel(barre:GetFrameLevel() + 1)
	horloge:SetHitRectInsets(HORLOGE.MARGES[1], HORLOGE.MARGES[2],
		HORLOGE.MARGES[3], HORLOGE.MARGES[4])
	if texte then
		texte:SetFont(HORLOGE.POLICE, HORLOGE.TAILLE)
		texte:SetShadowOffset(1, -1)
		texte:SetShadowColor(0, 0, 0, 1)
		texte:SetTextColor(1, 1, 1)
		texte:ClearAllPoints()
		texte:SetPoint("CENTER", horloge, "CENTER", HORLOGE.TEXTE_X, HORLOGE.TEXTE_Y)
	end
	M.horlogeHabillee = true
end

-- LES COORDONNEES. camelot demande C_Map.GetPlayerMapPosition sur la meilleure
-- carte ; 3.3.5 n'a que GetPlayerMapPosition, qui repond sur la carte
-- AFFICHEE par la carte du monde. On la ramene sur la zone du joueur aux
-- changements de zone et a la fermeture de la carte du monde -- jamais
-- pendant qu'elle est ouverte, on changerait la page que le joueur lit.
-- En instance, 3.3.5 rend (0, 0) : rien n'est ecrit, comme chez camelot
-- quand la position n'existe pas.
function M.recentrerCarteDuMonde()
	if SetMapToCurrentZone and not (WorldMapFrame and WorldMapFrame:IsShown()) then
		SetMapToCurrentZone()
	end
end

function M.majCoordonnees()
	local coords = M.coords
	if not coords then
		return
	end
	local x, y = 0, 0
	if GetPlayerMapPosition then
		x, y = GetPlayerMapPosition("player")
	end
	if not x or not y or (x == 0 and y == 0) then
		coords.texte:SetText("")
		return
	end
	if GetCVar and GetCVar("coordsByTenths") == "1" then
		coords.texte:SetText(string.format(COORD.DIXIEMES, x * 100, y * 100))
	else
		coords.texte:SetText(string.format(COORD.ENTIER,
			math.floor(x * 100 + 0.5), math.floor(y * 100 + 0.5)))
	end
end

-- POSER L'ECHELLE k SUR LA CARTE. Sa taille devient 198 / k, ce qui la laisse
-- a 198 a l'ecran. Ses fils que l'addon place lui-meme -- le fond qui porte le
-- cadre et les boutons, la zone du zoom -- recoivent 1 / k pour garder leur
-- taille. MinimapPing, lui, SUIT la carte : Minimap_SetPing le place en unites
-- de la carte (x * Minimap:GetWidth()).
local function appliquerEchelle(k)
	local carte = M.carte
	if not carte then
		return
	end
	M.echelle = k
	carte:SetScale(k)
	carte:SetWidth(CARTE_COTE / k)
	carte:SetHeight(CARTE_COTE / k)
	for _, fils in ipairs({ _G["MinimapBackdrop"], M.zoneZoom }) do
		if fils then
			fils:SetScale(1 / k)
		end
	end
end

M.appliquerEchelle = appliquerEchelle

local function construire()
	local cluster = _G["MinimapCluster"]
	local carte = _G["Minimap"]
	local fond = _G["MinimapBackdrop"]

	if not cluster or not carte or not fond then
		dire("minimap : le client n'a pas MinimapCluster, Minimap ou MinimapBackdrop.")
		return false
	end

	if not ForeverUI.SetAtlas then
		dire("minimap : AtlasUtil.lua manque, rien n'est habille.")
		return false
	end

	M.cluster = cluster
	M.carte = carte

	-- 1. LE CLUSTER. camelot garde les memes marges de souris qu'en 3.3.5 ;
	-- seule la taille change.
	cluster:SetWidth(CLUSTER_L)
	cluster:SetHeight(CLUSTER_H)
	cluster:SetFrameStrata("LOW")
	cluster:SetHitRectInsets(MARGES_SOURIS[1], MARGES_SOURIS[2],
		MARGES_SOURIS[3], MARGES_SOURIS[4])

	etouffer(_G["MinimapBorderTop"])

	-- 2. LE CONTENEUR ET LA CARTE.
	local conteneur = M.conteneur
	if not conteneur then
		conteneur = CreateFrame("Frame", "ForeverUIMinimapContainer", cluster)
		M.conteneur = conteneur
	end
	conteneur:SetWidth(CADRE_L)
	conteneur:SetHeight(CADRE_H)
	conteneur:ClearAllPoints()
	conteneur:SetPoint("TOP", cluster, "TOP", CONTENEUR_X, CONTENEUR_Y)

	carte:SetParent(conteneur)
	carte:ClearAllPoints()
	carte:SetPoint("CENTER", conteneur, "CENTER", 0, 0)
	carte:SetMaskTexture(CHEMIN_MASQUE)
	for _, fleche in ipairs(FLECHES) do
		if carte[fleche.methode] then
			carte[fleche.methode](carte, FLECHES.chemin .. fleche.fichier)
		end
	end

	-- 3. LE CADRE. Il se pose sur MinimapBackdrop, comme chez camelot : ce
	-- cadre est fils de la carte, donc dessine PAR-DESSUS le terrain et ses
	-- points, et ses propres fils -- les boutons -- passent au-dessus de lui.
	fond:SetWidth(CADRE_L)
	fond:SetHeight(CADRE_H)
	fond:ClearAllPoints()
	fond:SetPoint("CENTER", carte, "CENTER", 0, 0)

	etouffer(_G["MinimapBorder"])
	etouffer(_G["MinimapNorthTag"])
	etouffer(_G["MinimapCompassTexture"])

	local anneau = M.anneau
	if not anneau then
		anneau = fond:CreateTexture(nil, "ARTWORK")
		M.anneau = anneau
	end
	ForeverUI.SetAtlas(anneau, ATLAS_CADRE, true)
	anneau:SetWidth(CADRE_L)
	anneau:SetHeight(CADRE_H)
	anneau:ClearAllPoints()
	anneau:SetPoint("CENTER", fond, "CENTER", 0, 0)

	-- 4. LA BARRE DU NOM DE ZONE.
	local barre = M.barre
	if not barre then
		barre = CreateFrame("Frame", "ForeverUIMinimapBorderTop", cluster)
		M.barre = barre
		decouperEnNeuf(barre, KIT_BARRE, "BACKGROUND")
	end
	barre:SetWidth(BARRE_L)
	barre:SetHeight(BARRE_H)
	barre:ClearAllPoints()
	barre:SetPoint("TOP", cluster, "TOP", BARRE_X, BARRE_Y)

	local zoneBouton = _G["MinimapZoneTextButton"]
	if zoneBouton then
		zoneBouton:SetParent(cluster)
		zoneBouton:SetWidth(ZONE_L)
		zoneBouton:SetHeight(ZONE_H)
		zoneBouton:ClearAllPoints()
		zoneBouton:SetPoint("LEFT", barre, "LEFT", ZONE_X, 0)
		zoneBouton:SetFrameLevel(barre:GetFrameLevel() + 1)
	end

	local zoneTexte = _G["MinimapZoneText"]
	if zoneTexte then
		zoneTexte:SetWidth(TEXTE_L)
		zoneTexte:SetHeight(TEXTE_H)
		zoneTexte:ClearAllPoints()
		zoneTexte:SetPoint("CENTER", zoneBouton or barre, "CENTER", 0, TEXTE_Y)
		zoneTexte:SetDrawLayer("OVERLAY")
		-- La justification vient de l'attribut du gabarit camelot, pas de
		-- l'objet de police : GameFontNormal n'en porte aucune, donc centre.
		zoneTexte:SetJustifyH("LEFT")
		zoneTexte:SetJustifyV("MIDDLE")
	end

	-- 5. LE SUIVI. On garde le cadre du client -- c'est lui qui ouvre le menu
	-- des pistages et qui connait leur liste -- et on ne lui laisse que ca.
	local suivi = _G["MiniMapTracking"]
	if suivi then
		suivi:SetParent(cluster)
		suivi:SetWidth(SUIVI_COTE)
		suivi:SetHeight(SUIVI_COTE)
		suivi:ClearAllPoints()
		suivi:SetPoint("RIGHT", barre, "LEFT", SUIVI_X, 0)
		suivi:SetFrameLevel(barre:GetFrameLevel() + 1)

		etouffer(_G["MiniMapTrackingBackground"])
		etouffer(_G["MiniMapTrackingIcon"])
		etouffer(_G["MiniMapTrackingIconOverlay"])

		if not M.suiviFond then
			M.suiviFond = suivi:CreateTexture(nil, "BACKGROUND")
		end
		ForeverUI.SetAtlas(M.suiviFond, KIT_BARRE, true)
		M.suiviFond:SetAllPoints(suivi)

		local bouton = _G["MiniMapTrackingButton"]
		if bouton then
			bouton:SetWidth(SUIVI_BOUTON_L)
			bouton:SetHeight(SUIVI_BOUTON_H)
			bouton:ClearAllPoints()
			bouton:SetPoint("CENTER", suivi, "CENTER", 0, 0)
			bouton:SetHitRectInsets(0, 0, 0, 0)

			etouffer(_G["MiniMapTrackingButtonBorder"])
			etouffer(_G["MiniMapTrackingButtonShine"])

			etatBouton(bouton, "Normal", "ui-hud-minimap-tracking-up")
			etatBouton(bouton, "Pushed", "ui-hud-minimap-tracking-down")
			local survol = etatBouton(bouton, "Highlight", "ui-hud-minimap-tracking-mouseover")
			if survol then
				survol:SetBlendMode("BLEND")
			end
		end
	end

	-- 6. LE COURRIER, sous le suivi.
	local rangee = M.rangee
	if not rangee then
		rangee = CreateFrame("Frame", "ForeverUIMinimapIndicators", cluster)
		M.rangee = rangee
	end
	rangee:SetWidth(COURRIER_L)
	rangee:SetHeight(COURRIER_H)
	rangee:ClearAllPoints()
	rangee:SetPoint("TOPRIGHT", suivi or barre, "BOTTOMRIGHT", 0, 0)

	local courrier = _G["MiniMapMailFrame"]
	if courrier then
		courrier:SetParent(rangee)
		courrier:SetWidth(COURRIER_L)
		courrier:SetHeight(COURRIER_H)
		courrier:ClearAllPoints()
		courrier:SetPoint("TOPLEFT", rangee, "TOPLEFT", 0, 0)

		etouffer(_G["MiniMapMailIcon"])
		etouffer(_G["MiniMapMailBorder"])

		if not M.courrierIcone then
			M.courrierIcone = courrier:CreateTexture(nil, "ARTWORK")
		end
		ForeverUI.SetAtlas(M.courrierIcone, "ui-hud-minimap-mail-up")
		M.courrierIcone:ClearAllPoints()
		M.courrierIcone:SetPoint("TOPLEFT", courrier, "TOPLEFT", 0, 0)
	end

	-- 7. LE ZOOM. La zone de saisie passe en strate BACKGROUND, comme chez
	-- camelot : elle ne doit attraper la souris que la ou rien d'autre ne la
	-- prend, sinon elle volerait les clics de la carte.
	local zoneZoom = M.zoneZoom
	if not zoneZoom then
		zoneZoom = CreateFrame("Frame", "ForeverUIMinimapZoomHitArea", carte)
		zoneZoom:EnableMouse(true)
		zoneZoom:SetFrameStrata("BACKGROUND")
		M.zoneZoom = zoneZoom
	end
	zoneZoom:SetWidth(ZOOM_ZONE)
	zoneZoom:SetHeight(ZOOM_ZONE)
	zoneZoom:ClearAllPoints()
	zoneZoom:SetPoint("CENTER", carte, "CENTER", ZOOM_ZONE_X, ZOOM_ZONE_Y)

	local plus = _G["MinimapZoomIn"]
	local moins = _G["MinimapZoomOut"]

	local function habillerZoom(bouton, largeur, hauteur, x, y, nom)
		if not bouton then
			return
		end
		bouton:SetWidth(largeur)
		bouton:SetHeight(hauteur)
		bouton:ClearAllPoints()
		bouton:SetPoint("CENTER", carte, "CENTER", x, y)
		-- Les marges du client rognaient 4 px a gauche et a droite d'un
		-- bouton de 32 ; sur 17 il ne resterait rien a cliquer.
		bouton:SetHitRectInsets(0, 0, 0, 0)
		etatBouton(bouton, "Normal", nom)
		etatBouton(bouton, "Pushed", nom .. "-down")

		-- camelot ecrit `desaturated="true"` sur l'etat eteint. 3.3.5 a bien
		-- SetDesaturated, mais il REND FAUX quand la carte graphique ne sait
		-- pas le faire : on assombrit alors a la main.
		local eteint = etatBouton(bouton, "Disabled", nom)
		if eteint and not (eteint.SetDesaturated and eteint:SetDesaturated(true)) then
			eteint:SetVertexColor(0.45, 0.45, 0.45)
		end

		-- L'etat de survol du client est ADDITIF -- une lueur posee sur
		-- l'image. Celui de camelot est une IMAGE COMPLETE, la meme en plus
		-- clair : la poser en additif la ferait blanchir.
		local survol = etatBouton(bouton, "Highlight", nom .. "-mouseover")
		if survol then
			survol:SetBlendMode("BLEND")
		end
		bouton:Hide()
	end

	habillerZoom(plus, ZOOM_PLUS_L, ZOOM_PLUS_H, ZOOM_PLUS_X, ZOOM_PLUS_Y,
		"ui-hud-minimap-zoom-in")
	habillerZoom(moins, ZOOM_MOINS_L, ZOOM_MOINS_H, ZOOM_MOINS_X, ZOOM_MOINS_Y,
		"ui-hud-minimap-zoom-out")

	-- MinimapMixin:OnLeave ne cache les deux boutons que si la souris n'est
	-- plus sur AUCUN des quatre. On rejoue la meme condition.
	local function montrer()
		if plus then plus:Show() end
		if moins then moins:Show() end
	end

	local function cacherSiPossible()
		if plus and plus:IsMouseOver() then return end
		if moins and moins:IsMouseOver() then return end
		if zoneZoom:IsMouseOver() then return end
		if carte:IsMouseOver() then return end
		if plus then plus:Hide() end
		if moins then moins:Hide() end
	end

	M.montrerZoom = montrer
	M.cacherZoom = cacherSiPossible

	if not M.zoomBranche then
		carte:HookScript("OnEnter", montrer)
		carte:HookScript("OnLeave", cacherSiPossible)
		zoneZoom:SetScript("OnEnter", montrer)
		zoneZoom:SetScript("OnLeave", cacherSiPossible)
		if plus then
			plus:HookScript("OnEnter", montrer)
			plus:HookScript("OnLeave", cacherSiPossible)
		end
		if moins then
			moins:HookScript("OnEnter", montrer)
			moins:HookScript("OnLeave", cacherSiPossible)
		end
		M.zoomBranche = true
	end

	-- 8. L'ANNEAU DU CYCLE JOUR/NUIT.
	local cycle = M.cycle
	if not cycle then
		cycle = CreateFrame("Frame", "ForeverUIMinimapDiel", cluster)
		cycle:SetFrameLevel(CYCLE_NIVEAU)
		M.cycle = cycle
		M.astre = cycle:CreateTexture(nil, "BACKGROUND")
		M.astre:SetPoint("CENTER", cycle, "CENTER", 0, 0)
		M.cycleBord = cycle:CreateTexture(nil, "OVERLAY")
		M.cycleBord:SetAllPoints(cycle)
	end
	cycle:SetWidth(CYCLE_COTE)
	cycle:SetHeight(CYCLE_COTE)
	cycle:ClearAllPoints()
	cycle:SetPoint("CENTER", cluster, "CENTER", CYCLE_X, CYCLE_Y)
	ForeverUI.SetAtlas(M.cycleBord, ATLAS_CYCLE, true)
	M.astre:SetWidth(ASTRE_COTE)
	M.astre:SetHeight(ASTRE_COTE)

	-- 9. LA DIFFICULTE D'INSTANCE, au coin de la barre.
	local difficulte = _G["MiniMapInstanceDifficulty"]
	if difficulte then
		difficulte:SetParent(cluster)
		difficulte:ClearAllPoints()
		difficulte:SetPoint("TOPRIGHT", barre, "TOPRIGHT", 0, DIFFICULTE_Y)
	end

	-- 10. LE CALENDRIER, a droite de la barre.
	local calendrier = _G["GameTimeFrame"]
	if calendrier then
		calendrier:SetParent(cluster)
		calendrier:SetWidth(CALENDRIER.L)
		calendrier:SetHeight(CALENDRIER.H)
		calendrier:ClearAllPoints()
		calendrier:SetPoint("TOPLEFT", barre, "TOPRIGHT", CALENDRIER.X, 0)
		calendrier:SetFrameLevel(barre:GetFrameLevel() + 1)
		-- 3.3.5 lui donne des marges de 6/0/5/10 pour un bouton de 40 ;
		-- camelot n'en declare aucune.
		calendrier:SetHitRectInsets(0, 0, 0, 0)
		M.majCalendrier()
	end

	-- 11. L'HORLOGE, dans la barre. Blizzard_TimeManager se charge a la
	-- demande : si elle n'est pas encore la, ADDON_LOADED la rattrapera.
	M.habillerHorloge()

	-- 12. LES COORDONNEES DU JOUEUR, sous la carte. Frere de la carte dans le
	-- conteneur, comme PlayerCoords chez camelot.
	local coords = M.coords
	if not coords then
		coords = CreateFrame("Frame", "ForeverUIMinimapPlayerCoords", conteneur)
		coords.texte = coords:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		coords.texte:SetAllPoints(coords)
		coords.texte:SetJustifyH("CENTER")
		coords.attente = 0
		coords:SetScript("OnUpdate", function(self, ecoule)
			self.attente = self.attente - (ecoule or 0)
			if self.attente > 0 then
				return
			end
			self.attente = COORD.PERIODE
			M.majCoordonnees()
		end)
		M.coords = coords
	end
	coords:SetWidth(COORD.L)
	coords:SetHeight(COORD.H)
	coords:ClearAllPoints()
	coords:SetPoint("BOTTOM", carte, "BOTTOM", 0, COORD.Y)

	-- 13. L'ECHELLE, en dernier : la zone du zoom doit exister.
	appliquerEchelle(M.echelle or ECHELLE_CARTE)

	-- 14. LES QUATRE BOUTONS QUE CAMELOT N'A PAS, poses sur l'anneau.
	for _, item in ipairs(AUTOUR) do
		local bouton = _G[item.nom]
		if bouton then
			bouton:SetParent(fond)
			poserSurAnneau(bouton, carte, item.angle)
		end
	end

	return true
end

-- L'HEURE DU SERVEUR decide de l'astre. 3.3.5 n'a pas d'evenement de cycle :
-- on relit l'heure une fois par minute.
local function majCycle()
	if not M.astre then
		return
	end
	local heure = GetGameTime and GetGameTime() or 12
	local jour = heure >= AUBE and heure < CREPUSCULE
	M.jour = jour
	ForeverUI.SetAtlas(M.astre, jour and ATLAS_JOUR or ATLAS_NUIT, true)
end

M.Refresh = function()
	if M.cluster then
		majCycle()
	end
end

local veilleur = CreateFrame("Frame")
veilleur.ecoule = 0
veilleur:RegisterEvent("PLAYER_ENTERING_WORLD")
veilleur:RegisterEvent("MINIMAP_UPDATE_ZOOM")
veilleur:RegisterEvent("ADDON_LOADED")
veilleur:RegisterEvent("ZONE_CHANGED_NEW_AREA")
veilleur:SetScript("OnEvent", function(_self, event, arg1)
	if event == "PLAYER_ENTERING_WORLD" then
		construire()
		majCycle()
		M.recentrerCarteDuMonde()
	elseif event == "ADDON_LOADED" then
		if arg1 == "Blizzard_TimeManager" then
			M.habillerHorloge()
		end
	elseif event == "ZONE_CHANGED_NEW_AREA" then
		M.recentrerCarteDuMonde()
	elseif event == "MINIMAP_UPDATE_ZOOM" then
		-- MinimapMixin:OnEvent eteint le bouton arrive au bout de sa course.
		local plus, moins = _G["MinimapZoomIn"], _G["MinimapZoomOut"]
		local carte = M.carte
		if plus and moins and carte and carte.GetZoom and carte.GetZoomLevels then
			local niveau = carte:GetZoom()
			if niveau == carte:GetZoomLevels() - 1 then plus:Disable() else plus:Enable() end
			if niveau == 0 then moins:Disable() else moins:Enable() end
		end
	end
end)

veilleur:SetScript("OnUpdate", function(self, elapsed)
	self.ecoule = self.ecoule + (elapsed or 0)
	if self.ecoule < CYCLE_PERIODE then
		return
	end
	self.ecoule = 0
	majCycle()
end)

-- GameTimeFrame_SetDate est rappelee par le client a chaque changement de
-- jour : on repasse derriere elle.
if hooksecurefunc and GameTimeFrame_SetDate then
	hooksecurefunc("GameTimeFrame_SetDate", function() M.majCalendrier() end)
end
if WorldMapFrame and WorldMapFrame.HookScript then
	WorldMapFrame:HookScript("OnHide", function() M.recentrerCarteDuMonde() end)
end

if construire() then
	majCycle()
	-- La minimap s'enregistre comme tout le reste : rien dans ce projet ne
	-- pose sa position definitive lui-meme, sinon elle serait la seule que le
	-- joueur ne pourrait pas deplacer.
	if ForeverUI.Layout and ForeverUI.Layout.Register then
		ForeverUI.Layout.Register(_G["MinimapCluster"], "minimap", "Minimap",
			"TOPRIGHT", "TOPRIGHT", 0, 0)
	end
end


ForeverUI.MinimapDebug = function(argument)
	local cluster, carte = M.cluster, M.carte
	if not cluster or not carte then
		dire("minimap : rien de construit.")
		return
	end

	-- `/fui minimap echelle <k>` : retoucher l'echelle a la main, jusqu'au
	-- prochain /reload. Sans nombre, rend celle du projet.
	if argument and string.match(argument, "^echelle%s*$") then
		argument = "echelle " .. ECHELLE_CARTE
	end
	local k = argument and tonumber(string.match(argument, "^echelle%s+([%d%.]+)$"))
	if k and k > 0 then
		appliquerEchelle(k)
		dire(string.format("minimap : echelle %.3f, taille %.1f, a l'ecran %.1f",
			k, carte:GetWidth(), carte:GetWidth() * k))
		return
	end

	local function ligne(texte)
		DEFAULT_CHAT_FRAME:AddMessage("   " .. texte)
	end

	dire(string.format("minimap : cluster %.0f x %.0f | conteneur %.0f x %.0f | carte %.0f",
		cluster:GetWidth(), cluster:GetHeight(),
		M.conteneur:GetWidth(), M.conteneur:GetHeight(), carte:GetWidth()))
	ligne(string.format("cadre %s | masque %s | echelle %.3f (projet %.3f)",
		ATLAS_CADRE, CHEMIN_MASQUE, M.echelle or 1, ECHELLE_CARTE))
	ligne(string.format("zone : \"%s\" justifie %s, largeur %.0f",
		tostring(_G["MinimapZoneText"] and _G["MinimapZoneText"]:GetText()),
		tostring(_G["MinimapZoneText"] and _G["MinimapZoneText"]:GetJustifyH()),
		_G["MinimapZoneText"] and _G["MinimapZoneText"]:GetWidth() or 0))
	ligne(string.format("zoom : niveau %s sur %s | plus visible=%s | moins visible=%s",
		tostring(carte:GetZoom()), tostring(carte:GetZoomLevels()),
		tostring(_G["MinimapZoomIn"] and _G["MinimapZoomIn"]:IsShown()),
		tostring(_G["MinimapZoomOut"] and _G["MinimapZoomOut"]:IsShown())))
	ligne(string.format("cycle : heure %s -> %s", tostring(GetGameTime and GetGameTime()),
		M.jour and "jour" or "nuit"))

	ligne(string.format("horloge : %s | calendrier : %s | coordonnees : '%s'",
		_G["TimeManagerClockButton"] and (M.horlogeHabillee and "habillee" or "pas habillee") or "pas chargee",
		_G["GameTimeFrame"] and (_G["GameTimeFrame"]:IsShown() and "visible" or "masque") or "ABSENT",
		tostring(M.coords and M.coords.texte:GetText())))

	for _, item in ipairs(AUTOUR) do
		local bouton = _G[item.nom]
		ligne(string.format("%-26s %s, angle %d", item.nom,
			bouton and (bouton:IsShown() and "visible" or "masque") or "ABSENT",
			item.angle))
	end
end
