--[[----------------------------------------------------------------------------
    Attriboost — interface joueur, côté client

    Expédiée au client par AIO : rien à installer. Ouverture par le bouton de
    minimap, /attributs, /attriboost, ou un clic droit sur un Tome du Savoir
    ou un Livre des talents.

    La fenêtre ne décide de rien : elle affiche l'état que le serveur lui envoie
    (Etat) et lui adresse des demandes (Echanger, EchangerTalents, Attribuer,
    Reinitialiser). Les points posés sur les statistiques restent EN ATTENTE
    (barre claire) jusqu'à « Valider » ; « Annuler » les rend.

    Assets : uniquement ceux de l'interface 3.3.5 d'origine — bordure et plaque
    de titre des boîtes de dialogue, contour des barres de compétences, fonds
    d'infobulle, barres de statut, boutons de panneau, icônes. Animations :
    fondu d'ouverture, remplissage amorti des barres, sursaut du compteur,
    texte flottant des gains, halo des livres au survol.

    Client Lua 5.1 : 60 upvalues par fonction — constantes dans RC, textes
    dans L, état dans S, fonctions dans H.
------------------------------------------------------------------------------]]
local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return                                  -- côté serveur : on s'arrête ici
end

local Handlers = AIO.AddHandlers("Attriboost", {})

-- `.reload ale` réexécute ce fichier en entier, et le client 3.3.5 ne détruit
-- jamais un cadre : ceux du chargement précédent survivraient, l'ancienne
-- fenêtre restant affichée sous la nouvelle. On la neutralise ici — scripts
-- retirés d'abord pour que son OnHide ne parte pas, puis masquée — et on retire
-- son entrée d'UISpecialFrames, que la reconstruction remettra. Le bouton de
-- minimap et l'infobulle d'analyse, eux, sont REPRIS tels quels plus bas.
local vieux = _G["AttriboostFrame"]
if vieux then
    vieux:UnregisterAllEvents()
    vieux:SetScript("OnUpdate", nil)
    vieux:SetScript("OnEvent", nil)
    vieux:SetScript("OnHide", nil)
    vieux:SetScript("OnShow", nil)
    vieux:Hide()
    _G["AttriboostFrame"] = nil
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "AttriboostFrame" then
            table.remove(UISpecialFrames, i)
        end
    end
end

local FR = GetLocale() == "frFR"
local L = FR and {
    titre = "Attributs",
    disponibles = "disponible(s)",
    livre = "Livre de connaissance",
    livreTalents = "Livre des talents",
    enSac = "En sac : %d",
    parLivre = "%d points d'attribut par livre",
    parLivreTalents = "1 point de talent par livre",
    echanger = "Échanger",
    tout = "Tout",
    valider = "Valider",
    annuler = "Annuler",
    reinit = "Réinitialiser",
    parPoint = "%s par point",
    attente = "(+%d)",
    gainAttributs = "+%d point(s) d'attribut",
    gainTalents = "+%d point(s) de talent",
    reinitFait = "Attributs réinitialisés",
    confirmReinit = "Réinitialiser tous les attributs pour %s ?\nLes points reviendront dans la réserve.",
    aide = "Clic : 1 point — Maj : 5 — Ctrl : 10",
    inactif = "Le système d'attributs est désactivé.",
    mmAide = "Clic : ouvrir ou fermer la fenêtre",
    noms = {
        stamina = "Endurance", strength = "Force", agility = "Agilité",
        intellect = "Intelligence", spirit = "Esprit", spellpower = "Dégâts des sorts",
        critdamage = "Dégâts des coups critiques", resists = "Toutes les résistances",
        penetration = "Pénétration des sorts", healing = "Puissance des soins",
    },
} or {
    titre = "Attributes",
    disponibles = "available",
    livre = "Book of Knowledge",
    livreTalents = "Book of Talents",
    enSac = "In bags: %d",
    parLivre = "%d attribute points per book",
    parLivreTalents = "1 talent point per book",
    echanger = "Exchange",
    tout = "All",
    valider = "Confirm",
    annuler = "Cancel",
    reinit = "Reset",
    parPoint = "%s per point",
    attente = "(+%d)",
    gainAttributs = "+%d attribute point(s)",
    gainTalents = "+%d talent point(s)",
    reinitFait = "Attributes reset",
    confirmReinit = "Reset all attributes for %s?\nPoints return to the pool.",
    aide = "Click: 1 point — Shift: 5 — Ctrl: 10",
    inactif = "The attribute system is disabled.",
    mmAide = "Click: open or close the window",
    noms = {
        stamina = "Stamina", strength = "Strength", agility = "Agility",
        intellect = "Intellect", spirit = "Spirit", spellpower = "Spell damage",
        critdamage = "Critical strike damage", resists = "All resistances",
        penetration = "Spell penetration", healing = "Healing power",
    },
}

