-- ForeverUI : l'onglet du familier.
--
-- A LA DEMANDE, et non d'apres la source. camelot ne fait pas du familier un
-- onglet de la colonne : son PAPERDOLL_SIDEBARS le met en TROISIEME ONGLET
-- DU VOLET DROIT, a cote des statistiques et du gestionnaire, et son volet
-- gauche garde la silhouette du joueur. 3.3.5, lui, en fait un ecran a part
-- entiere -- PetPaperDollFrame, deuxieme de CHARACTERFRAME_SUBFRAMES -- et
-- c'est celui-la que la colonne ouvre.
--
-- CE QUI EST DEMANDE :
--   volet gauche   l'apercu en trois dimensions du familier
--   volet droit    la meme interface que les statistiques du personnage --
--                  "Niveau X <nom>", puis la categorie "General" avec
--                  Sante, Armure, Degats, Puissance d'attaque et Score
--                  critique, puis la categorie "Resistances"
--
-- CE QUE 3.3.5 DONNE, ET OU.
--
--   PetModelFrame              l'apercu, un PlayerModel que le client cale
--                              sur "pet" dans PetPaperDollFrame_Update
--   UnitHealthMax("pet")       la sante
--   PaperDollFrame_SetArmor(PetArmorFrame, "Pet")
--   PaperDollFrame_SetDamage(PetDamageFrame, "Pet")
--   PaperDollFrame_SetAttackPower(PetAttackPowerFrame, "Pet")
--                              les trois ecrivent dans <cadre>StatText, et
--                              c'est de la QU'ON LIT : le calcul et la mise
--                              en forme restent au client -- les degats
--                              s'ecrivent "45 - 62", teintes s'il y a lieu
--   UnitResistance("pet", ecole)  les resistances, l'ecole venant du
--                              GetID() de PetMagicResFrame<i>
--   NUM_PET_RESISTANCE_TYPES   combien il y en a : cinq
--
-- CE QUI DIFFERE, ET POURQUOI.
--
--   * LE SCORE CRITIQUE EST CELUI DE L'AGILITE, et rien d'autre. 3.3.5
--     n'expose pas le critique d'un familier : son ecran ne le montre pas,
--     et aucune fonction ne le rend. GetCritChanceFromAgility("pet") est ce
--     que le client porte de plus proche -- c'est meme ce dont il se sert
--     pour l'infobulle de l'agilite du familier. La valeur affichee est
--     donc la PART VENANT DE L'AGILITE, pas le total. C'est un manque,
--     signale, pas un choix.
--   * LES CINQ CARACTERISTIQUES ne sont pas montrees : la demande porte sur
--     cinq lignes nommees, et celles-la n'en font pas partie.

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI

-- Les memes mesures que les statistiques du personnage, dans
-- CharacterFrame.lua : une page du meme volet doit avoir le meme bord.
local MARGE = 20                        -- STAT_MARGE
local PAS = 13                          -- STAT_PAS, la hauteur d'une ligne
local ENTETE_H = 34                     -- STAT_ENTETE
local ENTETE_DEBORD = 5                 -- STAT_ENTETE_DEBORD
local ENTRE_GROUPES = 16                -- STAT_ENTRE_GROUPES
local HAUT = 14                         -- sous le haut du volet
local NIVEAU_H = 20
local NIVEAU_ECART = -8

-- LES FLECHES DE ROTATION, A LA MEME PLACE QUE CELLES DU PERSONNAGE.
--
-- A LA DEMANDE. Les memes mesures que poserModele, dans CharacterFrame.lua :
-- centrees sur le HAUT du volet, cote a cote, et un cran au-dessus du
-- modele pour recevoir le clic. Les deux boutons font 35 x 35 dans les deux
-- ecrans -- releve dans les XML du client -- il n'y a donc que la place qui
-- differait.
local ROTATION_Y = -12
local ROTATION_ECART = 4

