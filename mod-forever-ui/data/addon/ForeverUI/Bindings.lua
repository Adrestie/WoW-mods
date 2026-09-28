-- ForeverUI : la fenetre des raccourcis clavier (KeyBindingFrame,
-- Blizzard_BindingUI, chargee a la demande), a la DA de camelot (demande de
-- l'utilisateur, 2026-09-28 : « fait le menu et reglages », etape 2).
--
-- RELEVE -- CE QUE LE CLIENT CHARGE (Blizzard_BindingUI.xml / .lua de
-- 3.3.5, par la chaine d'archives) :
--   KeyBindingFrame  640 x 512, TOP (0, -100), strate DIALOG ; six textures
--     UI-KeyBindingFrame-* dont la partie visible va de (4, 4) a (596, 500)
--     (mesure sur l'image) ; en-tete UI-DialogBox-Header et
--     KeyBindingFrameHeaderText (KEY_BINDINGS, ou CHARACTER_KEY_BINDINGS) ;
--     KeyBindingFrameCommandLabel (26, -35) puis KEY1 et KEY2 ;
--     KeyBindingFrameOutputText a BOTTOM (0, 52) ; ces textes sont des
--     REGIONS de la fenetre.
--   17 lignes KeyBindingFrameBindingTemplate (560 x 25, la premiere a (27,
--     -53), puis 2 plus haut que le bas de la precedente) : Description,
--     Header, deux boutons UIPanelButtonTemplate2 180 x 22 (Key1Button a
--     175, Key2Button a sa suite) ; le choisi par LockHighlight.
--   KeyBindingFrameScrollFrame (FauxScrollFrameTemplate 560 x 390 a (2,
--     -53)) et sa barre UIPanelScrollBarTemplate.
--   KeyBindingFrameCharacterButton (UICheckButtonTemplate 20 x 20, TOPLEFT
--     sur TOPRIGHT (-245, -12)).
--   Boutons 130 x 22 : Default (gris) BOTTOMLEFT (10, 21) ; Cancel
--     BOTTOMRIGHT (-50, 21), Okay et Unbind a sa gauche. Echap = Cancel.
--
-- RELEVE -- CAMELOT : les raccourcis sont une categorie de SettingsPanel
-- (blizzard_settings_shared/blizzard_keybindings.xml) :
--   KeyBindingFrameBindingButtonTemplate  UIMenuButtonStretchTemplate (le
--     bouton argente, voir Gb.BoutonArgent) ; SelectedHighlight
--     UI-Silver-Button-Select en ADD, 160 x 20 a CENTER (0, -3), montre sur
--     le bouton choisi ; texte CENTER (0, -1).
--   la fenetre et le cadre : ceux des reglages (etape 1, VALIDEE) --
--     SettingsFrameTemplate translucide, croix, boutons UIPanelButton a
--     BOTTOMRIGHT (-16, 16) et 2 entre eux, Defaults a BOTTOMLEFT (16, 16),
--     case SettingsCheckbox, cadre interieur Options_InnerFrame (valide sur
--     l'Interface), barre MinimalScrollBar.
--
-- CE QUI DIFFERE, ET POURQUOI. « 3.3.5 rhabillee », comme les reglages :
-- les lignes, les boutons et la logique du client restent.
--   La fenetre de camelot recouvre la partie VISIBLE de l'art de 3.3.5.
--   ECART : la case « Raccourcis propres au personnage » est, en 3.3.5, dans
--   la barre de titre ; la fenetre grandit de 30 et le contenu descend de 24
--   pour la loger dessous, sans toucher aux intitules des colonnes.
--   Les intitules (COMMAND, KEY1, KEY2), le message du bas et le titre sont
--   des regions de la fenetre du client, que le fond de camelot couvrirait :
--   ils sont recopies au-dessus (Gb.Recopier).
--   Le liseré du bouton choisi a la largeur du bouton de 3.3.5 (180).
--   La croix fait Annuler, comme Echap : rien de ce qu'Annuler reecrit
--   (LoadBindings, KeyBindingFrame.selected) n'est lu par le code protege du
--   client, a la difference des reglages.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

local Gb = ForeverUI.Gabarits

local K = {}
ForeverUI.Raccourcis = K

local N = {
	agrandir = 30, decaler = 24,
	fenetre = { g = 4, h = -4, d = -44, b = 12 },   -- la partie visible de l'art de 3.3.5
	commande = { 26, -35 }, liste = { 27, -53 }, defile = { 2, -53 },
	caseXY = { -245, -12 },
	interieur = { g = 15, h = -49, d = -50, b = 3 },  -- b : sous la derniere ligne
	lignes = 17, ligneH = 25, lignePas = 23,
	bouton = { 130, 22 }, bord = 16, ecart = 2,
	choixH = 20, choixY = -3,
}

local SEP = string.char(92)
local CHOIX = "Interface" .. SEP .. "ForeverUI" .. SEP .. "buttons" .. SEP .. "ui-silver-button-select"

-- le liseré du bouton choisi : KeyBindingFrame.selected et keyID, lus
function K.Peindre()
	local f = KeyBindingFrame
	if not f then return end
	for i = 1, N.lignes do
		for k = 1, 2 do
			local b = _G["KeyBindingFrameBinding" .. i .. "Key" .. k .. "Button"]
			if b and b.foreverChoix then
				local choisi = f.selected ~= nil and b.commandName == f.selected and f.keyID == b:GetID()
				Gb.Montrer(b.foreverChoix, choisi)
			end
		end
	end
end

local function habillerBouton(b)
	Gb.BoutonArgent(b)
	local t = b:CreateTexture(nil, "OVERLAY")
	t:SetTexture(CHOIX)
	t:SetBlendMode("ADD")
	t:SetWidth(b:GetWidth())
	t:SetHeight(N.choixH)
	t:SetPoint("CENTER", b, "CENTER", 0, N.choixY)
	t:Hide()
	b.foreverChoix = t
end

function K.Habiller()
	local f = KeyBindingFrame
	if not f or f.foreverHabit then return end
	-- la partie visible, puis la place de la case sous la barre de titre
	f:SetHeight(f:GetHeight() + N.agrandir)
	local fen = CreateFrame("Frame", nil, f)
	fen:SetFrameLevel(f:GetFrameLevel())
	fen:SetPoint("TOPLEFT", f, "TOPLEFT", N.fenetre.g, N.fenetre.h)
	fen:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", N.fenetre.d, N.fenetre.b)
	-- l'art de 3.3.5 (six morceaux et l'en-tete) s'eteint
	for _, r in ipairs({ f:GetRegions() }) do
		if r:GetObjectType() == "Texture" then
			r:SetAlpha(0)
		end
	end
	local habit = Gb.Fenetre(fen, KeyBindingFrameHeaderText:GetText())
	habit.stries:Hide()
	f.foreverHabit = habit
	KeyBindingFrameHeaderText:SetAlpha(0)
	local function titre()
		habit.titre:SetText(KeyBindingFrameHeaderText:GetText() or "")
	end
	hooksecurefunc(KeyBindingFrameHeaderText, "SetText", titre)
	hooksecurefunc(KeyBindingFrameHeaderText, "SetFormattedText", titre)
	-- la croix : Annuler, comme Echap
	local croix = CreateFrame("Button", "KeyBindingFrameForeverUICloseButton", f)
	croix:SetFrameLevel(f:GetFrameLevel() + 20)
	Gb.Croix(croix, fen)
	croix:SetScript("OnClick", function()
		KeyBindingFrameCancelButton:Click()
	end)
	f.foreverCroix = croix

	-- le contenu descend
	local d = N.decaler
	KeyBindingFrameCommandLabel:ClearAllPoints()
	KeyBindingFrameCommandLabel:SetPoint("TOPLEFT", f, "TOPLEFT", N.commande[1], N.commande[2] - d)
	KeyBindingFrameBinding1:ClearAllPoints()
	KeyBindingFrameBinding1:SetPoint("TOPLEFT", f, "TOPLEFT", N.liste[1], N.liste[2] - d)
	KeyBindingFrameScrollFrame:ClearAllPoints()
	KeyBindingFrameScrollFrame:SetPoint("TOPLEFT", f, "TOPLEFT", N.defile[1], N.defile[2] - d)
	KeyBindingFrameCharacterButton:ClearAllPoints()
	KeyBindingFrameCharacterButton:SetPoint("TOPLEFT", f, "TOPRIGHT", N.caseXY[1], N.caseXY[2] - d)

	-- le cadre interieur autour des lignes et de la barre
	local I = N.interieur
	local basListe = N.liste[2] - d - (N.lignes - 1) * N.lignePas - N.ligneH
	local rect = CreateFrame("Frame", nil, fen)
	rect:SetPoint("TOPLEFT", f, "TOPLEFT", I.g, I.h - d)
	rect:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", I.d, basListe - I.b)
	fen.foreverRect = rect
	habit.interieur = Gb.CadreInterieur(fen, rect)

	-- les textes du client, recopies au-dessus du fond
	habit.textes = {}
	for _, fs in ipairs({ KeyBindingFrameCommandLabel, KeyBindingFrameKey1Label,
			KeyBindingFrameKey2Label, KeyBindingFrameOutputText }) do
		habit.textes[#habit.textes + 1] = Gb.Recopier(fs, habit.conteneur, GameFontNormal)
	end

	-- les boutons argentes et leur liseré
	for i = 1, N.lignes do
		for k = 1, 2 do
			local b = _G["KeyBindingFrameBinding" .. i .. "Key" .. k .. "Button"]
			if b then habillerBouton(b) end
		end
	end

	-- la barre, la case
	Gb.Barre(KeyBindingFrameScrollFrameScrollBar)
	ForeverUI.Reglages.Case(KeyBindingFrameCharacterButton)

	-- les boutons du bas : UIPanelButtonTemplate
	local precedent
	for _, b in ipairs({ KeyBindingFrameCancelButton, KeyBindingFrameOkayButton, KeyBindingFrameUnbindButton }) do
		b:SetWidth(N.bouton[1])
		b:SetHeight(N.bouton[2])
		Gb.BoutonPanneau(b)
		b:ClearAllPoints()
		if precedent then
			b:SetPoint("RIGHT", precedent, "LEFT", -N.ecart, 0)
		else
			b:SetPoint("BOTTOMRIGHT", fen, "BOTTOMRIGHT", -N.bord, N.bord)
		end
		precedent = b
	end
	local defaut = KeyBindingFrameDefaultButton
	defaut:SetWidth(N.bouton[1])
	defaut:SetHeight(N.bouton[2])
	Gb.BoutonPanneau(defaut)
	defaut:ClearAllPoints()
	defaut:SetPoint("BOTTOMLEFT", fen, "BOTTOMLEFT", N.bord, N.bord)

	hooksecurefunc("KeyBindingFrame_Update", K.Peindre)
	hooksecurefunc("KeyBindingFrame_SetSelected", K.Peindre)
	K.Peindre()
end

-- chargee a la demande : a son arrivee, ou tout de suite si elle est la
if KeyBindingFrame then
	K.Habiller()
end
local veille = CreateFrame("Frame")
veille:RegisterEvent("ADDON_LOADED")
veille:SetScript("OnEvent", function(self, _, nom)
	if nom == "Blizzard_BindingUI" then
		K.Habiller()
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
K.veille = veille
