-- ForeverUI : les hotes et leurs contenus.
--
-- CE QUE C'EST, ET POURQUOI.
--
-- Une fenetre moderne n'est pas un bloc : c'est un ou deux HOTES -- des
-- surfaces fixes -- dans lesquels des CONTENUS se remplacent. camelot le dit
-- ainsi dans CharacterFrame.xml : LeftPaneHost et RightPaneHost, et une
-- SidePane par onglet. Changer d'onglet n'y recalcule rien : un contenu se
-- masque, un autre se montre.
--
-- LE DEFAUT QUE CELA CORRIGE. La feuille de personnage decidait sa visibilite
-- a cinq endroits -- l'habillage, les deux onglets du volet, le repli, et la
-- fonction des statistiques -- et reposait TOUTE sa geometrie a chaque
-- evenement. D'ou deux fautes que rien ne pouvait prevenir :
--   * le panneau du gestionnaire d'equipement restait a l'ecran quand on
--     changeait d'onglet lateral, parce qu'il appartient a NOTRE volet et
--     non au PaperDollFrame du client, que lui seul masque ;
--   * les barres de reputation traversaient le volet droit, parce que le
--     cadre du client garde la taille de la fenetre d'origine et que
--     personne ne le bornait.
-- Tant que la visibilite se decide partout, chaque nouvel ecran rouvre les
-- memes plaies. Elle se decide donc ICI, et nulle part ailleurs.
--
-- LE MODELE, en trois mots :
--
--   HOTE     une surface qui accueille : un volet, une colonne.
--   GROUPE   ce qu'un onglet ouvre. Un groupe touche TOUS les hotes a la
--            fois : c'est un ecran entier.
--   PAGE     un contenu dans un hote pour un groupe donne. Plusieurs pages
--            dans le meme hote et le meme groupe se remplacent entre elles
--            -- ce sont des boutons, pas des onglets.
--
-- Un contenu se CONSTRUIT une seule fois, a sa premiere ouverture, et pose sa
-- geometrie a ce moment-la. Ensuite il ne fait plus que paraitre et
-- disparaitre. Rien n'est recalcule.
--
-- CE QU'UN CONTENU DECLARE POSSEDER. Notre racine est un cadre a nous : ses
-- fils la suivent. Mais un ecran de 3.3.5 est fait de cadres DU CLIENT, que
-- l'on ne reparente pas -- leur niveau et leur strate s'y perdraient, et des
-- reglages deja valides avec. Un contenu declare donc aussi la LISTE des
-- cadres du client qu'il possede, et la bibliotheque les montre et les masque
-- avec sa racine. Une seule boucle, un seul endroit.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Panes = {}
ForeverUI.Panes = Panes

local hotes = {}        -- nom -> { cadre, contenus, groupe, page, montre }
local ordreHotes = {}

-- --------------------------------------------------------------- les hotes