local RC = {
    LARGEUR = 640, BANDEAU_H = 44, CARTE_H = 108, LIGNE_H = 42,
    PIED_H = 54, ECART = 8, ICONE = 30, ICONE_LIVRE = 40, BARRE_H = 16,
    NOM_W = 176, BOUTON = 24, LIVRE = 890010, LIVRE_TALENTS = 890011,
    -- Retraits du contenu par rapport à la boîte de dialogue : liseré de 32 px
    -- d'épaisseur visible ~10 px, plaque de titre à cheval sur le bord haut.
    INSET_G = 20, INSET_H = 38, INSET_D = 20, INSET_B = 20,
    -- Boîte de dialogue standard 3.3.5 (bordure seule : ses fonds sont translucides,
    -- l'opacité vient d'un aplat posé dessous) et plaque de titre.
    BORDURE_DIALOGUE = "Interface\\DialogFrame\\UI-DialogBox-Border",
    PLAQUE = "Interface\\DialogFrame\\UI-DialogBox-Header",
    FOND_SOLIDE = { 0.08, 0.08, 0.10, 1 },
    -- Contour des barres de compétences de la feuille de personnage, rogné à sa zone utile.
    BARRE_BORDURE = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder",
    BARRE_BORDURE_COORDS = { 0.0078, 0.9961, 0.1875, 0.7812 },
    -- Bouton de minimap, composition standard 3.3.5 : fond noir, icône rognée
    -- en rond, cercle de suivi par-dessus. ANGLE = position sur le pourtour, en
    -- degrés (0 = droite, 90 = haut) ; celui du Mythique+ occupe 189°.
    MM_ANGLE = 120, MM_RAYON = 80, MM_TAILLE = 31,
    MM_FOND = "Interface\\Minimap\\UI-Minimap-Background",
    MM_BORDURE = "Interface\\Minimap\\MiniMap-TrackingBorder",
    MM_SURVOL = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
    MM_ICONE = "Interface\\Icons\\INV_Misc_Book_09",
    ICONE_LIVRE_DEF = "Interface\\Icons\\INV_Misc_Book_09",
    ICONE_TALENTS_DEF = "Interface\\Icons\\INV_Misc_Book_11",
    ICONES = {
        stamina = "Interface\\Icons\\Spell_Holy_WordFortitude",
        strength = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
        agility = "Interface\\Icons\\INV_Sword_51",
        intellect = "Interface\\Icons\\Spell_Holy_ArcaneIntellect",
        spirit = "Interface\\Icons\\Spell_Holy_Rapture",
        spellpower = "Interface\\Icons\\INV_Enchant_EssenceMysticalSmall",
        critdamage = "Interface\\Icons\\Ability_Rogue_BloodSplatter",
        resists = "Interface\\Icons\\INV_Elemental_Primal_Shadow",
        penetration = "Interface\\Icons\\Ability_Mage_MissileBarrage",
        healing = "Interface\\Icons\\INV_Enchant_EssenceAstralSmall",
    },
    -- Repli si l'infobulle du sort ne se lit pas (valeurs du Spell.dbc au 2026-09-04).
    PAR_POINT = {
        stamina = "+5", strength = "+5", agility = "+5", intellect = "+5", spirit = "+5",
        spellpower = "+5", critdamage = "+1%", resists = "+1", penetration = "+1", healing = "+10",
    },
    FOND = "Interface\\Tooltips\\UI-Tooltip-Background",
    BORDURE = "Interface\\Tooltips\\UI-Tooltip-Border",
    BARRE = "Interface\\TargetingFrame\\UI-StatusBar",
    SURBRILLANCE = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
    HALO = "Interface\\Buttons\\ButtonHilight-Square",
    CADRE_ICONE = "Interface\\Buttons\\UI-Quickslot2",
    BLANC = "Interface\\Buttons\\WHITE8X8",
    OR = { 1, 0.82, 0 },
    GRIS = { 0.55, 0.55, 0.55 },
    FOND_CARTE = { 0.06, 0.06, 0.08, 1 },
    BORD_CARTE = { 0.40, 0.40, 0.44, 1 },
    FOND_BARRE = { 0.13, 0.13, 0.16, 1 },
    BARRE_ACQUIS = { 0.85, 0.66, 0.12 },
    BARRE_ATTENTE = { 0.95, 0.95, 0.85 },
    AMORTI = 9,            -- vitesse de remplissage des barres (par seconde)
    FONDU = 0.18,          -- durée du fondu d'ouverture
    FLOTTANT = 1.1,        -- durée du texte flottant
    PIECES = { "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t",
               "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t",
               "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t" },
}

local S = {
    ui = nil, etat = nil, attente = {}, lignes = {}, cartes = {},
    spin = { livres = 1, talents = 1 }, anim = false, parPoint = {},
    dernierDispo = nil, flottants = {}, mm = nil,
}
local H = {}