local ATLAS_ENTETE = "ui-character-info-title"
local ATLAS_NIVEAU = "ui-character-info-itemlevel-bounce"
local ATLAS_FOND_SOMBRE = "ui-character-info-itemlevel-bounce"
local ATLAS_FOND_CLAIR = "ui-character-info-line-bounce"

-- La taille du volet, par construction : un contenu se batit a sa premiere
-- ouverture, qui peut preceder la pose de la fenetre.
local VOLET_L, VOLET_H = 233, 464
local VOLET_GAUCHE_L, VOLET_GAUCHE_H = 398, 464

local panneau, detail

-- ---------------------------------------------------------------- les donnees

local function aUnFamilier()
    return (HasPetUI and HasPetUI()) and UnitExists and UnitExists("pet")
end

-- LE TEXTE D'UNE LIGNE. Trois valeurs se lisent dans les cadres du client,
-- apres l'avoir fait calculer : c'est lui qui les met en forme.
local function lireDuClient(nomCadre, poser)
    local cadre = _G[nomCadre]
    if not cadre then
        return nil
    end
    if poser then
        poser(cadre, "Pet")
    end
    local texte = _G[nomCadre .. "StatText"]
    return texte and texte:GetText()
end

local function lireGeneral()
    local lignes = {}

    lignes[#lignes + 1] = {
        nom = HEALTH or "Health",
        valeur = tostring((UnitHealthMax and UnitHealthMax("pet")) or 0),
    }
    lignes[#lignes + 1] = {
        nom = ARMOR or "Armor",
        valeur = lireDuClient("PetArmorFrame", PaperDollFrame_SetArmor) or "",
    }
    lignes[#lignes + 1] = {
        nom = DAMAGE or "Damage",
        valeur = lireDuClient("PetDamageFrame", PaperDollFrame_SetDamage) or "",
    }
    -- LE NOM DE LA LIGNE : "Attack Power", et non "Power".
    --
    -- ATTACK_POWER vaut "Power" dans ce client -- releve dans ses
    -- GlobalStrings. La seule chaine qui porte exactement "Attack Power"
    -- est ATTACK_POWER_TOOLTIP, celle de l'infobulle ; c'est donc elle
    -- qu'on prend, et ATTACK_POWER ne sert plus que de dernier recours.
    lignes[#lignes + 1] = {
        nom = ATTACK_POWER_TOOLTIP or ATTACK_POWER or "Attack Power",
        valeur = lireDuClient("PetAttackPowerFrame",
            PaperDollFrame_SetAttackPower) or "",
    }

    -- ECART ASSUME : la part venant de l'agilite, faute de mieux. Voir
    -- l'entete.
    local critique = (GetCritChanceFromAgility and GetCritChanceFromAgility("pet")) or 0
    lignes[#lignes + 1] = {
        nom = MELEE_CRIT_CHANCE or "Critical Strike",
        valeur = string.format("%.2f%%", critique),
    }

    return lignes
end

local function lireResistances()
    local lignes = {}
    local combien = NUM_PET_RESISTANCE_TYPES or 5
    for rang = 1, combien do
        local cadre = _G["PetMagicResFrame" .. rang]
        local ecole = cadre and cadre.GetID and cadre:GetID()
        if ecole then
            local _, valeur = UnitResistance("pet", ecole)
            lignes[#lignes + 1] = {
                nom = _G["RESISTANCE" .. ecole .. "_NAME"] or tostring(ecole),
                valeur = tostring(valeur or 0),
            }
        end
    end
    return lignes
end

-- --------------------------------------------------------------- le volet droit

local groupes = {}
local rangees = {}

