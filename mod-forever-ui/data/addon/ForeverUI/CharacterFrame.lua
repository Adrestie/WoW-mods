-- ForeverUI : la feuille du personnage.
--
-- Reprise a zero le 2026-09-22, avec la capture de reference sous les yeux :
-- docs/reference/camelot_feuille_personnage.png (923 x 663, echelle 4/3 --
-- le cadre y mesure 837 x 647 pour 631 x 484 logiques).
--
-- CE JALON pose le cadre, ses deux volets, les emplacements d'equipement et
-- les onglets lateraux. Le contenu du volet droit -- les statistiques et
-- leurs categories -- vient ensuite.
--
-- RELEVE DES SOURCES. Seuls camelot/ et shared/ font foi ; les trois
-- fichiers de la feuille existent en camelot/, il n'y a rien a trancher.
--
-- camelot/CharacterFrameConstants.lua
--   CHARACTER_FRAME_WIDTH 631, CHARACTER_FRAME_HEIGHT 484, replie 398.
--
-- camelot/CharacterFrame.xml
--   CharacterFrame herite de PortraitFrameBaseTemplate, dont le layoutType
--   est "PortraitFrameTemplate" : la meme mise en page que les sacs, au
--   coin haut gauche pres -- UI-Frame-PortraitMetal-CornerTopLeft, un
--   anneau plus large pour un portrait de 62. Son NineSlice et son
--   PortraitContainer (frameLevel 400) sont des CADRES FILS.
--   LeftPaneHost   398 de large, TOPLEFT (0, -20) et BOTTOMLEFT du cadre ;
--                  fond UI-Character-Info-General-BG (398 x 464).
--   RightPaneHost  233, accroche au TOPRIGHT du volet gauche ; fond
--                  UI-Character-Info-Stat-BG SANS ancrage -- donc il
--                  remplit -- et UI-Character-Info-Stat-StoneBG (233 x 85)
--                  en ARTWORK au TOPLEFT ; un common-framedivider de 11
--                  pose a -6, tendu sur la hauteur.
--   ModeTabs       64 x 384, TOPLEFT sur le TOPRIGHT du cadre, y = -30.
--
-- camelot/CharacterFrame.lua
--   CHARACTER_FRAME_TAB : Character 1, Reputation 2, Skills 3, PVP 4,
--   Currency 5, Statistics 6. L'onglet du personnage porte le PORTRAIT du
--   joueur, rogne a 0,03125 (UpdateCharacterModeTabPortrait).
--
-- SidePanelTabButtonMixin (blizzard_sharedxml)
--   la taille d'un onglet vient de son art : common-sidetab, 55 x 60 dans
--   la variante camelot, moins 5 de hauteur transparente -> 55 x 55.
--   L'icone est centree a (-3, 0).
--
-- camelot/PaperDollFrame.xml et .lua
--   emplacement 40 x 40, cadre UI-Character-Info-GearSlot a sa taille ;
--   colonne gauche TOPLEFT (24, -60), colonne droite TOPRIGHT (-20, -60),
--   ecart 6 ; l'arme principale au BOTTOM (-60, 30) du volet gauche quand
--   l'emplacement de distance est montre, puis secondaire et distance a
--   +6 ; distance et munitions en 27 avec -GearSlotSmall, munitions a +19
--   de la distance ; la scene du modele occupe tout le volet gauche.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   3.3.5 montre toujours un emplacement de distance -- arc, arme de jet ou
--   relique selon la classe : seule la variante a -60 sert.
--   Les icones d'onglet INV_SideTab_*_c60 que la source demande N'EXISTENT
--   PAS dans l'export du client : seul l'art commun des onglets y est. Les
--   onglets gardent donc le texte du client, sauf celui du personnage qui
--   porte son portrait comme dans la source.
--   Les emplacements, les onglets et le modele sont des cadres du client :
--   ils sont redimensionnes et reposes, jamais recrees, et jamais en
--   combat.

local LARGEUR, HAUTEUR = 631, 484
local VOLET_GAUCHE, VOLET_DROIT = 398, 233
local COMBLE = 20                       -- les volets commencent sous le titre
local NIVEAU_ART = 5                    -- l'art passe au-dessus des volets

-- L'ENCADREMENT DE METAL, ET CE QUI MANQUAIT.
--
-- RELEVE -- NineSliceLayouts.PortraitFrameTemplate donne les memes
-- decalages que HeldBagLayout : haut gauche (-13, 16), haut droit (4, 16),
-- bas gauche (-13, -3), bas droit (4, -3). Seul l'atlas du coin haut gauche
-- differe. Mais la source NE S'ARRETE PAS LA : camelot repasse ensuite sur
-- TOUTES les mises en page (camelot/NineSliceLayoutOverrides.lua), parce que
-- "l'art fait pour Camelot ne fait pas la taille exacte de l'art standard et
-- doit etre decale autrement" -- ce sont ses mots.
--
--   coin haut droit (UI-Frame-Metal-CornerTopRight)      x += -2   ->  2
--   coin bas gauche (UI-Frame-Metal-CornerBottomLeft)    y  = -8
--   coin bas droit  (UI-Frame-Metal-CornerBottomRight)   x += -2, y = -8
--
-- Nous prenions les valeurs NON corrigees : les deux coins du bas etaient
-- 5 px trop haut, d'ou un encadrement qui n'allait pas jusqu'en bas de la
-- fenetre, et les coins de droite 2 px trop a droite.
--
-- ET CE QUI MANQUAIT ENCORE : ces decalages, corriges ou non, posent le
-- CONTOUR EXTERIEUR de l'image. Le filet interieur du metal tombe alors a
-- 6 px DANS la fenetre, et ces 6 px de fond restent visibles sous lui --
-- c'est ce qui se lit comme un encadrement qui n'atteint pas le bas.
--
-- MESURE SUR L'ART, et non sur une capture : une capture a sa propre
-- echelle, l'atlas non. uiframemetal2xc60 est en double densite, donc les
-- mesures sont divisees par deux. Distance du filet interieur au bord de
-- l'image, en pixels d'affichage :
--
--   bande gauche   18,5   (coin portrait et coin bas gauche, identiques)
--   bande droite    8,5
--   bande basse    14
--   bande haute    41,5   -- c'est la barre de titre, interieure par
--                            conception : le haut ne se recalcule pas.
--
-- Le decalage vaut donc cette distance : l'image deborde d'autant, et son
-- filet tombe pile sur le bord de la fenetre.
--
-- PANNEAU_MONTEE est en plus, et n'est PAS de la source : 1 px de montee de
-- tout l'encadrement, juge a l'ecran, a la demande.
local PANNEAU_MONTEE = 1
local PANNEAU_COINS = {
	coinHautGauche = { x = -18.5, y = 16 + PANNEAU_MONTEE },
	coinHautDroit = { x = 8.5, y = 16 + PANNEAU_MONTEE },
	coinBasGauche = { x = -18.5, y = -14 + PANNEAU_MONTEE },
	coinBasDroit = { x = 8.5, y = -14 + PANNEAU_MONTEE },
}

local EMPLACEMENT = 40

-- L'ECART entre deux emplacements. La source n'en donne qu'un, 6, pour les
-- deux sens. ECART ASSUME, sur demande : les colonnes sont resserrees de 2
-- px, la rangee des armes garde le 6 de la source.
local ECART = 6
local ECART_VERTICAL = ECART - 2
local GAUCHE_X, GAUCHE_Y = 24, -60
local DROITE_X, DROITE_Y = -20, -60
local ARME_X, ARME_Y = -60, 30
local PETIT = 27                        -- ne sert plus qu'aux munitions
local MUNITIONS_ECART = 19

-- ECART ASSUME, sur demande. camelot pose l'emplacement de distance en 27
-- avec UI-Character-Info-GearSlotSmall, comme les munitions. Il porte
-- pourtant, selon la classe, une arme a distance OU une relique -- des
-- objets de meme rang que les deux armes de melee. Les quatre emplacements
-- de la rangee prennent donc la meme taille que les autres.

-- LES DEUX ONGLETS DU VOLET DROIT.
--
-- RELEVE -- camelot/PaperDollFrame.xml. PaperDollSidebarTabs est un cadre de
-- 233 x 85 ancre au TOP du volet droit, y = -4 ; il tient des CheckButton de
-- 42 x 42 -- PaperDollSidebarTabTemplate -- dont le premier est au TOP
-- (0, -5) et les autres colles a sa gauche et a sa droite. Chacun porte une
-- Icon de 42 en BACKGROUND, le cadre UI-Character-Info-StatTab en BORDER a
-- sa taille d'atlas, et UI-Character-Info-StatTab-Selected quand il est
-- choisi.
--
-- RELEVE -- mainline/PaperDollFrameConstants.lua, la table que camelot
-- charge (PAPERDOLL_SIDEBARS) :
--   STATS             icon = nil, "Uses the character portrait", rogne a
--                     0,109375 / 0,890625 / 0,09375 / 0,90625
--   EQUIPMENTMANAGER  Interface\PaperDollInfoFrame\PaperDollSidebarTabs
--                     rogne a 0,015625 / 0,53125 / 0,46875 / 0,60546875
--   PET / TITLES      les autres onglets, hors sujet ici
--
-- CE QUI DIFFERE, ET POURQUOI.
--   PaperDollSidebarTabs.blp N'EXISTE PAS dans ce client : l'onglet du
--   gestionnaire prend donc UI-GearManager-Button, qui y est, et qui est
--   justement l'icone de son bouton d'origine.
--   Les chaines PAPERDOLL_SIDEBAR_STATS et PAPERDOLL_EQUIPMENTMANAGER n'y
--   sont pas non plus. L'infobulle du premier onglet prend CHARACTER_INFO,
--   la plus proche que ce client porte ; le second a EQUIPMENT_MANAGER, qui
--   existe tel quel.
--   Le client n'a pas d'onglets lateraux : ces deux-la sont crees. Le
--   gestionnaire, lui, n'est pas recree -- l'onglet ouvre et ferme le
--   GearManagerDialog du client, exactement comme le bouton d'origine, qui
--   est masque.
local ONGLET_VOLET = 42
local ONGLET_VOLET_Y = -9               -- -4 du cadre des onglets, -5 du premier