-- ---------------------------------------------------------------------------
-- Aides
-- ---------------------------------------------------------------------------
function H.Argent(cuivre)
    cuivre = math.floor(cuivre or 0)
    local po, pa, pc = math.floor(cuivre / 10000), math.floor(cuivre / 100) % 100, cuivre % 100
    local t = {}
    if po > 0 then table.insert(t, po .. RC.PIECES[1]) end
    if pa > 0 then table.insert(t, pa .. RC.PIECES[2]) end
    if pc > 0 or #t == 0 then table.insert(t, pc .. RC.PIECES[3]) end
    return table.concat(t, " ")
end

function H.Pas()
    if IsControlKeyDown() then return 10 end
    if IsShiftKeyDown() then return 5 end
    return 1
end

function H.IconeSort(cle, spell)
    local _, _, icone = GetSpellInfo(spell)
    return icone or RC.ICONES[cle]
end

-- Le bonus par point se lit dans l'infobulle du sort : c'est le client qui
-- porte le Spell.dbc, la valeur affichée est donc toujours la vraie.
function H.ParPoint(cle, spell)
    if S.parPoint[cle] then return S.parPoint[cle] end
    local tip = S.scan or _G["AttriboostScanTip"]
    if not tip then
        tip = CreateFrame("GameTooltip", "AttriboostScanTip", nil, "GameTooltipTemplate")
    end
    S.scan = tip
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:SetHyperlink("spell:" .. spell)
    local trouve
    for i = 2, tip:NumLines() do
        local ligne = _G["AttriboostScanTipTextLeft" .. i]
        local texte = ligne and ligne:GetText()
        if texte then
            local n, pct = texte:match("(%d+)%s*(%%?)")
            if n then trouve = "+" .. n .. pct; break end
        end
    end
    tip:Hide()
    S.parPoint[cle] = trouve or RC.PAR_POINT[cle] or "?"
    return S.parPoint[cle]
end

function H.Disponibles()
    if not S.etat then return 0 end
    local total = 0
    for _, n in pairs(S.attente) do total = total + n end
    return S.etat.disponibles - total, total
end

function H.Bouton(parent, texte, w, h)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(w); b:SetHeight(h or 22)
    b:SetText(texte)
    return b
end

function H.Actif(bouton, actif)
    if actif then bouton:Enable() else bouton:Disable() end
end

