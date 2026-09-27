-- ForeverUI : l'ecran de connexion, copie de celui de camelot.
--
-- RELEVE -- blizzard_gluexml/mainline/accountlogin.xml et .lua ([Family] =
-- mainline pour camelot), camelot/accountloginoverrides.lua,
-- blizzard_gluexmlbase/mainline/gluebuttons.xml et constants.lua. Tous les
-- nombres ci-dessous sont ceux de camelot, en unites de camelot (l'echelle
-- est posee une fois sur GlueParent, ForeverUIGlue.lua) :
--   * logo Blizzard 100 x 100 a BOTTOM (0, 8) ; mention legale
--     GlueFontNormalSmall a BOTTOM (0, 10) ; version GlueFontNormalSmall a
--     BOTTOMLEFT (10, 10) ; logo du jeu 256 x 128 a TOPLEFT (3, -7) ;
--   * compte : champ 320 x 50 au CENTRE (0, -15) (AdjustAnchor de camelot),
--     fond TooltipBackdropTemplate / TooltipMixedLayout, GLUE_BACKDROP_COLOR
--     (0,09) et GLUE_BACKDROP_BORDER_COLOR (0,8) ; texte GlueLoginEditBoxFont,
--     marges (12, 5, 0, 5) ; libelle GlueFontNormalLogin 600 x 64, BOTTOM sur
--     le haut du champ (0, -19) ;
--   * mot de passe : meme champ, TOP sur le bas du compte (0, -43) ; libelle
--     256 x 64 ;
--   * Log In : GlueButtonBigTemplate 250 x 66, rouge, GlueFontNormalLogin /
--     Highlight / Disable, TOP sur le bas du mot de passe (0, -50) ;
--   * « se souvenir » : ResizeCheckButtonTemplate -- case 28 x 28
--     (UI-CheckBox-*), libelle GlueFontNormalLogin a 2 a sa droite -- le bloc
--     pose par son BOTTOM sur le haut de Log In (0, 2) ;
--   * Quit : GlueButtonTemplate (200 x 30, GlueFontNormal) a BOTTOMRIGHT
--     (-24, 56) ; Create Account 10 au-dessus ; Menu 10 au-dessus ;
--   * a l'ouverture, l'interface apparait en 0,75 s (FadeIn) ;
--   * Echap dans un champ lui retire la main (AccountLogin_OnEscapePressed).
-- Les textes suivent la langue du client (chaines de 3.3.5) ; « Menu »
-- (MAINMENU) n'existe pas dans 3.3.5 : texte de camelot.

local G = ForeverUIGlue
local ui = AccountLoginUI
local compte = AccountLoginAccountEdit
local motDePasse = AccountLoginPasswordEdit
local connexion = AccountLoginLoginButton
local case = AccountLoginSaveAccountName

-- ------------------------------------------------------------ le pied de page

for _, r in ipairs({ ui:GetRegions() }) do
	if r:GetObjectType() == "FontString" and r:GetText() == BLIZZ_DISCLAIMER then
		r:SetFontObject(G.Police("GlueFontNormalSmall"))
		r:ClearAllPoints()
		r:SetPoint("BOTTOM", ui, "BOTTOM", 0, 10)
	end
end
AccountLoginVersion:SetFontObject(G.Police("GlueFontNormalSmall"))
AccountLoginVersion:SetJustifyH("LEFT")
AccountLoginVersion:ClearAllPoints()
AccountLoginVersion:SetPoint("BOTTOMLEFT", ui, "BOTTOMLEFT", 10, 10)

-- ------------------------------------------------------------ les champs

local function champ(edit, libelle, largeurLibelle)
	edit:SetBackdrop(nil)
	edit:SetWidth(320)
	edit:SetHeight(50)
	G.FondInfobulle(edit, "TooltipMixedLayout", G.GLUE_BACKDROP_COLOR, G.GLUE_BACKDROP_BORDER_COLOR)
	edit:SetFontObject(G.Police("GlueLoginEditBoxFont"))
	edit:SetTextInsets(12, 5, 0, 5)
	libelle:SetFontObject(G.Police("GlueFontNormalLogin"))
	libelle:SetJustifyH("CENTER")
	libelle:SetWidth(largeurLibelle)
	libelle:SetHeight(64)
	libelle:ClearAllPoints()
	libelle:SetPoint("BOTTOM", edit, "TOP", 0, -19)
	-- Echap retire la main au champ, sans quitter le jeu
	edit:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
end

local libelleMotDePasse
for _, r in ipairs({ motDePasse:GetRegions() }) do
	if r:GetObjectType() == "FontString" and r:GetText() == PASSWORD then
		libelleMotDePasse = r
	end
end
champ(compte, AccountLoginAccountEditLabel, 600)
champ(motDePasse, libelleMotDePasse, 256)
-- l'invite de 3.3.5 dans le champ vide : camelot n'en a pas (le client la
-- montre et la cache lui-meme : on la rend invisible)
AccountLoginAccountEditFill:SetAlpha(0)