-- UNE LIGNE : le meme gabarit que StatFrameTemplate -- intitule a gauche,
-- valeur calee a droite -- et le meme fond alterne que les statistiques du
-- personnage.
local function creerLigne(rang, largeur)
    local ligne = CreateFrame("Frame", "ForeverUIPetStat" .. rang, detail)
    ligne:SetWidth(largeur)
    ligne:SetHeight(PAS)

    local fond = ligne:CreateTexture(nil, "BACKGROUND")
    fond:SetPoint("TOPLEFT", ligne, "TOPLEFT", 0, 0)
    fond:SetPoint("BOTTOMRIGHT", ligne, "BOTTOMRIGHT", 0, 0)
    ligne.fond = fond

    local intitule = ligne:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    intitule:SetJustifyH("LEFT")
    intitule:SetPoint("LEFT", ligne, "LEFT", 0, 0)
    ligne.intitule = intitule

    local valeur = ligne:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    valeur:SetJustifyH("RIGHT")
    valeur:SetPoint("RIGHT", ligne, "RIGHT", 0, 0)
    valeur:SetPoint("LEFT", intitule, "RIGHT", 4, 0)
    ligne.valeur = valeur

    rangees[rang] = ligne
    return ligne
end

local function creerEntete(rang, largeur)
    local entete = CreateFrame("Frame", "ForeverUIPetCategory" .. rang, detail)
    entete:SetWidth(largeur + 2 * ENTETE_DEBORD)
    entete:SetHeight(ENTETE_H)

    -- L'encadre de camelot, tendu : le meme que les selecteurs de categorie
    -- des statistiques du personnage.
    local fond = entete:CreateTexture(nil, "BACKGROUND")
    ForeverUI.SetAtlas(fond, ATLAS_ENTETE, true)
    fond:SetAllPoints(entete)

    local intitule = entete:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    intitule:SetPoint("CENTER", entete, "CENTER", 0, 1)
    entete.intitule = intitule

    groupes[rang] = entete
    return entete
end

-- LES RESISTANCES SONT DES ICONES, POSEES A L'HORIZONTAL.
--
-- A LA DEMANDE, et non en lignes de texte. Ce sont les CADRES DU CLIENT --
-- PetMagicResFrame1 a 5, MagicResistanceFrameTemplate, 32 x 29 -- qui
-- portent deja l'icone d'ecole, decoupee dans
-- Interface/PaperDollInfoFrame/UI-Character-ResistanceIcons, la valeur au
-- BOTTOM (0, 3) et l'infobulle que PetPaperDollFrame_SetResistances
-- compose. On les reprend donc entiers plutot que de les refaire : le
-- client garde le calcul, la teinte et l'infobulle.
--
-- Ils sont fils de l'ecran du client, que le balayage masque : on les
-- REPARENTE dans le volet droit. Ils n'y perdent rien -- ils ne portent
-- aucun de nos reglages de niveau.
--
-- Rend la hauteur occupee.
local RES_L, RES_H = 32, 29             -- MagicResistanceFrameTemplate

local function poserResistances(largeur, y)
    if PetPaperDollFrame_SetResistances then
        PetPaperDollFrame_SetResistances()
    end

    local combien = NUM_PET_RESISTANCE_TYPES or 5
    -- Ils s'etalent sur toute la largeur des lignes, a pas egaux.
    local ecart = 0
    if combien > 1 then
        ecart = (largeur - combien * RES_L) / (combien - 1)
        if ecart < 0 then
            ecart = 0
        end
    end

    for rang = 1, combien do
        local cadre = _G["PetMagicResFrame" .. rang]
        if cadre then
            cadre:SetParent(detail)
            cadre:SetWidth(RES_L)
            cadre:SetHeight(RES_H)
            cadre:ClearAllPoints()
            cadre:SetPoint("TOPLEFT", detail, "TOPLEFT",
                MARGE + (rang - 1) * (RES_L + ecart), -y)
            cadre:Show()
            for _, region in ipairs({ cadre:GetRegions() }) do
                if region.Show then
                    region:Show()
                end
            end
        end
    end

    return RES_H
end