function H.Fond(cadre, couleur, bordure)
    cadre:SetBackdrop({
        bgFile = RC.BLANC, edgeFile = bordure and RC.BORDURE or nil,
        tile = true, tileSize = 8, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    cadre:SetBackdropColor(unpack(couleur))
    if bordure then cadre:SetBackdropBorderColor(unpack(RC.BORD_CARTE)) end
end

-- Boîte de dialogue 3.3.5 : aplat opaque, bordure standard, plaque de titre à
-- cheval sur le bord haut (disposition du panneau d'options), bouton de
-- fermeture classique. Rien que des textures de l'interface d'origine.
function H.CadreDialogue(f, titre)
    f:SetBackdrop({
        edgeFile = RC.BORDURE_DIALOGUE, tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 },
    })
    f:SetBackdropBorderColor(1, 1, 1, 1)

    local fond = f:CreateTexture(nil, "BACKGROUND")
    fond:SetTexture(RC.BLANC)
    fond:SetVertexColor(unpack(RC.FOND_SOLIDE))
    fond:SetPoint("TOPLEFT", 9, -9)
    fond:SetPoint("BOTTOMRIGHT", -9, 9)

    local plaque = f:CreateTexture(nil, "ARTWORK")
    plaque:SetTexture(RC.PLAQUE)
    plaque:SetWidth(256); plaque:SetHeight(64)
    plaque:SetPoint("TOP", 0, 12)

    local texte = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    texte:SetPoint("CENTER", f, "TOP", 0, -8)
    texte:SetText(titre)
    texte:SetTextColor(unpack(RC.OR))

    local fermer = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    fermer:SetPoint("TOPRIGHT", -6, -6)
    fermer:SetScript("OnClick", function() f:Hide() end)
    return f
end

-- ---------------------------------------------------------------------------
-- Animations
-- ---------------------------------------------------------------------------
-- Sursaut du compteur de points : deux échelles enchaînées.
function H.Sursaut()
    local nombre = S.ui.nombre
    if not nombre.sursaut then
        local g = nombre:CreateAnimationGroup()
        local a = g:CreateAnimation("Scale")
        a:SetScale(1.35, 1.35); a:SetDuration(0.10); a:SetOrder(1); a:SetOrigin("CENTER", 0, 0)
        local b = g:CreateAnimation("Scale")
        b:SetScale(1 / 1.35, 1 / 1.35); b:SetDuration(0.14); b:SetOrder(2); b:SetOrigin("CENTER", 0, 0)
        nombre.sursaut = g
    end
    if nombre.sursaut:IsPlaying() then nombre.sursaut:Stop() end
    nombre.sursaut:Play()
end

-- Texte qui monte et s'efface depuis le compteur (gains, réinitialisation).
function H.Flottant(texte, r, g, b)
    local f
    for _, cand in ipairs(S.flottants) do
        if not cand.anim:IsPlaying() then f = cand; break end
    end
    if not f then
        f = CreateFrame("Frame", nil, S.ui)
        f:SetWidth(300); f:SetHeight(24)
        f:SetFrameLevel(S.ui:GetFrameLevel() + 20)
        f.texte = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        f.texte:SetPoint("CENTER")
        local anim = f:CreateAnimationGroup()
        local monte = anim:CreateAnimation("Translation")
        monte:SetOffset(0, 46); monte:SetDuration(RC.FLOTTANT)
        if monte.SetSmoothing then monte:SetSmoothing("OUT") end
        local fondu = anim:CreateAnimation("Alpha")
        fondu:SetChange(-1); fondu:SetDuration(RC.FLOTTANT * 0.55); fondu:SetStartDelay(RC.FLOTTANT * 0.45)
        anim:SetScript("OnFinished", function() f:Hide() end)
        f.anim = anim
        table.insert(S.flottants, f)
    end
    f:ClearAllPoints()
    f:SetPoint("CENTER", S.ui.nombre, "CENTER", -60, 6)
    f.texte:SetText(texte)
    f.texte:SetTextColor(r or 1, g or 0.82, b or 0)
    f:SetAlpha(1)
    f:Show()
    f.anim:Play()
end

-- Fondu d'ouverture. PAS d'animation d'alpha ici : en 3.3.5 elle rend au
-- cadre son alpha de départ (zéro) à la fin, APRÈS OnFinished, et la fenêtre
-- s'effaçait. UIFrameFadeIn règle l'alpha directement et le laisse à 1.
function H.Ouverture()
    UIFrameFadeIn(S.ui, RC.FONDU, 0, 1)
end

-- Remplissage amorti des barres, une seule boucle pour toutes.
function H.Amortir(elapsed)
    local reste = false
    local k = math.min(1, elapsed * RC.AMORTI)
    for _, l in ipairs(S.lignes) do
        local d = l.cible - l.actuel
        if math.abs(d) > 0.02 then
            l.actuel = l.actuel + d * k
            reste = true
        else
            l.actuel = l.cible
        end
        l.barre:SetValue(l.actuel)
        l.barreAttente:SetValue(l.actuel + (S.attente[l.cle] or 0))
    end
    S.anim = reste
end

-- ---------------------------------------------------------------------------
-- Rendu
-- ---------------------------------------------------------------------------
function H.RendreCarte(c)
    local possede = GetItemCount(c.objet) or 0
    local maxi = math.max(1, possede)
    if S.spin[c.nom] > maxi then S.spin[c.nom] = maxi end
    if S.spin[c.nom] < 1 then S.spin[c.nom] = 1 end
    local ok = possede > 0 and S.etat and S.etat.actif
    c.compte:SetText(string.format(L.enSac, possede))
    c.valeur:SetText(tostring(S.spin[c.nom]))
    c:SetAlpha(ok and 1 or 0.45)
    H.Actif(c.moins, ok and S.spin[c.nom] > 1)
    H.Actif(c.plus, ok and S.spin[c.nom] < possede)
    H.Actif(c.tout, ok and S.spin[c.nom] < possede)
    H.Actif(c.echanger, ok)
end

function H.RendreLigne(l)
    local st = S.etat and S.etat.stats[l.index]
    if not st then return end
    local attente = S.attente[l.cle] or 0
    local dispo = H.Disponibles()
    l.barre:SetMinMaxValues(0, st.max)
    l.barreAttente:SetMinMaxValues(0, st.max)
    l.cible = st.valeur
    if attente > 0 then
        l.valeur:SetText(string.format("%d |cffffffcc%s|r / %d", st.valeur, string.format(L.attente, attente), st.max))
    else
        l.valeur:SetText(string.format("%d / %d", st.valeur, st.max))
    end
    l.parPoint:SetText(string.format(L.parPoint, H.ParPoint(l.cle, st.spell)))
    local plein = st.valeur + attente >= st.max
    H.Actif(l.plus, S.etat.actif and not plein and dispo > 0)
    H.Actif(l.moins, attente > 0)
    l.nom:SetTextColor(plein and 0.6 or 1, plein and 0.6 or 0.82, plein and 0.6 or 0)
    S.anim = true
end

function H.Rendre()
    local ui = S.ui
    if not ui or not S.etat then return end
    local dispo, enAttente = H.Disponibles()
    ui.nombre:SetText(tostring(dispo))
    ui.nombreLibelle:SetText(L.disponibles)
    if S.dernierDispo ~= nil and S.dernierDispo ~= dispo then H.Sursaut() end
    S.dernierDispo = dispo
    ui.avertissement:SetText(S.etat.actif and "" or L.inactif)

    for _, c in pairs(S.cartes) do H.RendreCarte(c) end
    for _, l in ipairs(S.lignes) do H.RendreLigne(l) end

    H.Actif(ui.valider, enAttente > 0)
    H.Actif(ui.annuler, enAttente > 0)
    local total = 0
    for _, st in ipairs(S.etat.stats) do total = total + st.valeur end
    ui.reinit:SetText(L.reinit .. "  " .. H.Argent(S.etat.coutReset))
    H.Actif(ui.reinit, S.etat.actif and total > 0 and GetMoney() >= S.etat.coutReset)
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------
function H.Poser(cle, delta)
    local st
    for _, s in ipairs(S.etat.stats) do if s.cle == cle then st = s end end
    if not st then return end
    local attente = S.attente[cle] or 0
    if delta > 0 then
        local dispo = H.Disponibles()
        delta = math.min(delta, dispo, st.max - st.valeur - attente)
        if delta <= 0 then return end
    else
        delta = -math.min(-delta, attente)
        if delta == 0 then return end
    end
    S.attente[cle] = attente + delta
    if S.attente[cle] <= 0 then S.attente[cle] = nil end
    H.Rendre()
end

function H.Valider()
    local demande, total = {}, 0
    for cle, n in pairs(S.attente) do demande[cle] = n; total = total + n end
    if total == 0 then return end
    AIO.Handle("Attriboost", "Attribuer", demande)
end

function H.Annuler()
    S.attente = {}
    H.Rendre()
end

function H.Reinitialiser()
    StaticPopup_Show("ATTRIBOOST_REINIT", H.Argent(S.etat.coutReset))
end

function H.Ouvrir()
    if not S.ui then H.Construire() end
    if S.ui:IsShown() then return end
    S.attente = {}
    S.ui:Show()
    H.Ouverture()
    AIO.Handle("Attriboost", "Ouvrir")
end

function H.Basculer()
    if S.ui and S.ui:IsShown() then S.ui:Hide() else H.Ouvrir() end
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
function H.Carte(parent, nom, objet, iconeDefaut, libelle, sousLibelle, handler)
    local c = CreateFrame("Frame", nil, parent)
    c:SetHeight(RC.CARTE_H)
    H.Fond(c, RC.FOND_CARTE, true)
    c.nom, c.objet = nom, objet

    local cadreIcone = CreateFrame("Button", nil, c)
    cadreIcone:SetWidth(RC.ICONE_LIVRE); cadreIcone:SetHeight(RC.ICONE_LIVRE)
    cadreIcone:SetPoint("TOPLEFT", 14, -14)
    local icone = cadreIcone:CreateTexture(nil, "ARTWORK")
    icone:SetAllPoints()
    icone:SetTexture((GetItemIcon and GetItemIcon(objet)) or select(10, GetItemInfo(objet)) or iconeDefaut)
    icone:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    local bord = cadreIcone:CreateTexture(nil, "OVERLAY")
    bord:SetTexture(RC.CADRE_ICONE)
    bord:SetPoint("TOPLEFT", -12, 12); bord:SetPoint("BOTTOMRIGHT", 12, -12)
    local halo = cadreIcone:CreateTexture(nil, "HIGHLIGHT")
    halo:SetTexture(RC.HALO); halo:SetBlendMode("ADD"); halo:SetAllPoints()
    cadreIcone:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. objet)
        GameTooltip:Show()
    end)
    cadreIcone:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local titre = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titre:SetPoint("TOPLEFT", cadreIcone, "TOPRIGHT", 12, 0)
    titre:SetText(libelle)
    titre:SetTextColor(unpack(RC.OR))
    c.compte = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.compte:SetPoint("TOPLEFT", titre, "BOTTOMLEFT", 0, -3)
    local sous = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    sous:SetPoint("TOPLEFT", c.compte, "BOTTOMLEFT", 0, -2)
    sous:SetText(sousLibelle)

    -- Compteur : [-] n [+] Tout ...................... Échanger
    c.moins = H.Bouton(c, "-", RC.BOUTON, RC.BOUTON)
    c.moins:SetPoint("BOTTOMLEFT", 14, 12)
    c.valeur = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    c.valeur:SetPoint("LEFT", c.moins, "RIGHT", 4, 0)
    c.valeur:SetWidth(34); c.valeur:SetJustifyH("CENTER")
    c.plus = H.Bouton(c, "+", RC.BOUTON, RC.BOUTON)
    c.plus:SetPoint("LEFT", c.valeur, "RIGHT", 4, 0)
    c.tout = H.Bouton(c, L.tout, 48, RC.BOUTON)
    c.tout:SetPoint("LEFT", c.plus, "RIGHT", 6, 0)
    c.echanger = H.Bouton(c, L.echanger, 96, 24)
    c.echanger:SetPoint("BOTTOMRIGHT", -12, 12)

    c.moins:SetScript("OnClick", function() S.spin[nom] = S.spin[nom] - H.Pas(); H.RendreCarte(c) end)
    c.plus:SetScript("OnClick", function() S.spin[nom] = S.spin[nom] + H.Pas(); H.RendreCarte(c) end)
    c.tout:SetScript("OnClick", function() S.spin[nom] = GetItemCount(objet) or 1; H.RendreCarte(c) end)
    c.echanger:SetScript("OnClick", function()
        local n = S.spin[nom]
        if n >= 1 and (GetItemCount(objet) or 0) >= n then
            AIO.Handle("Attriboost", handler, n)
        end
    end)
    return c