-- L'ICONE TIENT DANS L'OUVERTURE DU CADRE, PAS DANS LE BOUTON.
--
-- camelot donne 42 a son Icon, soit tout le bouton. Ses icones a lui sont
-- des rognages de PaperDollSidebarTabs, qui portent leur propre marge
-- transparente ; un portrait, lui, remplit sa texture d'un bord a l'autre et
-- ressort donc des angles arrondis du cadre.
--
-- Mesure sur UI-Character-Info-StatTab : sur ses 42, la bande de metal
-- occupe 3..6 et 35..38, l'ouverture va donc de 7 a 34 -- 28 px, centres.
local ONGLET_ICONE = 28
local ATLAS_ONGLET_VOLET = "ui-character-info-stattab"
local ATLAS_ONGLET_VOLET_CHOISI = "ui-character-info-stattab-selected"
local ONGLET_PORTRAIT_COORD = { 0.109375, 0.890625, 0.09375, 0.90625 }
local ICONE_GESTIONNAIRE = "Interface\\PaperDollInfoFrame\\UI-GearManager-Button"

-- L'ART DU GESTIONNAIRE EST PLUS HAUT QUE LARGE. Le fichier fait 64 x 64,
-- mais son contenu opaque n'occupe que x 6..58 sur toute la hauteur : c'est
-- un bouton de 52 x 64, qui parait donc rectangulaire dans un onglet carre.
-- On en prend le carre central -- la meme plage sur les deux axes, 6..58,
-- soit 52 x 52 -- comme l'onglet des statistiques rogne son portrait.
local ICONE_GESTIONNAIRE_COORD = { 6 / 64, 58 / 64, 6 / 64, 58 / 64 }

local PIERRE_HAUTEUR = 85               -- UI-Character-Info-Stat-StoneBG
local SEPARATEUR = 11
local SEPARATEUR_EMBOUT = 4             -- mesure sur l'art : 11 x 50, deux embouts

local ONGLETS_L, ONGLETS_H = 64, 384    -- CharacterFrameModeTabs
local ONGLETS_Y = -30
local ONGLET_L, ONGLET_H = 55, 55       -- 55 x 60 moins 5 de transparent
local ONGLET_ICONE = 32
local ONGLET_ICONE_X = -3               -- GetIconAnchorOffsetsForTabArt
local PORTRAIT_ONGLET = 0.03125         -- UpdateCharacterModeTabPortrait

local PORTRAIT = 48                     -- voir le calcul plus bas

-- LE PORTRAIT SUIT SON ANNEAU. L'anneau est porte par le coin haut gauche
-- de l'encadrement : deplacer ce coin deplace le trou, et un portrait pose
-- en dur se retrouve a cote. Sa place se calcule donc DEPUIS le coin, et
-- non plus en absolu -- c'est ce qui l'avait desaxe quand l'encadrement est
-- passe au calcul sur le filet interieur.
--
-- Centre du trou dans l'image du coin, en pixels d'affichage : (38 ; -38,5)
-- du coin haut gauche de l'image. Mesure sur l'art -- l'anneau y occupe les
-- plages 13..39 et 113..138 de la feuille, en double densite, soit un trou
-- centre a 76 px de feuille = 38 affiches -- et c'est aussi ce que donnait
-- la place validee en jeu quand le coin etait a (-13, 16).
local PORTRAIT_TROU_X, PORTRAIT_TROU_Y = 38, -38.5
local PORTRAIT_X = PANNEAU_COINS.coinHautGauche.x + PORTRAIT_TROU_X
local PORTRAIT_Y = PANNEAU_COINS.coinHautGauche.y + PORTRAIT_TROU_Y

-- LE TITRE. TitledPanelMixin:SetTitleOffsets pose le conteneur du titre en
-- TOPLEFT (gauche, -1) et TOPRIGHT (droite, -1), avec son texte a TOP
-- (0, -5). ContainerFrame l'appelle avec 35 ; CharacterFrame ne l'appelle
-- PAS et garde donc les valeurs par defaut, 58 et -24. Le titre n'est donc
-- pas centre sur la fenetre mais entre le portrait et le bouton de
-- fermeture -- son milieu tombe a 332,5 sur 631, ce que la capture
-- confirme. CharacterFrameMixin:OnLoad ajoute SetTitleMaxLinesAndHeight(1,
-- 13) : une seule ligne.
local TITRE_GAUCHE, TITRE_DROITE = 58, -24
local TITRE_CONTENEUR, TITRE_TEXTE = -1, -5
local TITRE_BANDE = 20

-- ECART ASSUME, sur demande. characterFrameDisplayInfo fait suivre le
-- titre au sous-cadre affiche : le nom du joueur par defaut, puis
-- REPUTATION, CURRENCY, PVP, SKILLS ou STATISTICS selon le panneau, en
-- jaune. Ici la barre du haut porte TOUJOURS le nom du personnage et son
-- titre, quel que soit le panneau.

-- LE NIVEAU, LA RACE ET LA CLASSE, dans le volet DROIT.
--
-- RELEVE -- PaperDollLevelInfo : une bande de 220 x 20 posee au TOP
-- (0, -50) de PaperDollSidebarTabs, qui est elle-meme au TOP (0, -4) du
-- volet droit. La ligne tombe donc a -54 sous le haut du volet, centree.
-- C'est le "Druidesse de niveau 3" de la capture. 3.3.5 n'a qu'une ligne
-- pour les trois ; elle prend cette place.
local NIVEAU_Y = -54
local NIVEAU_LARGEUR, NIVEAU_HAUTEUR = 220, 20

-- LES FLECHES DU MODELE, centrees dans le volet gauche : leur milieu tombe
-- sur celui du volet, mesure a 276 sur la capture contre 275 pour le volet.
-- Leur hauteur est un REGLAGE, pas un releve -- la capture montre trois
-- boutons la ou 3.3.5 en a deux, et ils n'ont pas la meme taille.
local ROTATION_Y = -12
local ROTATION_ECART = 4

-- LE MODELE remonte d'autant dans son volet. Reglage lui aussi : la source
-- fait remplir tout le volet a sa scene, mais sa camera n'est pas celle de
-- 3.3.5, qui cadre le personnage plus bas.
local MODELE_Y = 24

-- L'ECHELLE DU MODELE. Camelot cadre son personnage par une scene
-- (CharacterModelScene) et la position de son acteur ; 3.3.5 n'a pas de
-- scene, et ce client n'a ni SetCamDistanceScale ni SetPortraitZoom --
-- verifie dans Wow.exe, seul SetModelScale y figure. C'est donc par lui
-- qu'on recule le personnage. Valeur choisie a l'oeil, a la demande.
-- CE QUE CE CLIENT PORTE, releve dans Wow.exe : SetModelScale et
-- GetModelScale, SetPosition et GetPosition, SetCamera, SetFacing. PAS de
-- SetCameraDistance, SetCameraPosition, SetCameraTarget, SetCustomCamera ni
-- SetPortraitZoom. Deux leviers, donc, et deux seulement :
--
--   ECHELLE   SetModelScale reduit le MODELE. La camera ne bouge pas, et le
--             modele se reduit autour de son origine -- il parait donc aussi
--             glisser vers le bas du cadre.
--   POSITION  SetPosition(profondeur, lateral, hauteur) deplace le modele
--             devant la camera. L'eloigner le rapetisse SANS changer son
--             cadrage : c'est le vrai recul.
--
-- Reglable en jeu par /fui modele, pour juger a l'oeil ; ce qui est ici est
-- ce qui s'applique au chargement.
-- VALEURS RETENUES, jugees a l'ecran. C'est la POSITION qui cadre : le
-- personnage recule de 6,5 devant la camera, ce qui le rapetisse sans
-- deplacer son cadrage. L'echelle reste celle du client -- nil veut dire
-- qu'on n'y touche pas, et non qu'on la remet a 1.
local MODELE_ECHELLE = nil
local MODELE_POSITION = { -6.5, 0, 0 }   -- profondeur, lateral, hauteur

