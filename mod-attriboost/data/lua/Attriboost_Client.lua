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

    AVEC ForeverUI (mod-forever-ui) SUR LE CLIENT : ni fenêtre grise ni
    bouton de minimap. Le module déclare un onglet de la fenêtre
    Progression, qu'ouvre le micro-bouton du même nom ; sa page reprend
    la feuille de personnage et l'onglet Compétences de ForeverUI (voir
    « Page de la fenêtre Progression », plus bas). Le code de cette
    fenêtre est copié plus bas, identique à celui de ItemUpgrade_Client.lua :
    le premier module chargé la crée, le suivant y ajoute son onglet.
    Sans ForeverUI, rien ne change. Commandes
    et livres ouvrent l'une ou l'autre.

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

-- Textes : AUCUN ici. Leur seule source est la base (tables `module_string`
-- et `module_string_locale` du cœur, module 'mod-attriboost'), partagée avec
-- le module C++ ; le serveur les envoie avec ce code, dans la langue du client
-- du joueur (handler Textes, plus bas). ID donne le numéro de chaque texte de
-- l'interface ; `{}` y marque une valeur, remplie par Remplir.
local ID = {
    inactif = 1, reinitFait = 14,
    titre = 101, disponibles = 102, livre = 103, livreTalents = 104, enSac = 105,
    parLivre = 106, parLivreTalents = 107, echanger = 108, tout = 109,
    valider = 110, annuler = 111, reinit = 112, parPoint = 113, attente = 114,
    gainAttributs = 115, gainTalents = 116, confirmReinit = 117, aide = 118,
    mmAide = 119, progression = 120,
}
local ID_NOMS = {
    stamina = 131, strength = 132, agility = 133, intellect = 134, spirit = 135,
    spellpower = 136, critdamage = 137, resists = 138, penetration = 139,
    healing = 140,
}
local TEXTES = {}

local function Remplir(texte, ...)
    local valeurs, n = { ... }, 0
    return (texte:gsub("{}", function()
        n = n + 1
        return tostring(valeurs[n])
    end))
end

-- L.cle rend le texte de la cle ; L.noms[stat] le nom d'une statistique.
local L = setmetatable({
    noms = setmetatable({}, { __index = function(_, cle) return TEXTES[ID_NOMS[cle]] end }),
}, { __index = function(_, cle) return TEXTES[ID[cle]] or cle end })

local RC = {
    LARGEUR = 640, BANDEAU_H = 44, CARTE_H = 108, LIGNE_H = 42,
    PIED_H = 54, ECART = 8, ICONE = 30, ICONE_LIVRE = 40, BARRE_H = 16,
    NOM_W = 176, BOUTON = 24, LIVRE = 82010, LIVRE_TALENTS = 82011,
    -- L'aura « Attributs », la seule que le joueur voit : son infobulle liste
    -- les bonus (les dix auras des statistiques sont invisibles).
    RESUME = 82012,
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
    -- L'onglet de la fenêtre Progression : sa clé, sa place (en
    -- haut, avant celui d'Item Upgrade), son icône (une image du module,
    -- cuite au masque des onglets, que son installeur écrit dans l'archive du
    -- jeu).
    CLE = "attriboost", ORDRE = 1,
    ONGLET_ICONE = "Interface\\Attriboost\\inv_misc_book_09",
    -- le portrait de la fenêtre Progression, si ce module la crée
    PORTRAIT = "Interface\\Attriboost\\legacy-up-c60-masque",
}

local S = {
    ui = nil, etat = nil, attente = {}, lignes = {}, cartes = {},
    spin = { livres = 1, talents = 1 }, anim = false, parPoint = {},
    descriptions = {},          -- la ligne de l'infobulle de chaque sort qui porte sa valeur
    resume = nil,               -- le dernier état reçu, pour l'infobulle de l'aura « Attributs »
    dernierDispo = nil, flottants = {}, mm = nil,
    fui = nil,                  -- la page de la fenêtre Progression
    choisie = nil,              -- sa statistique choisie (clé)
}
local H = {}
local FUI = {}                  -- la page de la fenêtre Progression

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
            if n then
                trouve = "+" .. n .. pct
                S.descriptions[cle] = texte
                break
            end
        end
    end
    tip:Hide()
    S.parPoint[cle] = trouve or RC.PAR_POINT[cle] or "?"
    return S.parPoint[cle]
end

-- La ligne d'une statistique dans l'infobulle de l'aura « Attributs » : le
-- texte de son sort (« +5 Stamina. », « Augmente définitivement l'Endurance de
-- 5. »), la valeur d'un point remplacée par celle de tous ses points ; à
-- défaut, le bonus total suivi du nom de la statistique.
function H.LigneBonus(st)
    local un, pct = string.match(H.ParPoint(st.cle, st.spell) or "", "(%d+)%s*(%%?)")
    un = tonumber(un)
    if not un then return nil end
    local total = un * st.valeur
    local texte = S.descriptions[st.cle]
    if texte then
        local fait = false
        texte = string.gsub(texte, "%d+", function(n)
            if fait or tonumber(n) ~= un then return nil end
            fait = true
            return tostring(total)
        end)
        if fait then return texte end
    end
    return "+" .. total .. pct .. " " .. (L.noms[st.cle] or st.cle)
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
-- Le compteur de points de la vue affichée, et l'endroit d'où partent les
-- textes flottants (cadre hôte, ancre, décalage).
function H.Compteur()
    if S.fui then return FUI.h and FUI.h.valeur end
    return S.ui and S.ui.nombre
end

function H.CibleFlottant()
    if S.fui then
        if FUI.h then return S.fui, FUI.h.cadreValeur, 0, 6 end
        return nil
    end
    if S.ui then return S.ui, S.ui.nombre, -60, 6 end
end

-- Sursaut du compteur de points : deux échelles enchaînées.
function H.Sursaut()
    local nombre = H.Compteur()
    if not nombre then return end
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
    local hote, ancre, dx, dy = H.CibleFlottant()
    if not hote then return end
    local f
    for _, cand in ipairs(S.flottants) do
        if not cand.anim:IsPlaying() then f = cand; break end
    end
    if not f then
        f = CreateFrame("Frame", nil, hote)
        f:SetWidth(300); f:SetHeight(24)
        f:SetFrameLevel(hote:GetFrameLevel() + 20)
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
    f:SetPoint("CENTER", ancre, "CENTER", dx, dy)
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
    c.compte:SetText(Remplir(L.enSac, possede))
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
        l.valeur:SetText(string.format("%d |cffffffcc%s|r / %d", st.valeur, Remplir(L.attente, attente), st.max))
    else
        l.valeur:SetText(string.format("%d / %d", st.valeur, st.max))
    end
    l.parPoint:SetText(Remplir(L.parPoint, H.ParPoint(l.cle, st.spell)))
    local plein = st.valeur + attente >= st.max
    H.Actif(l.plus, S.etat.actif and not plein and dispo > 0)
    H.Actif(l.moins, attente > 0)
    l.nom:SetTextColor(plein and 0.6 or 1, plein and 0.6 or 0.82, plein and 0.6 or 0)
    S.anim = true
end

-- La vue affichée : la page de la fenêtre Progression avec ForeverUI, la
-- fenêtre grise sinon.
function H.Rendre()
    if S.fui then
        FUI.Rendre()
    else
        H.RendreClassique()
    end
end

function H.RendreClassique()
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
    -- Texte compose ici : il vient du serveur et n'existe pas au chargement.
    -- StaticPopup le passe a string.format : ses % sont doubles.
    local texte = Remplir(L.confirmReinit, H.Argent(S.etat.coutReset))
    StaticPopupDialogs["ATTRIBOOST_REINIT"].text = (texte:gsub("%%", "%%%%"))
    StaticPopup_Show("ATTRIBOOST_REINIT")
end

function H.Ouvrir()
    if S.fui then
        Progression.Ouvrir(RC.CLE)
        return
    end
    if not S.ui then H.Construire() end
    if S.ui:IsShown() then return end
    S.attente = {}
    S.ui:Show()
    H.Ouverture()
    AIO.Handle("Attriboost", "Ouvrir")
end

function H.Basculer()
    if S.fui then
        Progression.Basculer(RC.CLE)
        return
    end
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
        Remplir(L.parLivre, 3), "Echanger")
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
-- Page de la fenêtre Progression
-- ---------------------------------------------------------------------------
-- La disposition de la feuille de personnage de ForeverUI et de son onglet
-- Compétences (CharacterFrame.lua, SkillsTab.lua, validés), avec les éléments
-- que prête la fenêtre Progression (Progression.Kit) :
--   volet gauche  398 de large sous la barre de titre, fond
--                 UI-Character-Info-General-BG tendu à sa hauteur ; de haut en
--                 bas (demande du 2026-09-29) : les deux cartes d'échange (Tome
--                 du Savoir, Livre des talents : emplacement de composant,
--                 compteur et boutons rouges de la page de fabrication), le
--                 séparateur UI-Character-Info-ScrollLine-Long (le trait du haut
--                 de la liste ; celui du bas reste), la liste des dix
--                 statistiques (marges 10, écart 3, retrait 2 ; une ligne de 30 :
--                 nom GameFontHighlight à (2), jauge 160 x 29 à droite (-3)
--                 « valeur / max », « (+n) » en vert et les points en attente
--                 plus clairs ; survol 0,10, choisie 0,20), puis Réinitialiser
--                 sur toute la largeur, aux marges de la liste
--   volet droit   le reste (271), fond UI-Character-Info-Stat-BG tendu, bande de
--                 pierre en haut, séparateur common-framedivider à -6 ; dans la
--                 bande, à la place du niveau d'objet de camelot, l'en-tête
--                 UI-Character-Info-Title (197 x 34, « Attributs ») et la valeur
--                 « n disponible(s) » sur UI-Character-Info-ItemLevel-Bounce
--                 (Game15Font_o1) ; dessous, le détail de la statistique choisie
--                 (SkillDetailFrame) : nom, bonus par point, séparateur, puis le
--                 cadran de l'onglet PvP (demande du 2026-09-29) -- sa jauge
--                 part du bas, les points en attente plus clairs dessous ; au
--                 milieu du cercle le bonus total, « (+n) » en vert pour
--                 l'attente ; sous le cadran les points « valeur / max », à la
--                 place des victoires honorables -- et le compteur des points à
--                 poser ; en bas, Annuler et Valider
-- La première statistique est choisie à l'ouverture (SelectFirstSkill...).
local NC = {
    gauche = { 2, -21, 398, 2 },
    liste = { 10, -170, marge = 10, ecart = 3, ligne = 30, retrait = 2 },
    barre = { 160, 29, -3 }, nomX = 2, nomH = 15,
    cartes = { 10, -10, 186, 150, ecart = 6 },
    carte = { slot = { 12, -12, 39 }, nomX = 8, compteur = { 12, -66 }, marge = 12 },
    reset = { 10, 10 },
    pierre = 85, entete = { 197, 34, -2 }, valeur = { 187, 29 },
    detail = { 16, -95, -12 },
    titreL = 243, sousTitreY = -3, separateurY = -4,
    -- l'onglet PvP : le cadran sous le séparateur (0), le compte de ses
    -- victoires 1 sous le cadran, 12 de haut, GameFontNormal
    cadran = { 0, points = -1, pointsH = 12 },
    compteurY = -10,
    boutons = { h = 28, l = 80, marge = 30, bas = 12, ecart = 4 },
    separateur = { -6, embout = 4 },
    compteur = { 31, 20, fleche = { 23, 22 }, ecartMoins = -6 },
    fleches = "Interface\\Buttons\\UI-SpellbookIcon-",
    saisie = "Interface\\Common\\Common-Input-Border",
    police15 = "Fonts\\FRIZQT__.TTF",
    niveaux = { volets = 1, contenu = 2, separateur = 21 },
    evenements = { "BAG_UPDATE", "PLAYER_MONEY" },
}

-- Game15Font_o1 (15, contour), absente de 3.3.5
function FUI.Police15()
    local p = _G["AttriboostFontGame15o1"] or CreateFont("AttriboostFontGame15o1")
    p:SetFont(NC.police15, 15, "OUTLINE")
    p:SetTextColor(1, 1, 1)
    return p
end