end

function H.Ligne(parent, index, cle)
    local l = CreateFrame("Button", nil, parent)
    l:SetHeight(RC.LIGNE_H)
    l.index, l.cle, l.actuel, l.cible = index, cle, 0, 0

    local surbrillance = l:CreateTexture(nil, "HIGHLIGHT")
    surbrillance:SetTexture(RC.SURBRILLANCE); surbrillance:SetBlendMode("ADD")
    surbrillance:SetAllPoints(); surbrillance:SetAlpha(0.5)

    l.icone = l:CreateTexture(nil, "ARTWORK")
    l.icone:SetWidth(RC.ICONE); l.icone:SetHeight(RC.ICONE)
    l.icone:SetPoint("LEFT", 8, 0)
    l.icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    l.nom = l:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    l.nom:SetPoint("TOPLEFT", l.icone, "TOPRIGHT", 10, 0)
    l.nom:SetWidth(RC.NOM_W); l.nom:SetJustifyH("LEFT")
    l.nom:SetText(L.noms[cle] or cle)
    l.parPoint = l:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    l.parPoint:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -1)
    l.parPoint:SetWidth(RC.NOM_W); l.parPoint:SetJustifyH("LEFT")

    -- Boutons à droite, barre entre le nom et les boutons.
    l.plus = H.Bouton(l, "+", RC.BOUTON, RC.BOUTON)
    l.plus:SetPoint("RIGHT", -8, 0)
    l.moins = H.Bouton(l, "-", RC.BOUTON, RC.BOUTON)
    l.moins:SetPoint("RIGHT", l.plus, "LEFT", -4, 0)

    local fondBarre = CreateFrame("Frame", nil, l)
    fondBarre:SetHeight(RC.BARRE_H)
    fondBarre:SetPoint("LEFT", l.nom, "RIGHT", 12, -6)
    fondBarre:SetPoint("RIGHT", l.moins, "LEFT", -14, 0)
    local fond = fondBarre:CreateTexture(nil, "BACKGROUND")
    fond:SetTexture(RC.BLANC); fond:SetAllPoints()
    fond:SetVertexColor(unpack(RC.FOND_BARRE))

    l.barreAttente = CreateFrame("StatusBar", nil, fondBarre)
    l.barreAttente:SetAllPoints()
    l.barreAttente:SetStatusBarTexture(RC.BARRE)
    l.barreAttente:SetStatusBarColor(RC.BARRE_ATTENTE[1], RC.BARRE_ATTENTE[2], RC.BARRE_ATTENTE[3], 0.55)
    l.barre = CreateFrame("StatusBar", nil, fondBarre)
    l.barre:SetAllPoints()
    l.barre:SetFrameLevel(l.barreAttente:GetFrameLevel() + 1)
    l.barre:SetStatusBarTexture(RC.BARRE)
    l.barre:SetStatusBarColor(unpack(RC.BARRE_ACQUIS))
    l.valeur = l.barre:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.valeur:SetPoint("CENTER", fondBarre, "CENTER", 0, 0)
    local contour = CreateFrame("Frame", nil, fondBarre)
    contour:SetFrameLevel(l.barre:GetFrameLevel() + 1)
    contour:SetPoint("TOPLEFT", -3, 3)
    contour:SetPoint("BOTTOMRIGHT", 3, -3)
    local liseret = contour:CreateTexture(nil, "OVERLAY")
    liseret:SetTexture(RC.BARRE_BORDURE)
    liseret:SetAllPoints()
    liseret:SetTexCoord(unpack(RC.BARRE_BORDURE_COORDS))

    l.plus:SetScript("OnClick", function() H.Poser(cle, H.Pas()) end)
    l.moins:SetScript("OnClick", function() H.Poser(cle, -H.Pas()) end)
    l:SetScript("OnEnter", function(self)
        local st = S.etat and S.etat.stats[index]
        if not st then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. st.spell)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.aide, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return l