-- LE PANNEAU DES RESISTANCES se decale vers la droite. On garde son
-- ancrage d'origine et on n'y ajoute que ce decalage, sinon chaque passage
-- le pousserait un peu plus loin.
local RESISTANCES_X = 30

-- LES STATISTIQUES.
--
-- D'OU VIENT LA SOURCE. Le client charge son PaperDollFrame depuis
-- patch-enUS-2 (le .xml) et patch-enUS-3 (le .lua) : c'est le FrameXML
-- d'origine. Le patch-enUS-9, lui, porte l'extension .disabled -- le jeu
-- ne l'ouvre pas, et ses noms (MostrarStatPaperDoll*DropDown,
-- PStatFrameTemplate) n'existent nulle part a l'ecran. Tout ce qui suit
-- est releve sur ce que le client charge VRAIMENT : l'addon ne depend
-- d'aucune archive ajoutee.
--
-- CE QUE LE CLIENT PORTE. CharacterAttributesFrame, 230 x 78, tient deux
-- groupes de six lignes poses COTE A COTE -- PlayerStatFrameLeft1..6 et
-- PlayerStatFrameRight1..6 -- chacun coiffe de son menu de categorie,
-- PlayerStatFrameLeftDropDown et PlayerStatFrameRightDropDown. Le modele
-- d'une ligne, StatFrameTemplate, fait 104 x 13 : un intitule a gauche,
-- sa valeur dans un cadre fils cale a droite. Les lignes s'enchainent
-- sans ecart, d'ou un pas de 13.
--
-- L'addon n'en recree aucun : le calcul des valeurs, les infobulles et le
-- menu des categories restent au client. Il les repose l'un SOUS l'autre
-- dans le volet droit -- une seule colonne, comme camelot -- et les
-- elargit : le volet fait 233 et le modele 104, et une ligne dont la
-- valeur est calee a droite gagne a occuper toute la largeur.
local STAT_PAS = 13                     -- la hauteur de StatFrameTemplate
local STAT_MARGE = 20                   -- de chaque cote du volet
local STAT_HAUT = 10                    -- sous la bande de pierre
local STAT_ENTRE_GROUPES = 16
local STAT_PAR_GROUPE = 6

-- LES SELECTEURS DE CATEGORIE. Ce sont des UIDropDownMenuTemplate : un
-- cadre de 40 x 32 dont l'art -- $parentLeft 25, $parentMiddle 115,
-- $parentRight 25, sur 64 de haut -- DEBORDE tres largement et ne suit pas
-- la taille du cadre. Il s'efface, et l'en-tete moderne prend sa place ;
-- le clic, lui, reste celui du client ($parentButton ouvre le menu des
-- cinq PLAYERSTAT_DROPDOWN_OPTIONS).
--
-- RELEVE -- CharacterStatFrameCategoryTemplate de camelot : 197 x 40, fond
-- UI-Character-Info-Title tendu du TOPLEFT au BOTTOMRIGHT, intitule
-- GameFontHighlight centre a (0, 1). Ses lignes font 187 : l'en-tete
-- deborde donc de 5 de chaque cote.
--
-- L'intitule ne se lit pas sur le bouton : la categorie choisie vit dans
-- une CVar qui porte une CLE, et le texte est la globale du meme nom. Le
-- client rappelle UpdatePaperdollStats(prefixe, cle) a chaque changement.
-- ECART ASSUME, sur demande : 34 et non 40. C'est la hauteur PROPRE de
-- l'art de bouton (common-button-tertiary-normal, 46 x 34) : a cette taille
-- la bande centrale du decoupage ne s'etire plus du tout en hauteur.
local STAT_ENTETE = 34
local STAT_ENTETE_DEBORD = 5
-- LE SELECTEUR EST UN BOUTON, PAS UN EN-TETE.
--
-- Il portait UI-Character-Info-Title, l'en-tete de categorie de camelot. A
-- la demande il prend l'art de bouton commonbuttontertiaryc60, avec ses
-- deux etats : common-button-tertiary-normal et ...-pressed, 46 x 34
-- chacun. L'etat presse tient tant que sa liste est ouverte, ce qui donne
-- au bouton la meme lecture qu'un onglet enfonce.
--
-- DECOUPE, ET NON ETIREE. Mesure sur l'art : a partir de x = 11 le profil
-- d'une colonne ne change plus -- l'about arrondi fait donc 11 px, et le
-- coin vaut 11 sur les deux axes (11 + 24 + 11 en largeur, 11 + 12 + 11 en
-- hauteur). Tendue de 46 a 203, l'image ecraserait ses angles.
--
-- LA FLECHE S'EN VA. Le bouton du client ($parentButton) n'a plus lieu
-- d'etre : toute la barre ouvre deja le menu.
local ATLAS_BOUTON = "common-button-tertiary-normal"
local ATLAS_BOUTON_PRESSE = "common-button-tertiary-pressed"
local BOUTON_COIN = 11
local BOUTON_MARGES = { 0, 0, 0, 0 }
local SELECTEUR_PIECES = { "Left", "Middle", "Right", "Text" }
local STAT_GROUPES = {
	{
		selecteur = "PlayerStatFrameLeftDropDown",
		prefixe = "PlayerStatFrameLeft",
		cvar = "playerStatLeftDropdown",
	},
	{
		selecteur = "PlayerStatFrameRightDropDown",
		prefixe = "PlayerStatFrameRight",
		cvar = "playerStatRightDropdown",
	},
}

local FERMETURE = 24
local FERMETURE_X, FERMETURE_Y = 1, 0
local FERMETURE_ATLAS = {
	{ atlas = "redbutton-exit", methode = "GetNormalTexture" },
	{ atlas = "redbutton-exit-pressed", methode = "GetPushedTexture" },
	{ atlas = "redbutton-exit-disabled", methode = "GetDisabledTexture" },
	{ atlas = "redbutton-highlight", methode = "GetHighlightTexture" },
}

local COIN_PORTRAIT = "ui-frame-portraitmetal-cornertopleft"

local ATLAS = {
	fondGauche = "ui-character-info-general-bg",
	fondDroit = "ui-character-info-stat-bg",
	pierre = "ui-character-info-stat-stonebg",
	separateur = "common-framedivider",
	emplacement = "ui-character-info-gearslot",
	petitEmplacement = "ui-character-info-gearslotsmall",
	onglet = "common-sidetab",
	ongletSurvol = "common-sidetab-hover",
	ongletChoisi = "common-sidetab-selected",
}

local COLONNE_GAUCHE = {
	"Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
}
local COLONNE_DROITE = {
	"Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
}
local RANGEE_ARMES = { "MainHand", "SecondaryHand", "Ranged" }

-- ECART ASSUME, sur demande : la rangee du bas se resserre vers la gauche.
-- Les valeurs sont RELATIVES au voisin de gauche, et s'additionnent le long
-- de la chaine -- decaler la main gauche de 2 emporte la distance avec elle.
-- Sur l'ecran : main droite 0, main gauche -2, distance -4, et les munitions
-- -4 puisqu'elles s'accrochent a la distance.
--
-- La fleche des munitions n'a pas de reglage : c'est une region de
-- l'emplacement lui-meme -- une texture OVERLAY de 23 x 41 centree a
-- (-22, 0) sur CharacterAmmoSlot -- donc elle le suit.
local RANGEE_DECALAGE = { 0, -2, -2 }

-- L'art d'epoque ne tient pas qu'au cadre : 3.3.5 le repartit sur ses
-- sous-cadres, qui sont des cadres fils et echappent a un balayage du seul
-- CharacterFrame.
local ANCIENS_CADRES = {
	"CharacterFrame", "PaperDollFrame", "PetPaperDollFrame", "SkillFrame",
	"ReputationFrame", "HonorFrame", "TokenFrame", "PaperDollItemsFrame",
	"CharacterAttributesFrame", "CharacterAttributesFrameer",
	"CharacterResistanceFrame",
}

-- LA FENETRE SE DEPLACE PAR SA BARRE DU HAUT. Le cadre du client est
-- range par le systeme de panneaux : il le repose a chaque ouverture. On
-- retient donc la place choisie et on la repose apres lui, a chaque
-- passage de l'habillage -- qui tourne justement a l'ouverture.
local function placeRetenue()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.positions = ForeverUIDB.positions or {}
	return ForeverUIDB.positions
end

local voletGauche, voletDroit, barreOnglets
local onglets = {}

local function balayerTextures(cadre)
	if not cadre or not cadre.GetRegions then
		return
	end

	local regions = { cadre:GetRegions() }
	for _, region in ipairs(regions) do
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
end

local function effacerArtDepoque()
	for _, nom in ipairs(ANCIENS_CADRES) do
		balayerTextures(_G[nom])
	end
end