-- Declarer un hote. Le cadre existe deja : la bibliotheque ne le cree pas,
-- elle ne fait que savoir ou les contenus vont.
function Panes.NewHost(nom, cadre)
	local hote = hotes[nom]
	if not hote then
		hote = { nom = nom, contenus = {}, ordre = {}, pages = {}, montre = true }
		hotes[nom] = hote
		ordreHotes[#ordreHotes + 1] = nom
	end
	hote.cadre = cadre
	return hote
end

function Panes.Host(nom)
	local hote = hotes[nom]
	return hote and hote.cadre
end

-- ---------------------------------------------------------- les contenus

-- def = { hote, groupe, id, construire }
--
-- construire(hoteCadre) est appelee UNE fois, a la premiere ouverture. Elle
-- rend, dans l'ordre : la racine -- un cadre a nous, ou nil -- et la liste
-- des cadres du client que ce contenu possede.
function Panes.Register(def)
	local hote = hotes[def.hote]
	if not hote then
		error("ForeverUI.Panes : hote inconnu -- " .. tostring(def.hote))
	end

	local contenu = {
		id = def.id,
		groupe = def.groupe,
		construire = def.construire,
		hote = hote,
		bati = false,
		cadres = {},
	}
	hote.contenus[def.id] = contenu
	hote.ordre[#hote.ordre + 1] = def.id

	-- La premiere page declaree pour un groupe en devient la page par defaut.
	if hote.pages[def.groupe] == nil then
		hote.pages[def.groupe] = def.id
	end
	return contenu
end

local function batir(contenu)
	if contenu.bati then
		return
	end
	contenu.bati = true                     -- avant l'appel : pas de boucle

	if contenu.construire then
		local racine, cadres = contenu.construire(contenu.hote.cadre)
		contenu.racine = racine
		contenu.cadres = cadres or {}
	end
end

-- Un contenu possede aussi des cadres du client, declares apres coup : un
-- ecran peut en decouvrir a l'usage, quand le client les cree tard.
function Panes.Own(hote, id, cadre)
	local h = hotes[hote]
	local contenu = h and h.contenus[id]
	if not contenu or not cadre then
		return
	end
	for _, connu in ipairs(contenu.cadres) do
		if connu == cadre then
			return
		end
	end
	contenu.cadres[#contenu.cadres + 1] = cadre
end

local function poser(contenu, visible)
	if visible then
		batir(contenu)
	elseif not contenu.bati then
		-- Jamais ouvert, donc rien a masquer : on ne le batit pas pour cela.
		return
	end

	if contenu.racine then
		if visible then contenu.racine:Show() else contenu.racine:Hide() end
	end
	for _, cadre in ipairs(contenu.cadres) do
		if cadre and cadre.Show then
			if visible then cadre:Show() else cadre:Hide() end
		end
	end
end

-- ------------------------------------------------------------ l'affichage

local function appliquer(hote)
	local voulu = hote.montre and hote.pages[hote.groupe or ""] or nil

	for _, id in ipairs(hote.ordre) do
		poser(hote.contenus[id], id == voulu)
	end
	hote.actuel = voulu

	-- UN HOTE SANS CONTENU NE S'AFFICHE PAS. C'est ce qui empeche un volet
	-- droit vide -- et son fond, et sa bande de pierre -- de rester a
	-- l'ecran sur un onglet qui n'a rien a y mettre.
	if hote.cadre then
		local utile = hote.montre and voulu ~= nil
		if utile then hote.cadre:Show() else hote.cadre:Hide() end
	end
end

-- Ouvrir un groupe : un ecran entier, tous les hotes a la fois.
function Panes.ShowGroup(groupe)
	for _, nom in ipairs(ordreHotes) do
		local hote = hotes[nom]
		hote.groupe = groupe
		appliquer(hote)
	end
	Panes.groupe = groupe
end

function Panes.CurrentGroup()
	return Panes.groupe
end

-- Changer de page dans un hote, sans toucher au groupe : c'est ce que font
-- deux boutons qui se partagent la meme surface.
function Panes.ShowPage(nom, id)
	local hote = hotes[nom]
	if not hote or not hote.contenus[id] then
		return
	end
	hote.pages[hote.groupe or ""] = id
	appliquer(hote)
end

function Panes.CurrentPage(nom)
	local hote = hotes[nom]
	return hote and hote.actuel
end

-- Masquer un hote entier -- le repli d'un volet. Le groupe et la page
-- choisie sont conserves : deplier les retrouve.
function Panes.SetHostShown(nom, etat)
	local hote = hotes[nom]
	if not hote then
		return
	end
	hote.montre = etat and true or false
	appliquer(hote)
end

function Panes.IsHostShown(nom)
	local hote = hotes[nom]
	return hote ~= nil and hote.montre and hote.actuel ~= nil
end

-- Un hote a-t-il quelque chose a montrer pour ce groupe ? Repond sans rien
-- batir : c'est ce qui decide, par exemple, si le bouton de repli a un sens.
function Panes.HasContent(nom, groupe)
	local hote = hotes[nom]
	return hote ~= nil and hote.pages[groupe or hote.groupe or ""] ~= nil
end

-- Reposer l'etat courant. A appeler quand un contenu vient d'etre declare
-- apres l'ouverture du groupe, jamais dans une boucle d'affichage.
function Panes.Refresh()
	for _, nom in ipairs(ordreHotes) do
		appliquer(hotes[nom])
	end
end

-- TEMOIN. Ce que chaque hote montre, et ce qu'il possede.
function Panes.Report()
	local lignes = {}
	for _, nom in ipairs(ordreHotes) do
		local hote = hotes[nom]
		local pages = {}
		for _, id in ipairs(hote.ordre) do
			local contenu = hote.contenus[id]
			if contenu.groupe == hote.groupe then
				pages[#pages + 1] = string.format("%s(%d cadres%s)", id,
					#contenu.cadres, contenu.bati and "" or ", jamais bati")
			end
		end
		lignes[#lignes + 1] = string.format(
			"%s : groupe=%s page=%s visible=%s | pages du groupe : %s",
			nom, tostring(hote.groupe), tostring(hote.actuel),
			tostring(hote.montre), table.concat(pages, ", "))
	end
	return lignes
end