end

function H.Construire()
    local hauteur = RC.INSET_H + RC.BANDEAU_H + RC.ECART + RC.CARTE_H + RC.ECART
                    + 10 * RC.LIGNE_H + RC.ECART + RC.PIED_H + RC.INSET_B
    local f = CreateFrame("Frame", "AttriboostFrame", UIParent)
    f:SetWidth(RC.LARGEUR); f:SetHeight(hauteur)
    f:SetPoint("CENTER")
    f:SetMovable(true); f:EnableMouse(true); f:SetToplevel(true)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    -- La fenêtre entière sert de poignée : les boutons, au-dessus, gardent la main.
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f:Hide()
    table.insert(UISpecialFrames, "AttriboostFrame")
    S.ui = f
    H.CadreDialogue(f, L.titre)

    -- Bandeau sous la barre de titre : avertissement à gauche, compteur à droite.
    local bandeau = CreateFrame("Frame", nil, f)
    bandeau:SetPoint("TOPLEFT", RC.INSET_G, -RC.INSET_H)
    bandeau:SetPoint("TOPRIGHT", -RC.INSET_D, -RC.INSET_H)
    bandeau:SetHeight(RC.BANDEAU_H)
    f.avertissement = bandeau:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.avertissement:SetPoint("LEFT", 8, 0)
    f.avertissement:SetTextColor(1, 0.3, 0.3)

    f.nombre = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    f.nombre:SetPoint("RIGHT", -96, 0)
    f.nombre:SetText("0")
    f.nombre:SetTextColor(unpack(RC.OR))
    f.nombreLibelle = bandeau:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.nombreLibelle:SetPoint("LEFT", f.nombre, "RIGHT", 6, -2)
    f.nombreLibelle:SetText(L.disponibles)

    local filet = f:CreateTexture(nil, "ARTWORK")
    filet:SetTexture(RC.BLANC); filet:SetHeight(1)
    filet:SetPoint("TOPLEFT", bandeau, "BOTTOMLEFT", 0, 0)
    filet:SetPoint("TOPRIGHT", bandeau, "BOTTOMRIGHT", 0, 0)
    filet:SetVertexColor(0.5, 0.5, 0.55, 0.5)

    -- Deux cartes d'échange côte à côte.
    local largeurCarte = (RC.LARGEUR - RC.INSET_G - RC.INSET_D - RC.ECART) / 2
    local carteLivres = H.Carte(f, "livres", RC.LIVRE, RC.ICONE_LIVRE_DEF, L.livre,
        string.format(L.parLivre, 3), "Echanger")
    carteLivres:SetWidth(largeurCarte)
    carteLivres:SetPoint("TOPLEFT", bandeau, "BOTTOMLEFT", 0, -RC.ECART)
    local carteTalents = H.Carte(f, "talents", RC.LIVRE_TALENTS, RC.ICONE_TALENTS_DEF, L.livreTalents,
        L.parLivreTalents, "EchangerTalents")
    carteTalents:SetWidth(largeurCarte)
    carteTalents:SetPoint("TOPRIGHT", bandeau, "BOTTOMRIGHT", 0, -RC.ECART)
    S.cartes = { livres = carteLivres, talents = carteTalents }

    -- Les dix lignes.
    local ordre = { "stamina", "strength", "agility", "intellect", "spirit",
                    "spellpower", "critdamage", "resists", "penetration", "healing" }
    local precedent = carteLivres
    for i, cle in ipairs(ordre) do
        local l = H.Ligne(f, i, cle)
        l:SetPoint("TOPLEFT", f, "TOPLEFT", RC.INSET_G, -(RC.INSET_H + RC.BANDEAU_H + RC.ECART + RC.CARTE_H + RC.ECART + (i - 1) * RC.LIGNE_H))
        l:SetPoint("RIGHT", f, "RIGHT", -RC.INSET_D, 0)
        if i % 2 == 0 then
            local bande = l:CreateTexture(nil, "BACKGROUND")
            bande:SetTexture(RC.BLANC); bande:SetAllPoints()
            bande:SetVertexColor(0, 0, 0, 0.22)
        end
        S.lignes[i] = l
        precedent = l
    end

    -- Pied : réinitialisation à gauche, annuler / valider à droite.
    local pied = CreateFrame("Frame", nil, f)
    pied:SetPoint("BOTTOMLEFT", RC.INSET_G, RC.INSET_B)
    pied:SetPoint("BOTTOMRIGHT", -RC.INSET_D, RC.INSET_B)
    pied:SetHeight(RC.PIED_H)
    local filet2 = pied:CreateTexture(nil, "ARTWORK")
    filet2:SetTexture(RC.BLANC); filet2:SetHeight(1)
    filet2:SetPoint("TOPLEFT"); filet2:SetPoint("TOPRIGHT")
    filet2:SetVertexColor(0.5, 0.5, 0.55, 0.5)
    f.reinit = H.Bouton(pied, L.reinit, 190, 24)
    f.reinit:SetPoint("LEFT", 4, 0)
    f.reinit:SetScript("OnClick", H.Reinitialiser)
    f.valider = H.Bouton(pied, L.valider, 110, 24)
    f.valider:SetPoint("RIGHT", -4, 0)
    f.valider:SetScript("OnClick", H.Valider)
    f.annuler = H.Bouton(pied, L.annuler, 90, 24)
    f.annuler:SetPoint("RIGHT", f.valider, "LEFT", -6, 0)
    f.annuler:SetScript("OnClick", H.Annuler)

    -- Icônes des lignes (le Spell.dbc client fait foi).
    f:SetScript("OnShow", function()
        for _, l in ipairs(S.lignes) do
            local st = S.etat and S.etat.stats[l.index]
            l.icone:SetTexture(H.IconeSort(l.cle, st and st.spell or 0))
        end
    end)
    f:SetScript("OnHide", function()
        S.attente = {}
        GameTooltip:Hide()
    end)
    f:SetScript("OnUpdate", function(_, elapsed)
        if S.anim then H.Amortir(elapsed) end
    end)
    f:RegisterEvent("BAG_UPDATE")
    f:RegisterEvent("PLAYER_MONEY")
    f:SetScript("OnEvent", function()
        if f:IsShown() then H.Rendre() end
    end)