local function monterVolets(cadre)
	if voletGauche then
		return
	end

	voletGauche = CreateFrame("Frame", "ForeverUICharacterLeftPane", cadre)
	voletGauche:SetWidth(VOLET_GAUCHE)
	voletGauche:SetPoint("TOPLEFT", cadre, "TOPLEFT", 0, -COMBLE)
	voletGauche:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT", 0, 0)

	local fondGauche = voletGauche:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fondGauche, ATLAS.fondGauche)
	fondGauche:SetPoint("TOPLEFT", voletGauche, "TOPLEFT", 0, 0)

	voletDroit = CreateFrame("Frame", "ForeverUICharacterRightPane", cadre)
	voletDroit:SetWidth(VOLET_DROIT)
	voletDroit:SetPoint("TOPLEFT", voletGauche, "TOPRIGHT", 0, 0)
	voletDroit:SetPoint("BOTTOMLEFT", voletGauche, "BOTTOMRIGHT", 0, 0)

	-- La source declare ce fond sans ancrage : il remplit son volet. A sa
	-- taille d'atlas (233 x 383) il laisserait 81 px nus en bas.
	local fondDroit = voletDroit:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fondDroit, ATLAS.fondDroit, true)
	fondDroit:SetAllPoints(voletDroit)

	local pierre = voletDroit:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(pierre, ATLAS.pierre)
	pierre:SetPoint("TOPLEFT", voletDroit, "TOPLEFT", 0, 0)
	voletDroit.pierre = pierre

	-- Le separateur porte un embout a chaque bout : tendu tel quel sur la
	-- hauteur du volet, ils s'etalent. Trois tranches.
	-- Il passe DEVANT l'encadrement de la fenetre. L'habillage vit dans un
	-- cadre fils a NIVEAU_ART ; le separateur, pose au niveau du volet,
	-- passait dessous et disparaissait sous le metal. Il prend donc un cran
	-- de plus que l'habillage -- qui n'existe pas encore quand les volets se
	-- montent, d'ou le calcul depuis la constante et non depuis le cadre.
	local separateur = ForeverUI.CreateVerticalDivider(voletDroit, ATLAS.separateur,
		SEPARATEUR_EMBOUT, cadre:GetFrameLevel() + NIVEAU_ART + 1)
	separateur:SetWidth(SEPARATEUR)
	separateur:SetPoint("TOPLEFT", voletDroit, "TOPLEFT", -6, -1)
	separateur:SetPoint("BOTTOMLEFT", voletDroit, "BOTTOMLEFT", -6, 0)
	voletDroit.separateur = separateur

	ForeverUI.CharacterPanes = { gauche = voletGauche, droit = voletDroit }
end

-- LE PORTRAIT. La source le pose en 62 dans PortraitContainer et l'arrondit
-- par un masque ; ici c'est le trou de l'anneau qui decoupe, comme sur les
-- sacs.
--
-- PROFIL DE L'ANNEAU, mesure sur l'art a la taille ou il est dessine --
-- rayon en pixels d'affichage, contre l'opacite :
--
--   0 a 12    transparent, c'est le trou
--   13 a 25   degrade
--   26 a 29   opaque
--   30 a 32   retombee, rien au-dela
--
-- Un carre de cote C touche le rayon C/2 sur ses axes et C/2 x racine(2)
-- dans ses angles. Aucune taille ne couvre le degrade tout en cachant ses
-- angles : il faudrait C >= 52 pour les uns et C <= 41 pour les autres.
--
-- C = 48, A LA DEMANDE : sur les axes il atteint 24, la ou le metal est
-- deja opaque a 86 % -- c'etait les "2 px de chaque cote" qui manquaient
-- avec 44, qui s'arretait a 22, dans le degrade a moitie transparent. En
-- contrepartie ses angles tombent a 33,9, au-dela de l'anneau : si leurs
-- pointes se voient, 46 est le compromis (axes a 23, angles a 32,5, dans
-- la retombee).
local function poserPortrait(cadre)
	local hote = cadre.foreverHabillage or cadre
	if not cadre.foreverPortrait then
		local portrait = hote:CreateTexture(nil, "BACKGROUND")
		portrait:SetWidth(PORTRAIT)
		portrait:SetHeight(PORTRAIT)
		portrait:SetPoint("CENTER", hote, "TOPLEFT", PORTRAIT_X, PORTRAIT_Y)
		cadre.foreverPortrait = portrait
	end

	if SetPortraitTexture then
		SetPortraitTexture(cadre.foreverPortrait, "player")
	end
end

-- LE TITRE, dans un cadre fils. La source range le sien dans
-- TitleContainer, a frameLevel 510 : au-dessus du NineSlice, qui est a 400.
-- Il le faut, le metal etant en OVERLAY sur son propre cadre.
local function poserTitre(cadre)
	if not cadre.foreverBandeTitre then
		local ancien = _G["CharacterNameText"]
		if ancien then
			ancien:Hide()
		end

		local bande = CreateFrame("Frame", "ForeverUICharacterTitle", cadre)
		bande:SetFrameLevel(cadre:GetFrameLevel() + NIVEAU_ART + 2)
		bande:SetHeight(TITRE_BANDE)
		bande:SetPoint("TOPLEFT", cadre, "TOPLEFT", TITRE_GAUCHE, TITRE_CONTENEUR)
		bande:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", TITRE_DROITE, TITRE_CONTENEUR)

		local texte = bande:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		texte:SetPoint("TOP", bande, "TOP", 0, TITRE_TEXTE)
		texte:SetPoint("LEFT", bande, "LEFT")
		texte:SetPoint("RIGHT", bande, "RIGHT")
		texte:SetJustifyH("CENTER")
		cadre.foreverBandeTitre = bande
		cadre.foreverTitre = texte

		-- La barre du haut sert de poignee : clic maintenu, la fenetre suit.
		cadre:SetMovable(true)
		cadre:SetClampedToScreen(true)
		bande:EnableMouse(true)
		bande:RegisterForDrag("LeftButton")
		bande:SetScript("OnDragStart", function()
			if not InCombatLockdown() then
				cadre:StartMoving()
			end
		end)
		bande:SetScript("OnDragStop", function()
			cadre:StopMovingOrSizing()
			local point, _, pointRelatif, x, y = cadre:GetPoint(1)
			if point then
				placeRetenue()["feuille"] = {
					point = point, relativePoint = pointRelatif, x = x, y = y,
				}
			end
		end)
	end

	-- UnitPVPName rend le nom ACCOMPAGNE de son titre quand le joueur en
	-- porte un ; sans titre, c'est le nom seul.
	local texte = cadre.foreverTitre
	local nom = (UnitPVPName and UnitPVPName("player")) or UnitName("player")
	-- (le deplacement est monte plus bas, une seule fois)
	texte:SetText(nom or "")
	if HIGHLIGHT_FONT_COLOR then
		texte:SetTextColor(HIGHLIGHT_FONT_COLOR.r, HIGHLIGHT_FONT_COLOR.g,
			HIGHLIGHT_FONT_COLOR.b)
	end
end

-- Le bouton de fermeture : celui du client, rhabille du X rouge des
-- panneaux modernes et remis au coin haut droit.
local function poserFermeture(cadre)
	local fermer = _G["CharacterFrameCloseButton"]
	if not fermer then
		return
	end

	fermer:SetWidth(FERMETURE)
	fermer:SetHeight(FERMETURE)
	fermer:ClearAllPoints()
	fermer:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", FERMETURE_X, FERMETURE_Y)
	fermer:SetFrameLevel(cadre:GetFrameLevel() + NIVEAU_ART + 2)

	if cadre.foreverFermetureHabillee then
		return
	end

	for _, entree in ipairs(FERMETURE_ATLAS) do
		local texture = fermer[entree.methode] and fermer[entree.methode](fermer)
		if texture then
			ForeverUI.SetAtlas(texture, entree.atlas, true)
			texture:ClearAllPoints()
			texture:SetAllPoints(fermer)
			if entree.atlas == "redbutton-highlight" then
				texture:SetBlendMode("ADD")
			end
		end
	end
	cadre.foreverFermetureHabillee = true
end

local function habillerEmplacement(nom, cote, atlasCadre)
	local bouton = _G["Character" .. nom .. "Slot"]
	if not bouton then
		return nil
	end

	bouton:SetWidth(cote)
	bouton:SetHeight(cote)

	-- LE MODELE PREND LA SOURIS, ET IL COUVRE TOUT LE VOLET.
	--
	-- Chez le client, la scene du modele tient entre les deux colonnes
	-- d'emplacements (233 x 215) : rien ne se recouvre. Camelot lui donne
	-- tout le volet gauche et pose les emplacements PAR-DESSUS, ce qu'on a
	-- repris -- mais le modele, lui, est sensible a la souris, et il nait
	-- au meme niveau de cadre que les emplacements, tous enfants de
	-- PaperDollFrame.
	--
	-- MESURE EN JEU (/fui perso) : emplacement et modele tous deux a 28,
	-- et GetMouseFocus rend CharacterModelFrame. A NIVEAU EGAL, C'EST LE
	-- MODELE QUI RECOIT LE CLIC -- plus de deseequipement, plus
	-- d'infobulle. L'emplacement passe donc un cran au-dessus.
	--
	-- Le test est un "au moins" : chaque passage de l'habillage le rejoue,
	-- et une augmentation seche ferait monter le niveau sans fin.
	local modele = _G["CharacterModelFrame"]
	if modele and modele.GetFrameLevel
		and bouton:GetFrameLevel() <= modele:GetFrameLevel() then
		bouton:SetFrameLevel(modele:GetFrameLevel() + 1)
	end

	if not bouton.foreverCadre then
		local normale = bouton:GetNormalTexture()
		if normale then
			normale:SetAlpha(0)
		end

		local cadre = bouton:CreateTexture(nil, "BACKGROUND")
		ForeverUI.SetAtlas(cadre, atlasCadre)
		cadre:SetPoint("CENTER", bouton, "CENTER", 0, 0)
		bouton.foreverCadre = cadre
	end

	local icone = _G["Character" .. nom .. "SlotIconTexture"]
	if icone then
		icone:ClearAllPoints()
		icone:SetAllPoints(bouton)
		icone:SetTexCoord(0, 1, 0, 1)
	end

	return bouton
