-- ForeverUI : l'onglet PvP.
--
-- RELEVE -- camelot/PVPRankFrame.xml et pvprankframe.lua, lus en entier.
--
-- PVPRankFrame         setAllPoints, parent CharacterFrame, useParentLevel
--   SeasonTimerField   GameFontNormal, aligne a DROITE, TOPRIGHT sur
--                      CharacterFrameLeftPaneHost (-46, -18)
--   MainInfoFrame      TOPLEFT sur le meme (0, -60)
--                      BOTTOMRIGHT sur son TOPRIGHT (0, -195)
--     CurrentSeasonField        GameFontNormalMed2, centre, TOP (0, -20)
--     CurrentRankField          GameFontHighlightLarge, centre, TOP du
--                               BOTTOM de la saison (0, -10)
--     CurrentRankProgressField  GameFontNormal, centre, TOP du BOTTOM du
--                               rang (0, -210)
--     Line                      UI-Character-Info-Honor-LevelBG, BOTTOM du
--                               BOTTOM du rang, y = -10
--     RankProgressBarDisplay    un Cooldown de 154 x 154, TOP (0, -95),
--                               renverse et tourne de 180 :
--       lueur        UI-Character-Info-Honor-Bar-BG-Glow, 275 x 295, centree
--       fond         115 x 115, centre : -BG-Horde ou -BG-Alliance
--       anneau       235 x 209, CENTER (0, -1)
--       badge        72 x 84, centre : -Icon-<rang>, ou -Icon-Horde /
--                    -Icon-Alliance quand le rang est nul
--       NextRewardLevel  au BOTTOM (0, -1) : l'anneau
--                    UI-Character-Info-Honor-RewardRing, et le NUMERO du
--                    rang en GameFontNormalLarge, centre
--   DetailFrame        CharacterFrameSidePaneTemplate
--
-- CE QUE 3.3.5 DONNE, ET CE QU'IL NE DONNE PAS.
--
-- camelot tire tout de C_MajorFactions -- le systeme de renom -- qui n'existe
-- pas ici. Les trois fonctions de l'epoque des rangs sont TOUJOURS dans le
-- binaire, verifie dans Wow.exe : UnitPVPRank, GetPVPRankInfo et
-- GetPVPRankProgress. WotLK a simplement cesse de s'en servir dans son
-- FrameXML.
--
-- MAIS ELLES NE RENDENT RIEN, et le temoin /fui pvp l'a dit : UnitPVPRank = 0
-- avec 67 victoires honorables au compteur. La raison est dans le serveur, et
-- non dans le client -- mod-pvp-titles/src/mod_pvp_titles.cpp, lu en entier :
-- le module pose des TITRES, par SetTitle sur CharTitles, et ne touche jamais
-- au vieux compteur de rang. Le rang se demande donc aux titres connus, par
-- IsTitleKnown -- present dans le binaire, verifie -- et la progression se
-- calcule sur les victoires honorables, que GetPVPLifetimeStats donne.
--
-- Heureuse coincidence : la planche de camelot porte QUATORZE icones de rang,
-- exactement les quatorze rangs de l'epoque. Son art c60 EST celui des rangs
-- classiques.
--
-- Quand il n'y a pas de rang, l'ecran montre l'embleme de la faction. Ce que
-- WotLK sait vraiment donner -- les statistiques d'honneur, par
-- GetPVPLifetimeStats, GetPVPSessionStats, GetPVPYesterdayStats et
-- GetHonorCurrency -- s'ecrit dans le volet gauche, sous le titre ; le volet
-- droit est vide (2026-09-26).
--
-- LA JAUGE CIRCULAIRE, REFAITE PAR QUADRANTS.
--
-- camelot la fait avec un Cooldown dont il remplace la texture de balayage :
--   <Cooldown reverse="true" rotation="180">
--     <SwipeTexture file="Interface/PVPFrame/pvpqueue-sidebar-honorbar-fill"/>
-- SetSwipeTexture est ABSENT du binaire de 3.3.5 -- verifie -- et la texture
-- de balayage de son Cooldown est cablee dans le moteur : la remplacer
-- changerait TOUS les temps de recharge du jeu.
--
-- ON REFAIT DONC LE BALAYAGE. Le cadran est coupe en quatre quarts. Un quart
-- que la jauge a depasse montre le quart de l'anneau tel quel ; le quart ou
-- la jauge s'arrete montre un DEMI anneau -- la moitie gauche, cuite par
-- tools/cuire_masque.py -- qu'on fait TOURNER par SetTexCoord a huit
-- arguments. Un demi anneau tourne de phi couvre les 180 degres qui
-- FINISSENT a phi ; le rectangle du quadrant le coupe, et il ne reste que
-- l'arc voulu. Aucun masque, aucun ScrollFrame : quatre textures.
--
--   rotation="180" : la jauge PART DU BAS, six heures.
--   sens : celui des aiguilles, celui du Cooldown. Depuis le bas, elle monte
--          donc par la GAUCHE. Si elle tournait a l'envers en jeu, c'est
--          JAUGE_SENS qu'il faudrait passer a -1.
--
-- CE QUI DIFFERE, ET POURQUOI :
--   * GameFontNormalMed2 n'existe pas : GameFontNormalLarge le remplace.
--   * Le compte a rebours de fin de saison demande
--     C_SeasonInfo.GetTimeUntilCurrentPVPSeasonEnd, absent lui aussi. La
--     ligne reste, vide.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local SAISON_X, SAISON_Y = -46, -18
-- LE HAUT DU VOLET (demande du 2026-09-25 : y faire entrer les equipes
-- d'arene et les points d'arene). "Arena N" s'en va, et le rang, la jauge et
-- les victoires honorables remontent le plus haut possible : le bloc part
-- du haut du volet, le titre du rang a RANG_HAUT sous lui, le cadran garde
-- son ecart d'avant au titre (49 : -95 sous le bloc, le titre etant a -46
-- -- saison a -20, sa ligne de 16, puis -10).
--
-- REMONTES ENCORE DE 10, a la demande (2026-09-25) : le cadran et le
-- compteur de victoires, le titre restant ou il est. Mesure sur l'art
-- (ui-character-info-honor-bar-bg, 230 x 201 pose en 235 x 209) : son
-- anneau commence a 10 px sous le bord de l'image ; a -51, le haut visible
-- de l'anneau tombe vers -35, a quelques pixels sous le titre. Plus haut,
-- il le toucherait.
--
-- L'HONNEUR ENTRE LE TITRE ET LA JAUGE (demande du 2026-09-26). Les quatre
-- donnees du volet droit -- points d'honneur, victoires honorables,
-- aujourd'hui, hier -- descendent dans le volet gauche, sur DEUX COLONNES,
-- entre le trait du titre et la jauge, puis un separateur. Le cadran ne se
-- pose donc plus au titre mais sous ce separateur.
--
-- Mesures sur l'alpha des images (seuil 128, l'ombre ne compte pas) :
--   le trait du titre   ui-character-info-honor-levelbg, 350 x 62, plein
--                       des lignes 53 a 58 : il finit 4 au-dessus du bas de
--                       son image
--   l'anneau            plein a partir de la ligne 31 de 201 (pose en 209) :
--                       son haut visible tombe 6 sous le haut du cadran
local BLOC_Y = 0
local RANG_HAUT = -12
local HONNEUR_SOUS_LIGNE = -2           -- 6 sous le trait plein
local HONNEUR_L = 366
local HONNEUR_COLONNE = 173             -- (366 - 20) / 2
local HONNEUR_RANGEE_H, HONNEUR_ECART = 14, 3
local SEPARATEUR_HONNEUR_Y = -4
local CADRAN_SOUS_SEPARATEUR = 0        -- l'anneau parait 6 plus bas
local BLOC_Y2 = -195
local SAISON_TITRE_Y = -20
-- LE COMPTEUR, 5 PX SOUS LA JAUGE (demande du 2026-09-25). Il s'accroche
-- au cadran et non plus au titre.
--
-- LE BAS VISIBLE DE LA JAUGE, mesure sur l'alpha des images (2026-09-26,
-- remonte a la demande). L'anneau (230 x 201, pose en 235 x 209) est PLEIN
-- jusqu'a la ligne 169 ; les vingt suivantes ne sont qu'une ombre qui
-- s'eteint (alpha 133 a 2) -- les compter, comme la premiere fois, placait
-- le compteur 22 px trop bas. Son bas plein tombe ainsi a 5 AU-DESSUS du bas
-- du cadran ; celui de l'anneau numerote (54, plein jusqu'a la ligne 49,
-- pose a -1) a 4 au-dessus. Cinq sous le plus bas des deux : -1.
-- Sa hauteur est fixe : sans rang il est vide, et ce qui le suit (le
-- separateur, les points d'arene, les equipes) ne doit pas remonter.
local PROGRES_SOUS_CADRAN = -1
local PROGRES_H = 12
local LIGNE_Y = -10

local CADRAN = 154
local LUEUR_L, LUEUR_H = 275, 295
local FOND_L, FOND_H = 115, 115
local ANNEAU_L, ANNEAU_H = 235, 209
local ANNEAU_Y = -1
local BADGE_L, BADGE_H = 72, 84
local RECOMPENSE_Y = -1

local ATLAS_LIGNE = "ui-character-info-honor-levelbg"
local ATLAS_LUEUR = "ui-character-info-honor-bar-bg-glow"
local ATLAS_ANNEAU = "ui-character-info-honor-bar-bg"
local ATLAS_FOND = "ui-character-info-honor-bar-bg-%s"
local ATLAS_BADGE_FACTION = "ui-character-info-honor-icon-%s"
local ATLAS_BADGE_RANG = "ui-character-info-honor-icon-%d"
local ATLAS_ANNEAU_RECOMPENSE = "ui-character-info-honor-rewardring"
local ATLAS_SEPARATEUR_LONG = "ui-character-info-scrollline-long"

-- LA JAUGE. Les deux morceaux cuits, l'angle de depart et le sens.
local JAUGE_ENTIER = "Interface\\ForeverUI\\PvP\\honorfill"
local JAUGE_MOITIE = "Interface\\ForeverUI\\PvP\\honorfillhalf"
local JAUGE_DEPART = 180        -- <Cooldown rotation="180"> : six heures
local JAUGE_SENS = 1            -- 1 : sens des aiguilles ; -1 : l'inverse


local VOLET_L, VOLET_H = 398, 464

local bloc, detail

-- DECLAREES AVANT D'ETRE ECRITES. majBloc borne la fenetre a chaque passage,
-- et il est ecrit plus haut qu'elles : sans ces deux lignes leurs noms s'y
-- resoudraient en GLOBALES, donc nil. Le meme piege que majEtatSelecteurs
-- dans CharacterFrame.lua.
local hoteGauche
local bornerAuVolet

-- --------------------------------------------------------------- les donnees

local function faction()
	return (UnitFactionGroup and UnitFactionGroup("player")) or "Alliance"
end

-- LE NOM D'UN RANG SE LIT DANS LES CHAINES DU CLIENT, ET ELLES DONNENT LE
-- DECALAGE.
--
-- camelot le fait ainsi -- GetPVPRankText :
--   faction01 = (Alliance) et 1 ou 0
--   cle = "PVP_RANK_" .. (Rank_1 + rang - 1) .. "_" .. faction01
--
-- Ce client porte les QUARANTE chaines, et leur ordre tranche une question
-- que je n'aurais pas su resoudre autrement -- releve dans GlobalStrings :
--
--   PVP_RANK_1..4   Pariah, Outlaw, Exiled, Dishonored : les rangs NEGATIFS
--   PVP_RANK_5      Scout / Private                    : le rang 1
--   PVP_RANK_6      Grunt / Corporal                   : le rang 2
--   PVP_RANK_10     Stone Guard / Knight               : le rang 6
--
-- L'INDICE DE UnitPVPRank EST DONC LA CLE, telle quelle : le numero
-- affichable vaut l'indice moins quatre, et c'est ce decalage-la, celui de
-- l'epoque des rangs, que la table des chaines confirme.
--
-- On nomme ainsi plutot que par GetPVPRankInfo, qui ne rend rien ici --
-- releve par /fui pvp : UnitPVPRank = 0, nom = nil.
-- SANS RANG, LE JOUEUR EST UN CIVIL, PAS UN DESHONORE.
--
-- Le nom d'un rang se lit a l'indice "numero + 4". A numero = 0, cela donne
-- l'indice 4 -- PVP_RANK_4, "Dishonored" -- et l'ecran annoncait donc
-- deshonore tout joueur de moins de cinquante victoires. Or les indices 1 a
-- 4, Pariah, Outlaw, Exiled et Dishonored, sont les rangs NEGATIFS, ceux
-- qu'on obtient en tuant des civils : rien a voir avec un joueur qui n'a
-- simplement pas encore de rang.
--
-- ECART ASSUME : "Civilian" N'EST PAS UNE CHAINE DU CLIENT. Cherchee dans
-- GlobalStrings -- les quarante chaines de rang vont de PVP_RANK_0 a
-- PVP_RANK_19, aucune ne la porte -- et dans le binaire : absente des deux.
-- Elle est donc ecrite en clair ici, et ne se traduira pas. L'autre choix
-- serait de n'ecrire aucun titre du tout ; celui-ci a ete demande.
local NOM_SANS_RANG = "Civilian"

local function nomDuRang(indice)
	if not indice or indice <= 0 then
		return nil
	end
	local faction01 = (faction() == "Alliance") and 1 or 0
	return _G["PVP_RANK_" .. tostring(indice) .. "_" .. tostring(faction01)]
end

-- LE RANG NE VIENT PAS DU COMPTEUR DE RANG : IL VIENT DES TITRES.
--
-- Releve dans le module du serveur, modules/mod-pvp-titles/src/
-- mod_pvp_titles.cpp, lu en entier : AwardEarnedTitles compare les victoires
-- honorables de toute une vie a quatorze seuils, et pose un TITRE --
-- me->SetTitle(sCharTitlesStore.LookupEntry(...)). Il ne touche a AUCUN
-- moment au vieux compteur de rang de l'epoque classique.
--
-- UnitPVPRank reste donc a zero pour toujours, quel que soit le nombre de
-- victoires, et c'est aux titres connus qu'il faut demander le rang.
--
-- LES IDENTIFIANTS. Releve dans CharTitles.dbc du serveur, et l'ordre y est
-- celui des rangs : 1 a 14 pour l'Alliance -- Private ... Grand Marshal --
-- et 15 a 28 pour la Horde -- Scout ... High Warlord. Pour ces
-- identifiants-la, et pour eux seuls, l'indice de bit vaut l'identifiant :
-- IsTitleKnown les lit tels quels.
local TITRE_PREMIER = { Alliance = 1, Horde = 15 }
local RANGS = 14

-- IsTitleKnown REND UN NOMBRE, PAS UN BOOLEEN, ET ZERO EST VRAI EN LUA.
--
-- Le client l'ecrit lui-meme -- Interface/FrameXML/PaperDollFrame.lua, ligne
-- 2605, lu dans l'archive :
--   for i = 1, GetNumTitles() do
--       if ( IsTitleKnown(i) ~= 0 ) then
--
-- Ecrit `if IsTitleKnown(id) then`, le test est VRAI pour tous les titres :
-- la boucle partait de 14 et s'arretait au premier tour. En jeu, cela donnait
-- "Grand Marshal", le rang 14 et la jauge pleine a 67 victoires.
local function titreConnu(identifiant)
	if not IsTitleKnown then
		return false
	end
	local connu = IsTitleKnown(identifiant)
	return connu ~= nil and connu ~= false and connu ~= 0
end

local function rangParLesTitres()
	local premier = TITRE_PREMIER[faction()] or TITRE_PREMIER.Alliance
	for numero = RANGS, 1, -1 do
		if titreConnu(premier + numero - 1) then
			return numero
		end
	end
	return 0
end

-- CE QU'IL FAUT DE VICTOIRES POUR CHAQUE RANG.
--
-- ECART ASSUME, ET LE SEUL DE CET ECRAN QUE LE CLIENT NE PEUT PAS VERIFIER.
-- Ces quatorze nombres sont la CONFIGURATION DU SERVEUR --
-- configs/modules/mod_pvptitles.conf, cles PvPTitles.Rank_1 a Rank_14 --
-- et aucune fonction du client ne les demande. Ils sont donc recopies ici,
-- releves le 23/09/2026 sur la production. Si le serveur change ses seuils,
-- CETTE TABLE EST LE SEUL ENDROIT A REPRENDRE.
--
-- Sans eux la jauge resterait vide : GetPVPRankProgress ne rend rien, pour
-- la meme raison qu'UnitPVPRank.
local SEUILS = { 50, 100, 250, 500, 750, 1000, 1500, 2000, 2500, 3000,
                 3500, 4000, 5000, 6500 }

local function progresParLesVictoires(numero, victoires)
	local suivant = SEUILS[numero + 1]
	if not suivant then
		return 1          -- rang maximal : la jauge est pleine
	end
	local acquis = (numero > 0) and SEUILS[numero] or 0
	if suivant <= acquis then
		return 0
	end
	local part = ((victoires or 0) - acquis) / (suivant - acquis)
	if part < 0 then
		return 0
	elseif part > 1 then
		return 1
	end
	return part
end

local function lireRang()
	local indice = UnitPVPRank and UnitPVPRank("player") or 0
	local nom, numero
	if indice and indice > 0 and GetPVPRankInfo then
		nom, numero = GetPVPRankInfo(indice, "player")
	end

	if not numero or numero <= 0 then
		numero = (indice > 4) and (indice - 4) or 0
	end

	-- Le compteur n'est plus alimente : on demande aux titres.
	if numero <= 0 then
		numero = rangParLesTitres()
	end

	-- LE NOM. Trois cas, et pas deux.
	--   numero > 0        un vrai rang : indice = numero + 4
	--   indice de 1 a 4   un rang NEGATIF -- Pariah, Outlaw, Exiled,
	--                     Dishonored -- qui se nomme par son indice tel quel
	--   ni l'un ni l'autre le joueur n'a pas de rang : il est CIVIL
	if not nom then
		if numero > 0 then
			nom = nomDuRang(numero + 4)
		elseif indice and indice >= 1 and indice <= 4 then
			nom = nomDuRang(indice)
		else
			nom = NOM_SANS_RANG
		end
	end

	local victoires = 0
	if GetPVPLifetimeStats then
		victoires = GetPVPLifetimeStats() or 0
	end

	local progres = 0
	if GetPVPRankProgress then
		progres = GetPVPRankProgress() or 0
	end
	if not progres or progres <= 0 then
		progres = progresParLesVictoires(numero, victoires)
	end

	return {
		indice = indice,
		nom = nom,
		numero = numero,
		progres = progres,
		victoires = victoires,
		seuil = SEUILS[numero + 1],
	}
end

-- CE QUE WotLK SAIT TOUJOURS DONNER : l'honneur.
local function lireHonneur()
	local vie, deshonneur, meilleurRang = 0, 0, 0
	if GetPVPLifetimeStats then
		vie, deshonneur, meilleurRang = GetPVPLifetimeStats()
	end
	local jour, pointsJour = 0, 0
	if GetPVPSessionStats then
		jour, pointsJour = GetPVPSessionStats()
	end
	local hier, pointsHier = 0, 0
	if GetPVPYesterdayStats then
		hier, pointsHier = GetPVPYesterdayStats()
	end
	local courant = GetHonorCurrency and GetHonorCurrency() or 0

	return {
		vie = vie or 0,
		deshonneur = deshonneur or 0,
		meilleurRang = meilleurRang or 0,
		jour = jour or 0,
		pointsJour = pointsJour or 0,
		hier = hier or 0,
		pointsHier = pointsHier or 0,
		courant = courant or 0,
	}
end

-- ----------------------------------------------------------------- la jauge

-- LES QUATRE QUARTS, dans le sens des aiguilles depuis midi, en fraction du
-- cadran : u vers la droite, v vers le BAS -- le repere des coordonnees de
-- texture.
local QUADRANTS = {
	{ 0.5, 1.0, 0.0, 0.5 },   -- haut-droit  : de   0 a  90 degres
	{ 0.5, 1.0, 0.5, 1.0 },   -- bas-droit   : de  90 a 180
	{ 0.0, 0.5, 0.5, 1.0 },   -- bas-gauche  : de 180 a 270
	{ 0.0, 0.5, 0.0, 0.5 },   -- haut-gauche : de 270 a 360
}

-- OU LIRE, dans une texture qu'on a fait tourner de phi dans le sens des
-- aiguilles, le point (u, v) du cadran entier.
--
-- SetTexCoord a huit arguments ne deplace pas les quatre coins du rectangle a
-- l'ecran : il dit seulement quel point de l'image chacun montre. Faire
-- tourner l'image revient donc a faire tourner la LECTURE en sens inverse
-- autour du centre. Ce qui tombe hors de [0, 1] recopie le texel du bord, et
-- ce bord est vide : les coins restent transparents.
local function tourner(u, v, cosinus, sinus)
	local du, dv = u - 0.5, v - 0.5
	return 0.5 + du * cosinus + dv * sinus, 0.5 - du * sinus + dv * cosinus
end

local function poserQuart(tex, cadran, u1, u2, v1, v2)
	if JAUGE_SENS < 0 then
		u1, u2 = 1 - u2, 1 - u1
	end
	tex:ClearAllPoints()
	tex:SetPoint("TOPLEFT", cadran, "TOPLEFT", u1 * CADRAN, -v1 * CADRAN)
	tex:SetPoint("BOTTOMRIGHT", cadran, "TOPLEFT", u2 * CADRAN, -v2 * CADRAN)
end

local function monterJauge(cadran)
	local quarts = {}
	for i = 1, 4 do
		local quart = QUADRANTS[i]
		local u1, u2, v1, v2 = quart[1], quart[2], quart[3], quart[4]
		local q = { u1 = u1, u2 = u2, v1 = v1, v2 = v2 }

		-- Ou commence ce quart, compte depuis le depart de la jauge.
		q.depart = (90 * (i - 1) - JAUGE_DEPART) % 360

		-- Le quart DEPASSE : l'anneau entier, lu sur ce quart.
		q.plein = cadran:CreateTexture(nil, "ARTWORK")
		q.plein:SetTexture(JAUGE_ENTIER)
		q.plein:SetTexCoord(u1, u2, v1, v2)
		poserQuart(q.plein, cadran, u1, u2, v1, v2)
		q.plein:Hide()

		-- Le quart OU LA JAUGE S'ARRETE : le demi anneau, tourne.
		q.arc = cadran:CreateTexture(nil, "ARTWORK")
		q.arc:SetTexture(JAUGE_MOITIE)
		poserQuart(q.arc, cadran, u1, u2, v1, v2)
		q.arc:Hide()

		quarts[i] = q
	end
	return quarts
end

local function majJauge(fraction)
	if not bloc or not bloc.jauge then
		return
	end

	fraction = fraction or 0
	if fraction < 0 then
		fraction = 0
	elseif fraction > 1 then
		fraction = 1
	end
	local parcouru = fraction * 360

	for i = 1, 4 do
		local q = bloc.jauge[i]
		if parcouru >= q.depart + 90 then
			q.arc:Hide()
			q.plein:Show()
		elseif parcouru <= q.depart then
			q.arc:Hide()
			q.plein:Hide()
		else
			q.plein:Hide()

			-- Le demi anneau couvre les 180 degres qui FINISSENT a l'angle
			-- dont on l'a tourne. On veut qu'ils finissent sur la tete de la
			-- jauge, JAUGE_DEPART + parcouru : on le tourne donc de cet
			-- angle, moins le demi-tour qu'il porte deja.
			local phi = math.rad(JAUGE_DEPART + parcouru - 360)
			local cosinus, sinus = math.cos(phi), math.sin(phi)
			local hgu, hgv = tourner(q.u1, q.v1, cosinus, sinus)
			local bgu, bgv = tourner(q.u1, q.v2, cosinus, sinus)
			local hdu, hdv = tourner(q.u2, q.v1, cosinus, sinus)
			local bdu, bdv = tourner(q.u2, q.v2, cosinus, sinus)
			q.arc:SetTexCoord(hgu, hgv, bgu, bgv, hdu, hdv, bdu, bdv)
			q.arc:Show()
		end
	end
end
ForeverUI.PvPGauge = majJauge

-- --------------------------------------------------------------- l'affichage

local function poserBadge(rang)
	if not bloc then
		return
	end

	-- UpdateFactionBadge : sans rang, l'embleme de la faction ; avec, le
	-- badge du rang.
	local pose = false
	if rang.numero and rang.numero > 0 then
		pose = ForeverUI.SetAtlas(bloc.badge,
			string.format(ATLAS_BADGE_RANG, rang.numero), true)
	end
	if not pose then
		ForeverUI.SetAtlas(bloc.badge,
			string.format(ATLAS_BADGE_FACTION, string.lower(faction())), true)
	end
	bloc.badge:SetWidth(BADGE_L)
	bloc.badge:SetHeight(BADGE_H)
end

local function majBloc()
	if not bloc then
		return
	end

	bornerAuVolet()

	local rang = lireRang()

	-- LA SAISON PORTE SON INTITULE.
	--
	-- Elle s'ecrivait en chiffre nu, juste au-dessus du rang : un "1" seul
	-- se lisait comme un rang. camelot ecrit EXPANSION_SEASON_NAME, que ce
	-- client n'a pas ; ARENA -- "Arena" -- est ce qu'il porte de plus
	-- proche.
	--
	-- RETIREE le 2026-09-25, a la demande : la place va aux equipes d'arene.
	bloc.saison:SetText("")
	bloc.saison:Hide()

	-- LE TITRE EN HAUT, LE NUMERO DANS L'ANNEAU.
	--
	-- A LA DEMANDE, et non d'apres la source : camelot ecrit les deux en
	-- haut -- PVP_RANK_NUMBER_AND_TITLE donne "Rang N : Nom" dans le
	-- CurrentRankField -- puis repete le numero dans l'anneau de recompense,
	-- par LevelLabel. Ici le titre reste seul en haut, et le numero n'est
	-- qu'a un endroit : dans le cercle dore.
	bloc.rang:SetText(rang.nom or "")

	-- L'HONNEUR, AUX INTITULES DU CLIENT, DANS SA LANGUE.
	--
	-- Ils se lisaient dans LIFETIME_HONORABLE_KILLS, TODAY et YESTERDAY,
	-- qu'aucun GlobalStrings de 3.3.5 ne porte : le texte de secours, en
	-- francais, s'affichait sur un client anglais (releve du 2026-09-26).
	-- Ceux du client, releves dans son GlobalStrings.lua -- les memes que
	-- PVPHonor de WotLK : HONOR_POINTS "Honor Points", HONORABLE_KILLS
	-- "Honorable Kills", HONOR_TODAY "Today", HONOR_YESTERDAY "Yesterday".
	local honneur = lireHonneur()
	local cases = {
		{ HONOR_POINTS or "", honneur.courant },
		{ HONORABLE_KILLS or "", honneur.vie },
		{ HONOR_TODAY or "",
		  tostring(honneur.jour) .. " (" .. tostring(honneur.pointsJour) .. ")" },
		{ HONOR_YESTERDAY or "",
		  tostring(honneur.hier) .. " (" .. tostring(honneur.pointsHier) .. ")" },
	}
	for n, c in ipairs(cases) do
		bloc.honneur.cases[n].intitule:SetText(c[1])
		bloc.honneur.cases[n].valeur:SetText(tostring(c[2]))
	end

	poserBadge(rang)

	majJauge(rang.progres)

	-- LA PROGRESSION S'ECRIT EN CHIFFRES, PAS EN POURCENTAGE.
	--
	-- C'est ce que fait CurrentRankProgressField chez camelot :
	--   string.format(PVP_RANK_CURRENT_PROGRESS, rankPoints,
	--                 nextRankPointsThreshold)
	-- Cette chaine n'existe pas en 3.3.5 -- ce client n'a plus le systeme de
	-- rangs -- d'ou le "%d / %d" nu. Les deux nombres sont les VICTOIRES
	-- HONORABLES de toute une vie et le seuil du palier suivant : ce sont
	-- eux que mod-pvp-titles compare, et eux qui font avancer la jauge.
	--
	-- AU RANG MAXIMAL il n'y a plus de seuil : le compte reste seul.
	if rang.seuil then
		bloc.progres:SetText(string.format("%d / %d", rang.victoires or 0,
			rang.seuil))
	elseif rang.numero and rang.numero > 0 then
		bloc.progres:SetText(tostring(rang.victoires or 0))
	else
		bloc.progres:SetText("")
	end

	-- SANS RANG, PAS D'ANNEAU. Un cercle dore vide se lit comme un defaut ;
	-- le cadran garde sa lueur, son fond de faction et l'embleme.
	if rang.numero and rang.numero > 0 then
		bloc.numero:SetText(tostring(rang.numero))
		bloc.recompense:Show()
		bloc.numero:Show()
	else
		bloc.numero:SetText("")
		bloc.recompense:Hide()
		bloc.numero:Hide()
	end

	-- LES EQUIPES D'ARENE, sous le rang (PvPArena.lua).
	if ForeverUI.PvPArena then
		ForeverUI.PvPArena.maj()
	end
end
ForeverUI.PvPUpdate = majBloc

-- ---------------------------------------------------------- la construction

-- L'ECRAN DU CLIENT SE TAIT EN ENTIER, a chaque passage : PVPParentFrame
-- porte ses onglets, ses cadres d'equipe d'arene, son bandeau de hors-saison
-- et tout leur art. Regions ET cadres fils, comme pour les competences.
local function etoufferEcranDuClient()
	local cadre = _G["PVPParentFrame"]
	if not cadre then
		return
	end

	if cadre.SetBackdrop then
		cadre:SetBackdrop(nil)
	end
	for _, region in ipairs({ cadre:GetRegions() }) do
		if region.Hide then
			region:Hide()
		end
	end
	if cadre.GetChildren then
		for _, fils in ipairs({ cadre:GetChildren() }) do
			if fils ~= bloc and fils.Hide then
				fils:Hide()
			end
		end
	end
end

-- LA FENETRE PvP CESSE D'ETRE UN PANNEAU, ET PAS SEULEMENT UNE FENETRE.
--
-- Releve dans l'UIParent.lua du client, ligne 52 :
--   UIPanelWindows["PVPParentFrame"] = { area = "left", pushable = 0,
--                                        whileDead = 1 }
--
-- Elle est donc INSCRITE au systeme de panneaux. Tant qu'elle y est, le
-- systeme la replace des qu'il repasse -- UpdateUIPanelPositions rend ses
-- ancres a UIParent -- et elle redevient une dalle de 384 x 512 posee a
-- l'ecran. Son art etant eteint, cette dalle ne SE VOIT PAS ; mais elle
-- prend la souris, et tout ce qui passe dessous cesse de repondre au clic.
-- C'est ainsi que les onglets lateraux devenaient incliquables des qu'on
-- ouvrait le PvP.
--
-- La retirer de la table est le seul geste qui vaille : le cadre n'est plus
-- une fenetre, il est le contenu d'un volet.
local function detacherDuSystemeDePanneaux(cadre)
	if UIPanelWindows then
		UIPanelWindows["PVPParentFrame"] = nil
	end
	-- Ceinture et bretelles : si le systeme l'a deja prise en charge, elle
	-- garde une place jusqu'a ce qu'on l'en sorte.
	if HideUIPanel and cadre.IsShown and cadre:IsShown() then
		HideUIPanel(cadre)
	end
end

-- BORNER LA FENETRE AU VOLET. Refait a chaque passage, et non une seule fois
-- a la construction : le jour ou un autre systeme lui rendrait ses ancres,
-- le passage suivant les reprend.
bornerAuVolet = function()
	local cadre = _G["PVPParentFrame"]
	local hote = hoteGauche
	if not cadre or not hote then
		return
	end
	if cadre:GetParent() ~= hote then
		cadre:SetParent(hote)
	end
	if cadre.SetToplevel then
		cadre:SetToplevel(false)
	end
	cadre:ClearAllPoints()
	cadre:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, 0)
	cadre:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", 0, 0)