-- Les éléments de cette page, par leurs coordonnées dans les feuilles que
-- ForeverUI installe (voir la trousse de la fenêtre Progression), ajoutés à
-- la trousse avant que la page ne se construise.
FUI.ART = {
    ["charactercreate-customize-dropdown-linemouseover-middle"] = { "interface\\ForeverUI\\glues\\charactercreate\\charactercreate", 0.997559, 0.998047, 0.000488, 0.02002, 1, 40 },
    ["charactercreate-customize-dropdown-linemouseover-side"] = { "interface\\ForeverUI\\glues\\charactercreate\\charactercreate", 0.990723, 0.996582, 0.000488, 0.02002, 12, 40 },
    ["common-framedivider"] = { "interface\\ForeverUI\\common\\commonframedividerc60", 0.0625, 0.75, 0.015625, 0.796875, 11, 50 },
    ["common-insideframe"] = { "interface\\ForeverUI\\common\\commoninsideframec60", 0.007812, 0.84375, 0.007812, 0.84375, 107, 107 },
    ["professions-slot-bg"] = { "interface\\ForeverUI\\professions\\professions-slot-bg", 0, 0.671875, 0, 0.671875, 43, 43 },
    ["ui-character-info-general-bg"] = { "interface\\ForeverUI\\paperdollinfoframe\\paperdollinfopart2c60", 0.000977, 0.389648, 0.000977, 0.454102, 398, 464 },
    ["ui-character-info-honor-bar-bg"] = { "interface\\ForeverUI\\pvpframe\\uicharacterinfohonorc60", 0.001953, 0.451172, 0.001953, 0.394531, 230, 201 },
    ["ui-character-info-honor-bar-bg-alliance"] = { "interface\\ForeverUI\\pvpframe\\uicharacterinfohonorc60", 0.001953, 0.1875, 0.523438, 0.708984, 95, 95 },
    ["ui-character-info-honor-bar-bg-glow"] = { "interface\\ForeverUI\\pvpframe\\uicharacterinfohonorc60", 0.455078, 0.816406, 0.001953, 0.363281, 185, 185 },
    ["ui-character-info-honor-bar-bg-horde"] = { "interface\\ForeverUI\\pvpframe\\uicharacterinfohonorc60", 0.001953, 0.1875, 0.712891, 0.898438, 95, 95 },
    ["ui-character-info-itemlevel-bounce"] = { "interface\\ForeverUI\\paperdollinfoframe\\paperdollinfopart1c60", 0.263672, 0.462891, 0.000977, 0.021484, 204, 21 },
    ["ui-character-info-scrollline"] = { "interface\\ForeverUI\\paperdollinfoframe\\paperdollinfopart1c60", 0.701172, 0.90625, 0.000977, 0.007812, 210, 7 },
    ["ui-character-info-scrollline-long"] = { "interface\\ForeverUI\\paperdollinfoframe\\paperdollinfopart1c60", 0.283203, 0.658203, 0.046875, 0.054688, 384, 8 },
    ["ui-character-info-stat-bg"] = { "interface\\ForeverUI\\paperdollinfoframe\\paperdollinfopart2c60", 0.621094, 0.848633, 0.376953, 0.750977, 233, 383 },
    ["ui-character-info-stat-stonebg"] = { "interface\\ForeverUI\\paperdollinfoframe\\paperdollinfopart1c60", 0.459961, 0.6875, 0.859375, 0.942383, 233, 85 },
    ["ui-character-info-title"] = { "interface\\ForeverUI\\paperdollinfoframe\\paperdollinfopart1c60", 0.283203, 0.479492, 0.056641, 0.087891, 201, 32 },
}
FUI.DECOUPES = {
    ["128-redbutton-highlight"] = { "interface\\ForeverUI\\buttons\\128-redbutton-highlight", 0.003906, 0.865234, 0, 1, 441, 128, nil, nil },
    ["128-redbutton-left"] = { "interface\\ForeverUI\\buttons\\128-redbutton-left-c60", 0.015625, 0.90625, 0, 1, 114, 128, nil, nil },
    ["128-redbutton-left-disabled"] = { "interface\\ForeverUI\\buttons\\128-redbutton-left-disabled-c60", 0.015625, 0.90625, 0, 1, 114, 128, nil, nil },
    ["128-redbutton-left-pressed"] = { "interface\\ForeverUI\\buttons\\128-redbutton-left-pressed-c60", 0.015625, 0.90625, 0, 1, 114, 128, nil, nil },
    ["128-redbutton-right"] = { "interface\\ForeverUI\\buttons\\128-redbutton-right-c60", 0.003906, 0.574219, 0, 1, 292, 128, nil, nil },
    ["128-redbutton-right-disabled"] = { "interface\\ForeverUI\\buttons\\128-redbutton-right-disabled-c60", 0.003906, 0.574219, 0, 1, 292, 128, nil, nil },
    ["128-redbutton-right-pressed"] = { "interface\\ForeverUI\\buttons\\128-redbutton-right-pressed-c60", 0.003906, 0.574219, 0, 1, 292, 128, nil, nil },
    ["_128-redbutton-center"] = { "interface\\ForeverUI\\buttons\\_128-redbutton-center-c60", 0.015625, 0.515625, 0, 1, 64, 128, true, false },
    ["_128-redbutton-center-disabled"] = { "interface\\ForeverUI\\buttons\\_128-redbutton-center-disabled-c60", 0.015625, 0.515625, 0, 1, 64, 128, true, false },
    ["_128-redbutton-center-pressed"] = { "interface\\ForeverUI\\buttons\\_128-redbutton-center-pressed-c60", 0.015625, 0.515625, 0, 1, 64, 128, true, false },
    ["common-insideframe"] = { "interface\\ForeverUI\\common\\commoninsideframec60", 0.007812, 0.84375, 0.007812, 0.84375, 107, 107, false, false, { 53, 53, 53, 53, 0 } },
}

-- LE CADRAN : celui de l'onglet PvP de camelot (PVPRankFrame.xml,
-- RankProgressBarDisplay), sans badge ni anneau de récompense, écrit ici :
-- 154 x 154 ; lueur ui-character-info-honor-bar-bg-glow 275 x 295 et fond de
-- la faction du joueur 115 x 115 au centre ; anneau
-- ui-character-info-honor-bar-bg 235 x 209 à (0, -1). La jauge part du bas
-- (<Cooldown rotation="180">) et tourne dans le sens des aiguilles. Elle est
-- BLEUE, du bleu des barres (demande du 2026-09-29) : l'anneau entier et le
-- demi-anneau bleus sont des images du module, que son installeur écrit
-- dans l'archive du jeu.
--   calques : le nombre de jauges superposées, la première dessous ;
--   cadran:Jauge(k, part) règle la k-ième (part de 0 à 1), cadran:Alpha(k, a)
--   sa transparence ; cadran.centre : un cadre au-dessus de la jauge, pour
--   ce qui s'écrit au milieu du cercle.
-- 3.3.5 n'a pas de jauge circulaire : chaque quart du cercle porte deux
-- textures, l'anneau entier lu sur ce quart (quart dépassé) et le
-- demi-anneau tourné (quart où la jauge s'arrête) ; les quarts pas encore
-- atteints restent vides.
FUI.CADRAN = {
    cote = 154, depart = 180,
    lueur = { 275, 295 }, fond = { 115, 115 }, anneau = { 235, 209, 0, -1 },
    entier = "Interface\\Attriboost\\honorfillblue",
    moitie = "Interface\\Attriboost\\honorfillhalfblue",
    -- les quarts, dans le sens des aiguilles depuis midi, en fraction du
    -- cadran : u vers la droite, v vers le bas
    quarts = { { 0.5, 1, 0, 0.5 }, { 0.5, 1, 0.5, 1 }, { 0, 0.5, 0.5, 1 }, { 0, 0.5, 0, 0.5 } },
}

-- le point (u, v) du cadran entier, lu dans une image tournée de l'angle
-- (cosinus, sinus) dans le sens des aiguilles : tourner l'image revient à
-- tourner la lecture en sens inverse autour du centre ; ce qui sort de
-- [0, 1] reprend le bord de l'image, vide
local function lireTourne(u, v, cosinus, sinus)
    local du, dv = u - 0.5, v - 0.5
    return 0.5 + du * cosinus + dv * sinus, 0.5 - du * sinus + dv * cosinus
end

local function majJauge(quarts, part)
    part = math.max(0, math.min(1, part or 0))
    local parcouru = part * 360
    for _, q in ipairs(quarts) do
        if parcouru >= q.depart + 90 then
            q.arc:Hide()
            q.plein:Show()
        elseif parcouru <= q.depart then
            q.arc:Hide()
            q.plein:Hide()
        else
            -- le demi-anneau couvre les 180 degrés qui finissent à l'angle
            -- dont on le tourne : on le tourne jusqu'à la tête de la jauge,
            -- moins le demi-tour qu'il porte déjà
            q.plein:Hide()
            local phi = math.rad(FUI.CADRAN.depart + parcouru - 360)
            local c, s = math.cos(phi), math.sin(phi)
            local a1, a2 = lireTourne(q.u1, q.v1, c, s)
            local b1, b2 = lireTourne(q.u1, q.v2, c, s)
            local c1, c2 = lireTourne(q.u2, q.v1, c, s)
            local d1, d2 = lireTourne(q.u2, q.v2, c, s)
            q.arc:SetTexCoord(a1, a2, b1, b2, c1, c2, d1, d2)
            q.arc:Show()
        end
    end
end

function FUI.Cadran(parent, calques)
    local K, C = FUI.K, FUI.CADRAN
    local c = CreateFrame("Frame", nil, parent)
    c:SetWidth(C.cote)
    c:SetHeight(C.cote)
    local function image(calque, nom, taille, x, y)
        local t = c:CreateTexture(nil, calque)
        K.SetAtlas(t, nom, true)
        t:SetWidth(taille[1])
        t:SetHeight(taille[2])
        t:SetPoint("CENTER", c, "CENTER", x or 0, y or 0)
        return t
    end
    image("BACKGROUND", "ui-character-info-honor-bar-bg-glow", C.lueur)
    local faction = string.lower((UnitFactionGroup and UnitFactionGroup("player")) or "Alliance")
    image("BACKGROUND", "ui-character-info-honor-bar-bg-" .. faction, C.fond)
    image("BORDER", "ui-character-info-honor-bar-bg", C.anneau, C.anneau[3], C.anneau[4])
    c.jauges = {}
    for k = 1, calques or 1 do
        local quarts = {}
        for i, Q in ipairs(C.quarts) do
            local q = { u1 = Q[1], u2 = Q[2], v1 = Q[3], v2 = Q[4], depart = (90 * (i - 1) - C.depart) % 360 }
            local function quart(fichier)
                local t = c:CreateTexture(nil, "ARTWORK")
                t:SetTexture(fichier)
                t:ClearAllPoints()
                t:SetPoint("TOPLEFT", c, "TOPLEFT", q.u1 * C.cote, -q.v1 * C.cote)
                t:SetPoint("BOTTOMRIGHT", c, "TOPLEFT", q.u2 * C.cote, -q.v2 * C.cote)
                t:Hide()
                return t
            end
            q.plein = quart(C.entier)
            q.plein:SetTexCoord(q.u1, q.u2, q.v1, q.v2)
            q.arc = quart(C.moitie)
            quarts[i] = q
        end
        c.jauges[k] = quarts
    end
    function c:Jauge(k, part) majJauge(self.jauges[k], part) end
    function c:Alpha(k, a)
        for _, q in ipairs(self.jauges[k]) do
            q.plein:SetAlpha(a)
            q.arc:SetAlpha(a)
        end
    end
    c.centre = CreateFrame("Frame", nil, c)
    c.centre:SetAllPoints(c)
    c.centre:SetFrameLevel(c:GetFrameLevel() + 1)
    return c
end

-- Construite à la première ouverture de l'onglet : les textes sont arrivés.
function FUI.Construire(p)
    local K = Progression.Kit
    FUI.K = K
    local h = { page = p, lignes = {}, cartes = {} }
    FUI.h = h
    local base = p:GetFrameLevel()
    -- les deux volets de la feuille
    local G = NC.gauche
    local gauche = CreateFrame("Frame", nil, p)
    gauche:SetWidth(G[3])
    gauche:SetPoint("TOPLEFT", p, "TOPLEFT", G[1], G[2])
    gauche:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", G[1], G[4])
    gauche:SetFrameLevel(base + NC.niveaux.volets)
    local fondGauche = gauche:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(fondGauche, "ui-character-info-general-bg", true)
    fondGauche:SetAllPoints(gauche)
    local droit = CreateFrame("Frame", nil, p)
    droit:SetPoint("TOPLEFT", gauche, "TOPRIGHT", 0, 0)
    droit:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -G[1], G[4])
    droit:SetFrameLevel(base + NC.niveaux.volets)
    local fondDroit = droit:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(fondDroit, "ui-character-info-stat-bg", true)
    fondDroit:SetAllPoints(droit)
    local pierre = droit:CreateTexture(nil, "ARTWORK")
    K.SetAtlas(pierre, "ui-character-info-stat-stonebg", true)
    pierre:SetHeight(NC.pierre)
    pierre:SetPoint("TOPLEFT", droit, "TOPLEFT", 0, 0)
    pierre:SetPoint("TOPRIGHT", droit, "TOPRIGHT", 0, 0)
    local sep = K.SeparateurVertical(droit, "common-framedivider", NC.separateur.embout, base + NC.niveaux.separateur)
    sep:SetPoint("TOPLEFT", droit, "TOPLEFT", NC.separateur[1], -1)
    sep:SetPoint("BOTTOMLEFT", droit, "BOTTOMLEFT", NC.separateur[1], 0)
    h.gauche, h.droit = gauche, droit
    FUI.ConstruireCartes(gauche)
    FUI.ConstruireListe(gauche)
    FUI.ConstruirePierre(droit)
    FUI.ConstruireDetail(droit)
    FUI.ConstruireBoutons(gauche, droit)
    p:SetScript("OnShow", function(self)
        for _, ev in ipairs(NC.evenements) do self:RegisterEvent(ev) end
        S.attente = {}
        AIO.Handle("Attriboost", "Ouvrir")
        FUI.Rendre()
    end)
    p:SetScript("OnHide", function(self)
        for _, ev in ipairs(NC.evenements) do self:UnregisterEvent(ev) end
        S.attente = {}
        GameTooltip:Hide()
    end)
    p:SetScript("OnEvent", function() FUI.Rendre() end)
