--[[----------------------------------------------------------------------------
    Amélioration d'objets (mod-item-upgrade) — interface joueur, côté client

    Expédiée au client par AIO : rien à installer. Ouverture par /amelioration,
    /iu, ou un clic droit sur un jeton de puissance. Même charte que la fenêtre
    Attriboost : boîte de dialogue 3.3.5, plaque de titre, cartes sombres,
    barres de progression au liseré des compétences, uniquement des textures de
    l'interface d'origine.

    La fenêtre ne décide de rien. Le choix d'un objet (glisser-déposer depuis
    les sacs, ou clic sur une pièce d'équipement) demande au serveur son barème
    (Selectionner → Objet) ; le module C++ répond en parallèle par un message
    d'addon « STATS » (rangs et valeurs en mémoire, seule autorité). Les cases
    cochées restent EN ATTENTE (barre claire) jusqu'à « Améliorer » ; le coût
    de la sélection est calculé ici, à partir du barème reçu.

    Client Lua 5.1 : 60 upvalues par fonction — constantes dans RC, textes
    dans L, état dans S, fonctions dans H.
------------------------------------------------------------------------------]]
local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return                                  -- côté serveur : on s'arrête ici
end

local Handlers = AIO.AddHandlers("ItemUpgrade", {})

local FR = GetLocale() == "frFR"
local L = FR and {
    titre = "Amélioration d'objets",
    deposer = "Déposez un objet ici",
    aide = "Glissez un objet depuis vos sacs, ou cliquez une pièce d'équipement.",
    retirer = "Clic : retirer l'objet",
    equipement = "Équipement",
    niveau = "Niveau d'objet %d",
    chargement = "Lecture de l'objet…",
    aucune = "Aucune statistique améliorable sur cet objet.",
    invalide = "Cet objet ne peut pas être amélioré.",
    rang = "%d / %d",
    rangMax = "rang maximum",
    suivant = "%d → %d  (+%d)",
    actuel = "%d",
    cout = "Coût de la sélection",
    gratuit = "Aucun coût",
    manquant = "%s manquant",
    requis = "Requis : %d",
    possede = "Vous avez : %d",
    manque = "Manque : %d",
    honneur = "%d honneur",
    arene = "%d arène",
    tout = "Tout sélectionner",
    annuler = "Annuler",
    ameliorer = "Améliorer",
    reussi = "+%d rang(s)",
    inactif = "Le système d'amélioration est désactivé.",
    mmAide = "Clic : ouvrir ou fermer la fenêtre",
    aideLigne = "Clic : sélectionner pour le prochain rang",
    prochain = "Prochain rang : %d (+%d %%)",
    coutRang = "Coût du prochain rang :",
    noms = {
        [0] = "Mana", [1] = "Points de vie", [3] = "Agilité", [4] = "Force", [5] = "Intelligence",
        [6] = "Esprit", [7] = "Endurance", [12] = "Score de défense", [13] = "Score d'esquive",
        [14] = "Score de parade", [15] = "Score de blocage", [16] = "Toucher (mêlée)",
        [17] = "Toucher (distance)", [18] = "Toucher (sorts)", [19] = "Critique (mêlée)",
        [20] = "Critique (distance)", [21] = "Critique (sorts)", [22] = "Toucher subi (mêlée)",
        [23] = "Toucher subi (distance)", [24] = "Toucher subi (sorts)", [25] = "Critique subi (mêlée)",
        [26] = "Critique subi (distance)", [27] = "Critique subi (sorts)", [28] = "Hâte (mêlée)",
        [29] = "Hâte (distance)", [30] = "Hâte (sorts)", [31] = "Score de toucher",
        [32] = "Score de critique", [33] = "Score de toucher subi", [34] = "Score de critique subi",
        [35] = "Score de résilience", [36] = "Score de hâte", [37] = "Score d'expertise",
        [38] = "Puissance d'attaque", [39] = "Puissance d'attaque à distance",
        [40] = "Puissance d'attaque farouche", [41] = "Soins", [42] = "Dégâts des sorts",
        [43] = "Mana toutes les 5 s", [44] = "Pénétration d'armure", [45] = "Puissance des sorts",
        [46] = "Points de vie toutes les 5 s", [47] = "Pénétration des sorts", [48] = "Valeur de blocage",
    },
} or {
    titre = "Item Upgrades",
    deposer = "Drop an item here",
    aide = "Drag an item from your bags, or click a piece of equipment.",
    retirer = "Click: remove the item",
    equipement = "Equipment",
    niveau = "Item level %d",
    chargement = "Reading item…",
    aucune = "No upgradeable statistic on this item.",
    invalide = "This item cannot be upgraded.",
    rang = "%d / %d",
    rangMax = "maximum rank",
    suivant = "%d → %d  (+%d)",
    actuel = "%d",
    cout = "Cost of the selection",
    gratuit = "No cost",
    manquant = "%s missing",
    requis = "Required: %d",
    possede = "You have: %d",
    manque = "Missing: %d",
    honneur = "%d honor",
    arene = "%d arena",
    tout = "Select all",
    annuler = "Cancel",
    ameliorer = "Upgrade",
    reussi = "+%d rank(s)",
    inactif = "The item upgrade system is disabled.",
    mmAide = "Click: open or close the window",
    aideLigne = "Click: select for the next rank",
    prochain = "Next rank: %d (+%d %%)",
    coutRang = "Cost of the next rank:",
    noms = {
        [0] = "Mana", [1] = "Health", [3] = "Agility", [4] = "Strength", [5] = "Intellect",
        [6] = "Spirit", [7] = "Stamina", [12] = "Defense rating", [13] = "Dodge rating",
        [14] = "Parry rating", [15] = "Block rating", [16] = "Hit (melee)", [17] = "Hit (ranged)",
        [18] = "Hit (spell)", [19] = "Crit (melee)", [20] = "Crit (ranged)", [21] = "Crit (spell)",
        [22] = "Hit taken (melee)", [23] = "Hit taken (ranged)", [24] = "Hit taken (spell)",
        [25] = "Crit taken (melee)", [26] = "Crit taken (ranged)", [27] = "Crit taken (spell)",
        [28] = "Haste (melee)", [29] = "Haste (ranged)", [30] = "Haste (spell)", [31] = "Hit rating",
        [32] = "Critical strike rating", [33] = "Hit taken rating", [34] = "Crit taken rating",
        [35] = "Resilience rating", [36] = "Haste rating", [37] = "Expertise rating",
        [38] = "Attack power", [39] = "Ranged attack power", [40] = "Feral attack power",
        [41] = "Healing", [42] = "Spell damage", [43] = "Mana per 5 sec.", [44] = "Armor penetration",
        [45] = "Spell power", [46] = "Health per 5 sec.", [47] = "Spell penetration", [48] = "Block value",
    },
}