end

local function poserEmplacements()
	local precedent
	for index, nom in ipairs(COLONNE_GAUCHE) do
		local bouton = habillerEmplacement(nom, EMPLACEMENT, ATLAS.emplacement)
		if bouton then
			bouton:ClearAllPoints()
			if index == 1 then
				bouton:SetPoint("TOPLEFT", voletGauche, "TOPLEFT", GAUCHE_X, GAUCHE_Y)
			else
				bouton:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, -ECART_VERTICAL)
			end
			precedent = bouton
		end
	end

	precedent = nil
	for index, nom in ipairs(COLONNE_DROITE) do
		local bouton = habillerEmplacement(nom, EMPLACEMENT, ATLAS.emplacement)
		if bouton then
			bouton:ClearAllPoints()
			if index == 1 then
				bouton:SetPoint("TOPRIGHT", voletGauche, "TOPRIGHT", DROITE_X, DROITE_Y)
			else
				bouton:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, -ECART_VERTICAL)
			end
			precedent = bouton
		end
	end

	precedent = nil
	for index, nom in ipairs(RANGEE_ARMES) do
		local bouton = habillerEmplacement(nom, EMPLACEMENT, ATLAS.emplacement)
		if bouton then
			bouton:ClearAllPoints()
			if index == 1 then
				bouton:SetPoint("BOTTOM", voletGauche, "BOTTOM", ARME_X, ARME_Y)
			else
				bouton:SetPoint("TOPLEFT", precedent, "TOPRIGHT",
					ECART + (RANGEE_DECALAGE[index] or 0), 0)
			end
			precedent = bouton
		end
	end

	local munitions = habillerEmplacement("Ammo", PETIT, ATLAS.petitEmplacement)
	if munitions and precedent then
		munitions:ClearAllPoints()
		munitions:SetPoint("LEFT", precedent, "RIGHT", MUNITIONS_ECART, 0)
	end
end

ForeverUI.ModeleReglage = { echelle = MODELE_ECHELLE, position = MODELE_POSITION }

-- LE MODELE SE CHARGE APRES COUP, ET REPART A ZERO.
--
-- PaperDollFrame_OnShow appelle CharacterModelFrame:SetUnit("player"), qui
-- lance un chargement ASYNCHRONE. Notre reglage, pose juste apres, s'applique
-- a un modele qui n'est pas encore la : la fin du chargement remet la
-- transformation a zero et le personnage ressort du cadre. La meme commande
-- tapee a la main tient, elle, parce que le modele est deja charge -- c'est
-- exactement ce qu'on observait.
--
-- On repose donc le reglage pendant une seconde et demie apres chaque
-- passage, a chaque image. Sans condition : rien ne garantit que GetPosition
-- rende ce que le moteur dessine vraiment, donc on ne compare pas, on
-- repose. C'est le meme rattrapage que pour la hauteur des sacs.
local MODELE_RATTRAPAGE = 1.5

local rattrapageModele = CreateFrame("Frame", "ForeverUICharacterModelRecheck")
rattrapageModele:Hide()
rattrapageModele.reste = 0

local function appliquerReglageModele()
	local modele = _G["CharacterModelFrame"]
	if not modele then
		return
	end

	local reglage = ForeverUI.ModeleReglage
	if modele.SetModelScale and reglage.echelle then
		modele:SetModelScale(reglage.echelle)
	end
	if modele.SetPosition and reglage.position then
		modele:SetPosition(reglage.position[1], reglage.position[2], reglage.position[3])
	end
end

rattrapageModele:SetScript("OnUpdate", function(self, ecoule)
	appliquerReglageModele()
	self.reste = self.reste - (ecoule or 0)
	if self.reste <= 0 then
		self:Hide()
	end
end)

ForeverUI.ModeleRattrapage = rattrapageModele

local function poserModele()
	local modele = CharacterModelFrame
	if not modele then
		return
	end

	modele:ClearAllPoints()
	modele:SetPoint("TOPLEFT", voletGauche, "TOPLEFT", 0, MODELE_Y)
	modele:SetPoint("BOTTOMRIGHT", voletGauche, "BOTTOMRIGHT", 0, MODELE_Y)

	-- Tout de suite, puis a chaque image le temps que le modele finisse
	-- d'arriver.
	appliquerReglageModele()
	rattrapageModele.reste = MODELE_RATTRAPAGE
	rattrapageModele:Show()

	-- Les fleches de rotation : centrees sur le volet, cote a cote.
	local gauche = _G["CharacterModelFrameRotateLeftButton"]
	local droite = _G["CharacterModelFrameRotateRightButton"]
	if gauche and droite then
		local demi = gauche:GetWidth() / 2 + ROTATION_ECART / 2

		gauche:ClearAllPoints()
		gauche:SetPoint("TOP", voletGauche, "TOP", -demi, ROTATION_Y)
		gauche:SetFrameLevel(modele:GetFrameLevel() + 2)

		droite:ClearAllPoints()
		droite:SetPoint("TOP", voletGauche, "TOP", demi, ROTATION_Y)
		droite:SetFrameLevel(modele:GetFrameLevel() + 2)
	end
end

-- Le panneau des resistances, decale vers la droite. Son ancrage d'origine
-- est garde a part : on repart toujours de lui, jamais de la position
-- courante, qui derive a chaque passage.
local function poserResistances()
	local cadre = _G["CharacterResistanceFrame"]
	if not cadre or not cadre.GetPoint or cadre:GetNumPoints() == 0 then
		return
	end

	if not cadre.foreverAncrage then
		local point, cible, pointCible, x, y = cadre:GetPoint(1)
		cadre.foreverAncrage = { point, cible, pointCible, x or 0, y or 0 }
	end

	local a = cadre.foreverAncrage
	cadre:ClearAllPoints()
	cadre:SetPoint(a[1], a[2], a[3], a[4] + RESISTANCES_X, a[5])
end

-- Un selecteur prend le fond et l'intitule de l'en-tete moderne. Le menu
-- reste celui du client : c'est lui qui porte les categories et le calcul.
-- DECLAREE AVANT D'ETRE ECRITE. habillerSelecteur la greffe sur la liste,
-- et elle n'est ecrite que plus bas : sans cette ligne son nom s'y resout
-- en GLOBALE, donc nil, et HookScript refuse le greffon. Declaree ici, elle
-- devient une variable de portee que la fermeture voit se remplir.
local majEtatSelecteurs

local function habillerSelecteur(selecteur)
	if selecteur.foreverIntitule then
		return
	end

	local nom = selecteur:GetName()

	-- Le cadre dore du menu deroulant s'en va : il deborde du cadre et ne
	-- se redimensionne pas avec lui. Son texte part avec, l'en-tete porte
	-- le sien.
	for _, piece in ipairs(SELECTEUR_PIECES) do
		local region = nom and _G[nom .. piece]
		if region then
			region:Hide()
		end
	end

	selecteur.foreverFond = ForeverUI.CreateNineSlice(selecteur, ATLAS_BOUTON,
		BOUTON_COIN, BOUTON_MARGES, "BACKGROUND")
	selecteur.foreverPresse = ForeverUI.CreateNineSlice(selecteur,
		ATLAS_BOUTON_PRESSE, BOUTON_COIN, BOUTON_MARGES, "BACKGROUND")
	for _, tranche in ipairs(selecteur.foreverPresse or {}) do
		tranche:Hide()
	end

	local intitule = selecteur:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	intitule:SetPoint("CENTER", selecteur, "CENTER", 0, 1)
	selecteur.foreverIntitule = intitule

	-- LA LISTE TOMBE SOUS LE BOUTON, SANS DECALAGE.
	--
	-- Sans ancrage donne, ToggleDropDownMenu accroche la liste a
	-- "<nom>Left" -- la piece doree du menu deroulant, que nous avons
	-- justement masquee -- d'ou un decalage. UIDropDownMenu_SetAnchor est
	-- l'entree que le client prevoit pour cela : le TOPLEFT de la liste sur
	-- le BOTTOMLEFT du bouton, sans ecart.
	if UIDropDownMenu_SetAnchor then
		UIDropDownMenu_SetAnchor(selecteur, 0, 0, "TOPLEFT", selecteur, "BOTTOMLEFT")
	end

	-- La fleche du client s'efface : toute la barre ouvre le menu.
	local bouton = nom and _G[nom .. "Button"]
	if bouton then
		bouton:Hide()
	end

	if not ForeverUI.statListeGreffee then
		local liste = _G["DropDownList1"]
		if liste and liste.HookScript then
			liste:HookScript("OnShow", majEtatSelecteurs)
			liste:HookScript("OnHide", majEtatSelecteurs)
			ForeverUI.statListeGreffee = true
		end
	end

	selecteur:EnableMouse(true)
	selecteur:SetScript("OnMouseUp", function(self)
		ToggleDropDownMenu(nil, nil, self)
		if PlaySound then
			PlaySound("igMainMenuOptionCheckBoxOn")
		end
		majEtatSelecteurs()
	end)
