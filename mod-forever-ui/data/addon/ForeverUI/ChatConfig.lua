-- ForeverUI : la configuration du chat (ChatConfigFrame), a la DA de
-- camelot (demande de l'utilisateur, 2026-09-28 : « fait le menu et
-- reglages », etape 3).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (ChatConfigFrame.xml / .lua de 3.3.5) :
--   ChatConfigFrame 645 x 595, <Backdrop> UI-DialogBox, en-tete
--     UI-DialogBox-Header et ChatConfigFrameHeaderText (CHATCONFIG_HEADER,
--     pose a l'ouverture) ;
--   ChatConfigBoxTemplate : <Backdrop> d'infobulle (fond et bord), bord
--     TOOLTIP_DEFAULT_COLOR a 0,5, fond TOOLTIP_DEFAULT_BACKGROUND_COLOR ;
--     les cadres a case et a nuancier (ChatConfigCheckBoxTemplate,
--     ChatConfigSwatchTemplate, et six cadres du journal de combat) : le
--     meme bord, sans fond ;
--   les lignes a case et a nuancier sont creees par ChatConfig_Create-
--     Checkboxes / _CreateTieredCheckboxes / _CreateColorSwatches a
--     PLAYER_ENTERING_WORLD, les onglets des filtres a la demande ;
--   la liste des filtres du journal de combat : FauxScrollFrameTemplate-
--     Light et sa barre.
--
-- RELEVE -- CAMELOT (blizzard_chatframe/mainline/chatconfigframe.xml, le
-- [Family] de camelot) : la meme fenetre, les memes noms et gabarits --
--   ChatConfigFrame : DialogBorderTemplate et DialogHeaderTemplate
--     (headerTextPadding 100) ;
--   ChatConfigBoxTemplate = TooltipBackdropTemplate, bord a 0,5 ;
--   ChatConfigBorderBoxTemplate = TooltipBorderBackdropTemplate (le bord
--     seul), bord a 0,5 ;
--   cases (UI-CheckBox-*), boutons de categorie (UI-Listbox-Highlight2),
--     onglets (ChatFrameTab), nuanciers (ChatFrameColorSwatch) et boutons
--     UIPanelButtonTemplate : l'art de 3.3.5, inchange ;
--   la liste des filtres : MinimalScrollBar.
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee » : places, tailles et
-- logique du client. La fenetre de camelot est plus large (745 x 605) parce
-- qu'elle porte les onglets des fenetres de chat, que 3.3.5 n'a pas.
-- Chaque cadre a bord d'infobulle garde les couleurs que le client lui a
-- donnees ; le fond n'est pose que s'il en avait un.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local C = {}
ForeverUI.ConfigChat = C

local N = { entete = 100 }

local function bordInfobulle(f)
	local fond = f.GetBackdrop and f:GetBackdrop()
	return fond and type(fond.edgeFile) == "string"
		and string.find(string.lower(fond.edgeFile), "ui%-tooltip%-border") and fond
end

-- TooltipBackdropTemplate / TooltipBorderBackdropTemplate sur un cadre a
-- <Backdrop> d'infobulle : ses couleurs relues avant, reposees apres
function C.Boite(f)
	local fond = bordInfobulle(f)
	if not fond or f.foreverNeuf then return end
	local r, g, b, a = f:GetBackdropBorderColor()
	local cr, cg, cb = f:GetBackdropColor()
	local avecFond = fond.bgFile ~= nil
	local p = ForeverUI.Tooltips.Habiller(f)
	for nom, t in pairs(p) do
		if nom == "Center" then
			if avecFond then
				t:SetVertexColor(cr or 0, cg or 0, cb or 0, 1)
			else
				t:SetAlpha(0)
			end
		else
			t:SetVertexColor(r or 1, g or 1, b or 1, a or 1)
		end
	end
end

-- tous les descendants : les boites, et les barres des listes a defilement
-- (MinimalScrollBar n'a pas le lisere d'infobulle de
-- UIPanelScrollBarTemplateLightBorder, $parentBorder : il s'enleve)
function C.Balayer(cadre)
	for _, c in ipairs({ cadre:GetChildren() }) do
		local nom = c:GetName()
		local sb = c:GetObjectType() == "ScrollFrame" and nom and _G[nom .. "ScrollBar"]
		if sb and not sb.foreverBarre then
			local lisere = _G[sb:GetName() .. "Border"]
			if lisere then lisere:SetBackdrop(nil) end
			Gb.Barre(sb)
		end
		C.Boite(c)
		C.Balayer(c)
	end
end

function C.Habiller()
	local f = ChatConfigFrame
	if not f or f.foreverHabit then return end
	f:SetBackdrop(nil)
	local cadre, fond = Gb.CadreDialogue(f)
	ChatConfigFrameHeader:SetAlpha(0)
	ChatConfigFrameHeaderText:SetAlpha(0)
	local entete = Gb.EnTete(f, ChatConfigFrameHeaderText:GetText(), GameFontNormal, N.entete)
	local function titre()
		entete:Poser(ChatConfigFrameHeaderText:GetText())
	end
	hooksecurefunc(ChatConfigFrameHeaderText, "SetText", titre)
	hooksecurefunc(ChatConfigFrameHeaderText, "SetFormattedText", titre)
	f.foreverHabit = { cadre = cadre, fond = fond, entete = entete }
	C.Balayer(f)
	-- les lignes et les onglets crees ensuite par le client
	f:HookScript("OnShow", function(self) C.Balayer(self) end)
	for _, nom in ipairs({ "ChatConfig_CreateCheckboxes", "ChatConfig_CreateTieredCheckboxes",
			"ChatConfig_CreateColorSwatches" }) do
		if type(_G[nom]) == "function" then
			hooksecurefunc(nom, function(cadreLignes)
				if cadreLignes then C.Balayer(cadreLignes) end
			end)
		end
	end
end

C.Habiller()