end

-- ---------------------------------------------------------------------------
-- Ce que le serveur nous dit
-- ---------------------------------------------------------------------------
function Handlers.Etat(player, etat, extra)
    if type(etat) ~= "table" then return end
    if not S.ui then H.Construire() end
    S.etat = etat
    S.attente = {}
    for _, l in ipairs(S.lignes) do
        local st = etat.stats[l.index]
        if st then l.icone:SetTexture(H.IconeSort(l.cle, st.spell)) end
    end
    H.Rendre()
    if type(extra) == "table" then
        if extra.echange then H.Flottant(string.format(L.gainAttributs, extra.echange)) end
        if extra.talents then H.Flottant(string.format(L.gainTalents, extra.talents), 0.4, 0.8, 1) end
        if extra.reinitialise then
            H.Flottant(L.reinitFait, 0.8, 0.8, 0.8)
            for _, l in ipairs(S.lignes) do l.cible = 0 end
            S.anim = true
        end
    end
end

-- ---------------------------------------------------------------------------
-- Ouverture : commandes, clic droit sur les livres, confirmation
-- ---------------------------------------------------------------------------
SLASH_ATTRIBOOST1 = "/attributs"
SLASH_ATTRIBOOST2 = "/attriboost"
SlashCmdList["ATTRIBOOST"] = function() H.Basculer() end

