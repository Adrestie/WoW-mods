--[[----------------------------------------------------------------------------
    Sphèrier Papota — interface joueur, côté client (expédié par AIO)

    Reprend le langage visuel validé de l'éditeur : nœud = disque + anneau de
    qualité + icône ronde, slot = châsse de gemme, arcs d'anneau cuits en
    texture, liaisons actives en cyan, départ cerclé d'or.

    États : actif (pleine couleur), achetable (atténué — départ ou voisin d'un
    actif), inaccessible (éteint). L'achat se confirme par une boîte de dialogue
    et s'exécute côté serveur par la commande du module (règles et messages).

    Accès : bouton « Sphèrier » de la fenêtre des talents, /spherier,
    .spherier show. Textes bilingues selon la langue du client.
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- côté serveur : on s'arrête ici
end

local SpherierJoueurHandlers = AIO.AddHandlers("SpherierJoueur", {})

local sqrt, cos, sin, pi   = math.sqrt, math.cos, math.sin, math.pi
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local fmt                  = string.format

-- ---------------------------------------------------------------------------
-- Textes selon la langue du client
-- ---------------------------------------------------------------------------

local FR = GetLocale() == "frFR"
local L = {
    titre        = FR and "Sphèrier" or "Sphere Grid",
    bouton       = FR and "Sphèrier" or "Sphere Grid",
    points       = FR and "Spherite : |cffffd100%d|r" or "Spherite: |cffffd100%d|r",
    prochain     = FR and "Prochain coût : |cffffd100%d|r" or "Next cost: |cffffd100%d|r",
    actifs       = FR and "%d / %d actifs" or "%d / %d active",
    noeud        = FR and "Nœud" or "Node",
    slot         = FR and "Slot" or "Socket",
    slot_desc    = FR and "N'accueille que des runes." or "Accepts runes only.",
    pierre       = FR and "Pierre %s" or "%s stone",
    sort_titre   = FR and "Sort" or "Spell",
    sort_desc    = FR and "Apprend ce sort à l'activation." or "Teaches this spell when activated.",
    sort_inconnu = FR and "Sort n°%d" or "Spell #%d",
    noeud_vide   = FR and "Nœud vide" or "Empty node",
    vide_desc    = FR and "Recevra une pierre sertie." or "Awaits a socketed stone.",
    depart       = FR and "Point de départ de la classe" or "Class starting cell",
    etat_actif   = FR and "Actif" or "Active",
    etat_cout    = FR and "Coût : %d Spherite(s) — cliquez pour acheter" or "Cost: %d Spherite — click to buy",
    etat_chemin  = FR and "Chemin : %d emplacements, coût total %d Spherite(s) — cliquez pour tout acheter"
                       or "Path: %d cells, total cost %d Spherite — click to buy them all",
    inaccessible = FR and "Inaccessible : aucun chemin ne mène ici."
                       or "Unreachable: no path leads here.",
    confirme     = FR and "Acheter cet emplacement pour %d Spherite(s) ?"
                       or "Buy this cell for %d Spherite?",
    confirme_chemin = FR and "Débloquer %d emplacements d'un coup pour %d Spherite(s) ?"
                          or "Unlock %d cells at once for %d Spherite?",
    confirme_sort   = FR and "Réapprendre ce sort pour %d Spherite(s) ?"
                          or "Relearn this spell for %d Spherite?",
    acheter      = FR and "Acheter" or "Buy",
    annuler      = FR and "Annuler" or "Cancel",
    recap_titre  = FR and "Statistiques" or "Statistics",
    recap_aide   = FR and "Acquis / total de la grille" or "Acquired / grid total",
    runes_titre  = FR and "Runes actives" or "Active runes",
    runes_vide   = FR and "Aucune rune sertie." or "No rune socketed.",
    runes_inertes = FR and "Runes inactives" or "Inactive runes",
    sorts_titre  = FR and "Sorts de classe" or "Class spells",
    sorts_vide   = FR and "Aucun sort pour cette classe." or "No spell for this class.",
    rune_titre   = FR and "Rune" or "Rune",
    rune_desc    = FR and "Ajoute un rang à %s." or "Adds one rank to %s.",
    rune_ligne   = FR and "%s — rang %d" or "%s — rank %d",
    rune_apprend = FR and "Sertir cette rune vous apprendra %s (rang %d)."
                       or "Socketing this rune will teach you %s (rank %d).",
    rune_requis  = FR and "Pré-requis : %s" or "Requires: %s",
    rune_classe  = FR and "Cette rune appartient à une autre classe."
                       or "That rune belongs to another class.",
    rune_max     = FR and "Trois runes au maximum par sort."
                       or "Three runes per spell at most.",
    rune_max_s   = FR and "Trois runes au maximum par statistique."
                       or "Three runes per statistic at most.",
    rune_stat_titre = FR and "Rune de statistique" or "Statistic rune",
    rune_stat_desc  = FR and "Majore de %d %% ce que le sphèrier vous accorde en %s."
                          or "Increases by %d%% what your sphere grid grants in %s.",
    rune_stat_pose  = FR and "Sertir cette rune majorera de %d %% ce que le sphèrier vous accorde en %s."
                          or "Socketing this rune will increase by %d%% what your sphere grid grants in %s.",
    rune_stat_ligne = FR and "%s +%d %% (%d)" or "%s +%d%% (%d)",
    rune_objet   = FR and "Rune %s" or "Rune of %s",
    rune_inerte  = FR and "%s — rang de base non connu" or "%s — base rank unknown",
    rune_inerte_t = FR and "%s — talent non appris" or "%s — talent not learned",
    rune_off     = FR and "Sans effet : le talent n'est pas appris."
                       or "No effect: the talent is not learned.",
    rune_off_r   = FR and "Sans effet : vous ne connaissez pas %s."
                       or "No effect: you do not know %s.",
    -- Sertissage et épingle
    vide_actif   = FR and "Vide — à sertir" or "Empty — awaiting a stone",
    act_sertir   = FR and "Clic gauche : sertir une pierre" or "Left-click: socket a stone",
    act_sertir_r = FR and "Clic gauche : sertir une rune" or "Left-click: socket a rune",
    rune_rang    = FR and "Rang %d" or "Rank %d",
    act_lacher   = FR and "…ou y lâcher une pierre prise dans un sac"
                       or "…or drop a stone from your bags onto it",
    act_epingle  = FR and "Clic droit : épingle de l'oubli" or "Right-click: Pin of Oblivion",
    choix_titre  = FR and "Sertir une pierre" or "Socket a stone",
    choix_vide   = FR and "Aucune pierre dans vos sacs." or "No stone in your bags.",
    choix_defiler = FR and "Molette pour faire défiler" or "Scroll to see more",
    epingle_rune_pct = FR and "Vider cet emplacement ?\n\n|cffff5555%s sera détruite et la majoration retombera à %d %%.|r\nÉpingles en sac : %d"
                        or "Empty this cell?\n\n|cffff5555%s will be destroyed and the bonus will drop back to %d%%.|r\nPins in bags: %d",
    epingle_rune_rang = FR and "Vider cet emplacement ?\n\n|cffff5555%s sera détruite et le sort retournera au rang %d.|r\nÉpingles en sac : %d"
                        or "Empty this cell?\n\n|cffff5555%s will be destroyed and the spell will drop back to rank %d.|r\nPins in bags: %d",
    epingle_rune  = FR and "Vider cet emplacement ?\n\n|cffff5555%s sera détruite.|r\nÉpingles en sac : %d"
                        or "Empty this cell?\n\n|cffff5555%s will be destroyed.|r\nPins in bags: %d",
    epingle_texte = FR and "Vider cet emplacement ?\n\n|cffff5555%s sera détruit.|r\nÉpingles en sac : %d"
                        or "Empty this cell?\n\n|cffff5555%s will be destroyed.|r\nPins in bags: %d",
    epingle_sort  = FR and "Oublier ce sort ?\n\n|cffff5555%s sera oublié.|r\nÉpingles en sac : %d"
                        or "Forget this spell?\n\n|cffff5555%s will be forgotten.|r\nPins in bags: %d",
    valider       = FR and "Valider" or "Confirm",
    sertir_texte  = FR and "Sertir %s dans cet emplacement ?\n\n|cff88ff88%s|r"
                        or "Socket %s into this cell?\n\n|cff88ff88%s|r",
    -- Objet pris en main depuis un sac : bandeau de la fenêtre.
    main_pierre   = FR and "%s en main — cliquez un emplacement vide. Clic droit pour reposer."
                        or "%s in hand — click an empty cell. Right-click to put it back.",
    main_epingle  = FR and "%s en main — cliquez un emplacement à vider. Clic droit pour la reposer."
                        or "%s in hand — click a cell to empty. Right-click to put it back.",
    contenu_sort  = FR and "Sort appris" or "Spell learned",
    contenu_oubli = FR and "Sort oublié — recliquez pour le réapprendre (coût habituel)"
                        or "Spell forgotten — click again to relearn (usual cost)",
}

-- Ordre du catalogue des 16 statistiques (SPHERIER_CONCEPTION.md §8) : cinq
-- principales, puis les secondaires. C'est l'ordre du récapitulatif.
local STAT_ORDRE = {
    "endurance", "intelligence", "esprit", "dexterite", "force",
    "parade", "blocage", "esquive", "hate", "critique", "touche",
    "puissance_sorts", "puissance_attaque", "penetration_armure",
    "expertise", "bonus_soins",
}

local STAT_LABELS = {
    endurance = FR and "Endurance" or "Stamina",
    intelligence = FR and "Intelligence" or "Intellect",
    esprit = FR and "Esprit" or "Spirit",
    dexterite = FR and "Dextérité" or "Agility",
    force = FR and "Force" or "Strength",
    parade = FR and "Parade" or "Parry",
    blocage = FR and "Blocage" or "Block",
    esquive = FR and "Esquive" or "Dodge",
    hate = FR and "Hâte" or "Haste",
    critique = FR and "Critique" or "Critical strike",
    touche = FR and "Touché" or "Hit",
    puissance_sorts = FR and "Puissance des sorts" or "Spell power",
    puissance_attaque = FR and "Puissance d'attaque" or "Attack power",
    penetration_armure = FR and "Pénétration d'armure" or "Armor penetration",
    expertise = FR and "Expertise" or "Expertise",
    bonus_soins = FR and "Bonus des soins" or "Healing bonus",
}

-- Bonus par qualité : conception figée (SPHERIER_CONCEPTION.md §7).
local QUALITES = {
    { label = FR and "Commun"     or "Common",    bonus = 5 },
    { label = FR and "Inhabituel" or "Uncommon",  bonus = 7 },
    { label = FR and "Rare"       or "Rare",      bonus = 10 },
    { label = FR and "Épique"     or "Epic",      bonus = 15 },
    { label = FR and "Légendaire" or "Legendary", bonus = 30 },
}

-- ---------------------------------------------------------------------------
-- Constantes de rendu — celles de l'éditeur, visuel validé
-- ---------------------------------------------------------------------------

-- Lua 5.1 (client WoW) : 60 upvalues au plus par fonction. Toutes les
-- constantes de rendu vivent donc dans UNE table - un seul upvalue.
local RC = {}

RC.SPACING    = 64
RC.NODE_SIZE  = 34
RC.EDGE_THICK = 11   -- style « conduit » : doit suivre EPAISSEURS du generateur
RC.MARGIN     = 120

RC.NODE_DISC_TEXTURE = "Interface\\GLUES\\MODELS\\UI_Tauren\\gradientCircle"
RC.NODE_RING_TEXTURE = "Interface\\Cooldown\\ping4"
RC.NODE_DISC_SIZE  = 78
RC.NODE_RING_SIZE  = 46  -- juste au-dela du cadre d'icone (rayon 19,3)
RC.NODE_DISC_COLOR = { 0.05, 0.05, 0.06 }
RC.ICON_SIZE_NODE  = 34

RC.SOCKET_SHEET        = "Interface\\ItemSocketingFrame\\UI-ItemSockets"
RC.SOCKET_HOLE_COORDS  = { 0.71875, 1, 0.7109375, 1 }
RC.SOCKET_FRAME_COORDS = { 0.171875, 0.3984375, 0.40234375, 0.609375 }
RC.SLOT_SCALE = 0.80

-- JALON 7 (2026-09-06) : les textures vivent dans patch-z, en BLP, sous un
-- chemin propre au MPQ ; les chemins se posent SANS extension.
RC.ART_DIR      = "Interface\\Papota\\SpherierArt\\"
RC.LINE_TEXTURE = RC.ART_DIR .. "line"
RC.LINEFACTOR_2 = (128 / 126) / 2
RC.ARC_TEXTURES = { RC.ART_DIR .. "arc1", RC.ART_DIR .. "arc2", RC.ART_DIR .. "arc3" }

-- Cadre d'icône, technique du plugin Paragon (UIParagon.xml, ParagonStatItem) :
-- l'icône ronde en ARTWORK, et par-dessus, en OVERLAY, cet anneau du client —
-- centre transparent, bande opaque, extérieur transparent. C'est lui qui
-- recouvre le bord de l'icône, le masque du moteur n'étant pas réglable (et un
-- SetTexCoord posé après le détruirait). Anneau brun-doré RGB(113,99,71), rayon
-- intérieur à 0,636 du demi-côté : à 44 px il mord de 3 px sur une icône de 34.
RC.FRAME_SHEET  = "Interface\\Journeys\\JourneysFrame2x"
RC.FRAME_COORDS = { 0.762207, 0.814941, 0.124512, 0.177246 }
RC.FRAME_SIZE   = 44
RC.ARC_TEX_W, RC.ARC_TEX_H = 256, 128
RC.ARC_CHORD_U0, RC.ARC_CHORD_V, RC.ARC_CHORD_TEXELS = 8, 100, 240

RC.QUALITY_COLORS = {
    { 1.00, 1.00, 1.00 }, { 0.12, 1.00, 0.00 }, { 0.00, 0.44, 0.87 },
    { 0.64, 0.21, 0.93 }, { 1.00, 0.50, 0.00 },
}
RC.SLOT_COLOR   = { 0.31, 0.69, 0.89 }
-- Emplacement de sort : le cadre de sort du grimoire custom (NewSpellBook,
-- planche Interface\FrameXML\NewSpellBook\NewSpellbook\Spellbook-Parts,
-- régions relevées dans NewSpellBookFrame.xml) — assiette parchemin, icône
-- CARRÉE, cadre orné de sarments : or quand le sort est actif, brun
-- (« non appris ») sinon. Référence Blizzard : bouton 37, cadre or 70x65
-- décalé de +1.5, cadre brun 70x59 décalé de -3, assiette 43 — transposés
-- pour une icône de 30 (facteur 30/37).
RC.SORT_COLOR = { 1.00, 0.30, 0.85 }         -- couleur d'accent (infobulles)
RC.SB_SHEET       = "Interface\\FrameXML\\NewSpellBook\\NewSpellbook\\Spellbook-Parts"
RC.SB_FOND_COORDS = { 0.79296875, 0.9609375, 0.00390625, 0.171875 }
RC.SB_FOND_SIZE   = 35
RC.SB_OR_COORDS   = { 0.00390625, 0.27734375, 0.44140625, 0.6953125 }
RC.SB_OR_W, RC.SB_OR_H, RC.SB_OR_DX, RC.SB_OR_DY = 57, 53, 1.2, 0
RC.SB_BRUN_COORDS = { 0.00390625, 0.27734375, 0.703125, 0.93359375 }
RC.SB_BRUN_W, RC.SB_BRUN_H, RC.SB_BRUN_DX, RC.SB_BRUN_DY = 57, 48, 1.2, -2.4
RC.ICON_SIZE_SORT = 30    -- icône carrée, comme dans le grimoire
RC.ICON_SIZE_RUNE = 26    -- la gemme tient dans la châsse, sans la déborder
-- Une rune sertie mais INERTE — talent oublié, rang de base inconnu — doit se
-- voir au premier coup d'œil : elle garde sa place mais passe au rouge.
RC.RUNE_INERTE = { 1, 0.30, 0.30 }
RC.RUNE_ACTIVE = { 0.9, 0.9, 0.9 }
-- La regle appartient au module (SpherierSertissage::TropDeRunes) ; on la
-- redit ici pour ne pas laisser tenter un geste voue au refus.
RC.RUNES_PAR_SORT = 3
-- Nœud vide : le centre est bouché par un disque opaque sombre (masque de
-- portrait sur une texture unie) — les liaisons ne se voient pas au travers.
RC.EMPTY_NODE_COLOR = { 0.55, 0.55, 0.55 }
RC.PLUG_TEXTURE     = "Interface\\Buttons\\WHITE8X8"
RC.PLUG_COLOR       = { 0.07, 0.07, 0.08 }
RC.EDGE_ACTIVE  = { 0.20, 0.88, 0.96, 1 }    -- les deux bouts actifs
RC.EDGE_FRONT   = { 0.45, 0.45, 0.45, 1 }    -- un bout actif : la frontière
RC.EDGE_OFF     = { 0.14, 0.14, 0.14, 1 }    -- éteint
RC.DEPART_COLOR     = { 1.00, 0.82, 0 }
RC.DEPART_RING_SIZE = 52

RC.DIM_ACHETABLE    = 0.55
RC.DIM_INACCESSIBLE = 0.15

-- Achat en attente de confirmation : contour blanc PULSANT sur les
-- emplacements concernés et sur les liaisons qu'ils vont activer. Rien n'est
-- allumé pour autant — les emplacements gardent leur état, seule la pulsation
-- désigne ce que l'achat va débloquer.
RC.PULSE_COLOR   = { 1, 1, 1, 1 }
RC.PULSE_SIZE    = 56                -- anneau blanc, au-delà de tout le reste
RC.PULSE_MIN     = 0.12
RC.PULSE_MAX     = 0.95
RC.PULSE_PERIODE = 2.0               -- secondes par battement

-- Étincelles : un point lumineux parcourt chaque liaison, à son allure propre.
-- Texture = le dégradé circulaire des nœuds en fusion ADD, d'où un noyau blanc
-- et un halo doux sans ressource nouvelle. Elles sont posées sur le CANEVAS en
-- OVERLAY : au-dessus des liaisons (ARTWORK), et sous les emplacements, qui
-- sont des cadres enfants et passent donc devant quoi qu'il arrive.
RC.SPARK_TEXTURE = RC.ART_DIR .. "spark"
RC.SPARK_SIZE = 24
-- Halo de la statistique survolée dans le récapitulatif. ping4 n'étant qu'un
-- trait fin, l'épaisseur s'obtient en empilant plusieurs anneaux de rayons
-- voisins : en fusion ADD, ils se fondent en une bande continue.
RC.STATHL_SIZES = { 48, 52, 56, 60 }
RC.STATHL_COLOR = { 1.00, 1.00, 0.70 }
RC.STATHL_ALPHA = 0.75
-- Récapitulatif : largeur du panneau, hauteur d'une ligne, ordonnée de la
-- première ligne (les suivantes s'empilent en dessous, à l'affichage).
RC.RECAP_W  = 236
RC.RECAP_H  = 15
-- Fond d'une ligne survolee dans le recapitulatif. Rouge sombre pour une
-- rune inerte : la surbrillance dit deja qu'elle ne donne rien.
RC.RECAP_HL = { 0.25, 0.25, 0.18 }

-- --- Habillage (2026-08-27) -------------------------------------------------
-- Rien de neuf n'est empaqueté : tout vient des archives du client.
--
-- Aucun fond de fenêtre : les deux panneaux l'occupent en entier, il n'y
-- aurait rien à voir derrière eux.
--
-- Marges intérieures du contour des boîtes de dialogue, hauteur du bandeau, et
-- le filet qui sépare les deux panneaux — deux points, pas trente-deux.
RC.BORD_G, RC.BORD_D, RC.BORD_H, RC.BORD_B = 11, 12, 12, 11
RC.BANDEAU_H = 28
RC.FILET = 2
RC.FILET_COULEUR = { 0, 0, 0 }

-- Le panneau des statistiques prend le fond de la SPÉCIALISATION courante.
-- `GetTalentTabInfo` rend le nom de fichier du décor : rien à coder en dur, et
-- l'image suit le joueur quand il change d'arbre.
RC.TALENT_CHEMIN = "Interface\\TalentFrame\\%s-%s"
-- Un décor est peint en QUATRE quartiers — aucune texture ne dépassait 256 de
-- côté en 3.3.5. L'assemblage fait 320 par 331 : 256 + 64 de large, 256 + 75 de
-- haut. Les deux quartiers du bas mesurent pourtant 128 de haut, dont 53 de
-- VIDE : sans les couper, le bas du panneau se viderait.
RC.TALENT_L = 256 / 320
RC.TALENT_H = 256 / 331
RC.TALENT_BAS_V = 75 / 128
RC.TALENT_RATIO = 320 / 331
RC.TALENT_ALPHA = 0.50
RC.TALENT_TEINTE = { 0.42, 0.42, 0.48 }   -- assombri (2026-09-05) : le texte passe devant
-- Chaque quartier, avec la part de l'image qu'il porte et la part de sa propre
-- texture qui est peinte : les deux du bas s'arrêtent à 75 sur 128.
RC.TALENT_QUARTIERS = {
    { coin = "TopLeft",     u0 = 0,           u1 = 256 / 320, v0 = 0,           v1 = 256 / 331, vmax = 1 },
    { coin = "TopRight",    u0 = 256 / 320,   u1 = 1,         v0 = 0,           v1 = 256 / 331, vmax = 1 },
    { coin = "BottomLeft",  u0 = 0,           u1 = 256 / 320, v0 = 256 / 331,   v1 = 1,         vmax = 75 / 128 },
    { coin = "BottomRight", u0 = 256 / 320,   u1 = 1,         v0 = 256 / 331,   v1 = 1,         vmax = 75 / 128 },
}
RC.RECAP_HL_INERTE = { 0.35, 0.15, 0.15 }
-- Couleurs du récapitulatif. Le violet est celui des objets épiques, pour que
-- « au-delà du maximum » se lise du même œil que le reste de l'interface.
RC.RECAP_TXT = { 1, 1, 1 }
RC.RECAP_TXT_PLEIN = { 0.2, 1, 0.2 }
RC.RECAP_TXT_DEPASSE = { 0.64, 0.21, 0.93 }
RC.RECAP_Y0 = -38
RC.SPARK_VMIN, RC.SPARK_VMAX = 0.06, 0.20   -- fraction de liaison par seconde

RC.ZOOM_MIN, RC.ZOOM_MAX, RC.ZOOM_STEP = 0.30, 1.60, 0.10

-- Liste de choix des pierres, ouverte au clic sur un emplacement actif et vide.
-- Elle ne montre que ce qui tient dans les sacs et qui est sertissable ; la
-- molette fait défiler quand il y en a plus que de lignes.
RC.PICK_W        = 232
RC.PICK_ROW_H    = 22
RC.PICK_ROWS     = 8
RC.PICK_ICON     = 18
RC.PICK_PAD      = 10
RC.EPINGLE_ENTRY = 803300           -- repli ; la valeur qui fait foi vient de la base
RC.PLAYER_BAGS   = { 0, 1, 2, 3, 4 }
-- Objet pris en main par un clic droit dans un sac : le curseur passe en mode
-- « appliquer sur une cible », comme un sort à lancer. SetCursor attend un NOM
-- de curseur du moteur (cf. ShowInspectCursor dans UIParent.lua), pas un chemin.
-- Barré tant que ce qui est survolé ne peut pas recevoir l'objet — c'est la
-- règle du jeu pour tout ce qui s'applique sur une cible.
RC.CURSEUR_MAIN    = "CAST_CURSOR"
RC.CURSEUR_MAIN_KO = "CAST_ERROR_CURSOR"

-- ---------------------------------------------------------------------------
-- État
-- ---------------------------------------------------------------------------

local UI
local DEF  = nil        -- définition envoyée par le serveur
local ETAT = nil        -- état du personnage
local zoom = 1
local bounds = { minx = 0, miny = 0, maxx = 0, maxy = 0 }
-- Centrage du contenu quand il est plus petit que la vue : le canevas est
-- gonflé à la taille de la vue et le contenu décalé d'autant — sans cela, un
-- zoom arrière tasse la grille dans le coin haut-gauche (ancrage du
-- ScrollFrame).
local offsetX, offsetY = 0, 0

local nParId, cParId, adjParId = {}, {}, {}

-- Achat en attente de confirmation : ensemble des emplacements qui seront
-- débloqués si le joueur valide. Leur contour pulse, ainsi que celui des
-- liaisons concernées, tant que la boîte de dialogue reste ouverte.
local achatEnCours = nil

-- Statistique survolée dans le récapitulatif : toutes les pierres qui la
-- portent s'entourent alors d'un halo, y compris celles pas encore achetées.
local statSurvolee = nil
-- Rune survolee dans le recapitulatif : meme principe que la statistique,
-- les emplacements qui la portent recoivent un halo. On retient aussi si
-- elle est inerte, pour teindre ce halo en rouge.
local runeSurvolee, runeInerte = nil, false
-- Ligne de sort survolée dans la barre latérale : l'emplacement qui le porte
-- reçoit le halo.
local sortSurvole = nil
-- L'empreinte de la définition que le client tient : le serveur ne renvoie
-- la grille que si elle a changé (2026-09-05).
local DEF_VERSION = nil

-- Sertissage, épingle et liste de choix. Elles vivent dans UNE table plutôt
-- qu'en locals nus : chaque local de module coûte un upvalue aux grosses
-- fonctions (Rebuild), et le client Lua 5.1 en plafonne à 60.
local ACT = {}

-- Catalogue des objets du sphèrier (pierres, runes, entrée de l'épingle),
-- demandé au serveur dès le chargement : sans lui, le client ne saurait pas
-- reconnaître une pierre dans un sac AVANT la première ouverture de la fenêtre.
-- Rien n'y est codé en dur, tout vient de la base.
local CAT = { pierres = {}, runes = {}, runesStat = {}, epingle = 0, iconeParStat = {} }

local function EstActif(id)     return ETAT and ETAT.actives[id] end

local function EstAchetable(id)
    if not DEF or not ETAT or EstActif(id) then return false end
    if DEF.depart == id then return true end
    for _, v in ipairs(adjParId[id] or {}) do
        if EstActif(v) then return true end
    end
    return false
end

-- Coût de la tranche applicable pour un nombre d'emplacements déjà actifs —
-- le même barème que le module.
local function CoutTranche(nbActifs)
    local cout = 0
    for _, t in ipairs(DEF and DEF.bareme or {}) do
        if t.min > nbActifs then break end
        cout = t.cout
    end
    return cout
end

-- Plus court chemin (en sauts) entre l'emplacement visé et l'actif le plus
-- proche — ou le départ si rien n'est actif (le départ fait alors partie des
-- achats). Renvoie la liste ordonnée des emplacements à acheter, du côté
-- actif vers la cible, ou nil si aucun chemin n'existe.
local function CheminVers(cible)
    if not DEF or not ETAT or EstActif(cible) then return nil end

    local aucunActif = (ETAT.nbActifs or 0) == 0
    local vus, parent, file = { [cible] = true }, {}, { cible }
    local tete, arrivee = 1, nil

    while file[tete] do
        local courant = file[tete]
        tete = tete + 1

        local atteint = (not aucunActif and EstActif(courant))
            or (aucunActif and DEF.depart == courant)
        if atteint then
            arrivee = courant
            break
        end

        for _, v in ipairs(adjParId[courant] or {}) do
            if not vus[v] then
                vus[v] = true
                parent[v] = courant
                file[#file + 1] = v
            end
        end
    end

    if not arrivee then return nil end

    -- La chaîne des parents remonte de l'arrivée vers la cible : c'est
    -- l'ordre d'achat. L'actif atteint est exclu ; le départ (grille encore
    -- vierge) est inclus, il s'achète comme les autres.
    local chemin = {}
    local courant = aucunActif and arrivee or parent[arrivee]
    while courant do
        chemin[#chemin + 1] = courant
        courant = parent[courant]
    end
    return #chemin > 0 and chemin or nil
end

local function CoutChemin(chemin)
    local total = 0
    for i = 1, #chemin do
        total = total + CoutTranche((ETAT.nbActifs or 0) + i - 1)
    end
    return total
end

-- Habille le cadre d'un emplacement de sort : or (actif) ou brun (non
-- appris) — géométrie de NewSpellBookFrame.xml, transposée.
local function HabillerCadreSort(btn, dore, r, g, b)
    local cadre = btn.sbCadre
    if dore then
        cadre:SetTexCoord(RC.SB_OR_COORDS[1], RC.SB_OR_COORDS[2],
            RC.SB_OR_COORDS[3], RC.SB_OR_COORDS[4])
        cadre:SetWidth(RC.SB_OR_W)
        cadre:SetHeight(RC.SB_OR_H)
        cadre:ClearAllPoints()
        cadre:SetPoint("CENTER", RC.SB_OR_DX, RC.SB_OR_DY)
    else
        cadre:SetTexCoord(RC.SB_BRUN_COORDS[1], RC.SB_BRUN_COORDS[2],
            RC.SB_BRUN_COORDS[3], RC.SB_BRUN_COORDS[4])
        cadre:SetWidth(RC.SB_BRUN_W)
        cadre:SetHeight(RC.SB_BRUN_H)
        cadre:ClearAllPoints()
        cadre:SetPoint("CENTER", RC.SB_BRUN_DX, RC.SB_BRUN_DY)
    end
    cadre:SetVertexColor(r, g, b)
    btn.sbFond:SetVertexColor(r, g, b)
    btn.sbFond:Show()
    cadre:Show()
end

-- ---------------------------------------------------------------------------
-- Tracés — segments et arcs de l'éditeur, à l'identique
-- ---------------------------------------------------------------------------

local function AcquireLine(canvas, pool, col, tex)
    local t = table.remove(pool.free)
    if not t then t = canvas:CreateTexture(nil, "ARTWORK") end
    t:SetTexture(tex or RC.LINE_TEXTURE)
    t:SetDrawLayer("ARTWORK")
    t:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
    -- Une texture rendue au réservoir peut sortir d'une pulsation : sans cette
    -- remise à zéro, elle resservirait avec l'alpha où la pulsation l'a laissée.
    t:SetAlpha(1)
    t:Show()
    pool.used[#pool.used + 1] = t
    return t
end

local function DrawSegment(canvas, pool, sx, sy, ex, ey, w, col)
    local T = AcquireLine(canvas, pool, col)
    T:ClearAllPoints()

    local dx, dy = ex - sx, ey - sy
    local cx, cy = (sx + ex) / 2, (sy + ey) / 2

    if dx == 0 and dy == 0 then T:Hide() return end

    if dy == 0 then
        T:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
        T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", min(sx, ex), cy - w / 2)
        T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", max(sx, ex), cy + w / 2)
        return T
    end

    if dx == 0 then
        T:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
        T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", cx - w / 2, min(sy, ey))
        T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", cx + w / 2, max(sy, ey))
        return T
    end

    if dx < 0 then dx, dy = -dx, -dy end

    local l = sqrt(dx * dx + dy * dy)
    local s, c = -dy / l, dx / l
    local sc = s * c

    local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy
    if dy >= 0 then
        Bwid = ((l * c) - (w * s)) * RC.LINEFACTOR_2
        Bhgt = ((w * c) - (l * s)) * RC.LINEFACTOR_2
        BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc
        BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx
        TRy = BRx
    else
        Bwid = ((l * c) + (w * s)) * RC.LINEFACTOR_2
        Bhgt = ((w * c) + (l * s)) * RC.LINEFACTOR_2
        BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc
        BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy
        TRx = TLy
    end

    local function cl(v) return v > 10000 and 10000 or (v < -10000 and -10000 or v) end

    T:SetTexCoord(cl(TLx), cl(TLy), cl(BLx), cl(BLy), cl(TRx), cl(TRy), cl(BRx), cl(BRy))
    T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", cx - Bwid, cy - Bhgt)
    T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", cx + Bwid, cy + Bhgt)
    return T
end

local function DrawClusterArc(canvas, pool, ax, ay, bx, by, ccx, ccy, ring, col)
    local tex = RC.ARC_TEXTURES[ring]
    if not tex then return end

    local dx, dy = bx - ax, by - ay
    local Lg = sqrt(dx * dx + dy * dy)
    if Lg == 0 then return end
    local ux, uy = dx / Lg, dy / Lg
    local s = Lg / RC.ARC_CHORD_TEXELS

    local nx, ny = (ax + bx) / 2 - ccx, (ay + by) / 2 - ccy
    local nl = sqrt(nx * nx + ny * ny)
    if nl == 0 then nx, ny = -uy, ux else nx, ny = nx / nl, ny / nl end

    local function toScreen(tu, tv)
        local du = (tu - RC.ARC_CHORD_U0) * s
        local dv = (RC.ARC_CHORD_V - tv) * s
        return ax + ux * du + nx * dv, ay + uy * du + ny * dv
    end
    local x1, y1 = toScreen(0, 0)
    local x2, y2 = toScreen(RC.ARC_TEX_W, 0)
    local x3, y3 = toScreen(0, RC.ARC_TEX_H)
    local x4, y4 = toScreen(RC.ARC_TEX_W, RC.ARC_TEX_H)
    local minx, maxx = min(x1, x2, x3, x4), max(x1, x2, x3, x4)
    local miny, maxy = min(y1, y2, y3, y4), max(y1, y2, y3, y4)

    local function toTex(qx, qy)
        local rx, ry = qx - ax, qy - ay
        return (RC.ARC_CHORD_U0 + (rx * ux + ry * uy) / s) / RC.ARC_TEX_W,
               (RC.ARC_CHORD_V - (rx * nx + ry * ny) / s) / RC.ARC_TEX_H
    end

    local T = AcquireLine(canvas, pool, col, tex)
    T:ClearAllPoints()
    local ulu, ulv = toTex(minx, maxy)
    local llu, llv = toTex(minx, miny)
    local uru, urv = toTex(maxx, maxy)
    local lru, lrv = toTex(maxx, miny)
    T:SetTexCoord(ulu, ulv, llu, llv, uru, urv, lru, lrv)
    T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", minx, miny)
    T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", maxx, maxy)
    return T
end

-- ---------------------------------------------------------------------------
-- Rendu
-- ---------------------------------------------------------------------------

local function ToPixels(gx, gy)
    return (gx - bounds.minx) * RC.SPACING + RC.MARGIN + offsetX,
           (gy - bounds.miny) * RC.SPACING + RC.MARGIN + offsetY
end

local Rebuild, CentrerSur

-- ---------------------------------------------------------------------------
-- Sertissage : ce que porte un emplacement, et les gestes qui l'y mettent
-- ---------------------------------------------------------------------------

-- Ce qu'un emplacement montre AUJOURD'HUI. Tant qu'il n'est pas acheté, la
-- grille annonce ce qu'il donnera (la pierre de la définition) ; une fois
-- acheté, elle montre ce qu'il porte réellement — une pierre sertie a pu
-- remplacer celle d'origine, l'épingle a pu le vider.
function ACT.Effectif(n)
    if EstActif(n.id) then
        local c = ETAT.contenu[n.id]
        if c then return c.stat, c.montant or 0, c.qualite or 0 end
        return nil, 0, 0
    end
    -- LE CONTENU DE COMPTE VAUT AUSSI AVANT L'ACHAT (2026-09-06) : un nœud
    -- vidé ou regarni par un autre personnage du compte se montre tel quel,
    -- et c'est ce que l'achat donnera.
    local compte = ETAT and ETAT.contenuCompte and ETAT.contenuCompte[n.id]
    if compte ~= nil then
        local effet = CAT.pierres[compte]
        if effet then return effet.stat, effet.montant or 0, effet.qualite or 0 end
        return nil, 0, 0
    end
    return n.stat, n.montant or 0, n.qualite or 0
end

-- Vrai si l'emplacement est acheté et ne porte rien : c'est le seul cas où l'on
-- peut sertir. `brut` vaut 0 pour un emplacement vidé comme pour un nœud vide
-- de naissance.
function ACT.EstVide(n)
    return EstActif(n.id) and (not ETAT.brut or (ETAT.brut[n.id] or 0) == 0)
end

-- La rune que porte un slot, ou rien. `contenu` ne parle que des pierres,
-- dont l'effet est connu ; pour une rune, c'est `brut` qui sait ce qui est
-- serti, et le catalogue qui sait le décrire.
function ACT.RuneSertie(n)
    if not (ETAT and ETAT.brut) then return nil end
    local entree = ETAT.brut[n.id]
    if not entree or entree == 0 then return nil end
    -- Les deux sortes : `sort` marque une rune de rang, `pct` une rune de
    -- statistique. Un descripteur de pierre porte `stat` lui aussi, d'où le
    -- choix de `pct` comme marqueur.
    local r = CAT.runes[entree] or CAT.runesStat[entree]
    if not r then return nil end
    return r, entree
end

-- Une rune ne donne son rang que si le joueur connaît DÉJÀ le dernier rang de
-- Blizzard : un talent oublié la laisse sertie mais inerte, et le module ne la
-- déloge pas. Le serveur envoie avec l'état ceux qui sont remplis à cet
-- instant, puisque cela suit les talents.
function ACT.RuneActive(entree)
    -- Une rune de statistique n'a aucune condition : elle majore ce que la
    -- grille donne, quoi qu'il arrive.
    if entree and CAT.runesStat[entree] then return true end
    local r = entree and CAT.runes[entree]
    if not r then return false end
    if not (r.requis and r.requis > 0) then return true end
    return (ETAT and ETAT.requisOk and ETAT.requisOk[entree]) and true or false
end

-- Combien de runes de CETTE ENTRÉE sont déjà serties. C'est exactement la
-- règle du module — trois entrées identiques au plus dans la grille — et elle
-- vaut pour les deux sortes de rune, une entrée valant une famille de sort
-- comme une statistique.
function ACT.CompterRunes(entree)
    local n = 0
    if not (entree and DEF and ETAT and ETAT.brut) then return n end
    for _, e in ipairs(DEF.nodes) do
        if ETAT.brut[e.id] == entree then n = n + 1 end
    end
    return n
end

-- Un emplacement acheté et vide peut recevoir quelque chose : une pierre s'il
-- s'agit d'un nœud, une rune s'il s'agit d'un slot. Un emplacement de sort ne
-- se sertit jamais.
function ACT.PeutSertir(n)
    return (n.kind == 0 or n.kind == 1) and ACT.EstVide(n)
end

-- Le module tranche pour de bon ; on refuse ici ce qui est manifestement
-- impossible, pour ne pas proposer un geste voué au refus.
-- Une rune de RANG appartient à une classe et ne se sertit que dans la
-- grille de celle-ci. Elle se loote pourtant sans condition : c'est voulu, et
-- c'est l'établi qui la rendra utile. Les runes de statistique n'ont pas cette
-- attache.
function ACT.BonneClasse(entree)
    local r = entree and CAT.runes[entree]
    if not r or not r.classe or r.classe == 0 then return true end
    return not DEF or not DEF.classe or DEF.classe == r.classe
end

function ACT.AccepteObjet(n, entree)
    if not ACT.PeutSertir(n) then return false end
    if n.kind == 1 then
        if not ACT.BonneClasse(entree) then return false end
        return (CAT.runes[entree] or CAT.runesStat[entree]) ~= nil
    end
    return CAT.pierres[entree] ~= nil
end

-- Ce que le catalogue dit d'une entrée d'objet. Une pierre va dans un nœud,
-- une rune dans un slot (jalon 5) : c'est le module qui tranche, on se contente
-- ici de reconnaître l'objet et de savoir le décrire.
function ACT.Sertissable(entree)
    if not entree then return nil end
    return CAT.pierres[entree] or CAT.runes[entree] or CAT.runesStat[entree]
end

function ACT.EntreeEpingle()
    return (CAT.epingle and CAT.epingle > 0) and CAT.epingle or RC.EPINGLE_ENTRY
end

function ACT.EstEpingle(entree)
    return entree == ACT.EntreeEpingle()
end

-- « Rune de Frappe héroïque », mais « Rune d'Onde de choc » : en français,
-- « de » s'élide devant une voyelle ou un h muet. Même règle que le nom posé
-- en base par le générateur, pour que les deux se ressemblent.
local function DeSort(nomSort)
    local d = (nomSort or ""):sub(1, 1)
    return (("aeiouyhAEIOUYHàâäéèêëîïôöùûüÿœÀÂÄÉÈÊËÎÏÔÖÙÛÜŒ"):find(d, 1, true)
            and "d'" or "de ") .. (nomSort or "")
end

function ACT.NomObjet(entree, descripteur)
    local nom = GetItemInfo(entree)
    if nom then return nom end
    -- Une rune SERTIE n'est plus dans les sacs : le client n'en a donc pas
    -- forcément le nom en cache, et sans cela l'épingle annonçait « +0 ? ».
    if descripteur and descripteur.sort then
        local nomSort = GetSpellInfo(descripteur.sort)
                        or fmt(L.sort_inconnu, descripteur.sort)
        -- L'élision ne vaut que pour le français : « Rune of X » en anglais.
        return fmt(L.rune_objet, FR and DeSort(nomSort) or nomSort)
    end
    if descripteur and descripteur.pct then
        local nomStat = STAT_LABELS[descripteur.stat] or "?"
        return fmt(L.rune_objet, FR and DeSort(nomStat) or nomStat)
    end
    if descripteur then
        return fmt("+%d %s", descripteur.montant or 0, STAT_LABELS[descripteur.stat] or "?")
    end
    return tostring(entree)
end

function ACT.IconeObjet(entree, descripteur)
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(entree)
    return texture
        or (descripteur and CAT.iconeParStat[descripteur.stat])
        or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Parcours des sacs du joueur. `filtre` reçoit l'entrée et dit si on la garde.
function ACT.ParcourirSacs(filtre, action)
    for _, sac in ipairs(RC.PLAYER_BAGS) do
        for emp = 1, (GetContainerNumSlots(sac) or 0) do
            local entree = GetContainerItemID and GetContainerItemID(sac, emp)
            if not entree then
                local lien = GetContainerItemLink(sac, emp)
                entree = lien and tonumber(lien:match("item:(%d+)"))
            end
            if entree and filtre(entree) then
                local _, nb = GetContainerItemInfo(sac, emp)
                action(entree, nb or 1)
            end
        end
    end
end

function ACT.CompterEnSac(entree)
    local total = 0
    ACT.ParcourirSacs(function(e) return e == entree end,
        function(_, nb) total = total + nb end)
    return total
end

-- Ce que le joueur porte et qui peut entrer dans CET emplacement, regroupé par
-- entrée et ordonné comme le récapitulatif : par statistique, puis par qualité.
function ACT.PierresEnSac(n)
    local parEntree, liste = {}, {}
    ACT.ParcourirSacs(function(e)
            if n then return ACT.AccepteObjet(n, e) end
            return ACT.Sertissable(e) ~= nil
        end,
        function(e, nb)
            if parEntree[e] then
                parEntree[e].nb = parEntree[e].nb + nb
            else
                local p = ACT.Sertissable(e)
                parEntree[e] = { entree = e, nb = nb, stat = p.stat,
                                 montant = p.montant, qualite = p.qualite,
                                 sort = p.sort, rang = p.rang }
                liste[#liste + 1] = parEntree[e]
            end
        end)

    local rang = {}
    for i, cle in ipairs(STAT_ORDRE) do rang[cle] = i end
    table.sort(liste, function(a, b)
        local ra, rb = rang[a.stat] or 99, rang[b.stat] or 99
        if ra ~= rb then return ra < rb end
        return (a.qualite or 0) > (b.qualite or 0)
    end)
    return liste
end

function ACT.FermerChoix()
    if UI and UI.choix then UI.choix:Hide() end
end

-- --- objet pris en main --------------------------------------------------
-- Un clic droit sur une pierre, une rune ou une épingle dans un sac ouvre le
-- sphèrier et met l'objet « en main » : le curseur passe en mode application et
-- un bandeau rappelle ce qu'on tient. Le clic gauche sur un emplacement fait
-- alors exactement ce que ferait le geste équivalent dans l'interface.
function ACT.MajBandeau()
    if not UI or not UI.banniere then return end
    local m = ACT.enMain
    if not m then
        UI.banniere:SetText("")
        UI.banniereIcone:Hide()
        return
    end
    UI.banniere:SetText(fmt(m.epingle and L.main_epingle or L.main_pierre,
        ACT.NomObjet(m.entree, m.descripteur)))
    UI.banniereIcone:SetTexture(ACT.IconeObjet(m.entree, m.descripteur))
    UI.banniereIcone:Show()
end

-- Ce que l'objet en main peut viser. L'épingle vide un emplacement garni ;
-- une pierre ou une rune remplit un emplacement vide du bon type.
function ACT.CibleValide(n)
    local m = ACT.enMain
    if not m or not n then return false end
    if m.epingle then return EstActif(n.id) and not ACT.EstVide(n) end
    return ACT.AccepteObjet(n, m.entree)
end

-- Curseur d'application : barré partout, franc au survol de ce qui peut
-- recevoir l'objet.
function ACT.MajCurseur()
    if not ACT.enMain or not SetCursor then return end
    SetCursor(ACT.CibleValide(ACT.survol) and RC.CURSEUR_MAIN or RC.CURSEUR_MAIN_KO)
end

function ACT.PrendreEnMain(entree)
    local descripteur = ACT.Sertissable(entree)
    if not descripteur and not ACT.EstEpingle(entree) then return false end

    ACT.enMain = { entree = entree, descripteur = descripteur,
                   epingle = descripteur == nil }
    ACT.survol = nil
    -- Le clic qui vient de prendre l'objet est encore enfoncé : sans cela, la
    -- surveillance ci-dessous le prendrait pour un « clic ailleurs ».
    ACT.clicPrecedent = true
    ACT.MajCurseur()
    ACT.MajBandeau()
    return true
end

function ACT.Reposer()
    if not ACT.enMain then return end
    ACT.enMain = nil
    ACT.survol = nil
    if ResetCursor then ResetCursor() end
    ACT.MajBandeau()
end

-- Battement du mode « objet en main », à chaque image tant que la fenêtre est
-- ouverte. Il tient deux choses :
--
-- 1. le curseur, réaffirmé en continu — les autres cadres du jeu appellent
--    ResetCursor() dès qu'on les survole (CursorUpdate dans UIParent.lua), et
--    le nôtre doit tenir jusqu'à l'annulation ;
-- 2. « tout clic ailleurs repose l'objet ». On OBSERVE les boutons de la souris
--    au lieu d'intercepter les clics : un cadre qui les attraperait les
--    empêcherait d'atteindre le reste de l'interface. Seul le front montant
--    compte.
function ACT.Battement()
    if not ACT.enMain then return end

    ACT.MajCurseur()

    if not (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then
        ACT.clicPrecedent = false
        return
    end
    if ACT.clicPrecedent then return end
    ACT.clicPrecedent = true

    -- Une confirmation ouverte prolonge le geste : ce n'est pas un ailleurs.
    if StaticPopup_Visible("SPHERIER_SERTIR") or StaticPopup_Visible("SPHERIER_EPINGLE") then
        return
    end

    -- Un emplacement est survolé : c'est SON clic, on le laisse décider. Le
    -- reposer ici, sur l'enfoncement, laisserait le relâchement retomber dans
    -- le comportement normal du clic — un emplacement non acheté proposerait
    -- alors son achat, ce qui n'est pas le geste demandé.
    if ACT.survol then return end

    ACT.Reposer()
end

function ACT.Sertir(nodeId, entree)
    ACT.FermerChoix()
    AIO.Handle("SpherierJoueur", "Sertir", nodeId, entree)
    ACT.Reposer()
end

-- Une pierre réellement tenue par le curseur du jeu (glissée depuis un sac) :
-- même geste, autre source.
function ACT.PierreDuCurseur()
    if not CursorHasItem or not CursorHasItem() then return nil end
    local genre, a, lien = GetCursorInfo()
    if genre ~= "item" then return nil end
    local entree = tonumber(a) or (lien and tonumber(tostring(lien):match("item:(%d+)")))
    if entree and ACT.Sertissable(entree) then return entree end
    return nil
end

local function LigneChoix(liste, i, ligne)
    local p = liste[i]
    if not p then ligne:Hide() return end

    local q = RC.QUALITY_COLORS[p.qualite or 1] or RC.QUALITY_COLORS[1]
    ligne.icone:SetTexture(ACT.IconeObjet(p.entree, p))
    ligne.nom:SetText(ACT.NomObjet(p.entree, p))
    ligne.nom:SetTextColor(q[1], q[2], q[3])
    -- Une rune ne porte pas de statistique : elle donne un rang. On dit donc
    -- lequel plutôt que d'afficher « +0 ? ».
    local quantite = p.nb > 1 and fmt("  x%d", p.nb) or ""
    if p.pct then
        ligne.effet:SetText(fmt("+%d %%%%  %s",
            p.pct * (ACT.CompterRunes(p.entree) + 1),
            STAT_LABELS[p.stat] or "?") .. quantite)
        ligne.effet:SetTextColor(0.1, 1, 0.1)
    elseif p.sort then
        -- Le rang promis tient compte de ce qui est déjà serti : la deuxième
        -- rune d'une famille donne le suivant, pas le premier.
        ligne.effet:SetText(fmt(L.rune_rang,
            (p.rang or 0) + ACT.CompterRunes(p.entree)) .. quantite)
        if ACT.RuneActive(p.entree) then
            ligne.effet:SetTextColor(0.1, 1, 0.1)
        else
            ligne.effet:SetTextColor(RC.RUNE_INERTE[1], RC.RUNE_INERTE[2], RC.RUNE_INERTE[3])
        end
    else
        ligne.effet:SetText(fmt("+%d %s%s", p.montant or 0,
            STAT_LABELS[p.stat] or "?", quantite))
        ligne.effet:SetTextColor(0.1, 1, 0.1)
    end
    ligne.entree = p.entree
    ligne:Show()
end

function ACT.RemplirChoix()
    local cadre = UI.choix
    -- N'offrir que ce qui peut entrer ici : des pierres pour un nœud, des
    -- runes pour un slot.
    local liste = ACT.PierresEnSac(nParId[cadre.node])
    cadre.liste = liste

    local maxi = max(0, #liste - RC.PICK_ROWS)
    if cadre.offset > maxi then cadre.offset = maxi end

    for i = 1, RC.PICK_ROWS do
        LigneChoix(liste, i + cadre.offset, cadre.lignes[i])
    end
    cadre.vide:SetText(#liste == 0 and L.choix_vide
        or (#liste > RC.PICK_ROWS and L.choix_defiler or ""))
end

function ACT.OuvrirChoix(btn, n)
    if not UI.choix then
        local cadre = CreateFrame("Frame", "SpherierChoixPierre", UI)
        cadre:SetFrameStrata("DIALOG")
        cadre:SetWidth(RC.PICK_W)
        cadre:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        cadre:EnableMouse(true)
        cadre:EnableMouseWheel(true)
        cadre:SetScript("OnMouseWheel", function(self, delta)
            local maxi = max(0, #(self.liste or {}) - RC.PICK_ROWS)
            self.offset = min(maxi, max(0, self.offset - delta))
            ACT.RemplirChoix()
        end)

        local titre = cadre:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
        titre:SetPoint("TOPLEFT", RC.PICK_PAD + 2, -RC.PICK_PAD - 2)
        titre:SetText(L.choix_titre)

        local fermer = CreateFrame("Button", nil, cadre, "UIPanelCloseButton")
        fermer:SetWidth(24)
        fermer:SetHeight(24)
        fermer:SetPoint("TOPRIGHT", -4, -4)

        cadre.lignes = {}
        for i = 1, RC.PICK_ROWS do
            local ligne = CreateFrame("Button", nil, cadre)
            ligne:SetWidth(RC.PICK_W - 2 * RC.PICK_PAD - 4)
            ligne:SetHeight(RC.PICK_ROW_H)
            ligne:SetPoint("TOPLEFT", RC.PICK_PAD + 2,
                -(RC.PICK_PAD + 20) - (i - 1) * RC.PICK_ROW_H)
            ligne:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

            ligne.icone = ligne:CreateTexture(nil, "ARTWORK")
            ligne.icone:SetWidth(RC.PICK_ICON)
            ligne.icone:SetHeight(RC.PICK_ICON)
            ligne.icone:SetPoint("LEFT")

            ligne.nom = ligne:CreateFontString(nil, "OVERLAY", "GameTooltipText")
            ligne.nom:SetPoint("LEFT", RC.PICK_ICON + 6, 5)
            ligne.nom:SetJustifyH("LEFT")

            ligne.effet = ligne:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
            ligne.effet:SetPoint("LEFT", RC.PICK_ICON + 6, -5)
            ligne.effet:SetJustifyH("LEFT")
            ligne.effet:SetTextColor(0.1, 1, 0.1)

            ligne:SetScript("OnClick", function(self)
                if self.entree and cadre.node then
                    ACT.DemanderSertissage(cadre.node, self.entree)
                end
            end)
            cadre.lignes[i] = ligne
        end

        cadre.vide = cadre:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
        cadre.vide:SetPoint("BOTTOMLEFT", RC.PICK_PAD + 2, RC.PICK_PAD + 2)

        cadre:SetHeight(RC.PICK_PAD * 2 + 20 + RC.PICK_ROWS * RC.PICK_ROW_H + 16)
        table.insert(UISpecialFrames, "SpherierChoixPierre")
        UI.choix = cadre
    end

    UI.choix.node = n.id
    UI.choix.offset = 0
    UI.choix:ClearAllPoints()
    UI.choix:SetPoint("TOPLEFT", btn, "BOTTOMRIGHT", 4, 0)
    UI.choix.ancre = btn
    ACT.RemplirChoix()
    UI.choix:Show()
end

-- Le bouton de validation d'une épingle est grisé tant que le joueur n'en porte
-- aucune : le refus du module resterait la vraie barrière, mais il vaut mieux
-- montrer d'emblée que le geste est impossible.
StaticPopupDialogs["SPHERIER_EPINGLE"] = {
    text = "%s",
    button1 = L.valider,
    button2 = L.annuler,
    OnShow = function(self)
        local bouton = _G[self:GetName() .. "Button1"]
        if not bouton then return end
        if ACT.CompterEnSac(ACT.EntreeEpingle()) > 0 then
            bouton:Enable()
        else
            bouton:Disable()
        end
    end,
    OnAccept = function(self, data)
        AIO.Handle("SpherierJoueur", "Epingler", data)
    end,
    -- OnHide couvre les trois sorties : validation, annulation et Échap.
    OnHide = function() ACT.Reposer() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

-- Posé juste avant l'ouverture : `OnShow` est appelé AVANT que `popup.data` ne
-- soit renseigné par l'appelant, il ne peut donc rien y lire. Même détour que
-- pour l'épingle, qui grise son bouton quand le sac n'en contient aucune.
local sertirBloque = false

-- Sertir consomme la pierre : confirmation, comme pour l'épingle.
StaticPopupDialogs["SPHERIER_SERTIR"] = {
    text = "%s",
    button1 = L.valider,
    button2 = L.annuler,
    OnShow = function(self)
        local bouton = _G[self:GetName() .. "Button1"]
        if not bouton then return end
        if sertirBloque then bouton:Disable() else bouton:Enable() end
    end,
    OnAccept = function(self, data)
        -- Ceinture et bretelles : le bouton est grisé, mais rien ne coûte de
        -- refuser une seconde fois.
        if sertirBloque then return end
        if data then ACT.Sertir(data.node, data.entree) end
    end,
    OnHide = function() ACT.Reposer() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function ACT.DemanderSertissage(nodeId, entree)
    local descripteur = ACT.Sertissable(entree)
    if not descripteur then return end
    ACT.FermerChoix()

    local q = RC.QUALITY_COLORS[descripteur.qualite or 1] or RC.QUALITY_COLORS[1]
    local nom = fmt("|cff%02x%02x%02x%s|r", q[1] * 255, q[2] * 255, q[3] * 255,
        ACT.NomObjet(entree, descripteur))
    local effet
    sertirBloque = false
    -- Barrage de dernier recours : les listes n'offrent plus les runes d'une
    -- autre classe, mais le curseur chargé ou un lâcher pourraient y mener.
    if descripteur.sort and not ACT.BonneClasse(entree) then
        sertirBloque = true
        local popup = StaticPopup_Show("SPHERIER_SERTIR",
            fmt(L.sertir_texte, nom, "|r|cffff4444" .. L.rune_classe .. "|r"))
        if popup then popup.data = { node = nodeId, entree = entree } end
        return
    end

    if descripteur.pct then
        -- Une rune de statistique : ce qui compte est la majoration TOTALE
        -- qu'elle portera, cumul compris.
        local deja = ACT.CompterRunes(entree)
        if deja >= RC.RUNES_PAR_SORT then
            sertirBloque = true
            local popup = StaticPopup_Show("SPHERIER_SERTIR",
                fmt(L.sertir_texte, nom, "|r|cffff4444" .. L.rune_max_s .. "|r"))
            if popup then popup.data = { node = nodeId, entree = entree } end
            return
        end
        effet = fmt(L.rune_stat_pose, descripteur.pct * (deja + 1),
                    STAT_LABELS[descripteur.stat] or "?")
    elseif descripteur.sort then
        local nomSort = GetSpellInfo(descripteur.sort)
                        or fmt(L.sort_inconnu, descripteur.sort)
        local deja = ACT.CompterRunes(entree)
        -- Le module refuse la quatrième : autant le dire avant plutôt que de
        -- laisser le joueur l'apprendre par un message d'erreur.
        if deja >= RC.RUNES_PAR_SORT then
            sertirBloque = true
            local popup = StaticPopup_Show("SPHERIER_SERTIR",
                fmt(L.sertir_texte, nom, "|r|cffff4444" .. L.rune_max .. "|r"))
            if popup then popup.data = { node = nodeId, entree = entree } end
            return
        end
        -- Le rang obtenu dépend de ce qui est DÉJÀ serti.
        effet = fmt(L.rune_apprend, nomSort, (descripteur.rang or 0) + deja)
        -- Une rune de talent ne fait rien tant que le talent n'est pas pris :
        -- on annonce le pré-requis AVANT, vert s'il est tenu, rouge sinon — et
        -- dans ce dernier cas on refuse le sertissage, qui ne servirait à rien.
        if descripteur.talent and descripteur.requis and descripteur.requis > 0 then
            local nomRequis = GetSpellInfo(descripteur.requis) or nomSort
            local tenu = ACT.RuneActive(entree)
            sertirBloque = not tenu
            effet = effet .. "|r\n" .. (tenu and "|cff44ff44" or "|cffff4444")
                .. fmt(L.rune_requis, nomRequis) .. "|r"
        end
    else
        effet = fmt("+%d %s", descripteur.montant or 0,
                    STAT_LABELS[descripteur.stat] or "?")
    end
    local popup = StaticPopup_Show("SPHERIER_SERTIR", fmt(L.sertir_texte, nom, effet))
    if popup then popup.data = { node = nodeId, entree = entree } end
end

-- L'épingle DÉTRUIT ce que l'emplacement contient : jamais sans confirmation.
-- Le nombre d'épingles en sac est rappelé ; s'il est nul, le module refusera en
-- rouge, c'est lui qui tient la règle.
function ACT.DemanderEpingle(n)
    if not EstActif(n.id) or ACT.EstVide(n) then return end

    local quoi, modele, rangApres
    if n.kind == 2 then
        quoi = (n.sort and n.sort > 0 and GetSpellInfo(n.sort)) or fmt(L.sort_inconnu, n.sort or 0)
        modele = L.epingle_sort
    else
        local rune, entree = ACT.RuneSertie(n)
        if rune then
            -- Une rune n'a pas de statistique : on la nomme. Et « une rune »
            -- se détruiT au féminin, d'où un modèle de phrase à part.
            quoi, modele = ACT.NomObjet(entree, rune), L.epingle_rune
            -- Ce qui décide vraiment : où l'on retombe. Sans effet, la rune
            -- inerte ne fait retomber personne, on se tait.
            if rune.pct then
                rangApres = rune.pct * max(0, ACT.CompterRunes(entree) - 1)
                modele = L.epingle_rune_pct
            elseif ACT.RuneActive(entree) then
                rangApres = (rune.rang or 1) - 1 + max(0, ACT.CompterRunes(entree) - 1)
                modele = L.epingle_rune_rang
            end
        else
            local stat, montant = ACT.Effectif(n)
            quoi, modele = fmt("+%d %s", montant, STAT_LABELS[stat] or "?"), L.epingle_texte
        end
    end

    local epingles = ACT.CompterEnSac(ACT.EntreeEpingle())
    local popup = StaticPopup_Show("SPHERIER_EPINGLE",
        rangApres and fmt(modele, quoi, rangApres, epingles)
                   or fmt(modele, quoi, epingles))
    if popup then popup.data = n.id end
end

local function ShowTooltip(btn, n)
    local stat, montant, qualite = ACT.Effectif(n)

    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    if n.kind == 1 then
        local rune, entreeRune = ACT.RuneSertie(n)
        if rune and rune.pct then
            GameTooltip:SetText(L.rune_stat_titre,
                RC.SLOT_COLOR[1], RC.SLOT_COLOR[2], RC.SLOT_COLOR[3])
            GameTooltip:AddLine(fmt(L.rune_stat_desc,
                rune.pct * ACT.CompterRunes(entreeRune),
                STAT_LABELS[rune.stat] or "?"), 1, 1, 1, true)
        elseif rune then
            -- MÊME GESTE QUE POUR LES EMPLACEMENTS DE SORT : la rune ajoute un
            -- rang à un sort, encore faut-il savoir lequel fait quoi. Le titre
            -- « Rune » cède la place au nom du sort ; la ligne « Ajoute un rang
            -- à… » reste, c'est elle qui dit ce que la rune, elle, fait.
            local nomSort = GetSpellInfo(rune.sort or 0)
                            or fmt(L.sort_inconnu, rune.sort or 0)
            if GetSpellInfo(rune.sort or 0) then
                GameTooltip:SetHyperlink("spell:" .. rune.sort)
                GameTooltip:AddLine(" ")
            else
                GameTooltip:SetText(L.rune_titre,
                    RC.SLOT_COLOR[1], RC.SLOT_COLOR[2], RC.SLOT_COLOR[3])
            end
            GameTooltip:AddLine(fmt(L.rune_desc, nomSort), 1, 1, 1, true)
            if not ACT.RuneActive(entreeRune) then
                local c = RC.RUNE_INERTE
                GameTooltip:AddLine(rune.talent and L.rune_off
                    or fmt(L.rune_off_r, GetSpellInfo(rune.requis or 0) or nomSort),
                    c[1], c[2], c[3], true)
            end
        else
            GameTooltip:SetText(L.slot, RC.SLOT_COLOR[1], RC.SLOT_COLOR[2], RC.SLOT_COLOR[3])
            GameTooltip:AddLine(L.slot_desc, 0.8, 0.8, 0.8, true)
        end
    elseif n.kind == 2 then
        -- L'INFOBULLE DU SORT LUI-MÊME : coût, portée, incantation, recharge
        -- et description, telles que le client les lit dans son Spell.dbc. On
        -- n'écrivait que le NOM, et le joueur achetait sans savoir quoi.
        --
        -- SetHyperlink REMPLACE tout le contenu de l'infobulle : il passe donc
        -- en premier, les lignes du sphèrier s'ajoutant derrière. C'est bien
        -- lui qu'il faut appeler et pas SetSpellByID, qui n'existe pas en
        -- 3.3.5.
        local nomSort = n.sort and n.sort > 0 and GetSpellInfo(n.sort)
        if nomSort then
            GameTooltip:SetHyperlink("spell:" .. n.sort)
            -- Une ligne vide, sans quoi la phrase du sphèrier se lirait comme
            -- la suite de la description du sort.
            GameTooltip:AddLine(" ")
        else
            -- Sort absent du Spell.dbc du client : mieux vaut l'ancien
            -- affichage qu'une infobulle vide.
            GameTooltip:SetText(L.sort_titre,
                RC.SORT_COLOR[1], RC.SORT_COLOR[2], RC.SORT_COLOR[3])
            GameTooltip:AddLine(fmt(L.sort_inconnu, n.sort or 0), 1, 1, 1, true)
        end
        -- Un sort épinglé reste dans la grille, mais n'est plus appris.
        if EstActif(n.id) and ACT.EstVide(n) then
            GameTooltip:AddLine(L.contenu_oubli, 1, 0.5, 0.1, true)
        else
            GameTooltip:AddLine(L.sort_desc, 0.8, 0.8, 0.8, true)
        end
    elseif not stat then
        GameTooltip:SetText(L.noeud_vide,
            RC.EMPTY_NODE_COLOR[1], RC.EMPTY_NODE_COLOR[2], RC.EMPTY_NODE_COLOR[3])
        GameTooltip:AddLine(EstActif(n.id) and L.vide_actif or L.vide_desc, 0.8, 0.8, 0.8, true)
    else
        local q = RC.QUALITY_COLORS[qualite] or RC.QUALITY_COLORS[1]
        local qual = QUALITES[qualite] or QUALITES[1]
        GameTooltip:SetText(L.noeud, 1, 1, 1)
        GameTooltip:AddLine(fmt(L.pierre, qual and qual.label or "?"), q[1], q[2], q[3], true)
        GameTooltip:AddLine(fmt("+%d %s", montant, STAT_LABELS[stat] or "?"), 0.1, 1, 0.1, true)
    end

    if DEF and DEF.depart == n.id then
        GameTooltip:AddLine(L.depart, 1, 0.82, 0, true)
    end

    GameTooltip:AddLine(" ")
    if EstActif(n.id) then
        GameTooltip:AddLine(L.etat_actif, 0.2, 1, 0.2, true)
        -- Ce que le joueur peut faire ici, maintenant.
        if ACT.PeutSertir(n) then
            GameTooltip:AddLine(n.kind == 1 and L.act_sertir_r or L.act_sertir, 1, 0.82, 0, true)
            GameTooltip:AddLine(L.act_lacher, 0.6, 0.6, 0.6, true)
        elseif not ACT.EstVide(n) then
            GameTooltip:AddLine(L.act_epingle, 1, 0.82, 0, true)
        end
    else
        local chemin = CheminVers(n.id)
        if not chemin then
            GameTooltip:AddLine(L.inaccessible, 0.6, 0.6, 0.6, true)
        else
            local cout = CoutChemin(chemin)
            local assez = ETAT and ETAT.disponibles >= cout
            local texte = (#chemin == 1) and fmt(L.etat_cout, cout)
                or fmt(L.etat_chemin, #chemin, cout)
            GameTooltip:AddLine(texte,
                assez and 1 or 1, assez and 0.82 or 0.25, assez and 0 or 0.25, true)
        end
    end
    GameTooltip:Show()
end

StaticPopupDialogs["SPHERIER_ACHAT"] = {
    text = "%s",
    button1 = L.acheter,
    button2 = L.annuler,
    OnAccept = function(self, data)
        AIO.Handle("SpherierJoueur", "AcheterChemin", data)
    end,
    -- Couvre les trois sorties : achat, annulation, Échap.
    OnHide = function()
        if achatEnCours then
            achatEnCours = nil
            Rebuild()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- Tous les gestes de la grille passent par ici.
--
-- Emplacement NON acheté : le chemin le plus court depuis le domaine actif est
-- calculé, son coût total affiché, et l'achat — confirmé — se fait d'un coup.
-- Emplacement acheté : clic gauche pour sertir (pierre du curseur, sinon la
-- liste des pierres du sac), clic droit pour l'épingle. Un emplacement de sort
-- vidé par l'épingle se réapprend d'un clic, au coût habituel.
local function OnNodeClick(n, bouton, btn)
    -- Objet pris en main depuis un sac : il prime sur tout le reste. Le clic
    -- droit le repose, le clic gauche l'applique là où c'est possible.
    if ACT.enMain then
        if bouton == "RightButton" or not ACT.CibleValide(n) then
            ACT.Reposer()
        elseif ACT.enMain.epingle then
            ACT.DemanderEpingle(n)
        else
            ACT.DemanderSertissage(n.id, ACT.enMain.entree)
        end
        return
    end

    if EstActif(n.id) then
        if bouton == "RightButton" then
            ACT.DemanderEpingle(n)
        elseif ACT.PeutSertir(n) then
            local entree = ACT.PierreDuCurseur()
            if entree then
                ClearCursor()
                ACT.DemanderSertissage(n.id, entree)
            else
                ACT.OuvrirChoix(btn, n)
            end
        elseif n.kind == 2 and ACT.EstVide(n) then
            local cout = CoutTranche(ETAT.nbActifs or 0)
            if ETAT.disponibles < cout then
                AIO.Handle("SpherierJoueur", "Refuser")
                return
            end
            local popup = StaticPopup_Show("SPHERIER_ACHAT", fmt(L.confirme_sort, cout))
            if popup then popup.data = { n.id } end
        end
        return
    end

    if bouton == "RightButton" then return end

    local chemin = CheminVers(n.id)
    if not chemin then return end
    local cout = CoutChemin(chemin)

    -- Pas les moyens : on ne propose même pas l'achat. Le refus est demandé au
    -- serveur plutôt qu'affiché ici, pour qu'il emprunte le même canal rouge
    -- que tous les autres refus du module — un seul texte, un seul rendu.
    if not ETAT or ETAT.disponibles < cout then
        AIO.Handle("SpherierJoueur", "Refuser")
        return
    end

    local texte = (#chemin == 1) and fmt(L.confirme, cout)
        or fmt(L.confirme_chemin, #chemin, cout)
    local popup = StaticPopup_Show("SPHERIER_ACHAT", texte)
    if not popup then return end
    popup.data = chemin

    achatEnCours = {}
    for _, id in ipairs(chemin) do achatEnCours[id] = true end
    Rebuild()
end

-- Réservoir d'étincelles (2026-09-06) : une étincelle court sur chaque liaison
-- ACTIVE MONTRÉE ; elle est prise quand la liaison entre dans la fenêtre et
-- rendue quand elle en sort. Vitesse et sens sont tirés à la création et
-- gardés d'un usage à l'autre.
local function PrendreEtincelle()
    local s = table.remove(UI.etincellesLibres)
    if not s then
        local tex = UI.canvas:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(RC.SPARK_TEXTURE)
        tex:SetBlendMode("ADD")
        tex:SetWidth(RC.SPARK_SIZE)
        tex:SetHeight(RC.SPARK_SIZE)
        local v = RC.SPARK_VMIN + math.random() * (RC.SPARK_VMAX - RC.SPARK_VMIN)
        if math.random(2) == 1 then v = -v end
        s = { tex = tex, t = math.random(), v = v }
    end
    s.tex:Show()
    local actives = UI.etincellesActives
    actives[#actives + 1] = s
    return s
end

local function RendreEtincelle(s)
    s.tex:Hide()
    local actives = UI.etincellesActives
    for i = #actives, 1, -1 do
        if actives[i] == s then
            actives[i] = actives[#actives]
            actives[#actives] = nil
            break
        end
    end
    UI.etincellesLibres[#UI.etincellesLibres + 1] = s
end

-- Récapitulatif : pour chaque statistique, ce que le joueur a DÉJÀ (somme des
-- pierres serties dans ses emplacements actifs) et ce que la grille entière
-- pourrait lui donner (somme de toutes les pierres qu'elle contient).
local function CalculerTotaux()
    local brut, total = {}, {}
    if not DEF then return brut, total, {}, {} end

    -- Le potentiel de la grille tient compte du contenu de compte : un nœud
    -- vidé ne promet plus rien, une pierre sertie promet la sienne.
    for _, n in ipairs(DEF.nodes) do
        local stat, montant = ACT.Effectif(n)
        if stat and montant and montant ~= 0 then
            total[stat] = (total[stat] or 0) + montant
        end
    end
    for _, c in pairs(ETAT and ETAT.contenu or {}) do
        if c.stat and c.montant then
            brut[c.stat] = (brut[c.stat] or 0) + c.montant
        end
    end

    -- Une rune de statistique majore CE QUE LA GRILLE DONNE : elle s'applique
    -- sur la somme des pierres, jamais sur une valeur brute du personnage.
    -- Même calcul que le module, plafond des trois runes compris — sans quoi
    -- le panneau annoncerait autre chose que la feuille de personnage.
    local nb, pct = {}, {}
    for _, n in ipairs(DEF.nodes) do
        local entree = ETAT and ETAT.brut and ETAT.brut[n.id]
        local r = (entree and entree ~= 0) and CAT.runesStat[entree] or nil
        if r then
            nb[r.stat] = (nb[r.stat] or 0) + 1
            if nb[r.stat] <= RC.RUNES_PAR_SORT then
                pct[r.stat] = (pct[r.stat] or 0) + r.pct
            end
        end
    end

    -- Le gain est chiffré, mais il n'entre PAS dans la ligne de la
    -- statistique : celle-ci dit ce que les pierres donnent, la ligne de la
    -- rune dit ce que le pourcentage y ajoute. Le compter des deux côtés
    -- ferait lire « 55 » là où la grille en pose 50.
    local gain = {}
    for cle, v in pairs(brut) do
        gain[cle] = floor(v * (pct[cle] or 0) / 100)
    end
    return brut, total, pct, gain
end

-- Les runes serties, regroupées par sort : trois runes d'une même famille ne
-- font pas trois lignes mais trois rangs. Le catalogue donne le rang qu'accorde
-- la PREMIÈRE ; les suivantes montent d'autant.
local function ListerRunes(gains)
    local lignes, inertes, par, ordre = {}, {}, {}, {}
    if not (DEF and ETAT and ETAT.brut) then return lignes, inertes end
    for _, n in ipairs(DEF.nodes) do
        local entree = ETAT.brut[n.id]
        local r = (entree and entree ~= 0)
                  and (CAT.runes[entree] or CAT.runesStat[entree]) or nil
        if r then
            if not par[entree] then
                par[entree] = { r = r, nb = 0, actif = ACT.RuneActive(entree) }
                ordre[#ordre + 1] = entree
            end
            par[entree].nb = par[entree].nb + 1
        end
    end
    -- Deux listes distinctes : les actives sous leur titre, les inertes sous le
    -- leur. Une rune dont le talent n'est plus pris ne donne aucun rang, la
    -- ranger parmi les actives serait mentir.
    for _, entree in ipairs(ordre) do
        local e = par[entree]
        local r = e.r
        local vus = min(e.nb, RC.RUNES_PAR_SORT)
        if r.pct then
            -- La forme demandée : le pourcentage cumulé, puis entre
            -- parenthèses ce qu'il rapporte réellement.
            lignes[#lignes + 1] = {
                texte = fmt(L.rune_stat_ligne, ACT.NomObjet(entree, r),
                            r.pct * vus, (gains and gains[r.stat]) or 0),
                couleur = RC.RUNE_ACTIVE, hl = RC.RECAP_HL,
                cle = entree, inerte = false }
        else
            local nom = GetSpellInfo(r.sort) or fmt(L.sort_inconnu, r.sort or 0)
            if e.actif then
                lignes[#lignes + 1] = {
                    texte = fmt(L.rune_ligne, nom, (r.rang or 1) + vus - 1),
                    couleur = RC.RUNE_ACTIVE, hl = RC.RECAP_HL,
                    cle = entree, inerte = false }
            else
                inertes[#inertes + 1] = {
                    texte = fmt(r.talent and L.rune_inerte_t or L.rune_inerte, nom),
                    couleur = RC.RUNE_INERTE, hl = RC.RECAP_HL_INERTE,
                    cle = entree, inerte = true }
            end
        end
    end
    return lignes, inertes
end

-- La spécialisation courante, c'est l'arbre où le joueur a mis le plus de
-- points. `GetTalentTabInfo` rend jusqu'au NOM DE FICHIER du décor : rien à
-- coder en dur, et l'image suit un changement d'arbre sans qu'on s'en mêle.
local function DecorSpecialisation()
    if not GetTalentTabInfo then return nil end
    local meilleur, points = nil, -1
    for i = 1, (GetNumTalentTabs and GetNumTalentTabs() or 3) do
        local _, _, depenses, fichier = GetTalentTabInfo(i)
        if fichier and (depenses or 0) > points then
            meilleur, points = fichier, depenses or 0
        end
    end
    return meilleur
end

-- Couvrir le panneau SANS DÉFORMER : l'image est mise à l'échelle par la
-- hauteur, et l'on ne montre qu'une bande verticale centrée. Le panneau étant
-- étroit, cette bande tombe le plus souvent tout entière dans les quartiers de
-- gauche — les autres se cachent alors d'eux-mêmes.
local function PoserFondSpec()
    if not (UI and UI.fond and UI.recapCadre) then return end
    local decor = DecorSpecialisation()
    local larg, haut = UI.recapCadre:GetWidth(), UI.recapCadre:GetHeight()
    if not (decor and larg and haut) or larg <= 0 or haut <= 0 then
        for _, t in pairs(UI.fond) do t:Hide() end
        return
    end

    local bande = min(1, (larg / haut) / RC.TALENT_RATIO)
    local u0, u1 = 0.5 - bande / 2, 0.5 + bande / 2

    for _, q in ipairs(RC.TALENT_QUARTIERS) do
        local t = UI.fond[q.coin]
        local a, b = max(q.u0, u0), min(q.u1, u1)
        if b <= a then
            t:Hide()
        else
            t:SetTexture(fmt(RC.TALENT_CHEMIN, decor, q.coin))
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", UI.recapCadre, "TOPLEFT",
                       (a - u0) / bande * larg, -q.v0 * haut)
            t:SetWidth((b - a) / bande * larg)
            t:SetHeight((q.v1 - q.v0) * haut)
            t:SetTexCoord((a - q.u0) / (q.u1 - q.u0), (b - q.u0) / (q.u1 - q.u0),
                          0, q.vmax)
            t:Show()
        end
    end
end

local function MettreAJourRecap()
    if not UI or not UI.recapLignes then return end
    local acquis, total, _pct, gains = CalculerTotaux()

    -- Les sorts de classe d'abord : ce que la grille apprend à CE personnage.
    -- Appris (l'emplacement porte le sort) en vert, pas encore en rouge.
    local y = -8
    UI.sortTitre:ClearAllPoints()
    UI.sortTitre:SetPoint("TOPLEFT", 10, y)
    y = y - 18
    local poseS = 0
    if DEF then
        for _, n in ipairs(DEF.nodes) do
            if n.kind == 2 and (n.sort or 0) > 0 and poseS < #UI.sortLignes then
                poseS = poseS + 1
                local ligne = UI.sortLignes[poseS]
                local appris = ETAT and ETAT.brut and (ETAT.brut[n.id] or 0) ~= 0
                local c = appris and RC.RECAP_TXT_PLEIN or RC.RUNE_INERTE
                ligne.nom:SetText(GetSpellInfo(n.sort) or fmt(L.sort_inconnu, n.sort))
                ligne.nom:SetTextColor(c[1], c[2], c[3])
                if ligne.cadre.noeud ~= n.id then ligne.hl:Hide() end
                ligne.cadre.noeud = n.id
                ligne.cadre:ClearAllPoints()
                ligne.cadre:SetPoint("TOPLEFT", 6, y)
                ligne.cadre:SetPoint("TOPRIGHT", -6, y)
                ligne.cadre:Show()
                y = y - RC.RECAP_H
            end
        end
    end
    for k = poseS + 1, #UI.sortLignes do
        UI.sortLignes[k].cadre.noeud = nil
        UI.sortLignes[k].hl:Hide()
        UI.sortLignes[k].cadre:Hide()
    end
    if poseS == 0 then
        UI.sortVide:ClearAllPoints()
        UI.sortVide:SetPoint("TOPLEFT", 10, y)
        UI.sortVide:Show()
        y = y - RC.RECAP_H
    else
        UI.sortVide:Hide()
    end

    -- Puis les statistiques, sous leur titre et leur légende.
    y = y - 10
    UI.recapTitre:ClearAllPoints()
    UI.recapTitre:SetPoint("TOPLEFT", 10, y)
    y = y - 14
    UI.recapAide:ClearAllPoints()
    UI.recapAide:SetPoint("TOPLEFT", 10, y)
    y = y - 16

    -- Une statistique que la grille ne porte pas du tout n'est pas affichée.
    -- Les lignes restantes sont réempilées à la suite, sans trou.
    for _, cle in ipairs(STAT_ORDRE) do
        local ligne = UI.recapLignes[cle]
        -- `acquis` est ce que les PIERRES donnent, `gains` ce que les runes de
        -- statistique y ajoutent. Le total affiché les additionne, mais la
        -- couleur ne regarde que les pierres : une rune ne fait pas une grille
        -- complète, elle la dépasse.
        local a, g, t = acquis[cle] or 0, gains[cle] or 0, total[cle] or 0
        if ligne and t > 0 then
            ligne.valeur:SetText(fmt("%d / %d", a + g, t))
            local c = RC.RECAP_TXT
            if a >= t then
                c = (g > 0) and RC.RECAP_TXT_DEPASSE or RC.RECAP_TXT_PLEIN
            end
            ligne.nom:SetTextColor(c[1], c[2], c[3])
            ligne.valeur:SetTextColor(c[1], c[2], c[3])
            ligne.cadre:ClearAllPoints()
            ligne.cadre:SetPoint("TOPLEFT", 6, y)
            ligne.cadre:SetPoint("TOPRIGHT", -6, y)
            ligne.cadre:Show()
            y = y - RC.RECAP_H
        elseif ligne then
            ligne.cadre:Hide()
        end
    end

    -- La section des runes suit les lignes réellement affichées. Deux titres :
    -- « Runes actives » toujours, « Runes inactives » seulement s'il y en a.
    y = y - 12
    UI.runeTitre:ClearAllPoints()
    UI.runeTitre:SetPoint("TOPLEFT", 10, y)
    y = y - 16

    -- Les runes se déduisent de ce que les slots portent : le serveur envoie
    -- déjà l'entrée sertie dans `brut` et le catalogue dans `runes`.
    local actives, inertes = ListerRunes(gains)
    local pose = 0

    local function Poser(r)
        pose = pose + 1
        local ligne = UI.runeLignes[pose]
        if not ligne then return end
        ligne.nom:SetText(r.texte)
        ligne.nom:SetTextColor(r.couleur[1], r.couleur[2], r.couleur[3])
        ligne.hl:SetTexture(r.hl[1], r.hl[2], r.hl[3], 1)
        if ligne.cadre.cle ~= r.cle then ligne.hl:Hide() end
        ligne.cadre.cle, ligne.cadre.inerte = r.cle, r.inerte
        ligne.cadre:ClearAllPoints()
        ligne.cadre:SetPoint("TOPLEFT", 6, y)
        ligne.cadre:SetPoint("TOPRIGHT", -6, y)
        ligne.cadre:Show()
        y = y - RC.RECAP_H
    end

    for _, r in ipairs(actives) do Poser(r) end
    -- SetShown n'existe pas en 3.3.5.
    if #actives == 0 then
        UI.runeVide:ClearAllPoints()
        UI.runeVide:SetPoint("TOPLEFT", 10, y)
        UI.runeVide:Show()
        y = y - RC.RECAP_H
    else
        UI.runeVide:Hide()
    end

    if #inertes > 0 then
        y = y - 8
        UI.runeTitreInerte:ClearAllPoints()
        UI.runeTitreInerte:SetPoint("TOPLEFT", 10, y)
        UI.runeTitreInerte:Show()
        y = y - 16
        for _, r in ipairs(inertes) do Poser(r) end
    else
        UI.runeTitreInerte:Hide()
    end

    for k = pose + 1, #UI.runeLignes do
        UI.runeLignes[k].cadre.cle = nil
        UI.runeLignes[k].hl:Hide()
        UI.runeLignes[k].cadre:Hide()
    end
end

local pulsePhase = 0

local function AvancerPulsations(elapsed)
    local liste = UI.pulses
    local n = liste and #liste or 0
    if n == 0 then return end
    pulsePhase = pulsePhase + elapsed
    local a = RC.PULSE_MIN + (RC.PULSE_MAX - RC.PULSE_MIN)
        * (0.5 + 0.5 * sin(pulsePhase * 2 * pi / RC.PULSE_PERIODE))
    for i = 1, n do liste[i]:SetAlpha(a) end
end

local function AvancerEtincelles(elapsed)
    local liste = UI.etincellesActives
    for i = 1, #liste do
        local s = liste[i]
        local t = s.t + s.v * elapsed
        if t >= 1 then t = t - 1 elseif t < 0 then t = t + 1 end
        s.t = t
        local x, y
        if s.arc then
            local ang = s.a0 + s.da * t
            x, y = s.cx + s.r * cos(ang), s.cy + s.r * sin(ang)
        else
            x, y = s.x0 + s.dx * t, s.y0 + s.dy * t
        end
        s.tex:SetPoint("CENTER", UI.canvas, "BOTTOMLEFT", x, y)
    end
end

-- LE RECTANGLE VISIBLE, en pixels du canevas (2026-09-05). La grille commune
-- compte 2 442 emplacements : habiller chacun à chaque reconstruction mettait
-- le client à genoux. On ne rend que ce qui tombe dans la fenêtre, avec une
-- marge, et l'on reconstruit quand la fenêtre a bougé d'assez.
--
-- Ici le défilement se compte DÉJÀ en pixels de canevas (le glissement divise
-- par le zoom, voir plus bas) ; la demi-fenêtre vient de DemiVue(). L'axe y du
-- canevas monte, celui du défilement descend : retournement sur la hauteur.
local CULL_MARGE = 160
local dernierCull = { h = 0, v = 0 }
local DemiVue

local function RectVisible()
    local vp, canvas = UI.viewport, UI.canvas
    local demiW, demiH = DemiVue()
    if demiW < 1 or demiH < 1 then
        return -math.huge, -math.huge, math.huge, math.huge
    end
    local sx, sy = vp:GetHorizontalScroll(), vp:GetVerticalScroll()
    local ch = canvas:GetHeight()
    return sx - CULL_MARGE, ch - sy - 2 * demiH - CULL_MARGE,
           sx + 2 * demiW + CULL_MARGE, ch - sy + CULL_MARGE
end

local function Dedans(rect, x, y)
    return x >= rect[1] and x <= rect[3] and y >= rect[2] and y <= rect[4]
end

-- ---------------------------------------------------------------------------
-- Rendu VIRTUALISÉ (2026-09-06)
-- ---------------------------------------------------------------------------
-- La grille commune compte 2 450 emplacements et autant de liaisons. Rien n'est
-- créé pour ce qui est hors fenêtre : un emplacement qui entre reçoit un bouton
-- d'un réservoir et le rend en sortant ; une liaison qui entre prend sa
-- texture (et son étincelle si elle est active), et les rend en sortant.
--   Placer()   : géométrie — positions, boîtes des liaisons, cases de 256 px.
--   Cull()     : à chaque image de glissement, ce qui entre et ce qui sort.
--   Restyler() : changement d'état ou survol — rhabille ce qui est montré.
--   Rebuild()  : le point d'entrée historique — géométrie si elle a changé,
--                sinon filtre puis rhabillage.

local CASE = 256
local visActuel = { 0, 0, 0, 0 }
local montresN, montresE = {}, {}         -- indice → bouton ; liaison → vrai
local nouveauxN, nouveauxE = {}, {}       -- tampons du filtre, réutilisés
local dernierFiltre = { h = nil, v = nil, z = nil }
local cleGeometrie = nil

local function CleCase(x, y)
    return floor(x / CASE) * 65536 + floor(y / CASE)
end

-- Un bouton neuf, habillé de toutes ses textures ; il servira à bien des
-- emplacements au fil du glissement. Ses scripts lisent self.node.
local function NouveauBouton()
    local canvas = UI.canvas
    local btn
    btn = CreateFrame("Button", nil, canvas)
    btn:SetWidth(RC.NODE_SIZE)
    btn:SetHeight(RC.NODE_SIZE)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetFrameLevel(canvas:GetFrameLevel() + 5)

    btn.disc = btn:CreateTexture(nil, "BACKGROUND")
    btn.disc:SetTexture(RC.NODE_DISC_TEXTURE)
    btn.disc:SetBlendMode("ADD")
    btn.disc:SetWidth(RC.NODE_DISC_SIZE)
    btn.disc:SetHeight(RC.NODE_DISC_SIZE)
    btn.disc:SetPoint("CENTER")
    btn.disc:SetVertexColor(RC.NODE_DISC_COLOR[1], RC.NODE_DISC_COLOR[2], RC.NODE_DISC_COLOR[3])

    btn.ring = btn:CreateTexture(nil, "OVERLAY")
    btn.ring:SetTexture(RC.NODE_RING_TEXTURE)
    btn.ring:SetBlendMode("ADD")
    btn.ring:SetWidth(RC.NODE_RING_SIZE)
    btn.ring:SetHeight(RC.NODE_RING_SIZE)
    btn.ring:SetPoint("CENTER")

    btn.hole = btn:CreateTexture(nil, "BACKGROUND")
    btn.hole:SetTexture(RC.SOCKET_SHEET)
    btn.hole:SetTexCoord(RC.SOCKET_HOLE_COORDS[1], RC.SOCKET_HOLE_COORDS[2],
        RC.SOCKET_HOLE_COORDS[3], RC.SOCKET_HOLE_COORDS[4])
    btn.hole:SetWidth(72 * RC.SLOT_SCALE)
    btn.hole:SetHeight(74 * RC.SLOT_SCALE)
    btn.hole:SetPoint("CENTER")

    btn.socket = btn:CreateTexture(nil, "BORDER")
    btn.socket:SetTexture(RC.SOCKET_SHEET)
    btn.socket:SetTexCoord(RC.SOCKET_FRAME_COORDS[1], RC.SOCKET_FRAME_COORDS[2],
        RC.SOCKET_FRAME_COORDS[3], RC.SOCKET_FRAME_COORDS[4])
    btn.socket:SetWidth(57 * RC.SLOT_SCALE)
    btn.socket:SetHeight(52 * RC.SLOT_SCALE)
    btn.socket:SetPoint("CENTER")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetWidth(RC.ICON_SIZE_NODE)
    btn.icon:SetHeight(RC.ICON_SIZE_NODE)
    btn.icon:SetPoint("CENTER")

    -- Cadre posé sur le bord de l'icône ronde (méthode Paragon).
    btn.iconRim = btn:CreateTexture(nil, "OVERLAY")
    btn.iconRim:SetTexture(RC.FRAME_SHEET)
    btn.iconRim:SetTexCoord(RC.FRAME_COORDS[1], RC.FRAME_COORDS[2],
        RC.FRAME_COORDS[3], RC.FRAME_COORDS[4])
    btn.iconRim:SetWidth(RC.FRAME_SIZE)
    btn.iconRim:SetHeight(RC.FRAME_SIZE)
    btn.iconRim:SetPoint("CENTER")

    -- Le cadre de sort du grimoire : assiette parchemin sous l'icône,
    -- cadre orné par-dessus (or ou brun, posé au rendu).
    btn.sbFond = btn:CreateTexture(nil, "BORDER")
    btn.sbFond:SetTexture(RC.SB_SHEET)
    btn.sbFond:SetTexCoord(RC.SB_FOND_COORDS[1], RC.SB_FOND_COORDS[2],
        RC.SB_FOND_COORDS[3], RC.SB_FOND_COORDS[4])
    btn.sbFond:SetWidth(RC.SB_FOND_SIZE)
    btn.sbFond:SetHeight(RC.SB_FOND_SIZE)
    btn.sbFond:SetPoint("CENTER")

    btn.sbCadre = btn:CreateTexture(nil, "OVERLAY")
    btn.sbCadre:SetTexture(RC.SB_SHEET)
    btn.sbCadre:SetPoint("CENTER")

    -- Halo de la statistique survolée dans le récapitulatif.
    btn.statHL = {}
    for k = 1, #RC.STATHL_SIZES do
        local t = btn:CreateTexture(nil, "OVERLAY")
        t:SetTexture(RC.NODE_RING_TEXTURE)
        t:SetBlendMode("ADD")
        t:SetWidth(RC.STATHL_SIZES[k])
        t:SetHeight(RC.STATHL_SIZES[k])
        t:SetPoint("CENTER")
        t:SetVertexColor(RC.STATHL_COLOR[1], RC.STATHL_COLOR[2], RC.STATHL_COLOR[3])
        t:SetAlpha(RC.STATHL_ALPHA)
        t:Hide()
        btn.statHL[k] = t
    end

    -- Contour blanc d'un achat en attente : par-dessus tout le reste,
    -- son alpha est piloté par la pulsation.
    btn.pulse = btn:CreateTexture(nil, "OVERLAY")
    btn.pulse:SetTexture(RC.NODE_RING_TEXTURE)
    btn.pulse:SetBlendMode("ADD")
    btn.pulse:SetWidth(RC.PULSE_SIZE)
    btn.pulse:SetHeight(RC.PULSE_SIZE)
    btn.pulse:SetPoint("CENTER")
    btn.pulse:Hide()

    btn.departRing = btn:CreateTexture(nil, "OVERLAY")
    btn.departRing:SetTexture(RC.NODE_RING_TEXTURE)
    btn.departRing:SetBlendMode("ADD")
    btn.departRing:SetWidth(RC.DEPART_RING_SIZE)
    btn.departRing:SetHeight(RC.DEPART_RING_SIZE)
    btn.departRing:SetPoint("CENTER")
    btn.departRing:SetVertexColor(RC.DEPART_COLOR[1], RC.DEPART_COLOR[2], RC.DEPART_COLOR[3])

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnEnter", function(self)
        if self.node then ShowTooltip(self, self.node) end
        -- Le survol dit au curseur si l'emplacement peut recevoir ce
        -- qu'on tient : franc si oui, barré sinon.
        ACT.survol = self.node
        ACT.MajCurseur()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ACT.survol = nil
        ACT.MajCurseur()
    end)
    btn:SetScript("OnClick", function(self, bouton)
        if self.node then OnNodeClick(self.node, bouton, self) end
    end)
    -- Pierre lâchée depuis un sac : même chemin que le clic, curseur
    -- chargé — c'est le geste naturel du jeu pour sertir.
    btn:SetScript("OnReceiveDrag", function(self)
        if not self.node or not ACT.PeutSertir(self.node) then return end
        local entree = ACT.PierreDuCurseur()
        if entree then
            ClearCursor()
            ACT.DemanderSertissage(self.node.id, entree)
        end
    end)

    return btn
end

-- Le halo d'un emplacement selon les survols de la barre latérale : une
-- statistique (toutes les pierres qui la portent), une rune (les slots qui la
-- portent, en rouge si inerte), un sort (son emplacement).
local function PoserHalo(btn, n, eStat)
    local halo, haloC = false, RC.STATHL_COLOR
    if runeSurvolee then
        local r, entreeRune = ACT.RuneSertie(n)
        if r and entreeRune == runeSurvolee then
            halo = true
            if runeInerte then haloC = RC.RUNE_INERTE end
        end
    elseif sortSurvole and sortSurvole == n.id then
        halo = true
    elseif statSurvolee and eStat == statSurvolee then
        halo = true
    end
    for k = 1, #btn.statHL do
        if halo then
            btn.statHL[k]:SetVertexColor(haloC[1], haloC[2], haloC[3])
            btn.statHL[k]:Show()
        else
            btn.statHL[k]:Hide()
        end
    end
end

-- Au survol d'une ligne de la barre latérale, seuls les halos changent : on ne
-- rhabille pas tout ce qui est montré.
local function RestylerHalos()
    for _, btn in pairs(montresN) do
        local n = btn.node
        if n then PoserHalo(btn, n, (ACT.Effectif(n))) end
    end
end

-- L'habillage d'un emplacement selon l'état du personnage et les survols.
local function Habiller(btn, n)
    local tint = 1
    if not EstActif(n.id) then
        tint = EstAchetable(n.id) and RC.DIM_ACHETABLE or RC.DIM_INACCESSIBLE
    end

    -- Ce que l'emplacement porte vraiment : la pierre d'origine tant qu'il
    -- n'est pas acheté, son contenu réel ensuite.
    local eStat, _, eQualite = ACT.Effectif(n)

    -- Survol d'une ligne du récapitulatif : ce qu'elle désigne s'entoure
    -- d'un halo. Pour une statistique, toutes les pierres qui la portent,
    -- achetées ou non ; pour une rune, les slots qui la portent — en rouge
    -- si elle est inerte, la couleur disant déjà qu'elle ne donne rien.
    PoserHalo(btn, n, eStat)

    -- L'emplacement d'un achat en attente garde son état : seul son
    -- contour blanc pulse pour désigner ce qui va être débloqué.
    if achatEnCours and achatEnCours[n.id] then
        btn.pulse:Show()
        btn.pulseOn = true
    else
        btn.pulse:Hide()
        btn.pulseOn = false
    end

    if n.kind == 1 then
        btn.disc:Hide()
        btn.ring:Hide()
        btn.iconRim:Hide()
        btn.sbFond:Hide()
        btn.sbCadre:Hide()
        btn.hole:Show()
        btn.socket:Show()
        btn.socket:SetVertexColor(tint, tint, tint)
        btn.hole:SetAlpha(tint < 1 and (tint < 0.5 and 0.20 or 0.6) or 1)

        -- Une rune sertie se voit : elle prend l'icône du sort qu'elle
        -- améliore et se pose dans la châsse, comme une gemme. Carrée,
        -- donc sans masque de portrait — et ne JAMAIS mêler les deux.
        local rune, entreeRune = ACT.RuneSertie(n)
        if rune then
            -- Une rune de rang prend l'icône de son sort, une rune de
            -- statistique celle de sa statistique — la même que les
            -- pierres, relevée sur la grille.
            local path
            if rune.pct then
                path = CAT.iconeParStat[rune.stat]
            else
                local _, _, icone = GetSpellInfo(rune.sort or 0)
                path = icone
            end
            path = path or "Interface\\Icons\\INV_Misc_QuestionMark"
            if btn.iconPath ~= path or btn.iconMode ~= "carre" then
                btn.iconPath, btn.iconMode = path, "carre"
                btn.icon:SetTexture(path)
                btn.icon:SetTexCoord(0, 1, 0, 1)
            end
            btn.icon:SetWidth(RC.ICON_SIZE_RUNE)
            btn.icon:SetHeight(RC.ICON_SIZE_RUNE)
            btn.icon:Show()

            -- Inerte : le talent n'est plus pris, la rune reste en place et
            -- ne donne plus rien. L'emplacement ENTIER vire au rouge —
            -- l'icone et la chasse qui la tient. Pas d'anneau en plus : la
            -- couleur dit deja tout, et un cercle alourdirait la grille.
            if ACT.RuneActive(entreeRune) then
                btn.icon:SetVertexColor(tint, tint, tint)
            else
                local c = RC.RUNE_INERTE
                btn.icon:SetVertexColor(c[1] * tint, c[2] * tint, c[3] * tint)
                btn.socket:SetVertexColor(c[1] * tint, c[2] * tint, c[3] * tint)
            end
        else
            btn.icon:Hide()
        end
    else
        btn.hole:Hide()
        btn.socket:Hide()

        -- Icône : ronde (masque de portrait) pour les pierres, CARRÉE
        -- pour les sorts — le cadre du grimoire encadre un carré. Un
        -- nœud vide reçoit un disque opaque sombre découpé rond — les
        -- liaisons ne se voient pas au travers.
        local path, plug, carre
        if n.kind == 2 then
            local _, _, icone = GetSpellInfo(n.sort or 0)
            path, carre = icone or "Interface\\Icons\\INV_Misc_QuestionMark", true
        elseif eStat then
            -- L'icône suit la pierre RÉELLEMENT portée : celle de la
            -- définition, ou celle de la statistique sertie depuis.
            -- L'ICÔNE RONDE EST CUITE EN FICHIER (gen_icones_rondes.py), une par
            -- statistique : plus de masque au vol. Carrée pour le moteur.
            path, carre = RC.ART_DIR .. "rond_" .. eStat, true
        else
            path, plug = RC.PLUG_TEXTURE, true
        end
        btn.icon:Show()
        local mode = carre and "carre" or "rond"
        if btn.iconPath ~= path or btn.iconMode ~= mode then
            btn.iconPath, btn.iconMode = path, mode
            if carre or not SetPortraitToTexture then
                btn.icon:SetTexture(path)
                btn.icon:SetTexCoord(0, 1, 0, 1)
            else
                -- Ne JAMAIS appeler SetTexCoord ensuite : le moteur perd
                -- alors son masque circulaire et l'icône redevient carrée.
                SetPortraitToTexture(btn.icon, path)
            end
        end

        if n.kind == 2 then
            -- Le cadre du grimoire remplace entièrement le cercle ; brun
            -- « non appris » tant que le sort n'est pas actif.
            btn.disc:Hide()
            btn.ring:Hide()
            btn.iconRim:Hide()
            btn.icon:SetWidth(RC.ICON_SIZE_SORT)
            btn.icon:SetHeight(RC.ICON_SIZE_SORT)
            HabillerCadreSort(btn, EstActif(n.id), tint, tint, tint)
        else
            btn.disc:Show()
            btn.ring:Show()
            btn.iconRim:Show()
            btn.iconRim:SetVertexColor(tint, tint, tint)
            btn.icon:SetWidth(RC.ICON_SIZE_NODE)
            btn.icon:SetHeight(RC.ICON_SIZE_NODE)
            btn.sbFond:Hide()
            btn.sbCadre:Hide()

            local c
            if not eStat then
                c = RC.EMPTY_NODE_COLOR
            else
                c = RC.QUALITY_COLORS[eQualite] or RC.QUALITY_COLORS[1]
            end
            btn.ring:SetVertexColor(c[1] * tint, c[2] * tint, c[3] * tint)
        end

        if plug then
            btn.icon:SetVertexColor(RC.PLUG_COLOR[1], RC.PLUG_COLOR[2], RC.PLUG_COLOR[3])
        else
            btn.icon:SetVertexColor(tint, tint, tint)
        end
    end

    if DEF.depart == n.id then btn.departRing:Show() else btn.departRing:Hide() end
    btn:Show()
end

local function RendreTexture(t)
    if not t then return end
    t:Hide()
    t:ClearAllPoints()
    local pool = UI.linePool
    pool.free[#pool.free + 1] = t
end

local function CouleurLiaison(it)
    local actA, actB = EstActif(it.a.id), EstActif(it.b.id)
    if actA and actB then return RC.EDGE_ACTIVE, true end
    if actA or actB then return RC.EDGE_FRONT, false end
    return RC.EDGE_OFF, false
end

-- Liaison que l'achat en attente va activer : ses deux bouts seront actifs,
-- et l'un au moins fait partie de l'achat.
local function LiaisonPulse(it)
    if not achatEnCours then return false end
    local achatA, achatB = achatEnCours[it.a.id], achatEnCours[it.b.id]
    if not (achatA or achatB) then return false end
    return (EstActif(it.a.id) or achatA) and (EstActif(it.b.id) or achatB)
end

local function TracerLiaison(it, col)
    local canvas, pool = UI.canvas, UI.linePool
    if it.arc then
        return DrawClusterArc(canvas, pool, it.ax, it.ay, it.bx, it.by, it.ccx, it.ccy, it.ring, col)
    end
    return DrawSegment(canvas, pool, it.ax, it.ay, it.bx, it.by, RC.EDGE_THICK, col)
end

local function PoserEtincelle(it)
    local s = PrendreEtincelle()
    it.etincelle = s
    if it.arc then
        -- L'étincelle suit l'arc, pas la corde : centre, rayon et angle
        -- parcouru par le plus court chemin.
        local a0 = math.atan2(it.ay - it.ccy, it.ax - it.ccx)
        local a1 = math.atan2(it.by - it.ccy, it.bx - it.ccx)
        local da = a1 - a0
        while da >  pi do da = da - 2 * pi end
        while da < -pi do da = da + 2 * pi end
        s.arc, s.cx, s.cy = true, it.ccx, it.ccy
        s.r  = sqrt((it.ax - it.ccx) ^ 2 + (it.ay - it.ccy) ^ 2)
        s.a0, s.da = a0, da
    else
        s.arc = false
        s.x0, s.y0, s.dx, s.dy = it.ax, it.ay, it.bx - it.ax, it.by - it.ay
    end
end

-- Met la liaison montrée en accord avec l'état : couleur, étincelle, contour
-- d'achat — sans la retracer.
local function StylerLiaison(it)
    local col, active = CouleurLiaison(it)
    if it.tex then it.tex:SetVertexColor(col[1], col[2], col[3], col[4] or 1) end
    if active and not it.etincelle then
        PoserEtincelle(it)
    elseif not active and it.etincelle then
        RendreEtincelle(it.etincelle)
        it.etincelle = nil
    end
    local pulse = LiaisonPulse(it)
    if pulse and not it.texPulse then
        local T = TracerLiaison(it, RC.PULSE_COLOR)
        -- En OVERLAY : par-dessus la liaison qu'il souligne.
        if T then T:SetDrawLayer("OVERLAY") end
        it.texPulse = T
    elseif not pulse and it.texPulse then
        RendreTexture(it.texPulse)
        it.texPulse = nil
    end
end

local function MontrerLiaison(it)
    it.tex = TracerLiaison(it, (CouleurLiaison(it)))
    it.visible = true
    StylerLiaison(it)
end

local function CacherLiaison(it)
    RendreTexture(it.tex)
    it.tex = nil
    RendreTexture(it.texPulse)
    it.texPulse = nil
    if it.etincelle then
        RendreEtincelle(it.etincelle)
        it.etincelle = nil
    end
    it.visible = false
end

-- Les contours qui pulsent, parmi ce qui est montré.
local function RassemblerPulses()
    local liste = {}
    for _, btn in pairs(montresN) do
        if btn.pulseOn then liste[#liste + 1] = btn.pulse end
    end
    for it in pairs(montresE) do
        if it.texPulse then liste[#liste + 1] = it.texPulse end
    end
    UI.pulses = liste
end

local function RangeEnCases()
    local cases = {}
    for i, n in ipairs(DEF.nodes) do
        local k = CleCase(n.px, n.py)
        local c = cases[k]
        if not c then c = { n = {}, e = {} } cases[k] = c end
        c.n[#c.n + 1] = i
    end
    for _, it in ipairs(UI.liaisons) do
        for cx = floor(it.x0 / CASE), floor(it.x1 / CASE) do
            for cy = floor(it.y0 / CASE), floor(it.y1 / CASE) do
                local k = cx * 65536 + cy
                local c = cases[k]
                if not c then c = { n = {}, e = {} } cases[k] = c end
                c.e[#c.e + 1] = it
            end
        end
    end
    UI.cases = cases
end

-- Tout rendre : avant une nouvelle géométrie, rien de montré ne vaut plus.
local function ViderTout()
    for i, btn in pairs(montresN) do
        btn:Hide()
        btn.node, btn.index = nil, nil
        UI.boutonsLibres[#UI.boutonsLibres + 1] = btn
        montresN[i] = nil
    end
    for it in pairs(montresE) do
        CacherLiaison(it)
        montresE[it] = nil
    end
    UI.linePool.used = {}
    UI.pulses = {}
end

local function Placer()
    local canvas = UI.canvas

    -- étendue
    local minx, maxx, miny, maxy
    for _, n in ipairs(DEF.nodes) do
        minx = (not minx or n.x < minx) and n.x or minx
        maxx = (not maxx or n.x > maxx) and n.x or maxx
        miny = (not miny or n.y < miny) and n.y or miny
        maxy = (not maxy or n.y > maxy) and n.y or maxy
    end
    if not minx then minx, maxx, miny, maxy = 0, 8, 0, 6 end

    bounds.minx, bounds.miny, bounds.maxx, bounds.maxy = minx, miny, maxx, maxy

    -- Le canevas porte l'étendue des NŒUDS, plus une vue entière de marge —
    -- une demi-vue de chaque côté. C'est cette marge, et rien d'autre, qui
    -- permet au CENTRE de la caméra d'atteindre le nœud le plus excentré : sans
    -- elle, un nœud du bord ne peut être amené qu'au bord de la vue.
    --
    -- La marge se compte en unités du canevas, où la vue en occupe vue / zoom :
    -- elle grandit quand on dézoome, ce qu'il faut pour que la règle tienne à
    -- tous les zooms.
    --
    -- La réserve — le `max` — n'est là que par prudence envers le client :
    -- `GetHorizontalScrollRange` ignore l'échelle de l'enfant, et si jamais il
    -- bornait lui-même le défilement, il le ferait sur cette valeur fausse. En
    -- gardant le canevas au moins aussi large que la vue BRUTE plus deux marges,
    -- la borne du client reste au-delà de la nôtre à tous les zooms.
    --
    -- RC.MARGIN ne sert par ailleurs qu'à ne pas coller le nœud du bord contre
    -- l'arête du canevas, où il serait rogné.
    local etendueW = (maxx - minx) * RC.SPACING
    local etendueH = (maxy - miny) * RC.SPACING
    local brutW = UI.viewport:GetWidth() or 0
    local brutH = UI.viewport:GetHeight() or 0
    local vueW = zoom > 0 and brutW / zoom or 0
    local vueH = zoom > 0 and brutH / zoom or 0
    local W  = etendueW + max(vueW, brutW + RC.MARGIN * 2) + RC.MARGIN * 2
    local Hh = etendueH + max(vueH, brutH + RC.MARGIN * 2) + RC.MARGIN * 2
    offsetX = (W - etendueW) / 2 - RC.MARGIN
    offsetY = (Hh - etendueH) / 2 - RC.MARGIN
    canvas:SetWidth(W)
    canvas:SetHeight(Hh)

    for _, n in ipairs(DEF.nodes) do
        n.px, n.py = ToPixels(n.x, n.y)
    end

    -- Les liaisons : leur boîte et leur tracé (arc ou segment), sans texture.
    UI.liaisons = {}
    for _, e in ipairs(DEF.edges) do
        local a, b = nParId[e[1]], nParId[e[2]]
        if a and b then
            local it = { a = a, b = b, ax = a.px, ay = a.py, bx = b.px, by = b.py,
                         x0 = min(a.px, b.px), y0 = min(a.py, b.py),
                         x1 = max(a.px, b.px), y1 = max(a.py, b.py) }
            local sameRing = a.cluster ~= 0 and a.cluster == b.cluster and a.ring == b.ring
            local adjacent = sameRing and
                (abs(a.branch - b.branch) == 1 or abs(a.branch - b.branch) == 7)
            local c = adjacent and cParId[a.cluster]
            if c then
                it.arc = true
                it.ccx, it.ccy = ToPixels(c.x, c.y)
                it.ring = a.ring
            end
            UI.liaisons[#UI.liaisons + 1] = it
        end
    end
    RangeEnCases()
end

local function Cull(force)
    if not UI or not UI.cases or not DEF then return end
    local vp = UI.viewport
    local h, v = vp:GetHorizontalScroll(), vp:GetVerticalScroll()
    if not force and h == dernierFiltre.h and v == dernierFiltre.v and zoom == dernierFiltre.z then
        return
    end
    dernierFiltre.h, dernierFiltre.v, dernierFiltre.z = h, v, zoom
    dernierCull.h, dernierCull.v = h, v

    local vis = visActuel
    vis[1], vis[2], vis[3], vis[4] = RectVisible()
    for k in pairs(nouveauxN) do nouveauxN[k] = nil end
    for k in pairs(nouveauxE) do nouveauxE[k] = nil end
    local cases, canvas = UI.cases, UI.canvas
    local nodes = DEF.nodes

    local function visite(c)
        for _, i in ipairs(c.n) do
            local n = nodes[i]
            if Dedans(vis, n.px, n.py) then
                nouveauxN[i] = true
                if not montresN[i] then
                    local btn = table.remove(UI.boutonsLibres) or NouveauBouton()
                    montresN[i] = btn
                    btn.node, btn.index = n, i
                    btn:ClearAllPoints()
                    btn:SetPoint("CENTER", canvas, "BOTTOMLEFT", n.px, n.py)
                    Habiller(btn, n)
                end
            end
        end
        for _, it in ipairs(c.e) do
            if not nouveauxE[it]
               and not (it.x1 < vis[1] or it.x0 > vis[3] or it.y1 < vis[2] or it.y0 > vis[4]) then
                nouveauxE[it] = true
                if not it.visible then MontrerLiaison(it) end
                montresE[it] = true
            end
        end
    end
    if vis[1] == -math.huge then
        for _, c in pairs(cases) do visite(c) end
    else
        for cx = floor(vis[1] / CASE), floor(vis[3] / CASE) do
            for cy = floor(vis[2] / CASE), floor(vis[4] / CASE) do
                local c = cases[cx * 65536 + cy]
                if c then visite(c) end
            end
        end
    end

    -- Ce qui était montré et ne l'est plus rend son bouton ou sa texture.
    for i, btn in pairs(montresN) do
        if not nouveauxN[i] then
            if UI.choix and UI.choix:IsShown() and UI.choix.ancre == btn then ACT.FermerChoix() end
            btn:Hide()
            btn.node, btn.index = nil, nil
            UI.boutonsLibres[#UI.boutonsLibres + 1] = btn
            montresN[i] = nil
        end
    end
    for it in pairs(montresE) do
        if not nouveauxE[it] then
            CacherLiaison(it)
            montresE[it] = nil
        end
    end
    UI.linePool.used = {}       -- plus un registre : chaque liaison tient sa texture
    RassemblerPulses()
end

local function Restyler()
    if not UI or not DEF then return end
    for i, btn in pairs(montresN) do
        Habiller(btn, DEF.nodes[i])
    end
    for it in pairs(montresE) do
        StylerLiaison(it)
    end
    UI.linePool.used = {}
    RassemblerPulses()
end

function Rebuild()
    if not UI or not DEF then return end
    local vp = UI.viewport
    local cle = tostring(DEF) .. ":" .. zoom .. ":" .. (vp:GetWidth() or 0) .. ":" .. (vp:GetHeight() or 0)
    if cle ~= cleGeometrie then
        cleGeometrie = cle
        ViderTout()
        Placer()
        Cull(true)
    else
        Cull(true)
        Restyler()
    end

    -- bandeau
    UI.pointsLabel:SetText(fmt(L.points, ETAT and ETAT.disponibles or 0)
        .. "   " .. fmt(L.prochain, ETAT and ETAT.prochainCout or 0)
        .. "   " .. fmt(L.actifs, ETAT and ETAT.nbActifs or 0, #DEF.nodes))

    PoserFondSpec()
    MettreAJourRecap()
end

-- ---------------------------------------------------------------------------
-- Fenêtre
-- ---------------------------------------------------------------------------

-- Les bornes du défilement se posent sur LES NŒUDS EXTRÊMES, et non sur le
-- canevas : le centre de la vue doit pouvoir atteindre exactement le nœud le
-- plus à gauche, le plus à droite, le plus haut et le plus bas. Borner sur le
-- canevas revenait à amener le bord du contenu au bord de l'écran et jamais en
-- son milieu.
--
-- **LE DÉFILEMENT SE COMPTE DANS L'UNITÉ DE L'ENFANT**, pas en pixels d'écran.
-- Le canevas est mis à l'échelle par `SetScale(zoom)` : une unité de défilement
-- vaut donc zoom pixels d'écran, et la demi-vue qui sépare le bord de la vue de
-- son centre vaut largeurVue / (2 × zoom) unités de canevas. Multiplier par le
-- zoom au lieu de diviser laissait quarante-neuf unités de grille hors d'atteinte
-- au bord droit une fois dézoomé, tout en autorisant la caméra à sortir dans le
-- vide de l'autre côté. À zoom 1 les deux calculs coïncident — c'est ce qui
-- rendait le défaut invisible là et là seulement.
--
-- `GetHorizontalScrollRange` ne sert à rien ici : le client le mesure sur la
-- largeur BRUTE de l'enfant, sans tenir compte de son échelle.
--
-- Et le défilement vertical part du HAUT du canevas quand nos positions partent
-- du BAS — d'où l'inversion, qui échange aussi les deux bornes.
DemiVue = function()
    local vp = UI.viewport
    if zoom <= 0 then return 0, 0 end
    return (vp:GetWidth() or 0) / (2 * zoom), (vp:GetHeight() or 0) / (2 * zoom)
end

local function ClampScroll()
    local vp = UI.viewport
    vp:UpdateScrollChildRect()
    local demiW, demiH = DemiVue()
    local hautCanevas = UI.canvas:GetHeight() or 0

    local xMin, yMin = ToPixels(bounds.minx, bounds.miny)
    local xMax, yMax = ToPixels(bounds.maxx, bounds.maxy)

    local hMin, hMax = xMin - demiW, xMax - demiW
    -- Le nœud le plus HAUT donne la borne la plus BASSE du défilement.
    local vMin = (hautCanevas - yMax) - demiH
    local vMax = (hautCanevas - yMin) - demiH

    vp:SetHorizontalScroll(max(hMin, min(vp:GetHorizontalScroll(), hMax)))
    vp:SetVerticalScroll(max(vMin, min(vp:GetVerticalScroll(), vMax)))
end

-- Point de grille au centre de la vue. Attention aux axes : le défilement
-- vertical se mesure depuis le HAUT, nos positions depuis le BAS du canevas.
local function CentreVu()
    local vp = UI.viewport
    local demiW, demiH = DemiVue()
    local pxHaut = vp:GetHorizontalScroll() + demiW
    local pyHaut = vp:GetVerticalScroll() + demiH
    local px, py = pxHaut, UI.canvas:GetHeight() - pyHaut
    return (px - RC.MARGIN - offsetX) / RC.SPACING + bounds.minx,
           (py - RC.MARGIN - offsetY) / RC.SPACING + bounds.miny
end

-- Fait défiler pour amener ce point de grille au centre de la vue.
function CentrerSur(gx, gy)
    local vp = UI.viewport
    local px, py = ToPixels(gx, gy)
    local demiW, demiH = DemiVue()
    vp:UpdateScrollChildRect()
    vp:SetHorizontalScroll(px - demiW)
    vp:SetVerticalScroll((UI.canvas:GetHeight() - py) - demiH)
    ClampScroll()
    -- LE CENTRAGE REFILTRE (2026-09-05) : le rendu est filtre sur la fenetre, et
    -- un centrage sans filtre laissait la grille commune invisible a
    -- l'ouverture jusqu'au premier glissement. Le filtre par cases est bon
    -- marche : on le rejoue a chaque centrage.
    Cull(true)
end

-- Zoom centré : le point regardé reste au centre, et Rebuild recalcule la
-- taille du canevas et le centrage du contenu à la nouvelle échelle.
local function SetZoom(z)
    z = max(RC.ZOOM_MIN, min(RC.ZOOM_MAX, z))
    if z == zoom then return end
    local gx, gy = CentreVu()
    zoom = z
    UI.canvas:SetScale(zoom)
    Rebuild()               -- nouvelle géométrie : tout est replacé
    CentrerSur(gx, gy)      -- et filtré là où la vue s'est posée
end

local function BuildUI()
    -- Le contour de WoW plutôt qu'un filet d'un pixel : c'est le même que
    -- celui des boîtes de dialogue du jeu, donc chez lui à l'écran.
    local backdrop = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    }

    local f = CreateFrame("Frame", "SpherierJoueurFrame", UIParent)
    -- LA FENÊTRE PREND L'ÉCRAN (2026-09-05) : quatre cinquièmes de la largeur,
    -- les six septièmes de la hauteur, jamais moins qu'avant (1000 × 680).
    -- Tout le reste s'ancre aux bords : la grille gagne ce que la fenêtre gagne.
    local ecranW, ecranH = UIParent:GetWidth() or 1024, UIParent:GetHeight() or 768
    f:SetWidth(max(1000, min(1700, floor(ecranW * 0.80))))
    f:SetHeight(max(680, min(1050, floor(ecranH * 0.86))))
    f:SetPoint("CENTER")
    f:SetBackdrop(backdrop)
    -- Sans teinte : le contour des boîtes de dialogue a ses propres couleurs,
    -- et le noircir revenait à l'effacer.
    f:SetBackdropColor(1, 1, 1, 1)
    f:SetBackdropBorderColor(1, 1, 1, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetToplevel(true)
    f:Hide()
    -- La liste de choix et l'objet en main sont des satellites de la fenêtre :
    -- ils ne lui survivent pas.
    f:SetScript("OnHide", function()
        ACT.FermerChoix()
        ACT.Reposer()
    end)
    -- Échap ferme la fenêtre : le client vide `UISpecialFrames` à chaque appui,
    -- et ce qui n'y figure pas ne s'en va jamais ainsi. L'`OnHide` ci-dessus
    -- fait le ménage, la sortie par Échap vaut donc celle par le bouton.
    table.insert(UISpecialFrames, "SpherierJoueurFrame")
    UI = f
    UI.boutonsLibres = {}
    UI.linePool    = { free = {}, used = {} }
    UI.etincellesLibres, UI.etincellesActives = {}, {}
    UI.liaisons    = {}
    UI.pulses      = {}

    -- La roche du grimoire custom, sous tout le reste : elle remplace l'aplat
    -- gris et ne se répète pas, la planche faisant 1024 de côté.
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", RC.BORD_G, -RC.BORD_H)
    header:SetPoint("TOPRIGHT", -RC.BORD_D, -RC.BORD_H)
    header:SetHeight(RC.BANDEAU_H)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetTexture(0.12, 0.12, 0.12, 1)

    local title = header:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
    title:SetPoint("LEFT", 12, 0)
    title:SetText(L.titre)
    title:SetTextColor(1, 0.82, 0)

    UI.pointsLabel = header:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.pointsLabel:SetPoint("RIGHT", -40, 0)

    -- Bandeau de l'objet en main : le curseur seul ne dit pas CE QU'ON tient.
    UI.banniereIcone = header:CreateTexture(nil, "OVERLAY")
    UI.banniereIcone:SetWidth(18)
    UI.banniereIcone:SetHeight(18)
    UI.banniereIcone:SetPoint("LEFT", title, "RIGHT", 16, 0)
    UI.banniereIcone:Hide()

    UI.banniere = header:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.banniere:SetPoint("LEFT", UI.banniereIcone, "RIGHT", 6, 0)
    UI.banniere:SetTextColor(1, 0.82, 0)

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- ----------------------------------------------------- récapitulatif
    -- Une ligne par statistique du catalogue : « acquis / total de la grille ».
    -- Survoler une ligne allume toutes les pierres de cette statistique.
    -- Pas de contour propre : il porterait celui des boîtes de dialogue, et les
    -- deux panneaux se retrouveraient séparés par un gros trait et en retrait
    -- des bords. Ils se touchent, et un filet les sépare.
    local recap = CreateFrame("Frame", nil, f)
    recap:SetPoint("TOPLEFT", RC.BORD_G, -(RC.BORD_H + RC.BANDEAU_H))
    recap:SetPoint("BOTTOMLEFT", RC.BORD_G, RC.BORD_B)
    recap:SetWidth(RC.RECAP_W)

    -- Le décor de la spécialisation courante, en quatre quartiers. Il est posé
    -- ici et replacé à chaque changement de taille, sa découpe dépendant des
    -- proportions du panneau.
    local filet = f:CreateTexture(nil, "OVERLAY")
    filet:SetPoint("TOPLEFT", recap, "TOPRIGHT", 0, 0)
    filet:SetPoint("BOTTOMLEFT", recap, "BOTTOMRIGHT", 0, 0)
    filet:SetWidth(RC.FILET)
    filet:SetTexture(RC.FILET_COULEUR[1], RC.FILET_COULEUR[2], RC.FILET_COULEUR[3], 1)

    UI.recapCadre = recap
    UI.fond = {}
    for _, q in ipairs(RC.TALENT_QUARTIERS) do
        local t = recap:CreateTexture(nil, "BACKGROUND")
        t:SetAlpha(RC.TALENT_ALPHA)
        t:SetVertexColor(RC.TALENT_TEINTE[1], RC.TALENT_TEINTE[2], RC.TALENT_TEINTE[3])
        t:Hide()
        UI.fond[q.coin] = t
    end
    recap:SetScript("OnSizeChanged", function() PoserFondSpec() end)

    -- LES SORTS DE CLASSE EN TÊTE (2026-09-05) : une ligne par emplacement de
    -- sort que la classe voit — vert appris, rouge pas encore ; le survol
    -- allume l'emplacement sur la grille, comme pour les runes. Placées par
    -- MettreAJourRecap, comme tout le reste du panneau.
    UI.sortTitre = recap:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.sortTitre:SetPoint("TOPLEFT", 10, -8)
    UI.sortTitre:SetText(L.sorts_titre)
    UI.sortTitre:SetTextColor(1, 0.82, 0)
    UI.sortVide = recap:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    UI.sortVide:SetText(L.sorts_vide)
    UI.sortVide:Hide()
    UI.sortLignes = {}
    for i = 1, 8 do
        local ligne = CreateFrame("Frame", nil, recap)
        ligne:SetHeight(RC.RECAP_H)
        ligne:EnableMouse(true)
        ligne:Hide()

        local surbrillance = ligne:CreateTexture(nil, "BACKGROUND")
        surbrillance:SetAllPoints()
        surbrillance:SetTexture(RC.RECAP_HL[1], RC.RECAP_HL[2], RC.RECAP_HL[3], 1)
        surbrillance:Hide()

        local nom = ligne:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        nom:SetPoint("LEFT", 4, 0)
        nom:SetPoint("RIGHT", -4, 0)
        nom:SetJustifyH("LEFT")

        ligne:SetScript("OnEnter", function(self)
            if not self.noeud then return end
            surbrillance:Show()
            sortSurvole = self.noeud
            RestylerHalos()
        end)
        ligne:SetScript("OnLeave", function(self)
            surbrillance:Hide()
            if sortSurvole == self.noeud then
                sortSurvole = nil
                RestylerHalos()
            end
        end)

        UI.sortLignes[i] = { cadre = ligne, nom = nom, hl = surbrillance }
    end

    UI.recapTitre = recap:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.recapTitre:SetText(L.recap_titre)
    UI.recapTitre:SetTextColor(1, 0.82, 0)

    UI.recapAide = recap:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    UI.recapAide:SetText(L.recap_aide)

    -- Les lignes sont créées ici, mais c'est MettreAJourRecap qui les place et
    -- décide lesquelles s'affichent : une statistique absente de la grille est
    -- masquée, et les autres se réempilent sans trou.
    UI.recapLignes = {}
    local y = RC.RECAP_Y0
    for _, cle in ipairs(STAT_ORDRE) do
        local ligne = CreateFrame("Frame", nil, recap)
        ligne:SetPoint("TOPLEFT", 6, y)
        ligne:SetPoint("TOPRIGHT", -6, y)
        ligne:SetHeight(RC.RECAP_H)
        ligne:EnableMouse(true)
        ligne:Hide()

        local surbrillance = ligne:CreateTexture(nil, "BACKGROUND")
        surbrillance:SetAllPoints()
        surbrillance:SetTexture(RC.RECAP_HL[1], RC.RECAP_HL[2], RC.RECAP_HL[3], 1)
        surbrillance:Hide()

        local nom = ligne:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        nom:SetPoint("LEFT", 4, 0)
        nom:SetText(STAT_LABELS[cle] or cle)

        local valeur = ligne:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        valeur:SetPoint("RIGHT", -4, 0)

        ligne:SetScript("OnEnter", function()
            surbrillance:Show()
            statSurvolee = cle
            RestylerHalos()
        end)
        ligne:SetScript("OnLeave", function()
            surbrillance:Hide()
            if statSurvolee == cle then
                statSurvolee = nil
                RestylerHalos()
            end
        end)

        UI.recapLignes[cle] = { cadre = ligne, nom = nom, valeur = valeur }
        y = y - RC.RECAP_H
    end

    y = y - 12
    UI.runeTitre = recap:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.runeTitre:SetPoint("TOPLEFT", 10, y)
    UI.runeTitre:SetText(L.runes_titre)
    UI.runeTitre:SetTextColor(1, 0.82, 0)
    y = y - 16

    UI.runeVide = recap:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    UI.runeVide:SetPoint("TOPLEFT", 10, y)
    UI.runeVide:SetText(L.runes_vide)

    UI.runeTitreInerte = recap:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.runeTitreInerte:SetPoint("TOPLEFT", 10, y)
    UI.runeTitreInerte:SetText(L.runes_inertes)
    UI.runeTitreInerte:SetTextColor(RC.RUNE_INERTE[1], RC.RUNE_INERTE[2], RC.RUNE_INERTE[3])
    UI.runeTitreInerte:Hide()

    -- Des CADRES, comme les lignes de statistique : une ligne de rune se
    -- survole, et ce survol allume les emplacements qui la portent.
    -- MettreAJourRecap les place et décide lesquelles s'affichent.
    UI.runeLignes = {}
    for i = 1, 10 do
        local ligne = CreateFrame("Frame", nil, recap)
        ligne:SetPoint("TOPLEFT", 6, y - (i - 1) * RC.RECAP_H)
        ligne:SetPoint("TOPRIGHT", -6, y - (i - 1) * RC.RECAP_H)
        ligne:SetHeight(RC.RECAP_H)
        ligne:EnableMouse(true)
        ligne:Hide()

        local surbrillance = ligne:CreateTexture(nil, "BACKGROUND")
        surbrillance:SetAllPoints()
        surbrillance:SetTexture(RC.RECAP_HL[1], RC.RECAP_HL[2], RC.RECAP_HL[3], 1)
        surbrillance:Hide()

        local nom = ligne:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        nom:SetPoint("LEFT", 4, 0)

        ligne:SetScript("OnEnter", function(self)
            if not self.cle then return end
            surbrillance:Show()
            runeSurvolee, runeInerte = self.cle, self.inerte
            RestylerHalos()
        end)
        ligne:SetScript("OnLeave", function(self)
            surbrillance:Hide()
            if runeSurvolee == self.cle then
                runeSurvolee, runeInerte = nil, false
                RestylerHalos()
            end
        end)

        UI.runeLignes[i] = { cadre = ligne, nom = nom, hl = surbrillance }
    end

    local viewport = CreateFrame("ScrollFrame", "SpherierJoueurViewport", f)
    viewport:SetPoint("TOPLEFT", RC.BORD_G + RC.RECAP_W + RC.FILET,
                      -(RC.BORD_H + RC.BANDEAU_H))
    viewport:SetPoint("BOTTOMRIGHT", -RC.BORD_D, RC.BORD_B)
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    UI.viewport = viewport

    local vpbg = viewport:CreateTexture(nil, "BACKGROUND")
    vpbg:SetAllPoints()
    vpbg:SetTexture(0.03, 0.03, 0.03, 1)

    local canvas = CreateFrame("Frame", "SpherierJoueurCanvas", viewport)
    canvas:SetWidth(1400)
    canvas:SetHeight(1000)
    viewport:SetScrollChild(canvas)
    UI.canvas = canvas

    viewport:SetScript("OnMouseDown", function(self, button)
        -- Un objet en main : ce clic ne sert qu'à le reposer. Surtout pas à
        -- entamer un déplacement de la grille.
        if ACT.enMain then
            ACT.Reposer()
            return
        end
        if button ~= "LeftButton" then return end
        local scale = UIParent:GetEffectiveScale()
        startX, startY = GetCursorPosition()
        startX, startY = startX / scale, startY / scale
        startH, startV = self:GetHorizontalScroll(), self:GetVerticalScroll()
        dragging = true
    end)
    viewport:SetScript("OnMouseUp", function()
        if dragging then
            dragging = false
            Cull(true)
        end
    end)
    viewport:SetScript("OnHide", function() dragging = false end)
    viewport:SetScript("OnUpdate", function(self)
        if not dragging then return end
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        -- Le curseur se mesure en pixels d'écran, le défilement en unités du
        -- canevas : sans la division, le contenu file plus vite ou moins vite
        -- que la main dès qu'on quitte le zoom 1.
        local k = (zoom > 0) and zoom or 1
        self:SetHorizontalScroll(startH - (cx - startX) / k)
        self:SetVerticalScroll(startV + (cy - startY) / k)
        ClampScroll()
        Cull()                  -- bon marché : à chaque image, sans à-coups
    end)
    viewport:SetScript("OnMouseWheel", function(_, delta) SetZoom(zoom + delta * RC.ZOOM_STEP) end)

    return f
end

local function EnsureUI()
    if not UI then BuildUI() end
end

-- ---------------------------------------------------------------------------
-- Handlers AIO
-- ---------------------------------------------------------------------------

-- Le catalogue arrive seul, avant toute ouverture : c'est lui qui permet de
-- reconnaître une pierre ou une épingle dans un sac.
function SpherierJoueurHandlers.Catalogue(_, cat)
    if type(cat) ~= "table" then return end
    CAT.pierres      = cat.pierres or {}
    CAT.runes        = cat.runes or {}
    CAT.runesStat    = cat.runesStat or {}
    CAT.epingle      = cat.epingle or 0
    CAT.iconeParStat = cat.iconeParStat or {}
end

-- LE FIL SE DÉPLIE ICI (2026-09-05). Le serveur envoie des tableaux
-- positionnels et rien de dérivable ; on reconstitue la définition telle que
-- tout le reste du fichier la lit. Voir Compacter() dans Spherier_Joueur.lua.
--   n : { id, kind, cluster, ring, branch, pierre, sort, x×10000, y×10000 }
local function DeplierDef(fil)
    local def = { nodes = {}, edges = {}, clusters = {}, bareme = {},
                  pierres = fil.pierres or {}, runes = fil.runes or {}, runesStat = fil.runesStat or {},
                  iconeParStat = fil.iconeParStat or {}, epingle = fil.epingle or 0,
                  classe = fil.classe, depart = fil.depart or 0 }
    for _, r in ipairs(fil.n or {}) do
        local effet = def.pierres[r[6] or 0]
        def.nodes[#def.nodes + 1] = {
            id = r[1], kind = r[2], cluster = r[3], ring = r[4], branch = r[5],
            stat = effet and effet.stat or nil,
            montant = effet and effet.montant or 0,
            qualite = effet and effet.qualite or 0,
            sort = r[7] or 0,
            x = (r[8] or 0) / 10000, y = (r[9] or 0) / 10000,
        }
    end
    local e = fil.e or {}
    for i = 1, #e - 1, 2 do def.edges[#def.edges + 1] = { e[i], e[i + 1] } end
    for _, c in ipairs(fil.c or {}) do
        def.clusters[#def.clusters + 1] = { id = c[1], x = c[2] / 10000, y = c[3] / 10000, rot = c[4] / 10000 }
    end
    local b = fil.b or {}
    for i = 1, #b - 1, 2 do def.bareme[#def.bareme + 1] = { min = b[i], cout = b[i + 1] } end
    return def
end

-- L'état ne porte que `brut` (entrée de chaque emplacement actif) : `actives`
-- et `contenu` s'en déduisent avec le catalogue des pierres.
local function DeplierEtat(etat)
    if type(etat) ~= "table" then return etat end
    etat.brut = etat.brut or {}
    etat.contenuCompte = etat.contenuCompte or {}
    etat.actives, etat.contenu = {}, {}
    for id, entree in pairs(etat.brut) do
        etat.actives[id] = true
        local effet = CAT.pierres[entree]
        if effet then
            etat.contenu[id] = { stat = effet.stat, montant = effet.montant, qualite = effet.qualite }
        end
    end
    return etat
end

-- `fil` est faux quand le serveur sait que nous tenons déjà cette version :
-- seul l'état voyage. Sans définition en main pour autant, on redemande tout.
function SpherierJoueurHandlers.Afficher(_, fil, etat, version)
    EnsureUI()

    if fil then
        -- L'ouverture rafraîchit le catalogue au passage : une seule source.
        SpherierJoueurHandlers.Catalogue(nil, fil)

        DEF, DEF_VERSION = DeplierDef(fil), version
        nParId, cParId, adjParId = {}, {}, {}
        for _, n in ipairs(DEF.nodes) do nParId[n.id] = n end
        for _, c in ipairs(DEF.clusters) do cParId[c.id] = c end
        for _, e in ipairs(DEF.edges) do
            adjParId[e[1]] = adjParId[e[1]] or {}
            adjParId[e[2]] = adjParId[e[2]] or {}
            table.insert(adjParId[e[1]], e[2])
            table.insert(adjParId[e[2]], e[1])
        end
    elseif not DEF then
        AIO.Handle("SpherierJoueur", "Ouvrir")
        return
    end
    ETAT = DeplierEtat(etat)

    UI:Show()
    zoom = 1
    UI.canvas:SetScale(1)
    Rebuild()
    -- Un objet peut avoir été pris en main AVANT que la fenêtre n'existe.
    ACT.MajBandeau()
    CentrerSur((bounds.minx + bounds.maxx) / 2, (bounds.miny + bounds.maxy) / 2)
end

function SpherierJoueurHandlers.MettreAJour(_, etat)
    if not UI or not DEF then return end
    ETAT = DeplierEtat(etat)
    Rebuild()
end

-- ---------------------------------------------------------------------------
-- Accès : bouton de la fenêtre des talents, /spherier
-- ---------------------------------------------------------------------------

local function Basculer()
    if UI and UI:IsShown() then
        UI:Hide()
    else
        AIO.Handle("SpherierJoueur", "Ouvrir", DEF_VERSION)
    end
end

-- Onglet « Sphèrier » à droite du dernier onglet visible de la fenêtre des
-- talents (« Glyphes » en temps normal). Il n'appartient pas au système
-- d'onglets de la fenêtre : il reste dessiné « désélectionné » et ouvre notre
-- propre fenêtre. Ré-ancré à chaque ouverture, car les onglets visibles
-- changent (double spécialisation, familier).
local function AncrerOnglet(tab)
    local ancre
    for i = 1, 8 do
        local t = _G["PlayerTalentFrameTab" .. i]
        if t and t:IsShown() then ancre = t end
    end
    tab:ClearAllPoints()
    if ancre then
        tab:SetPoint("LEFT", ancre, "RIGHT", -16, 0)
    else
        tab:SetPoint("TOPLEFT", PlayerTalentFrame, "BOTTOMLEFT", 70, 61)
    end
end

local function AccrocherTalents()
    if not PlayerTalentFrame or SpherierTalentFrameTab then return end

    local tab = CreateFrame("Button", "SpherierTalentFrameTab", PlayerTalentFrame,
        "CharacterFrameTabButtonTemplate")
    tab:SetText(L.bouton)
    if PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0) end
    if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    tab:SetScript("OnClick", Basculer)

    AncrerOnglet(tab)
    PlayerTalentFrame:HookScript("OnShow", function() AncrerOnglet(tab) end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, _, addon)
    if addon == "Blizzard_TalentUI" then AccrocherTalents() end
end)
if IsAddOnLoaded and IsAddOnLoaded("Blizzard_TalentUI") then AccrocherTalents() end

SLASH_SPHERIERJOUEUR1 = "/spherier"
SlashCmdList["SPHERIERJOUEUR"] = Basculer

-- ---------------------------------------------------------------------------
-- Clic droit sur une pierre, une rune ou une épingle dans un sac
-- ---------------------------------------------------------------------------
-- Le jeu appelle UseContainerItem sur tout clic droit d'un objet en sac
-- (ContainerFrame.lua, branche « else » de ContainerFrameItemButton_OnClick).
-- Nos objets n'ayant aucun sort d'utilisation, ce clic ne fait rien côté
-- serveur : on peut donc lui donner un sens ici sans rien détourner. La fenêtre
-- s'ouvre et l'objet passe « en main » — le geste suivant est celui de
-- l'interface, à l'identique.
hooksecurefunc("UseContainerItem", function(sac, emplacement)
    -- Quand une de ces fenêtres est ouverte, le clic droit ne veut PAS dire
    -- « utiliser » : il vend, il joint à un courrier, il met en vente. On ne
    -- s'en mêle pas.
    for _, nom in ipairs({ "MerchantFrame", "MailFrame", "TradeFrame", "AuctionFrame" }) do
        local cadre = _G[nom]
        if cadre and cadre:IsShown() then return end
    end

    local entree = GetContainerItemID and GetContainerItemID(sac, emplacement)
    if not entree then
        local lien = GetContainerItemLink(sac, emplacement)
        entree = lien and tonumber(lien:match("item:(%d+)"))
    end
    if not entree then return end
    if not (ACT.Sertissable(entree) or ACT.EstEpingle(entree)) then return end

    if not (UI and UI:IsShown()) then AIO.Handle("SpherierJoueur", "Ouvrir", DEF_VERSION) end
    ACT.PrendreEnMain(entree)
end)

-- ---------------------------------------------------------------------------
-- Le compte de Spherite se tient à jour, fenêtre ouverte
-- ---------------------------------------------------------------------------
-- La Spherite arrive SANS QUE LE JOUEUR TOUCHE À L'INTERFACE : un Nexus
-- consommé, un boss tombé, un donjon fini. Le crédit se fait côté C++, qui
-- n'adresse aucun message AIO — le serveur ne peut donc pas nous prévenir.
-- C'est le client qui demande, et seulement tant que sa fenêtre est ouverte.
--
-- DEUX TEMPS, pour ne pas redessiner dans le vide : on ne demande que le
-- NOMBRE, d'une requête, et l'on ne réclame l'état complet que s'il a bougé.
-- Un Rebuild toutes les deux secondes ferait clignoter les infobulles et
-- coûterait trois requêtes en base à chaque battement.
--
-- Un cadre à part, et non un OnUpdate sur la fenêtre : il bat même quand elle
-- n'existe pas encore, et ne dispute son script à personne.
-- L'accumulateur vit SUR LE CADRE et non en local : le chunk est en Lua 5.1,
-- borné à 200 locales, et ce fichier en compte déjà beaucoup.
local POULS = 2.0
local batteur = CreateFrame("Frame")
batteur.ecoule = 0
batteur:SetScript("OnUpdate", function(self, delta)
    self.ecoule = self.ecoule + delta
    if self.ecoule < POULS then return end
    self.ecoule = 0
    if UI and UI:IsShown() then
        AIO.Handle("SpherierJoueur", "Points")
    end
end)

function SpherierJoueurHandlers.Points(_, disponibles)
    if not UI or not UI:IsShown() or not ETAT then return end
    if disponibles == ETAT.disponibles then return end
    AIO.Handle("SpherierJoueur", "Rafraichir")
end

-- Le catalogue est demandé dès le chargement du code : c'est ce qui rend le
-- clic droit ci-dessus opérant avant même la première ouverture de la fenêtre.
AIO.Handle("SpherierJoueur", "Catalogue")