local RC = {
    LARGEUR = 640, CARTE_H = 84, EQUIP_H = 46, LIGNE_H = 42, COUT_H = 72, PIED_H = 54,
    ECART = 8, ICONE = 30, ICONE_OBJET = 40, ICONE_EQUIP = 28, ICONE_JETON = 28, BARRE_H = 16,
    NOM_W = 196, COCHE = 24, MAX_LIGNES = 10,
    -- Retraits du contenu par rapport à la boîte de dialogue (charte Attriboost).
    INSET_G = 20, INSET_H = 38, INSET_D = 20, INSET_B = 20,
    BORDURE_DIALOGUE = "Interface\\DialogFrame\\UI-DialogBox-Border",
    PLAQUE = "Interface\\DialogFrame\\UI-DialogBox-Header",
    FOND_SOLIDE = { 0.08, 0.08, 0.10, 1 },
    BARRE_BORDURE = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-BarBorder",
    BARRE_BORDURE_COORDS = { 0.0078, 0.9961, 0.1875, 0.7812 },
    -- Bouton de minimap, composition standard 3.3.5 : fond noir, icône rognée
    -- en rond, cercle de suivi par-dessus. ANGLE = position sur le pourtour, en
    -- degrés (0 = droite, 90 = haut) ; Attriboost occupe 120°, le Mythique+ 189°.
    MM_ANGLE = 155, MM_RAYON = 80, MM_TAILLE = 31,
    MM_FOND = "Interface\\Minimap\\UI-Minimap-Background",
    MM_BORDURE = "Interface\\Minimap\\MiniMap-TrackingBorder",
    MM_SURVOL = "Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight",
    MM_ICONE = "Interface\\Icons\\Trade_BlackSmithing",
    FOND = "Interface\\Tooltips\\UI-Tooltip-Background",
    BORDURE = "Interface\\Tooltips\\UI-Tooltip-Border",
    BARRE = "Interface\\TargetingFrame\\UI-StatusBar",
    SURBRILLANCE = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
    HALO = "Interface\\Buttons\\ButtonHilight-Square",
    CADRE_ICONE = "Interface\\Buttons\\UI-Quickslot2",
    EMPLACEMENT_VIDE = "Interface\\Buttons\\UI-EmptySlot",
    COCHE_TEX = "Interface\\Buttons\\UI-CheckBox-Check",
    BLANC = "Interface\\Buttons\\WHITE8X8",
    OR = { 1, 0.82, 0 },
    GRIS = { 0.55, 0.55, 0.55 },
    ROUGE = { 1, 0.3, 0.3 },
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
    -- Emplacements d'équipement, dans l'ordre de la feuille de personnage.
    EQUIP = { 1, 2, 3, 15, 5, 9, 10, 6, 7, 8, 11, 12, 13, 14, 16, 17, 18 },
    JETONS = { 801050, 801051, 801052, 801053, 801054 },
    PREFIXE = "ITEMUPGRADE_RESP",
    ICONE_DEFAUT = "Interface\\Icons\\INV_Misc_Gem_01",
    ICONES = {
        [0] = "Interface\\Icons\\Spell_Shadow_ManaBurn",
        [1] = "Interface\\Icons\\INV_Potion_54",
        [3] = "Interface\\Icons\\INV_Sword_51",
        [4] = "Interface\\Icons\\Spell_Holy_GreaterBlessingofKings",
        [5] = "Interface\\Icons\\Spell_Holy_ArcaneIntellect",
        [6] = "Interface\\Icons\\Spell_Holy_Rapture",
        [7] = "Interface\\Icons\\Spell_Holy_WordFortitude",
        [12] = "Interface\\Icons\\Ability_Defend",
        [13] = "Interface\\Icons\\Ability_Rogue_Feint",
        [14] = "Interface\\Icons\\Ability_Parry",
        [15] = "Interface\\Icons\\INV_Shield_06",
        [16] = "Interface\\Icons\\Ability_Marksmanship",
        [17] = "Interface\\Icons\\Ability_Marksmanship",
        [18] = "Interface\\Icons\\Ability_Marksmanship",
        [19] = "Interface\\Icons\\Ability_CriticalStrike",
        [20] = "Interface\\Icons\\Ability_CriticalStrike",
        [21] = "Interface\\Icons\\Ability_CriticalStrike",
        [22] = "Interface\\Icons\\Ability_Warrior_ShieldReflection",
        [23] = "Interface\\Icons\\Ability_Warrior_ShieldReflection",
        [24] = "Interface\\Icons\\Ability_Warrior_ShieldReflection",
        [25] = "Interface\\Icons\\Ability_Warrior_ShieldReflection",
        [26] = "Interface\\Icons\\Ability_Warrior_ShieldReflection",
        [27] = "Interface\\Icons\\Ability_Warrior_ShieldReflection",
        [28] = "Interface\\Icons\\Spell_Nature_BloodLust",
        [29] = "Interface\\Icons\\Spell_Nature_BloodLust",
        [30] = "Interface\\Icons\\Spell_Nature_BloodLust",
        [31] = "Interface\\Icons\\Ability_Marksmanship",
        [32] = "Interface\\Icons\\Ability_CriticalStrike",
        [33] = "Interface\\Icons\\Ability_Warrior_ShieldReflection",
        [34] = "Interface\\Icons\\Ability_Warrior_ShieldReflection",
        [35] = "Interface\\Icons\\Ability_Warrior_ShieldWall",
        [36] = "Interface\\Icons\\Spell_Nature_BloodLust",
        [37] = "Interface\\Icons\\INV_Sword_27",
        [38] = "Interface\\Icons\\Ability_Warrior_BattleShout",
        [39] = "Interface\\Icons\\Ability_Hunter_SniperShot",
        [40] = "Interface\\Icons\\Ability_Druid_Ravage",
        [41] = "Interface\\Icons\\Spell_Holy_HolyBolt",
        [42] = "Interface\\Icons\\INV_Enchant_EssenceMysticalSmall",
        [43] = "Interface\\Icons\\Spell_Magic_ManaGain",
        [44] = "Interface\\Icons\\Ability_Warrior_SavageBlow",
        [45] = "Interface\\Icons\\INV_Enchant_EssenceMysticalSmall",
        [46] = "Interface\\Icons\\Spell_Nature_Regenerate",
        [47] = "Interface\\Icons\\Ability_Mage_MissileBarrage",
        [48] = "Interface\\Icons\\Ability_Warrior_ShieldBash",
    },
}