end

-- ------------------------------------------------------------- la liste
function FUI.ConstruireListe(gauche)
    local K, h, Li = FUI.K, FUI.h, NC.liste
    local liste = CreateFrame("Frame", nil, gauche)
    liste:SetPoint("TOPLEFT", gauche, "TOPLEFT", Li[1], Li[2])
    liste:SetWidth(NC.gauche[3] - 2 * Li[1])
    liste:SetHeight(2 * Li.marge + 10 * Li.ligne + 9 * Li.ecart)
    liste:SetFrameLevel(gauche:GetFrameLevel() + 1)
    for _, bord in ipairs({ "TOP", "BOTTOM" }) do
        local trait = liste:CreateTexture(nil, "ARTWORK")
        K.SetAtlas(trait, "ui-character-info-scrollline-long")
        trait:SetPoint("CENTER", liste, bord, 0, 0)
    end
    h.liste = liste
end

function FUI.Survol(l)
    l.survol:SetAlpha((l.choisie and 0.20) or (l:IsMouseOver() and 0.10) or 0)
end

-- une jauge de l'onglet Compétences (SkillsBarTemplate) : fond découpé à 10,
-- remplissage bleu cuit, points en attente plus clairs dessous, texte
function FUI.Jauge(parent, largeur, hauteur)
    local K, J = FUI.K, FUI.K.Jauge
    local barre = CreateFrame("Frame", nil, parent)
    barre:SetWidth(largeur)
    barre:SetHeight(hauteur)
    K.NeufTranches(barre, J.fond, J.coin, { 0, 0, 0, 0 }, "BACKGROUND")
    barre.attente = barre:CreateTexture(nil, "BORDER")
    barre.attente:SetPoint("LEFT", barre, "LEFT", 0, 0)
    barre.attente:SetAlpha(0.45)
    barre.rempli = barre:CreateTexture(nil, "ARTWORK")
    barre.rempli:SetPoint("LEFT", barre, "LEFT", 0, 0)
    barre.texte = barre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    barre.texte:SetPoint("LEFT", barre, "LEFT", 0, 0)
    barre.texte:SetPoint("RIGHT", barre, "RIGHT", 0, 0)
    barre.texte:SetJustifyH("CENTER")
    barre.largeur = largeur
    return barre
end

function FUI.Remplir(t, part, largeur)
    local J = FUI.K.Jauge
    part = math.max(0, math.min(part or 0, 1))
    if part * largeur < 1 then
        t:Hide()
    else
        t:SetTexture(J.fichier)
        t:SetTexCoord(0, part, 0, 1)
        t:SetWidth(largeur * part)
        t:SetHeight(J.remplissage)
        t:Show()
    end
end

-- « valeur / max », ou « valeur (+n) / max » avec des points en attente
function FUI.RemplirJauge(barre, st, attente)
    FUI.Remplir(barre.rempli, st.valeur / math.max(1, st.max), barre.largeur)
    FUI.Remplir(barre.attente, (st.valeur + attente) / math.max(1, st.max), barre.largeur)
    if attente > 0 then
        barre.texte:SetText(string.format("%d |cff20ff20%s|r / %d", st.valeur, Remplir(L.attente, attente), st.max))
    else
        barre.texte:SetText(string.format("%d / %d", st.valeur, st.max))
    end
end

function FUI.Ligne(i)
    local K, h, Li = FUI.K, FUI.h, NC.liste
    local l = CreateFrame("Button", nil, h.liste)
    l:SetHeight(Li.ligne)
    l:SetPoint("TOPLEFT", h.liste, "TOPLEFT", Li.marge + Li.retrait, -(Li.marge + (i - 1) * (Li.ligne + Li.ecart)))
    l:SetWidth(NC.gauche[3] - 2 * NC.liste[1] - 2 * Li.marge - Li.retrait)
    l:RegisterForClicks("LeftButtonUp")
    local survol = CreateFrame("Frame", nil, l)
    survol:SetAllPoints(l)
    survol:SetAlpha(0)
    local cote = "charactercreate-customize-dropdown-linemouseover-side"
    local g = survol:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(g, cote, true)
    g:SetWidth(6)
    g:SetPoint("TOPLEFT", survol, "TOPLEFT", 0, 0)
    g:SetPoint("BOTTOMLEFT", survol, "BOTTOMLEFT", 0, 0)
    local d = survol:CreateTexture(nil, "BACKGROUND")
    if K.SetAtlas(d, cote, true) then
        local e = K.AtlasEntry(cote)
        d:SetTexCoord(e[3], e[2], e[4], e[5])
    end
    d:SetWidth(6)
    d:SetPoint("TOPRIGHT", survol, "TOPRIGHT", 0, 0)
    d:SetPoint("BOTTOMRIGHT", survol, "BOTTOMRIGHT", 0, 0)
    local m = survol:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(m, "charactercreate-customize-dropdown-linemouseover-middle", true)
    m:SetPoint("TOPLEFT", g, "TOPRIGHT", 0, 0)
    m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT", 0, 0)
    l.survol = survol
    l.barre = FUI.Jauge(l, NC.barre[1], NC.barre[2])
    l.barre:SetPoint("RIGHT", l, "RIGHT", NC.barre[3], 0)
    l.nom = l:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    l.nom:SetHeight(NC.nomH)
    l.nom:SetJustifyH("LEFT")
    l.nom:SetPoint("LEFT", l, "LEFT", NC.nomX, 0)
    l.nom:SetPoint("RIGHT", l.barre, "LEFT", -10, 0)
    l:SetScript("OnClick", function(self)
        if not self.cle then return end
        PlaySound("igMainMenuOptionCheckBoxOn")
        S.choisie = self.cle
        FUI.Rendre()
    end)
    l:SetScript("OnEnter", function(self)
        FUI.Survol(self)
        if not self.spell then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("spell:" .. self.spell)
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function(self)
        FUI.Survol(self)
        GameTooltip:Hide()
    end)
    return l
end

function FUI.MajListe()
    local h = FUI.h
    local stats = S.etat and S.etat.stats or {}
    for i = 1, math.max(#stats, #h.lignes) do
        local st = stats[i]
        local l = h.lignes[i]
        if st then
            if not l then
                l = FUI.Ligne(i)
                h.lignes[i] = l
            end
            local attente = S.attente[st.cle] or 0
            local plein = st.valeur + attente >= st.max
            l.cle, l.spell = st.cle, st.spell
            l.nom:SetText(L.noms[st.cle] or st.cle)
            l.nom:SetTextColor(plein and 0.6 or 1, plein and 0.6 or 1, plein and 0.6 or 1)
            FUI.RemplirJauge(l.barre, st, attente)
            l.choisie = (st.cle == S.choisie)
            FUI.Survol(l)
            l:Show()
        elseif l then
            l:Hide()
        end
    end
end

-- ------------------------------------------------------------- le compteur
-- NumericInputSpinnerTemplate de la page de fabrication (TradeSkill.lua) :
-- saisie 31 x 20 au liseré Common-Input-Border, flèches 23 x 22
-- (UI-SpellbookIcon-Prev/NextPage), la moins à 6 de la saisie. ecrire(n)
-- reçoit la valeur saisie ; les flèches sont laissées à l'appelant.
function FUI.Compteur(parent, ecrire)
    local C = NC.compteur
    local c = CreateFrame("EditBox", nil, parent)
    c:SetWidth(C[1])
    c:SetHeight(C[2])
    c:SetAutoFocus(false)
    c:SetNumeric(true)
    c:SetMaxLetters(3)
    c:SetFontObject(ChatFontNormal)
    c:SetJustifyH("CENTER")
    local function bord(u1, u2, largeur)
        local t = c:CreateTexture(nil, "BACKGROUND")
        t:SetTexture(NC.saisie)
        t:SetTexCoord(u1, u2, 0, 0.625)
        if largeur then t:SetWidth(largeur) end
        t:SetHeight(20)
        return t
    end
    local g = bord(0, 0.0625, 8)
    g:SetPoint("LEFT", c, "LEFT", -5, 0)
    local d = bord(0.9375, 1, 8)
    d:SetPoint("RIGHT", c, "RIGHT", 0, 0)
    local m = bord(0.0625, 0.9375)
    m:SetPoint("LEFT", g, "RIGHT", 0, 0)
    m:SetPoint("RIGHT", d, "LEFT", 0, 0)
    c:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    c:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    c:SetScript("OnEditFocusLost", function(self) ecrire(self:GetNumber() or 0) end)
    local function fleche(fichier)
        local f = CreateFrame("Button", nil, c)
        f:SetWidth(C.fleche[1])
        f:SetHeight(C.fleche[2])
        f:SetNormalTexture(NC.fleches .. fichier .. "-Up")
        f:SetPushedTexture(NC.fleches .. fichier .. "-Down")
        f:SetDisabledTexture(NC.fleches .. fichier .. "-Disabled")
        f:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
        f:GetHighlightTexture():SetBlendMode("ADD")
        return f
    end
    c.plus = fleche("NextPage")
    c.plus:SetPoint("LEFT", c, "RIGHT", 0, 0)
    c.moins = fleche("PrevPage")
    c.moins:SetPoint("RIGHT", c, "LEFT", C.ecartMoins, 0)
    return c
end

-- un bouton rouge de la page de fabrication (128-RedButton, 28 de haut, 80 au
-- moins, texte + 30)
function FUI.BoutonRouge(parent, clic)
    local B = NC.boutons
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(B.l)
    b:SetHeight(B.h)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b:SetFontString(fs)
    FUI.K.BoutonTroisTranches(b, "128-redbutton", { GameFontNormal, GameFontHighlight, GameFontDisable })
    b:SetScript("OnClick", clic)
    return b
end

function FUI.Texte(b, texte)
    b:SetText(texte)
    local fs = b:GetFontString()
    b:SetWidth(math.max(NC.boutons.l, (fs and fs:GetStringWidth() or 0) + NC.boutons.marge))
end

-- ------------------------------------------------------------- les cartes
function FUI.Carte(gauche, nom, objet, libelle, sousLibelle, handler)
    local K, Ca = FUI.K, NC.carte
    local c = CreateFrame("Frame", nil, gauche)
    c:SetWidth(NC.cartes[3])
    c:SetHeight(NC.cartes[4])
    c:SetFrameLevel(gauche:GetFrameLevel() + 1)
    c.nom, c.objet = nom, objet
    local fond = c:CreateTexture(nil, "BACKGROUND")
    fond:SetTexture(0, 0, 0, 0.35)
    fond:SetPoint("TOPLEFT", c, "TOPLEFT", 4, -4)
    fond:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -4, 4)
    local bord = K.AtlasEtire(c, "common-insideframe", "BORDER")
    bord.rect:SetAllPoints(c)
    -- l'emplacement de composant : Professions-Slot-bg, icône, UI-Quickslot2
    local b = CreateFrame("Button", nil, c)
    b:SetWidth(Ca.slot[3])
    b:SetHeight(Ca.slot[3])
    b:SetPoint("TOPLEFT", c, "TOPLEFT", Ca.slot[1], Ca.slot[2])
    local fondSlot = b:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(fondSlot, "professions-slot-bg", true)
    fondSlot:SetAllPoints(b)
    local icone = b:CreateTexture(nil, "ARTWORK")
    icone:SetAllPoints(b)
    icone:SetTexture((GetItemIcon and GetItemIcon(objet)) or select(10, GetItemInfo(objet))
        or (nom == "livres" and RC.ICONE_LIVRE_DEF or RC.ICONE_TALENTS_DEF))
    b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    local cadre = b:GetNormalTexture()
    cadre:SetDrawLayer("BORDER")
    cadre:ClearAllPoints()
    cadre:SetAllPoints(b)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink("item:" .. objet)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local largeurTexte = NC.cartes[3] - Ca.slot[1] - Ca.slot[3] - Ca.nomX - Ca.marge
    c.titre = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.titre:SetPoint("TOPLEFT", b, "TOPRIGHT", Ca.nomX, 0)
    c.titre:SetWidth(largeurTexte)
    c.titre:SetJustifyH("LEFT")
    c.titre:SetText(libelle)
    c.compte = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.compte:SetPoint("TOPLEFT", c.titre, "BOTTOMLEFT", 0, -3)
    c.compte:SetWidth(largeurTexte)
    c.compte:SetJustifyH("LEFT")
    c.sous = c:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    c.sous:SetPoint("TOPLEFT", c.compte, "BOTTOMLEFT", 0, -2)
    c.sous:SetWidth(largeurTexte)
    c.sous:SetJustifyH("LEFT")
    c.sous:SetText(sousLibelle)
    -- le compteur, « Tout » à sa droite, « Échanger » en bas
    c.compteur = FUI.Compteur(c, function(n)
        S.spin[nom] = n
        FUI.Rendre()
    end)
    c.compteur:SetPoint("TOPLEFT", c, "TOPLEFT",
        Ca.compteur[1] + NC.compteur.fleche[1] - NC.compteur.ecartMoins, Ca.compteur[2])
    c.compteur.moins:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        S.spin[nom] = S.spin[nom] - H.Pas()
        FUI.Rendre()
    end)
    c.compteur.plus:SetScript("OnClick", function()
        PlaySound("igMainMenuOptionCheckBoxOn")
        S.spin[nom] = S.spin[nom] + H.Pas()
        FUI.Rendre()
    end)
    c.tout = FUI.BoutonRouge(c, function()
        S.spin[nom] = GetItemCount(objet) or 1
        FUI.Rendre()
    end)
    FUI.Texte(c.tout, L.tout)
    -- centré sur la hauteur du compteur (28 contre 20)
    c.tout:SetPoint("TOPRIGHT", c, "TOPRIGHT", -Ca.marge, Ca.compteur[2] + (NC.boutons.h - NC.compteur[2]) / 2)
    c.echanger = FUI.BoutonRouge(c, function()
        local n = S.spin[nom]
        if n >= 1 and (GetItemCount(objet) or 0) >= n then
            AIO.Handle("Attriboost", handler, n)
        end
    end)
    FUI.Texte(c.echanger, L.echanger)
    c.echanger:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", Ca.marge, Ca.marge)
    c.echanger:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -Ca.marge, Ca.marge)
    return c
