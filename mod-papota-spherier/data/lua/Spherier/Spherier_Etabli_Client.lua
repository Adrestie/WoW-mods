--[[----------------------------------------------------------------------------
    Sphèrier Papota — l'établi, côté client (expédié par AIO)

    UNE fenêtre, TROIS emplacements. On y pose ce qu'on veut : c'est l'établi
    qui reconnaît la recette, montre le résultat attendu et allume le bouton.

      3 pierres identiques        -> la même pierre, qualité au-dessus
      2 pierres de même qualité   -> une autre pierre, même qualité
      3 runes, quelles qu'elles soient -> une rune au hasard

    Le résultat d'une fusion est connu d'avance : son icône est la vraie. Les
    deux autres tirent au sort, mais l'icône reste honnête — toutes les pierres
    d'une même qualité partagent leur apparence, si bien que montrer « une
    pierre de cette qualité » ne promet rien de faux ; seule la statistique est
    inconnue, et l'infobulle le dit.

    Ouverture : l'objet de monde « Établi du sphèrier ».
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- côté serveur : on s'arrête ici
end

local SpherierEtabliHandlers = AIO.AddHandlers("SpherierEtabli", {})

local max, min = math.max, math.min
local fmt = string.format
local FR = GetLocale() == "frFR"

local L = {
    titre     = FR and "Établi du sphèrier" or "Sphere Grid Workbench",
    faire     = FR and "Fabriquer" or "Craft",
    vide      = FR and "Vide" or "Empty",
    choisir   = FR and "Clic gauche : choisir un objet" or "Left-click: choose an item",
    retirer   = FR and "Clic droit : retirer" or "Right-click: remove",
    liste     = FR and "Choisir un objet" or "Choose an item",
    rien      = FR and "Aucun objet dans vos sacs ne convient"
                    or "No item in your bags is suitable",
    aide      = FR and "Trois pierres identiques, deux pierres de même qualité, ou trois runes."
                    or "Three identical stones, two stones of the same quality, or three runes.",
    r_fusion  = FR and "Fusion : la même pierre, une qualité au-dessus."
                    or "Merging: the same stone, one quality above.",
    r_relance = FR and "Relance : une autre pierre, de même qualité."
                    or "Reroll: another stone, of the same quality.",
    r_refonte = FR and "Refonte : une rune tirée au hasard dans tout le catalogue."
                    or "Recasting: one rune drawn at random from the whole catalogue.",
    p_titre   = FR and "Résultat" or "Result",
    p_hasard  = FR and "Statistique tirée au hasard." or "Statistic drawn at random.",
    p_rune    = FR and "Rune tirée au hasard." or "Rune drawn at random.",
    pierre    = FR and "Pierre" or "Stone",
    aide_titre = FR and "Les recettes de l'établi" or "Workbench recipes",
    aide_1    = FR and "3 pierres identiques → la même pierre, une qualité au-dessus."
                    or "3 identical stones → the same stone, one quality above.",
    aide_2    = FR and "2 pierres de même qualité → une autre pierre, même qualité."
                    or "2 stones of the same quality → another stone, same quality.",
    aide_3    = FR and "3 runes, quelles qu'elles soient → une rune au hasard."
                    or "3 runes, any of them → one rune at random.",
    aide_note = FR and "Une pierre légendaire ne fusionne pas : il n'y a rien au-dessus."
                    or "A legendary stone cannot be merged: there is nothing above.",
    rune      = FR and "Rune" or "Rune",
}

local STAT_LABELS = {
    endurance = FR and "Endurance" or "Stamina",
    intelligence = FR and "Intelligence" or "Intellect",
    esprit = FR and "Esprit" or "Spirit",
    dexterite = FR and "Dextérité" or "Agility",
    force = FR and "Force" or "Strength",
    parade = FR and "Parade" or "Parry",
    blocage = FR and "Blocage" or "Block",
    esquive = FR and "Esquive" or "Dodge",
    hate = FR and "Hâte" or "Haste",
    critique = FR and "Critique" or "Critical strike",
    touche = FR and "Touché" or "Hit",
    puissance_sorts = FR and "Puissance des sorts" or "Spell power",
    puissance_attaque = FR and "Puissance d'attaque" or "Attack power",
    penetration_armure = FR and "Pénétration d'armure" or "Armor penetration",
    expertise = FR and "Expertise" or "Expertise",
    bonus_soins = FR and "Bonus des soins" or "Healing bonus",
}

-- Constantes de rendu dans UNE table : le client est en Lua 5.1, borné à
-- soixante upvalues par fonction, et chaque local nu en consomme un.
local EC = {
    W = 344, H = 196,
    SLOT = 42, RESULT = 46,
    BAGS = { 0, 1, 2, 3, 4 },
    PICK_W = 250, PICK_ROWS = 9, PICK_ROW_H = 22, PICK_ICON = 18,
    PICK_MIN = 190, PICK_MAX = 460, PICK_MARGE = 46,
    FLECHE = "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up",
    INCONNU = "Interface\\Icons\\INV_Misc_QuestionMark",
    -- Le « i » du plugin Paragon, relevé dans FrameXML\\Paragon\\UIParagon.xml :
    -- une texture standard du client, pas une ressource à empaqueter.
    AIDE = "Interface\\Common\\help-i",
    BORDURE = "Interface\\Tooltips\\UI-Tooltip-Border",
    BORD_VIDE = { 0.35, 0.35, 0.35 },
    -- Un aplat opaque sur toute la fenêtre : rien ne doit se lire au travers.
    FOND = { 0.06, 0.055, 0.05 },
    -- Une rune, sans plus de précision : la refonte peut rendre n'importe
    -- laquelle des deux sortes, aucune icône particulière ne conviendrait.
    RUNE_QUELCONQUE = "Interface\\Icons\\INV_Misc_Rune_06",
}

local CAT = { pierres = {}, runes = {}, runesStat = {} }
local UI = nil

-- ---------------------------------------------------------------------------
-- Sacs et catalogue
-- ---------------------------------------------------------------------------

local function ParcourirSacs(filtre, action)
    for _, sac in ipairs(EC.BAGS) do
        for emp = 1, (GetContainerNumSlots(sac) or 0) do
            local entree = GetContainerItemID and GetContainerItemID(sac, emp)
            if not entree then
                local lien = GetContainerItemLink(sac, emp)
                entree = lien and tonumber(lien:match("item:(%d+)"))
            end
            if entree and filtre(entree) then
                local _, nb = GetContainerItemInfo(sac, emp)
                action(entree, nb or 1)
            end
        end
    end
end

local function CompterEnSac(entree)
    local total = 0
    ParcourirSacs(function(e) return e == entree end,
                  function(_, nb) total = total + nb end)
    return total
end

local function EstPierre(entree) return entree and CAT.pierres[entree] end
local function EstRune(entree)
    return entree and (CAT.runes[entree] or CAT.runesStat[entree])
end
local function DuSpherier(entree) return EstPierre(entree) or EstRune(entree) end

-- Ce qu'un emplacement peut ENCORE accueillir. Dès qu'un composant est posé,
-- il ferme les possibilités : une pierre rare n'appelle que des pierres rares
-- — la fusion en veut trois fois la même, la relance deux de la même qualité,
-- les deux exigent donc la même qualité — et une rune n'appelle que des runes.
-- L'emplacement qu'on remplit ne se contraint pas lui-même : rouvrir sa liste
-- doit permettre d'en changer, et de repartir sur autre chose si c'est le seul
-- posé.
local function Compatible(entree, sauf)
    local montant, rune = nil, false
    for i = 1, 3 do
        local pose = (i ~= sauf) and UI.choix[i] or nil
        if pose then
            local p = EstPierre(pose)
            if p then montant = p.montant else rune = true end
        end
    end
    if montant then
        local p = EstPierre(entree)
        return p ~= nil and p.montant == montant
    end
    if rune then
        return EstRune(entree) ~= nil
    end
    return DuSpherier(entree) ~= nil
end

-- Combien il reste de cette entrée une fois retiré ce que les emplacements en
-- ont déjà pris : sans quoi on proposerait deux fois la dernière du sac.
local function Disponible(entree, sauf)
    local reste = CompterEnSac(entree)
    for i = 1, 3 do
        if i ~= sauf and UI.choix[i] == entree then reste = reste - 1 end
    end
    return reste
end


local function NomObjet(entree)
    local nom = GetItemInfo(entree)
    if nom then return nom end
    local p = CAT.pierres[entree]
    if p then return fmt("%s (%s +%d)", L.pierre, STAT_LABELS[p.stat] or "?", p.montant or 0) end
    local r = CAT.runesStat[entree]
    if r then return fmt("%s (%s +%d%%)", L.rune, STAT_LABELS[r.stat] or "?", r.pct or 0) end
    r = CAT.runes[entree]
    if r then return fmt("%s (%s)", L.rune, GetSpellInfo(r.sort or 0) or "?") end
    return tostring(entree)
end

-- La qualité vient du catalogue, que le serveur lit dans item_template ;
-- `GetItemInfo` ne sert que de repli, un objet jamais vu du client n'y étant
-- pas encore connu — c'est justement le cas du résultat d'une fusion.
local function QualiteObjet(entree)
    local d = entree and (CAT.pierres[entree] or CAT.runes[entree] or CAT.runesStat[entree])
    if d and d.qualite then return d.qualite end
    local _, _, q = GetItemInfo(entree or 0)
    return q
end

-- La couleur d'une qualité se lit dans la table du client : la recopier à la
-- main la ferait mentir le jour où le jeu en change une.
local function TeindreCadre(cadre, qualite)
    local c = qualite and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[qualite]
    if c then
        cadre:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    else
        cadre:SetBackdropBorderColor(EC.BORD_VIDE[1], EC.BORD_VIDE[2], EC.BORD_VIDE[3], 1)
    end
end

-- Toutes les runes partagent aujourd'hui la même qualité ; tant que c'est vrai,
-- la refonte peut annoncer la couleur de ce qu'elle rendra. Si elles venaient à
-- se diversifier, on ne promet plus rien.
local function QualiteDesRunes()
    local vue = nil
    for _, r in pairs(CAT.runes) do
        if vue and r.qualite ~= vue then return nil end
        vue = r.qualite
    end
    for _, r in pairs(CAT.runesStat) do
        if vue and r.qualite ~= vue then return nil end
        vue = r.qualite
    end
    return vue
end

local function IconeObjet(entree)
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(entree)
    return texture or EC.INCONNU
end

-- ---------------------------------------------------------------------------
-- La recette se déduit de ce qui est posé
-- ---------------------------------------------------------------------------

-- La pierre de la même statistique dont le montant est le plus petit au-dessus :
-- c'est ainsi que le module lit « qualité supérieure », sans jamais toucher à un
-- identifiant. Toutes les pierres d'une qualité portant le même montant, la
-- comparaison de qualité se fait de la même façon.
local function PierreAuDessus(p)
    local meilleure, montant = nil, nil
    for entree, autre in pairs(CAT.pierres) do
        if autre.stat == p.stat and autre.montant > p.montant
           and (not montant or autre.montant < montant) then
            meilleure, montant = entree, autre.montant
        end
    end
    return meilleure
end

local function PierreDeQualite(montant)
    for entree, autre in pairs(CAT.pierres) do
        if autre.montant == montant then return entree end
    end
end

-- Rend : la clé de recette, les entrées à envoyer, l'icône du résultat, son
-- libellé, et la ligne d'explication. Rien de tout cela n'engage le module, qui
-- revérifie tout — on évite seulement un geste voué au refus.
local function Detecter()
    local poses = {}
    for i = 1, 3 do
        if UI.choix[i] then poses[#poses + 1] = UI.choix[i] end
    end

    if #poses == 3 and EstPierre(poses[1])
       and poses[1] == poses[2] and poses[2] == poses[3] then
        local produit = PierreAuDessus(CAT.pierres[poses[1]])
        if produit then
            return "fusion", poses, IconeObjet(produit), NomObjet(produit),
                   L.r_fusion, QualiteObjet(produit)
        end
        return nil, poses, nil, nil, L.aide
    end

    if #poses == 2 then
        local a, b = EstPierre(poses[1]), EstPierre(poses[2])
        if a and b and a.montant == b.montant then
            local temoin = PierreDeQualite(a.montant)
            return "relance", poses, temoin and IconeObjet(temoin) or EC.INCONNU,
                   L.p_hasard, L.r_relance, QualiteObjet(temoin)
        end
    end

    if #poses == 3 and EstRune(poses[1]) and EstRune(poses[2]) and EstRune(poses[3]) then
        return "refonte", poses, EC.RUNE_QUELCONQUE, L.p_rune, L.r_refonte,
               QualiteDesRunes()
    end

    return nil, poses, nil, nil, L.aide
end

-- ---------------------------------------------------------------------------
-- Sélecteur
-- ---------------------------------------------------------------------------

local function FermerChoix()
    if UI and UI.pick then UI.pick:Hide() end
end

local function RemplirChoix()
    local cadre = UI.pick
    local vus, liste = {}, {}
    ParcourirSacs(function(e) return Compatible(e, cadre.case) end, function(e)
        if not vus[e] and Disponible(e, cadre.case) > 0 then
            vus[e] = true
            liste[#liste + 1] = e
        end
    end)
    table.sort(liste)
    cadre.liste = liste

    -- La largeur suit le texte le plus long, mesuré sur TOUTES les entrées et
    -- non sur les seules visibles : une entrée en bas de défilement serait
    -- sinon tronquée.
    local plus = 0
    for _, entree in ipairs(liste) do
        cadre.metre:SetText(fmt("%s  x%d", NomObjet(entree), Disponible(entree, cadre.case)))
        plus = max(plus, cadre.metre:GetStringWidth() or 0)
    end
    cadre.metre:SetText(L.rien)
    plus = max(plus, cadre.metre:GetStringWidth() or 0)
    cadre:SetWidth(min(EC.PICK_MAX, max(EC.PICK_MIN, plus + EC.PICK_MARGE)))

    local maxi = max(0, #liste - EC.PICK_ROWS)
    if cadre.offset > maxi then cadre.offset = maxi end

    for i = 1, EC.PICK_ROWS do
        local ligne = cadre.lignes[i]
        local entree = liste[i + cadre.offset]
        if entree then
            ligne.icone:SetTexture(IconeObjet(entree))
            ligne.nom:SetText(fmt("%s  x%d", NomObjet(entree), Disponible(entree, cadre.case)))
            ligne.entree = entree
            ligne:Show()
        else
            ligne:Hide()
        end
    end
    cadre.vide:SetText(#liste == 0 and L.rien or "")
end

-- ---------------------------------------------------------------------------
-- Fenêtre
-- ---------------------------------------------------------------------------

local function MettreAJour()
    for i = 1, 3 do
        local case, entree = UI.cases[i], UI.choix[i]
        if entree then
            case.icone:SetTexture(IconeObjet(entree))
            case.icone:Show()
        else
            case.icone:Hide()
        end
        TeindreCadre(case, entree and QualiteObjet(entree) or nil)
    end

    local recette, _, icone, libelle, ligne, qualite = Detecter()
    UI.recette = recette
    UI.produitNom = libelle
    UI.explication:SetText(ligne)

    if recette then
        UI.resultat.icone:SetTexture(icone)
        UI.resultat.icone:Show()
        UI.resultat:Show()
        UI.fleche:SetAlpha(1)
        UI.bouton:Enable()
        TeindreCadre(UI.resultat, qualite)
    else
        UI.resultat.icone:Hide()
        UI.fleche:SetAlpha(0.3)
        UI.bouton:Disable()
        TeindreCadre(UI.resultat, nil)
    end
end

local function Fabriquer()
    local recette, poses = Detecter()
    if not recette then return end
    if recette == "fusion" then
        AIO.Handle("SpherierEtabli", "Fusion", poses[1])
    elseif recette == "relance" then
        AIO.Handle("SpherierEtabli", "Relance", poses[1], poses[2])
    else
        AIO.Handle("SpherierEtabli", "Refonte", poses[1], poses[2], poses[3])
    end
    -- Les sacs changent : on repart d'emplacements vides et on laisse le module
    -- répondre. La remise à jour suit l'événement du sac.
    for i = 1, 3 do UI.choix[i] = nil end
    FermerChoix()
    MettreAJour()
end

local function Construire()
    local f = CreateFrame("Frame", "SpherierEtabliFrame", UIParent)
    f:SetWidth(EC.W)
    f:SetHeight(EC.H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    -- Toute la fenêtre, bord à bord : le contour des boîtes de dialogue se
    -- dessine par-dessus, sa bordure vivant dans une couche supérieure.
    local fond = f:CreateTexture(nil, "BACKGROUND")
    fond:SetAllPoints()
    fond:SetTexture(EC.FOND[1], EC.FOND[2], EC.FOND[3], 1)

    local titre = f:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
    titre:SetPoint("TOP", 0, -16)
    titre:SetText(L.titre)

    local fermer = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    fermer:SetPoint("TOPRIGHT", -6, -6)
    fermer:SetScript("OnClick", function() FermerChoix() f:Hide() end)

    -- Le « i » du plugin Paragon : même texture, même sobriété — à demi effacé
    -- au repos, franc au survol.
    local aide = CreateFrame("Button", nil, f)
    aide:SetWidth(24)
    aide:SetHeight(24)
    aide:SetPoint("TOPLEFT", 12, -12)
    aide:SetAlpha(0.5)
    aide:SetNormalTexture(EC.AIDE)
    aide:SetHighlightTexture(EC.AIDE, "ADD")
    aide:SetScript("OnEnter", function(self)
        self:SetAlpha(1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.aide_titre, 1, 0.82, 0)
        GameTooltip:AddLine(L.aide_1, 1, 1, 1, true)
        GameTooltip:AddLine(L.aide_2, 1, 1, 1, true)
        GameTooltip:AddLine(L.aide_3, 1, 1, 1, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.aide_note, 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    aide:SetScript("OnLeave", function(self)
        self:SetAlpha(0.5)
        GameTooltip:Hide()
    end)

    UI = { cadre = f, cases = {}, choix = {} }

    -- Trois emplacements, puis la flèche, puis le résultat.
    for i = 1, 3 do
        local case = CreateFrame("Button", nil, f)
        case:SetWidth(EC.SLOT)
        case:SetHeight(EC.SLOT)
        case:SetPoint("TOPLEFT", 26 + (i - 1) * (EC.SLOT + 10), -74)
        case:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        -- Le cadre porte la couleur de qualité : l'icône est donc rentrée de
        -- trois points, sans quoi elle le recouvrirait.
        case:SetBackdrop({ edgeFile = EC.BORDURE, edgeSize = 12 })
        case:SetBackdropBorderColor(EC.BORD_VIDE[1], EC.BORD_VIDE[2], EC.BORD_VIDE[3], 1)

        local fond = case:CreateTexture(nil, "BACKGROUND")
        fond:SetPoint("TOPLEFT", 3, -3)
        fond:SetPoint("BOTTOMRIGHT", -3, 3)
        fond:SetTexture(0, 0, 0, 0.5)

        case.icone = case:CreateTexture(nil, "ARTWORK")
        case.icone:SetPoint("TOPLEFT", 3, -3)
        case.icone:SetPoint("BOTTOMRIGHT", -3, 3)
        case.icone:Hide()

        case:SetScript("OnClick", function(self, bouton)
            if bouton == "RightButton" then
                UI.choix[i] = nil
                FermerChoix()
                MettreAJour()
                return
            end
            local cadre = UI.pick
            cadre.case, cadre.offset = i, 0
            cadre:ClearAllPoints()
            cadre:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -6)
            RemplirChoix()
            cadre:Show()
        end)
        case:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(UI.choix[i] and NomObjet(UI.choix[i]) or L.vide, 1, 1, 1)
            GameTooltip:AddLine(UI.choix[i] and L.retirer or L.choisir, 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        case:SetScript("OnLeave", function() GameTooltip:Hide() end)
        UI.cases[i] = case
    end

    local fleche = f:CreateTexture(nil, "ARTWORK")
    fleche:SetWidth(28)
    fleche:SetHeight(28)
    fleche:SetPoint("TOPLEFT", 26 + 3 * (EC.SLOT + 10) + 4, -81)
    fleche:SetTexture(EC.FLECHE)
    fleche:SetAlpha(0.3)
    UI.fleche = fleche

    local resultat = CreateFrame("Button", nil, f)
    resultat:SetWidth(EC.RESULT)
    resultat:SetHeight(EC.RESULT)
    resultat:SetPoint("TOPLEFT", 26 + 3 * (EC.SLOT + 10) + 40, -72)
    resultat:SetBackdrop({ edgeFile = EC.BORDURE, edgeSize = 12 })
    resultat:SetBackdropBorderColor(EC.BORD_VIDE[1], EC.BORD_VIDE[2], EC.BORD_VIDE[3], 1)
    local rfond = resultat:CreateTexture(nil, "BACKGROUND")
    rfond:SetPoint("TOPLEFT", 3, -3)
    rfond:SetPoint("BOTTOMRIGHT", -3, 3)
    rfond:SetTexture(0, 0, 0, 0.5)
    resultat.icone = resultat:CreateTexture(nil, "ARTWORK")
    resultat.icone:SetPoint("TOPLEFT", 3, -3)
    resultat.icone:SetPoint("BOTTOMRIGHT", -3, 3)
    resultat.icone:Hide()
    resultat:SetScript("OnEnter", function(self)
        if not UI.recette then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L.p_titre, 1, 0.82, 0)
        GameTooltip:AddLine(UI.produitNom or "", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    resultat:SetScript("OnLeave", function() GameTooltip:Hide() end)
    UI.resultat = resultat

    -- Au-DESSUS des emplacements : on lit ce qu'on va faire avant de poser.
    UI.explication = f:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.explication:SetPoint("TOPLEFT", 22, -38)
    UI.explication:SetWidth(EC.W - 44)
    UI.explication:SetJustifyH("LEFT")
    UI.explication:SetText(L.aide)


    local bouton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    bouton:SetWidth(130)
    bouton:SetHeight(26)
    bouton:SetPoint("BOTTOM", 0, 22)
    bouton:SetText(L.faire)
    bouton:SetScript("OnClick", Fabriquer)
    bouton:Disable()
    UI.bouton = bouton

    -- Le sélecteur, partagé par les trois emplacements.
    local cadre = CreateFrame("Frame", "SpherierEtabliChoix", f)
    cadre:SetFrameStrata("FULLSCREEN_DIALOG")
    cadre:SetWidth(EC.PICK_W)
    cadre:SetHeight(EC.PICK_ROWS * EC.PICK_ROW_H + 34)
    cadre:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 24,
        insets = { left = 6, right = 6, top = 6, bottom = 6 },
    })
    -- Opaque : sans fond plein, la grille et le décor se lisaient au travers
    -- de la liste, qui devenait illisible.
    cadre:SetBackdropColor(0.06, 0.05, 0.04, 1)
    local plein = cadre:CreateTexture(nil, "BACKGROUND")
    plein:SetPoint("TOPLEFT", 6, -6)
    plein:SetPoint("BOTTOMRIGHT", -6, 6)
    plein:SetTexture(0.05, 0.04, 0.035, 1)

    cadre:EnableMouse(true)
    cadre:EnableMouseWheel(true)
    cadre:SetScript("OnMouseWheel", function(self, delta)
        local maxi = max(0, #(self.liste or {}) - EC.PICK_ROWS)
        self.offset = min(maxi, max(0, (self.offset or 0) - delta))
        RemplirChoix()
    end)
    cadre:Hide()

    local ct = cadre:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    ct:SetPoint("TOPLEFT", 12, -10)
    ct:SetText(L.liste)

    -- En rouge : c'est un refus, pas une indication.
    cadre.vide = cadre:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    cadre.vide:SetPoint("TOPLEFT", 12, -26)
    cadre.vide:SetTextColor(1, 0.3, 0.3)

    -- Le mètre : une chaîne de la même police, jamais affichée, sur laquelle on
    -- mesure chaque entrée avant de décider de la largeur.
    cadre.metre = cadre:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    cadre.metre:Hide()

    cadre.lignes = {}
    for i = 1, EC.PICK_ROWS do
        local ligne = CreateFrame("Button", nil, cadre)
        ligne:SetHeight(EC.PICK_ROW_H)
        ligne:SetPoint("TOPLEFT", 10, -26 - (i - 1) * EC.PICK_ROW_H)
        ligne:SetPoint("TOPRIGHT", -10, -26 - (i - 1) * EC.PICK_ROW_H)
        ligne:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

        ligne.icone = ligne:CreateTexture(nil, "ARTWORK")
        ligne.icone:SetWidth(EC.PICK_ICON)
        ligne.icone:SetHeight(EC.PICK_ICON)
        ligne.icone:SetPoint("LEFT")

        ligne.nom = ligne:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        ligne.nom:SetPoint("LEFT", EC.PICK_ICON + 6, 0)
        ligne.nom:SetJustifyH("LEFT")

        ligne:SetScript("OnClick", function(self)
            if not self.entree then return end
            UI.choix[cadre.case] = self.entree
            FermerChoix()
            MettreAJour()
        end)
        cadre.lignes[i] = ligne
    end
    cadre.offset = 0
    UI.pick = cadre
    -- Échap referme la liste d'abord, la fenêtre ensuite : le client n'en cache
    -- qu'une par appui, et la plus récemment inscrite passe la première.
    tinsert(UISpecialFrames, "SpherierEtabliChoix")

    -- Les sacs bougent à chaque fabrication : la fenêtre se remet d'aplomb
    -- d'elle-même plutôt que d'attendre un clic.
    local veille = CreateFrame("Frame", nil, f)
    veille:RegisterEvent("BAG_UPDATE")
    veille:SetScript("OnEvent", function()
        if f:IsShown() then
            MettreAJour()
            if cadre:IsShown() then RemplirChoix() end
        end
    end)

    tinsert(UISpecialFrames, "SpherierEtabliFrame")
    return f
end

-- ---------------------------------------------------------------------------
-- Handlers
-- ---------------------------------------------------------------------------

function SpherierEtabliHandlers.Catalogue(_, cat)
    CAT.pierres   = (cat and cat.pierres) or {}
    CAT.runes     = (cat and cat.runes) or {}
    CAT.runesStat = (cat and cat.runesStat) or {}
end

function SpherierEtabliHandlers.Afficher(_, cat)
    SpherierEtabliHandlers.Catalogue(nil, cat)
    local f = (UI and UI.cadre) or Construire()
    for i = 1, 3 do UI.choix[i] = nil end
    MettreAJour()
    f:Show()
end
