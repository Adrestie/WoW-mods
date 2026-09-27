-- ForeverUI : les dialogues et l'infobulle des ecrans d'accueil, copies de
-- ceux de camelot.
--
-- RELEVE -- blizzard_staticpopup_glue : gluedialog.xml, gluedialog.lua,
-- gluedialoguserscaledtemplates.lua, mainline/gluedialog.lua,
-- mainline/gluedialogdefs.lua (FORCE_RENAME_CHARACTER) ; blizzard_gluexml :
-- mainline/characterselect.xml (CharacterDeleteDialog),
-- mainline/characterselect/characterselectui.lua (CharacterDeletionDialogMixin),
-- mainline/characterselect.lua et shared/characterselect/characterselectutil.lua
-- (FORCE_RENAME_CHARACTER), mainline/gluetooltip.xml ; blizzard_sharedxml :
-- sharedtooltiptemplates.xml / .lua, mainline/nineslicelayouts.lua,
-- shared/button/threeslicebuttontemplate.xml (SharedButtonTemplate).
-- Nombres de camelot, a la taille de texte par defaut (1) :
--   * dialogue (GlueDialog) : conteneur de 512 (600 avec l'icone d'alerte) au
--     centre ; bord UI-DiamondDialogBox-Border decoupe en neuf sur tout le
--     conteneur, fond UI-Frame-DialogBox-BackgroundTile en mosaique de
--     (8, -9) a (-8, 9) ; texte GlueFontNormalLarge de 450 a TOP (0, -23) ;
--     icone d'alerte 48 x 48 a LEFT (17, 0) ; boutons rouges 200 x 30
--     (GlueFontNormal) : seul, a BOTTOM (0, 18) ; a deux, le premier a
--     BOTTOMRIGHT sur BOTTOM (-6, 18), le second 15 a sa droite ; a trois, le
--     deuxieme a BOTTOM (0, 18), les autres a 15 de part et d'autre, le
--     conteneur large de 75 + 3 x 200 + 2 x 15 + 75 et le texte de ce total
--     moins 40 ; hauteur 16 + texte + 13 + bouton + 25 (25 sans bouton) ;
--     aucun type de 3.3.5 n'est en colonne (displayVertical) ni n'a de champ ;
--   * suppression (CharacterDeleteDialog) : celle de 3.3.5 (memes ancres,
--     meme calcul de hauteur), cadre DialogBorderTemplate, boutons
--     GlueDialogButtonTemplate (200 x 30), polices GlueFontNormalLarge,
--     GlueFontNormalSmall, GlueFontHighlight (champ) ;
--   * renommage force : le dialogue FORCE_RENAME_CHARACTER (showAlert, texte
--     « message\nCHAR_RENAME_INSTRUCTIONS », champ TooltipBackdropTemplate de
--     130 x 32 au centre, marges de texte 12 / 5 / 0 / 5, GlueFontHighlight,
--     OK et Cancel ; hauteur + 13 + champ) ;
--   * infobulle (GlueTooltip) : disposition TooltipDefaultLayout, fond
--     TOOLTIP_DEFAULT_BACKGROUND_COLOR (0,09) opaque, bord blanc ; premiere
--     ligne GlueFontNormal, deuxieme GlueFontNormalSmall.
-- Les cadres restent ceux du client (ses scripts decident de tout) : on les
-- rhabille, et on les repose apres lui.

local G = ForeverUIGlue

