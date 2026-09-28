-- ForeverUI : le selecteur de couleur (ColorPickerFrame) et la petite
-- fenetre d'opacite (OpacityFrame), a la DA de camelot (demande de
-- l'utilisateur, 2026-09-28 : « fait le menu et reglages », etape 3).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (ColorPickerFrame.xml de 3.3.5) :
--   ColorPickerFrame : un ColorSelect 365 x 200 (305 sans opacite, pose a
--     son OnShow), <Backdrop> UI-DialogBox, en-tete ColorPickerFrameHeader
--     et un texte sans nom (COLOR_PICKER) ; roue ColorPickerWheel 128 x 128
--     a (16, -32), barre de valeur 32 x 128 a sa droite (24) ; ColorSwatch
--     32 x 32 a (225, -32) ; OpacitySliderFrame (Slider vertical 16 x 128,
--     <Backdrop> UI-SliderBar, curseur UI-SliderBar-Button-Vertical 32 x 32,
--     textes « - », « + » et $parentText) a 32 a droite du nuancier ;
--     boutons GameMenuButtonTemplate Cancel (BOTTOMRIGHT (-10, 10)) et
--     Okay a sa gauche.
--   OpacityFrame 80 x 180 : <Backdrop> UI-DialogBox, son curseur.
--
-- RELEVE -- CAMELOT (blizzard_colorpickerframe/mainline, le [Family] de
-- camelot) :
--   ColorPickerFrame 388 x 210 (331 sans opacite) : DialogBorderTemplate,
--     DialogHeaderTemplate (COLOR_PICKER) ; ColorPicker a (23, -30), roue a
--     (0, -7), barre de valeur a 24, colonne d'opacite (ColorAlphaTexture,
--     32 x 128) a 24 encore, sur le damier colorpicker-checkerboard (a
--     TOPRIGHT (-157, -37)), curseur
--     UI-ColorPicker-Buttons (48 x 14, 0,25 / 1 / 0 / 0,875, comme celui de
--     la valeur) ; ColorSwatchCurrent 47 x 25 a TOPRIGHT (-100, -37) ;
--     boutons UIPanelButtonTemplate 154 x 22 dans un pied de 331 a BOTTOM
--     (0, 12) : Cancel a sa droite (-11,5), Okay a la gauche de Cancel.
--   OpacityFrame : DialogBorderTemplate ; son curseur garde l'art
--     BACKDROP_SLIDER_8_8 de 3.3.5.
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee » : le curseur d'opacite
-- du client reste (sa valeur et son OnValueChanged) et prend la place et
-- l'allure de la colonne de camelot -- damier, degrade de la couleur
-- choisie du plein (en haut, cote « + » du client) au transparent, curseur
-- en fleches ; ses textes « - », « + » et « Opacity » s'eteignent.
-- ColorSwatchOriginal et le champ hexadecimal de camelot n'ont pas
-- d'equivalent en 3.3.5 : pas ajoutes.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local CP = {}
ForeverUI.Couleurs = CP

local SEP = string.char(92)

local N = {
	largeur = 388, largeurSans = 331, hauteur = 210,
	roue = { 23, -37 },
	nuancier = { l = 47, h = 25, x = -100, y = -37 },
	opacite = { x = -157, y = -37, l = 32, h = 128 },
	curseur = { l = 48, h = 14, uv = { 0.25, 1, 0, 0.875 } },
	bouton = { 154, 22 }, piedY = 12,
}

-- la colonne d'opacite : le degrade de la couleur choisie sur le damier
function CP.Degrade()
	local s = OpacitySliderFrame
	local d = s and s.foreverDegrade
	if not d then return end
	local r, g, b = ColorPickerFrame:GetColorRGB()
	d:SetGradientAlpha("VERTICAL", r, g, b, 0, r, g, b, 1)
end

function CP.Habiller()
	local f = ColorPickerFrame
	if not f or f.foreverHabit then return end
	f:SetBackdrop(nil)
	f:SetHeight(N.hauteur)
	local cadre, fond = Gb.CadreDialogue(f)
	-- l'en-tete du client (texture nommee et texte sans nom)
	ColorPickerFrameHeader:SetAlpha(0)
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == COLOR_PICKER then
			r:SetAlpha(0)
		end
	end
	local entete = Gb.EnTete(f, COLOR_PICKER, GameFontNormal)
	f.foreverHabit = { cadre = cadre, fond = fond, entete = entete }

	-- la roue (la barre de valeur la suit, a 24), le nuancier courant
	ColorPickerWheel:ClearAllPoints()
	ColorPickerWheel:SetPoint("TOPLEFT", f, "TOPLEFT", N.roue[1], N.roue[2])
	ColorSwatch:SetWidth(N.nuancier.l)
	ColorSwatch:SetHeight(N.nuancier.h)
	ColorSwatch:ClearAllPoints()
	ColorSwatch:SetPoint("TOPLEFT", f, "TOPRIGHT", N.nuancier.x, N.nuancier.y)

	-- la colonne d'opacite de camelot sur le curseur du client
	local s = OpacitySliderFrame
	local O = N.opacite
	s:SetBackdrop(nil)
	s:SetWidth(O.l)
	s:SetHeight(O.h)
	s:ClearAllPoints()
	s:SetPoint("TOPLEFT", f, "TOPRIGHT", O.x, O.y)
	for _, r in ipairs({ s:GetRegions() }) do
		if r:GetObjectType() == "FontString" then r:SetAlpha(0) end
	end
	local damier = s:CreateTexture(nil, "BACKGROUND")
	ForeverUI.SetAtlas(damier, "colorpicker-checkerboard")
	damier:SetAllPoints(s)
	local degrade = s:CreateTexture(nil, "BORDER")
	degrade:SetTexture(1, 1, 1, 1)
	degrade:SetAllPoints(s)
	s.foreverDegrade = degrade
	local K = N.curseur
	s:SetThumbTexture("Interface" .. SEP .. "Buttons" .. SEP .. "UI-ColorPicker-Buttons")
	local pouce = s:GetThumbTexture()
	pouce:SetTexCoord(K.uv[1], K.uv[2], K.uv[3], K.uv[4])
	pouce:SetWidth(K.l)
	pouce:SetHeight(K.h)
	f.foreverHabit.damier = damier

	-- les boutons : UIPanelButtonTemplate 154 x 22, la paire centree
	for _, b in ipairs({ ColorPickerOkayButton, ColorPickerCancelButton }) do
		b:SetWidth(N.bouton[1])
		b:SetHeight(N.bouton[2])
		Gb.BoutonPanneau(b)
		b:ClearAllPoints()
	end
	ColorPickerOkayButton:SetPoint("BOTTOMRIGHT", f, "BOTTOM", 0, N.piedY)
	ColorPickerCancelButton:SetPoint("BOTTOMLEFT", f, "BOTTOM", 0, N.piedY)

	-- apres l'OnShow du client (365 / 305) : les largeurs de camelot
	f:HookScript("OnShow", function(self)
		self:SetWidth(self.hasOpacity and N.largeur or N.largeurSans)
		CP.Degrade()
	end)
	f:HookScript("OnColorSelect", CP.Degrade)

	-- la petite fenetre d'opacite : son cadre seul
	if OpacityFrame then
		OpacityFrame:SetBackdrop(nil)
		OpacityFrame.foreverHabit = { Gb.CadreDialogue(OpacityFrame) }
	end
end

CP.Habiller()