local S = {
    ui = nil, etat = nil, objet = nil, stats = nil, entry = nil, lien = nil,
    lignes = {}, donnees = {}, selection = {}, equip = {}, jetons = {},
    anim = false, reussites = 0, flottants = {}, attente = false, mm = nil,
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

function H.Id(lien)
    return lien and tonumber(lien:match("item:(%d+)"))
end

function H.Nom(typ)
    return L.noms[typ] or ("#" .. tostring(typ))
end

function H.Icone(typ)
    return RC.ICONES[typ] or RC.ICONE_DEFAUT
end

-- Valeur d'une statistique au rang donné : formule du module
-- (valeur × (1 + pct/100), plancher valeur + rang).
function H.Valeur(base, typ, rang)
    if not rang or rang <= 0 then return base end
    local b = S.objet and S.objet.bareme[typ]
    local pct = b and b.pct and b.pct[rang]
    if not pct then return base end
    local v = math.floor(base * (1 + pct / 100))
    if v < base + rang then v = base + rang end
    return v
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
-- cheval sur le bord haut, bouton de fermeture classique (charte Attriboost).
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

-- Icône dans un cadre de raccourci, avec halo au survol (carte Attriboost).
function H.CadreIcone(parent, taille)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(taille); b:SetHeight(taille)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetAllPoints()
    b.icone:SetTexCoord(0.06, 0.94, 0.06, 0.94)
    local marge = math.floor(taille * 0.3)
    b.bord = b:CreateTexture(nil, "OVERLAY")
    b.bord:SetTexture(RC.CADRE_ICONE)
    b.bord:SetPoint("TOPLEFT", -marge, marge); b.bord:SetPoint("BOTTOMRIGHT", marge, -marge)
    local halo = b:CreateTexture(nil, "HIGHLIGHT")
    halo:SetTexture(RC.HALO); halo:SetBlendMode("ADD"); halo:SetAllPoints()
    return b
end

-- ---------------------------------------------------------------------------
-- Animations (fondu, remplissage amorti, texte flottant)
-- ---------------------------------------------------------------------------
function H.Ouverture()
    UIFrameFadeIn(S.ui, RC.FONDU, 0, 1)
end

function H.Amortir(elapsed)
    local reste = false
    local k = math.min(1, elapsed * RC.AMORTI)
    for _, l in ipairs(S.lignes) do
        if l:IsShown() then
            local d = l.cible - l.actuel
            if math.abs(d) > 0.02 then
                l.actuel = l.actuel + d * k
                reste = true
            else
                l.actuel = l.cible
            end
            l.barre:SetValue(l.actuel)
            l.barreAttente:SetValue(l.actuel + (l.attente or 0))
        end
    end
    S.anim = reste
end

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
    f:SetPoint("CENTER", S.ui.carte, "CENTER", 0, 0)
    f.texte:SetText(texte)
    f.texte:SetTextColor(r or 1, g or 0.82, b or 0)
    f:SetAlpha(1)
    f:Show()
    f.anim:Play()
end

-- ---------------------------------------------------------------------------
-- Fusion des deux sources : gabarit (serveur Lua) et STATS (module C++)
-- ---------------------------------------------------------------------------
-- Une statistique du gabarit absente de STATS est au rang maximum (le module
-- ne liste que celles qui ont encore un rang à acheter). Une statistique de
-- STATS absente du gabarit (suffixe aléatoire) est ajoutée à la suite.
function H.Fusionner()
    S.donnees = {}
    if not S.objet or S.objet.absent then return end
    local vus = {}
    for _, s in ipairs(S.objet.stats) do
        local b = S.objet.bareme[s.type]
        local st = S.stats and S.stats[s.type]
        local d = { type = s.type, base = s.base, max = b and b.max or S.objet.rangMax }
        if st then
            d.rang, d.suivant, d.baseC = st.rang, st.suivant, st.base
        elseif S.stats then
            d.rang = d.max          -- listé au gabarit, absent de STATS : au maximum
        else
            d.rang = nil            -- STATS pas encore reçu
        end
        table.insert(S.donnees, d)
        vus[s.type] = true
    end
    if S.stats then
        for typ, st in pairs(S.stats) do
            if not vus[typ] then
                local b = S.objet.bareme[typ]
                table.insert(S.donnees, { type = typ, base = st.base, baseC = st.base, rang = st.rang,
                                          suivant = st.suivant, max = b and b.max or S.objet.rangMax })
            end
        end
    end
end

function H.Donnee(typ)
    for _, d in ipairs(S.donnees) do
        if d.type == typ then return d end
    end
end

function H.CoutSelection()
    local total = { c = 0, h = 0, a = 0, o = {}, n = 0 }
    if not S.objet or S.objet.absent then return total end
    for typ, sel in pairs(S.selection) do
        local d = H.Donnee(typ)
        local b = S.objet.bareme[typ]
        if sel and d and d.rang and b and d.rang < d.max then
            local c = b.couts[d.rang + 1]
            if c then
                total.c = total.c + (c.c or 0)
                total.h = total.h + (c.h or 0)
                total.a = total.a + (c.a or 0)
                for _, o in ipairs(c.o or {}) do
                    total.o[o[1]] = (total.o[o[1]] or 0) + o[2]
                end
            end
            total.n = total.n + 1
        end
    end
    return total
end

function H.Suffisant(total)
    if GetMoney() < total.c then return false end
    if total.h > 0 and (GetHonorCurrency and GetHonorCurrency() or 0) < total.h then return false end
    if total.a > 0 and (GetArenaCurrency and GetArenaCurrency() or 0) < total.a then return false end
    for id, n in pairs(total.o) do
        if (GetItemCount(id) or 0) < n then return false end
    end
    return true
end

-- ---------------------------------------------------------------------------
-- Rendu
-- ---------------------------------------------------------------------------
function H.RendreCarte()
    local c = S.ui.carte
    if S.lien then
        local nom, _, qualite, niveau, _, _, _, _, _, texture = GetItemInfo(S.lien)
        c.slot.icone:SetTexture(texture or RC.ICONE_DEFAUT)
        c.slot.icone:Show()
        c.slot.vide:Hide()
        local r, g, b = GetItemQualityColor(qualite or 1)
        c.nom:SetText(nom or S.lien)
        c.nom:SetTextColor(r, g, b)
        if S.objet and S.objet.absent then
            c.sous:SetText(L.invalide); c.sous:SetTextColor(unpack(RC.ROUGE))
        elseif not S.objet or not S.stats then
            c.sous:SetText(L.chargement); c.sous:SetTextColor(unpack(RC.GRIS))
        else
            c.sous:SetText(string.format(L.niveau, niveau or 0)); c.sous:SetTextColor(unpack(RC.GRIS))
        end
    else
        c.slot.icone:Hide()
        c.slot.vide:Show()
        c.nom:SetText(L.deposer)
        c.nom:SetTextColor(unpack(RC.OR))
        c.sous:SetText(L.aide)
        c.sous:SetTextColor(unpack(RC.GRIS))
    end
end

function H.RendreEquipement()
    for _, e in ipairs(S.equip) do
        local lien = GetInventoryItemLink("player", e.slot)
        local texture = GetInventoryItemTexture("player", e.slot)
        e.lien = lien
        if lien and texture then
            e.icone:SetTexture(texture)
            e:SetAlpha(1)
            e:Enable()
            if S.lien and H.Id(lien) == S.entry then
                e.choisi:Show()
            else
                e.choisi:Hide()
            end
        else
            e.icone:SetTexture(RC.EMPLACEMENT_VIDE)
            e:SetAlpha(0.35)
            e:Disable()
            e.choisi:Hide()
        end
    end
end

function H.RendreLigne(l, d)
    l.donnee = d
    l.icone:SetTexture(H.Icone(d.type))
    l.nom:SetText(H.Nom(d.type))
    local plein = d.rang and d.rang >= d.max
    local sel = S.selection[d.type] and not plein
    local base = d.baseC or d.base
    if d.rang == nil then
        l.detail:SetText(L.chargement)
    elseif plein then
        l.detail:SetText(string.format(L.actuel, H.Valeur(base, d.type, d.rang)) .. "  ·  " .. L.rangMax)
    else
        local actuel = H.Valeur(base, d.type, d.rang)
        local suivant = d.suivant or H.Valeur(base, d.type, d.rang + 1)
        l.detail:SetText(string.format(L.suivant, actuel, suivant, suivant - actuel))
    end
    l.barre:SetMinMaxValues(0, d.max)
    l.barreAttente:SetMinMaxValues(0, d.max)
    l.cible = d.rang or 0
    l.attente = sel and 1 or 0
    if sel then
        l.valeur:SetText(string.format("%d |cffffffcc(+1)|r / %d", d.rang, d.max))
    else
        l.valeur:SetText(string.format(L.rang, d.rang or 0, d.max))
    end
    l.nom:SetTextColor(plein and 0.6 or 1, plein and 0.6 or 0.82, plein and 0.6 or 0)
    if plein or d.rang == nil then
        l.coche:Hide()
    else
        l.coche:Show()
        l.coche:SetChecked(sel and 1 or nil)
    end
    S.anim = true
end

function H.RendreCout()
    local ui = S.ui
    local total = H.CoutSelection()
    local suffisant = H.Suffisant(total)
    -- Or, honneur, arène
    if total.n == 0 then
        ui.cout.argent:SetText("")
    elseif total.c == 0 and total.h == 0 and total.a == 0 and next(total.o) == nil then
        ui.cout.argent:SetText("|cff20c020" .. L.gratuit .. "|r")
    else
        local t = {}
        if total.c > 0 then
            local s = H.Argent(total.c)
            if GetMoney() < total.c then
                s = "|cffff4040" .. s .. "|r  |cffff4040(" .. string.format(L.manquant, H.Argent(total.c - GetMoney())) .. ")|r"
            end
            table.insert(t, s)
        end
        if total.h > 0 then table.insert(t, string.format(L.honneur, total.h)) end
        if total.a > 0 then table.insert(t, string.format(L.arene, total.a)) end
        ui.cout.argent:SetText(table.concat(t, "   "))
    end
    -- Jetons
    local i = 0
    for id, n in pairs(total.o) do
        i = i + 1
        local j = S.jetons[i]
        if not j then
            j = H.CadreIcone(ui.cout, RC.ICONE_JETON)
            j.compte = j:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            j.compte:SetPoint("BOTTOMRIGHT", 2, -2)
            j:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetHyperlink("item:" .. self.id)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(string.format(L.requis, self.n), 1, 0.82, 0)
                GameTooltip:AddLine(string.format(L.possede, GetItemCount(self.id) or 0), 1, 1, 1)
                if (GetItemCount(self.id) or 0) < self.n then
                    GameTooltip:AddLine(string.format(L.manque, self.n - (GetItemCount(self.id) or 0)), 1, 0.3, 0.3)
                end
                GameTooltip:Show()
            end)
            j:SetScript("OnLeave", function() GameTooltip:Hide() end)
            S.jetons[i] = j
        end
        j.id, j.n = id, n
        j:ClearAllPoints()
        j:SetPoint("RIGHT", ui.cout, "RIGHT", -16 - (i - 1) * (RC.ICONE_JETON + 18), -4)
        local texture = (GetItemIcon and GetItemIcon(id)) or select(10, GetItemInfo(id)) or RC.ICONE_DEFAUT
        j.icone:SetTexture(texture)
        local possede = GetItemCount(id) or 0
        j.compte:SetText(tostring(n))
        if possede < n then
            j.compte:SetTextColor(1, 0.3, 0.3)
            j.icone:SetVertexColor(1, 0.55, 0.55)
        else
            j.compte:SetTextColor(1, 1, 1)
            j.icone:SetVertexColor(1, 1, 1)
        end
        j:Show()
    end
    for k = i + 1, #S.jetons do S.jetons[k]:Hide() end

    local actif = S.etat and S.etat.actif ~= false
    H.Actif(ui.ameliorer, actif and total.n > 0 and suffisant)
    H.Actif(ui.annuler, total.n > 0)
    local selectionnable = false
    for _, d in ipairs(S.donnees) do
        if d.rang and d.rang < d.max then selectionnable = true end
    end
    H.Actif(ui.tout, actif and selectionnable)
