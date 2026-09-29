--[[----------------------------------------------------------------------------
    Amélioration d'objets (mod-item-upgrade) — interface joueur, côté client

    Expédiée au client par AIO (addon AIO_Client requis). Ouverture par
    /amelioration, /iu, le bouton de la minimap ou un clic droit sur un jeton de
    puissance. Même charte que la fenêtre Attriboost : boîte de dialogue 3.3.5,
    plaque de titre, cartes sombres, barres de progression au liseré des
    compétences, uniquement des textures de l'interface d'origine.

    La fenêtre ne décide de rien : le module C++ tient toutes les règles. Elle
    lui parle par le canal de commandes des addons du cœur (préfixe
    « AzerothCore ») : « .item_upgrade state » décrit l'objet choisi, ligne par
    ligne (statistiques, dégâts et vitesse de l'arme, coût du prochain rang) ;
    « .item_upgrade upgrade » achète le prochain rang des lignes cochées, toutes
    ou aucune. L'objet est désigné par sa place (sac et case, ou emplacement
    d'équipement) : le glisser-déposer ne la donnant pas, elle est notée quand
    l'objet est pris. Les cases cochées restent EN ATTENTE (barre claire)
    jusqu'à « Améliorer » ; le coût affiché additionne ceux reçus du module.

    AVEC ForeverUI (mod-forever-ui) SUR LE CLIENT : ni fenêtre grise ni
    bouton de minimap. Le module déclare un onglet de la fenêtre
    Progression, qu'ouvre le micro-bouton du même nom ; sa page reprend
    la page de fabrication des métiers de ForeverUI (voir
    « Page de la fenêtre Progression », plus bas). Le code de cette
    fenêtre est copié plus bas, identique à celui de Attriboost_Client.lua :
    le premier module chargé la crée, le suivant y ajoute son onglet.
    Sans ForeverUI, rien ne change. Commandes et jetons ouvrent l'une ou l'autre.

    Aucun texte ici : ils arrivent du serveur (handler Textes), dans la langue
    du client, depuis les tables `module_string` du cœur.

    Client Lua 5.1 : 60 upvalues par fonction — constantes dans RC, textes
    dans L, état dans S, fonctions dans H.
------------------------------------------------------------------------------]]
local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return                                  -- côté serveur : on s'arrête ici
end

local Handlers = AIO.AddHandlers("ItemUpgrade", {})

-- Textes : AUCUN ici. Leur seule source est la base (tables `module_string`
-- et `module_string_locale` du cœur, module 'mod-item-upgrade'), partagée avec
-- le module C++ ; le serveur les envoie avec ce code, dans la langue du client
-- du joueur (handler Textes, plus bas). ID donne le numéro de chaque texte de
-- la fenêtre ; `{}` y marque une valeur, remplie par Remplir. Les refus du
-- module (« #ERR n ») s'affichent par leur numéro, 1 à 9.
local ID = {
    invalide = 5,
    titre = 101, deposer = 102, aide = 103, retirer = 104, equipement = 105,
    niveau = 106, chargement = 107, aucune = 108, rangMax = 109, cout = 110,
    gratuit = 111, manquant = 112, requis = 113, possede = 114, manque = 115,
    honneur = 116, arene = 117, tout = 118, annuler = 119, ameliorer = 120,
    reussi = 121, mmAide = 122, aideLigne = 123, prochain = 124, coutRang = 125,
    degats = 126, vitesse = 127, emplacement = 128, refuse = 129, inactif = 130,
    sacs = 131, vide = 132, choisir = 133, progression = 134,
}
local NOM_STAT = 1000       -- texte 1000 + n : nom de la statistique n
local TEXTES = {}

local function Remplir(texte, ...)
    local valeurs, n = { ... }, 0
    return (texte:gsub("{}", function()
        n = n + 1
        return tostring(valeurs[n])
    end))
end

-- L.cle rend le texte de la clé ; L.noms[type] le nom d'une statistique.
local L = setmetatable({
    noms = setmetatable({}, { __index = function(_, typ) return TEXTES[NOM_STAT + typ] end }),
}, { __index = function(_, cle) return TEXTES[ID[cle]] or cle end })

local RC = {
    LARGEUR = 640, CARTE_H = 84, EQUIP_H = 46, LIGNE_H = 42, COUT_H = 72, PIED_H = 54,
    ECART = 8, ICONE = 30, ICONE_OBJET = 40, ICONE_EQUIP = 28, ICONE_JETON = 28, BARRE_H = 16,
    NOM_W = 196, COCHE = 24,
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
    JETONS = { 83050, 83051, 83052, 83053, 83054 },
    -- Canal de commandes des addons du cœur, et « conteneur » de l'équipement
    -- pour le module (ItemUpgrade::ADDON_EQUIPMENT). Sacs : 0 à 4.
    CANAL = "AzerothCore",
    EQUIPEMENT = 100,
    -- L'onglet de la fenêtre Progression : sa clé, sa place (sous
    -- celui d'Attriboost), son icône (une image que ForeverUI installe, cuite
    -- au masque des onglets), et le fond rond d'une fiche sans objet.
    CLE = "itemupgrade", ORDRE = 2,
    ONGLET_ICONE = "Interface\\ForeverUI\\tabicons\\trade_blacksmithing",
    -- le portrait de la fenêtre Progression, si ce module la crée
    PORTRAIT = "Interface\\ItemUpgrade\\legacy-up-c60-masque",
    EMPLACEMENT_ROND = "Interface\\PaperDoll\\UI-Backpack-EmptySlot",
    -- Objets des sacs que la liste montre : ceux qui s'équipent, sauf chemise,
    -- tabard, sacs et munitions (comme la bande d'équipement, RC.EQUIP).
    LISTE = {
        INVTYPE_HEAD = true, INVTYPE_NECK = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true,
        INVTYPE_ROBE = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true, INVTYPE_FEET = true,
        INVTYPE_WRIST = true, INVTYPE_HAND = true, INVTYPE_FINGER = true, INVTYPE_TRINKET = true,
        INVTYPE_CLOAK = true, INVTYPE_WEAPON = true, INVTYPE_SHIELD = true, INVTYPE_2HWEAPON = true,
        INVTYPE_WEAPONMAINHAND = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_HOLDABLE = true,
        INVTYPE_RANGED = true, INVTYPE_THROWN = true, INVTYPE_RANGEDRIGHT = true, INVTYPE_RELIC = true,
    },
    ICONE_DEFAUT = "Interface\\Icons\\INV_Misc_Gem_01",
    ICONE_DEGATS = "Interface\\Icons\\Ability_MeleeDamage",
    ICONE_VITESSE = "Interface\\Icons\\Ability_Rogue_Sprint",
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
        [43] = "Interface\\Icons\\Spell_Magic_ManaGain",
        [44] = "Interface\\Icons\\Ability_Warrior_SavageBlow",
        [45] = "Interface\\Icons\\INV_Enchant_EssenceMysticalSmall",
        [46] = "Interface\\Icons\\Spell_Nature_Regenerate",
        [47] = "Interface\\Icons\\Ability_Mage_MissileBarrage",
        [48] = "Interface\\Icons\\Ability_Warrior_ShieldBash",
    },
}

local S = {
    ui = nil, lieu = nil, lien = nil, objet = nil, prise = nil,
    lignes = {}, donnees = {}, selection = {}, equip = {}, jetons = {},
    anim = false, flottants = {}, attente = false, mm = nil,
    compteur = 0, requetes = {}, refus = nil,
    fui = nil,                  -- la page de la fenêtre Progression
    replie = {}, filtre = nil,  -- sa liste : catégories repliées, recherche
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

function H.Pct(pct)
    return string.format("%g", pct or 0)
end

function H.Secondes(ms)
    return string.format("%.2f s", (ms or 0) / 1000)
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

-- Texte qui monte et s'efface au centre d'`ancre`, dans le cadre `hote` (la
-- fenêtre grise, ou la page de la fenêtre Progression).
function H.Flottant(texte, hote, ancre, r, g, b)
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
    f:SetPoint("CENTER", ancre, "CENTER", 0, 0)
    f.texte:SetText(texte)
    f.texte:SetTextColor(r or 1, g or 0.82, b or 0)
    f:SetAlpha(1)
    f:Show()
    f.anim:Play()
end

-- ---------------------------------------------------------------------------
-- Dialogue avec le module C++ (canal de commandes des addons du cœur)
-- ---------------------------------------------------------------------------
-- Envoi : « i » + numéro sur 4 caractères + commande, en chuchotement d'addon
-- à soi-même. Réponse, sous le même numéro : « a » (reçu), « m » + une ligne
-- (autant que nécessaire), puis « o » (fait) ou « f » (refusé). `suite`
-- reçoit les lignes une fois la réponse complète.
function H.Envoyer(commande, suite)
    S.compteur = S.compteur % 999 + 1
    local numero = string.format("U%03d", S.compteur)
    S.requetes[numero] = { lignes = {}, suite = suite }
    SendAddonMessage(RC.CANAL, "i" .. numero .. commande, "WHISPER", UnitName("player"))
end

function H.Reponse(message)
    local op, numero, corps = message:sub(1, 1), message:sub(2, 5), message:sub(6)
    local r = S.requetes[numero]
    if not r then return end                -- réponse destinée à un autre addon
    if op == "m" then
        table.insert(r.lignes, corps)
    elseif op == "o" or op == "f" then
        S.requetes[numero] = nil
        r.suite(r.lignes)
    end
end

-- Coût du prochain rang : « - » ou « type:valeur[:nombre] » séparés par des
-- virgules (1 cuivre, 2 honneur, 3 arène, 4 objet et nombre).
function H.LireCout(texte)
    local c = { c = 0, h = 0, a = 0, o = {} }
    for morceau in (texte or "-"):gmatch("[^,]+") do
        local t, v1, v2 = morceau:match("^(%d+):(%d+):?(%d*)$")
        t, v1, v2 = tonumber(t), tonumber(v1), tonumber(v2)
        if t == 1 then
            c.c = c.c + v1
        elseif t == 2 then
            c.h = c.h + v1
        elseif t == 3 then
            c.a = c.a + v1
        elseif t == 4 then
            table.insert(c.o, { v1, v2 or 1 })
        end
    end
    return c
end

-- Lignes du module → objet et lignes de la fenêtre (voir item_upgrade_addon.cpp).
function H.Lire(lignes)
    local r = { donnees = {} }
    for _, ligne in ipairs(lignes) do
        local m = {}
        for mot in ligne:gmatch("%S+") do table.insert(m, mot) end
        local n = function(i) return tonumber(m[i]) end
        if m[1] and m[1]:sub(1, 1) ~= "#" then
            r.texte = r.texte or ligne      -- réponse du cœur (commande inconnue...)
        elseif m[1] == "#ERR" then
            r.erreur = n(2)
        elseif m[1] == "#OK" then
            r.ok = n(2)
        elseif m[1] == "#ITEM" then
            r.objet = { guid = n(2), entry = n(3), stats = n(4) == 1, degats = n(5) == 1, vitesse = n(6) == 1 }
        elseif m[1] == "#STAT" then
            local d = { cle = n(2), type = n(2), base = n(3), rang = n(4), max = n(5), actuel = n(6),
                        suivant = n(7), pct = n(8), refuse = n(9) == 1, inactif = n(10) == 1,
                        cout = H.LireCout(m[11]) }
            d.detail = d.suivant >= 0 and string.format("%d → %d  (+%d)", d.actuel, d.suivant, d.suivant - d.actuel)
                       or tostring(d.actuel)
            table.insert(r.donnees, d)
        elseif m[1] == "#DMG" then
            local d = { cle = "dmg", rang = n(2), max = n(3), pct = n(5), cout = H.LireCout(m[12]) }
            local actuel = m[8] .. " - " .. m[9]
            d.detail = n(10) >= 0 and (actuel .. "  →  " .. m[10] .. " - " .. m[11]) or actuel
            table.insert(r.donnees, d)
        elseif m[1] == "#SPD" then
            local d = { cle = "spd", rang = n(2), max = n(3), pct = n(5), cout = H.LireCout(m[9]) }
            local actuel = H.Secondes(n(7))
            d.detail = n(8) >= 0 and (actuel .. "  →  " .. H.Secondes(n(8))) or actuel
            table.insert(r.donnees, d)
        end
    end
    return r
end

-- Texte d'un refus : celui du module par son numéro, sinon la ligne du cœur.
function H.TexteRefus(r)
    return (r.erreur and TEXTES[r.erreur]) or r.texte or ""
end

-- Une ligne se coche si elle a un prochain rang que l'objet accepte.
function H.Choisissable(d)
    return d.rang < d.max and not d.refuse
end

function H.Nom(d)
    if d.cle == "dmg" then return L.degats end
    if d.cle == "spd" then return L.vitesse end
    return L.noms[d.type] or ("#" .. tostring(d.type))
end

function H.Icone(d)
    if d.cle == "dmg" then return RC.ICONE_DEGATS end
    if d.cle == "spd" then return RC.ICONE_VITESSE end
    return RC.ICONES[d.type] or RC.ICONE_DEFAUT
end

-- ---------------------------------------------------------------------------
-- Place de l'objet
-- ---------------------------------------------------------------------------
function H.Id(lien)
    return lien and tonumber(lien:match("item:(%d+)"))
end

function H.LienA(lieu)
    if lieu.c == RC.EQUIPEMENT then
        return GetInventoryItemLink("player", lieu.s)
    end
    return GetContainerItemLink(lieu.c, lieu.s)
end

-- Le glisser-déposer ne dit pas d'où vient l'objet (GetCursorInfo ne rend que
-- son lien) : sa place est notée quand il est pris.
hooksecurefunc("PickupContainerItem", function(sac, case)
    S.prise = { c = sac, s = case, lien = GetContainerItemLink(sac, case) }
end)
hooksecurefunc("PickupInventoryItem", function(case)
    S.prise = { c = RC.EQUIPEMENT, s = case, lien = GetInventoryItemLink("player", case) }
end)

-- L'objet choisi a changé de place (équipé, rangé...) : on le retrouve s'il
-- est seul de son espèce dans les sacs et l'équipement, sinon on le lâche.
function H.Retrouver()
    local trouve, n = nil, 0
    for sac = 0, 4 do
        for case = 1, GetContainerNumSlots(sac) do
            if GetContainerItemLink(sac, case) == S.lien then
                trouve, n = { c = sac, s = case }, n + 1
            end
        end
    end
    for case = 1, 19 do
        if GetInventoryItemLink("player", case) == S.lien then
            trouve, n = { c = RC.EQUIPEMENT, s = case }, n + 1
        end
    end
    return n == 1 and trouve or nil
end

function H.Verifier()
    if not S.lieu or H.LienA(S.lieu) == S.lien then return end
    local lieu = H.Retrouver()
    if lieu then
        S.lieu = lieu
        H.Demander()
    else
        H.Retirer()
    end
end

-- ---------------------------------------------------------------------------
-- Coût de la sélection
-- ---------------------------------------------------------------------------
function H.CoutSelection()
    local total = { c = 0, h = 0, a = 0, o = {}, n = 0 }
    for _, d in ipairs(S.donnees) do
        if S.selection[d.cle] and H.Choisissable(d) then
            total.c = total.c + d.cout.c
            total.h = total.h + d.cout.h
            total.a = total.a + d.cout.a
            for _, o in ipairs(d.cout.o) do
                total.o[o[1]] = (total.o[o[1]] or 0) + o[2]
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

-- Or, honneur et arène de la sélection, en une ligne (vide sans sélection).
function H.TexteCout(total)
    if total.n == 0 then return "" end
    if total.c == 0 and total.h == 0 and total.a == 0 and next(total.o) == nil then
        return "|cff20c020" .. L.gratuit .. "|r"
    end
    local t = {}
    if total.c > 0 then
        local s = H.Argent(total.c)
        if GetMoney() < total.c then
            s = "|cffff4040" .. s .. "|r  |cffff4040(" .. Remplir(L.manquant, H.Argent(total.c - GetMoney())) .. ")|r"
        end
        table.insert(t, s)
    end
    if total.h > 0 then table.insert(t, Remplir(L.honneur, total.h)) end
    if total.a > 0 then table.insert(t, Remplir(L.arene, total.a)) end
    return table.concat(t, "   ")
end

-- Infobulle d'une ligne (statistique, dégâts ou vitesse), dans les deux vues.
function H.InfobulleLigne(proprio, d)
    GameTooltip:SetOwner(proprio, "ANCHOR_RIGHT")
    GameTooltip:AddLine(H.Nom(d), 1, 0.82, 0)
    if d.rang < d.max then
        GameTooltip:AddLine(d.detail, 1, 1, 1)
        GameTooltip:AddLine(Remplir(L.prochain, d.rang + 1, H.Pct(d.pct)), 1, 1, 1)
        local c = d.cout
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.coutRang, 1, 0.82, 0)
        if c.c == 0 and c.h == 0 and c.a == 0 and #c.o == 0 then
            GameTooltip:AddLine(L.gratuit, 0.2, 0.75, 0.2)
        end
        if c.c > 0 then GameTooltip:AddLine(H.Argent(c.c), 1, 1, 1) end
        if c.h > 0 then GameTooltip:AddLine(Remplir(L.honneur, c.h), 1, 1, 1) end
        if c.a > 0 then GameTooltip:AddLine(Remplir(L.arene, c.a), 1, 1, 1) end
        for _, o in ipairs(c.o) do
            local nomObjet = GetItemInfo(o[1]) or ("#" .. o[1])
            local ok = (GetItemCount(o[1]) or 0) >= o[2]
            GameTooltip:AddLine(o[2] .. " × " .. nomObjet, 1, ok and 1 or 0.3, ok and 1 or 0.3)
        end
        GameTooltip:AddLine(" ")
        if d.refuse then
            GameTooltip:AddLine(L.refuse, 1, 0.3, 0.3)
        else
            GameTooltip:AddLine(L.aideLigne, 0.7, 0.7, 0.7)
        end
    else
        GameTooltip:AddLine(d.detail .. "  ·  " .. L.rangMax, 1, 1, 1)
    end
    if d.inactif then
        GameTooltip:AddLine(L.inactif, 1, 0.3, 0.3)
    end
    GameTooltip:Show()
end

-- Infobulle d'un jeton du coût : l'objet, puis requis, possédé, manquant.
function H.InfobulleJeton(proprio, id, n)
    GameTooltip:SetOwner(proprio, "ANCHOR_RIGHT")
    GameTooltip:SetHyperlink("item:" .. id)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(Remplir(L.requis, n), 1, 0.82, 0)
    GameTooltip:AddLine(Remplir(L.possede, GetItemCount(id) or 0), 1, 1, 1)
    if (GetItemCount(id) or 0) < n then
        GameTooltip:AddLine(Remplir(L.manque, n - (GetItemCount(id) or 0)), 1, 0.3, 0.3)
    end
    GameTooltip:Show()
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
        if S.objet and S.objet.refus then
            c.sous:SetText(S.objet.refus); c.sous:SetTextColor(unpack(RC.ROUGE))
        elseif not S.objet then
            c.sous:SetText(L.chargement); c.sous:SetTextColor(unpack(RC.GRIS))
        else
            c.sous:SetText(Remplir(L.niveau, niveau or 0)); c.sous:SetTextColor(unpack(RC.GRIS))
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
            if S.lieu and S.lieu.c == RC.EQUIPEMENT and S.lieu.s == e.slot then
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
    l.icone:SetTexture(H.Icone(d))
    l.nom:SetText(H.Nom(d))
    local plein = d.rang >= d.max
    local sel = S.selection[d.cle] and H.Choisissable(d)
    if plein then
        l.detail:SetText(d.detail .. "  ·  " .. L.rangMax)
    else
        l.detail:SetText(d.detail)
    end
    l.barre:SetMinMaxValues(0, d.max)
    l.barreAttente:SetMinMaxValues(0, d.max)
    l.cible = d.rang
    l.attente = sel and 1 or 0
    if sel then
        l.valeur:SetText(string.format("%d |cffffffcc(+1)|r / %d", d.rang, d.max))
    else
        l.valeur:SetText(string.format("%d / %d", d.rang, d.max))
    end
    local terne = plein or d.refuse
    l.nom:SetTextColor(terne and 0.6 or 1, terne and 0.6 or 0.82, terne and 0.6 or 0)
    if H.Choisissable(d) then
        l.coche:Show()
        l.coche:SetChecked(sel and 1 or nil)
    else
        l.coche:Hide()
    end
    S.anim = true
end

function H.RendreCout()
    local ui = S.ui
    local total = H.CoutSelection()
    local suffisant = H.Suffisant(total)
    -- Or, honneur, arène
    ui.cout.argent:SetText(H.TexteCout(total))
    -- Jetons
    local i = 0
    for id, n in pairs(total.o) do
        i = i + 1
        local j = S.jetons[i]
        if not j then
            j = H.CadreIcone(ui.cout, RC.ICONE_JETON)
            j.compte = j:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            j.compte:SetPoint("BOTTOMRIGHT", 2, -2)
            j:SetScript("OnEnter", function(self) H.InfobulleJeton(self, self.id, self.n) end)
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

    H.Actif(ui.ameliorer, not S.attente and total.n > 0 and suffisant)
    H.Actif(ui.annuler, total.n > 0)
    local selectionnable = false
    for _, d in ipairs(S.donnees) do
        if H.Choisissable(d) then selectionnable = true end
    end
    H.Actif(ui.tout, not S.attente and selectionnable)
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
    if not ui then return end
    H.RendreCarte()
    H.RendreEquipement()
    ui.avertissement:SetText(S.refus or "")

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
        if S.objet and S.objet.refus then
            ui.message:SetText(S.objet.refus)
        elseif S.objet then
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
-- Réponse du module pour l'objet affiché : son état, ou le refus.
function H.Appliquer(r)
    if r.objet then
        S.objet = r.objet
        S.donnees = r.donnees
    else
        S.objet, S.donnees = { refus = H.TexteRefus(r) }, {}
    end
    -- Une coche sans prochain rang disparaît.
    for cle in pairs(S.selection) do
        local garde = false
        for _, d in ipairs(S.donnees) do
            if d.cle == cle and H.Choisissable(d) then garde = true end
        end
        if not garde then S.selection[cle] = nil end
    end
    H.Rendre()
end

function H.Demander()
    local lieu = S.lieu
    H.Envoyer(string.format("item_upgrade state %d %d", lieu.c, lieu.s), function(lignes)
        if S.lieu ~= lieu then return end   -- réponse à une sélection abandonnée
        H.Appliquer(H.Lire(lignes))
    end)
end

function H.Selectionner(c, s, lien)
    S.lieu, S.lien = { c = c, s = s }, lien
    S.objet, S.donnees, S.selection, S.refus = nil, {}, {}, nil
    H.Rendre()
    H.Demander()
end

function H.Retirer()
    S.lieu, S.lien, S.objet, S.donnees, S.selection, S.refus = nil, nil, nil, {}, {}, nil
    H.Rendre()
end

function H.Refuser(texte)
    S.refus = texte
    UIErrorsFrame:AddMessage(texte, 1, 0.1, 0.1)
end

function H.Basculer(cle)
    for _, d in ipairs(S.donnees) do
        if d.cle == cle and H.Choisissable(d) then
            S.selection[cle] = not S.selection[cle] or nil
        end
    end
    H.Rendre()
end

function H.Tout()
    for _, d in ipairs(S.donnees) do
        if H.Choisissable(d) then S.selection[d.cle] = true end
    end
    H.Rendre()
end

function H.Annuler()
    S.selection = {}
    H.Rendre()
end

function H.Ameliorer()
    if not S.lieu or not S.objet or not S.objet.guid or S.attente then return end
    local cibles = {}
    for _, d in ipairs(S.donnees) do
        if S.selection[d.cle] and H.Choisissable(d) then
            table.insert(cibles, tostring(d.cle))
        end
    end
    if #cibles == 0 then return end
    local lieu = S.lieu
    S.attente, S.refus = true, nil
    H.Rendre()
    H.Envoyer(string.format("item_upgrade upgrade %d %d %d %s", lieu.c, lieu.s, S.objet.guid,
                            table.concat(cibles, ",")), function(lignes)
        S.attente = false
        local r = H.Lire(lignes)
        if r.ok then
            S.selection = {}
            H.Succes(#cibles)
        else
            H.Refuser(H.TexteRefus(r))
        end
        if S.lieu ~= lieu then return end
        if r.objet then
            H.Appliquer(r)
        else
            H.Rendre()
            H.Demander()                    -- refus : l'état a pu changer
        end
    end)
end

function H.Deposer()
    local genre, _, lien = GetCursorInfo()
    if genre == "item" and lien then
        local p = S.prise
        ClearCursor()
        if p and p.lien == lien and (p.c == RC.EQUIPEMENT or (p.c >= 0 and p.c <= 4)) then
            H.Selectionner(p.c, p.s, lien)
        else
            H.Refuser(L.emplacement)
            H.Rendre()
        end
        return true
    end
    return false
end

-- « +n rang(s) » au-dessus de la fiche de l'objet, dans la vue affichée.
function H.Succes(n)
    local texte = Remplir(L.reussi, n)
    if S.fui then
        if FUI.h then H.Flottant(texte, S.fui, FUI.h.fiche.cadre) end
    elseif S.ui then
        H.Flottant(texte, S.ui, S.ui.carte)
    end
end

-- L'objet choisi est relu à chaque ouverture : il a pu changer entre-temps.
function H.Relire()
    if S.lieu then
        if H.LienA(S.lieu) == S.lien then H.Demander() else H.Verifier() end
    end
end

function H.Ouvrir()
    if S.fui then
        Progression.Ouvrir(RC.CLE)
        return
    end
    if not S.ui then H.Construire() end
    if S.ui:IsShown() then return end
    S.ui:Show()
    H.Ouverture()
    H.Relire()
end

function H.BasculerFenetre()
    if S.fui then
        Progression.Basculer(RC.CLE)
        return
    end
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
            if self.lien then H.Selectionner(RC.EQUIPEMENT, self.slot, self.lien) end
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
    l.coche:SetScript("OnClick", function() if l.donnee then H.Basculer(l.donnee.cle) end end)

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

    l:SetScript("OnClick", function() if l.donnee then H.Basculer(l.donnee.cle) end end)
    l:SetScript("OnEnter", function(self)
        if self.donnee then H.InfobulleLigne(self, self.donnee) end
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

    -- Message quand il n'y a pas de ligne (aucun objet, objet refusé…).
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
    f.avertissement:SetPoint("RIGHT", f.annuler, "LEFT", -12, 0)
    f.avertissement:SetJustifyH("LEFT")
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
        S.selection, S.refus = {}, nil
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
        if not f:IsShown() then return end
        H.Verifier()
        H.Rendre()
    end)
    H.Rendre()
end

-- ---------------------------------------------------------------------------
-- Page de la fenêtre Progression
-- ---------------------------------------------------------------------------
-- La disposition de la page de fabrication des métiers de ForeverUI
-- (TradeSkill.lua, validée), à ses nombres, avec les éléments que prête la
-- fenêtre Progression (Progression.Kit) :
--   liste    304 de large, de (5, -72) à 5 du bas : recherche en haut, puis
--            « Équipement » et « Sacs » en en-têtes repliables ; un objet par
--            ligne de 20, son icône à la place de celle de progression, son
--            nom à la couleur de sa qualité ; le choisi en surbrillance ;
--            infobulle de l'objet au survol
--   rang     453 x 18 à (110, -40) : « nom rangs/total » de l'objet choisi,
--            bande et éclat de la forge
--   fiche    360 x 484 à droite de la liste (2, 0) : carte de la forge, cadre
--            common-insideframe ; l'objet en icône ronde 53 dans son contour
--            de qualité, nom et niveau ; ses lignes au modèle de l'onglet
--            Compétences (case à cocher 26, nom et détail, jauge 140 x 29
--            « rang / max », « (+1) » en vert et le rang en attente plus clair
--            pour une ligne cochée ; survol 0,10, cochée 0,20) ; en bas, le
--            coût de la sélection : l'argent, puis chaque jeton dans un
--            emplacement de composant (« possédé/requis nom »)
--   boutons  rouges, 28 de haut : Améliorer à (-9, 7), Annuler à sa gauche,
--            Tout sélectionner à la place de « Tout créer » (-362, 7)
-- Un objet se choisit dans la liste (sa place est celle de la ligne) ou se
-- dépose sur la fiche. La jauge fait 140 et non 160 : à 160, le nom d'une
-- statistique n'aurait que 121 de place dans la fiche.
local NC = {
    page = { 3, -21 },
    liste = { 5, -72, 304, bas = 5 },
    recherche = { 13, -8, 20, droite = -8 },
    zone = { 8, -35, -20, 5 },
    arbre = { retrait = 10, haut = 5, bas = 5, droite = 5, espace = 1, dessus = 1, dessous = 10 },
    categorie = { h = 25, texte = 8, bouton = 20, boutonX = -6 },
    objet = { h = 20, cadre = { 26, 15, -9 }, icone = 14, nomX = 4, marge = 10 },
    aucun = { 0, -60, 200 },
    pas = 21,
    rang = { 110, -40, 453, 18, fond = { 451, 29 }, rempli = { 441, 18, 5, -3 }, masque = 1,
             eclat = { 53, 16 }, texte = -3 },
    fiche = { 2, 0, 360, 484 },
    resultat = { 28, -28, 47, icone = 53, contour = 68, lueur = 66 },
    nom = { 14, 17, 250 }, sous = { 0, -4 },
    lignes = { 20, -87, -20, ecart = 10, message = -40 },
    stat = { h = 30, ecart = 3, case = 26, nomX = 30, nomL = 141, barre = { 140, 29, -3 }, detail = -1 },
    cout = { 28, 16, 304, etiquette = 20, argent = 18, emplacement = { 180, 50 }, ecart = 5,
             bouton = 39, nomX = 46, nomTaille = { 108, 36 } },
    boutons = { droite = { -9, 7 }, tout = { -362, 7 }, h = 28, l = 80, marge = 30, ecart = -4 },
    niveaux = { liste = 1, fiche = 1, rang = 4 },
    carte = "profession-background-card-blacksmithing", bande = "blacksmithing",
    contour = { [0] = "gray", [1] = "white", [2] = "green", [3] = "blue", [4] = "purple",
                [5] = "orange", [6] = "artifact", [7] = "account" },
    contourJeton = { [1] = "professions-slot-frame", [2] = "professions-slot-frame-green",
                     [3] = "professions-slot-frame-blue", [4] = "professions-slot-frame-epic",
                     [5] = "professions-slot-frame-legendary" },
    manquant = { 0.6275, 0.6275, 0.6275 },
    evenements = { "BAG_UPDATE", "PLAYER_MONEY", "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED" },
}

-- Les éléments de cette page, par leurs coordonnées dans les feuilles que
-- ForeverUI installe (voir la trousse de la fenêtre Progression), ajoutés à
-- la trousse avant que la page ne se construise.
FUI.ART = {
    ["skillbar_fill_flipbook_blacksmithing"] = { "interface\\ForeverUI\\professions\\skillbar_fill_flipbook_blacksmithing", 0, 0.835938, 0, 0.53125, 856, 34 },
    ["skillbar_flare_blacksmithing"] = { "interface\\ForeverUI\\professions\\skillbar_flare_blacksmithing", 0, 0.828125, 0, 0.515625, 53, 33 },
    ["!minimal-scrollbar-track-middle-c60"] = { "interface\\ForeverUI\\buttons\\minimalscrollbarverticalc60", 0.015625, 0.140625, 0, 0.000977, 8, 1 },
    ["auctionhouse-itemicon-border-account"] = { "interface\\ForeverUI\\auctionframe\\auctionhouse", 0.670898, 0.803711, 0.000977, 0.133789, 136, 136 },
    ["auctionhouse-itemicon-border-artifact"] = { "interface\\ForeverUI\\auctionframe\\auctionhouse", 0.805664, 0.938477, 0.000977, 0.133789, 136, 136 },
    ["auctionhouse-itemicon-border-blue"] = { "interface\\ForeverUI\\auctionframe\\auctionhouse", 0.000977, 0.133789, 0.428711, 0.561523, 136, 136 },
    ["auctionhouse-itemicon-border-color"] = { "interface\\ForeverUI\\auctionframe\\auctionhouse", 0.000977, 0.133789, 0.833008, 0.96582, 136, 136 },
    ["auctionhouse-itemicon-border-gray"] = { "interface\\ForeverUI\\auctionframe\\auctionhouse", 0.135742, 0.268555, 0.428711, 0.561523, 136, 136 },
    ["auctionhouse-itemicon-border-green"] = { "interface\\ForeverUI\\auctionframe\\auctionhouse", 0.000977, 0.133789, 0.563477, 0.696289, 136, 136 },
    ["auctionhouse-itemicon-border-orange"] = { "interface\\ForeverUI\\auctionframe\\auctionhouse", 0.135742, 0.268555, 0.563477, 0.696289, 136, 136 },
    ["auctionhouse-itemicon-border-purple"] = { "interface\\ForeverUI\\auctionframe\\auctionhouse", 0.000977, 0.133789, 0.698242, 0.831055, 136, 136 },
    ["auctionhouse-itemicon-border-white"] = { "interface\\ForeverUI\\auctionframe\\auctionhouse", 0.135742, 0.268555, 0.698242, 0.831055, 136, 136 },
    ["charactercreate-customize-dropdown-linemouseover-middle"] = { "interface\\ForeverUI\\glues\\charactercreate\\charactercreate", 0.997559, 0.998047, 0.000488, 0.02002, 1, 40 },
    ["charactercreate-customize-dropdown-linemouseover-side"] = { "interface\\ForeverUI\\glues\\charactercreate\\charactercreate", 0.990723, 0.996582, 0.000488, 0.02002, 12, 40 },
    ["checkbox-minimal"] = { "interface\\ForeverUI\\common\\minimalcheckboxc60", 0.03125, 0.96875, 0.03125, 0.9375, 30, 29 },
    ["checkmark-minimal"] = { "interface\\ForeverUI\\common\\minimalcheckbox-hd", 0.015625, 0.484375, 0.5, 0.953125, 30, 29 },
    ["common-button-list-collapseexpand"] = { "interface\\ForeverUI\\common\\commonbuttonlistc60", 0.669922, 0.794922, 0.001953, 0.056641, 64, 28 },
    ["common-button-list-minus"] = { "interface\\ForeverUI\\common\\commonbuttonlistc60", 0.669922, 0.695312, 0.119141, 0.126953, 13, 4 },
    ["common-button-list-plus"] = { "interface\\ForeverUI\\common\\commonbuttonlistc60", 0.728516, 0.753906, 0.060547, 0.085938, 13, 13 },
    ["common-insideframe"] = { "interface\\ForeverUI\\common\\commoninsideframec60", 0.007812, 0.84375, 0.007812, 0.84375, 107, 107 },
    ["common-search-border-left"] = { "interface\\ForeverUI\\common\\commonsearch", 0.886719, 0.949219, 0.335938, 0.648438, 16, 40 },
    ["common-search-border-middle"] = { "interface\\ForeverUI\\common\\commonsearch", 0.003906, 0.878906, 0.335938, 0.648438, 224, 40 },
    ["common-search-border-right"] = { "interface\\ForeverUI\\common\\commonsearch", 0.003906, 0.066406, 0.664062, 0.976562, 16, 40 },
    ["common-search-clearbutton"] = { "interface\\ForeverUI\\common\\commonsearch", 0.175781, 0.253906, 0.664062, 0.820312, 20, 20 },
    ["common-search-magnifyingglass"] = { "interface\\ForeverUI\\common\\commonsearch", 0.074219, 0.167969, 0.664062, 0.851562, 24, 24 },
    ["minimal-scrollbar-arrow-bottom-c60"] = { "interface\\ForeverUI\\buttons\\minimalscrollbarproportionalc60", 0.242188, 0.375, 0.8125, 0.984375, 17, 11 },
    ["minimal-scrollbar-arrow-bottom-over-c60"] = { "interface\\ForeverUI\\buttons\\minimalscrollbarproportionalc60", 0.539062, 0.671875, 0.015625, 0.1875, 17, 11 },
    ["minimal-scrollbar-arrow-top-c60"] = { "interface\\ForeverUI\\buttons\\minimalscrollbarproportionalc60", 0.6875, 0.820312, 0.015625, 0.1875, 17, 11 },
    ["minimal-scrollbar-arrow-top-over-c60"] = { "interface\\ForeverUI\\buttons\\minimalscrollbarproportionalc60", 0.835938, 0.96875, 0.015625, 0.1875, 17, 11 },
    ["minimal-scrollbar-thumb-middle-c60"] = { "interface\\ForeverUI\\buttons\\minimalscrollbarverticalc60", 0.171875, 0.296875, 0.000977, 0.503906, 8, 515 },
    ["minimal-scrollbar-thumb-top-c60"] = { "interface\\ForeverUI\\buttons\\minimalscrollbarproportionalc60", 0.007812, 0.070312, 0.609375, 0.734375, 8, 8 },
    ["minimal-scrollbar-track-bottom-c60"] = { "interface\\ForeverUI\\buttons\\minimalscrollbarproportionalc60", 0.085938, 0.148438, 0.765625, 0.890625, 8, 8 },
    ["minimal-scrollbar-track-top-c60"] = { "interface\\ForeverUI\\buttons\\minimalscrollbarproportionalc60", 0.164062, 0.226562, 0.609375, 0.734375, 8, 8 },
    ["profession-background-card-blacksmithing"] = { "interface\\ForeverUI\\professions\\professioncardbackgroundblacksmithingc60", 0.000977, 0.352539, 0.141602, 0.614258, 360, 484 },
    ["profession-background-overview"] = { "interface\\ForeverUI\\professions\\professionoverviewbackgroundc60", 0.000977, 0.650391, 0.000977, 0.557617, 665, 570 },
    ["profession-background-template2"] = { "interface\\ForeverUI\\professions\\professiontrainerbackgroundc60", 0.000977, 0.650391, 0.000977, 0.557617, 665, 570 },
    ["professions-background-summarylist"] = { "interface\\ForeverUI\\professions\\professions-background-summarylist", 0, 0.523438, 0, 0.558594, 268, 572 },
    ["professions-skillbar-bg"] = { "interface\\ForeverUI\\professions\\professions-skillbar-bg", 0, 0.880859, 0, 0.90625, 451, 29 },
    ["professions-skillbar-frame"] = { "interface\\ForeverUI\\professions\\professions-skillbar-frame", 0, 0.880859, 0, 0.90625, 451, 29 },
    ["professions-slot-bg"] = { "interface\\ForeverUI\\professions\\professions-slot-bg", 0, 0.671875, 0, 0.671875, 43, 43 },
    ["professions-slot-frame"] = { "interface\\ForeverUI\\professions\\professions-slot-frame", 0, 0.625, 0, 0.625, 40, 40 },
    ["professions-slot-frame-blue"] = { "interface\\ForeverUI\\professions\\professions-slot-frame-blue", 0, 0.625, 0, 0.625, 40, 40 },
    ["professions-slot-frame-epic"] = { "interface\\ForeverUI\\professions\\professions-slot-frame-epic", 0, 0.625, 0, 0.625, 40, 40 },
    ["professions-slot-frame-green"] = { "interface\\ForeverUI\\professions\\professions-slot-frame-green", 0, 0.625, 0, 0.625, 40, 40 },
    ["professions-slot-frame-legendary"] = { "interface\\ForeverUI\\professions\\professions-slot-frame-legendary", 0, 0.625, 0, 0.625, 40, 40 },
    ["professions_recipe_active"] = { "interface\\ForeverUI\\professions\\professions_recipe_active", 0, 0.521484, 0, 0.59375, 267, 19 },
    ["professions_recipe_hover"] = { "interface\\ForeverUI\\professions\\professions_recipe_hover", 0, 0.603516, 0, 0.65625, 309, 21 },
    ["skillbar_fill_flipbook_defaultblue"] = { "interface\\ForeverUI\\professions\\skillbar_fill_flipbook_defaultblue", 0, 0.859375, 0, 0.515625, 880, 33 },
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

-- LES POLICES de la page de fabrication de camelot, absentes de 3.3.5 ou
-- différentes : { nom, fichier, taille, contour, ombre }
FUI.POLICES = {
    ligne = { "PapotaAmeliorationPoliceLigne", "Fonts\\FRIZQT__.TTF", 12 },                  -- GameFontHighlight_NoShadow
    categorie = { "PapotaAmeliorationPoliceCategorie", "Fonts\\FRIZQT__.TTF", 15, nil, true }, -- Game15Font_Shadow
    med2 = { "PapotaAmeliorationPoliceMed2", "Fonts\\FRIZQT__.TTF", 14, nil, true },          -- GameFontHighlightMed2
    small2 = { "PapotaAmeliorationPoliceSmall2", "Fonts\\FRIZQT__.TTF", 11 },                 -- GameFontHighlightSmall2
    rang = { "PapotaAmeliorationPoliceRang", "Fonts\\ARIALN.TTF", 12, "OUTLINE" },            -- Number12FontOutline
}

-- la police de la clé (créée une fois), sinon defaut
function FUI.Police(cle, defaut)
    local d = FUI.POLICES[cle]
    if not d then return defaut end
    local p = _G[d[1]]
    if not p then
        p = CreateFont(d[1])
        p:SetFont(d[2], d[3], d[4] or "")
        if d[5] then
            p:SetShadowOffset(1, -1)
            p:SetShadowColor(0, 0, 0, 1)
        else
            p:SetShadowOffset(0, 0)
            p:SetShadowColor(0, 0, 0, 0)
        end
        p:SetTextColor(1, 1, 1)
    end
    return p
end

-- L'EN-TÊTE D'UNE CATÉGORIE : common-button-list-collapseExpand, ses deux
-- bouts de 18 (sur 64 texels) et son centre (28 texels) posé tuile à tuile à
-- la largeur de la ligne. FondEntete pose les bouts sur un calque (mode de
-- fusion et transparence au choix), TuilerEntete le centre.
FUI.ENTETE = { atlas = "common-button-list-collapseexpand", cote = 18, image = 64 }

function FUI.FondEntete(b, calque, mode, alpha)
    local E = FUI.ENTETE
    local e = FUI.K.AtlasEntry(E.atlas)
    if not e then return {} end
    local du = (e[3] - e[2]) / E.image
    local morceaux = {}
    local function morceau(u1, u2)
        local t = b:CreateTexture(nil, calque)
        t:SetTexture(e[1])
        t:SetTexCoord(u1, u2, e[4], e[5])
        if mode then t:SetBlendMode(mode) end
        if alpha then t:SetAlpha(alpha) end
        morceaux[#morceaux + 1] = t
        return t
    end
    local gauche = morceau(e[2], e[2] + E.cote * du)
    gauche:SetWidth(E.cote)
    gauche:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
    gauche:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
    local droite = morceau(e[3] - E.cote * du, e[3])
    droite:SetWidth(E.cote)
    droite:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, 0)
    droite:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
    b.tuilesEntete = b.tuilesEntete or {}
    b.tuilesEntete[calque] = { gauche = gauche, du = du, e = e, milieu = E.image - 2 * E.cote,
        cote = E.cote, tuiles = {}, mode = mode, alpha = alpha }
    return morceaux
end

function FUI.TuilerEntete(b, largeur)
    for calque, T in pairs(b.tuilesEntete or {}) do
        for _, t in ipairs(T.tuiles) do t:Hide() end
        local reste, x, n = largeur - 2 * T.cote, 0, 0
        while reste > 0 do
            n = n + 1
            local t = T.tuiles[n]
            if not t then
                t = b:CreateTexture(nil, calque)
                t:SetTexture(T.e[1])
                if T.mode then t:SetBlendMode(T.mode) end
                if T.alpha then t:SetAlpha(T.alpha) end
                T.tuiles[n] = t
            end
            local l = math.min(T.milieu, reste)
            local u1 = T.e[2] + T.cote * T.du
            t:SetTexCoord(u1, u1 + l * T.du, T.e[4], T.e[5])
            t:SetWidth(l)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", T.gauche, "TOPRIGHT", x, 0)
            t:SetPoint("BOTTOMLEFT", T.gauche, "BOTTOMRIGHT", x, 0)
            t:Show()
            x = x + l
            reste = reste - l
        end
    end
end

-- LA BARRE DE DÉFILEMENT : MinimalScrollBar de camelot, que 3.3.5 n'a pas
-- (ni le ScrollBox qui la pilote), écrite ici. 8 de large, à (5, -2) /
-- (5, 4) de la liste ; flèches de 17 x 11 (survol : leur variante -over) ;
-- glissière : deux bouts de 8 et un milieu tendu ; curseur : son bout du
-- haut (8), le même retourné en bas, un milieu tendu, 16 au moins. La page
-- lui dit combien de lignes existent, combien tiennent et où elle en est
-- (Regler) ; elle rend le nouveau décalage (surDefilement) et dit quand elle
-- paraît ou s'efface (surVisibilite), sans toucher à aucune liste.
FUI.BARRE = {
    largeur = 8, fleche = { 17, 11 }, bout = 8,
    trackHaut = "minimal-scrollbar-track-top-c60",
    trackMilieu = "!minimal-scrollbar-track-middle-c60",
    trackBas = "minimal-scrollbar-track-bottom-c60",
    curseurBout = "minimal-scrollbar-thumb-top-c60",
    curseurMilieu = "minimal-scrollbar-thumb-middle-c60",
    flecheHaut = { "minimal-scrollbar-arrow-top-c60", "minimal-scrollbar-arrow-top-over-c60" },
    flecheBas = { "minimal-scrollbar-arrow-bottom-c60", "minimal-scrollbar-arrow-bottom-over-c60" },
}

-- la hauteur de la souris, à l'échelle du cadre (GetCursorPosition rend des
-- coordonnées d'écran)
local function hauteurSouris(cadre)
    local _, y = GetCursorPosition()
    return y / (cadre:GetEffectiveScale() or 1)
end

function FUI.BarreDefilement(nom, parent, liste)
    local K, B = FUI.K, FUI.BARRE
    local barre = CreateFrame("Frame", nom, parent)
    barre:SetWidth(B.largeur)
    barre:SetPoint("TOPLEFT", liste, "TOPRIGHT", 5, -2)
    barre:SetPoint("BOTTOMLEFT", liste, "BOTTOMRIGHT", 5, 4)
    barre.total, barre.visibles, barre.decalage = 0, 0, 0

    local function fleche(suffixe, atlas, pas)
        local b = CreateFrame("Button", nom .. suffixe, barre)
        b:SetWidth(B.fleche[1])
        b:SetHeight(B.fleche[2])
        local image = b:CreateTexture(nil, "ARTWORK")
        K.SetAtlas(image, atlas[1], true)
        image:SetAllPoints(b)
        b.image = image
        b:SetScript("OnEnter", function(self) K.SetAtlas(self.image, atlas[2], true) end)
        b:SetScript("OnLeave", function(self) K.SetAtlas(self.image, atlas[1], true) end)
        b:SetScript("OnClick", function() barre:Deplacer(barre.decalage + pas) end)
        return b
    end
    local haut = fleche("Up", B.flecheHaut, -1)
    haut:SetPoint("TOP", barre, "TOP", 0, 0)
    barre.flecheHaut = haut
    local bas = fleche("Down", B.flecheBas, 1)
    bas:SetPoint("BOTTOM", barre, "BOTTOM", 0, 0)
    barre.flecheBas = bas

    local piste = CreateFrame("Frame", nil, barre)
    piste:SetPoint("TOPLEFT", haut, "BOTTOMLEFT", 0, 0)
    piste:SetPoint("BOTTOMRIGHT", bas, "TOPRIGHT", 0, 0)
    piste:SetWidth(B.largeur)
    barre.piste = piste
    local function tranche(cadre, atlas, calque)
        local t = cadre:CreateTexture(nil, calque or "BACKGROUND")
        K.SetAtlas(t, atlas, true)
        t:SetWidth(B.largeur)
        return t
    end
    local pHaut = tranche(piste, B.trackHaut)
    pHaut:SetHeight(B.bout)
    pHaut:SetPoint("TOP", piste, "TOP", 0, 0)
    local pBas = tranche(piste, B.trackBas)
    pBas:SetHeight(B.bout)
    pBas:SetPoint("BOTTOM", piste, "BOTTOM", 0, 0)
    local pMilieu = tranche(piste, B.trackMilieu)
    pMilieu:SetPoint("TOPLEFT", pHaut, "BOTTOMLEFT", 0, 0)
    pMilieu:SetPoint("BOTTOMRIGHT", pBas, "TOPRIGHT", 0, 0)

    local curseur = CreateFrame("Frame", nom .. "Thumb", piste)
    curseur:SetWidth(B.largeur)
    curseur:SetHeight(2 * B.bout)
    curseur:EnableMouse(true)
    barre.curseur = curseur
    local cHaut = tranche(curseur, B.curseurBout, "ARTWORK")
    cHaut:SetHeight(B.bout)
    cHaut:SetPoint("TOP", curseur, "TOP", 0, 0)
    -- le même bout, retourné : le haut et le bas de son rectangle échangés
    local cBas = tranche(curseur, B.curseurBout, "ARTWORK")
    local e = K.AtlasEntry(B.curseurBout)
    if e then cBas:SetTexCoord(e[2], e[3], e[5], e[4]) end
    cBas:SetHeight(B.bout)
    cBas:SetPoint("BOTTOM", curseur, "BOTTOM", 0, 0)
    local cMilieu = tranche(curseur, B.curseurMilieu, "ARTWORK")
    cMilieu:SetPoint("TOPLEFT", cHaut, "BOTTOMLEFT", 0, 0)
    cMilieu:SetPoint("BOTTOMRIGHT", cBas, "TOPRIGHT", 0, 0)

    function barre:Deplacer(vers)
        local maximum = math.max(0, self.total - self.visibles)
        vers = math.max(0, math.min(math.floor(vers + 0.5), maximum))
        if vers == self.decalage then return end
        self.decalage = vers
        self:Repositionner()
        if self.surDefilement then self.surDefilement(vers) end
    end

    function barre:Repositionner()
        local hauteur = self.piste:GetHeight() or 0
        local maximum = math.max(0, self.total - self.visibles)
        if hauteur <= 0 or maximum <= 0 then
            self.curseur:Hide()
            return
        end
        local taille = math.min(hauteur, math.max(2 * B.bout, math.floor(hauteur * self.visibles / self.total + 0.5)))
        self.curseur:SetHeight(taille)
        self.curseur:ClearAllPoints()
        self.curseur:SetPoint("TOP", self.piste, "TOP", 0, -(hauteur - taille) * (self.decalage / maximum))
        self.curseur:Show()
    end

    function barre:Regler(total, visibles, decalage)
        self.total, self.visibles, self.decalage = total or 0, visibles or 0, decalage or 0
        local avec = self.total > self.visibles
        if avec then
            self:Show()
            self:Repositionner()
        else
            self:Hide()
        end
        if avec ~= self.avecAvant then
            self.avecAvant = avec
            if self.surVisibilite then self.surVisibilite(avec) end
        end
    end

    -- glisser le curseur : un OnUpdate le suit tant que le bouton est tenu
    curseur:SetScript("OnMouseDown", function(self)
        self.prise = hauteurSouris(self)
        self.priseDecalage = barre.decalage
        self:SetScript("OnUpdate", function(soi)
            local course = (barre.piste:GetHeight() or 0) - (soi:GetHeight() or 0)
            local maximum = math.max(0, barre.total - barre.visibles)
            if course <= 0 or maximum <= 0 then return end
            barre:Deplacer(soi.priseDecalage + (soi.prise - hauteurSouris(soi)) / course * maximum)
        end)
    end)
    curseur:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
    -- cliquer la glissière saute d'une page, du côté du clic
    piste:EnableMouse(true)
    piste:SetScript("OnMouseDown", function(self)
        local y = hauteurSouris(self)
        if y > (barre.curseur:GetTop() or 0) then
            barre:Deplacer(barre.decalage - barre.visibles)
        elseif y < (barre.curseur:GetBottom() or 0) then
            barre:Deplacer(barre.decalage + barre.visibles)
        end
    end)
    barre:Hide()
    return barre
end

local function poser(r, ...)
    r:ClearAllPoints()
    r:SetPoint(...)
end

-- Construite à la première ouverture de l'onglet : les textes sont arrivés.
function FUI.Construire(p)
    local K = Progression.Kit
    FUI.K = K
    local h = { page = p, categories = {}, objets = {}, lignes = {}, emplacements = {},
                decalage = 0, decalageLignes = 0 }
    FUI.h = h
    local base = p:GetFrameLevel()
    -- les fonds de la page de fabrication
    local fond = p:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(fond, "profession-background-overview", true)
    fond:SetPoint("TOPLEFT", p, "TOPLEFT", 2, -21)
    fond:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", -2, 2)
    local gabarit = p:CreateTexture(nil, "BORDER")
    K.SetAtlas(gabarit, "profession-background-template2")
    gabarit:SetPoint("TOPLEFT", p, "TOPLEFT", NC.page[1], NC.page[2])
    FUI.ConstruireListe(p, base + NC.niveaux.liste)
    FUI.ConstruireRang(p, base + NC.niveaux.rang)
    FUI.ConstruireFiche(p, base + NC.niveaux.fiche)
    FUI.ConstruireBoutons(p)
    p:SetScript("OnShow", function(self)
        for _, ev in ipairs(NC.evenements) do self:RegisterEvent(ev) end
        H.Relire()
        H.Rendre()
    end)
    p:SetScript("OnHide", function(self)
        for _, ev in ipairs(NC.evenements) do self:UnregisterEvent(ev) end
        S.selection, S.refus = {}, nil
        GameTooltip:Hide()
    end)
    p:SetScript("OnEvent", function()
        H.Verifier()
        H.Rendre()
    end)
end

-- ------------------------------------------------------------- la liste
function FUI.ConstruireListe(p, niveau)
    local K, h, Li = FUI.K, FUI.h, NC.liste
    local liste = CreateFrame("Frame", nil, p)
    liste:SetWidth(Li[3])
    liste:SetPoint("TOPLEFT", p, "TOPLEFT", Li[1], Li[2])
    liste:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", Li[1], Li.bas)
    liste:SetFrameLevel(niveau)
    h.liste = liste
    local fond = liste:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(fond, "professions-background-summarylist", true)
    fond:SetAllPoints(liste)
    local aucun = liste:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    aucun:SetWidth(NC.aucun[3])
    aucun:SetPoint("TOP", liste, "TOP", NC.aucun[1], NC.aucun[2])
    aucun:SetText(L.vide)
    aucun:Hide()
    h.aucun = aucun
    h.recherche = FUI.Recherche(liste)
    local zone = CreateFrame("ScrollFrame", nil, liste)
    h.zone = zone
    FUI.PoserZone(false)
    h.avecBarre = false
    local enfant = CreateFrame("Frame", nil, zone)
    enfant:SetWidth(1)
    enfant:SetHeight(1)
    zone:SetScrollChild(enfant)
    enfant:SetFrameLevel(niveau + 1)
    h.enfant = enfant
    local barre = FUI.BarreDefilement("PapotaAmeliorationListeBarre", liste, zone)
    barre:ClearAllPoints()
    barre:SetPoint("TOPLEFT", zone, "TOPRIGHT", 0, 0)
    barre:SetPoint("BOTTOMLEFT", zone, "BOTTOMRIGHT", 0, 0)
    barre.surDefilement = function(pas)
        h.decalage = pas
        FUI.MajListe()
    end
    h.barre = barre
    zone:EnableMouseWheel(true)
    zone:SetScript("OnMouseWheel", function(_, sens)
        if barre:IsShown() then barre:Deplacer(barre.decalage - sens * 3) end
    end)
end

-- sans barre : la même marge à droite qu'à gauche (règle de l'atelier)
function FUI.PoserZone(avec)
    local h, Z = FUI.h, NC.zone
    h.zone:ClearAllPoints()
    h.zone:SetPoint("TOPLEFT", h.liste, "TOPLEFT", Z[1], Z[2])
    h.zone:SetPoint("BOTTOMRIGHT", h.liste, "BOTTOMRIGHT", avec and Z[3] or -Z[1], Z[4])
end

-- SearchBoxTemplate, comme la page de fabrication (sans le filtre à droite)
function FUI.Recherche(liste)
    local K, R = FUI.K, NC.recherche
    local r = CreateFrame("EditBox", nil, liste)
    r:SetHeight(R[3])
    r:SetPoint("TOPLEFT", liste, "TOPLEFT", R[1], R[2])
    r:SetWidth(NC.liste[3] - R[1] + R.droite)
    r:SetAutoFocus(false)
    r:SetMaxLetters(60)
    r:SetFontObject("GameFontHighlightSmall")
    r:SetTextInsets(16, 20, 0, 0)
    local g = r:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(g, "common-search-border-left", true)
    g:SetWidth(8) g:SetHeight(20)
    g:SetPoint("LEFT", r, "LEFT", -5, 0)
    local d = r:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(d, "common-search-border-right", true)
    d:SetWidth(8) d:SetHeight(20)
    d:SetPoint("RIGHT", r, "RIGHT", 0, 0)
    local m = r:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(m, "common-search-border-middle", true)
    m:SetPoint("TOPLEFT", g, "TOPRIGHT")
    m:SetPoint("BOTTOMRIGHT", d, "BOTTOMLEFT")
    local loupe = r:CreateTexture(nil, "OVERLAY")
    K.SetAtlas(loupe, "common-search-magnifyingglass", true)
    loupe:SetWidth(10) loupe:SetHeight(10)
    loupe:SetPoint("LEFT", r, "LEFT", 1, -1)
    local consigne = r:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    consigne:SetPoint("TOPLEFT", r, "TOPLEFT", 16, 0)
    consigne:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", -20, 0)
    consigne:SetJustifyH("LEFT")
    consigne:SetTextColor(0.35, 0.35, 0.35)
    consigne:SetText(SEARCH)
    local effacer = CreateFrame("Button", nil, r)
    effacer:SetWidth(17) effacer:SetHeight(17)
    effacer:SetPoint("RIGHT", r, "RIGHT", -3, 0)
    local croix = effacer:CreateTexture(nil, "ARTWORK")
    K.SetAtlas(croix, "common-search-clearbutton", true)
    croix:SetWidth(10) croix:SetHeight(10)
    croix:SetPoint("CENTER", effacer, "CENTER", 0, 0)
    croix:SetAlpha(0.5)
    effacer:SetScript("OnEnter", function() croix:SetAlpha(1) end)
    effacer:SetScript("OnLeave", function() croix:SetAlpha(0.5) end)
    effacer:SetScript("OnClick", function()
        r:SetText("")
        r:ClearFocus()
    end)
    effacer:Hide()
    r:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    r:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    r:SetScript("OnEditFocusGained", function() consigne:Hide() end)
    r:SetScript("OnEditFocusLost", function(self)
        if self:GetText() == "" then consigne:Show() end
    end)
    r:SetScript("OnTextChanged", function(self)
        local t = self:GetText() or ""
        if t == "" then effacer:Hide() else effacer:Show() consigne:Hide() end
        S.filtre = (t ~= "") and string.lower(t) or nil
        FUI.h.decalage = 0
        FUI.MajListe()
    end)
    return r
end

function FUI.CreerCategorie(n)
    local K, h, C = FUI.K, FUI.h, NC.categorie
    local b = CreateFrame("Button", nil, h.enfant)
    b:SetHeight(C.h)
    b:RegisterForClicks("LeftButtonUp")
    FUI.FondEntete(b, "BACKGROUND")
    FUI.FondEntete(b, "HIGHLIGHT", "ADD", 0.4)
    local plus = CreateFrame("Frame", nil, b)
    plus:SetWidth(C.bouton)
    plus:SetHeight(C.bouton)
    plus:SetPoint("RIGHT", b, "RIGHT", C.boutonX, 0)
    plus.Icon = plus:CreateTexture(nil, "ARTWORK")
    plus.Icon:SetPoint("CENTER", plus, "CENTER", 0, 0)
    b.plus = plus
    local texte = b:CreateFontString(nil, "OVERLAY")
    texte:SetFontObject(FUI.Police("categorie", GameFontNormal))
    texte:SetJustifyH("LEFT")
    texte:SetPoint("LEFT", b, "LEFT", C.texte, 0)
    texte:SetPoint("RIGHT", plus, "LEFT", -4, 0)
    b.texte = texte
    local n_ = NORMAL_FONT_COLOR
    texte:SetTextColor(n_.r, n_.g, n_.b)
    b:SetScript("OnEnter", function(self) self.texte:SetTextColor(1, 1, 1) end)
    b:SetScript("OnLeave", function(self) self.texte:SetTextColor(n_.r, n_.g, n_.b) end)
    b:SetScript("OnMouseDown", function(self)
        poser(self.texte, "LEFT", self, "LEFT", C.texte + 1, -1)
        self.texte:SetPoint("RIGHT", self.plus, "LEFT", -4, 0)
        poser(self.plus.Icon, "CENTER", self.plus, "CENTER", 1, -1)
    end)
    b:SetScript("OnMouseUp", function(self)
        poser(self.texte, "LEFT", self, "LEFT", C.texte, 0)
        self.texte:SetPoint("RIGHT", self.plus, "LEFT", -4, 0)
        poser(self.plus.Icon, "CENTER", self.plus, "CENTER", 0, 0)
    end)
    b:SetScript("OnClick", function(self)
        PlaySound("igMainMenuOptionCheckBoxOn")
        S.replie[self.cle] = not S.replie[self.cle] or nil
        FUI.MajListe()
    end)
    return b
end

function FUI.CreerObjet(n)
    local K, h, R = FUI.K, FUI.h, NC.objet
    local b = CreateFrame("Button", nil, h.enfant)
    b:SetHeight(R.h)
    b:RegisterForClicks("LeftButtonUp")
    local cadre = CreateFrame("Frame", nil, b)
    cadre:SetWidth(R.cadre[1])
    cadre:SetHeight(R.cadre[2])
    cadre:SetPoint("LEFT", b, "LEFT", R.cadre[3], 0)
    b.icone = cadre:CreateTexture(nil, "OVERLAY")
    b.icone:SetWidth(R.icone)
    b.icone:SetHeight(R.icone)
    b.icone:SetPoint("RIGHT", cadre, "RIGHT", 0, 0)
    local nom = b:CreateFontString(nil, "OVERLAY")
    nom:SetFontObject(FUI.Police("ligne", GameFontHighlight))
    nom:SetJustifyH("LEFT")
    nom:SetHeight(12)
    nom:SetPoint("LEFT", cadre, "RIGHT", R.nomX, 0)
    b.nom = nom
    -- choisie (au-dessus du nom) et survol (calque HIGHLIGHT)
    local choix = CreateFrame("Frame", nil, b)
    choix:SetAllPoints(b)
    choix:SetFrameLevel(b:GetFrameLevel() + 1)
    choix:EnableMouse(false)
    b.choisie = choix:CreateTexture(nil, "OVERLAY")
    K.SetAtlas(b.choisie, "professions_recipe_active")
    b.choisie:SetPoint("CENTER", b, "CENTER", 0, -1)
    b.choisie:Hide()
    local survol = b:CreateTexture(nil, "HIGHLIGHT")
    K.SetAtlas(survol, "professions_recipe_hover")
    survol:SetPoint("CENTER", b, "CENTER", 0, -1)
    survol:SetAlpha(0.5)
    b:SetScript("OnEnter", function(self)
        local o = self.objet
        if not o then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if o.c == RC.EQUIPEMENT then
            GameTooltip:SetInventoryItem("player", o.s)
        else
            GameTooltip:SetBagItem(o.c, o.s)
        end
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        local o = self.objet
        if not o then return end
        if IsModifiedClick() then
            HandleModifiedItemClick(o.lien)
            return
        end
        PlaySound("igMainMenuOptionCheckBoxOn")
        H.Selectionner(o.c, o.s, o.lien)
    end)
    return b
end

-- Un objet des sacs entre dans la liste s'il s'équipe (RC.LISTE).
function FUI.Equipable(lien)
    local emplacement = select(9, GetItemInfo(lien))
    return emplacement and RC.LISTE[emplacement] or false
end

function FUI.NomDe(lien)
    return GetItemInfo(lien) or string.match(lien, "%[(.-)%]") or lien
end

function FUI.Garde(lien)
    return not S.filtre or string.find(string.lower(FUI.NomDe(lien)), S.filtre, 1, true) ~= nil
end

-- L'équipement dans l'ordre de la feuille de personnage, puis les sacs ; une
-- catégorie sans objet (après la recherche) disparaît.
function FUI.Elements()
    local A = NC.arbre
    local cats = { { cle = "equip", nom = L.equipement, objets = {} },
                   { cle = "sacs", nom = L.sacs, objets = {} } }
    for _, slot in ipairs(RC.EQUIP) do
        local lien = GetInventoryItemLink("player", slot)
        if lien and FUI.Garde(lien) then
            table.insert(cats[1].objets, { c = RC.EQUIPEMENT, s = slot, lien = lien })
        end
    end
    for sac = 0, 4 do
        for case = 1, GetContainerNumSlots(sac) or 0 do
            local lien = GetContainerItemLink(sac, case)
            if lien and FUI.Equipable(lien) and FUI.Garde(lien) then
                table.insert(cats[2].objets, { c = sac, s = case, lien = lien })
            end
        end
    end
    local elements = {}
    for _, cat in ipairs(cats) do
        if #cat.objets > 0 then
            cat.categorie, cat.deplie = true, not S.replie[cat.cle]
            table.insert(elements, cat)
            if cat.deplie then
                table.insert(elements, { espace = A.dessus })
                for _, o in ipairs(cat.objets) do table.insert(elements, o) end
                table.insert(elements, { espace = A.dessous })
            end
        end
    end
    return elements
end

-- La largeur d'un nom, mesurée sur un texte à part jamais borné (voir
-- TradeSkill.lua : un texte déjà borné rend sa largeur affichée).
function FUI.LargeurNom(texte)
    local h = FUI.h
    if not h.mesure then
        h.mesure = h.enfant:CreateFontString(nil, "OVERLAY")
        h.mesure:SetFontObject(FUI.Police("ligne", GameFontHighlight))
        h.mesure:SetPoint("TOPLEFT", h.enfant, "TOPLEFT", 0, 0)
        h.mesure:SetAlpha(0)
    end
    h.mesure:SetText(texte)
    return h.mesure:GetStringWidth()
end

function FUI.RemplirObjet(b, o, largeur)
    local R = NC.objet
    local _, _, q, _, _, _, _, _, _, texture = GetItemInfo(o.lien)
    b.objet = o
    b.icone:SetTexture(texture or RC.ICONE_DEFAUT)
    local nom = FUI.NomDe(o.lien)
    b.nom:SetText(nom)
    local r, g, bl = GetItemQualityColor(q or 1)
    b.nom:SetTextColor(r, g, bl)
    local place = largeur - (R.marge + R.cadre[1])
    b.nom:SetWidth(math.max(1, math.min(place, FUI.LargeurNom(nom))))
    local choisie = S.lieu and S.lieu.c == o.c and S.lieu.s == o.s
    if choisie then b.choisie:Show() else b.choisie:Hide() end
end

function FUI.MajListe()
    local h, K, A = FUI.h, FUI.K, NC.arbre
    local elements = FUI.Elements()
    local hauteur = A.haut + A.bas
    for i, e in ipairs(elements) do
        hauteur = hauteur + (e.categorie and NC.categorie.h or e.espace or NC.objet.h) + (i > 1 and A.espace or 0)
    end
    local vue = h.zone:GetHeight()
    if not vue or vue <= 0 then
        vue = Progression.fenetre:GetHeight() + NC.liste[2] - NC.liste.bas + NC.zone[2] - NC.zone[4]
    end
    local avec = hauteur > vue
    if avec ~= h.avecBarre then
        h.avecBarre = avec
        FUI.PoserZone(avec)
    end
    local largeur = NC.liste[3] - NC.zone[1] + (avec and NC.zone[3] or -NC.zone[1])
    h.enfant:SetWidth(largeur)
    h.enfant:SetHeight(math.max(hauteur, 1))
    local y, nc, no = A.haut, 0, 0
    for i, e in ipairs(elements) do
        if i > 1 then y = y + A.espace end
        if e.categorie then
            nc = nc + 1
            local b = h.categories[nc] or FUI.CreerCategorie(nc)
            h.categories[nc] = b
            b.cle = e.cle
            b.texte:SetText(e.nom)
            K.SetAtlas(b.plus.Icon, e.deplie and "common-button-list-minus" or "common-button-list-plus")
            local l = largeur - A.droite
            b:SetWidth(l)
            FUI.TuilerEntete(b, l)
            poser(b, "TOPLEFT", h.enfant, "TOPLEFT", 0, -y)
            b:Show()
            y = y + NC.categorie.h
        elseif e.espace then
            y = y + e.espace
        else
            no = no + 1
            local b = h.objets[no] or FUI.CreerObjet(no)
            h.objets[no] = b
            local l = largeur - A.droite - A.retrait
            b:SetWidth(l)
            poser(b, "TOPLEFT", h.enfant, "TOPLEFT", A.retrait, -y)
            FUI.RemplirObjet(b, e, l)
            b:Show()
            y = y + NC.objet.h
        end
    end
    for i = nc + 1, #h.categories do h.categories[i]:Hide() end
    for i = no + 1, #h.objets do h.objets[i]:Hide() end
    if #elements == 0 then h.aucun:Show() else h.aucun:Hide() end
    local total = math.ceil(hauteur / NC.pas)
    local visibles = math.floor(vue / NC.pas)
    h.decalage = math.max(0, math.min(h.decalage or 0, total - visibles))
    h.barre:Regler(total, visibles, h.decalage)
    h.zone:SetVerticalScroll(math.min(h.decalage * NC.pas, math.max(0, hauteur - vue)))
end

-- ------------------------------------------------------------- le rang
function FUI.ConstruireRang(p, niveau)
    local K, R = FUI.K, NC.rang
    local rang = CreateFrame("Frame", nil, p)
    rang:SetWidth(R[3])
    rang:SetHeight(R[4])
    rang:SetPoint("TOPLEFT", p, "TOPLEFT", R[1], R[2])
    rang:SetFrameLevel(niveau)
    local fond = rang:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(fond, "professions-skillbar-bg", true)
    fond:SetWidth(R.fond[1]) fond:SetHeight(R.fond[2])
    fond:SetPoint("TOPLEFT", rang, "TOPLEFT", 0, 0)
    local rempli = rang:CreateTexture(nil, "BORDER")
    rempli:SetHeight(R.rempli[2])
    rempli:SetPoint("TOPLEFT", rang, "TOPLEFT", R.rempli[3] + R.masque, R.rempli[4])
    local eclat = rang:CreateTexture(nil, "ARTWORK")
    eclat:SetWidth(R.eclat[1]) eclat:SetHeight(R.eclat[2])
    eclat:SetBlendMode("ADD")
    local cadre = rang:CreateTexture(nil, "OVERLAY")
    K.SetAtlas(cadre, "professions-skillbar-frame", true)
    cadre:SetWidth(R.fond[1]) cadre:SetHeight(R.fond[2])
    cadre:SetPoint("TOPLEFT", rang, "TOPLEFT", 0, 0)
    local dessus = CreateFrame("Frame", nil, rang)
    dessus:SetHeight(R[4])
    dessus:SetPoint("LEFT", rang, "LEFT", 0, R.texte)
    dessus:SetPoint("RIGHT", rang, "RIGHT", 0, R.texte)
    dessus:SetFrameLevel(niveau + 1)
    local t = dessus:CreateFontString(nil, "ARTWORK")
    t:SetFontObject(FUI.Police("rang", NumberFontNormal))
    t:SetPoint("CENTER", dessus, "CENTER", 0, 0)
    rang.rempli, rang.eclat, rang.texte = rempli, eclat, t
    rang:Hide()
    FUI.h.rang = rang
end

-- les rangs acquis de l'objet sur leur total (ProfessionsRankBarMixin, la
-- bande de la forge ; première image, masque et éclat de TradeSkill.lua)
function FUI.MajRang()
    local K, R, r = FUI.K, NC.rang, FUI.h.rang
    local rangs, total = 0, 0
    for _, d in ipairs(S.donnees) do
        rangs, total = rangs + d.rang, total + d.max
    end
    if not S.lien or total <= 0 then
        r:Hide()
        return
    end
    r:Show()
    r.texte:SetText(string.format("%s %d/%d", FUI.NomDe(S.lien), rangs, total))
    local e = K.AtlasEntry("skillbar_fill_flipbook_" .. NC.bande) or K.AtlasEntry("skillbar_fill_flipbook_defaultblue")
    local eclat = K.AtlasEntry("skillbar_flare_" .. NC.bande)
    local part = math.min(rangs / total, 1)
    local vu = math.min(R.rempli[1] - R.masque, R[3] * part)
    if e and vu >= 1 then
        r.rempli:SetTexture(e[1])
        local du = (e[3] - e[2]) / R.rempli[1]
        r.rempli:SetTexCoord(e[2] + du * R.masque, e[2] + du * (R.masque + vu), e[4], e[5])
        r.rempli:SetWidth(vu)
        r.rempli:Show()
    else
        r.rempli:Hide()
    end
    local masque = R[3] * part
    if eclat and masque >= 1 then
        local l = math.min(R.eclat[1], masque)
        local du = (eclat[3] - eclat[2]) / R.eclat[1]
        r.eclat:SetTexture(eclat[1])
        r.eclat:SetTexCoord(eclat[3] - du * l, eclat[3], eclat[4], eclat[5])
        r.eclat:SetWidth(l)
        poser(r.eclat, "RIGHT", r, "TOPLEFT", R.rempli[3] + R.masque + masque, R.rempli[4] - R.rempli[2] / 2)
        r.eclat:SetAlpha(rangs >= total and 0 or 1)
        r.eclat:Show()
    else
        r.eclat:Hide()
    end