end
ForeverUI.PvPBound = bornerAuVolet

local function monter(hote)
	local cadre = _G["PVPParentFrame"]
	if not cadre or not hote then
		return nil, {}
	end

	hoteGauche = hote
	detacherDuSystemeDePanneaux(cadre)
	bornerAuVolet()

	if bloc then
		etoufferEcranDuClient()
		majBloc()
		return nil, { cadre }
	end

	local largeur = hote:GetWidth() or 0
	if largeur < 100 then
		largeur = VOLET_L
	end

	-- LE BLOC PRINCIPAL. Ses deux ancrages donnent une bande de 135 de haut,
	-- du -60 au -195 sous le haut du volet.
	bloc = CreateFrame("Frame", "ForeverUIPvPMain", cadre)
	bloc:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, BLOC_Y)
	bloc:SetPoint("BOTTOMRIGHT", hote, "TOPRIGHT", 0, BLOC_Y2)

	-- Le compte a rebours de fin de saison : la ligne existe, vide.
	bloc.minuterie = cadre:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	bloc.minuterie:SetJustifyH("RIGHT")
	bloc.minuterie:SetPoint("TOPRIGHT", hote, "TOPRIGHT", SAISON_X, SAISON_Y)

	-- ECART ASSUME : GameFontNormalMed2 n'existe pas en 3.3.5.
	bloc.saison = bloc:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	bloc.saison:SetJustifyH("CENTER")
	bloc.saison:SetPoint("TOP", bloc, "TOP", 0, SAISON_TITRE_Y)

	bloc.rang = bloc:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	bloc.rang:SetJustifyH("CENTER")
	bloc.rang:SetPoint("TOP", bloc, "TOP", 0, RANG_HAUT)

	bloc.ligne = bloc:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(bloc.ligne, ATLAS_LIGNE)
	bloc.ligne:SetPoint("BOTTOM", bloc.rang, "BOTTOM", 0, LIGNE_Y)

	bloc.progres = bloc:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	bloc.progres:SetJustifyH("CENTER")
	bloc.progres:SetHeight(PROGRES_H)

	-- LE CADRAN : sa lueur, son fond de faction, son anneau, la jauge et le
	-- badge, dans cet ordre -- c'est lui qui decide ce qui passe devant.
	local cadran = CreateFrame("Frame", "ForeverUIPvPDial", bloc)
	cadran:SetWidth(CADRAN)
	cadran:SetHeight(CADRAN)
	cadran:SetFrameLevel(bloc:GetFrameLevel() + 1)
	bloc.cadran = cadran

	-- L'HONNEUR, sur deux colonnes, dans un cadre AU-DESSUS du cadran : la
	-- lueur de celui-ci deborde vers le haut et voilerait le texte.
	local honneur = CreateFrame("Frame", "ForeverUIPvPHonor", bloc)
	honneur:SetWidth(HONNEUR_L)
	honneur:SetHeight(2 * HONNEUR_RANGEE_H + HONNEUR_ECART)
	honneur:SetPoint("TOP", bloc.ligne, "BOTTOM", 0, HONNEUR_SOUS_LIGNE)
	honneur:SetFrameLevel(bloc:GetFrameLevel() + 2)
	bloc.honneur = honneur
	honneur.cases = {}
	for n = 1, 4 do
		local colonne, rangee = (n - 1) % 2, math.floor((n - 1) / 2)
		local x = colonne * (HONNEUR_L - HONNEUR_COLONNE)
		local y = -rangee * (HONNEUR_RANGEE_H + HONNEUR_ECART)
		local intitule = honneur:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		intitule:SetJustifyH("LEFT")
		intitule:SetPoint("TOPLEFT", honneur, "TOPLEFT", x, y)
		local valeur = honneur:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		valeur:SetJustifyH("RIGHT")
		valeur:SetPoint("TOPRIGHT", honneur, "TOPLEFT", x + HONNEUR_COLONNE, y)
		honneur.cases[n] = { intitule = intitule, valeur = valeur }
	end

	local separateur = honneur:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(separateur, ATLAS_SEPARATEUR_LONG)
	separateur:SetPoint("TOP", honneur, "BOTTOM", 0, SEPARATEUR_HONNEUR_Y)
	bloc.separateurHonneur = separateur

	cadran:SetPoint("TOP", separateur, "BOTTOM", 0, CADRAN_SOUS_SEPARATEUR)
	bloc.progres:SetPoint("TOP", cadran, "BOTTOM", 0, PROGRES_SOUS_CADRAN)

	local lueur = cadran:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(lueur, ATLAS_LUEUR, true)
	lueur:SetWidth(LUEUR_L)
	lueur:SetHeight(LUEUR_H)
	lueur:SetPoint("CENTER", cadran, "CENTER", 0, 0)

	local fond = cadran:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, string.format(ATLAS_FOND, string.lower(faction())), true)
	fond:SetWidth(FOND_L)
	fond:SetHeight(FOND_H)
	fond:SetPoint("CENTER", cadran, "CENTER", 0, 0)
	bloc.fond = fond

	local anneau = cadran:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(anneau, ATLAS_ANNEAU, true)
	anneau:SetWidth(ANNEAU_L)
	anneau:SetHeight(ANNEAU_H)
	anneau:SetPoint("CENTER", cadran, "CENTER", 0, ANNEAU_Y)

	-- LA JAUGE, entre l'anneau et le badge : quatre quarts, poses ici pour
	-- passer devant l'anneau et derriere le badge.
	bloc.jauge = monterJauge(cadran)

	bloc.badge = cadran:CreateTexture(nil, "ARTWORK")
	bloc.badge:SetPoint("CENTER", cadran, "CENTER", 0, 0)

	-- L'anneau de recompense, en bas du cadran, avec le numero du rang.
	local recompense = cadran:CreateTexture(nil, "OVERLAY")
	ForeverUI.SetAtlas(recompense, ATLAS_ANNEAU_RECOMPENSE)
	recompense:SetPoint("BOTTOM", cadran, "BOTTOM", 0, RECOMPENSE_Y)
	bloc.recompense = recompense

	bloc.numero = cadran:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	bloc.numero:SetPoint("CENTER", recompense, "CENTER", 0, 0)
	bloc.numero:SetJustifyH("CENTER")

	-- LES EQUIPES D'ARENE ET LES POINTS D'ARENE, dans le bas du volet
	-- (PvPArena.lua, demande du 2026-09-25).
	if ForeverUI.PvPArena then
		ForeverUI.PvPArena.monter(bloc, hote)
	end

	etoufferEcranDuClient()
	majBloc()
	return nil, { cadre }