end

-- L'ETAT PRESSE TIENT TANT QUE LA LISTE EST OUVERTE.
--
-- Elle se ferme de deux facons : par ToggleDropDownMenu, et par
-- CloseDropDownMenus quand on clique ailleurs -- celle-la ne passe pas par
-- la premiere. On se greffe donc sur le OnShow et le OnHide de la liste
-- elle-meme, qui couvrent les deux.
function majEtatSelecteurs()
	local liste = _G["DropDownList1"]
	for _, groupe in ipairs(STAT_GROUPES) do
		local selecteur = _G[groupe.selecteur]
		if selecteur and selecteur.foreverPresse then
			local ouvert = liste and liste:IsShown()
				and UIDROPDOWNMENU_OPEN_MENU == selecteur
			for _, tranche in ipairs(selecteur.foreverPresse) do
				if ouvert then tranche:Show() else tranche:Hide() end
			end
			for _, tranche in ipairs(selecteur.foreverFond or {}) do
				if ouvert then tranche:Hide() else tranche:Show() end
			end
		end
	end
end
ForeverUI.CharacterStatTabsState = majEtatSelecteurs

-- LE CLIENT RETAILLE LE SELECTEUR A CHAQUE OUVERTURE.
--
-- UIDropDownMenu_InitializeHelper finit par
--   frame:SetHeight(UIDROPDOWNMENU_BUTTON_HEIGHT * 2)
-- Cette constante, nous l'avons portee a 20 pour les lignes de menu de
-- camelot : le selecteur reprenait donc 40 des qu'on cliquait dessus. Elle
-- est appelee par securecall depuis UIDropDownMenu_Initialize, donc un
-- greffon sur celle-ci passe bien apres.
local function reposerTailleSelecteur(cadre)
	for _, groupe in ipairs(STAT_GROUPES) do
		local selecteur = _G[groupe.selecteur]
		if selecteur == cadre and selecteur.foreverTaille then
			selecteur:SetWidth(selecteur.foreverTaille[1])
			selecteur:SetHeight(selecteur.foreverTaille[2])
			return
		end
	end
end
ForeverUI.CharacterStatTabsSize = reposerTailleSelecteur

if hooksecurefunc and type(UIDropDownMenu_Initialize) == "function" then
	hooksecurefunc("UIDropDownMenu_Initialize", reposerTailleSelecteur)
end

-- L'intitule d'une categorie : la CVar porte une CLE (PLAYERSTAT_BASE_STATS),
-- le texte affichable est la globale du meme nom.
local function ecrireCategorie(selecteur, cle)
	if selecteur and selecteur.foreverIntitule then
		selecteur.foreverIntitule:SetText((cle and _G[cle]) or "")
	end
end

-- LES STATISTIQUES SE MONTRENT ET SE CACHENT, au gre des deux onglets.
--
-- Au retour on ne rallume pas les lignes une a une : on les montre puis on
-- laisse le client refaire son travail. UpdatePaperdollStats decide seul de
-- la sixieme ligne -- il la montre, et la cache pour les categories qui
-- n'ont que cinq statistiques -- et forcer la notre par-dessus ferait
-- apparaitre une ligne vide.
local function montrerStatistiques(afficher)
	if not voletDroit then
		return
	end

	voletDroit.statsMontrees = afficher and true or false

	for _, groupe in ipairs(STAT_GROUPES) do
		local selecteur = _G[groupe.selecteur]
		if selecteur then
			if afficher then selecteur:Show() else selecteur:Hide() end
		end
		for index = 1, STAT_PAR_GROUPE do
			local ligne = _G[groupe.prefixe .. index]
			if ligne then
				if afficher then ligne:Show() else ligne:Hide() end
			end
		end
	end

	if afficher and PaperDollFrame_UpdateStats then
		PaperDollFrame_UpdateStats()
	end
end
ForeverUI.CharacterShowStats = montrerStatistiques

-- Les statistiques, reposees dans le volet droit. Ce sont des cadres du
-- client : on les deplace et on les elargit, on ne les recree pas -- ce
-- sont eux qui portent les infobulles et les menus de categorie.
local function poserStatistiques()
	if not voletDroit then
		return
	end

	local largeur = VOLET_DROIT - 2 * STAT_MARGE
	local niveau = voletDroit:GetFrameLevel() + 3
	local y = -(PIERRE_HAUTEUR + STAT_HAUT)

	for _, groupe in ipairs(STAT_GROUPES) do
		local selecteur = _G[groupe.selecteur]
		if selecteur then
			habillerSelecteur(selecteur)
			ecrireCategorie(selecteur, GetCVar and GetCVar(groupe.cvar))

			-- La taille est retenue : le client la reprend a chaque
			-- ouverture du menu, et il faut pouvoir la reposer.
			selecteur.foreverTaille = { largeur + 2 * STAT_ENTETE_DEBORD, STAT_ENTETE }
			selecteur:SetFrameLevel(niveau)
			selecteur:SetWidth(selecteur.foreverTaille[1])
			selecteur:SetHeight(selecteur.foreverTaille[2])
			selecteur:ClearAllPoints()
			selecteur:SetPoint("TOPLEFT", voletDroit, "TOPLEFT",
				STAT_MARGE - STAT_ENTETE_DEBORD, y)
			-- Montre seulement si l'onglet des statistiques est celui
			-- qui est ouvert : chaque passage de l'habillage repasse ici.
			if voletDroit.statsMontrees == false then
				selecteur:Hide()
			else
				selecteur:Show()
			end
			y = y - STAT_ENTETE
		end

		for index = 1, STAT_PAR_GROUPE do
			local ligne = _G[groupe.prefixe .. index]
			if ligne then
				ligne:SetFrameLevel(niveau)
				ligne:SetWidth(largeur)
				ligne:ClearAllPoints()
				ligne:SetPoint("TOPLEFT", voletDroit, "TOPLEFT", STAT_MARGE, y)
				y = y - STAT_PAS
			end
		end

		y = y - STAT_ENTRE_GROUPES
	end
end

-- La ligne du niveau, de la race et de la classe.
--
-- PIEGE 3.3.5. Une region ne se REPARENTE pas : SetParent n'est pas dans la
-- table des methodes de FontString de ce client. Ancrer celle du client au
-- volet ne suffirait pas non plus -- elle appartient au cadre, donc elle se
-- dessinerait SOUS les volets, qui sont des cadres fils. On efface donc la
-- sienne et on pose la notre dans le volet, en recopiant son texte : c'est
-- le client qui le compose, nous ne faisons que l'afficher.
local function poserNiveau()
	local source = _G["CharacterLevelText"]

	if not voletDroit.ligneNiveau then
		local ligne = voletDroit:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		ligne:SetPoint("TOP", voletDroit, "TOP", 0, NIVEAU_Y)
		ligne:SetWidth(NIVEAU_LARGEUR)
		ligne:SetHeight(NIVEAU_HAUTEUR)
		ligne:SetJustifyH("CENTER")
		ligne:SetJustifyV("MIDDLE")
		voletDroit.ligneNiveau = ligne
	end

	if source then
		source:Hide()
	end

	-- SANS LA RACE, a la demande -- et c'est aussi ce que fait camelot :
	-- son PaperDollFrame_SetLevel emploie PLAYER_LEVEL_NO_SPEC, qui ne
	-- porte que le niveau et la classe. Cette chaine n'existe pas dans ce
	-- client, dont le PLAYER_LEVEL vaut "Level %s %s %s" -- niveau, RACE,
	-- classe. La ligne est donc recomposee a partir de deux chaines que le
	-- client porte, UNIT_LEVEL_TEMPLATE et le nom de classe, plutot que
	-- d'ecrire un format en dur qui ne tiendrait que dans une langue.
	local niveau = UnitLevel and UnitLevel("player")
	local classe = UnitClass and UnitClass("player")
	local texte = ""
	if niveau and classe then
		texte = string.format(UNIT_LEVEL_TEMPLATE or "Level %d", niveau) .. " " .. classe
	elseif source then
		texte = source:GetText() or ""
	end
	voletDroit.ligneNiveau:SetText(texte)
end

