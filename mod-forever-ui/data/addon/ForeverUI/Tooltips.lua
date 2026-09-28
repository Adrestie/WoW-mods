-- ForeverUI : les infobulles, a la DA de camelot (demande de l'utilisateur,
-- 2026-09-28 : « fait les infobulles »).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (FrameXML de 3.3.5, lu par la chaine
-- d'archives) :
--   gabarits     GameTooltipTemplate et ShoppingTooltipTemplate
--                (GameTooltipTemplate.xml) : un <Backdrop> UI-Tooltip-
--                Background / UI-Tooltip-Border, bord 16, retraits 5.
--                GameTooltip_OnLoad et GameTooltip_OnHide (GameTooltip.lua)
--                y posent TOOLTIP_DEFAULT_COLOR (bord) et
--                TOOLTIP_DEFAULT_BACKGROUND_COLOR (fond).
--   infobulles   GameTooltip, ShoppingTooltip1-3 (GameTooltip.xml),
--                ItemRefTooltip, ItemRefShoppingTooltip1-3 (ItemRef.xml),
--                WorldMapTooltip, WorldMapCompareTooltip1-3
--                (WorldMapFrame.xml), FrameStackTooltip et EventTraceTooltip
--                (Blizzard_DebugTools, charge a la demande) -- toutes sur ces
--                deux gabarits ; aucune n'est creee en Lua.
--   bulles       FriendsTooltip (FriendsFrame.xml), PartyMemberBuffTooltip
--                (PartyFrame.xml), SmallTextTooltip (GameTooltip.xml) : des
--                Frame au meme <Backdrop>.
--   comparaison  toutes les comparaisons (sac, marchand, quetes, carte, lien,
--                hotel des ventes) passent par GameTooltip_ShowCompareItem :
--                SetHyperlinkCompareItem ecrit « Currently Equipped »
--                (CURRENTLY_EQUIPPED) en PREMIERE LIGNE de l'infobulle de
--                comparaison, en GameFontNormalSmall.
--   croix        ItemRefCloseButton : 32 x 32, TOPRIGHT (1, 0),
--                UI-Panel-MinimizeButton-Up / -Down / -Highlight.
--
-- RELEVE -- CE QUE FAIT CAMELOT (blizzard_sharedxml, blizzard_sharedxmlgame,
-- blizzard_gametooltip et blizzard_uipanels_game : pas de camelot/, [Family]
-- mainline) :
--   SharedTooltipTemplate  un NineSlice, disposition TooltipDefaultLayout
--                (nineslicelayouts.lua) posee par NineSliceUtil.ApplyLayout
--                (nineslice.lua) : les coins Tooltip-NineSlice-Corner* (7 x 7)
--                aux quatre coins, les bords _Tooltip-NineSlice-EdgeTop /
--                -EdgeBottom et !Tooltip-NineSlice-EdgeLeft / -EdgeRight
--                tendus entre eux, en couche BORDER ; le centre
--                Tooltip-NineSlice-Center en BACKGROUND, de TopLeftCorner
--                (-4, 4) a BottomRightCorner (4, -4).
--   SharedTooltip_OnLoad   SetClampRectInsets(0, 0, 25, 0).
--   SharedTooltip_SetBackdropStyle  le centre a
--                TOOLTIP_DEFAULT_BACKGROUND_COLOR, alpha 1 ; le bord garde
--                sa couleur.
--   TooltipBackdropTemplateMixin  SetBackdropColor teinte le centre,
--                SetBackdropBorderColor le bord.
--   FriendsTooltip, PartyMemberBuffTooltip  TooltipBackdropTemplate : le meme
--                habillage.
--   ShoppingTooltipTemplate  CompareHeader : 100 x 22, BOTTOMLEFT sur le
--                TOPLEFT de l'infobulle (0, -1), niveau 1 sous l'infobulle
--                (2) ; fond tooltip-compare-label sur tout le cadre ; Label
--                GameTooltipText en NORMAL_FONT_COLOR, centre ; largeur =
--                Label + 30 (COMPARE_HEADER_PADDING,
--                tooltipcomparisonmanager.lua) ; texte EQUIPPED.
--   ItemRefTooltip  CloseButton UIPanelCloseButtonNoScripts : 24 x 24,
--                RedButton-Exit, RedButton-exit-pressed, RedButton-Highlight
--                en ADD ; TOPRIGHT (2, 2).
--   La police, la barre de vie (8 de haut, (2, -1) et (-2, -1) sous
--   l'infobulle) et les retraits des lignes sont ceux de 3.3.5 : rien a
--   reprendre.
--
-- CE QUI DIFFERE, ET POURQUOI.
--   Le NineSlice de camelot est un cadre fils au niveau de son parent
--   (useParentLevel) ; en 3.3.5 un cadre fils couvrirait les lignes : les
--   morceaux sont des regions de l'infobulle, comme a l'accueil
--   (G.NeufTranches).
--   Le <Backdrop> de 3.3.5 n'est pas une region : SetBackdrop(nil) seul
--   l'enleve. Ses couleurs passent aux morceaux -- SetBackdropColor et
--   SetBackdropBorderColor sont suivis, comme les renvoie
--   TooltipBackdropTemplateMixin. Un addon qui repose son propre fond
--   reprend la main : les morceaux s'effacent.
--   Une mosaique n'est possible, en 3.3.5, que sur une image entiere ; le
--   centre est d'une seule couleur et les bords sont constants sur leur
--   longueur : etires, ils rendent la meme chose.
--   ECART : 3.3.5 n'a pas la chaine EQUIPPED. Le bandeau porte donc
--   CURRENTLY_EQUIPPED, le texte que le client ecrivait en premiere ligne --
--   ligne que l'on vide. Une premiere ligne qui dit autre chose n'est pas
--   touchee, et l'infobulle n'a pas de bandeau.
--   Les infobulles des autres addons faites sur les gabarits du client (le
--   meme <Backdrop>) prennent le meme habillage. ItemSocketingDescription,
--   infobulle ENCHASSEE dans la fenetre de sertissage (camelot ne lui
--   dessine aucun cadre, IsEmbedded), attend la reprise de cette fenetre.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local T = {}
ForeverUI.Tooltips = T

local SEP = string.char(92)
local BORD_CLIENT = string.lower("Interface" .. SEP .. "Tooltips" .. SEP .. "UI-Tooltip-Border")

-- TooltipDefaultLayout, dans l'ordre et avec les ancrages de nineSliceSetup :
-- nom, element, point (et, pour un bord, point oppose et les deux coins)
local MORCEAUX = {
	{ "TopLeftCorner", "tooltip-nineslice-cornertopleft", "TOPLEFT" },
	{ "TopRightCorner", "tooltip-nineslice-cornertopright", "TOPRIGHT" },
	{ "BottomLeftCorner", "tooltip-nineslice-cornerbottomleft", "BOTTOMLEFT" },
	{ "BottomRightCorner", "tooltip-nineslice-cornerbottomright", "BOTTOMRIGHT" },
	{ "TopEdge", "_tooltip-nineslice-edgetop", "TOPLEFT", "TOPRIGHT", "TopLeftCorner", "TopRightCorner" },
	{ "BottomEdge", "_tooltip-nineslice-edgebottom", "BOTTOMLEFT", "BOTTOMRIGHT", "BottomLeftCorner", "BottomRightCorner" },
	{ "LeftEdge", "!tooltip-nineslice-edgeleft", "TOPLEFT", "BOTTOMLEFT", "TopLeftCorner", "BottomLeftCorner" },
	{ "RightEdge", "!tooltip-nineslice-edgeright", "TOPRIGHT", "BOTTOMRIGHT", "TopRightCorner", "BottomRightCorner" },
}
local CENTRE = { atlas = "tooltip-nineslice-center", x = -4, y = 4, x1 = 4, y1 = -4 }

-- SharedTooltip_OnLoad
local RETRAITS_ECRAN = { 0, 0, 25, 0 }

-- CompareHeader
local ENTETE = { largeur = 100, hauteur = 22, y = -1, marge = 30, atlas = "tooltip-compare-label" }

-- UIPanelCloseButtonNoScripts, a TOPRIGHT (2, 2) d'ItemRefTooltip
local CROIX = { cote = 24, x = 2, y = 2 }

-- les bulles du client qui ne sont pas des GameTooltip
local BULLES = { "FriendsTooltip", "PartyMemberBuffTooltip", "SmallTextTooltip" }

-- infobulles enchassees dans une fenetre : pas les notres
local EXCLUES = { ItemSocketingDescription = true }

-- le fond que posent les gabarits du client
local function fondDuClient(f)
	local fond = f.GetBackdrop and f:GetBackdrop()
	local bord = fond and fond.edgeFile
	return type(bord) == "string" and string.lower(string.gsub(bord, "/", SEP)) == BORD_CLIENT
end

-- SetCenterColor (centre) ou SetBorderColor (les huit autres morceaux)
local function teinter(bulle, centre, r, g, b, a)
	local p = bulle.foreverNeuf
	if not p or not r then return end
	for nom, t in pairs(p) do
		if (nom == "Center") == centre then
			t:SetVertexColor(r, g, b, a or 1)
		end
	end
end

-- Remplace le fond de 3.3.5 par la decoupe en neuf de camelot. Rend les
-- morceaux par nom.
function T.Habiller(bulle)
	if not bulle or bulle.foreverNeuf then return bulle and bulle.foreverNeuf end
	bulle:SetBackdrop(nil)

	local p = {}
	for _, m in ipairs(MORCEAUX) do
		local t = bulle:CreateTexture(nil, "BORDER")
		ForeverUI.SetAtlas(t, m[2])
		if m[4] then
			t:SetPoint(m[3], p[m[5]], m[4], 0, 0)
			t:SetPoint(m[4], p[m[6]], m[3], 0, 0)
		else
			t:SetPoint(m[3], bulle, m[3], 0, 0)
		end
		p[m[1]] = t
	end
	local c = bulle:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(c, CENTRE.atlas)
	c:SetPoint("TOPLEFT", p.TopLeftCorner, "BOTTOMRIGHT", CENTRE.x, CENTRE.y)
	c:SetPoint("BOTTOMRIGHT", p.BottomRightCorner, "TOPLEFT", CENTRE.x1, CENTRE.y1)
	p.Center = c
	bulle.foreverNeuf = p

	local fond, bord = TOOLTIP_DEFAULT_BACKGROUND_COLOR, TOOLTIP_DEFAULT_COLOR
	teinter(bulle, true, fond.r, fond.g, fond.b, 1)
	teinter(bulle, false, bord.r, bord.g, bord.b, 1)
	hooksecurefunc(bulle, "SetBackdropColor", function(self, r, g, b, a)
		teinter(self, true, r, g, b, a)
	end)
	hooksecurefunc(bulle, "SetBackdropBorderColor", function(self, r, g, b, a)
		teinter(self, false, r, g, b, a)
	end)
	hooksecurefunc(bulle, "SetBackdrop", function(self, autre)
		for _, t in pairs(self.foreverNeuf) do
			if autre then t:Hide() else t:Show() end
		end
	end)

	if bulle:GetObjectType() == "GameTooltip" then
		bulle:SetClampRectInsets(RETRAITS_ECRAN[1], RETRAITS_ECRAN[2], RETRAITS_ECRAN[3], RETRAITS_ECRAN[4])
	end
	return p
end

-- toutes les infobulles faites sur les gabarits du client, celles des
-- addons charges depuis comprises
function T.Balayer()
	local f = EnumerateFrames()
	while f do
		if not f.foreverNeuf and f:GetObjectType() == "GameTooltip"
			and not EXCLUES[f:GetName() or ""] and fondDuClient(f) then
			T.Habiller(f)
		end
		f = EnumerateFrames(f)
	end
end

-- ------------------------------------------------------------ la comparaison

local function entete(bulle)
	local h = bulle.foreverEntete
	if h then return h end
	h = CreateFrame("Frame", nil, bulle)
	h:SetWidth(ENTETE.largeur)
	h:SetHeight(ENTETE.hauteur)
	h:SetPoint("BOTTOMLEFT", bulle, "TOPLEFT", 0, ENTETE.y)
	local fond = h:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(fond, ENTETE.atlas, true)
	fond:SetAllPoints(h)
	local label = h:CreateFontString(nil, "ARTWORK", "GameTooltipText")
	label:SetPoint("CENTER", h, "CENTER", 0, 0)
	label:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	h.Label = label
	h:Hide()
	bulle.foreverEntete = h
	-- OnTooltipCleared : self.CompareHeader:Hide()
	bulle:HookScript("OnTooltipCleared", function(self)
		self.foreverEntete:Hide()
	end)
	return h
end

-- apres le client : la premiere ligne « Currently Equipped » monte dans le
-- bandeau
function T.Comparer(principale)
	principale = principale or GameTooltip
	local liste = principale and principale.shoppingTooltips
	if not liste or not CURRENTLY_EQUIPPED then return end
	for _, bulle in ipairs(liste) do
		local nom = bulle:GetName()
		local ligne = nom and _G[nom .. "TextLeft1"]
		if bulle:IsShown() and ligne and ligne:GetText() == CURRENTLY_EQUIPPED then
			T.Habiller(bulle)
			local h = entete(bulle)
			h.Label:SetText(CURRENTLY_EQUIPPED)
			h:SetWidth(h.Label:GetStringWidth() + ENTETE.marge)
			h:SetFrameLevel(math.max(bulle:GetFrameLevel() - 1, 0))
			h:Show()
			ligne:SetText("")
			-- le client recalcule la taille de l'infobulle a son Show
			bulle:Show()
		end
	end
end

-- ------------------------------------------------------------ la croix

local function habillerCroix(b)
	if not b or b.foreverCroix then return end
	b:SetWidth(CROIX.cote)
	b:SetHeight(CROIX.cote)
	b:ClearAllPoints()
	b:SetPoint("TOPRIGHT", b:GetParent(), "TOPRIGHT", CROIX.x, CROIX.y)
	for _, etat in ipairs({ { "GetNormalTexture", "redbutton-exit" },
		{ "GetPushedTexture", "redbutton-exit-pressed" },
		{ "GetHighlightTexture", "redbutton-highlight" } }) do
		local t = b[etat[1]] and b[etat[1]](b)
		if t then
			ForeverUI.SetAtlas(t, etat[2], true)
			t:ClearAllPoints()
			t:SetAllPoints(b)
			if etat[2] == "redbutton-highlight" then t:SetBlendMode("ADD") end
		end
	end
	b.foreverCroix = true
end

-- ------------------------------------------------------------ la mise en place

for _, nom in ipairs(BULLES) do
	local f = _G[nom]
	if f and fondDuClient(f) then
		T.Habiller(f)
	end
end
T.Balayer()
habillerCroix(ItemRefCloseButton)
hooksecurefunc("GameTooltip_ShowCompareItem", T.Comparer)

-- les addons charges ensuite (Blizzard_DebugTools...) et ceux qui creent
-- leurs infobulles a la connexion
local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:RegisterEvent("PLAYER_LOGIN")
veille:SetScript("OnEvent", function()
	T.Balayer()
end)
T.veille = veille