end

-- ------------------------------------------------------------- la fiche
function FUI.ConstruireFiche(p, niveau)
    local K, h, Fc, Rs = FUI.K, FUI.h, NC.fiche, NC.resultat
    local fiche = CreateFrame("Frame", nil, p)
    fiche:SetWidth(Fc[3])
    fiche:SetHeight(Fc[4])
    fiche:SetPoint("TOPLEFT", h.liste, "TOPRIGHT", Fc[1], Fc[2])
    fiche:SetFrameLevel(niveau)
    local F = { cadre = fiche }
    h.fiche = F
    local carte = fiche:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(carte, NC.carte, true)
    carte:SetAllPoints(fiche)
    local bord = K.AtlasEtire(fiche, "common-insideframe", "BORDER")
    bord.rect:SetAllPoints(fiche)
    -- toute la fiche accepte le dépôt d'un objet
    fiche:EnableMouse(true)
    fiche:SetScript("OnReceiveDrag", function() H.Deposer() end)
    fiche:SetScript("OnMouseUp", function() H.Deposer() end)
    -- l'objet
    local resultat = CreateFrame("Button", nil, fiche)
    resultat:SetWidth(Rs[3]) resultat:SetHeight(Rs[3])
    resultat:SetPoint("TOPLEFT", fiche, "TOPLEFT", Rs[1], Rs[2])
    resultat:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    F.resultat = resultat
    F.icone = resultat:CreateTexture(nil, "BORDER")
    F.icone:SetWidth(Rs.icone) F.icone:SetHeight(Rs.icone)
    F.icone:SetPoint("CENTER", resultat, "CENTER", 0, 0)
    F.contour = resultat:CreateTexture(nil, "OVERLAY")
    F.contour:SetWidth(Rs.contour) F.contour:SetHeight(Rs.contour)
    F.contour:SetPoint("CENTER", resultat, "CENTER", 0, 0)
    local lueur = resultat:CreateTexture(nil, "HIGHLIGHT")
    K.SetAtlas(lueur, "auctionhouse-itemicon-border-white", true)
    lueur:SetWidth(Rs.lueur) lueur:SetHeight(Rs.lueur)
    lueur:SetPoint("CENTER", resultat, "CENTER", 0, 0)
    lueur:SetBlendMode("ADD")
    lueur:SetAlpha(0.2)
    resultat:SetScript("OnEnter", function(self)
        if not S.lien then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(S.lien)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(L.retirer, 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    resultat:SetScript("OnLeave", function() GameTooltip:Hide() end)
    resultat:SetScript("OnReceiveDrag", function() H.Deposer() end)
    resultat:SetScript("OnClick", function()
        if S.lien and IsModifiedClick() then
            HandleModifiedItemClick(S.lien)
        elseif not H.Deposer() and S.lien then
            H.Retirer()
        end
    end)
    F.nom = fiche:CreateFontString(nil, "ARTWORK")
    F.nom:SetFontObject(FUI.Police("med2", GameFontHighlightMedium or GameFontHighlight))
    F.nom:SetJustifyH("LEFT")
    F.nom:SetWidth(NC.nom[3])
    F.nom:SetHeight(16)
    F.nom:SetPoint("LEFT", resultat, "RIGHT", NC.nom[1], NC.nom[2])
    F.sous = fiche:CreateFontString(nil, "ARTWORK")
    F.sous:SetFontObject(FUI.Police("small2", GameFontHighlightSmall))
    F.sous:SetJustifyH("LEFT")
    F.sous:SetJustifyV("TOP")
    F.sous:SetWidth(NC.nom[3])
    F.sous:SetHeight(28)
    F.sous:SetPoint("TOPLEFT", F.nom, "BOTTOMLEFT", NC.sous[1], NC.sous[2])
    -- les lignes, et leur barre de défilement dans la marge de la fiche
    local Lz = NC.lignes
    local zone = CreateFrame("Frame", nil, fiche)
    zone:SetPoint("TOPLEFT", fiche, "TOPLEFT", Lz[1], Lz[2])
    zone:SetWidth(Fc[3] - Lz[1] + Lz[3])
    zone:SetHeight(1)
    zone:SetFrameLevel(niveau + 1)
    zone:EnableMouseWheel(true)
    F.zone = zone
    local barre = FUI.BarreDefilement("PapotaAmeliorationLignesBarre", fiche, zone)
    barre.surDefilement = function(pas)
        h.decalageLignes = pas
        FUI.MajLignes()
    end
    barre:Hide()
    F.barre = barre
    zone:SetScript("OnMouseWheel", function(_, sens)
        if barre:IsShown() then barre:Deplacer(barre.decalage - sens) end
    end)
    F.message = fiche:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    F.message:SetWidth(Fc[3] - 2 * Lz[1])
    F.message:SetPoint("TOP", zone, "TOP", 0, Lz.message)
    -- le coût, en bas de la fiche
    local C = NC.cout
    local cout = CreateFrame("Frame", nil, fiche)
    cout:SetWidth(C[3])
    cout:SetHeight(C.etiquette + C.argent)
    cout:SetPoint("BOTTOMLEFT", fiche, "BOTTOMLEFT", C[1], C[2])
    cout:SetFrameLevel(niveau + 1)
    local etiquette = cout:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    etiquette:SetJustifyH("LEFT")
    etiquette:SetWidth(C[3])
    etiquette:SetHeight(C.etiquette)
    etiquette:SetPoint("TOPLEFT", cout, "TOPLEFT", 0, 0)
    etiquette:SetText(L.cout)
    local argent = cout:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    argent:SetJustifyH("LEFT")
    argent:SetWidth(C[3])
    argent:SetHeight(C.argent)
    argent:SetPoint("TOPLEFT", etiquette, "BOTTOMLEFT", 0, 0)
    F.cout, F.argent = cout, argent
end

-- un jeton du coût, dans un emplacement de composant de la page de
-- fabrication (Professions-Slot-bg, UI-Quickslot2, contour de qualité ;
-- « possédé/requis nom » à sa droite)
function FUI.Emplacement(n)
    local K, F, C = FUI.K, FUI.h.fiche, NC.cout
    local s = CreateFrame("Frame", nil, F.cout)
    s:SetWidth(C.emplacement[1])
    s:SetHeight(C.emplacement[2])
    local b = CreateFrame("Button", nil, s)
    b:SetWidth(C.bouton)
    b:SetHeight(C.bouton)
    b:SetPoint("LEFT", s, "LEFT", 0, 0)
    local fond = b:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(fond, "professions-slot-bg", true)
    fond:SetAllPoints(b)
    b.icone = b:CreateTexture(nil, "ARTWORK")
    b.icone:SetAllPoints(b)
    b.contour = b:CreateTexture(nil, "OVERLAY")
    b.contour:SetPoint("TOPLEFT", b.icone, "TOPLEFT", -5, 4)
    b.contour:SetPoint("BOTTOMRIGHT", b.icone, "BOTTOMRIGHT", 4, -5)
    b:SetNormalTexture("Interface\\Buttons\\UI-Quickslot2")
    local cadre = b:GetNormalTexture()
    cadre:SetDrawLayer("BORDER")
    cadre:ClearAllPoints()
    cadre:SetAllPoints(b)
    local nom = s:CreateFontString(nil, "BORDER")
    nom:SetFontObject(FUI.Police("ligne", GameFontHighlight))
    nom:SetJustifyH("LEFT")
    nom:SetWidth(C.nomTaille[1])
    nom:SetHeight(C.nomTaille[2])
    nom:SetPoint("LEFT", s, "LEFT", C.nomX, 0)
    s.bouton, s.nom = b, nom
    b:SetScript("OnEnter", function(self) H.InfobulleJeton(self, self.id, self.n) end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
        local lien = select(2, GetItemInfo(self.id))
        if lien and IsModifiedClick() then HandleModifiedItemClick(lien) end
    end)
    return s
end

-- Le coût de la sélection. Ses rangées de jetons : au moins une dès qu'une
-- ligne de l'objet en coûte, pour que les lignes ne bougent pas au premier
-- coché. Rend sa hauteur.
function FUI.MajCout()
    local K, F, C, h = FUI.K, FUI.h.fiche, NC.cout, FUI.h
    local total = H.CoutSelection()
    F.argent:SetText(H.TexteCout(total))
    local jetons = {}
    for id, n in pairs(total.o) do table.insert(jetons, { id, n }) end
    table.sort(jetons, function(a, b) return a[1] < b[1] end)
    local reserve = 0
    for _, d in ipairs(S.donnees) do
        if #d.cout.o > 0 then reserve = 1 end
    end
    for i, j in ipairs(jetons) do
        local s = h.emplacements[i] or FUI.Emplacement(i)
        h.emplacements[i] = s
        local b = s.bouton
        b.id, b.n = j[1], j[2]
        local nom, _, q, _, _, _, _, _, _, texture = GetItemInfo(j[1])
        b.icone:SetTexture(texture or (GetItemIcon and GetItemIcon(j[1])) or RC.ICONE_DEFAUT)
        local ct = NC.contourJeton[q or 0]
        if ct then
            K.SetAtlas(b.contour, ct, true)
            b.contour:Show()
        else
            b.contour:Hide()
        end
        local possede = GetItemCount(j[1]) or 0
        local c = possede >= j[2] and { 1, 1, 1 } or NC.manquant
        s.nom:SetText(string.format("%d/%d %s", possede, j[2], nom or ("#" .. j[1])))
        s.nom:SetTextColor(c[1], c[2], c[3])
        poser(s, "TOPLEFT", F.argent, "BOTTOMLEFT", 0, -(i - 1) * (C.emplacement[2] + C.ecart))
        s:Show()
    end
    for i = #jetons + 1, #h.emplacements do h.emplacements[i]:Hide() end
    local rangees = math.max(#jetons, reserve)
    local hauteur = C.etiquette + C.argent + rangees * (C.emplacement[2] + C.ecart)
    F.cout:SetHeight(hauteur)
    return hauteur
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

-- RefreshBackgroundHighlightOpacity de l'onglet Compétences
function FUI.Survol(l)
    l.survol:SetAlpha((l.choisie and 0.20) or (l:IsMouseOver() and 0.10) or 0)
end

function FUI.Ligne(k)
    local K, F, St, J = FUI.K, FUI.h.fiche, NC.stat, FUI.K.Jauge
    local l = CreateFrame("Button", nil, F.zone)
    l:SetHeight(St.h)
    l:RegisterForClicks("LeftButtonUp")
    local survol = CreateFrame("Frame", nil, l)
    survol:SetAllPoints(l)
    survol:SetAlpha(0)
    local g = survol:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(g, "charactercreate-customize-dropdown-linemouseover-side", true)
    g:SetWidth(6)
    g:SetPoint("TOPLEFT", survol, "TOPLEFT", 0, 0)
    g:SetPoint("BOTTOMLEFT", survol, "BOTTOMLEFT", 0, 0)
    local d = survol:CreateTexture(nil, "BACKGROUND")
    if K.SetAtlas(d, "charactercreate-customize-dropdown-linemouseover-side", true) then
        local e = K.AtlasEntry("charactercreate-customize-dropdown-linemouseover-side")
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
    -- la case (checkbox-minimal, checkmark-minimal : l'onglet Réputation)
    local case = CreateFrame("Button", nil, l)
    case:SetWidth(St.case)
    case:SetHeight(St.case)
    case:SetPoint("LEFT", l, "LEFT", 0, 0)
    local fondCase = case:CreateTexture(nil, "BACKGROUND")
    K.SetAtlas(fondCase, "checkbox-minimal")
    fondCase:SetPoint("CENTER", case, "CENTER", 0, 0)
    case.coche = case:CreateTexture(nil, "OVERLAY")
    K.SetAtlas(case.coche, "checkmark-minimal")
    case.coche:SetPoint("CENTER", case, "CENTER", 0, 0)
    l.case = case
    -- la jauge (SkillsBarTemplate)
    local barre = CreateFrame("Frame", nil, l)
    barre:SetWidth(St.barre[1])
    barre:SetHeight(St.barre[2])
    barre:SetPoint("RIGHT", l, "RIGHT", St.barre[3], 0)
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
    l.barre = barre
    -- le nom et, dessous, le détail
    l.nom = l:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    l.nom:SetJustifyH("LEFT")
    l.nom:SetWidth(St.nomL)
    l.nom:SetHeight(15)
    l.nom:SetPoint("BOTTOMLEFT", l, "LEFT", St.nomX, 0)
    l.detail = l:CreateFontString(nil, "OVERLAY")
    l.detail:SetFontObject(FUI.Police("small2", GameFontHighlightSmall))
    l.detail:SetJustifyH("LEFT")
    l.detail:SetWidth(St.nomL)
    l.detail:SetHeight(13)
    l.detail:SetPoint("TOPLEFT", l, "LEFT", St.nomX, St.detail)
    local function basculer()
        if l.donnee and H.Choisissable(l.donnee) then
            PlaySound("igMainMenuOptionCheckBoxOn")
            H.Basculer(l.donnee.cle)
        end
    end
    local function entrer()
        FUI.Survol(l)
        if l.donnee then H.InfobulleLigne(l, l.donnee) end
    end
    local function sortir()
        FUI.Survol(l)
        GameTooltip:Hide()
    end
    for _, c in ipairs({ l, case }) do
        c:SetScript("OnClick", basculer)
        c:SetScript("OnEnter", entrer)
        c:SetScript("OnLeave", sortir)
    end
    return l
end

function FUI.RemplirLigne(l, d)
    local St = NC.stat
    l.donnee = d
    local choisissable = H.Choisissable(d)
    local sel = S.selection[d.cle] and choisissable
    local plein = d.rang >= d.max
    l.nom:SetText(H.Nom(d))
    local terne = plein or d.refuse
    l.nom:SetTextColor(terne and 0.6 or 1, terne and 0.6 or 1, terne and 0.6 or 1)
    l.detail:SetText(plein and (d.detail .. "  ·  " .. L.rangMax) or d.detail)
    if choisissable then l.case:Show() else l.case:Hide() end
    if sel then l.case.coche:Show() else l.case.coche:Hide() end
    FUI.Remplir(l.barre.rempli, d.rang / d.max, St.barre[1])
    FUI.Remplir(l.barre.attente, sel and (d.rang + 1) / d.max or 0, St.barre[1])
    if sel then
        l.barre.texte:SetText(string.format("%d (|cff20ff20+1|r) / %d", d.rang, d.max))
    else
        l.barre.texte:SetText(string.format("%d / %d", d.rang, d.max))
    end
    l.choisie = sel and true or false
    FUI.Survol(l)
end

-- Les lignes de l'objet dans la place que leur laisse le coût ; au-delà, la
-- barre de défilement paraît dans la marge droite de la fiche.
function FUI.MajLignes(hauteurCout)
    local F, St, Lz, h = FUI.h.fiche, NC.stat, NC.lignes, FUI.h
    if hauteurCout then
        F.zone:SetHeight(math.max(St.h, NC.fiche[4] + Lz[2] - NC.cout[2] - hauteurCout - Lz.ecart))
    end
    local n = #S.donnees
    local pas = St.h + St.ecart
    local visibles = math.max(1, math.floor((F.zone:GetHeight() + St.ecart) / pas))
    h.decalageLignes = math.max(0, math.min(h.decalageLignes, n - visibles))
    F.barre:Regler(n, visibles, h.decalageLignes)
    for k = 1, math.max(visibles, #h.lignes) do
        local d = S.donnees[k + h.decalageLignes]
        local l = h.lignes[k]
        if d and k <= visibles then
            if not l then
                l = FUI.Ligne(k)
                h.lignes[k] = l
            end
            poser(l, "TOPLEFT", F.zone, "TOPLEFT", 0, -(k - 1) * pas)
            l:SetWidth(F.zone:GetWidth())
            FUI.RemplirLigne(l, d)
            l:Show()
        elseif l then
            l:Hide()
        end
    end
end

function FUI.MajFiche()
    local K, F = FUI.K, FUI.h.fiche
    local n_ = NORMAL_FONT_COLOR
    if S.lien then
        local nom, _, q, niveau, _, _, _, _, _, texture = GetItemInfo(S.lien)
        SetPortraitToTexture(F.icone, texture or RC.ICONE_DEFAUT)
        local c = NC.contour[q or 1]
        if c then
            K.SetAtlas(F.contour, "auctionhouse-itemicon-border-" .. c, true)
            F.contour:Show()
        else
            F.contour:Hide()
        end
        local r, g, b = GetItemQualityColor(q or 1)
        F.nom:SetText(nom or FUI.NomDe(S.lien))
        F.nom:SetTextColor(r, g, b)
        F.sous:SetText(Remplir(L.niveau, niveau or 0))
    else
        SetPortraitToTexture(F.icone, RC.EMPLACEMENT_ROND)
        K.SetAtlas(F.contour, "auctionhouse-itemicon-border-gray", true)
        F.contour:Show()
        F.nom:SetText(L.deposer)
        F.nom:SetTextColor(n_.r, n_.g, n_.b)
        F.sous:SetText(L.choisir)
    end
    -- un refus (dépôt, amélioration) passe devant, en rouge, jusqu'au suivant
    if S.refus then
        F.sous:SetText(S.refus)
        F.sous:SetTextColor(RC.ROUGE[1], RC.ROUGE[2], RC.ROUGE[3])
    else
        F.sous:SetTextColor(1, 1, 1)
    end
    local avecLignes = #S.donnees > 0
    if avecLignes then
        F.cout:Show()
        FUI.MajLignes(FUI.MajCout())
        F.message:Hide()
    else
        F.cout:Hide()
        FUI.MajLignes()
        if S.objet and S.objet.refus then
            F.message:SetText(S.objet.refus)
            F.message:SetTextColor(RC.ROUGE[1], RC.ROUGE[2], RC.ROUGE[3])
        elseif S.lien then
            F.message:SetText(S.objet and L.aucune or L.chargement)
            F.message:SetTextColor(RC.GRIS[1], RC.GRIS[2], RC.GRIS[3])
        else
            F.message:SetText("")
        end
        F.message:Show()
    end
end

-- ------------------------------------------------------------- les boutons
function FUI.ConstruireBoutons(p)
    local K, h, B = FUI.K, FUI.h, NC.boutons
    local polices = { GameFontNormal, GameFontHighlight, GameFontDisable }
    local function bouton(texte, clic)
        local b = CreateFrame("Button", nil, p)
        b:SetWidth(B.l)
        b:SetHeight(B.h)
        b:SetFrameLevel(p:GetFrameLevel() + NC.niveaux.fiche)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        b:SetFontString(fs)
        K.BoutonTroisTranches(b, "128-redbutton", polices)
        b:SetText(texte)
        b:SetWidth(math.max(B.l, (fs:GetStringWidth() or 0) + B.marge))
        b:SetScript("OnClick", clic)
        return b
    end
    h.ameliorer = bouton(L.ameliorer, H.Ameliorer)
    h.ameliorer:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", B.droite[1], B.droite[2])
    h.annuler = bouton(L.annuler, H.Annuler)
    h.annuler:SetPoint("RIGHT", h.ameliorer, "LEFT", B.ecart, 0)
    h.tout = bouton(L.tout, H.Tout)
    h.tout:SetPoint("BOTTOMLEFT", p, "BOTTOMRIGHT", B.tout[1], B.tout[2])
end

-- les règles de la fenêtre grise (H.RendreCout)
function FUI.MajBoutons()
    local h = FUI.h
    local total = H.CoutSelection()
    H.Actif(h.ameliorer, not S.attente and total.n > 0 and H.Suffisant(total))
    H.Actif(h.annuler, total.n > 0)
    local selectionnable = false
    for _, d in ipairs(S.donnees) do
        if H.Choisissable(d) then selectionnable = true end
    end
    H.Actif(h.tout, not S.attente and selectionnable)
end

function FUI.Rendre()
    if not FUI.h then return end
    FUI.MajListe()
    FUI.MajRang()
    FUI.MajFiche()
    FUI.MajBoutons()
end

-- ---------------------------------------------------------------------------
-- Ce que le serveur nous dit
-- ---------------------------------------------------------------------------
-- Les textes de la fenêtre, dans la langue du client : ils arrivent avec ce
-- code, dans le message d'ouverture d'AIO, avant tout affichage.
function Handlers.Textes(player, textes)
    if type(textes) == "table" then TEXTES = textes end
end

-- Réponses du module C++ : chuchotements d'addon de soi à soi, préfixe du
-- canal de commandes du cœur.
local ecoute = CreateFrame("Frame")
ecoute:RegisterEvent("CHAT_MSG_ADDON")
ecoute:SetScript("OnEvent", function(_, _, prefixe, message, canal, expediteur)
    if prefixe == RC.CANAL and expediteur == UnitName("player") then
        H.Reponse(message or "")
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

-- ---------------------------------------------------------------------------
-- Ouverture : commandes, clic droit sur un jeton de puissance
-- ---------------------------------------------------------------------------
SLASH_PAPOTA_AMELIORATION1 = "/amelioration"
SLASH_PAPOTA_AMELIORATION2 = "/ameliorer"
SLASH_PAPOTA_AMELIORATION3 = "/iu"
SlashCmdList["PAPOTA_AMELIORATION"] = function() H.BasculerFenetre() end

hooksecurefunc("UseContainerItem", function(bag, slot)
    local id = H.Id(GetContainerItemLink(bag, slot))
    if not id then return end
    for _, jeton in ipairs(RC.JETONS) do
        if id == jeton then
            H.Ouvrir()
            return
        end
    end
end)