end

-- LE VOLET DROIT (demandes du 2026-09-26). Il portait le titre du rang, son
-- numero et l'honneur ; l'honneur est passe au volet gauche, le reste a ete
-- retire. Il porte desormais les champs de bataille (PvPBattlegrounds.lua).
local function monterDetail(hote)
	if detail then
		return detail, {}
	end
	detail = CreateFrame("Frame", "ForeverUIPvPDetail", hote)
	detail:SetAllPoints(hote)
	if ForeverUI.PvPBattlegrounds then
		ForeverUI.PvPBattlegrounds.monter(detail)
	end
	return detail, {}
end

ForeverUI.PvPTab = { Build = monter, BuildRight = monterDetail }

-- TEMOIN -- /fui pvp. Ce que les trois fonctions de rang rendent REELLEMENT
-- sur ce serveur : WotLK ne s'en sert plus, mais elles sont dans le binaire,
-- et c'est le serveur qui decide si elles portent une valeur.
function ForeverUI.PvPDebug(essai)
	local dire = function(texte)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. texte)
	end

	-- VALEUR D'ESSAI. /fui pvp 0.35 pose la jauge a 35 % le temps de la
	-- regarder ; le prochain evenement de rang la remet sur la vraie.
	if essai then
		majJauge(essai)
		dire(string.format("jauge posee a %.0f %% (valeur d'essai)",
			essai * 100))
	else
		-- Sans valeur, le temoin REMET la jauge sur la progression reelle :
		-- une valeur d'essai ne doit pas survivre au releve qui la suit.
		majJauge(lireRang().progres)
	end

	local indice = UnitPVPRank and UnitPVPRank("player")
	local nom, numero
	if indice and GetPVPRankInfo then
		nom, numero = GetPVPRankInfo(indice, "player")
	end
	dire(string.format("compteur de rang : UnitPVPRank=%s -> nom=%s numero=%s"
		.. " | GetPVPRankProgress=%s",
		tostring(indice), tostring(nom), tostring(numero),
		tostring(GetPVPRankProgress and GetPVPRankProgress())))

	-- LES TITRES, la ou le serveur ecrit vraiment le rang.
	local premier = TITRE_PREMIER[faction()] or TITRE_PREMIER.Alliance
	local connus = {}
	for numero2 = 1, RANGS do
		if titreConnu(premier + numero2 - 1) then
			connus[#connus + 1] = tostring(numero2)
		end
	end
	dire(string.format("titres de rang (%s, identifiants %d a %d) : %s",
		faction(), premier, premier + RANGS - 1,
		(#connus > 0) and table.concat(connus, " ") or "aucun"))

	local r = lireRang()
	dire(string.format("retenu : rang=%s nom=%s | victoires=%d seuil=%s"
		.. " -> progres=%.3f",
		tostring(r.numero), tostring(r.nom), r.victoires or 0,
		tostring(r.seuil), r.progres or 0))

	local h = lireHonneur()
	dire(string.format("honneur : courant=%d vie=%d meilleurRang=%d "
		.. "aujourd'hui=%d (%d) hier=%d (%d)",
		h.courant, h.vie, h.meilleurRang, h.jour, h.pointsJour, h.hier, h.pointsHier))
	dire(string.format("saison d'arene : %s | faction : %s",
		tostring(GetCurrentArenaSeason and GetCurrentArenaSeason()), faction()))

	-- CE QUE MONTRE LA JAUGE, quart par quart : "plein", "arc" ou "vide".
	if bloc and bloc.jauge then
		local etats = {}
		for i = 1, 4 do
			local q = bloc.jauge[i]
			local etat = "vide"
			if q.plein:IsShown() then
				etat = "plein"
			elseif q.arc:IsShown() then
				etat = "arc"
			end
			etats[i] = string.format("%d(%d)=%s", i, q.depart, etat)
		end
		dire("jauge : depart " .. tostring(JAUGE_DEPART) .. " sens "
			.. tostring(JAUGE_SENS) .. " | " .. table.concat(etats, " "))
	else
		dire("jauge : l'ecran n'est pas encore monte")
	end
end

-- Le client refait son ecran dans PVPFrame_Update : on passe apres.
if hooksecurefunc and type(_G["PVPFrame_Update"]) == "function" then
	hooksecurefunc("PVPFrame_Update", function()
		etoufferEcranDuClient()
		majBloc()
	end)
end

-- CE QUI FAIT BOUGER LE RANG, maintenant qu'il vient des titres et des
-- victoires. KNOWN_TITLES_UPDATE dit qu'un titre est tombe -- c'est lui qui
-- annonce un rang gagne ; PLAYER_PVP_KILLS_CHANGED fait avancer la jauge a
-- chaque victoire. Les quatre existent dans ce client, verifie dans Wow.exe.
local veilleur = CreateFrame("Frame")
veilleur:RegisterEvent("KNOWN_TITLES_UPDATE")
veilleur:RegisterEvent("PLAYER_PVP_KILLS_CHANGED")
veilleur:RegisterEvent("PLAYER_PVP_RANK_CHANGED")
veilleur:RegisterEvent("HONOR_CURRENCY_UPDATE")
veilleur:SetScript("OnEvent", function()
	if bloc then
		majBloc()
	end
end)