local POLICES_BOUTON = { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" }
local BOUTON_L, BOUTON_H = 200, 30

-- le conteneur d'un dialogue (BG.Top et BG.Bottom de GlueDialog), en regions
-- de l'hote ; rend la fonction qui le dimensionne
local function conteneur(hote)
	hote:SetBackdrop(nil)
	local fond = hote:CreateTexture(nil, "BACKGROUND")
	fond:SetPoint("TOPLEFT", hote, "TOPLEFT", 8, -9)
	fond:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", -8, 9)
	local bord = G.AtlasEtire(hote, "UI-DiamondDialogBox-Border", "BORDER")
	bord.rect:SetAllPoints(hote)
	return function(largeur, hauteur)
		hote:SetWidth(largeur)
		hote:SetHeight(hauteur)
		G.Mosaique(fond, "UI-Frame-DialogBox-BackgroundTile", largeur - 16, hauteur - 18)
	end
end

-- GlueDialogButtonTemplate : le bouton rouge de 200 x 30
local function boutonDialogue(b)
	b:SetWidth(BOUTON_L)
	b:SetHeight(BOUTON_H)
	G.BoutonTroisTranches(b, "128-RedButton", POLICES_BOUTON)
end

-- ------------------------------------------------------------ le dialogue

local dimensionnerDialogue = conteneur(GlueDialogBackground)
GlueDialogText:SetFontObject(G.Police("GlueFontNormalLarge"))
-- SimpleHTML : une police par element ; si 3.3.5 refuse la forme a element,
-- le texte garde la police du client
for _, e in ipairs({ { "P", "GlueFontNormalLarge" }, { "H1", "GlueFontNormalLarge" }, { "H2", "GlueFontHighlight" } }) do
	pcall(GlueDialogHTML.SetFontObject, GlueDialogHTML, e[1], G.Police(e[2]))
end
for i = 1, 3 do
	boutonDialogue(_G["GlueDialogButton" .. i])
end
-- GlueDialog_OnUpdate ne fait que reposer l'art de 3.3.5 sur les boutons, a
-- chaque image
GlueDialog:SetScript("OnUpdate", nil)

-- GlueDialogMixin:Init et :Resize, apres GlueDialog_Show du client
local function mettreEnPageDialogue()
	local info = GlueDialogTypes[GlueDialog.which]
	if not info then
		return
	end
	local fond = GlueDialogBackground
	local boutons = {}
	for i = 1, 3 do
		local b = _G["GlueDialogButton" .. i]
		b:ClearAllPoints()
		if b:IsShown() then
			table.insert(boutons, b)
		end
	end
	local n = #boutons
	if n == 3 then
		boutons[2]:SetPoint("BOTTOM", fond, "BOTTOM", 0, 18)
		boutons[1]:SetPoint("RIGHT", boutons[2], "LEFT", -15, 0)
		boutons[3]:SetPoint("LEFT", boutons[2], "RIGHT", 15, 0)
	elseif n == 2 then
		boutons[1]:SetPoint("BOTTOMRIGHT", fond, "BOTTOM", -6, 18)
		boutons[2]:SetPoint("LEFT", boutons[1], "RIGHT", 15, 0)
	elseif n == 1 then
		boutons[1]:SetPoint("BOTTOM", fond, "BOTTOM", 0, 18)
	end

	local largeur, largeurTexte = info.showAlert and 600 or 512, 450
	if n == 3 then
		largeur = 75 + 3 * BOUTON_L + 2 * 15 + 75
		largeurTexte = largeur - 40
	end
	GlueDialogAlertIcon:ClearAllPoints()
	GlueDialogAlertIcon:SetPoint("LEFT", fond, "LEFT", 17, 0)

	local hauteurTexte
	if info.html then
		GlueDialogHTML:ClearAllPoints()
		GlueDialogHTML:SetPoint("TOP", fond, "TOP", 0, -23)
		hauteurTexte = select(4, GlueDialogHTML:GetBoundsRect()) or 0
	else
		GlueDialogText:ClearAllPoints()
		GlueDialogText:SetPoint("TOP", fond, "TOP", 0, -23)
		GlueDialogText:SetWidth(largeurTexte)
		hauteurTexte = GlueDialogText:GetHeight()
	end
	local hauteur = 16 + hauteurTexte + ((n > 0) and (13 + BOUTON_H + 25) or 25)
	dimensionnerDialogue(largeur, math.floor(hauteur + 0.5))
end

G.AccrocherFonction("GlueDialog_Show", mettreEnPageDialogue)
-- UPDATE_STATUS_DIALOG change le texte et la hauteur
G.Accrocher(GlueDialog, "OnEvent", function(_, event)
	if event == "UPDATE_STATUS_DIALOG" then
		mettreEnPageDialogue()
	end
end)

-- ------------------------------------------------------------ la suppression

CharacterDeleteBackground:SetBackdrop(nil)
G.CadreDialogue(CharacterDeleteBackground)
CharacterDeleteText1:SetFontObject(G.Police("GlueFontNormalLarge"))
CharacterDeleteText2:SetFontObject(G.Police("GlueFontNormalSmall"))
CharacterDeleteEditBox:SetFontObject(G.Police("GlueFontHighlight"))
boutonDialogue(CharacterDeleteButton1)
boutonDialogue(CharacterDeleteButton2)

-- ------------------------------------------------------------ le renommage force

local dimensionnerRenommage = conteneur(CharacterRenameBackground)
local texteRenommage = CharacterRenameText1
texteRenommage:SetFontObject(G.Police("GlueFontNormalLarge"))
texteRenommage:SetWidth(450)
texteRenommage:ClearAllPoints()
texteRenommage:SetPoint("TOP", CharacterRenameBackground, "TOP", 0, -23)
-- les consignes rejoignent le texte (un seul texte chez camelot)
CharacterRenameText2:SetAlpha(0)
CharacterRenameText2:Hide()
CharacterRenameAlertIcon:ClearAllPoints()
CharacterRenameAlertIcon:SetPoint("LEFT", CharacterRenameBackground, "LEFT", 17, 0)

local champ = CharacterRenameEditBox
for _, r in ipairs({ champ:GetRegions() }) do
	if r:GetObjectType() == "Texture" then
		r:SetTexture(nil)
		r:SetAlpha(0)
		r:Hide()
	end
end
champ:SetWidth(130)
champ:SetHeight(32)
champ:SetTextInsets(12, 5, 0, 5)
champ:SetFontObject(G.Police("GlueFontHighlight"))
champ:ClearAllPoints()
champ:SetPoint("CENTER", CharacterRenameDialog, "CENTER")
G.FondInfobulle(champ, "TooltipDefaultLayout", G.GLUE_BACKDROP_COLOR)

boutonDialogue(CharacterRenameButton1)
boutonDialogue(CharacterRenameButton2)
CharacterRenameButton1:ClearAllPoints()
CharacterRenameButton1:SetPoint("BOTTOMRIGHT", CharacterRenameBackground, "BOTTOM", -6, 18)
CharacterRenameButton2:ClearAllPoints()
CharacterRenameButton2:SetPoint("LEFT", CharacterRenameButton1, "RIGHT", 15, 0)

local function mettreEnPageRenommage()
	local hauteur = 16 + texteRenommage:GetHeight() + 13 + BOUTON_H + 25 + 13 + champ:GetHeight()
	dimensionnerRenommage(600, math.floor(hauteur + 0.5))
end
mettreEnPageRenommage()

-- le client montre le dialogue, puis y ecrit le message
G.Accrocher(CharacterSelect, "OnEvent", function(_, event, message)
	if event == "FORCE_RENAME_CHARACTER" then
		texteRenommage:SetText(string.format("%s\n%s", _G[message] or "", CHAR_RENAME_INSTRUCTIONS))
		mettreEnPageRenommage()
	end
end)
G.Accrocher(CharacterRenameDialog, "OnShow", function()
	champ:SetFocus()
end)

-- ------------------------------------------------------------ l'infobulle

GlueTooltip:SetBackdrop(nil)
G.FondInfobulle(GlueTooltip, "TooltipDefaultLayout", G.GLUE_BACKDROP_COLOR)
for _, v in ipairs({ { "TextLeft1", "GlueFontNormal" }, { "TextRight1", "GlueFontNormal" },
		{ "TextLeft2", "GlueFontNormalSmall" }, { "TextRight2", "GlueFontNormalSmall" } }) do
	_G["GlueTooltip" .. v[1]]:SetFontObject(G.Police(v[2]))
end
-- GlueTooltip_SetOwner ajoute un point sans retirer les autres : on les
-- retire a la fermeture, pour qu'un ancrage d'une autre forme (ANCHOR_LEFT de
-- camelot) ne tende pas l'infobulle entre deux points
GlueTooltip:ClearAllPoints()
G.Accrocher(GlueTooltip, "OnHide", function(self)
	self:ClearAllPoints()
end)