end

function FUI.ConstruireCartes(gauche)
    local h, Cs = FUI.h, NC.cartes
    local livres = FUI.Carte(gauche, "livres", RC.LIVRE, L.livre, Remplir(L.parLivre, 3), "Echanger")
    livres:SetPoint("TOPLEFT", gauche, "TOPLEFT", Cs[1], Cs[2])
    local talents = FUI.Carte(gauche, "talents", RC.LIVRE_TALENTS, L.livreTalents, L.parLivreTalents, "EchangerTalents")
    talents:SetPoint("TOPLEFT", livres, "TOPRIGHT", Cs.ecart, 0)
    h.cartes = { livres = livres, talents = talents }
end

-- les règles de la fenêtre grise (H.RendreCarte)
function FUI.MajCarte(c)
    local possede = GetItemCount(c.objet) or 0
    local maxi = math.max(1, possede)
    if S.spin[c.nom] > maxi then S.spin[c.nom] = maxi end
    if S.spin[c.nom] < 1 then S.spin[c.nom] = 1 end
    local ok = possede > 0 and S.etat and S.etat.actif
    c.compte:SetText(Remplir(L.enSac, possede))
    c.compteur:SetNumber(S.spin[c.nom])
    c:SetAlpha(ok and 1 or 0.45)
    H.Actif(c.compteur.moins, ok and S.spin[c.nom] > 1)
    H.Actif(c.compteur.plus, ok and S.spin[c.nom] < possede)
    H.Actif(c.tout, ok and S.spin[c.nom] < possede)
    H.Actif(c.echanger, ok)
    c.compteur:EnableMouse(ok and true or false)
end

-- ------------------------------------------------------------- la pierre
-- l'en-tête et la valeur du niveau d'objet de camelot (ItemLevelCategory,
-- ItemLevelFrame), en haut du volet droit ; au-dessus du cadran, dont la lueur
-- monte jusqu'à la pierre
function FUI.ConstruirePierre(droit)
    local K, h, E, V = FUI.K, FUI.h, NC.entete, NC.valeur
    local entete = CreateFrame("Frame", nil, droit)
    entete:SetWidth(E[1])
    entete:SetHeight(E[2])
    entete:SetPoint("TOP", droit, "TOP", 0, E[3])
    entete:SetFrameLevel(droit:GetFrameLevel() + 3)
    local fond = entete:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(fond, "ui-character-info-title", true)
    fond:SetAllPoints(entete)
    local titre = entete:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    titre:SetPoint("CENTER", entete, "CENTER", 0, 1)
    titre:SetText(L.titre)
    local cadre = CreateFrame("Frame", nil, droit)
    cadre:SetWidth(V[1])
    cadre:SetHeight(V[2])
    cadre:SetPoint("TOP", entete, "BOTTOM", 0, 0)
    cadre:SetFrameLevel(droit:GetFrameLevel() + 3)
    local rebond = cadre:CreateTexture(nil, "BORDER")
    K.SetAtlas(rebond, "ui-character-info-itemlevel-bounce")
    rebond:SetPoint("CENTER", cadre, "CENTER", 0, 0)
    local valeur = cadre:CreateFontString(nil, "ARTWORK")
    valeur:SetFontObject(FUI.Police15())
    valeur:SetPoint("CENTER", cadre, "CENTER", 0, -1)
    h.cadreValeur, h.valeur = cadre, valeur
    -- l'avertissement du système désactivé, sous la bande
    h.inactif = cadre:CreateFontString(nil, "ARTWORK", "GameFontRedSmall")
    h.inactif:SetPoint("TOP", droit, "TOP", 0, -NC.pierre + 2)
    h.inactif:SetText(L.inactif)
    h.inactif:Hide()
end

-- ------------------------------------------------------------- le détail
function FUI.ConstruireDetail(droit)
    local K, h, D = FUI.K, FUI.h, NC.detail
    -- les textes au-dessus du cadran : sa lueur déborde vers le haut et les
    -- voilerait (comme l'honneur de l'onglet PvP)
    local cadre = CreateFrame("Frame", nil, droit)
    cadre:SetPoint("TOPLEFT", droit, "TOPLEFT", D[1], D[2])
    cadre:SetPoint("BOTTOMRIGHT", droit, "BOTTOMRIGHT", D[3], NC.boutons.bas + NC.boutons.h + 8)
    cadre:SetFrameLevel(droit:GetFrameLevel() + 2)
    local d = { cadre = cadre }
    d.titre = cadre:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    d.titre:SetWidth(NC.titreL)
    d.titre:SetJustifyH("CENTER")
    d.titre:SetPoint("TOP", cadre, "TOP", 0, 0)
    d.sousTitre = cadre:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    d.sousTitre:SetWidth(NC.titreL)
    d.sousTitre:SetJustifyH("CENTER")
    d.sousTitre:SetPoint("TOP", d.titre, "BOTTOM", 0, NC.sousTitreY)
    d.separateur = cadre:CreateTexture(nil, "BORDER")
    K.SetAtlas(d.separateur, "ui-character-info-scrollline")
    d.separateur:SetPoint("TOP", d.sousTitre, "BOTTOM", 0, NC.separateurY)
    -- le cadran de l'onglet PvP, sous le texte ; deux jauges : l'attente
    -- (plus claire) dessous, l'acquis dessus
    local C = NC.cadran
    d.cadran = FUI.Cadran(droit, 2)
    d.cadran:SetFrameLevel(droit:GetFrameLevel() + 1)
    d.cadran.centre:SetFrameLevel(droit:GetFrameLevel() + 3)
    d.cadran:SetPoint("TOP", d.separateur, "BOTTOM", 0, C[1])
    d.cadran:Alpha(1, 0.45)
    d.bonus = d.cadran.centre:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    d.bonus:SetPoint("CENTER", d.cadran.centre, "CENTER", 0, 0)
    d.bonusAttente = d.cadran.centre:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    d.bonusAttente:SetPoint("TOP", d.bonus, "BOTTOM", 0, -2)
    -- les points, sous le cadran, là où l'onglet PvP compte les victoires
    d.points = cadre:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    d.points:SetJustifyH("CENTER")
    d.points:SetHeight(C.pointsH)
    d.points:SetPoint("TOP", d.cadran, "BOTTOM", 0, C.points)
    -- le compteur des points à poser sur la statistique choisie
    d.compteur = FUI.Compteur(cadre, function(n)
        local st = FUI.Choisie()
        if st then H.Poser(st.cle, n - (S.attente[st.cle] or 0)) end
        FUI.Rendre()
    end)
    d.compteur:SetPoint("TOP", d.points, "BOTTOM", 0, NC.compteurY)
    local function aide(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.aide, 1, 1, 1)
        GameTooltip:Show()
    end
    for sens, f in pairs({ [1] = d.compteur.plus, [-1] = d.compteur.moins }) do
        f:SetScript("OnClick", function()
            local st = FUI.Choisie()
            if not st then return end
            PlaySound("igMainMenuOptionCheckBoxOn")
            H.Poser(st.cle, sens * H.Pas())
        end)
        f:SetScript("OnEnter", aide)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    h.detail = d
end

-- le bonus de n points : celui d'un point (lu dans l'infobulle du sort, « +5 »
-- ou « +1% ») multiplié par n ; nil s'il ne se lit pas
function FUI.Bonus(st, n)
    local un, pct = string.match(H.ParPoint(st.cle, st.spell), "(%d+)%s*(%%?)")
    un = tonumber(un)
    if not un then return nil end
    return (un * n) .. pct
end

function FUI.Choisie()
    for _, st in ipairs(S.etat and S.etat.stats or {}) do
        if st.cle == S.choisie then return st end
    end
end

function FUI.MajDetail()
    local d = FUI.h.detail
    local st = FUI.Choisie()
    if not st then
        d.titre:SetText("")
        d.sousTitre:SetText("")
        d.separateur:Hide()
        d.cadran:Hide()
        d.points:SetText("")
        d.compteur:Hide()
        return
    end
    local attente = S.attente[st.cle] or 0
    local dispo = H.Disponibles()
    local plein = st.valeur + attente >= st.max
    local maxi = math.max(1, st.max)
    d.titre:SetText(L.noms[st.cle] or st.cle)
    d.sousTitre:SetText(Remplir(L.parPoint, H.ParPoint(st.cle, st.spell)))
    d.separateur:Show()
    d.cadran:Show()
    d.cadran:Jauge(1, (st.valeur + attente) / maxi)
    d.cadran:Jauge(2, st.valeur / maxi)
    -- au milieu du cercle : le bonus total, l'attente en vert dessous
    local total = FUI.Bonus(st, st.valeur)
    d.bonus:SetText(total and ("+" .. total) or "")
    local enPlus = attente > 0 and FUI.Bonus(st, attente)
    d.bonusAttente:SetText(enPlus and ("|cff20ff20" .. Remplir(L.attente, enPlus) .. "|r") or "")
    if attente > 0 then
        d.points:SetText(string.format("%d |cff20ff20%s|r / %d", st.valeur, Remplir(L.attente, attente), st.max))
    else
        d.points:SetText(string.format("%d / %d", st.valeur, st.max))
    end
    d.compteur:Show()
    d.compteur:SetNumber(attente)
    d.compteur:EnableMouse(S.etat.actif and true or false)
    H.Actif(d.compteur.plus, S.etat.actif and not plein and dispo > 0)
    H.Actif(d.compteur.moins, attente > 0)