-- UN PASSAGE : empiler l'entete de chaque categorie et ses lignes.
local function disposer()
    if not detail then
        return
    end

    local largeur = detail:GetWidth() or 0
    if largeur < 50 then
        largeur = VOLET_L
    end
    largeur = largeur - 2 * MARGE

    local blocs = {
        { nom = STAT_CATEGORY_GENERAL or "General", lignes = lireGeneral() },
        { nom = RESISTANCE or "Resistances", icones = true },
    }

    local y = HAUT

    -- "Niveau X <nom>", en tete du volet.
    local niveau = (UnitLevel and UnitLevel("pet")) or 0
    local nom = (UnitName and UnitName("pet")) or ""
    detail.niveau:SetWidth(largeur)
    detail.niveau:ClearAllPoints()
    detail.niveau:SetPoint("TOP", detail, "TOP", 0, -y)
    detail.niveau:SetText(string.format("%s %s",
        string.format(UNIT_LEVEL_TEMPLATE or "Level %d", niveau), nom))
    y = y + NIVEAU_H - NIVEAU_ECART

    local rangEntete, rangLigne = 0, 0
    for _, bloc in ipairs(blocs) do
        rangEntete = rangEntete + 1
        local entete = groupes[rangEntete] or creerEntete(rangEntete, largeur)
        entete:SetWidth(largeur + 2 * ENTETE_DEBORD)
        entete:ClearAllPoints()
        entete:SetPoint("TOPLEFT", detail, "TOPLEFT", MARGE - ENTETE_DEBORD, -y)
        entete.intitule:SetText(bloc.nom)
        entete:Show()
        y = y + ENTETE_H

        if bloc.icones then
            y = y + poserResistances(largeur, y)
        else
            for numero, donnees in ipairs(bloc.lignes) do
                rangLigne = rangLigne + 1
                local ligne = rangees[rangLigne] or creerLigne(rangLigne, largeur)
                ligne:SetWidth(largeur)
                ligne:ClearAllPoints()
                ligne:SetPoint("TOPLEFT", detail, "TOPLEFT", MARGE, -y)
                ligne.intitule:SetText(string.format(STAT_FORMAT or "%s:", donnees.nom))
                ligne.valeur:SetText(donnees.valeur)
                -- La sombre en premier, et le compte repart a chaque
                -- categorie : la meme regle que les statistiques du
                -- personnage.
                ForeverUI.SetAtlas(ligne.fond,
                    (numero % 2 == 1) and ATLAS_FOND_SOMBRE or ATLAS_FOND_CLAIR,
                    true)
                ligne:Show()
                y = y + PAS
            end
        end

        y = y + ENTRE_GROUPES
    end

    for rang = rangEntete + 1, #groupes do
        groupes[rang]:Hide()
    end
    for rang = rangLigne + 1, #rangees do
        rangees[rang]:Hide()
    end
end

local function majDetail()
    if not detail then
        return
    end
    if not aUnFamilier() then
        detail.niveau:SetText("")
        for _, entete in ipairs(groupes) do
            entete:Hide()
        end
        for _, ligne in ipairs(rangees) do
            ligne:Hide()
        end
        for rang = 1, (NUM_PET_RESISTANCE_TYPES or 5) do
            local cadre = _G["PetMagicResFrame" .. rang]
            if cadre then
                cadre:Hide()
            end
        end
        return
    end
    disposer()
end
ForeverUI.PetDetail = majDetail

-- ------------------------------------------------------------- le volet gauche

