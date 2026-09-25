-- ForeverUI : le grimoire de camelot (docs/GRIMOIRE.md, etape 1 : le cadre,
-- les categories et la grille, hors combat).
--
-- L'OSSATURE RESTE CELLE DE WOTLK. SpellBookFrame demeure le panneau que
-- ToggleSpellBook, la touche P et le micro-bouton ouvrent et ferment ; sa
-- croix (SpellBookCloseButton) reste la sienne, rhabillee, pour que la
-- fermeture ne passe pas par notre code. Son art et ses douze boutons de sort
-- s'effacent ; le livre de camelot se pose DANS SpellBookFrame, et s'ouvre
-- et se ferme avec lui.
--
-- LANCER UN SORT EST PROTEGE. Les douze boutons de WotLK lancent depuis
-- l'etat interne de son grimoire (type de livre, ligne, page) : la grille de
-- camelot ne peut pas s'y adosser. Chaque case est donc un bouton SECURISE
-- (SecureActionButtonTemplate, type "spell").
--
-- EN COMBAT (etape 2). Un sort ne se change sur une case que par du code
-- securise. Hors combat, TOUT est calcule -- chaque categorie, chaque page,
-- chaque groupe -- et publie dans un controleur securise
-- (SecureHandlerAttributeTemplate). Les onglets, les fleches, la roulette et
-- les groupes ne font que lui dire "categorie n" ou "tourne de 1" ; son bloc
-- "afficher" pose alors les cases (attributs, place, visibilite), puis rend
-- la main par CallMethod a du code ordinaire qui change images et textes --
-- ce que le client permet en combat. Le meme chemin sert hors combat : il n'y
-- en a qu'un.
--
-- Contraintes du client (RestrictedExecution.lua, RestrictedFrames.lua) :
-- un bloc securise ne contient ni accolade ni le mot "function" (d'ou
-- newtable) ; SetPoint n'y vise qu'un cadre explicitement protege, ou
-- "$parent". Ce qui reste impossible en combat : le calcul lui-meme (un sort
-- appris, un familier appele pendant le combat attendent sa fin). Agrandir ou
-- reduire, et les trois reglages, passent en combat : chaque combinaison
-- (8 jeux de reglages x 2 modes) est publiee a l'avance, et le menu des
-- reglages est fait de boutons securises.
--
-- RELEVE -- blizzard_playerspells (le .toc : camelot/ pour le cadre et le
-- grimoire, spellbook/ pour le reste) :
--   PlayerSpellsFrame   PortraitFrameTemplate ; 1618 x 720 (deux pages),
--                       809 x 720 (une page) ; panneau "center" : TOP de
--                       l'ecran a -116 ; titre SPELLBOOK ; portrait : l'icone
--                       de la ligne General ; bouton agrandir / reduire a
--                       gauche de la croix (MaximizeMinimizeButtonFrameTemplate)
--   SpellBookFrame      BOTTOMLEFT (0, 4), 1612 (806) x 702 ; pages
--                       spellbook-page-left / -right (c60) chacune sur une
--                       moitie, une seule (-right) en reduit
--   CategoryTabSystem   TOPLEFT (70, -26), onglets-icones en haut (44 x 32,
--                       ecart 1) : icone 36 x 35 centree, cadre
--                       spellbook-tab-frame-c60 en BOTTOM (0, 1) PAR-DESSUS
--                       l'icone ; choisi : -glow-c60 et -glow-gradient-c60
--   PagedSpellsFrame    TOPLEFT (0, -50) ; deux vues de 680 x 590, a
--                       (85, -45) et TOPRIGHT (-50, -45) ; 3 colonnes, ecarts
--                       15 x 10 ; en-tete 51 de haut, sort 60 ; les colonnes
--                       se remplissent l'une apres l'autre, sur le moins de
--                       rangees possible (PagedCondensedVerticalGrid)
--   PagingControls      BOTTOMRIGHT (-75, 40) : "Page n/m", fleche
--                       precedente, fleche suivante, ecart 8 ; SystemFont_Med3
--                       a l'encre du grimoire
--   en-tete             nom en SystemFont_Huge2 de (-8, 0) a (-60, 0) ;
--                       separateur spellbook-divider (11) de (-32) a (-60) ;
--                       fond spellbook-list-backplate 416 x 106 a LEFT
--                       (-85, 10), alpha 0,65
--   sort                icone 36 dans un bouton 40 x 40 a LEFT ; cadre carre
--                       spellbook-item-iconframe (-11, 1)/(1, -7), rond pour un
--                       passif (talents-node-circle-gray) ; ombre (-12, 3)/(2, -8) ;
--                       nom SystemFont_Large, sous-titre SystemFont_Med1 (le
--                       rang, ou "Passive"), a (50, -1) ; fond
--                       spellbook-item-backplate a 0,25, 1 au survol ; survol
--                       de l'icone en ADD a 0,35, 0,65 presse
--
-- CE QUI DIFFERE, ET POURQUOI.
--   * 3.3.5 n'a pas de masque : l'icone carree n'a pas ses coins arrondis ;
--     l'icone d'un passif s'arrondit par SetPortraitToTexture.
--   * 3.3.5 n'a pas de sorts "a venir" : aucun sort grise ni "disponible au
--     niveau n".
--   * le familier : ses sorts se lancent par leur nom, et le clic droit
--     bascule leur lancement automatique (/petautocasttoggle).
--   * le panneau de WotLK reste de zone "left" : le livre se pose ou camelot
--     pose un panneau "center", sans deplacer les autres.

ForeverUI = ForeverUI or {}

local S = {}
ForeverUI.SpellBook = S

local G = {
	largeur = 1618, largeurReduite = 809, hauteur = 720, haut = -116,
	livreL = 1612, livreLReduit = 806, livreH = 702, livreBas = 4,
	ongletsX = 70, ongletsY = -26, ongletL = 44, ongletH = 32, ongletEcart = 1,
	iconeOngletL = 34, iconeOngletH = 33,
	pagesHaut = -50, vueL = 680, vueH = 590, vue1X = 85, vueY = -45, vue2X = -50,
	colonnes = 3, ecartX = 15, ecartY = 10, enteteH = 51, sortH = 60, espace = 20,
	pagerX = -75, pagerY = 40, pagerEcart = 8, flecheCote = 32,
	boutonCote = 40, iconeCote = 36, texteX = 50,
	casesParVue = 24,
	fermerX = -2, fermerY = 1, rougeCote = 24,
	portraitX = -5, portraitY = 7, portraitCote = 62,
	titreX1 = 58, titreX2 = -24, titreY = -1, titreH = 20,
	reglagesX = -30, reglagesY = -27, reglagesL = 15, reglagesH = 16,
	-- le menu volant (SpellBookItemButtonMixin, FlyoutButtonTemplate,
	-- SpellFlyout) : ouvert a DROITE, decale de -4, 42 de haut ; fleche 15 x 6,
	-- a 4 du bord ferme, 2 ouvert ; petits boutons de 30, premier a 9, ecart 4,
	-- 9 apres le dernier ; bordure teintee a 0,7
	volantDecalage = -4, volantH = 42, flecheL = 15, flecheH = 6,
	flecheFerme = 4, flecheOuvert = 2, petitCote = 30, volantDebut = 9,
	volantEcart = 4, volantFin = 9, volantTeinte = 0.7,
	petitCadre = 35, petitEtatL = 31.6, petitEtatH = 30.9,
}
G.celluleL = (G.vueL - G.ecartX * (G.colonnes - 1)) / G.colonnes