end

function H.Rendre()
    local ui = S.ui
    if not ui then return end
    H.RendreCarte()
    H.RendreEquipement()
    ui.avertissement:SetText((S.etat and S.etat.actif == false) and L.inactif or "")

    local n = #S.donnees
    for i, l in ipairs(S.lignes) do
        local d = S.donnees[i]
        if d then
            H.RendreLigne(l, d)
            l:Show()
        else
            l:Hide()
        end
    end
    for i = #S.lignes + 1, n do
        local l = H.Ligne(ui, i)
        S.lignes[i] = l
        H.RendreLigne(l, S.donnees[i])
        l:Show()
    end
    if n == 0 then
        if S.objet and S.objet.absent then
            ui.message:SetText(L.invalide)
        elseif S.objet and S.stats then
            ui.message:SetText(L.aucune)
        elseif S.lien then
            ui.message:SetText(L.chargement)
        else
            ui.message:SetText("")
        end
        ui.message:Show()
    else
        ui.message:Hide()
    end
    H.RendreCout()

    -- Hauteur de la fenêtre selon le nombre de lignes (au moins une bande).
    local lignesH = math.max(1, n) * RC.LIGNE_H
    ui:SetHeight(RC.INSET_H + RC.CARTE_H + RC.ECART + RC.EQUIP_H + RC.ECART + lignesH
                 + RC.ECART + RC.COUT_H + RC.ECART + RC.PIED_H + RC.INSET_B)