end

-- ------------------------------------------------------------- les boutons
function FUI.ConstruireBoutons(gauche, droit)
    local h, B, R = FUI.h, NC.boutons, NC.reset
    h.valider = FUI.BoutonRouge(droit, H.Valider)
    FUI.Texte(h.valider, L.valider)
    h.annuler = FUI.BoutonRouge(droit, H.Annuler)
    FUI.Texte(h.annuler, L.annuler)
    local largeur = h.valider:GetWidth() + B.ecart + h.annuler:GetWidth()
    h.annuler:SetPoint("BOTTOMLEFT", droit, "BOTTOM", -largeur / 2, B.bas)
    h.valider:SetPoint("LEFT", h.annuler, "RIGHT", B.ecart, 0)
    -- Réinitialiser, en bas du volet gauche, sur toute sa largeur (demande
    -- du 2026-09-29), aux marges de la liste
    h.reinit = FUI.BoutonRouge(gauche, H.Reinitialiser)
    h.reinit:SetFrameLevel(gauche:GetFrameLevel() + 1)
    h.reinit:SetPoint("BOTTOMLEFT", gauche, "BOTTOMLEFT", R[1], R[2])
    h.reinit:SetPoint("BOTTOMRIGHT", gauche, "BOTTOMRIGHT", -R[1], R[2])
end

function FUI.Rendre()
    local h = FUI.h
    if not h then return end
    if S.etat and not S.choisie and S.etat.stats[1] then
        S.choisie = S.etat.stats[1].cle
    end
    local dispo, enAttente = H.Disponibles()
    h.valeur:SetText(S.etat and (dispo .. " " .. L.disponibles) or "")
    if S.etat and S.dernierDispo ~= nil and S.dernierDispo ~= dispo then H.Sursaut() end
    S.dernierDispo = S.etat and dispo or nil
    if S.etat and not S.etat.actif then h.inactif:Show() else h.inactif:Hide() end
    FUI.MajListe()
    FUI.MajDetail()
    for _, c in pairs(h.cartes) do FUI.MajCarte(c) end
    local etat = S.etat
    H.Actif(h.valider, (enAttente or 0) > 0)
    H.Actif(h.annuler, (enAttente or 0) > 0)
    local total = 0
    for _, st in ipairs(etat and etat.stats or {}) do total = total + st.valeur end
    FUI.Texte(h.reinit, L.reinit .. "  " .. H.Argent(etat and etat.coutReset or 0))
    H.Actif(h.reinit, etat and etat.actif and total > 0 and GetMoney() >= etat.coutReset)
end

-- ---------------------------------------------------------------------------
-- Ce que le serveur nous dit
-- ---------------------------------------------------------------------------
-- Les textes de l'interface, dans la langue du client : ils arrivent avec ce
-- code, dans le message d'ouverture d'AIO, avant tout affichage.
function Handlers.Textes(player, textes)
    if type(textes) == "table" then TEXTES = textes end
end

function Handlers.Etat(player, etat, extra)
    if type(etat) ~= "table" then return end
    if not S.fui and not S.ui then H.Construire() end
    S.etat = etat
    S.resume = etat
    S.attente = {}
    for _, l in ipairs(S.lignes) do
        local st = etat.stats[l.index]
        if st then l.icone:SetTexture(H.IconeSort(l.cle, st.spell)) end
    end
    H.Rendre()
    if type(extra) == "table" then
        if extra.echange then H.Flottant(Remplir(L.gainAttributs, extra.echange)) end
        if extra.talents then H.Flottant(Remplir(L.gainTalents, extra.talents), 0.4, 0.8, 1) end
        if extra.reinitialise then
            H.Flottant(L.reinitFait, 0.8, 0.8, 0.8)
            for _, l in ipairs(S.lignes) do l.cible = 0 end
            S.anim = true
        end
    end
end

-- L'état des points, sans rien construire ni afficher : il sert à l'infobulle
-- de l'aura « Attributs ». Si elle est montrée, elle se refait.
function Handlers.Resume(player, etat)
    if type(etat) ~= "table" then return end
    S.resume = etat
    local b = S.bulle
    local titre = b and _G[b.tip:GetName() .. "TextLeft1"]
    if b and b.tip:IsShown() and titre and titre:GetText() == GetSpellInfo(RC.RESUME) then
        b.tip:SetUnitAura(b.unit, b.index, b.filter)
    end
end