hooksecurefunc("UseContainerItem", function(bag, slot)
    local lien = GetContainerItemLink(bag, slot)
    local id = lien and tonumber(lien:match("item:(%d+)"))
    if id == RC.LIVRE or id == RC.LIVRE_TALENTS then
        H.Ouvrir()
    end
end)

-- ---------------------------------------------------------------------------
-- Bouton de minimap
-- ---------------------------------------------------------------------------
-- Composition des boutons de minimap 3.3.5 : le cercle de suivi (MiniMap-
-- TrackingBorder) posé en surimpression sur une icône rognée, sur fond noir de
-- minimap. Les textures de bouton des hauts faits, qu'emploie le bouton
-- Mythique+, sont absentes des archives de ce client : il s'affiche sans fond.
-- Position FIXE (RC.MM_ANGLE) : le code étant expédié par AIO et non installé
-- comme un vrai module d'interface, il n'a pas de variables sauvegardées où
-- retenir un déplacement.
function H.CreerBoutonMinimap()
    if not Minimap then
        return
    end
    -- `.reload ale` réexécute tout le fichier : sans cette reprise du bouton
    -- déjà posé, chaque rechargement en empilerait un de plus. On le réutilise
    -- et on lui rebranche les scripts, qui sinon appelleraient les fonctions du
    -- chargement précédent.
    local existant = _G["AttriboostMiniButton"]
    if existant then
        S.mm = existant
        H.BrancherBoutonMinimap(existant)
        return
    end
    local b = CreateFrame("Button", "AttriboostMiniButton", Minimap)
    b:SetWidth(RC.MM_TAILLE); b:SetHeight(RC.MM_TAILLE)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(Minimap:GetFrameLevel() + 8)

    local fond = b:CreateTexture(nil, "BACKGROUND")
    fond:SetTexture(RC.MM_FOND)
    fond:SetWidth(20); fond:SetHeight(20)
    fond:SetPoint("CENTER", 0, 0)

    local icone = b:CreateTexture(nil, "ARTWORK")
    icone:SetTexture(RC.MM_ICONE)
    icone:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    icone:SetWidth(18); icone:SetHeight(18)
    icone:SetPoint("CENTER", 0, 0)

    local bordure = b:CreateTexture(nil, "OVERLAY")
    bordure:SetTexture(RC.MM_BORDURE)
    bordure:SetWidth(53); bordure:SetHeight(53)
    bordure:SetPoint("CENTER", 11, -12)

    b:SetHighlightTexture(RC.MM_SURVOL)

    local a = math.rad(RC.MM_ANGLE)
    b:SetPoint("CENTER", Minimap, "CENTER", RC.MM_RAYON * math.cos(a), RC.MM_RAYON * math.sin(a))

    H.BrancherBoutonMinimap(b)
    S.mm = b
end

function H.BrancherBoutonMinimap(b)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.titre)
        GameTooltip:AddLine(L.mmAide, 1, 1, 1)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function()
        if S.ui and S.ui:IsShown() then
            PlaySound("igCharacterInfoClose")
        else
            PlaySound("igCharacterInfoOpen")
        end
        H.Basculer()
    end)
end

H.CreerBoutonMinimap()

StaticPopupDialogs["ATTRIBOOST_REINIT"] = {
    text = L.confirmReinit,
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function() AIO.Handle("Attriboost", "Reinitialiser") end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}