-- Un onglet du volet droit : le cadre de camelot, une icone dessous, et une
-- marque quand il est choisi. SetCheckedTexture ne prend qu'un CHEMIN dans
-- ce client, jamais un rectangle d'atlas : la marque est donc une texture a
-- nous, montree et cachee a la main.
local function creerOngletVolet(nom, infobulle, clic)
	local onglet = CreateFrame("Button", nom, voletDroit)
	onglet:SetWidth(ONGLET_VOLET)
	onglet:SetHeight(ONGLET_VOLET)
	onglet:SetFrameLevel(voletDroit:GetFrameLevel() + 3)

	local icone = onglet:CreateTexture(nil, "BACKGROUND")
	icone:SetWidth(ONGLET_ICONE)
	icone:SetHeight(ONGLET_ICONE)
	icone:SetPoint("CENTER", onglet, "CENTER", 0, 0)
	onglet.icone = icone

	local choisi = onglet:CreateTexture(nil, "BORDER")
	ForeverUI.SetAtlas(choisi, ATLAS_ONGLET_VOLET_CHOISI)
	choisi:SetPoint("CENTER", onglet, "CENTER", 0, 0)
	choisi:Hide()
	onglet.choisi = choisi

	local cadre = onglet:CreateTexture(nil, "ARTWORK")
	ForeverUI.SetAtlas(cadre, ATLAS_ONGLET_VOLET)
	cadre:SetPoint("CENTER", onglet, "CENTER", 0, 0)

	onglet:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(infobulle)
		GameTooltip:Show()
	end)
	onglet:SetScript("OnLeave", function() GameTooltip:Hide() end)
	if clic then
		onglet:SetScript("OnClick", clic)
	end

	return onglet
end

local function poserOngletsVolet()
	if not voletDroit then
		return
	end

	if not voletDroit.ongletStats then
		-- Les deux se comportent en onglets : celui qu'on ouvre ferme
		-- l'autre. Le gestionnaire reste celui du client, on ne fait que
		-- montrer et cacher son panneau.
		local function choisir(statistiques)
			if voletDroit.ongletStats then
				if statistiques then
					voletDroit.ongletStats.choisi:Show()
					voletDroit.ongletEquipement.choisi:Hide()
				else
					voletDroit.ongletStats.choisi:Hide()
					voletDroit.ongletEquipement.choisi:Show()
				end
			end
			montrerStatistiques(statistiques)
			if ForeverUI.EquipmentPane then
				ForeverUI.EquipmentPane.Apply()
			end
			if GearManagerDialog then
				if statistiques then
					GearManagerDialog:Hide()
				else
					GearManagerDialog:Show()
				end
			end
		end

		voletDroit.ongletStats = creerOngletVolet("ForeverUICharacterStatsTab",
			CHARACTER_INFO or "Character Info",
			function() choisir(true) end)
		voletDroit.ongletStats.choisi:Show()

		voletDroit.ongletEquipement = creerOngletVolet(
			"ForeverUICharacterGearTab", EQUIPMENT_MANAGER or "Equipment Manager",
			function() choisir(false) end)
		voletDroit.ongletEquipement.icone:SetTexture(ICONE_GESTIONNAIRE)
		voletDroit.ongletEquipement.icone:SetTexCoord(
			ICONE_GESTIONNAIRE_COORD[1], ICONE_GESTIONNAIRE_COORD[2],
			ICONE_GESTIONNAIRE_COORD[3], ICONE_GESTIONNAIRE_COORD[4])

		-- Les deux se touchent, comme chez camelot, et la paire est centree.
		voletDroit.ongletStats:SetPoint("TOP", voletDroit, "TOP",
			-ONGLET_VOLET / 2, ONGLET_VOLET_Y)
		voletDroit.ongletEquipement:SetPoint("LEFT", voletDroit.ongletStats,
			"RIGHT", 0, 0)
	end

	-- Le portrait, rogne comme la source le demande. A reposer : le client
	-- refait la texture a chaque changement d'apparence.
	if SetPortraitTexture then
		SetPortraitTexture(voletDroit.ongletStats.icone, "player")
		voletDroit.ongletStats.icone:SetTexCoord(ONGLET_PORTRAIT_COORD[1],
			ONGLET_PORTRAIT_COORD[2], ONGLET_PORTRAIT_COORD[3], ONGLET_PORTRAIT_COORD[4])
	end

	-- Le bouton d'origine du gestionnaire s'efface : c'est l'onglet qui
	-- ouvre desormais son panneau.
	local ancien = _G["GearManagerToggleButton"]
	if ancien then
		ancien:Hide()
	end
end

-- LES ONGLETS LATERAUX. camelot les met en colonne A DROITE, dehors : une
-- barre de 64 x 384 ancree au TOPRIGHT du cadre, 30 px sous son haut. Les
-- onglets du bas de 3.3.5 sont donc reposes la, empiles.
local function poserOnglets(cadre)
	if not barreOnglets then
		barreOnglets = CreateFrame("Frame", "ForeverUICharacterModeTabs", cadre)
		barreOnglets:SetWidth(ONGLETS_L)
		barreOnglets:SetHeight(ONGLETS_H)
		barreOnglets:SetPoint("TOPLEFT", cadre, "TOPRIGHT", 0, ONGLETS_Y)
	end

	local precedent
	local index = 1
	while true do
		local onglet = _G["CharacterFrameTab" .. index]
		if not onglet then
			break
		end

		if not onglet.foreverSkinned then
			balayerTextures(onglet)
			for _, methode in ipairs({ "GetNormalTexture", "GetPushedTexture",
				"GetDisabledTexture", "GetHighlightTexture" }) do
				local texture = onglet[methode] and onglet[methode](onglet)
				if texture then
					texture:SetAlpha(0)
				end
			end

			local fond = onglet:CreateTexture(nil, "BACKGROUND")
			ForeverUI.SetAtlas(fond, ATLAS.onglet, true)
			fond:SetAllPoints(onglet)
			onglet.foreverFond = fond

			local survol = onglet:CreateTexture(nil, "HIGHLIGHT")
			ForeverUI.SetAtlas(survol, ATLAS.ongletSurvol, true)
			survol:SetAllPoints(onglet)

			local icone = onglet:CreateTexture(nil, "ARTWORK")
			icone:SetWidth(ONGLET_ICONE)
			icone:SetHeight(ONGLET_ICONE)
			icone:SetPoint("CENTER", onglet, "CENTER", ONGLET_ICONE_X, 0)
			icone:Hide()
			onglet.foreverIcone = icone

			-- Le texte du client reste : les icones que la source demande
			-- pour les autres onglets n'existent pas dans l'export.
			local texte = _G["CharacterFrameTab" .. index .. "Text"]
			if texte then
				texte:ClearAllPoints()
				texte:SetPoint("CENTER", onglet, "CENTER", ONGLET_ICONE_X, 0)
				texte:SetWidth(ONGLET_L - 10)
			end

			onglet.foreverSkinned = true
			onglets[index] = onglet
		end

		onglet:SetWidth(ONGLET_L)
		onglet:SetHeight(ONGLET_H)
		onglet:ClearAllPoints()
		if precedent then
			onglet:SetPoint("TOPLEFT", precedent, "BOTTOMLEFT", 0, 0)
		else
			onglet:SetPoint("TOPLEFT", barreOnglets, "TOPLEFT", 0, 0)
		end
		precedent = onglet
		index = index + 1
	end

	-- L'onglet du personnage porte le portrait du joueur, rogne comme le
	-- fait UpdateCharacterModeTabPortrait.
	local premier = onglets[1]
	if premier and premier.foreverIcone and SetPortraitTexture then
		SetPortraitTexture(premier.foreverIcone, "player")
		premier.foreverIcone:SetTexCoord(PORTRAIT_ONGLET, 1 - PORTRAIT_ONGLET,
			PORTRAIT_ONGLET, 1 - PORTRAIT_ONGLET)
		premier.foreverIcone:Show()
		local texte = _G["CharacterFrameTab1Text"]
		if texte then
			texte:Hide()
		end
	end
end

-- Le systeme de panneaux du client repose la fenetre a chaque ouverture :
-- on remet la place retenue apres lui.
local function reposerLaPlace(cadre)
	local place = placeRetenue()["feuille"]
	if not place or InCombatLockdown() then
		return
	end

	cadre:ClearAllPoints()
	cadre:SetPoint(place.point, UIParent, place.relativePoint or place.point,
		place.x or 0, place.y or 0)
end

-- LE SYSTEME DE PANNEAUX REPREND LA MAIN, ET IL FAUT REPASSER DERRIERE.
--
-- GearManagerDialog_OnShow appelle UpdateUIPanelPositions(CharacterFrame),
-- et _OnHide appelle UpdateUIPanelPositions() : le systeme de panneaux
-- replace alors la feuille a SA position, et la place retenue par le joueur
-- est perdue. Ouvrir le gestionnaire remettait donc la fenetre a zero.
--
-- On greffe sur UpdateUIPanelPositions elle-meme, et non sur le seul
-- gestionnaire : toute autre ouverture qui la declenche pose le meme
-- probleme, et le greffon ne coute rien quand aucune place n'est retenue.
if hooksecurefunc and type(UpdateUIPanelPositions) == "function" then
	hooksecurefunc("UpdateUIPanelPositions", function()
		if CharacterFrame and CharacterFrame:IsShown() then
			reposerLaPlace(CharacterFrame)
		end
	end)
end

