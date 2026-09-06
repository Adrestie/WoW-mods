--[[----------------------------------------------------------------------------
    Solstice et Équinoxe — la jauge céleste, côté client

    Expédiée au client par AIO : rien à installer, rien à empaqueter.

    ON NE DESSINE PLUS DE BARRE. Le client porte déjà l'addon EclipseBarFrame
    (dans patch-frFR-z.mpq : Interface\addons\EclipseBarFrame\), une barre
    ancrée sous le portrait du joueur. On la DÉTOURNE plutôt que d'en poser
    une seconde.

    CE QUE L'ADDON FAIT DE LUI-MÊME, et qu'on remplace :

      * il ne s'affiche que pour un druide portant la forme de sélénien
        (24858) — ça nous convient, on n'y touche pas ;
      * son curseur suit la DURÉE RESTANTE des buffs d'Éclipse natifs
        48517 (solaire) et 48518 (lunaire), xPos = ±38 x (durée / 15) ;
      * il allume la moitié solaire ou lunaire, éteint l'autre et fait
        palpiter un halo sur l'astre atteint, selon ces mêmes buffs.

    CE QU'ON MET À LA PLACE :

      * le curseur suit NOTRE JAUGE, xPos = 38 x cran / 3, le cran venant des
        piles de « Jauge lunaire » (8610032) et « Jauge solaire » (8610033) —
        auras qui DOIVENT rester visibles : marquées sans icône le
        2026-09-04, elles ont cessé d'être rendues par UnitBuff et le
        curseur s'est figé au centre ;
      * la moitié s'allume quand un BOUT EST ATTEINT, c'est-à-dire quand le
        joueur porte Solstice (8610029, soleil) ou Équinoxe (8610030, lune).

    L'addon appelle EclipseBar_Update depuis son propre OnUpdate à chaque
    image : il suffit donc de remplacer cette fonction pour que tout suive.
    On remplace aussi OnShow et CheckBuffs, sans quoi les buffs natifs
    reprendraient la main sur les moitiés allumées.

    /solstice affiche ce que le client lit, pour trancher sans supposer.
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- côté serveur : on s'arrête ici
end

-- ---------------------------------------------------------------------------
-- Ce que le serveur nous dit
-- ---------------------------------------------------------------------------
local ID_JAUGE_LUNE, ID_JAUGE_SOLEIL = 8610032, 8610033   -- 1 à 3 piles
local ID_EQUINOXE, ID_SOLSTICE = 8610030, 8610029         -- bouts atteints
local ID_USE_SOLEIL, ID_USE_LUNE = 8610034, 8610035       -- astre épuisé
local BOUT = 3                                            -- crans par moitié
local COURSE = 38                                         -- pixels, comme l'addon

-- Relevés dans EclipseBarFrame.lua : on reprend ses propres découpes pour que
-- le halo et le curseur gardent exactement son apparence.
local MARQUEUR = {
    aucun  = { 0.914, 1.0, 0.82, 1.0 },
    soleil = { 1.0, 0.914, 0.641, 0.82 },   -- gauche/droite inversés : miroir
    lune   = { 0.914, 1.0, 0.641, 0.82 },
}
local HALO = {
    lune   = { x = 43, y = 45, l = 0.73437500, r = 0.90234375,
               h = 0.00781250, b = 0.35937500 },
    soleil = { x = 43, y = 45, l = 0.55859375, r = 0.72656250,
               h = 0.00781250, b = 0.35937500 },
}

-- OÙ ON LA POSE, ET DE QUELLE TAILLE. L'addon l'ancre sous le portrait du
-- joueur et la laisse à l'échelle de celui-ci ; on la ramène au centre de
-- l'écran, sous le personnage, et on la grossit. Trois chiffres à changer si
-- l'endroit ou la taille ne conviennent pas.
local ANCRE_X, ANCRE_Y = 0, -180
local ECHELLE = 1.6

local dernierEtat
local replacee = false


-- ---------------------------------------------------------------------------
-- Lecture des auras
-- ---------------------------------------------------------------------------
-- Rend le cran (-3 lune .. +3 soleil) et le bout atteint ("lune", "soleil"
-- ou nil). Tout se lit par IDENTIFIANT de sort : ni la langue ni un nom mal
-- orthographié ne peuvent s'y glisser.
local function lireJauge()
    local cran, bout, verrou = 0, nil, nil
    for i = 1, 40 do
        local nom, _, _, piles, _, _, _, _, _, _, id = UnitBuff("player", i)
        if not nom then
            break
        end
        if id == ID_JAUGE_LUNE or id == ID_JAUGE_SOLEIL then
            local crans = (piles and piles > 0) and piles or 1
            if crans > BOUT then crans = BOUT end
            cran = (id == ID_JAUGE_LUNE) and -crans or crans
        elseif id == ID_EQUINOXE then
            bout = "lune"
        elseif id == ID_SOLSTICE then
            bout = "soleil"
        elseif id == ID_USE_SOLEIL then
            verrou = "soleil"
        elseif id == ID_USE_LUNE then
            verrou = "lune"
        end
    end
    return cran, bout, verrou
end

-- ---------------------------------------------------------------------------
-- Le pilotage de la barre existante
-- ---------------------------------------------------------------------------
local function poseHalo(cadre, cote)
    local info = HALO[cote]
    cadre.glow:ClearAllPoints()
    cadre.glow:SetPoint("CENTER", (cote == "lune") and cadre.moon or cadre.sun,
                        "CENTER", 0, 0)
    cadre.glow:SetWidth(info.x)
    cadre.glow:SetHeight(info.y)
    cadre.glow:SetTexCoord(info.l, info.r, info.h, info.b)
    cadre.glow:Show()
    if cadre.glow.pulse and not cadre.glow.pulse:IsPlaying() then
        cadre.glow.pulse:Play()
    end
end

local function majEclipse(cadre)
    if not cadre or not cadre.marker then
        return                              -- OnLoad pas encore passé
    end
    local cran, bout, verrou = lireJauge()

    -- LE CURSEUR : notre cran, sur la course de l'addon.
    --
    -- SON ASPECT SUIT LE VERROU, PAS LE BIENFAIT. Il prend la flèche du côté
    -- atteint et la GARDE une fois les six secondes écoulées, jusqu'à ce que
    -- l'autre bout soit touché — c'est l'aura d'astre épuisé qui dure aussi
    -- longtemps, alors que le bienfait, lui, s'efface. Au moment de
    -- l'arrivée les deux désignent le même côté : la flèche ne cille pas.
    cadre.marker:ClearAllPoints()
    cadre.marker:SetPoint("CENTER", COURSE * cran / BOUT, 2)
    cadre.marker:SetTexCoord(unpack(MARQUEUR[bout or verrou or "aucun"]))

    -- TROIS ÉTATS, dans cet ordre de priorité :
    --   1. un bout vient d'être atteint : sa moitié s'allume et le halo
    --      palpite, six secondes durant ;
    --   2. sinon, si un astre est ÉPUISÉ, il s'éteint — c'est l'école
    --      opposée qu'il faut lancer, et la barre le montre ;
    --   3. sinon les deux astres sont normaux : le joueur choisit son école.
    -- On garde les animations de l'addon, mais on ne les relance qu'au
    -- CHANGEMENT — sans quoi l'OnUpdate les redéclencherait à chaque image.
    local etat = (bout and ("bout:" .. bout))
              or (verrou and ("verrou:" .. verrou))
              or "libre"
    if etat ~= dernierEtat then
        dernierEtat = etat
        if bout == "lune" then
            cadre.sunBar:Hide()
            cadre.darkMoon:Hide()
            cadre.darkSun:Hide()
            cadre.moonBar:Show()
            poseHalo(cadre, "lune")
            if cadre.moonDeactivate:IsPlaying() then cadre.moonDeactivate:Stop() end
            if not cadre.moonActivate:IsPlaying() then cadre.moonActivate:Play() end
        elseif bout == "soleil" then
            cadre.moonBar:Hide()
            cadre.darkSun:Hide()
            cadre.darkMoon:Hide()
            cadre.sunBar:Show()
            poseHalo(cadre, "soleil")
            if cadre.sunDeactivate:IsPlaying() then cadre.sunDeactivate:Stop() end
            if not cadre.sunActivate:IsPlaying() then cadre.sunActivate:Play() end
        else
            cadre.sunBar:Hide()
            cadre.moonBar:Hide()
            if cadre.glow.pulse and cadre.glow.pulse:IsPlaying() then
                cadre.glow.pulse:Stop()
            end
            cadre.glow:Hide()
            -- L'ASTRE ÉPUISÉ S'ÉTEINT, l'autre reste normal. Sans verrou,
            -- les deux restent normaux : le joueur a le choix.
            if verrou == "soleil" then
                cadre.darkMoon:Hide()
                cadre.darkSun:Show()
            elseif verrou == "lune" then
                cadre.darkSun:Hide()
                cadre.darkMoon:Show()
            else
                cadre.darkSun:Hide()
                cadre.darkMoon:Hide()
            end
        end
    end

    -- L'addon garde ces deux drapeaux pour ses propres bascules : on les tient
    -- à jour pour qu'il ne se croie jamais en désaccord avec l'écran.
    cadre.hasLunarEclipse = (bout == "lune")
    cadre.hasSolarEclipse = (bout == "soleil")
    cadre.eclipseDuration = 0
end

-- ---------------------------------------------------------------------------
-- On remplace les trois fonctions de l'addon
-- ---------------------------------------------------------------------------
-- Elles sont globales dans EclipseBarFrame.lua, et cet addon est chargé bien
-- avant qu'AIO ne nous expédie : les remplacer ici suffit. EclipseBar_Update
-- étant appelée par l'OnUpdate du cadre, le curseur suit tout seul.
-- ON LA REPLACE ET ON LA GROSSIT. Le cadre est parenté à PlayerFrame et
-- ancré sous lui ; on le rattache à UIParent — sans quoi il hériterait de
-- l'échelle du portrait — puis on le pose au centre, sous le personnage.
-- Show et Hide restent ceux de l'addon, le reparentage ne les gêne pas.
local function replacer()
    if replacee or not EclipseBarFrame then
        return
    end
    EclipseBarFrame:SetParent(UIParent)
    EclipseBarFrame:ClearAllPoints()
    EclipseBarFrame:SetPoint("CENTER", UIParent, "CENTER", ANCRE_X, ANCRE_Y)
    EclipseBarFrame:SetScale(ECHELLE)
    replacee = true
end

local function brancher()
    if not EclipseBarFrame or type(EclipseBar_Update) ~= "function" then
        return false                        -- l'addon n'est pas là
    end
    replacer()

    -- ON POSE LES SCRIPTS SUR LE CADRE, et pas seulement les globales. Le XML
    -- de l'addon lie ses gestionnaires PAR VALEUR au chargement
    -- (<OnUpdate function="EclipseBar_Update"/>) : réassigner la globale ne
    -- change rien à ce que le cadre appelle déjà. C'est ce qui laissait le
    -- curseur immobile.
    EclipseBarFrame:SetScript("OnUpdate", function(self) majEclipse(self) end)
    EclipseBarFrame:SetScript("OnShow", function(self)
        dernierEtat = nil                   -- on rejoue l'état à l'affichage
        majEclipse(self)
    end)

    -- Les globales servent quand même : EclipseBar_OnEvent, lui, les cherche
    -- à l'exécution pour montrer ou cacher la barre selon la forme. On garde
    -- donc son OnEvent et on remplace ce qu'il appelle.
    EclipseBar_Update = function(self) majEclipse(self) end
    EclipseBar_CheckBuffs = function(self)
        if self:IsShown() then majEclipse(self) end
    end
    EclipseBar_OnShow = function(self)
        dernierEtat = nil
        majEclipse(self)
    end
    return true
end

local branche = brancher()

-- Si l'addon n'était pas encore chargé, on réessaie à l'entrée en jeu.
local veille = CreateFrame("Frame")
veille:RegisterEvent("PLAYER_ENTERING_WORLD")
veille:SetScript("OnEvent", function()
    if not branche then
        branche = brancher()
    end
    replacer()
    if branche and EclipseBarFrame then
        dernierEtat = nil
        majEclipse(EclipseBarFrame)
    end
end)