-- les coins de metal : PortraitFrameTemplate, corrige par camelot (haut-droit
-- et bas-droit x - 2, bas y = -8)
local METAL = {
	{ cle = "hg", nom = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
	{ cle = "hd", nom = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
	{ cle = "bg", nom = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
	{ cle = "bd", nom = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
}

local ENCRE = { 0.18, 0.106, 0.059 }       -- SPELLBOOK_FONT_COLOR
local POLICE = "Fonts\\FRIZQT__.TTF"
local TEXTE = {
	titre = SPELLBOOK or "Spellbook",
	page = "Page %d/%d",                    -- PAGE_NUMBER_WITH_MAX
	passif = SPELL_PASSIVE or "Passive",
	familier = PET or "Pet",
	-- les reglages : SPELLBOOK_FILTER_PASSIVES et SHOW_ALL_SPELL_RANKS de camelot
	masquerPassifs = "Hide Passives",
	tousLesRangs = "Show all spell ranks",
	volants = "Group Similar Spells on Flyouts",   -- SPELLBOOK_USE_FLYOUTS
	passifsDesactives = "Hiding Passives is disabled while searching",   -- SPELLBOOK_SEARCH_HIDE_PASSIVES_DISABLED
}

-- LE MENU DES REGLAGES, en boutons securises. Il reprend la liste du client
-- telle que DropDown.lua l'habille (UIDropDownMenu.lua et
-- UIDropDownMenuTemplates.xml de 3.3.5, releve) : strate DIALOG, ancree
-- TOPLEFT sur le BOTTOMLEFT de la fleche (ToggleDropDownMenu, decalage 0) ;
-- lignes de 20 (UIDROPDOWNMENU_BUTTON_HEIGHT de ForeverUI) a x = 5 + 12 - 6
-- (case, mode MENU) et y = -15 - (n - 1) x 20 ; liste de n x 20 + 2 x 15 de
-- haut et de "texte le plus long + 40 + 25" de large, lignes 25 plus
-- etroites ; texte GameFontHighlightLeft a 20 du bord ; case
-- common-dropdown-ticksquare 12 a gauche, coche jaune 15 x 14 a (2, 1) ;
-- surbrillance UI-QuestTitleHighlight en ADD ; fond common-dropdown-bg-c60
-- en neuf tranches (18 ; 9, 6, 9, 12) a 0,925. Fermeture : 2 s apres la sortie
-- de la souris (UIDROPDOWNMENU_SHOW_TIME), ou la fleche.
local MENU = {
	ligneH = 20, bord = 15, ligneX = 11, texteX = 20, largeurPlus = 40, marge = 25,
	case = 12, cocheL = 15, cocheH = 14, cocheX = 2, cocheY = 1,
	fondCoin = 18, fondMarges = { 9, 6, 9, 12 }, fondAlpha = 0.925, attente = 2,
}
-- les reglages et leur bit dans la combinaison (REG) ; "volants" est coche
-- quand son bit est ABSENT (le bit dit "sans groupes")
local REGLAGES = {
	{ bit = 1, texte = TEXTE.masquerPassifs },
	{ bit = 2, texte = TEXTE.volants, inverse = true },
	{ bit = 4, texte = TEXTE.tousLesRangs },
}
local SEP = string.char(92)
local ROCHE = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock"
local FLECHES = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-SpellbookIcon-"
local SURVOL_CARRE = "Interface" .. SEP .. "Buttons" .. SEP .. "UI-Common-MouseHilight"
local ICONE_CLASSE = "Interface" .. SEP .. "ForeverUI" .. SEP .. "icons" .. SEP .. "classicon_"
-- le portrait : l'icone de la ligne General de camelot (inv_misc_book_09),
-- son masque rond cuit dedans (tools/cuire_masque.py)
local PORTRAIT = "Interface" .. SEP .. "ForeverUI" .. SEP .. "spellbook" .. SEP .. "portrait"

local function reglages()
	ForeverUIDB = ForeverUIDB or {}
	ForeverUIDB.grimoire = ForeverUIDB.grimoire or {}
	return ForeverUIDB.grimoire
end

local function police(fs, taille, c)
	fs:SetFont(POLICE, taille)
	c = c or ENCRE
	fs:SetTextColor(c[1], c[2], c[3])
end

-- ETOUFFER : image, opacite, visibilite, souris -- le code de WotLK remontre
-- ce qu'on se contente de cacher.
local function etouffer(f)
	if not f then return end
	if f.SetTexture then f:SetTexture(nil) end
	f:SetAlpha(0)
	if f.EnableMouse then f:EnableMouse(false) end
	f:Hide()
end

-- ---------------------------------------------------------------- les donnees
-- Les categories de camelot : une par ligne de sorts (Generale, puis une par
-- arbre), plus le familier. La Generale porte l'icone de la classe.
local function categories()
	local liste = {}
	for i = 1, GetNumSpellTabs() do
		local nom, icone, decalage, nombre = GetSpellTabInfo(i)
		if nom then
			if i == 1 then
				local _, classe = UnitClass("player")
				icone = ICONE_CLASSE .. string.lower(classe or "warrior")
			end
			table.insert(liste, { nom = nom, icone = icone, decalage = decalage, nombre = nombre, livre = BOOKTYPE_SPELL })
		end
	end
	local nombrePet = HasPetSpells()
	if nombrePet and nombrePet > 0 then
		table.insert(liste, {
			nom = TEXTE.familier, icone = GetPetIcon and GetPetIcon() or nil,
			decalage = 0, nombre = nombrePet, livre = BOOKTYPE_PET, familier = true,
		})
	end
	return liste
end
S.categories = categories
S.G = G
S.police = police

-- Les sorts d'une categorie. Sans "tous les rangs" (CVar ShowAllSpellRanks),
-- un sort ne garde que son rang le plus haut -- le dernier de la ligne.
-- "Masquer les passifs" (spellBookHidePassives chez camelot, que 3.3.5 n'a
-- pas : retenu dans les reglages de ForeverUI) les retire.
-- `opts` (facultatif) : { passifs = masquer, volants = sans groupes,
-- rangs = tous } -- par defaut, les reglages en cours.
local function optionsCourantes()
	return { passifs = reglages().masquerPassifs and true or false,
		volants = reglages().sansVolants and true or false,
		rangs = GetCVar("ShowAllSpellRanks") == "1" }
end

local function sortsDe(cat, opts)
	opts = opts or optionsCourantes()
	local sorts, dernier = {}, {}
	local tousLesRangs = opts.rangs
	local sansPassifs = opts.passifs
	for slot = cat.decalage + 1, cat.decalage + cat.nombre do
		local nom, rang = GetSpellName(slot, cat.livre)
		local passif = nom and IsPassiveSpell(slot, cat.livre) and true or false
		if nom and not (sansPassifs and passif) then
			local sort = { slot = slot, livre = cat.livre, nom = nom, rang = rang or "", passif = passif,
				icone = GetSpellTexture(slot, cat.livre), familier = cat.familier }
			if not tousLesRangs and dernier[nom] then
				sorts[dernier[nom]] = sort
			else
				table.insert(sorts, sort)
				dernier[nom] = #sorts
			end
		end
	end
	return sorts
end
S.sortsDe = sortsDe

-- ------------------------------------------------------------ les menus volants
-- "Group Similar Spells on Flyouts" (SPELLBOOK_USE_FLYOUTS). Chez camelot, le
-- serveur place dans le grimoire une entree "flyout" ; ses sorts en sont
-- retires (IsSpellBookItemLooseFlyoutMember) et s'ouvrent dans un menu
-- volant. 3.3.5 n'a ni entree ni menu : les groupes sont ceux du client
-- camelot, releves dans SpellFlyout.db2 et SpellFlyoutItem.db2 (nom,
-- description, icone, sorts dans l'ordre de leurs emplacements). N'y sont
-- pas : les deux groupes vides (263, 265) et les deux dont tous les sorts sont
-- propres a camelot (252 Spell Resistances, 257 Weapon Proficiencies).
--
-- APRES chaque liste de camelot, les sorts de classe que Burning Crusade et
-- WotLK ajoutent a ces familles, verifies dans le Spell.dbc du serveur et
-- rattaches a une ligne de classe (SkillLineAbility.dbc).
--
-- Un sort appartient a un groupe PAR SON NOM : GetSpellInfo(id) le donne pour
-- chaque identifiant releve, et les rangs que 3.3.5 ajoute (Burning Crusade,
-- WotLK) suivent ainsi le rang d'origine. Les identifiants propres a camelot
-- (au-dela d'un million) n'existent pas ici et ne comptent pas.
local VOLANTS = {
	-- Portails et teleportations : un groupe par faction (le masque de race de
	-- SpellFlyout). APRES la liste de camelot, les villes que Burning Crusade
	-- et WotLK ajoutent, verifiees dans le Spell.dbc du serveur : Exodar /
	-- Silvermoon, Shattrath (un sort par faction), Theramore / Stonard,
	-- Dalaran (le meme pour les deux).
	{ id = 248, nom = "Portal", icone = "spell_arcane_portalstormwind", faction = "Alliance",
		texte = "Creates a portal, teleporting group members who use it to a major city.",
		sorts = { 11419, 11416, 10059, 32266, 33691, 49360, 53142 } },
	{ id = 249, nom = "Portal", icone = "spell_arcane_portalorgrimmar", faction = "Horde",
		texte = "Creates a portal, teleporting group members who use it to a major city.",
		sorts = { 11417, 11420, 11418, 32267, 35717, 49361, 53142 } },
	{ id = 250, nom = "Teleport", icone = "spell_arcane_teleportstormwind", faction = "Alliance",
		texte = "Teleports you to a major city.",
		sorts = { 3565, 3562, 3561, 1297659, 32271, 33690, 49359, 53140 } },
	{ id = 251, nom = "Teleport", icone = "spell_arcane_teleportorgrimmar", faction = "Horde",
		texte = "Teleports you to a major city.",
		sorts = { 3567, 3566, 3563, 1297659, 32272, 35715, 49358, 53140 } },
	{ id = 253, nom = "Aspect", icone = "ability_hunter_aspectmastery",
		texte = "Take on aspects of nature.",
		sorts = { 13163, 13165, 14318, 14319, 14320, 14321, 14322, 25296, 5118, 13161,
			1299445, 1299446, 1299447, 13159, 20043, 20190,
			34074, 61846 } },                        -- + Viper, Dragonhawk
	{ id = 259, nom = "Summon Demon", icone = "spell_shadow_summonimp",
		texte = "Summons a Demon under the command of the Warlock",
		sorts = { 688, 697, 712, 713, 691,
			30146 } },                               -- + Felguard
	{ id = 261, nom = "Imp Spells", icone = "spell_fire_firebolt",
		texte = "[PH] Commands the Imp to cast spells",
		sorts = { 20801, 6307, 2949, 4511 } },
	{ id = 262, nom = "Shapeshift", icone = "ability_racial_bearform",
		texte = "Shapeshift into a different form.",
		sorts = { 5487, 9634, 1066, 768, 783, 24858,
			33943, 40120, 33891 } },                 -- + Flight, Swift Flight, Tree of Life
	{ id = 264, nom = "Blessings", icone = "spell_magic_magearmor",
		texte = "Places a Blessing on friendly targets.",
		-- 1038 (Blessing of Salvation chez camelot) est devenu Hand of
		-- Salvation : il passe avec les autres Hand, dans Utility Blessings
		sorts = { 20217, 25291, 19838, 19837, 19836, 19835, 19834, 19740, 25290,
			19854, 19853, 19852, 19850, 19742, 19979, 19978, 19977,
			20911 } },                               -- + Sanctuary
	{ id = 267, nom = "Pet Utilities", icone = "ability_hunter_beasttaming",
		texte = "Manage your pets.",
		sorts = { 883, 982, 6991, 2641, 1515, 1462, 5149 } },
	{ id = 268, nom = "Tracking", icone = "ability_tracking",
		texte = "Track your quarry.",
		sorts = { 1494, 19878, 19879, 19880, 19882, 19885, 19883, 19884 } },
	{ id = 269, nom = "Stances", icone = "ability_warrior_offensivestance",
		texte = "Activate a combat stance.",
		sorts = { 2457, 71, 2458 } },
	{ id = 270, nom = "Auras", icone = "spell_holy_devotionaura",
		texte = "Activate a protective aura for your group.",
		sorts = { 10301, 10300, 10299, 10298, 7294, 10293, 10292, 1032, 10291, 643,
			10290, 465, 19746, 20218, 19900, 19899, 19891, 19898, 19897, 19888,
			19896, 19895, 19876,
			32223 } },                               -- + Crusader Aura
	{ id = 272, nom = "Greater Blessings", icone = "spell_holy_greaterblessingofkings",
		texte = "Blessings that target all members of your group that share the same class.",
		sorts = { 25895, 25898, 25916, 25782, 25918, 25894, 25890,
			25899 } },                               -- + Greater Sanctuary
	{ id = 273, nom = "Utility Blessings", icone = "spell_holy_sealofvalor",
		texte = "Short duration Blessings used to save a single target.",
		sorts = { 10278, 5599, 1022, 1044, 20729, 6940,
			1038 } },                                -- + Hand of Salvation
	-- DEUX GROUPES QUE CAMELOT N'A PAS (demande du 2026-09-25) : les sceaux et
	-- les jugements du paladin, que son client classique ne groupe pas. Ni
	-- identifiant, ni description, ni icone propre : le groupe prend celle
	-- de son premier sort. Sorts verifies dans Spell.dbc et SkillLineAbility.
	{ nom = "Seals",
		sorts = { 21084, 20164, 20165, 20166, 20375, 31801, 53736 } },
	{ nom = "Judgements",
		sorts = { 20271, 53408, 53407 } },
}
S.VOLANTS = VOLANTS

-- nom du sort -> { groupe, rang du nom dans le groupe }, resolu une fois
-- (un nom peut servir a deux groupes : Dalaran est dans ceux des deux
-- factions ; on garde celui de la faction du joueur)
local parNom
local function volantDe(nom)
	if not parNom then
		parNom = {}
		for _, v in ipairs(VOLANTS) do
			local ordre, vus = 0, {}
			for _, id in ipairs(v.sorts) do
				local n = GetSpellInfo(id)
				if n and not vus[n] then
					vus[n] = true
					ordre = ordre + 1
					parNom[n] = parNom[n] or {}
					table.insert(parNom[n], { volant = v, ordre = ordre })
				end
			end
		end
	end
	local faction = UnitFactionGroup("player")
	for _, m in ipairs(parNom[nom] or {}) do
		if not m.volant.faction or m.volant.faction == faction then
			return m
		end
	end
end

-- Les groupes d'UNE categorie : un groupe ne reunit que des sorts d'un meme
-- onglet (les postures du guerrier, chacune dans son arbre, restent seules ;
-- les portails et teleportations du mage, tous dans le meme, se groupent).
-- Il lui faut au moins deux sorts DIFFERENTS -- deux rangs d'un meme sort ne
-- font pas un groupe. Ses sorts suivent l'ordre du groupe.
local function groupesDe(sorts)
	local groupes = {}
	for _, sort in ipairs(sorts) do
		local m = volantDe(sort.nom)
		if m then
			local g = groupes[m.volant]
			if not g then
				g = { membres = {}, noms = {}, differents = 0 }
				groupes[m.volant] = g
			end
			sort.ordre = m.ordre
			table.insert(g.membres, sort)
			if not g.noms[sort.nom] then
				g.noms[sort.nom] = true
				g.differents = g.differents + 1
			end
		end
	end
	for v, g in pairs(groupes) do
		if g.differents < 2 then
			groupes[v] = nil
		else
			table.sort(g.membres, function(a, b)
				if a.ordre ~= b.ordre then return a.ordre < b.ordre end
				return a.slot < b.slot
			end)
		end
	end
	return groupes
end

-- Ce que montre une categorie : ses sorts, et -- si l'on groupe -- chaque
-- groupe a la place de son premier sort, ses membres retires. Le familier
-- n'est pas groupe.
local function listeAffichee(cats, index, opts)
	opts = opts or optionsCourantes()
	local cat = cats[index]
	if not cat then return {} end
	local sorts = sortsDe(cat, opts)
	if cat.familier or opts.volants then
		return sorts
	end
	local groupes = groupesDe(sorts)
	local liste, poses = {}, {}
	for _, sort in ipairs(sorts) do
		local m = volantDe(sort.nom)
		local g = m and groupes[m.volant]
		if not g then
			table.insert(liste, sort)
		elseif not poses[m.volant] then
			poses[m.volant] = true
			local v = m.volant
			local icone = v.icone and ("Interface" .. SEP .. "Icons" .. SEP .. v.icone) or g.membres[1].icone
			table.insert(liste, { volant = v, nom = v.nom, rang = "", passif = false,
				icone = icone, membres = g.membres })
		end
	end
	return liste
end
S.listeAffichee = listeAffichee
S.optionsCourantes = optionsCourantes

-- ------------------------------------------------------------ la mise en page
-- PagedCondensedVerticalGrid : l'en-tete prend sa rangee -- et la reprend en
-- tete de chaque vue suivante de la categorie --, puis les sorts
-- remplissent les colonnes une a une sur ceil(restants / 3) rangees, dans la
-- place qui reste ; une vue pleine en ouvre une autre, et le compte des
-- rangees repart des sorts restants. Rend la liste des vues, chacune une
-- liste d'elements { en-tete ou sort, colonne, y }.
--
-- PLUSIEURS SECTIONS (les resultats d'une recherche) : chacune garde ses
-- rangees ; une section qui commence sur une vue deja remplie est precedee
-- de l'espaceur de camelot (spacerSize 20 + yPadding 10), et passe a la vue
-- suivante s'il n'y a plus la place de son en-tete et d'une rangee.
local function mettreEnPageGroupes(groupes)
	local vues = {}
	local vue, occupe
	local pas = G.sortH + G.ecartY
	local function nouvelleVue(titre)
		vue = {}
		table.insert(vues, vue)
		occupe = 0
		if titre then
			table.insert(vue, { entete = titre, colonne = 1, y = 0 })
			occupe = G.enteteH + G.ecartY
		end
	end
	for _, g in ipairs(groupes) do
		local titre, sorts = g.titre, g.sorts
		if not vue then
			nouvelleVue(titre)
		elseif occupe + G.espace + G.ecartY + G.enteteH + G.ecartY + pas > G.vueH then
			nouvelleVue(titre)
		else
			occupe = occupe + G.espace + G.ecartY
			if titre then
				table.insert(vue, { entete = titre, colonne = 1, y = occupe })
				occupe = occupe + G.enteteH + G.ecartY
			end
		end
		local i = 1
		while i <= #sorts do
			local dispo = math.floor((G.vueH - occupe) / pas)
			if dispo < 1 then
				nouvelleVue(titre)
				dispo = math.floor((G.vueH - occupe) / pas)
			end
			local restants = #sorts - i + 1
			local rangees = math.min(math.ceil(restants / G.colonnes), dispo)
			for colonne = 1, G.colonnes do
				for r = 1, rangees do
					if i <= #sorts then
						table.insert(vue, { sort = sorts[i], colonne = colonne, y = occupe + (r - 1) * pas })
						i = i + 1
					end
				end
			end
			occupe = occupe + rangees * pas
			if i <= #sorts then
				nouvelleVue(titre)
			end
		end
	end
	if not vue then nouvelleVue(nil) end
	return vues
end
S.mettreEnPageGroupes = mettreEnPageGroupes

local function mettreEnPage(titre, sorts)
	return mettreEnPageGroupes({ { titre = titre, sorts = sorts } })
end
S.mettreEnPage = mettreEnPage

-- --------------------------------------------------------------- les cases
local function atlas(t, nom, garder)
	return ForeverUI.SetAtlas(t, nom, garder)
end

-- un sort : un cadre porteur (fond, textes) et, dedans, le bouton securise
-- de l'icone
local function creerCase(vue, n)
	local c = CreateFrame("Frame", nil, vue)
	c:SetWidth(G.celluleL)
	c:SetHeight(G.sortH)
	local fond = c:CreateTexture(nil, "BACKGROUND")
	atlas(fond, "spellbook-item-backplate")
	fond:SetPoint("CENTER", c, "CENTER", 5, -5)
	fond:SetAlpha(0.25)
	c.fond = fond

	local b = CreateFrame("Button", "ForeverUISpellBookButton" .. n, c, "SecureActionButtonTemplate")
	b:SetWidth(G.boutonCote)
	b:SetHeight(G.boutonCote)
	b:SetPoint("LEFT", c, "LEFT", 0, 0)
	b:RegisterForClicks("AnyUp")
	b:RegisterForDrag("LeftButton")
	-- le numero de la case : le bloc securise des groupes le rend a
	-- ForeverUIVolant
	b:SetID(n)
	-- le clic modifie donne le lien dans la discussion, pas le sort
	b:SetAttribute("shift-type1", "lien")
	local icone = b:CreateTexture(nil, "ARTWORK")
	icone:SetWidth(G.iconeCote)
	icone:SetHeight(G.iconeCote)
	icone:SetPoint("CENTER", b, "CENTER", 0, 0)
	local ombre = b:CreateTexture(nil, "ARTWORK")
	atlas(ombre, "spellbook-item-iconframe-shadow", true)
	ombre:SetPoint("TOPLEFT", b, "TOPLEFT", -12, 3)
	ombre:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -8)
	local cadre = b:CreateTexture(nil, "OVERLAY")
	local survol = b:CreateTexture(nil, "OVERLAY")
	survol:SetAllPoints(b)
	survol:SetBlendMode("ADD")
	survol:SetAlpha(0.35)
	survol:Hide()
	local auto = b:CreateTexture(nil, "OVERLAY")
	atlas(auto, "spellbook-item-petautocast-corners", true)
	auto:SetAllPoints(icone)
	auto:Hide()
	local recharge = CreateFrame("Cooldown", "ForeverUISpellBookButton" .. n .. "Cooldown", b, "CooldownFrameTemplate")
	recharge:SetPoint("TOPLEFT", icone, "TOPLEFT", 2, -2)
	recharge:SetPoint("BOTTOMRIGHT", icone, "BOTTOMRIGHT", -2, 2)
	-- la fleche d'un menu volant (FlyoutButtonTemplate, Arrow)
	local fleche = b:CreateTexture(nil, "OVERLAY")
	fleche:Hide()
	b.icone, b.ombre, b.cadre, b.survol, b.auto, b.recharge = icone, ombre, cadre, survol, auto, recharge
	b.fleche = fleche

	-- les textes
	local nom = c:CreateFontString(nil, "ARTWORK")
	police(nom, 16)
	nom:SetJustifyH("LEFT")
	nom:SetWidth(G.celluleL - G.texteX)
	local sous = c:CreateFontString(nil, "ARTWORK")
	police(sous, 12)
	sous:SetJustifyH("LEFT")
	sous:SetWidth(G.celluleL - G.texteX)
	c.nom, c.sous = nom, sous

	b:SetScript("OnEnter", function(self)
		c.fond:SetAlpha(1)
		self.survol:Show()
		self.survole = true
		local sort = c.sort
		if sort and sort.volant then
			-- le groupe : son nom et sa description (SpellFlyout.db2)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(sort.nom, 1, 1, 1)
			if sort.volant.texte then GameTooltip:AddLine(sort.volant.texte, nil, nil, nil, 1) end
			GameTooltip:Show()
			S.poserFleche(self)
		elseif sort then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetSpell(sort.slot, sort.livre)
			GameTooltip:Show()
		end
	end)
	b:SetScript("OnLeave", function(self)
		self.survole, self.enfonce = nil, nil
		c.fond:SetAlpha(0.25)
		self.survol:Hide()
		GameTooltip:Hide()
		if c.sort and c.sort.volant then S.poserFleche(self) end
	end)
	b:SetScript("OnMouseDown", function(self)
		self.enfonce = true
		self.survol:SetAlpha(0.65)
		if c.sort and c.sort.volant then S.poserFleche(self) end
	end)
	b:SetScript("OnMouseUp", function(self)
		self.enfonce = nil
		self.survol:SetAlpha(0.35)
		if c.sort and c.sort.volant then S.poserFleche(self) end
	end)
	b:SetScript("OnDragStart", function(self)
		local sort = c.sort
		-- un groupe ne va pas sur une barre : 3.3.5 n'y a pas de menu volant
		if sort and not sort.volant then PickupSpell(sort.slot, sort.livre) end
		self.enfonce = nil
	end)
	-- SpellButton_OnModifiedClick : le lien du sort. Un groupe s'ouvre par le
	-- bloc securise enveloppe autour de OnClick (S.publier).
	b:SetScript("PostClick", function(self, souris)
		local sort = c.sort
		if sort and not sort.volant and IsModifiedClick("CHATLINK") then
			local lien = GetSpellLink(sort.slot, sort.livre)
			if lien then ChatEdit_InsertLink(lien) end
		end
	end)
	c.bouton = b
	c:Hide()
	return c
end

-- UpdateVisuals : cadre carre ou rond, textes, recharge, lancement
-- automatique. Rien de protege : appele en combat par ForeverUIVisuels.
local function remplirCase(c, sort)
	c.sort = sort
	local b = c.bouton
	if sort.passif then
		SetPortraitToTexture(b.icone, sort.icone)
		b.icone:SetTexCoord(0, 1, 0, 1)
		atlas(b.cadre, "talents-node-circle-gray", true)
		b.cadre:ClearAllPoints()
		b.cadre:SetAllPoints(b)
		atlas(b.survol, "spellbook-item-iconframe-passive-hover", true)
		-- un passif n'a que son icone ronde : pas l'ombre carree d'un actif
		b.ombre:Hide()
	else
		b.ombre:Show()
		b.icone:SetTexture(sort.icone)
		b.icone:SetTexCoord(0, 1, 0, 1)
		atlas(b.cadre, "spellbook-item-iconframe-c60", true)
		b.cadre:ClearAllPoints()
		b.cadre:SetPoint("TOPLEFT", b, "TOPLEFT", -11, 1)
		b.cadre:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -7)
		atlas(b.survol, "spellbook-item-iconframe-hover", true)
	end
	c.nom:SetText(sort.nom)
	local sousTitre = sort.rang
	if sousTitre == "" and sort.passif then sousTitre = TEXTE.passif end
	c.sous:SetText(sousTitre)
	-- le bloc de texte, centre sur la case a (50, -1)
	local hNom = c.nom:GetHeight() or 0
	local hSous = (sousTitre ~= "" and (c.sous:GetHeight() or 0)) or 0
	local total = hNom + (hSous > 0 and (2 + hSous) or 0)
	c.nom:ClearAllPoints()
	c.nom:SetPoint("TOPLEFT", c, "LEFT", G.texteX, total / 2 - 1)
	c.sous:ClearAllPoints()
	c.sous:SetPoint("TOPLEFT", c.nom, "BOTTOMLEFT", 0, -2)
	if sousTitre == "" then c.sous:Hide() else c.sous:Show() end

	if sort.volant then
		b.fleche:Show()
		S.poserFleche(b)
	else
		b.fleche:Hide()
	end
	S.majEtat(c)
end

-- "Nom(Rang N)" : ce que SecureActionButton passe a CastSpellByName
function S.texteDuSort(sort)
	local texte = sort.nom
	if sort.rang ~= "" and not sort.familier then texte = texte .. "(" .. sort.rang .. ")" end
	return texte
end

-- la recharge et le lancement automatique, sans toucher aux attributs
function S.majEtat(c)
	local sort = c.sort
	if not sort then return end
	local b = c.bouton
	if sort.volant then
		if CooldownFrame_SetTimer then CooldownFrame_SetTimer(b.recharge, 0, 0, 0) end
		b.auto:Hide()
		return
	end
	local debut, duree, actif = GetSpellCooldown(sort.slot, sort.livre)
	if CooldownFrame_SetTimer and debut then
		CooldownFrame_SetTimer(b.recharge, debut, duree, actif)
	end
	if sort.familier then
		local permis, allume = GetSpellAutocast(sort.slot, sort.livre)
		if permis and allume then b.auto:Show() else b.auto:Hide() end
	else
		b.auto:Hide()
	end
end

-- ------------------------------------------------------------ le menu volant
-- SetClampedTextureRotation a 90 ou 270, sur un element d'atlas : la forme a
-- huit arguments de SetTexCoord (SetRotation effacerait le rectangle), les
-- cotes echanges.
local function tournerAtlas(t, nom, degres, largeur, hauteur)
	local e = ForeverUI.AtlasEntry(nom)
	if not e then return end
	t:SetTexture(e[1])
	local u1, u2, v1, v2 = e[2], e[3], e[4], e[5]
	if degres == 90 then
		t:SetTexCoord(u1, v2, u2, v2, u1, v1, u2, v1)
	else
		t:SetTexCoord(u2, v1, u1, v1, u2, v2, u1, v2)
	end
	t:SetWidth(hauteur)
	t:SetHeight(largeur)
end

-- FlyoutButtonMixin : fleche normale, survolee ou enfoncee ; tournee vers la
-- droite (90) ferme, retournee (270) ouvert, a 4 ou 2 du bord droit
function S.poserFleche(b)
	local ouvert = S.volantOuvert == b
	local nom = "ui-hud-actionbar-flyout"
	if b.enfonce then
		nom = nom .. "-down"
	elseif b.survole then
		nom = nom .. "-mouseover"
	end
	tournerAtlas(b.fleche, nom, ouvert and 270 or 90, G.flecheL, G.flecheH)
	b.fleche:ClearAllPoints()
	b.fleche:SetPoint("RIGHT", b, "RIGHT", ouvert and G.flecheOuvert or G.flecheFerme, 0)
end

-- SpellFlyoutPopupButtonTemplate : le petit bouton d'action (30, cadre et
-- enfonce 35 centres, survol 31,6 x 30,9), securise pour lancer
local function creerPetit(volant, n)
	local b = CreateFrame("Button", "ForeverUISpellFlyoutButton" .. n, volant, "SecureActionButtonTemplate")
	b:SetWidth(G.petitCote)
	b:SetHeight(G.petitCote)
	b:RegisterForClicks("AnyUp")
	b:RegisterForDrag("LeftButton")
	b:SetAttribute("type1", "spell")
	b:SetAttribute("shift-type1", "lien")
	-- sa place ne change jamais : le bloc securise ne fait que le montrer
	b:SetPoint("LEFT", volant, "LEFT", G.volantDebut + (n - 1) * (G.petitCote + G.volantEcart), 0)
	b:Hide()
	local icone = b:CreateTexture(nil, "BORDER")
	icone:SetAllPoints(b)
	b.icone = icone
	local function etat(t, nom, l, h, add)
		ForeverUI.SetAtlas(t, nom, true)
		t:SetWidth(l)
		t:SetHeight(h)
		t:ClearAllPoints()
		t:SetPoint("CENTER", b, "CENTER", 0, 0)
		if add then t:SetBlendMode("ADD") end
	end
	local e = ForeverUI.AtlasEntry("ui-hud-actionbar-iconframe")
	b:SetNormalTexture(e and e[1] or "")
	etat(b:GetNormalTexture(), "ui-hud-actionbar-iconframe", G.petitCadre, G.petitCadre)
	b:SetPushedTexture(e and e[1] or "")
	etat(b:GetPushedTexture(), "ui-hud-actionbar-iconframe-down", G.petitCadre, G.petitCadre)
	b:SetHighlightTexture(e and e[1] or "")
	etat(b:GetHighlightTexture(), "ui-hud-actionbar-iconframe-mouseover", G.petitEtatL, G.petitEtatH)
	-- le COCHE : le survol en ADD, montre pendant que le sort est en cours
	local coche = b:CreateTexture(nil, "OVERLAY")
	etat(coche, "ui-hud-actionbar-iconframe-mouseover", G.petitEtatL, G.petitEtatH, true)
	coche:Hide()
	b.coche = coche
	b.recharge = CreateFrame("Cooldown", "ForeverUISpellFlyoutButton" .. n .. "Cooldown", b, "CooldownFrameTemplate")
	b.recharge:SetAllPoints(icone)

	b:SetScript("OnEnter", function(self)
		if not self.sort then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 4, 4)
		GameTooltip:SetSpell(self.sort.slot, self.sort.livre)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b:SetScript("OnDragStart", function(self)
		if self.sort then PickupSpell(self.sort.slot, self.sort.livre) end
	end)
	-- SpellFlyoutPopupButtonMixin:OnClick : le lien ici ; le sort puis la
	-- fermeture du menu passent par le bloc securise (S.publier)
	b:SetScript("PostClick", function(self)
		if self.sort and IsModifiedClick("CHATLINK") then
			local lien = GetSpellLink(self.sort.slot, self.sort.livre)
			if lien then ChatEdit_InsertLink(lien) end
		end
	end)
	return b
end

local function majPetit(b)
	local sort = b.sort
	if not sort then return end
	local debut, duree, actif = GetSpellCooldown(sort.slot, sort.livre)
	if CooldownFrame_SetTimer and debut then
		CooldownFrame_SetTimer(b.recharge, debut, duree, actif)
	end
	if IsCurrentSpell and IsCurrentSpell(sort.slot, sort.livre) then b.coche:Show() else b.coche:Hide() end
end

-- FlyoutPopupTemplate, ouvert a droite : le bout de depart (FlyoutBottom) a
-- gauche, le milieu (FlyoutMidLeft), le bout (FlyoutButton) a droite ; les
-- deux bouts tournes de 90
local function construireVolant(livre)
	local volant = CreateFrame("Frame", "ForeverUISpellFlyout", livre)
	volant:SetFrameStrata("DIALOG")
	volant:EnableMouse(true)
	volant:SetHeight(G.volantH)
	volant:Hide()
	local debut = volant:CreateTexture(nil, "BACKGROUND")
	tournerAtlas(debut, "ui-hud-actionbar-iconframe-flyoutbottom", 90, 47, 5)
	debut:SetHeight(G.volantH)
	debut:SetPoint("LEFT", volant, "LEFT", 0, 0)
	local fin = volant:CreateTexture(nil, "BACKGROUND")
	tournerAtlas(fin, "ui-hud-actionbar-iconframe-flyoutbutton", 90, 47, 29)
	fin:SetHeight(G.volantH)
	fin:SetPoint("RIGHT", volant, "RIGHT", 0, 0)
	local milieu = volant:CreateTexture(nil, "BACKGROUND")
	atlas(milieu, "_ui-hud-actionbar-iconframe-flyoutmidleft", true)
	milieu:SetHeight(G.volantH)
	milieu:SetPoint("LEFT", debut, "RIGHT", 0, 0)
	milieu:SetPoint("RIGHT", fin, "LEFT", 0, 0)
	for _, t in ipairs({ debut, milieu, fin }) do
		t:SetVertexColor(G.volantTeinte, G.volantTeinte, G.volantTeinte)
	end
	volant.boutons = {}
	-- ferme par qui que ce soit (page, livre, categorie) : la fleche suit
	volant:SetScript("OnHide", function()
		local b = S.volantOuvert
		S.volantOuvert = nil
		if b then S.poserFleche(b) end
	end)
	S.volant = volant
	return volant
end

-- ForeverUIVolant, appele par le bloc securise d'un groupe (CallMethod) :
-- les images des petits boutons et la fleche. Rien de protege.
function S.volantOuvertPar(k, vk)
	local ancien = S.volantOuvert
	local c = S.cases and S.cases[k]
	local membres = S.volantsDonnees and S.volantsDonnees[vk]
	if not c or not membres then return end
	S.volantOuvert = c.bouton
	if ancien and ancien ~= c.bouton then S.poserFleche(ancien) end
	for i, p in ipairs(S.volant.boutons) do
		p.sort = membres[i]
		if p.sort then
			p.icone:SetTexture(p.sort.icone)
			majPetit(p)
		end
	end
	S.poserFleche(c.bouton)
end

-- l'en-tete d'une categorie (SpellBookHeaderTemplate)
local function creerEntete(vue)
	local h = CreateFrame("Frame", nil, vue)
	h:SetWidth(G.vueL)
	h:SetHeight(G.enteteH)
	local fond = h:CreateTexture(nil, "BACKGROUND")
	atlas(fond, "spellbook-list-backplate", true)
	fond:SetWidth(416)
	fond:SetHeight(106)
	fond:SetPoint("LEFT", h, "LEFT", -85, 10)
	fond:SetAlpha(0.65)
	local texte = h:CreateFontString(nil, "ARTWORK")
	police(texte, 24)
	texte:SetJustifyH("LEFT")
	texte:SetPoint("TOPLEFT", h, "TOPLEFT", -8, 0)
	texte:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -60, 0)
	local trait = h:CreateTexture(nil, "ARTWORK")
	atlas(trait, "spellbook-divider", true)
	trait:SetHeight(11)
	trait:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT", -32, 0)
	trait:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -60, 0)
	h.texte = texte
	h:Hide()
	return h
end

-- ------------------------------------------------------------ le cadre
-- LA CROIX PAR-DESSUS LE LIVRE. Elle n'est pas sa fille : son niveau se
-- repose donc a chaque ouverture, au-dessus du metal (+20) et du titre (+21).
function S.leverCroix()
	local fermer, livre = SpellBookCloseButton, S.livre
	if not fermer or not livre then return end
	fermer:SetFrameStrata(livre:GetFrameStrata())
	fermer:SetFrameLevel(livre:GetFrameLevel() + 22)
end

local function boutonRouge(parent, normal, presse, gabarit)
	local b = CreateFrame("Button", nil, parent, gabarit)
	b:SetWidth(G.rougeCote)
	b:SetHeight(G.rougeCote)
	local e = ForeverUI.AtlasEntry(normal)
	b:SetNormalTexture(e and e[1] or "")
	atlas(b:GetNormalTexture(), normal, true)
	b:SetPushedTexture(e and e[1] or "")
	atlas(b:GetPushedTexture(), presse, true)
	b:SetHighlightTexture(e and e[1] or "")
	atlas(b:GetHighlightTexture(), "redbutton-highlight", true)
	b:GetHighlightTexture():SetBlendMode("ADD")
	return b
end

local function construireCadre(livre)
	-- le fond de roche et le metal (PortraitFrameTemplate)
	local roche = livre:CreateTexture(nil, "BACKGROUND")
	roche:SetTexture(ROCHE, true)
	if roche.SetHorizTile then roche:SetHorizTile(true) roche:SetVertTile(true) end
	roche:SetPoint("TOPLEFT", livre, "TOPLEFT", 2, -21)
	roche:SetPoint("BOTTOMRIGHT", livre, "BOTTOMRIGHT", -2, 2)

	local metal = CreateFrame("Frame", nil, livre)
	metal:SetAllPoints(livre)
	metal:SetFrameLevel(livre:GetFrameLevel() + 20)
	local p = {}
	for _, coin in ipairs(METAL) do
		local t = metal:CreateTexture(nil, "OVERLAY")
		atlas(t, coin.nom)
		t:SetPoint(coin.point, metal, coin.point, coin.x, coin.y)
		p[coin.cle] = t
	end
	local function bord(nom, a1, c1, r1, a2, c2, r2)
		local t = metal:CreateTexture(nil, "OVERLAY")
		atlas(t, nom)
		t:SetPoint(a1, c1, r1)
		t:SetPoint(a2, c2, r2)
	end
	bord("_ui-frame-metal-edgetop", "TOPLEFT", p.hg, "TOPRIGHT", "TOPRIGHT", p.hd, "TOPLEFT")
	bord("_ui-frame-metal-edgebottom", "BOTTOMLEFT", p.bg, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bd, "BOTTOMLEFT")
	bord("!ui-frame-metal-edgeleft", "TOPLEFT", p.hg, "BOTTOMLEFT", "BOTTOMLEFT", p.bg, "TOPLEFT")
	bord("!ui-frame-metal-edgeright", "TOPRIGHT", p.hd, "BOTTOMRIGHT", "BOTTOMRIGHT", p.bd, "TOPRIGHT")

	-- le portrait (PortraitContainer, sous le metal), rond
	local cadrePortrait = CreateFrame("Frame", nil, livre)
	cadrePortrait:SetAllPoints(livre)
	cadrePortrait:SetFrameLevel(livre:GetFrameLevel() + 19)
	local portrait = cadrePortrait:CreateTexture(nil, "OVERLAY")
	portrait:SetWidth(G.portraitCote)
	portrait:SetHeight(G.portraitCote)
	portrait:SetPoint("TOPLEFT", livre, "TOPLEFT", G.portraitX, G.portraitY)
	portrait:SetTexture(PORTRAIT)
	livre.portrait = portrait

	-- le titre (TitleContainer, au-dessus du metal)
	local bandeau = CreateFrame("Frame", nil, livre)
	bandeau:SetFrameLevel(livre:GetFrameLevel() + 21)
	bandeau:SetHeight(G.titreH)
	bandeau:SetPoint("TOPLEFT", livre, "TOPLEFT", G.titreX1, G.titreY)
	bandeau:SetPoint("TOPRIGHT", livre, "TOPRIGHT", G.titreX2, G.titreY)
	local titre = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titre:SetPoint("TOP", bandeau, "TOP", 0, -5)
	titre:SetText(TEXTE.titre)
	livre.titre = titre
	livre.bandeau = bandeau

	-- la croix : celle de WotLK, rhabillee. Elle reste l'enfant de
	-- SpellBookFrame : son OnClick ferme SON PARENT (HideUIPanel), et la
	-- fermeture ne passe ainsi jamais par notre code.
	local fermer = SpellBookCloseButton
	if fermer then
		S.leverCroix()
		fermer:SetWidth(G.rougeCote)
		fermer:SetHeight(G.rougeCote)
		fermer:SetHitRectInsets(0, 0, 0, 0)
		for _, etat in ipairs({ { "Normal", "redbutton-exit" }, { "Pushed", "redbutton-exit-pressed" },
			{ "Highlight", "redbutton-highlight" } }) do
			local e = ForeverUI.AtlasEntry(etat[2])
			local t = fermer["Get" .. etat[1] .. "Texture"](fermer)
			if not t and e then
				fermer["Set" .. etat[1] .. "Texture"](fermer, e[1])
				t = fermer["Get" .. etat[1] .. "Texture"](fermer)
			end
			if t then
				atlas(t, etat[2], true)
				t:ClearAllPoints()
				t:SetAllPoints(fermer)
			end
		end
		fermer:ClearAllPoints()
		fermer:SetPoint("TOPRIGHT", livre, "TOPRIGHT", G.fermerX, G.fermerY)
	end

	-- agrandir / reduire (MaximizeMinimizeButtonFrameTemplate), a gauche
	-- il dit au controleur de changer de mode (SecureHandlerClickTemplate) :
	-- en combat aussi
	local taille = boutonRouge(livre, "redbutton-condense", "redbutton-condense-pressed", "SecureHandlerClickTemplate")
	taille:SetFrameLevel(livre:GetFrameLevel() + 22)
	if fermer then
		taille:SetPoint("RIGHT", fermer, "LEFT", 0, 0)
	else
		taille:SetPoint("TOPRIGHT", livre, "TOPRIGHT", G.fermerX - G.rougeCote, G.fermerY)
	end
	taille:SetAttribute("_onclick", [==[ self:GetFrameRef("ctrl"):SetAttribute("taille", 1) ]==])
	taille:HookScript("OnClick", function() PlaySound("igMainMenuOptionCheckBoxOn") end)
	livre.taille = taille
end

local function construire()
	if S.livre or not SpellBookFrame then
		return S.livre
	end
	-- le panneau de WotLK n'attrape plus la souris : il est vide
	SpellBookFrame:EnableMouse(false)

	local livre = CreateFrame("Frame", "ForeverUISpellBookFrame", SpellBookFrame)
	livre:SetPoint("TOP", UIParent, "TOP", 0, G.haut)
	livre:SetHeight(G.hauteur)
	livre:SetWidth(G.largeur)
	livre:EnableMouse(true)
	-- PAS de SetToplevel ici : un livre qui se leve seul passerait par-dessus
	-- la croix, sa soeur. SpellBookFrame, lui, est toplevel, et les leve
	-- ensemble.
	S.livre = livre
	construireCadre(livre)

	-- le livre ouvert : deux pages, ou une en reduit
	local pages = CreateFrame("Frame", "ForeverUISpellBookPages", livre)
	pages:SetPoint("BOTTOMLEFT", livre, "BOTTOMLEFT", 0, G.livreBas)
	pages:SetHeight(G.livreH)
	pages:SetWidth(G.livreL)
	local gauche = pages:CreateTexture(nil, "BACKGROUND")
	atlas(gauche, "spellbook-page-left-c60-2x", true)
	gauche:SetPoint("TOPLEFT", pages, "TOPLEFT", 0, 0)
	gauche:SetPoint("BOTTOMRIGHT", pages, "BOTTOM", 0, 0)
	local droite = pages:CreateTexture(nil, "BACKGROUND")
	atlas(droite, "spellbook-page-right-c60-2x", true)
	droite:SetPoint("TOPLEFT", pages, "TOP", 0, 0)
	droite:SetPoint("BOTTOMRIGHT", pages, "BOTTOMRIGHT", 0, 0)
	local seule = pages:CreateTexture(nil, "BACKGROUND")
	atlas(seule, "spellbook-page-right-c60-2x", true)
	seule:SetAllPoints(pages)
	seule:Hide()
	pages.gauche, pages.droite, pages.seule = gauche, droite, seule
	S.pages = pages

	-- les onglets des categories
	local onglets = CreateFrame("Frame", nil, pages)
	onglets:SetPoint("TOPLEFT", pages, "TOPLEFT", G.ongletsX, G.ongletsY)
	onglets:SetWidth(1)
	onglets:SetHeight(G.ongletH)
	onglets.boutons = {}
	S.onglets = onglets

	-- les deux vues ; le contenu tourne les pages a la roulette, par un bloc
	-- securise (SecureHandlerMouseWheelTemplate)
	local contenu = CreateFrame("Frame", "ForeverUISpellBookContent", pages, "SecureHandlerMouseWheelTemplate")
	contenu:SetPoint("TOPLEFT", pages, "TOPLEFT", 0, G.pagesHaut)
	contenu:SetPoint("BOTTOMRIGHT", pages, "BOTTOMRIGHT", 0, 0)
	S.contenu = contenu
	S.vues = {}
	S.cases = {}
	for v = 1, 2 do
		local vue = CreateFrame("Frame", "ForeverUISpellBookView" .. v, contenu)
		vue:SetWidth(G.vueL)
		vue:SetHeight(G.vueH)
		if v == 1 then
			vue:SetPoint("TOPLEFT", contenu, "TOPLEFT", G.vue1X, G.vueY)
		else
			vue:SetPoint("TOPRIGHT", contenu, "TOPRIGHT", G.vue2X, G.vueY)
		end
		vue.cases = {}
		for n = 1, G.casesParVue do
			local k = (v - 1) * G.casesParVue + n
			vue.cases[n] = creerCase(vue, k)
			S.cases[k] = vue.cases[n]
		end
		vue.entetes = { creerEntete(vue) }
		vue.entete = vue.entetes[1]
		S.vues[v] = vue
	end

	-- les pages : "Page n/m", precedente, suivante (de droite a gauche) ; un
	-- clic dit au controleur de tourner (SecureHandlerClickTemplate)
	local suivante = CreateFrame("Button", "ForeverUISpellBookNextPage", contenu, "SecureHandlerClickTemplate")
	local precedente = CreateFrame("Button", "ForeverUISpellBookPrevPage", contenu, "SecureHandlerClickTemplate")
	for _, f in ipairs({ { suivante, "NextPage", 1 }, { precedente, "PrevPage", -1 } }) do
		local b = f[1]
		b:SetWidth(G.flecheCote)
		b:SetHeight(G.flecheCote)
		b:SetNormalTexture(FLECHES .. f[2] .. "-Up")
		b:SetPushedTexture(FLECHES .. f[2] .. "-Down")
		b:SetDisabledTexture(FLECHES .. f[2] .. "-Disabled")
		b:SetHighlightTexture(SURVOL_CARRE)
		b:GetHighlightTexture():SetBlendMode("ADD")
		b:SetAttribute("_onclick", ([[ self:GetFrameRef("ctrl"):SetAttribute("tourner", %d) ]]):format(f[3]))
		b:HookScript("OnClick", function() PlaySound("igAbiliityPageTurn") end)
	end
	suivante:SetPoint("BOTTOMRIGHT", contenu, "BOTTOMRIGHT", G.pagerX, G.pagerY)
	precedente:SetPoint("RIGHT", suivante, "LEFT", -G.pagerEcart, 0)
	local texte = contenu:CreateFontString(nil, "ARTWORK")
	police(texte, 14)
	texte:SetPoint("RIGHT", precedente, "LEFT", -G.pagerEcart, 0)
	S.pager = { suivante = suivante, precedente = precedente, texte = texte }
	contenu:EnableMouseWheel(true)
	contenu:SetAttribute("_onmousewheel", [[ self:GetFrameRef("ctrl"):SetAttribute("tourner", -delta) ]])

	-- ce que WotLK montre dans SpellBookFrame, et que camelot n'a pas
	-- les reglages (SpellBookSettingsDropdown) : TOPRIGHT (-30, -27) du livre
	S.creerReglages(pages)
	construireVolant(livre)
	S.creerControleur(livre)

	S.etoufferWotLK()
	S.poserTaille()
	return livre
end
S.construire = construire

-- ------------------------------------------------------------ les reglages
-- UIPanelArrowDropdownButtonTemplate : 15 x 16, la fleche
-- common-dropdown-a-button a sa taille d'atlas, centree ; au survol la meme
-- en ADD a 0,4 ; enfoncee, l'icone descend de (1, -1). Le menu s'ouvre
-- TOPLEFT sur BOTTOMLEFT (DropdownButton). Ses cases (SetupSettingsDropdown
-- de camelot) : masquer les passifs ; grouper en menus volants (retenu dans
-- ForeverUIDB, 3.3.5 n'a pas spellBookHideFlyouts ; groupe par defaut) ; tous
-- les rangs -- pour toutes les classes, a la demande (camelot l'ote au voleur
-- et au guerrier). Un clic coche et laisse le menu ouvert.
function S.creerReglages(pages)
	local b = CreateFrame("Button", "ForeverUISpellBookSettingsButton", pages, "SecureHandlerClickTemplate")
	b:SetWidth(G.reglagesL)
	b:SetHeight(G.reglagesH)
	b:SetPoint("TOPRIGHT", pages, "TOPRIGHT", G.reglagesX, G.reglagesY)
	local icone = b:CreateTexture(nil, "ARTWORK")
	atlas(icone, "common-dropdown-a-button")
	icone:SetPoint("CENTER", b, "CENTER", 0, 0)
	local survol = b:CreateTexture(nil, "HIGHLIGHT")
	atlas(survol, "common-dropdown-a-button")
	survol:SetPoint("CENTER", icone, "CENTER", 0, 0)
	survol:SetBlendMode("ADD")
	survol:SetAlpha(0.4)
	b.icone = icone
	b:SetScript("OnMouseDown", function() icone:SetPoint("CENTER", b, "CENTER", 1, -1) end)
	b:SetScript("OnMouseUp", function() icone:SetPoint("CENTER", b, "CENTER", 0, 0) end)

	-- la liste
	local liste = CreateFrame("Frame", "ForeverUISpellBookSettingsList", pages)
	liste:SetFrameStrata("DIALOG")
	liste:EnableMouse(true)
	liste:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, 0)
	liste:Hide()
	local tranches = ForeverUI.CreateNineSlice(liste, "common-dropdown-bg-c60", MENU.fondCoin, MENU.fondMarges, "BACKGROUND")
	for _, t in ipairs(tranches or {}) do t:SetAlpha(MENU.fondAlpha) end
	liste.lignes = {}
	local plusLong = 0
	for i, r in ipairs(REGLAGES) do
		local l = CreateFrame("Button", "ForeverUISpellBookSettingsEntry" .. i, liste, "SecureHandlerClickTemplate")
		l:SetID(r.bit)
		l:SetHeight(MENU.ligneH)
		l:SetPoint("TOPLEFT", liste, "TOPLEFT", MENU.ligneX, -MENU.bord - (i - 1) * MENU.ligneH)
		l:SetHighlightTexture("Interface" .. SEP .. "QuestFrame" .. SEP .. "UI-QuestTitleHighlight")
		l:GetHighlightTexture():SetBlendMode("ADD")
		local texte = l:CreateFontString(nil, "ARTWORK", "GameFontHighlightLeft")
		texte:SetPoint("LEFT", l, "LEFT", MENU.texteX, 0)
		texte:SetText(r.texte)
		plusLong = math.max(plusLong, texte:GetStringWidth() or 0)
		local case = l:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(case, "common-dropdown-ticksquare", true)
		case:SetWidth(MENU.case)
		case:SetHeight(MENU.case)
		case:SetPoint("LEFT", l, "LEFT", 0, 0)
		local coche = l:CreateTexture(nil, "ARTWORK")
		ForeverUI.SetAtlas(coche, "common-dropdown-icon-checkmark-yellow", true)
		coche:SetWidth(MENU.cocheL)
		coche:SetHeight(MENU.cocheH)
		coche:SetPoint("CENTER", case, "CENTER", MENU.cocheX, MENU.cocheY)
		coche:Hide()
		l.texte, l.coche, l.reglage = texte, coche, r
		-- UIDropDownMenuButton_OnClick, keepShownOnClick : la liste reste
		-- ouverte ; le reglage passe par le controleur, en combat aussi
		l:SetAttribute("_onclick", [==[ self:GetFrameRef("ctrl"):SetAttribute("reglage", self:GetID()) ]==])
		l:HookScript("OnClick", function() PlaySound("UChatScrollButton") end)
		-- SetupHidePassivesCheckbox : desactivee en recherche, avec son
		-- infobulle (les deux autres n'en ont pas)
		if r.bit == 1 then
			l:SetScript("OnEnter", function(self)
				if not S.reglagesGrises then return end
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(TEXTE.passifsDesactives, 1, 1, 1, 1, 1)
				GameTooltip:Show()
			end)
			l:SetScript("OnLeave", function() GameTooltip:Hide() end)
		end
		liste.lignes[i] = l
	end
	local largeur = plusLong + MENU.largeurPlus + MENU.marge
	liste:SetWidth(largeur)
	liste:SetHeight(#REGLAGES * MENU.ligneH + 2 * MENU.bord)
	for _, l in ipairs(liste.lignes) do l:SetWidth(largeur - MENU.marge) end

	-- la fleche ouvre ou ferme la liste, en combat aussi ; la liste se ferme
	-- d'elle-meme 2 s apres que la souris l'a quittee
	b:SetFrameRef("liste", liste)
	b:SetAttribute("_onclick", ([==[
		local l = self:GetFrameRef("liste")
		if l:IsShown() then
			l:Hide()
		else
			l:Show()
			l:RegisterAutoHide(%d)
			l:AddToAutoHide(self)
		end
	]==]):format(MENU.attente))
	S.reglages, S.listeReglages = b, liste
	return b
end

-- en combat aussi : grise pendant une recherche (le bloc securise
-- desactive les lignes ; ici, la couleur du texte)
function S.griserReglages(grise)
	if not S.listeReglages then return end
	S.reglagesGrises = grise
	for _, l in ipairs(S.listeReglages.lignes) do
		-- "Show all spell ranks" reste actif pendant une recherche (demande
		-- du 2026-09-25 ; camelot le desactive)
		if grise and l.reglage.bit ~= 4 then
			l.texte:SetTextColor(0.5, 0.5, 0.5)
		else
			l.texte:SetTextColor(1, 1, 1)
		end
	end
end

-- en combat aussi : les coches suivent la combinaison (textures seulement)
function S.cocherReglages(reg)
	if not S.listeReglages then return end
	for _, l in ipairs(S.listeReglages.lignes) do
		local actif = math.floor(reg / l.reglage.bit) % 2 == 1
		if l.reglage.inverse then actif = not actif end
		if actif then l.coche:Show() else l.coche:Hide() end
	end
end

function S.etoufferWotLK()
	for _, region in ipairs({ SpellBookFrame:GetRegions() }) do
		etouffer(region)
	end
	for _, enfant in ipairs({ SpellBookFrame:GetChildren() }) do
		if enfant ~= S.livre and enfant ~= SpellBookCloseButton then
			etouffer(enfant)
		end
	end
end

-- deux pages ou une : les images de la page et du bouton. Les largeurs et la
-- vue de droite sont au bloc securise "poser" ; ceci suit, en combat aussi.
function S.poserTaille(reduit)
	local livre, pages = S.livre, S.pages
	if not livre then return end
	if reduit == nil then reduit = reglages().reduit end
	if S.surTaille then S.surTaille(reduit) end
	if reduit then
		pages.gauche:Hide() pages.droite:Hide() pages.seule:Show()
		atlas(livre.taille:GetNormalTexture(), "redbutton-expand", true)
		atlas(livre.taille:GetPushedTexture(), "redbutton-expand-pressed", true)
	else
		pages.gauche:Show() pages.droite:Show() pages.seule:Hide()
		atlas(livre.taille:GetNormalTexture(), "redbutton-condense", true)
		atlas(livre.taille:GetPushedTexture(), "redbutton-condense-pressed", true)
	end
end

-- ------------------------------------------------------------ les onglets
-- un onglet dit au controleur "categorie n" (SecureHandlerClickTemplate) ;
-- il se cree hors combat seulement
local function creerOnglet(parent, n)
	local b = CreateFrame("Button", "ForeverUISpellBookTab" .. n, parent, "SecureHandlerClickTemplate")
	b:SetID(n)
	b:SetFrameRef("ctrl", S.ctrl)
	b:SetAttribute("_onclick", [[ self:GetFrameRef("ctrl"):SetAttribute("categorie", self:GetID()) ]])
	S.ctrl:SetFrameRef("o" .. n, b)
	S.ctrl:Execute(("ONGLETS[%d] = self:GetFrameRef(\"o%d\")"):format(n, n))
	b:SetWidth(G.ongletL)
	b:SetHeight(G.ongletH)
	local icone = b:CreateTexture(nil, "ARTWORK")
	icone:SetWidth(G.iconeOngletL)
	icone:SetHeight(G.iconeOngletH)
	icone:SetPoint("CENTER", b, "CENTER", -1, -1)
	-- le cadre PAR-DESSUS l'icone (ARTWORK sous-niveau 1) : un cadre fils
	local dessus = CreateFrame("Frame", nil, b)
	dessus:SetAllPoints(b)
	dessus:SetFrameLevel(b:GetFrameLevel() + 1)
	local cadre = dessus:CreateTexture(nil, "ARTWORK")
	atlas(cadre, "spellbook-tab-frame-c60")
	cadre:SetPoint("BOTTOM", b, "BOTTOM", 0, 1)
	local actif = dessus:CreateTexture(nil, "ARTWORK")
	atlas(actif, "spellbook-tab-frame-glow-c60")
	actif:SetPoint("BOTTOM", b, "BOTTOM", 0, 1)
	local lueur = dessus:CreateTexture(nil, "OVERLAY")
	atlas(lueur, "spellbook-tab-frame-glow-gradient-c60")
	lueur:SetPoint("BOTTOM", b, "BOTTOM", 0, 0)
	b.icone, b.cadre, b.actif, b.lueur = icone, cadre, actif, lueur
	b:HookScript("OnClick", function() PlaySound("igSpellBookOpen") end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -12, -6)
		GameTooltip:SetText(self.nom)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

-- hors combat : un onglet par categorie, a sa place
local function poserOnglets(cats)
	local onglets = S.onglets
	for i, cat in ipairs(cats) do
		local b = onglets.boutons[i]
		if not b then
			b = creerOnglet(onglets, i)
			onglets.boutons[i] = b
		end
		b.index, b.nom = i, cat.nom
		b.icone:SetTexture(cat.icone)
		b:ClearAllPoints()
		b:SetPoint("TOPLEFT", onglets, "TOPLEFT", (i - 1) * (G.ongletL + G.ongletEcart), 0)
		b:Show()
	end
	for i = #cats + 1, #onglets.boutons do
		onglets.boutons[i]:Hide()
	end
end

-- en combat aussi : l'onglet choisi s'allume (textures seulement ; son
-- activation est au bloc securise)
local function allumerOnglets(choisie)
	for i, b in ipairs(S.onglets.boutons) do
		-- 3.3.5 n'a pas SetShown
		if i == choisie then
			b.cadre:Hide() b.actif:Show() b.lueur:Show()
		else
			b.cadre:Show() b.actif:Hide() b.lueur:Hide()
		end
	end
end

-- ------------------------------------------------------------ le remplissage
S.etat = { categorie = 1, page = 1 }

-- Ce que l'on demande au controleur, hors combat seulement (le reste passe
-- par les onglets, les fleches et la roulette, qui sont securises).
function S.choisir(index)
	if InCombatLockdown() or not S.ctrl then return end
	S.ctrl:SetAttribute("categorie", index)
end

function S.tourner(sens)
	if InCombatLockdown() or not S.ctrl then return end
	S.ctrl:SetAttribute("tourner", sens)
end

-- LE CONTROLEUR. Son environnement securise garde les donnees publiees (D :
-- les cases de chaque page, NP : les pages de chaque categorie, V : les
-- sorts de chaque groupe), l'etat (CAT, PAGE, OUVERT) et les poignees des
-- cadres. Tout bloc est ecrit sans accolade ni le mot interdit.
local AFFICHER = [==[
	local liste = D[REG .. ":" .. MODE .. ":" .. CAT .. ":" .. PAGE]
	VOL:Hide()
	OUVERT = nil
	for k = 1, NB do
		CASES[k]:Hide()
		BOUTONS[k]:SetAttribute("volant", nil)
	end
	if liste then
		for i = 1, #liste do
			local e = liste[i]
			local c = CASES[e[1]]
			local b = BOUTONS[e[1]]
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", "$parent", "TOPLEFT", e[2], e[3])
			if e[4] == "" then b:SetAttribute("type1", nil) else b:SetAttribute("type1", e[4]) end
			if e[5] == "" then b:SetAttribute("spell", nil) else b:SetAttribute("spell", e[5]) end
			if e[6] == "" then
				b:SetAttribute("type2", nil)
				b:SetAttribute("macrotext2", nil)
			else
				b:SetAttribute("type2", e[6])
				b:SetAttribute("macrotext2", e[7])
			end
			if e[8] > 0 then b:SetAttribute("volant", e[8]) end
			c:Show()
		end
	end
	for i = 1, NC do
		if i == CAT then ONGLETS[i]:Disable() else ONGLETS[i]:Enable() end
	end
	for i = 1, NE do
		if CAT == 0 and ENTREES[i]:GetID() ~= 4 then ENTREES[i]:Disable() else ENTREES[i]:Enable() end
	end
	if PAGE > 1 then PREC:Enable() else PREC:Disable() end
	if PAGE < NP[REG .. ":" .. MODE .. ":" .. CAT] then SUIV:Enable() else SUIV:Disable() end
	control:CallMethod("ForeverUIVisuels", CAT, PAGE, MODE, REG)
]==]

local CHANGEMENT = [==[
	if name == "categorie" and value then
		self:SetAttribute("categorie", nil)
		if (value >= 1 and value <= NC) or (value == 0 and NP[REG .. ":" .. MODE .. ":0"]) then
			CAT = value
			PAGE = 1
			control:RunAttribute("afficher")
		end
	elseif name == "tourner" and value then
		self:SetAttribute("tourner", nil)
		local p = PAGE + value
		if p >= 1 and p <= NP[REG .. ":" .. MODE .. ":" .. CAT] then
			PAGE = p
			control:RunAttribute("afficher")
		end
	elseif name == "taille" and value then
		self:SetAttribute("taille", nil)
		if MODE == 2 then
			MODE = 1
			PAGE = PAGE * 2 - 1
		else
			MODE = 2
			PAGE = ceil(PAGE / 2)
		end
		if PAGE > NP[REG .. ":" .. MODE .. ":" .. CAT] then PAGE = NP[REG .. ":" .. MODE .. ":" .. CAT] end
		control:RunAttribute("poser")
		control:RunAttribute("afficher")
	elseif name == "effacer" and value then
		self:SetAttribute("effacer", nil)
		if CAT == 0 then
			CAT = 1
			PAGE = 1
			control:RunAttribute("afficher")
		end
	elseif name == "reglage" and value then
		self:SetAttribute("reglage", nil)
		if floor(REG / value) % 2 == 1 then REG = REG - value else REG = REG + value end
		if PAGE > NP[REG .. ":" .. MODE .. ":" .. CAT] then PAGE = NP[REG .. ":" .. MODE .. ":" .. CAT] end
		control:RunAttribute("afficher")
	end
]==]

-- MaximizeMinimizeButtonFrameTemplate : 1618 / 809 de large, deux pages ou
-- une (la vue de droite). %d : les largeurs de G.
local POSER = [==[
	if MODE == 1 then
		LIVRE:SetWidth(%d)
		PAGES:SetWidth(%d)
		VUE2:Hide()
	else
		LIVRE:SetWidth(%d)
		PAGES:SetWidth(%d)
		VUE2:Show()
	end
]==]

-- SpellFlyoutMixin:Toggle, enveloppe autour du OnClick de chaque case : le
-- meme groupe ferme le menu, un autre le deplace. Un modificateur ne l'ouvre
-- pas (le lien). %s : la largeur, calculee ici.
local OUVRIR = [==[
	local v = self:GetAttribute("volant")
	if v and not IsModifierKeyDown() then
		if OUVERT == self and VOL:IsShown() then
			VOL:Hide()
			OUVERT = nil
		else
			local liste = V[v]
			local n = #liste
			for i = 1, NBPETITS do
				if i <= n then
					PETITS[i]:SetAttribute("spell", liste[i])
					PETITS[i]:Show()
				else
					PETITS[i]:Hide()
				end
			end
			VOL:SetWidth(%d + n * %d)
			VOL:ClearAllPoints()
			VOL:SetPoint("LEFT", self, "RIGHT", %d, 0)
			VOL:Show()
			OUVERT = self
			control:CallMethod("ForeverUIVolant", self:GetID(), v)
		end
	end
]==]

-- un petit bouton : le sort part, puis le menu se ferme (sauf le lien)
local PETIT_AVANT = [==[ if not IsModifiedClick("CHATLINK") then return nil, "fermer" end ]==]
local PETIT_APRES = [==[ VOL:Hide() OUVERT = nil ]==]
-- le livre se ferme : le menu aussi (FlyoutButtonMixin:OnHide)
local CACHE = [==[ VOL:Hide() OUVERT = nil ]==]

function S.creerControleur(livre)
	local ctrl = CreateFrame("Frame", "ForeverUISpellBookControl", livre, "SecureHandlerAttributeTemplate")
	S.ctrl = ctrl
	for k, c in ipairs(S.cases) do
		ctrl:SetFrameRef("c" .. k, c)
		ctrl:SetFrameRef("b" .. k, c.bouton)
		ctrl:WrapScript(c.bouton, "OnClick", OUVRIR:format(G.volantDebut + G.volantFin - G.volantEcart,
			G.petitCote + G.volantEcart, G.volantDecalage))
	end
	ctrl:SetFrameRef("vol", S.volant)
	ctrl:SetFrameRef("livre", livre)
	ctrl:SetFrameRef("pages", S.pages)
	ctrl:SetFrameRef("vue2", S.vues[2])
	livre.taille:SetFrameRef("ctrl", ctrl)
	for i, l in ipairs(S.listeReglages.lignes) do
		l:SetFrameRef("ctrl", ctrl)
		ctrl:SetFrameRef("e" .. i, l)
	end
	ctrl:SetFrameRef("prec", S.pager.precedente)
	ctrl:SetFrameRef("suiv", S.pager.suivante)
	for _, b in ipairs({ S.pager.precedente, S.pager.suivante, S.contenu }) do
		b:SetFrameRef("ctrl", ctrl)
	end
	ctrl:Execute(([==[
		NB = %d
		CASES = newtable()
		BOUTONS = newtable()
		for k = 1, NB do
			CASES[k] = self:GetFrameRef("c" .. k)
			BOUTONS[k] = self:GetFrameRef("b" .. k)
		end
		VOL = self:GetFrameRef("vol")
		LIVRE = self:GetFrameRef("livre")
		PAGES = self:GetFrameRef("pages")
		VUE2 = self:GetFrameRef("vue2")
		MODE = 2
		REG = 0
		PREC = self:GetFrameRef("prec")
		SUIV = self:GetFrameRef("suiv")
		ONGLETS = newtable()
		PETITS = newtable()
		ENTREES = newtable()
		NE = %d
		for i = 1, NE do ENTREES[i] = self:GetFrameRef("e" .. i) end
		NBPETITS = 0
		D = newtable()
		NP = newtable()
		V = newtable()
		NC = 0
		CAT = 1
		PAGE = 1
	]==]):format(#S.cases, #S.listeReglages.lignes))
	ctrl:SetAttribute("afficher", AFFICHER)
	ctrl:SetAttribute("poser", POSER:format(G.largeurReduite, G.livreLReduit, G.largeur, G.livreL))
	ctrl:SetAttribute("_onattributechanged", CHANGEMENT)
	ctrl:WrapScript(S.contenu, "OnHide", CACHE)
	-- rendus par CallMethod : du code ordinaire, permis en combat
	ctrl.ForeverUIVisuels = function(_, cat, page, mode, reg) S.visuels(cat, page, mode, reg) end
	ctrl.ForeverUIVolant = function(_, k, vk) S.volantOuvertPar(k, vk) end
	return ctrl
end

-- les petits boutons du menu volant : autant que le plus grand groupe, crees
-- hors combat, chacun connu du controleur
local function assezDePetits(n)
	local volant, ctrl = S.volant, S.ctrl
	for i = #volant.boutons + 1, n do
		local p = creerPetit(volant, i)
		volant.boutons[i] = p
		ctrl:SetFrameRef("p" .. i, p)
		ctrl:WrapScript(p, "OnClick", PETIT_AVANT, PETIT_APRES)
		ctrl:Execute(("PETITS[%d] = self:GetFrameRef(\"p%d\") NBPETITS = %d"):format(i, i, i))
	end
end

-- une chaine pour le bloc securise
local function q(texte)
	return string.format("%q", texte or "")
end

-- LE CALCUL, HORS COMBAT : chaque categorie mise en page, publiee au
-- controleur, puis affichee a l'etat voulu.
function S.maj()
	local livre = S.livre
	if not livre then return end
	if InCombatLockdown() then
		S.enAttente = true
		return
	end
	S.enAttente, S.sale = nil, nil
	local cats = categories()
	local e = S.etat
	if e.categorie > #cats then e.categorie = 1 end
	-- LA RECHERCHE (SpellBookSearch.lua) : ses resultats forment une
	-- categorie de plus, la 0, sans onglet. Sans resultat, on en sort
	-- (DisplayFullSearchResults -> ClearActiveSearchState).
	local recherche = ForeverUI.SpellBookSearch
	if recherche then recherche.nouveauCalcul() end
	local groupesRecherche = {}
	if recherche and recherche.active() then
		-- une variante par jeu de reglages : la recherche suit "Hide Passives"
		-- et "Show all spell ranks", et ne groupe JAMAIS (demandes du
		-- 2026-09-25 ; camelot y montre passifs et tous les rangs, et groupe)
		local vide = true
		for r = 0, 7 do
			local g = recherche.groupes(cats, { passifs = r % 2 == 1, volants = true,
				rangs = math.floor(r / 4) % 2 == 1 })
			groupesRecherche[r] = g
			if #g > 0 then vide = false end
		end
		if vide then
			recherche.quitter()
			groupesRecherche = {}
		end
	end
	if e.categorie == 0 and not groupesRecherche[0] then e.categorie = 1 end
	poserOnglets(cats)
	local mode = reglages().reduit and 1 or 2
	local courantes = optionsCourantes()
	local reg = (courantes.passifs and 1 or 0) + (courantes.volants and 2 or 0) + (courantes.rangs and 4 or 0)

	-- TOUT EST PUBLIE : les huit jeux de reglages (REG, trois bits), chacun
	-- en une page (1) ou deux (2), pour que les reglages et le bouton
	-- agrandir / reduire marchent en combat. Dans un jeu, les vues sont les
	-- memes pour les deux modes ; seul leur regroupement en pages change.
	S.pagesDonnees, S.np, S.volantsDonnees = {}, {}, {}
	local code = { "wipe(D) wipe(NP) wipe(V)" }
	local plusGrand = 0
	for r = 0, 7 do
		local opts = { passifs = r % 2 == 1, volants = math.floor(r / 2) % 2 == 1, rangs = math.floor(r / 4) % 2 == 1 }
		S.pagesDonnees[r], S.np[r] = { {}, {} }, { {}, {} }
		-- la categorie 0 : les resultats de la recherche, pour ce jeu de
		-- reglages
		local g = groupesRecherche[r]
	for ci = (g and 0 or 1), #cats do
		local cat = cats[ci]
		local vues
		if ci == 0 then
			vues = mettreEnPageGroupes(g)
		else
			vues = mettreEnPage(cat.nom, listeAffichee(cats, ci, opts))
		end
		for parPage = 1, 2 do
			local nPages = math.max(1, math.ceil(#vues / parPage))
			S.np[r][parPage][ci] = nPages
			S.pagesDonnees[r][parPage][ci] = {}
			table.insert(code, ('NP["%d:%d:%d"] = %d'):format(r, parPage, ci, nPages))
			for page = 1, nPages do
				local donnees = { entetes = {}, cases = {} }
				S.pagesDonnees[r][parPage][ci][page] = donnees
				local entrees = {}
				for slot = 1, parPage do
					local n = 0
					for _, el in ipairs(vues[(page - 1) * parPage + slot] or {}) do
						if el.entete then
							donnees.entetes[slot] = donnees.entetes[slot] or {}
							table.insert(donnees.entetes[slot], el)
						else
							n = n + 1
							local k = (slot - 1) * G.casesParVue + n
							local sort = el.sort
							donnees.cases[k] = sort
							-- un groupe n'est publie qu'une fois, pour les deux modes
							if sort.volant and not sort.vk then
								table.insert(S.volantsDonnees, sort.membres)
								sort.vk = #S.volantsDonnees
								local textes = {}
								for _, m in ipairs(sort.membres) do table.insert(textes, q(S.texteDuSort(m))) end
								table.insert(code, ("V[%d] = newtable(%s)"):format(sort.vk, table.concat(textes, ", ")))
								plusGrand = math.max(plusGrand, #sort.membres)
							end
							local lance = not (sort.passif or sort.volant)
							table.insert(entrees, ("newtable(%d, %.14g, %d, %s, %s, %s, %s, %d)"):format(k,
								(el.colonne - 1) * (G.celluleL + G.ecartX), -el.y,
								q(lance and "spell" or ""), q(lance and S.texteDuSort(sort) or ""),
								q(sort.familier and "macro" or ""), q(sort.familier and ("/petautocasttoggle " .. sort.nom) or ""),
								sort.vk or 0))
						end
					end
				end
				table.insert(code, ('D["%d:%d:%d:%d"] = newtable(%s)'):format(r, parPage, ci, page, table.concat(entrees, ", ")))
			end
		end
	end
	end
	assezDePetits(plusGrand)
	if e.page > S.np[reg][mode][e.categorie] then e.page = S.np[reg][mode][e.categorie] end
	-- "poser" A CHAQUE CALCUL : la mise en page suit le reglage, meme quand il
	-- n'arrive qu'apres elle (les variables sauvegardees se chargent apres le
	-- fichier, donc apres la construction du livre)
	table.insert(code, ("NC = %d CAT = %d PAGE = %d MODE = %d REG = %d control:RunAttribute(\"poser\") control:RunAttribute(\"afficher\")")
		:format(#cats, e.categorie, e.page, mode, reg))
	S.ctrl:Execute(table.concat(code, "\n"))
end

-- ForeverUIVisuels : ce que le bloc securise vient de poser, en images et en
-- textes. Rien de protege ici : c'est ce qui rend le livre lisible en combat.
function S.visuels(cat, page, mode, reg)
	local e = S.etat
	e.categorie, e.page = cat, page
	mode, reg = mode or 2, reg or 0
	-- le mode et les reglages choisis se retiennent, meme changes en combat
	-- (SetCVar n'est pas protege)
	reglages().reduit = (mode == 1) or nil
	reglages().masquerPassifs = (reg % 2 == 1) or nil
	reglages().sansVolants = (math.floor(reg / 2) % 2 == 1) or nil
	local rangs = math.floor(reg / 4) % 2 == 1
	if rangs ~= (GetCVar("ShowAllSpellRanks") == "1") then
		SetCVar("ShowAllSpellRanks", rangs and "1" or "0")
	end
	S.reg = reg
	S.cocherReglages(reg)
	S.poserTaille(mode == 1)
	e.pages = S.np and S.np[reg][mode][cat] or 1
	allumerOnglets(cat)
	local donnees = S.pagesDonnees and S.pagesDonnees[reg][mode][cat] and S.pagesDonnees[reg][mode][cat][page]
	-- les en-tetes : un par section de la vue (cadres ordinaires, crees au
	-- besoin -- permis en combat)
	for slot, vue in ipairs(S.vues) do
		local liste = donnees and donnees.entetes[slot] or {}
		for i, el in ipairs(liste) do
			local h = vue.entetes[i]
			if not h then
				h = creerEntete(vue)
				vue.entetes[i] = h
			end
			h.texte:SetText(el.entete)
			h:ClearAllPoints()
			h:SetPoint("TOPLEFT", vue, "TOPLEFT", 0, -el.y)
			h:Show()
		end
		for i = #liste + 1, #vue.entetes do vue.entetes[i]:Hide() end
	end
	-- les reglages sont grises pendant une recherche (camelot les desactive)
	S.griserReglages(cat == 0)
	if S.surVisuels then S.surVisuels(cat) end
	for k, c in ipairs(S.cases) do
		local sort = donnees and donnees.cases[k]
		c.sort = sort
		if sort then remplirCase(c, sort) end
	end
	S.pager.texte:SetText(string.format(TEXTE.page, e.page, e.pages))
end

-- l'etat des cases montrees : recharges, lancement automatique
function S.majEtats()
	if not S.vues then return end
	if S.volant and S.volant:IsShown() then
		for _, p in ipairs(S.volant.boutons) do
			if p:IsShown() then majPetit(p) end
		end
	end
	for _, vue in ipairs(S.vues) do
		for _, c in ipairs(vue.cases) do
			if c:IsShown() and c.sort then S.majEtat(c) end
		end
	end
end

-- ------------------------------------------------------------ l'assemblage
construire()

if S.livre then
	-- deplacable par son titre ; devant quand il s'ouvre ou qu'on le clique
	ForeverUI.Superposition.deplacable(S.livre, S.livre.bandeau, "grimoire")
	ForeverUI.Superposition.inscrire("grimoire", SpellBookFrame, function()
		return { S.livre, _G.ForeverUISpellFlyout, _G.ForeverUISpellBookSettingsList,
			_G.ForeverUISpellBookSearchPreview }
	end)
	-- a chaque ouverture : le livre demande (sorts ou familier) et son contenu
	SpellBookFrame:HookScript("OnShow", function()
		S.etoufferWotLK()
		S.leverCroix()
		-- en combat, le livre s'ouvre tel qu'il a ete publie
		if InCombatLockdown() then return end
		if SpellBookFrame.bookType == BOOKTYPE_PET then
			local cats = categories()
			for i, cat in ipairs(cats) do
				if cat.familier then S.etat.categorie = i S.etat.page = 1 end
			end
		elseif S.etat.categorie and categories()[S.etat.categorie] and categories()[S.etat.categorie].familier then
			S.etat.categorie = 1
			S.etat.page = 1
		end
		S.maj()
	end)
	if hooksecurefunc and SpellBookFrame_Update then
		hooksecurefunc("SpellBookFrame_Update", S.etoufferWotLK)
	end
	-- LE LIVRE DOIT ETRE PUBLIE AVANT LE COMBAT, ouvert ou non : on peut
	-- l'ouvrir en combat. Un changement le marque, l'image suivante le
	-- recalcule (SPELLS_CHANGED arrive en rafales) ; PLAYER_REGEN_DISABLED,
	-- dernier moment hors verrou, rattrape ce qui n'a pas eu son image.
	local veille = CreateFrame("Frame")
	for _, ev in ipairs({ "PLAYER_ENTERING_WORLD", "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "PET_BAR_UPDATE",
		"UNIT_PET", "SPELL_UPDATE_COOLDOWN", "CURRENT_SPELL_CAST_CHANGED", "PLAYER_REGEN_DISABLED",
		"PLAYER_REGEN_ENABLED", "CVAR_UPDATE" }) do
		veille:RegisterEvent(ev)
	end
	local function aLImageSuivante()
		veille:SetScript("OnUpdate", nil)
		if S.sale and not InCombatLockdown() then S.maj() end
	end
	function S.marquer()
		S.sale = true
		veille:SetScript("OnUpdate", aLImageSuivante)
	end
	veille:SetScript("OnEvent", function(_, ev)
		if ev == "SPELL_UPDATE_COOLDOWN" or ev == "CURRENT_SPELL_CAST_CHANGED" then
			S.majEtats()
			return
		end
		if ev == "PET_BAR_UPDATE" then S.majEtats() end
		if ev == "PLAYER_REGEN_DISABLED" then
			if S.sale then S.maj() end
			return
		end
		if ev == "PLAYER_REGEN_ENABLED" then
			if S.sale or S.enAttente then S.maj() end
			return
		end
		S.marquer()
	end)
end

ForeverUI.SpellBookDebug = function()
	local prefixe = "|cff66ccffForeverUI|r "
	if not S.livre then
		DEFAULT_CHAT_FRAME:AddMessage(prefixe .. "grimoire : pas construit.")
		return
	end
	local cats = categories()
	local e = S.etat
	local noms = {}
	for _, c in ipairs(cats) do table.insert(noms, c.nom .. " (" .. c.nombre .. ")") end
	DEFAULT_CHAT_FRAME:AddMessage(prefixe .. string.format(
		"grimoire : %.0f x %.0f, %s | categorie %d/%d, page %d/%d | %s",
		S.livre:GetWidth(), S.livre:GetHeight(), reglages().reduit and "une page" or "deux pages",
		e.categorie, #cats, e.page, e.pages or 1, table.concat(noms, ", ")))
end