end

-- ---------------------------------------------------------------------------
-- Actions
-- ---------------------------------------------------------------------------
function H.Selectionner(lien)
    local id = H.Id(lien)
    if not id then return end
    S.lien, S.entry = lien, id
    S.objet, S.stats, S.selection, S.donnees, S.reussites = nil, nil, {}, {}, 0
    H.Rendre()
    AIO.Handle("ItemUpgrade", "Selectionner", id)
end

function H.Retirer()
    S.lien, S.entry, S.objet, S.stats, S.selection, S.donnees = nil, nil, nil, nil, {}, {}
    H.Rendre()
end

function H.Basculer(typ)
    local d = H.Donnee(typ)
    if not d or not d.rang or d.rang >= d.max then return end
    if S.selection[typ] then S.selection[typ] = nil else S.selection[typ] = true end
    H.Rendre()
end

function H.Tout()
    for _, d in ipairs(S.donnees) do
        if d.rang and d.rang < d.max then S.selection[d.type] = true end
    end
    H.Rendre()
end

function H.Annuler()
    S.selection = {}
    H.Rendre()
end

function H.Ameliorer()
    if not S.entry then return end
    local types = {}
    for _, d in ipairs(S.donnees) do
        if S.selection[d.type] and d.rang and d.rang < d.max then
            table.insert(types, d.type)
        end
    end
    if #types == 0 then return end
    S.reussites = 0
    AIO.Handle("ItemUpgrade", "Ameliorer", S.entry, types)