-- ------------------------------------------------------------ les boutons

G.BoutonTroisTranches(connexion, "128-RedButton", { "GlueFontNormalLogin", "GlueFontHighlightLogin", "GlueFontDisableLogin" })
connexion:SetWidth(250)
connexion:SetHeight(66)

local quitter = AccountLoginExitButton
G.BoutonTroisTranches(quitter, "128-RedButton", { "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" })
quitter:SetWidth(200)
quitter:SetHeight(30)

local creer = G.CreerBoutonTroisTranches("ForeverUIAccountLoginCreateAccountButton", ui, 200, 30, "128-RedButton",
	{ "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" }, CREATE_ACCOUNT)
creer:SetScript("OnClick", function()
	AccountLoginManageAccountButton:Click()
end)

local menu = G.CreerBoutonTroisTranches("ForeverUIAccountLoginMenuButton", ui, 200, 30, "128-RedButton",
	{ "GlueFontNormal", "GlueFontHighlight", "GlueFontDisable" }, "Menu")
menu:SetScript("OnClick", function()
	G.MontrerMenu()
end)

-- ce que camelot n'a pas sur cet ecran : ses fonctions passent par le menu
local CACHES = {
	"AccountLoginTOSButton", "AccountLoginCreditsButton", "AccountLoginCinematicsButton",
	"OptionsButton", "AccountLoginCommunityButton", "AccountLoginManageAccountButton",
	"AccountLoginShowLauncher", "AccountLoginUpgradeAccountButton",
}

-- ------------------------------------------------------------ la case

local libelleCase = AccountLoginSaveAccountNameText
libelleCase:SetFontObject(G.Police("GlueFontNormalLogin"))
case:SetWidth(28)
case:SetHeight(28)
local bloc = CreateFrame("Frame", nil, ui)

local function poserCase()
	-- ResizeLayoutFrame : la case a TOPLEFT, le libelle a 2 a sa droite ; le
	-- bloc a la largeur et la hauteur de son contenu
	local lw, lh = libelleCase:GetStringWidth(), libelleCase:GetStringHeight()
	bloc:SetWidth(28 + 2 + lw)
	bloc:SetHeight(math.max(28, lh))
	bloc:ClearAllPoints()
	bloc:SetPoint("BOTTOM", connexion, "TOP", 0, 2)
	case:ClearAllPoints()
	case:SetPoint("TOPLEFT", bloc, "TOPLEFT")
	libelleCase:ClearAllPoints()
	libelleCase:SetPoint("LEFT", case, "RIGHT", 2, 0)
end

-- ------------------------------------------------------------ la mise en page

local function poser()
	compte:ClearAllPoints()
	compte:SetPoint("CENTER", ui, "CENTER", 0, -15)
	motDePasse:ClearAllPoints()
	motDePasse:SetPoint("TOP", compte, "BOTTOM", 0, -43)
	connexion:ClearAllPoints()
	connexion:SetPoint("TOP", motDePasse, "BOTTOM", 0, -50)
	poserCase()
	quitter:ClearAllPoints()
	quitter:SetPoint("BOTTOMRIGHT", ui, "BOTTOMRIGHT", -24, 56)
	creer:ClearAllPoints()
	creer:SetPoint("BOTTOM", quitter, "TOP", 0, 10)
	menu:ClearAllPoints()
	menu:SetPoint("BOTTOM", creer, "TOP", 0, 10)
	for _, nom in ipairs(CACHES) do
		local f = _G[nom]
		if f then f:Hide() end
	end
	-- le texte de la case de lancement est une region de l'ecran
	for _, r in ipairs({ ui:GetRegions() }) do
		if r:GetObjectType() == "FontString" and r:GetText() == SHOW_LAUNCHER then
			r:Hide()
		end
	end
end
poser()

-- l'apparition en 0,75 s (FadeIn de AccountLoginUI)
local fondu = CreateFrame("Frame", nil, ui)
fondu:Hide()
fondu:SetScript("OnUpdate", function(self, ecoule)
	self.t = self.t + (ecoule or 0)
	local k = math.min(1, self.t / 0.75)
	ui:SetAlpha(k)
	if k >= 1 then self:Hide() end
end)

-- a chaque ouverture, apres le client : AccountLogin_SetupAccountListDDL
-- ajoute ses propres ancres au mot de passe et au bouton, et le client
-- remontre certains de ses boutons
G.Accrocher(AccountLogin, "OnShow", function()
	poser()
	fondu.t = 0
	ui:SetAlpha(0)
	fondu:Show()
end)

-- Echap sur l'ecran ne quitte plus le jeu (camelot) ; les autres touches
-- restent au client
local avant = AccountLogin:GetScript("OnKeyDown")
AccountLogin:SetScript("OnKeyDown", function(self, touche, ...)
	if touche == "ESCAPE" then
		return
	end
	if avant then
		avant(self, touche, ...)
	end
end)