-- LE BALAYAGE. L'ecran du client s'efface -- son art, ses onglets, sa barre
-- d'experience, ses cinq caracteristiques -- mais PAS l'apercu, ni le cadre
-- qui le porte.
--
-- L'APERCU N'EST PAS FILS DE L'ECRAN, IL EST PETIT-FILS.
--
-- Releve dans le PetPaperDollFrame.xml du client : PetModelFrame, ligne
-- 208, vit dans PetPaperDollFramePetFrame, ligne 128, qui est setAllPoints
-- sur l'ecran. Un balayage qui ne regarde que les fils DIRECTS et n'epargne
-- que le modele masquait donc son PARENT -- et l'apercu avec lui, sans
-- qu'aucune ligne ne l'ait demande. C'est exactement ce qui se voyait :
-- aucun rendu en trois dimensions.
--
-- On balaie donc les deux niveaux, en epargnant a chacun ce qui porte la
-- suite.
local function balayer(cadre, epargnes)
    if not cadre then
        return
    end

    if cadre.SetBackdrop then
        cadre:SetBackdrop(nil)
    end
    for _, region in ipairs({ cadre:GetRegions() }) do
        local nature = region.GetObjectType and region:GetObjectType()
        if nature == "Texture" then
            region:SetAlpha(0)
        elseif nature == "FontString" and region.Hide then
            region:Hide()
        end
    end
    if cadre.GetChildren then
        for _, fils in ipairs({ cadre:GetChildren() }) do
            if not epargnes[fils] and fils.Hide then
                fils:Hide()
            end
        end
    end
end

local function etoufferEcranDuClient()
    local ecran = _G["PetPaperDollFrame"]
    local porteur = _G["PetPaperDollFramePetFrame"]
    local modele = _G["PetModelFrame"]
    if not ecran then
        return
    end

    balayer(ecran, { [panneau or false] = true, [porteur or false] = true,
        [modele or false] = true })
    balayer(porteur, { [modele or false] = true })

    -- PetPaperDollFrame_SetTab le masque des qu'un autre onglet du client
    -- est choisi : on le remontre, c'est lui qui porte l'apercu.
    if porteur then
        porteur:Show()
    end
end

local function majApercu()
    local modele = _G["PetModelFrame"]
    if not modele or not panneau then
        return
    end

    etoufferEcranDuClient()

    modele:ClearAllPoints()
    modele:SetPoint("TOPLEFT", panneau, "TOPLEFT", 0, 0)
    modele:SetPoint("BOTTOMRIGHT", panneau, "BOTTOMRIGHT", 0, 0)

    -- LES FLECHES sont filles du MODELE -- releve dans le
    -- PetPaperDollFrame.xml, ligne 230 -- le balayage ne les atteint donc
    -- pas. Il ne reste qu'a les poser la ou sont celles du personnage.
    local gauche = _G["PetModelFrameRotateLeftButton"]
    local droite = _G["PetModelFrameRotateRightButton"]
    if gauche and droite then
        local demi = (gauche:GetWidth() or 0) / 2 + ROTATION_ECART / 2
        local niveau = (modele:GetFrameLevel() or 0) + 2

        gauche:ClearAllPoints()
        gauche:SetPoint("TOP", panneau, "TOP", -demi, ROTATION_Y)
        gauche:SetFrameLevel(niveau)

        droite:ClearAllPoints()
        droite:SetPoint("TOP", panneau, "TOP", demi, ROTATION_Y)
        droite:SetFrameLevel(niveau)
    end

    if aUnFamilier() then
        if modele.SetUnit then
            modele:SetUnit("pet")
        end
        modele:Show()
        if gauche then gauche:Show() end
        if droite then droite:Show() end
    else
        modele:Hide()
        if gauche then gauche:Hide() end
        if droite then droite:Hide() end
    end
end
ForeverUI.PetPreview = majApercu

-- ---------------------------------------------------------- la construction