local function habiller()
	local cadre = CharacterFrame
	if not cadre or InCombatLockdown() then
		return
	end

	cadre:SetWidth(LARGEUR)
	cadre:SetHeight(HAUTEUR)

	if not cadre.foreverSkinned then
		-- L'ORDRE COMPTE. Les volets sont des cadres fils : ils recouvrent
		-- toute region de leur parent. L'art du panneau doit donc vivre
		-- dans un cadre fils de niveau superieur, comme le NineSlice de la
		-- source, sinon les fonds le recouvrent.
		effacerArtDepoque()
		monterVolets(cadre)
		ForeverUI.SetPanelArt(cadre, {
			coinHautGauche = COIN_PORTRAIT,
			coins = PANNEAU_COINS,
			niveau = NIVEAU_ART,
		})
		cadre.foreverSkinned = true
	end

	effacerArtDepoque()
	if ForeverUI.UpdatePanelCorners then
		ForeverUI.UpdatePanelCorners(cadre)
	end
	poserPortrait(cadre)
	poserTitre(cadre)
	reposerLaPlace(cadre)
	poserFermeture(cadre)
	poserModele()
	poserResistances()
	poserStatistiques()
	poserNiveau()
	poserOngletsVolet()
	if ForeverUI.EquipmentPane then
		ForeverUI.EquipmentPane.Apply()
	end
	poserEmplacements()
	poserOnglets(cadre)
end

-- Le client rappelle UpdatePaperdollStats(prefixe, cle) des que la
-- categorie change : l'intitule de l'en-tete correspondant se remet a jour.
local function suivreCategorie(prefixe, cle)
	for _, groupe in ipairs(STAT_GROUPES) do
		if groupe.prefixe == prefixe then
			ecrireCategorie(_G[groupe.selecteur], cle)
			return
		end
	end
end

ForeverUI.CharacterSheet = { Apply = habiller, Tabs = onglets }

if hooksecurefunc and type(_G["UpdatePaperdollStats"]) == "function" then
	hooksecurefunc("UpdatePaperdollStats", suivreCategorie)
end

if hooksecurefunc then
	for _, nomFonction in ipairs({ "CharacterFrame_ShowSubFrame", "PaperDollFrame_OnShow",
		"PaperDollFrame_SetLevel", "CharacterFrame_Collapse", "CharacterFrame_Expand" }) do
		if type(_G[nomFonction]) == "function" then
			hooksecurefunc(nomFonction, habiller)
		end
	end
end

local veilleur = CreateFrame("Frame", "ForeverUICharacterWatcher")
veilleur:RegisterEvent("PLAYER_ENTERING_WORLD")
veilleur:RegisterEvent("PLAYER_REGEN_ENABLED")
veilleur:RegisterEvent("UNIT_INVENTORY_CHANGED")
veilleur:RegisterEvent("UNIT_PORTRAIT_UPDATE")
veilleur:RegisterEvent("UNIT_MODEL_CHANGED")
veilleur:SetScript("OnEvent", habiller)

if CharacterFrame then
	CharacterFrame:HookScript("OnShow", habiller)
end

habiller()

-- LE TEMOIN. Un bouton d'equipement qui ne repond pas au clic est recouvert
-- par un cadre qui prend la souris, ou bien il ne la prend plus lui-meme :
-- rien de tout cela ne se voit a l'ecran. On demande donc au jeu.
--
-- Deux reponses. D'abord l'etat du bouton et la liste de TOUT ce qui, visible
-- et sensible a la souris, couvre son centre -- avec sa strate et son niveau,
-- qui decident lequel recoit le clic. Ensuite, pendant cinq secondes, ce que
-- GetMouseFocus rend : il suffit de promener le curseur sur un emplacement
-- pour lire le nom du cadre qui l'intercepte vraiment.
local function nomDe(cadre)
	if not cadre then
		return "?"
	end
	return (cadre.GetName and cadre:GetName()) or "(sans nom)"
end

local function couvre(cadre, x, y)
	if not cadre.GetLeft then
		return false
	end
	local g, d, h, b = cadre:GetLeft(), cadre:GetRight(), cadre:GetTop(), cadre:GetBottom()
	return g and d and h and b and x >= g and x <= d and y >= b and y <= h
end

local function parcourir(cadre, x, y, trouves, profondeur)
	if not cadre or profondeur > 6 then
		return
	end

	if cadre.IsVisible and cadre:IsVisible() and cadre.IsMouseEnabled
		and cadre:IsMouseEnabled() and couvre(cadre, x, y) then
		trouves[#trouves + 1] = cadre
	end

	if cadre.GetChildren then
		local enfants = { cadre:GetChildren() }
		for _, enfant in ipairs(enfants) do
			parcourir(enfant, x, y, trouves, profondeur + 1)
		end
	end
end

function ForeverUI.CharacterSheetDebug()
	local dire = function(texte)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. texte)
	end

	local bouton = _G["CharacterHeadSlot"]
	if not bouton or not bouton:GetLeft() then
		dire("feuille : ouvrez-la d'abord, puis refaites /fui perso")
		return
	end

	dire(string.format("tete : %dx%d strate=%s niveau=%d souris=%s montre=%s",
		bouton:GetWidth(), bouton:GetHeight(), tostring(bouton:GetFrameStrata()),
		bouton:GetFrameLevel(), tostring(bouton:IsMouseEnabled()),
		tostring(bouton:IsVisible())))

	-- Un bouton peut aussi avoir perdu ses scripts ou avoir ete desactive :
	-- cela ne se voit pas davantage a l'ecran.
	DEFAULT_CHAT_FRAME:AddMessage(string.format(
		"   clic=%s glisser=%s recoit=%s actif=%s",
		tostring(bouton:GetScript("OnClick") ~= nil),
		tostring(bouton:GetScript("OnDragStart") ~= nil),
		tostring(bouton:GetScript("OnReceiveDrag") ~= nil),
		tostring(not bouton.IsEnabled or bouton:IsEnabled() and true or false)))

	local x = (bouton:GetLeft() + bouton:GetRight()) / 2
	local y = (bouton:GetTop() + bouton:GetBottom()) / 2
	local trouves = {}
	parcourir(CharacterFrame, x, y, trouves, 0)

	DEFAULT_CHAT_FRAME:AddMessage("   ce qui couvre son centre et prend la souris :")
	for _, cadre in ipairs(trouves) do
		DEFAULT_CHAT_FRAME:AddMessage(string.format("      %-34s strate=%-16s niveau=%d",
			nomDe(cadre), tostring(cadre:GetFrameStrata()), cadre:GetFrameLevel()))
	end

	local guetteur = ForeverUI.guetteurSouris
	if not guetteur then
		guetteur = CreateFrame("Frame", "ForeverUICharacterMouseWatch")
		guetteur:Hide()
		ForeverUI.guetteurSouris = guetteur
	end

	guetteur.reste = 5
	guetteur.dernier = nil
	guetteur:SetScript("OnUpdate", function(self, ecoule)
		self.reste = self.reste - ecoule
		if self.reste <= 0 then
			self:Hide()
			self:SetScript("OnUpdate", nil)
			DEFAULT_CHAT_FRAME:AddMessage("   (fin de la veille)")
			return
		end

		local sous = GetMouseFocus and GetMouseFocus()
		local nom = nomDe(sous)
		if nom ~= self.dernier then
			self.dernier = nom
			DEFAULT_CHAT_FRAME:AddMessage("      sous le curseur : " .. nom)
		end
	end)
	guetteur:Show()
	dire("promenez le curseur sur un emplacement pendant cinq secondes.")
end

-- LE REGLAGE DU MODELE EN JEU. Aucune des deux valeurs ne se releve dans la
-- source -- camelot cadre par une scene que 3.3.5 n'a pas -- elles se jugent
-- donc a l'oeil. La commande les pose et les rend, pour pouvoir comparer les
-- deux leviers sans recharger l'interface.
--
--   /fui modele                      ce que porte le modele
--   /fui modele echelle 0.8          SetModelScale
--   /fui modele position -5 0 0      SetPosition(profondeur, lateral, hauteur)
--   /fui modele position defaut      rend la position au client
function ForeverUI.CharacterModelTune(argument)
	local dire = function(texte)
		DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. texte)
	end

	local modele = _G["CharacterModelFrame"]
	if not modele then
		return
	end

	local cle, reste = string.match(argument or "", "^(%S*)%s*(.*)$")
	cle = string.lower(cle or "")
	local reglage = ForeverUI.ModeleReglage

	if cle == "echelle" then
		reglage.echelle = tonumber(reste) or reglage.echelle
	elseif cle == "position" then
		if string.lower(reste) == "defaut" then
			reglage.position = nil
			modele:RefreshUnit()
		else
			local x, y, z = string.match(reste, "^(%-?[%d%.]+)%s+(%-?[%d%.]+)%s+(%-?[%d%.]+)$")
			if x then
				reglage.position = { tonumber(x), tonumber(y), tonumber(z) }
			else
				dire("modele : /fui modele position <profondeur> <lateral> <hauteur>")
				return
			end
		end
	elseif cle ~= "" then
		dire("modele : echelle <n> | position <x> <y> <z> | position defaut")
		return
	end

	if ForeverUI.CharacterSheet then
		ForeverUI.CharacterSheet.Apply()
	end

	local echelle = modele.GetModelScale and modele:GetModelScale()
	local x, y, z = nil, nil, nil
	if modele.GetPosition then
		x, y, z = modele:GetPosition()
	end
	dire(string.format("modele : echelle=%s position=(%s, %s, %s)",
		tostring(echelle), tostring(x), tostring(y), tostring(z)))
end