-- ---------------------------------------------------------------------------
-- L'infobulle de l'aura « Attributs » liste les bonus
-- ---------------------------------------------------------------------------
-- Comme la bannière de Stellar Tarot : les dix auras des statistiques sont
-- invisibles (permanentes, elles agissent toujours) ; la seule que le joueur
-- voit, « Attributs » (RC.RESUME), ne fait rien, et son infobulle reçoit ici,
-- sous son propre texte, une ligne par statistique pourvue (H.LigneBonus). Le
-- crochet est posé une fois par session ; la fonction globale est redéfinie à
-- chaque chargement du script (« .reload ale »). L'état peut avoir changé par
-- une commande de discussion : il est redemandé au serveur, au plus toutes les
-- deux secondes, et l'infobulle se refait à la réponse (Handlers.Resume).
function ATTRIBOOST_ON_BUFF_TOOLTIP(tip, unit, index, filter)
    if not unit or not UnitIsUnit(unit, "player") then return end
    -- l'identifiant du sort est la onzième valeur de UnitAura en 3.3.5 ; le nom en repli
    local nom, _, _, _, _, _, _, _, _, _, id = UnitAura(unit, index, filter)
    if not nom or (id ~= RC.RESUME and nom ~= GetSpellInfo(RC.RESUME)) then return end
    S.bulle = { tip = tip, unit = unit, index = index, filter = filter }
    if GetTime() - (S.resumeDemande or 0) > 2 then
        S.resumeDemande = GetTime()
        AIO.Handle("Attriboost", "Resume")
    end
    local lignes = {}
    for _, st in ipairs(S.resume and S.resume.stats or {}) do
        if (st.valeur or 0) > 0 then
            local ligne = H.LigneBonus(st)
            if ligne then lignes[#lignes + 1] = ligne end
        end
    end
    if #lignes == 0 then return end
    tip:AddLine(" ")
    for _, ligne in ipairs(lignes) do
        tip:AddLine(ligne, 0.2, 1, 0.2, true)
    end
    tip:Show()
end

if not ATTRIBOOST_BULLE_ACCROCHEE then
    ATTRIBOOST_BULLE_ACCROCHEE = true
    hooksecurefunc(GameTooltip, "SetUnitBuff", function(tip, unit, index, filter)
        ATTRIBOOST_ON_BUFF_TOOLTIP(tip, unit, index, filter)
    end)
    hooksecurefunc(GameTooltip, "SetUnitAura", function(tip, unit, index, filter)
        ATTRIBOOST_ON_BUFF_TOOLTIP(tip, unit, index, filter)
    end)
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

-- ---------------------------------------------------------------------------
-- DÉBUT DE LA FENÊTRE PROGRESSION -- copie commune, IDENTIQUE dans
-- Attriboost_Client.lua et ItemUpgrade_Client.lua : toute modification se
-- reporte dans l'autre fichier.
-- ---------------------------------------------------------------------------
-- Une fenêtre au thème de Camelot -- le LegacySystemFrame de camelot -- dont
-- les modules du serveur ajoutent les onglets (demande du 2026-09-29 : « si
-- le serveur a le module d'interface de mod-forever-ui d'installé, au lieu
-- d'avoir des boutons autour de la minimap et une interface grise, il faut un
-- bouton dans la barre des micro boutons. cliquer sur le bouton devra ouvrir
-- une fenêtre au thème de Camelot avec un onglet pour "Attriboost" et un
-- autre pour item upgrade (sachant que l'un ou l'autre peut être absent) » ;
-- l'icône : celle du menu Legacy de camelot ; le nom : Progression).
--
-- PORTÉE PAR LES MODULES (choix de l'utilisateur, 2026-09-29) : ce code
-- arrive avec chaque module, par AIO. Le premier module chargé crée la
-- fenêtre ; le suivant la trouve (global Progression) et n'y ajoute que son
-- onglet.
--
-- INDÉPENDANTE DE ForeverUI (règle de l'utilisateur, 2026-09-29 : les
-- modules « détectent si "forever-ui" est installé. Si non -> addon normaux,
-- si oui, ils montent leurs ui chacun avec les sources que "forever-ui" a
-- installé et qu'il lui dise "ajoute ce bouton dans ta micro barre" »).
-- ForeverUI ne connaît ni cette fenêtre ni ces modules, et ce code n'appelle
-- AUCUNE de ses fonctions de dessin : tout ce qui se dessine est écrit ici ou
-- dans la page du module. De ForeverUI, il ne prend que :
--   * ses FICHIERS de textures installés (Interface\ForeverUI\...), avec
--     leurs coordonnées recopiées dans les tables ci-dessous et dans celles
--     des pages ;
--   * sa micro-barre : ForeverUI.AddMicroButton (le bouton, avec le jeu
--     d'icônes « legacy » de ForeverUI) et ForeverUI.UpdateMicro (enfoncé tant
--     que la fenêtre est ouverte).
-- Sans ForeverUI.AddMicroButton, la fenêtre n'existe pas, et les modules
-- gardent leur interface d'origine.
--
-- RELEVÉ -- CAMELOT (blizzard_legacysystem : blizzard_legacysystem.xml /
-- .lua, blizzard_legacysystemtemplates.xml, _bootstrap.lua, _registration
-- .lua ; blizzard_micromenu : mainline/mainmenubarmicrobuttons.lua,
-- camelot/micromenucontaineroverrides.lua ; blizzard_sharedxml :
-- mainline/shareduipaneltemplates.xml, portraitframe.lua,
-- shared/button/threeslicebuttontemplate.xml / .lua) :
--   fenêtre      LegacySystemFrame, PortraitFrameTemplate, 920 x 575 ;
--                RegisterUIPanel : area "left", xoffset 35, pushable 1,
--                largeur 1005 ; ToggleFrame ; sons IG_CHARACTER_INFO_OPEN /
--                _CLOSE ; pas de titre
--   cadre        roche UI-Background-Rock en mosaïque de (2, -21) à
--                (-2, 2) ; stries _UI-Frame-TopTileStreaks de 43 à
--                (6, -21) ; coins du métal à (-13, 16), (2, 16), (-13, -8),
--                (2, -8), bords tendus entre eux ; bandeau du titre de
--                (58, -1) à (-24, -1), 20 de haut, texte GameFontNormal
--                à -5 de son haut
--   croix        UIPanelCloseButton : 24 x 24, RedButton-Exit / -pressed /
--                -disabled, lueur RedButton-Highlight en ADD, à TOPRIGHT
--                (-2, 1) de la fenêtre
--   portrait     SetPortraitAtlasRaw("Legacy-up-c60"), 45 x 62, TOPLEFT
--                (2, 10) ; le CircleMask du gabarit (TempPortraitAlphaMask)
--                le suit de (2, 0) à (-2, 4) ; le portrait (niveau 400)
--                passe sous le métal (500)
--   onglets      LegacySystemTabTemplate (LargeSideTabButtonTemplate,
--                fillToInterior) : le premier TOPLEFT sur le TOPRIGHT
--                (0, -60), chacun sous le précédent (0, -2) ; infobulle
--                tooltipText ; SelectPage : la page montrée, son onglet
--                coché ; les pages au niveau 100
--   bouton rouge ThreeSliceButtonTemplate : Left et Right à leur taille
--                d'atlas mise à l'échelle de la hauteur du bouton, Center
--                tendu entre eux, rognés s'ils ne tiennent pas dans la
--                largeur (UpdateScale) ; états -Pressed et -Disabled ;
--                lueur <atlas>-Highlight en ADD ; texte enfoncé de (-2, -1)
--   micro-bouton LegacyMicroButton : LoadMicroButtonTextures "Legacy",
--                après les talents ; grisé tant que le système est
--                verrouillé, enfoncé tant que la fenêtre est ouverte
--
-- CE QUI DIFFÈRE, ET POURQUOI.
--   * Les pages sont celles que déclarent les modules, par P.Ajouter. Chaque
--     page déclarée demande le micro-bouton : le premier module le crée, le
--     second le trouve déjà là ; sans module, il n'existe pas (demande du
--     2026-09-29). Camelot, lui, le grise.
--   * Un disque noir sous le portrait, dans le cercle (demande du
--     2026-09-29 : « l'icône dans le cercle du portrait de la fenêtre doit
--     avoir un fond noir ») : celui du portrait rond de PortraitFrameTemplate
--     (62 x 62 à (-5, 7), rogné par son CircleMask de (2, 0) à (-2, 4) : 58 x
--     58 à (-3, 7)), TempPortraitAlphaMask noirci, sous l'anneau de métal.
--   * La fenêtre a la taille de celle des métiers de ForeverUI (673 x 594) :
--     la page d'Item Upgrade reprend sa page de fabrication, à ses nombres.
--     La largeur du panneau garde la marge de camelot (1005 pour 920 : 85,
--     onglets compris).
--   * Un titre, « Progression » : le nom retenu par l'utilisateur. Il vient
--     des textes du module qui le donne (nomFenetre), lus à l'affichage : les
--     textes d'un module arrivent après son code.
--   * 3.3.5 n'a pas de masque : le portrait est une image où l'ellipse du
--     CircleMask est cuite. Chaque module installe la sienne (son
--     installeur l'écrit dans l'archive du jeu) et la donne à P.Ajouter ; la
--     fenêtre prend celle du module qui la crée.
--   * 3.3.5 n'a ni atlas ni découpe en neuf : les éléments se posent par
--     leurs coordonnées dans leur feuille (tables ci-dessous), les découpes
--     en morceaux posés à la main.
--   * Le panneau se déclare par ses attributs UIPanelLayout-*, sans toucher
--     à la table UIPanelWindows du client.
--
-- CE QUE LES MODULES APPELLENT (ils testent Progression.Ajouter et
-- Progression.Kit) :
--   P.Ajouter{ cle, ordre, titre, icone, construire, nomFenetre, portrait }
--     -- déclare une page et rend son cadre (toute la fenêtre ;
--     construire(page) le remplit, une fois, à sa première ouverture). titre :
--     un texte, ou une fonction qui le rend. ordre : la place de l'onglet (le
--     plus petit en haut). nomFenetre : le nom de la fenêtre et du
--     micro-bouton (texte ou fonction) ; portrait : le fichier du portrait ;
--     ceux de la page qui crée la fenêtre. Redéclarer une clé (un « .reload
--     ale ») remplace sa page par un cadre neuf.
--   P.Ouvrir(cle), P.Basculer(cle), P.Fermer(), P.Montree(cle).
--   P.Kit : la trousse de dessin écrite ici (voir plus bas) ; une page y
--     ajoute les coordonnées de ses propres éléments par K.AjouterArt.
if not (Progression and Progression.Ajouter) and ForeverUI and ForeverUI.AddMicroButton then
    Progression = {}
    local P = Progression
    local SEP = string.char(92)
    local ART = "Interface" .. SEP .. "ForeverUI" .. SEP
    local BOUTON = "ProgressionMicroButton"

    local N = {
        fenetre = { 673, 594 },
        -- l'image du portrait : la région utile de sa toile (198 x 273 sur
        -- 256 x 512), posée en 45 x 62
        portrait = { 45, 62, x = 2, y = 10, coords = { 0, 0.773438, 0, 0.533203 } },
        disque = { 58, x = -3, y = 7, fichier = ART .. "characterframe" .. SEP .. "tempportraitalphamask" },
        roche = { fichier = "interface" .. SEP .. "ForeverUI" .. SEP .. "framegeneral" .. SEP .. "ui-background-rock", 2, -21, -2, 2 },
        stries = { 43, x = 6, y = -21, x2 = -2 },
        metal = {
            { nom = "ui-frame-portraitmetal-cornertopleft", point = "TOPLEFT", x = -13, y = 16 },
            { nom = "ui-frame-metal-cornertopright", point = "TOPRIGHT", x = 2, y = 16 },
            { nom = "ui-frame-metal-cornerbottomleft", point = "BOTTOMLEFT", x = -13, y = -8 },
            { nom = "ui-frame-metal-cornerbottomright", point = "BOTTOMRIGHT", x = 2, y = -8 },
        },
        titre = { x1 = 58, x2 = -24, y = -1, h = 20, texteY = -5 },
        -- les onglets latéraux (ceux du livre des métiers de ForeverUI)
        onglet = { cote = 55, y = -60, ecart = -2, icone = 50, iconeX = -3, rognage = 0.03125 },
        niveaux = { page = 1, onglets = 1, portrait = 19, metal = 20, titre = 21, croix = 22 },
    }

    -- RegisterUIPanel de camelot, plus whileDead (3.3.5 ne l'ouvre pas sans)
    local PANNEAU = { area = "left", xoffset = 35, pushable = 1, whileDead = 1, width = N.fenetre[1] + 85 }

    P.pages = {}
    P.ordre = {}

    -- ------------------------------------------------------------ la trousse

    -- LES ÉLÉMENTS, par leurs coordonnées dans les feuilles que ForeverUI
    -- installe (les éléments de camelot, aux tailles qu'il leur donne).
    -- art : { fichier, u1, u2, v1, v2, largeur, hauteur } ; decoupes : les
    -- éléments qui se découpent en morceaux (bouton rouge, croix, cadre
    -- intérieur), { fichier, u1, u2, v1, v2, largeur, hauteur, mosaïque
    -- horizontale, mosaïque verticale, découpe { gauche, haut, droite, bas } }.
    local K = { art = {}, decoupes = {} }
    P.Kit = K

    function K.AjouterArt(art, decoupes)
        for nom, e in pairs(art or {}) do K.art[nom] = e end
        for nom, e in pairs(decoupes or {}) do K.decoupes[nom] = e end
    end

    K.AjouterArt({
        ["!ui-frame-metal-edgeleft"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalvertical2xc60", 0.001953, 0.373047, 0, 1, 95, 128 },
        ["!ui-frame-metal-edgeright"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalvertical2xc60", 0.376953, 0.748047, 0, 1, 95, 128 },
        ["_ui-frame-metal-edgebottom"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalhorizontal2xc60", 0, 1, 0.001953, 0.392578, 128, 100 },
        ["_ui-frame-metal-edgetop"] = { "interface\\ForeverUI\\framegeneral\\uiframemetalhorizontal2xc60", 0, 1, 0.396484, 0.767578, 128, 95 },
        ["_ui-frame-toptilestreaks"] = { "interface\\ForeverUI\\framegeneral\\uiframehorizontal", 0, 1, 0.007812, 0.34375, 256, 43 },
        ["common-sidetab"] = { "interface\\ForeverUI\\common\\commonsidetabc60", 0.007812, 0.4375, 0.007812, 0.476562, 55, 60 },
        ["common-sidetab-hover"] = { "interface\\ForeverUI\\common\\commonsidetabc60", 0.007812, 0.4375, 0.492188, 0.960938, 55, 60 },
        ["common-sidetab-selected"] = { "interface\\ForeverUI\\common\\commonsidetabc60", 0.453125, 0.882812, 0.007812, 0.476562, 55, 60 },
        ["common-stat-bar-bg"] = { "interface\\ForeverUI\\common\\commonstatbarc60", 0.003906, 0.265625, 0.539062, 0.765625, 67, 29 },
        ["ui-frame-metal-cornerbottomleft"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.000977, 0.186523, 0.001953, 0.392578, 95, 100 },
        ["ui-frame-metal-cornerbottomright"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.000977, 0.186523, 0.396484, 0.787109, 95, 100 },
        ["ui-frame-metal-cornertopright"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.188477, 0.374023, 0.376953, 0.748047, 95, 95 },
        ["ui-frame-portraitmetal-cornertopleft"] = { "interface\\ForeverUI\\framegeneral\\uiframemetal2xc60", 0.375977, 0.561523, 0.376953, 0.748047, 95, 95 },
    }, {
        ["redbutton-exit"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.007812, 0.257812, 32, 32, nil, nil },
        ["redbutton-exit-disabled"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.273438, 0.523438, 32, 32, nil, nil },
        ["redbutton-exit-pressed"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.136719, 0.261719, 0.539062, 0.789062, 32, 32, nil, nil },
        ["redbutton-highlight"] = { "interface\\ForeverUI\\buttons\\redbuttonsc60", 0.402344, 0.527344, 0.007812, 0.257812, 32, 32, nil, nil },
    })

    -- la jauge des barres, celle de l'onglet Compétences : common-stat-bar-bg
    -- découpée à 10, 29 de haut, remplissage bleu de 15
    K.Jauge = { fond = "common-stat-bar-bg", coin = 10, hauteur = 29, remplissage = 15,
        fichier = ART .. "Bars" .. SEP .. "statbarfillblue" }

    function K.AtlasEntry(nom)
        return K.art[nom]
    end

    -- l'élément sur la texture ; garderTaille : sans lui, la texture prend
    -- sa taille. Rend vrai s'il est connu.
    function K.SetAtlas(t, nom, garderTaille)
        local e = K.art[nom]
        if not e then return false end
        t:SetTexture(e[1])
        t:SetTexCoord(e[2], e[3], e[4], e[5])
        if not garderTaille then
            t:SetWidth(e[6])
            t:SetHeight(e[7])
        end
        return true
    end

    function K.Montrer(r, oui)
        if oui then r:Show() else r:Hide() end
    end

    -- 3.3.5 rend 1 / nil, parfois 0 / 1 : zéro est vrai en Lua
    local function vrai(v)
        return v and v ~= 0 and true or false
    end

    -- EN NEUF : les coins gardent leur taille (coin), les bords ne s'étirent
    -- que dans un sens, le centre dans les deux ; marges { gauche, haut,
    -- droite, bas } : de combien l'image déborde du cadre. Rend les neuf
    -- morceaux, en régions du cadre, sur le calque donné.
    function K.NeufTranches(cadre, nom, coin, marges, calque)
        local e = K.art[nom]
        if not e then return nil end
        local du = (e[3] - e[2]) * coin / e[6]
        local dv = (e[5] - e[4]) * coin / e[7]
        local us = { e[2], e[2] + du, e[3] - du, e[3] }
        local vs = { e[4], e[4] + dv, e[5] - dv, e[5] }
        local morceaux = {}
        local function morceau(colonne, ligne)
            local t = cadre:CreateTexture(nil, calque or "BACKGROUND")
            t:SetTexture(e[1])
            t:SetTexCoord(us[colonne], us[colonne + 1], vs[ligne], vs[ligne + 1])
            morceaux[#morceaux + 1] = t
            return t
        end
        local hg, hd, bg, bd = morceau(1, 1), morceau(3, 1), morceau(1, 3), morceau(3, 3)
        local haut, bas = morceau(2, 1), morceau(2, 3)
        local gauche, droite = morceau(1, 2), morceau(3, 2)
        local centre = morceau(2, 2)
        for _, t in ipairs({ hg, hd, bg, bd }) do
            t:SetWidth(coin)
            t:SetHeight(coin)
        end
        haut:SetHeight(coin)
        bas:SetHeight(coin)
        gauche:SetWidth(coin)
        droite:SetWidth(coin)
        local G, H, D, B = marges[1], marges[2], marges[3], marges[4]
        hg:SetPoint("TOPLEFT", cadre, "TOPLEFT", -G, H)
        hd:SetPoint("TOPRIGHT", cadre, "TOPRIGHT", D, H)
        bg:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT", -G, -B)
        bd:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT", D, -B)
        haut:SetPoint("TOPLEFT", hg, "TOPRIGHT")
        haut:SetPoint("TOPRIGHT", hd, "TOPLEFT")
        bas:SetPoint("BOTTOMLEFT", bg, "BOTTOMRIGHT")
        bas:SetPoint("BOTTOMRIGHT", bd, "BOTTOMLEFT")
        gauche:SetPoint("TOPLEFT", hg, "BOTTOMLEFT")
        gauche:SetPoint("BOTTOMRIGHT", bg, "TOPRIGHT")
        droite:SetPoint("TOPLEFT", hd, "BOTTOMLEFT")
        droite:SetPoint("BOTTOMRIGHT", bd, "TOPRIGHT")
        centre:SetPoint("TOPLEFT", hg, "BOTTOMRIGHT")
        centre:SetPoint("BOTTOMRIGHT", bd, "TOPLEFT")
        return morceaux
    end

    -- UN SÉPARATEUR VERTICAL EN TROIS : un embout en haut et en bas (embout
    -- pixels de l'image), le milieu tiré entre eux ; étirer l'élément entier
    -- étalerait ses embouts.
    function K.SeparateurVertical(parent, nom, embout, niveau)
        local e = K.art[nom]
        local cadre = CreateFrame("Frame", nil, parent)
        if not e then
            cadre:Hide()
            return cadre
        end
        embout = embout or 4
        cadre:SetWidth(e[6])
        cadre:SetFrameLevel(niveau or parent:GetFrameLevel())
        local dv = (e[5] - e[4]) * embout / e[7]
        local function tranche(v1, v2)
            local t = cadre:CreateTexture(nil, "OVERLAY")
            t:SetTexture(e[1])
            t:SetTexCoord(e[2], e[3], v1, v2)
            return t
        end
        local haut = tranche(e[4], e[4] + dv)
        haut:SetHeight(embout)
        haut:SetPoint("TOPLEFT", cadre, "TOPLEFT")
        haut:SetPoint("TOPRIGHT", cadre, "TOPRIGHT")
        local bas = tranche(e[5] - dv, e[5])
        bas:SetHeight(embout)
        bas:SetPoint("BOTTOMLEFT", cadre, "BOTTOMLEFT")
        bas:SetPoint("BOTTOMRIGHT", cadre, "BOTTOMRIGHT")
        local milieu = tranche(e[4] + dv, e[5] - dv)
        milieu:SetPoint("TOPLEFT", haut, "BOTTOMLEFT")
        milieu:SetPoint("BOTTOMRIGHT", bas, "TOPRIGHT")
        cadre.haut, cadre.milieu, cadre.bas = haut, milieu, bas
        return cadre
    end

    -- un élément à découper, posé sur une texture (sans changer sa taille) ;
    -- rend l'élément
    local function poserDecoupe(t, nom)
        local e = K.decoupes[nom]
        if not e then return nil end
        t:SetTexture(e[1])
        t:SetTexCoord(e[2], e[3], e[4], e[5])
        return e
    end

    -- L'ÉLÉMENT ÉTIRÉ. Un élément à découpe se pose en morceaux autour d'un
    -- rectangle invisible (rect) que la page ancre comme elle ancrerait
    -- l'élément : les marges gardent leur taille, le reste s'étire. Rend
    -- { rect, Poser(nom), Montrer(oui), Alpha(a) }.
    local function decouperEtire(obj)
        local e = obj.e
        local d = e[10]
        for _, t in ipairs(obj.morceaux) do t:Hide() end
        if not d then
            obj.rect:SetTexture(e[1])
            obj.rect:SetTexCoord(e[2], e[3], e[4], e[5])
            return
        end
        obj.rect:SetTexture(nil)
        local W, Ht = e[6], e[7]
        local g, h, dr, b = d[1], d[2], d[3], d[4]
        local us = { e[2], e[2] + (e[3] - e[2]) * g / W, e[3] - (e[3] - e[2]) * dr / W, e[3] }
        local vs = { e[4], e[4] + (e[5] - e[4]) * h / Ht, e[5] - (e[5] - e[4]) * b / Ht, e[5] }
        local largeurs, hauteurs = { g, nil, dr }, { h, nil, b }
        local r, n = obj.rect, 0
        for ligne = 1, 3 do
            for col = 1, 3 do
                local lw, lh = largeurs[col], hauteurs[ligne]
                if (lw == nil or lw > 0) and (lh == nil or lh > 0) then
                    n = n + 1
                    local t = obj.morceaux[n]
                    if not t then
                        t = obj.hote:CreateTexture(nil, obj.calque)
                        obj.morceaux[n] = t
                    end
                    t:SetTexture(e[1])
                    t:SetTexCoord(us[col], us[col + 1], vs[ligne], vs[ligne + 1])
                    t:ClearAllPoints()
                    if col == 1 then
                        t:SetPoint("LEFT", r, "LEFT")
                        t:SetWidth(lw)
                    elseif col == 3 then
                        t:SetPoint("RIGHT", r, "RIGHT")
                        t:SetWidth(lw)
                    else
                        t:SetPoint("LEFT", r, "LEFT", g, 0)
                        t:SetPoint("RIGHT", r, "RIGHT", -dr, 0)
                    end
                    if ligne == 1 then
                        t:SetPoint("TOP", r, "TOP")
                        t:SetHeight(lh)
                    elseif ligne == 3 then
                        t:SetPoint("BOTTOM", r, "BOTTOM")
                        t:SetHeight(lh)
                    else
                        t:SetPoint("TOP", r, "TOP", 0, -h)
                        t:SetPoint("BOTTOM", r, "BOTTOM", 0, b)
                    end
                    if obj.visible ~= false then t:Show() end
                end
            end
        end
        obj.nombre = n
    end

    function K.AtlasEtire(hote, nom, calque)
        local obj = { hote = hote, calque = calque or "ARTWORK", morceaux = {} }
        obj.rect = hote:CreateTexture(nil, obj.calque)
        function obj:Poser(n)
            self.e = K.decoupes[n]
            decouperEtire(self)
        end
        function obj:Montrer(oui)
            self.visible = oui and true or false
            if self.e[10] then
                for i = 1, self.nombre or 0 do K.Montrer(self.morceaux[i], oui) end
            else
                K.Montrer(self.rect, oui)
            end
        end
        function obj:Alpha(a)
            self.rect:SetAlpha(a)
            for _, t in ipairs(self.morceaux) do t:SetAlpha(a) end
        end
        obj:Poser(nom)
        return obj
    end

    -- efface l'art que le client 3.3.5 pose sur ses propres boutons
    local function effacerArt(b)
        for _, lire in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
            local t = b[lire] and b[lire](b)
            if t then t:SetTexture(nil) end
        end
    end

    -- LE BOUTON ROUGE (ThreeSliceButtonTemplate) : voir le relevé plus haut.
    local function rogner(t, e, gaucheVersDroite, part)
        local u1, u2 = e[2], e[3]
        if gaucheVersDroite then
            t:SetTexCoord(u1, u1 + (u2 - u1) * part, e[4], e[5])
        else
            t:SetTexCoord(u2 - (u2 - u1) * part, u2, e[4], e[5])
        end
    end

    local function peindreTrois(b, etat)
        local r = b.trois
        if not vrai(b:IsEnabled()) then etat = "DISABLED" end
        local suffixe = (etat == "DISABLED" and "-disabled") or (etat == "PUSHED" and "-pressed") or ""
        local eg = poserDecoupe(r.gauche, r.atlas .. "-left" .. suffixe)
        poserDecoupe(r.centre, "_" .. r.atlas .. "-center" .. suffixe)
        local ed = poserDecoupe(r.droite, r.atlas .. "-right" .. suffixe)
        -- UpdateScale
        local hauteur, largeur = b:GetHeight(), b:GetWidth()
        local echelle = hauteur / eg[7]
        local lg, ld = eg[6] * echelle, ed[6] * echelle
        if lg + ld > largeur then
            local surplus = lg + ld - largeur
            local ng, nd = lg, ld
            if (lg - surplus) > ld then
                ng = lg - surplus
            elseif (ld - surplus) > lg then
                nd = ld - surplus
            else
                if lg ~= ld then
                    surplus = surplus - math.abs(lg - ld)
                    ng = math.min(lg, ld)
                    nd = ng
                end
                ng = ng - surplus / 2
                nd = nd - surplus / 2
            end
            rogner(r.gauche, eg, true, ng / lg)
            rogner(r.droite, ed, false, nd / ld)
            lg, ld = ng, nd
        end
        r.gauche:SetWidth(lg)
        r.gauche:SetHeight(hauteur)
        r.droite:SetWidth(ld)
        r.droite:SetHeight(hauteur)
        r.actif = vrai(b:IsEnabled())
    end

    -- atlas : le nom de l'élément, sans son suffixe (« 128-redbutton ») ;
    -- polices : { normale, survol, grisée }, des objets police
    function K.BoutonTroisTranches(b, atlas, polices)
        effacerArt(b)
        local r = { atlas = atlas }
        r.gauche = b:CreateTexture(nil, "BACKGROUND")
        r.gauche:SetPoint("TOPLEFT", b, "TOPLEFT")
        r.droite = b:CreateTexture(nil, "BACKGROUND")
        r.droite:SetPoint("TOPRIGHT", b, "TOPRIGHT")
        r.centre = b:CreateTexture(nil, "BACKGROUND")
        r.centre:SetPoint("TOPLEFT", r.gauche, "TOPRIGHT")
        r.centre:SetPoint("BOTTOMRIGHT", r.droite, "BOTTOMLEFT")
        b.trois = r
        -- la lueur, sur tout le bouton, en ADD
        b:SetHighlightTexture(K.decoupes[atlas .. "-highlight"][1])
        local lueur = b:GetHighlightTexture()
        poserDecoupe(lueur, atlas .. "-highlight")
        lueur:ClearAllPoints()
        lueur:SetAllPoints(b)
        lueur:SetBlendMode("ADD")
        if polices then
            b:SetNormalFontObject(polices[1])
            b:SetHighlightFontObject(polices[2] or polices[1])
            b:SetDisabledFontObject(polices[3] or polices[1])
        end
        local texte = b:GetFontString()
        if texte then
            texte:ClearAllPoints()
            texte:SetPoint("CENTER", b, "CENTER", 0, 0)
        end
        b:SetPushedTextOffset(-2, -1)
        b:HookScript("OnMouseDown", function(self)
            if vrai(self:IsEnabled()) then peindreTrois(self, "PUSHED") end
        end)
        b:HookScript("OnMouseUp", function(self) peindreTrois(self, "NORMAL") end)
        b:HookScript("OnShow", function(self) peindreTrois(self, "NORMAL") end)
        b:HookScript("OnSizeChanged", function(self) peindreTrois(self, "NORMAL") end)
        b:HookScript("OnEnable", function(self) peindreTrois(self, "NORMAL") end)
        b:HookScript("OnDisable", function(self) peindreTrois(self, "NORMAL") end)
        peindreTrois(b, "NORMAL")
        return b
    end

    -- la croix (UIPanelCloseButton) : voir le relevé plus haut
    local function croix(b, fenetre)
        b:SetWidth(24)
        b:SetHeight(24)
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", fenetre, "TOPRIGHT", -2, 1)
        for _, v in ipairs({
            { "SetNormalTexture", "GetNormalTexture", "redbutton-exit" },
            { "SetPushedTexture", "GetPushedTexture", "redbutton-exit-pressed" },
            { "SetDisabledTexture", "GetDisabledTexture", "redbutton-exit-disabled" },
            { "SetHighlightTexture", "GetHighlightTexture", "redbutton-highlight" },
        }) do
            b[v[1]](b, K.decoupes[v[3]][1])
            local t = b[v[2]](b)
            poserDecoupe(t, v[3])
            t:ClearAllPoints()
            t:SetAllPoints(b)
            if v[1] == "SetHighlightTexture" then t:SetBlendMode("ADD") end
        end
        return b
    end

    -- le cadre (PortraitFrameTemplate) : voir le relevé plus haut
    local function habiller(f, portrait)
        local R = N.roche
        local roche = f:CreateTexture(nil, "BACKGROUND")
        roche:SetTexture(R.fichier, true)
        if roche.SetHorizTile then
            roche:SetHorizTile(true)
            roche:SetVertTile(true)
        end
        roche:SetPoint("TOPLEFT", f, "TOPLEFT", R[1], R[2])
        roche:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", R[3], R[4])
        local stries = f:CreateTexture(nil, "BACKGROUND")
        K.SetAtlas(stries, "_ui-frame-toptilestreaks", true)
        stries:SetHeight(N.stries[1])
        stries:SetPoint("TOPLEFT", f, "TOPLEFT", N.stries.x, N.stries.y)
        stries:SetPoint("TOPRIGHT", f, "TOPRIGHT", N.stries.x2, N.stries.y)
        local metal = CreateFrame("Frame", nil, f)
        metal:SetAllPoints(f)
        metal:SetFrameLevel(f:GetFrameLevel() + N.niveaux.metal)
        local coins = {}
        for i, coin in ipairs(N.metal) do
            local t = metal:CreateTexture(nil, "OVERLAY")
            K.SetAtlas(t, coin.nom)
            t:SetPoint(coin.point, metal, coin.point, coin.x, coin.y)
            coins[i] = t
        end
        local function bord(nom, a1, c1, r1, a2, c2, r2)
            local t = metal:CreateTexture(nil, "OVERLAY")
            K.SetAtlas(t, nom)
            t:SetPoint(a1, c1, r1)
            t:SetPoint(a2, c2, r2)
        end
        bord("_ui-frame-metal-edgetop", "TOPLEFT", coins[1], "TOPRIGHT", "TOPRIGHT", coins[2], "TOPLEFT")
        bord("_ui-frame-metal-edgebottom", "BOTTOMLEFT", coins[3], "BOTTOMRIGHT", "BOTTOMRIGHT", coins[4], "BOTTOMLEFT")
        bord("!ui-frame-metal-edgeleft", "TOPLEFT", coins[1], "BOTTOMLEFT", "BOTTOMLEFT", coins[3], "TOPLEFT")
        bord("!ui-frame-metal-edgeright", "TOPRIGHT", coins[2], "BOTTOMRIGHT", "BOTTOMRIGHT", coins[4], "TOPRIGHT")
        local cadrePortrait = CreateFrame("Frame", nil, f)
        cadrePortrait:SetAllPoints(f)
        cadrePortrait:SetFrameLevel(f:GetFrameLevel() + N.niveaux.portrait)
        local Pt = N.portrait
        local image = cadrePortrait:CreateTexture(nil, "OVERLAY")
        image:SetWidth(Pt[1])
        image:SetHeight(Pt[1])
        image:SetPoint("TOPLEFT", f, "TOPLEFT", Pt.x, Pt.y)
        image:SetTexture(portrait)
        local T = N.titre
        local bandeau = CreateFrame("Frame", nil, f)
        bandeau:SetFrameLevel(f:GetFrameLevel() + N.niveaux.titre)
        bandeau:SetHeight(T.h)
        bandeau:SetPoint("TOPLEFT", f, "TOPLEFT", T.x1, T.y)
        bandeau:SetPoint("TOPRIGHT", f, "TOPRIGHT", T.x2, T.y)
        local titre = bandeau:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        titre:SetPoint("TOP", bandeau, "TOP", 0, T.texteY)
        titre:SetText("")
        -- 45 x 62, la région utile de l'image
        image:SetHeight(Pt[2])
        image:SetTexCoord(Pt.coords[1], Pt.coords[2], Pt.coords[3], Pt.coords[4])
        -- le fond noir du cercle, sous le portrait (même cadre, calque inférieur)
        local D = N.disque
        local disque = cadrePortrait:CreateTexture(nil, "ARTWORK")
        disque:SetTexture(D.fichier)
        disque:SetVertexColor(0, 0, 0, 1)
        disque:SetWidth(D[1])
        disque:SetHeight(D[1])
        disque:SetPoint("TOPLEFT", f, "TOPLEFT", D.x, D.y)
        return { roche = roche, stries = stries, metal = metal, portrait = image, titre = titre,
            bandeau = bandeau, cadrePortrait = cadrePortrait, disque = disque }
    end

    local function poser(r, ...)
        r:ClearAllPoints()
        r:SetPoint(...)
    end

    local function texte(v)
        if type(v) == "function" then return v() end
        return v
    end

    -- LE MICRO-BOUTON, dans la micro-barre de ForeverUI : demandé dès qu'une
    -- page existe (ForeverUI.AddMicroButton le crée une fois, après les
    -- talents, avec son jeu d'icônes Legacy ; en combat, à la sortie du
    -- combat), enfoncé tant que la fenêtre est ouverte.
    local majMicro
    local MICRO = {
        name = BOUTON, atlasSet = "legacy", after = "TalentMicroButton",
        tooltip = function() return texte(P.nom) or "" end,
        onClick = function() P.Basculer() end,
        ready = function() majMicro() end,
    }
    majMicro = function()
        if #P.ordre > 0 then
            ForeverUI.AddMicroButton(MICRO)
        end
        if ForeverUI.UpdateMicro then
            ForeverUI.UpdateMicro(BOUTON, (P.fenetre and P.fenetre:IsShown()) and true or false)
        end
    end

    -- ------------------------------------------------------------ les onglets

    local function creerOnglet(f, k)
        local O = N.onglet
        local b = CreateFrame("Button", "ProgressionTab" .. k, f)
        b:SetWidth(O.cote)
        b:SetHeight(O.cote)
        b:SetFrameLevel(f:GetFrameLevel() + N.niveaux.onglets)
        b:RegisterForClicks("LeftButtonUp")
        local fond = b:CreateTexture(nil, "BACKGROUND")
        K.SetAtlas(fond, "common-sidetab", true)
        fond:SetAllPoints(b)
        local icone = b:CreateTexture(nil, "ARTWORK")
        icone:SetWidth(O.icone)
        icone:SetHeight(O.icone)
        icone:SetPoint("CENTER", b, "CENTER", O.iconeX, 0)
        icone:SetTexCoord(O.rognage, 1 - O.rognage, O.rognage, 1 - O.rognage)
        local choisi = b:CreateTexture(nil, "OVERLAY")
        K.SetAtlas(choisi, "common-sidetab-selected", true)
        choisi:SetAllPoints(b)
        choisi:Hide()
        local survol = b:CreateTexture(nil, "HIGHLIGHT")
        K.SetAtlas(survol, "common-sidetab-hover", true)
        survol:SetAllPoints(b)
        b.icone, b.choisi = icone, choisi
        b:SetScript("OnEnter", function(self)
            local d = P.pages[self.cle or ""]
            if not d then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT", -4, -4)
            GameTooltip:SetText(texte(d.titre) or "")
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnMouseDown", function(self, bouton)
            if bouton == "LeftButton" then poser(self.icone, "CENTER", self, "CENTER", O.iconeX + 1, -1) end
        end)
        b:SetScript("OnMouseUp", function(self, bouton)
            if bouton == "LeftButton" then
                poser(self.icone, "CENTER", self, "CENTER", O.iconeX, 0)
                PlaySound("igCharacterInfoTab")
            end
        end)
        b:SetScript("OnClick", function(self)
            if self.cle then P.Choisir(self.cle) end
        end)
        if k == 1 then
            b:SetPoint("TOPLEFT", f, "TOPRIGHT", 0, O.y)
        else
            b:SetPoint("TOPLEFT", f.onglets[k - 1], "BOTTOMLEFT", 0, O.ecart)
        end
        return b
    end

    local function majOnglets()
        local f = P.fenetre
        if not f then return end
        for k, cle in ipairs(P.ordre) do
            local d = P.pages[cle]
            local b = f.onglets[k] or creerOnglet(f, k)
            f.onglets[k] = b
            b.cle = cle
            b.icone:SetTexture(d.icone)
            K.Montrer(b.choisi, cle == P.courante)
            b:Show()
        end
        for k = #P.ordre + 1, #f.onglets do f.onglets[k]:Hide() end
    end

    -- ------------------------------------------------------------ la fenêtre

    function P.Construire(portrait)
        if P.fenetre then return P.fenetre end
        local f = CreateFrame("Frame", "ProgressionFrame", UIParent)
        f:SetWidth(N.fenetre[1])
        f:SetHeight(N.fenetre[2])
        f:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
        f:SetToplevel(true)
        f:EnableMouse(true)
        f:Hide()
        -- le panneau, déclaré par ses attributs (GetUIPanelWindowInfo les lit
        -- avant la table UIPanelWindows)
        for k, v in pairs(PANNEAU) do
            f:SetAttribute("UIPanelLayout-" .. k, v)
        end
        f:SetAttribute("UIPanelLayout-defined", true)
        f:SetAttribute("UIPanelLayout-enabled", true)
        local habit = habiller(f, portrait)
        f.habit = habit
        local b = CreateFrame("Button", "ProgressionFrameCloseButton", f, "UIPanelCloseButton")
        croix(b, f)
        b:SetFrameLevel(f:GetFrameLevel() + N.niveaux.croix)
        f.croix = b
        f.onglets = {}
        f:SetScript("OnShow", function()
            habit.titre:SetText(texte(P.nom) or "")
            PlaySound("igCharacterInfoOpen")
            majMicro()
        end)
        f:SetScript("OnHide", function()
            PlaySound("igCharacterInfoClose")
            majMicro()
        end)
        P.fenetre = f
        return f
    end

    -- SelectPage : la page clé se montre (construite à sa première ouverture),
    -- les autres se cachent, son onglet est coché
    function P.Choisir(cle)
        local d = P.pages[cle]
        if not d then return end
        if not d.construite then
            d.construite = true
            d.construire(d.page)
        end
        for _, c in ipairs(P.ordre) do
            if c ~= cle then P.pages[c].page:Hide() end
        end
        P.courante = cle
        d.page:Show()
        majOnglets()
    end

    -- tri des onglets : ordre, puis clé
    local function avant(a, b)
        local x, y = P.pages[a], P.pages[b]
        if x.ordre ~= y.ordre then return x.ordre < y.ordre end
        return a < b
    end

    function P.Ajouter(d)
        if type(d) ~= "table" or type(d.cle) ~= "string" or type(d.construire) ~= "function" then return nil end
        local f = P.Construire(d.portrait)
        P.nom = P.nom or d.nomFenetre
        local ancienne = P.pages[d.cle]
        local montree = ancienne and ancienne.page:IsShown() and f:IsShown()
        if ancienne then
            ancienne.page:Hide()
        else
            table.insert(P.ordre, d.cle)
        end
        local page = CreateFrame("Frame", nil, f)
        page:SetAllPoints(f)
        page:SetFrameLevel(f:GetFrameLevel() + N.niveaux.page)
        page:Hide()
        P.pages[d.cle] = {
            cle = d.cle, ordre = tonumber(d.ordre) or 100, titre = d.titre or d.cle, icone = d.icone,
            construire = d.construire, page = page,
        }
        table.sort(P.ordre, avant)
        if montree then P.Choisir(d.cle) end
        majOnglets()
        majMicro()
        return page
    end

    -- ToggleLegacySystemUI : la page clé (sinon la dernière montrée, sinon la
    -- première)
    function P.Ouvrir(cle)
        if #P.ordre == 0 then return end
        local f = P.Construire()
        if not (cle and P.pages[cle]) then
            cle = (P.courante and P.pages[P.courante]) and P.courante or P.ordre[1]
        end
        if not f:IsShown() then ShowUIPanel(f) end
        if f:IsShown() and not (P.courante == cle and P.pages[cle].page:IsShown()) then
            P.Choisir(cle)
        end
    end

    function P.Fermer()
        if P.fenetre and P.fenetre:IsShown() then HideUIPanel(P.fenetre) end
    end

    -- la fenêtre ouverte sur cette page (ou sur toute page, sans clé) se ferme ;
    -- sinon elle s'ouvre sur elle
    function P.Basculer(cle)
        local f = P.fenetre
        if f and f:IsShown() and (not cle or cle == P.courante) then
            P.Fermer()
        else
            P.Ouvrir(cle)
        end
    end

    function P.Montree(cle)
        local f = P.fenetre
        return (f and f:IsShown() and P.courante == cle) and true or false
    end
end
-- ---------------------------------------------------------------------------
-- FIN DE LA FENÊTRE PROGRESSION (copie commune)
-- ---------------------------------------------------------------------------

-- Avec la fenêtre Progression (ForeverUI présent), son onglet remplace
-- la fenêtre grise et le bouton de la minimap. Les titres sont lus à
-- l'affichage : les textes arrivent après ce code.
if Progression and Progression.Ajouter and Progression.Kit then
    Progression.Kit.AjouterArt(FUI.ART, FUI.DECOUPES)
    S.fui = Progression.Ajouter({
        cle = RC.CLE, ordre = RC.ORDRE, icone = RC.ONGLET_ICONE,
        titre = function() return L.titre end,
        nomFenetre = function() return L.progression end, portrait = RC.PORTRAIT,
        construire = FUI.Construire,
    })
end
if not S.fui then
    H.CreerBoutonMinimap()
end

StaticPopupDialogs["ATTRIBOOST_REINIT"] = {
    text = "",       -- compose par H.Reinitialiser
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function() AIO.Handle("Attriboost", "Reinitialiser") end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}