local function monter(hote)
    local cadre = _G["PetPaperDollFrame"]
    if not cadre or not hote then
        return nil, {}
    end

    cadre:ClearAllPoints()
    cadre:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, 0)
    cadre:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", 0, 0)

    if panneau then
        majApercu()
        majDetail()
        return nil, { cadre }
    end

    panneau = CreateFrame("Frame", "ForeverUIPetPane", cadre)
    panneau:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, 0)
    panneau:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", 0, 0)
    local largeur = hote:GetWidth() or 0
    if largeur < 100 then
        largeur = VOLET_GAUCHE_L
    end
    panneau:SetWidth(largeur)
    local hauteur = hote:GetHeight() or 0
    if hauteur < 100 then
        hauteur = VOLET_GAUCHE_H
    end
    panneau:SetHeight(hauteur)

    majApercu()
    majDetail()
    return nil, { cadre }
end

local function monterDetail(hote)
    if detail then
        majDetail()
        return detail, {}
    end
    if not hote then
        return nil, {}
    end

    detail = CreateFrame("Frame", "ForeverUIPetStats", hote)
    detail:SetPoint("TOPLEFT", hote, "TOPLEFT", 0, 0)
    detail:SetPoint("BOTTOMRIGHT", hote, "BOTTOMRIGHT", 0, 0)
    local largeur = hote:GetWidth() or 0
    if largeur < 50 then
        largeur = VOLET_L
    end
    detail:SetWidth(largeur)

    -- "Niveau X <nom>", sur le meme fond que la ligne de niveau du
    -- personnage.
    local fond = detail:CreateTexture(nil, "BACKGROUND")
    ForeverUI.SetAtlas(fond, ATLAS_NIVEAU, true)

    local niveau = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    niveau:SetHeight(NIVEAU_H)
    niveau:SetJustifyH("CENTER")
    niveau:SetJustifyV("MIDDLE")
    detail.niveau = niveau

    fond:SetPoint("TOP", niveau, "TOP", 0, 0)
    fond:SetPoint("BOTTOM", niveau, "BOTTOM", 0, 0)
    fond:SetPoint("LEFT", niveau, "LEFT", 0, 0)
    fond:SetPoint("RIGHT", niveau, "RIGHT", 0, 0)

    majDetail()
    return detail, {}
end

ForeverUI.PetTab = { Build = monter, BuildRight = monterDetail }

-- Le client refait son ecran dans PetPaperDollFrame_Update : on passe apres,
-- et on reprend l'apercu comme le detail.
if hooksecurefunc and type(_G["PetPaperDollFrame_Update"]) == "function" then
    hooksecurefunc("PetPaperDollFrame_Update", function()
        majApercu()
        majDetail()
    end)
end

-- CE QUI FAIT BOUGER LE FAMILIER. UNIT_PET dit qu'il change ; les trois
-- autres, que ses chiffres bougent.
local veilleur = CreateFrame("Frame")
veilleur:RegisterEvent("UNIT_PET")
veilleur:RegisterEvent("UNIT_STATS")
veilleur:RegisterEvent("UNIT_ATTACK_POWER")
veilleur:RegisterEvent("UNIT_RESISTANCES")
veilleur:SetScript("OnEvent", function()
    majApercu()
    majDetail()
end)

-- TEMOIN -- /fui familier.
function ForeverUI.PetDebug()
    local dire = function(texte)
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. texte)
    end

    dire(string.format("familier : HasPetUI=%s UnitExists=%s | niveau=%s"
        .. " nom=%s famille=%s",
        tostring(HasPetUI and HasPetUI()),
        tostring(UnitExists and UnitExists("pet")),
        tostring(UnitLevel and UnitLevel("pet")),
        tostring(UnitName and UnitName("pet")),
        tostring(UnitCreatureFamily and UnitCreatureFamily("pet"))))

    for _, donnees in ipairs(lireGeneral()) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("   %-18s %s",
            donnees.nom, tostring(donnees.valeur)))
    end
    for _, donnees in ipairs(lireResistances()) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("   %-18s %s",
            donnees.nom, tostring(donnees.valeur)))
    end

    local modele = _G["PetModelFrame"]
    dire(string.format("apercu : %s | detail : %s",
        tostring(modele and modele:IsShown()),
        tostring(detail and detail:IsShown())))
end