end

function H.Deposer()
    local genre, _, lien = GetCursorInfo()
    if genre == "item" and lien then
        ClearCursor()
        H.Selectionner(lien)
        return true
    end
    return false
end

function H.Ouvrir()
    if not S.ui then H.Construire() end
    if S.ui:IsShown() then return end
    S.ui:Show()
    H.Ouverture()
    AIO.Handle("ItemUpgrade", "Ouvrir")
end

function H.BasculerFenetre()
    if S.ui and S.ui:IsShown() then S.ui:Hide() else H.Ouvrir() end
end

-- ---------------------------------------------------------------------------
-- Construction
-- ---------------------------------------------------------------------------
function H.Carte(parent)
    local c = CreateFrame("Frame", nil, parent)
    c:SetHeight(RC.CARTE_H)
    H.Fond(c, RC.FOND_CARTE, true)

    -- Emplacement de dépôt : cadre de raccourci, accepte le glisser-déposer.
    local slot = H.CadreIcone(c, RC.ICONE_OBJET)
    slot:SetPoint("TOPLEFT", 14, -14)
    slot.vide = slot:CreateTexture(nil, "BACKGROUND")
    slot.vide:SetTexture(RC.EMPLACEMENT_VIDE)
    slot.vide:SetPoint("TOPLEFT", -10, 10); slot.vide:SetPoint("BOTTOMRIGHT", 10, -10)
    slot:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    slot:RegisterForDrag("LeftButton")
    slot:SetScript("OnReceiveDrag", function() H.Deposer() end)
    slot:SetScript("OnClick", function(_, bouton)
        if not H.Deposer() and S.lien then H.Retirer() end
    end)
    slot:SetScript("OnEnter", function(self)
        if S.lien then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(S.lien)
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.retirer, 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    slot:SetScript("OnLeave", function() GameTooltip:Hide() end)
    c.slot = slot

    c.nom = c:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    c.nom:SetPoint("TOPLEFT", slot, "TOPRIGHT", 14, -2)
    c.nom:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    c.nom:SetJustifyH("LEFT")
    c.sous = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.sous:SetPoint("TOPLEFT", c.nom, "BOTTOMLEFT", 0, -4)
    c.sous:SetPoint("RIGHT", c, "RIGHT", -14, 0)
    c.sous:SetJustifyH("LEFT")
    c.sous:SetTextColor(unpack(RC.GRIS))

    -- Toute la carte accepte le dépôt d'un objet.
    c:EnableMouse(true)
    c:SetScript("OnReceiveDrag", function() H.Deposer() end)
    c:SetScript("OnMouseUp", function() H.Deposer() end)
    return c
end

function H.Equipement(parent)
    local e = CreateFrame("Frame", nil, parent)
    e:SetHeight(RC.EQUIP_H)
    local libelle = e:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    libelle:SetPoint("LEFT", 6, 0)
    libelle:SetText(L.equipement)
    local largeurLibelle = 74
    local pas = (RC.LARGEUR - RC.INSET_G - RC.INSET_D - largeurLibelle - 8) / #RC.EQUIP
    for i, slotId in ipairs(RC.EQUIP) do
        local b = H.CadreIcone(e, RC.ICONE_EQUIP)
        b.slot = slotId
        b:SetPoint("LEFT", e, "LEFT", largeurLibelle + (i - 1) * pas + (pas - RC.ICONE_EQUIP) / 2, 0)
        b.choisi = b:CreateTexture(nil, "OVERLAY")
        b.choisi:SetTexture(RC.COCHE_TEX)
        b.choisi:SetWidth(16); b.choisi:SetHeight(16)
        b.choisi:SetPoint("BOTTOMRIGHT", 4, -4)
        b.choisi:Hide()
        b:SetScript("OnClick", function(self)
            if self.lien then H.Selectionner(self.lien) end
        end)
        b:SetScript("OnEnter", function(self)
            if self.lien then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetInventoryItem("player", self.slot)
                GameTooltip:Show()
            end
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        table.insert(S.equip, b)
    end
    return e
end

function H.Ligne(parent, index)
    local l = CreateFrame("Button", nil, parent)
    l:SetHeight(RC.LIGNE_H)
    l:SetPoint("TOPLEFT", parent, "TOPLEFT", RC.INSET_G,
        -(RC.INSET_H + RC.CARTE_H + RC.ECART + RC.EQUIP_H + RC.ECART + (index - 1) * RC.LIGNE_H))
    l:SetPoint("RIGHT", parent, "RIGHT", -RC.INSET_D, 0)
    l.actuel, l.cible, l.attente = 0, 0, 0
    if index % 2 == 0 then
        local bande = l:CreateTexture(nil, "BACKGROUND")
        bande:SetTexture(RC.BLANC); bande:SetAllPoints()
        bande:SetVertexColor(0, 0, 0, 0.22)
    end

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
    l.detail = l:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    l.detail:SetPoint("TOPLEFT", l.nom, "BOTTOMLEFT", 0, -1)
    l.detail:SetWidth(RC.NOM_W); l.detail:SetJustifyH("LEFT")

    -- Case à cocher à droite, barre entre le nom et la case.
    l.coche = CreateFrame("CheckButton", nil, l, "UICheckButtonTemplate")
    l.coche:SetWidth(RC.COCHE); l.coche:SetHeight(RC.COCHE)
    l.coche:SetPoint("RIGHT", -8, 0)
    l.coche:SetScript("OnClick", function() if l.donnee then H.Basculer(l.donnee.type) end end)

    local fondBarre = CreateFrame("Frame", nil, l)
    fondBarre:SetHeight(RC.BARRE_H)
    fondBarre:SetPoint("LEFT", l.nom, "RIGHT", 12, -6)
    fondBarre:SetPoint("RIGHT", l.coche, "LEFT", -14, 0)
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

    l:SetScript("OnClick", function() if l.donnee then H.Basculer(l.donnee.type) end end)
    l:SetScript("OnEnter", function(self)
        local d = self.donnee
        if not d then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(H.Nom(d.type), 1, 0.82, 0)
        local base = d.baseC or d.base
        if d.rang and d.rang < d.max then
            local b = S.objet and S.objet.bareme[d.type]
            local pct = b and b.pct[d.rang + 1] or 0
            local actuel = H.Valeur(base, d.type, d.rang)
            local suivant = d.suivant or H.Valeur(base, d.type, d.rang + 1)
            GameTooltip:AddLine(string.format(L.suivant, actuel, suivant, suivant - actuel), 1, 1, 1)
            GameTooltip:AddLine(string.format(L.prochain, d.rang + 1, pct), 1, 1, 1)
            local c = b and b.couts[d.rang + 1]
            if c then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(L.coutRang, 1, 0.82, 0)
                if c.c and c.c > 0 then GameTooltip:AddLine(H.Argent(c.c), 1, 1, 1) end
                if c.h and c.h > 0 then GameTooltip:AddLine(string.format(L.honneur, c.h), 1, 1, 1) end
                if c.a and c.a > 0 then GameTooltip:AddLine(string.format(L.arene, c.a), 1, 1, 1) end
                for _, o in ipairs(c.o or {}) do
                    local nomObjet = GetItemInfo(o[1]) or ("#" .. o[1])
                    local ok = (GetItemCount(o[1]) or 0) >= o[2]
                    GameTooltip:AddLine(o[2] .. " × " .. nomObjet, ok and 1 or 1, ok and 1 or 0.3, ok and 1 or 0.3)
                end
            end
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(L.aideLigne, 0.7, 0.7, 0.7)
        elseif d.rang then
            GameTooltip:AddLine(string.format(L.actuel, H.Valeur(base, d.type, d.rang)) .. "  ·  " .. L.rangMax, 1, 1, 1)
        end
        GameTooltip:Show()
    end)
    l:SetScript("OnLeave", function() GameTooltip:Hide() end)
    l:Hide()
    return l
end

function H.Construire()
    local f = CreateFrame("Frame", "PapotaAmeliorationFrame", UIParent)
    f:SetWidth(RC.LARGEUR); f:SetHeight(400)
    f:SetPoint("CENTER")
    f:SetMovable(true); f:EnableMouse(true); f:SetToplevel(true)
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() f:StartMoving() end)
    f:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    f:Hide()
    table.insert(UISpecialFrames, "PapotaAmeliorationFrame")
    S.ui = f
    H.CadreDialogue(f, L.titre)

    -- Carte de l'objet.
    f.carte = H.Carte(f)
    f.carte:SetPoint("TOPLEFT", RC.INSET_G, -RC.INSET_H)
    f.carte:SetPoint("TOPRIGHT", -RC.INSET_D, -RC.INSET_H)

    -- Bande d'équipement.
    f.equipement = H.Equipement(f)
    f.equipement:SetPoint("TOPLEFT", f.carte, "BOTTOMLEFT", 0, -RC.ECART)
    f.equipement:SetPoint("TOPRIGHT", f.carte, "BOTTOMRIGHT", 0, -RC.ECART)
    local filet = f:CreateTexture(nil, "ARTWORK")
    filet:SetTexture(RC.BLANC); filet:SetHeight(1)
    filet:SetPoint("TOPLEFT", f.equipement, "BOTTOMLEFT", 0, 0)
    filet:SetPoint("TOPRIGHT", f.equipement, "BOTTOMRIGHT", 0, 0)
    filet:SetVertexColor(0.5, 0.5, 0.55, 0.5)

    -- Message quand il n'y a pas de ligne (aucun objet, objet invalide…).
    f.message = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.message:SetPoint("TOP", f.equipement, "BOTTOM", 0, -(RC.ECART + RC.LIGNE_H / 2 - 6))
    f.message:SetTextColor(unpack(RC.GRIS))

    -- Pied : tout sélectionner à gauche, annuler / améliorer à droite.
    local pied = CreateFrame("Frame", nil, f)
    pied:SetPoint("BOTTOMLEFT", RC.INSET_G, RC.INSET_B)
    pied:SetPoint("BOTTOMRIGHT", -RC.INSET_D, RC.INSET_B)
    pied:SetHeight(RC.PIED_H)
    local filet2 = pied:CreateTexture(nil, "ARTWORK")
    filet2:SetTexture(RC.BLANC); filet2:SetHeight(1)
    filet2:SetPoint("TOPLEFT"); filet2:SetPoint("TOPRIGHT")
    filet2:SetVertexColor(0.5, 0.5, 0.55, 0.5)
    f.tout = H.Bouton(pied, L.tout, 170, 24)
    f.tout:SetPoint("LEFT", 4, 0)
    f.tout:SetScript("OnClick", H.Tout)
    f.ameliorer = H.Bouton(pied, L.ameliorer, 110, 24)
    f.ameliorer:SetPoint("RIGHT", -4, 0)
    f.ameliorer:SetScript("OnClick", H.Ameliorer)
    f.annuler = H.Bouton(pied, L.annuler, 90, 24)
    f.annuler:SetPoint("RIGHT", f.ameliorer, "LEFT", -6, 0)
    f.annuler:SetScript("OnClick", H.Annuler)
    f.avertissement = pied:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.avertissement:SetPoint("LEFT", f.tout, "RIGHT", 12, 0)
    f.avertissement:SetTextColor(unpack(RC.ROUGE))

    -- Carte du coût, juste au-dessus du pied.
    f.cout = CreateFrame("Frame", nil, f)
    f.cout:SetHeight(RC.COUT_H)
    f.cout:SetPoint("BOTTOMLEFT", pied, "TOPLEFT", 0, RC.ECART)
    f.cout:SetPoint("BOTTOMRIGHT", pied, "TOPRIGHT", 0, RC.ECART)
    H.Fond(f.cout, RC.FOND_CARTE, true)
    local titreCout = f.cout:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titreCout:SetPoint("TOPLEFT", 14, -12)
    titreCout:SetText(L.cout)
    titreCout:SetTextColor(unpack(RC.OR))
    f.cout.argent = f.cout:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.cout.argent:SetPoint("TOPLEFT", titreCout, "BOTTOMLEFT", 0, -8)
    f.cout.argent:SetJustifyH("LEFT")

    f:SetScript("OnHide", function()
        S.selection = {}
        GameTooltip:Hide()
    end)
    f:SetScript("OnUpdate", function(_, elapsed)
        if S.anim then H.Amortir(elapsed) end
    end)
    f:RegisterEvent("BAG_UPDATE")
    f:RegisterEvent("PLAYER_MONEY")
    f:RegisterEvent("UNIT_INVENTORY_CHANGED")
    f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
    f:SetScript("OnEvent", function()
        if f:IsShown() then H.Rendre() end
    end)
    H.Rendre()
end

-- ---------------------------------------------------------------------------
-- Ce que le serveur nous dit (AIO)
-- ---------------------------------------------------------------------------
function Handlers.Etat(player, etat)
    if type(etat) ~= "table" then return end
    S.etat = etat
    if type(etat.jetons) == "table" and #etat.jetons > 0 then RC.JETONS = etat.jetons end
    if S.ui then H.Rendre() end
end

function Handlers.Objet(player, objet)
    if type(objet) ~= "table" or not S.ui then return end
    if objet.entry ~= S.entry then return end       -- réponse à une sélection abandonnée
    S.objet = objet
    if objet.actif == false and S.etat then S.etat.actif = false end
    H.Fusionner()
    H.Rendre()
end

-- ---------------------------------------------------------------------------
-- Ce que le module C++ nous dit (messages d'addon ITEMUPGRADE_RESP)
-- ---------------------------------------------------------------------------
function H.Message(msg)
    local mot, reste = msg:match("^(%S+)%s*(.*)$")
    if mot == "STATS" then
        if not S.entry then return end
        local nombres = {}
        for n in reste:gmatch("[^,%s]+") do table.insert(nombres, tonumber(n)) end
        local stats = {}
        for i = 1, #nombres - 4, 5 do
            stats[nombres[i]] = { base = nombres[i + 1], suivant = nombres[i + 2],
                                  rang = nombres[i + 3], rangSuivant = nombres[i + 4] }
        end
        S.stats = stats
        S.selection = {}
        H.Fusionner()
        H.Rendre()
        if S.reussites > 0 then
            H.Flottant(string.format(L.reussi, S.reussites))
            S.reussites = 0
        end
    elseif mot == "UPGRADE" then
        S.reussites = S.reussites + 1
    end
    -- « VALIDATE » et « COST » : non utilisés, la sélection et le coût passent par AIO.
end

local ecoute = CreateFrame("Frame")
ecoute:RegisterEvent("CHAT_MSG_ADDON")
ecoute:SetScript("OnEvent", function(_, _, prefixe, message, canal, expediteur)
    if prefixe == RC.PREFIXE and expediteur == UnitName("player") then
        H.Message(message or "")
    end
end)

-- ---------------------------------------------------------------------------
-- Bouton de minimap (même composition que celui d'Attriboost)
-- ---------------------------------------------------------------------------
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
    local existant = _G["PapotaAmeliorationMiniButton"]
    if existant then
        S.mm = existant
        H.BrancherBoutonMinimap(existant)
        return
    end
    local b = CreateFrame("Button", "PapotaAmeliorationMiniButton", Minimap)
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
        H.BasculerFenetre()
    end)
end

H.CreerBoutonMinimap()

-- ---------------------------------------------------------------------------
-- Ouverture : commandes, clic droit sur un jeton de puissance
-- ---------------------------------------------------------------------------
SLASH_PAPOTA_AMELIORATION1 = "/amelioration"
SLASH_PAPOTA_AMELIORATION2 = "/ameliorer"
SLASH_PAPOTA_AMELIORATION3 = "/iu"
SlashCmdList["PAPOTA_AMELIORATION"] = function() H.BasculerFenetre() end

hooksecurefunc("UseContainerItem", function(bag, slot)
    local lien = GetContainerItemLink(bag, slot)
    local id = H.Id(lien)
    if not id then return end
    for _, jeton in ipairs(RC.JETONS) do
        if id == jeton then
            H.Ouvrir()
            return
        end
    end
end)
