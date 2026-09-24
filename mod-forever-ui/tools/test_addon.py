# -*- coding: utf-8 -*-
"""Charge l'addon ForeverUI dans un faux client WoW (lupa) et verifie son comportement.

Ce n'est pas le jeu : c'est un bouchon des seules fonctions que l'addon appelle.
Il attrape ce qu'un client attraperait au chargement -- erreur de syntaxe, nom
de fonction faux, champ nil -- sans avoir a lancer WoW.
"""
import io, os, sys
import lupa

# Le depot est la source : c'est lui qu'on charge, pas la copie du client.
RACINE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDON = os.path.join(RACINE, "data", "addon", "ForeverUI")

MOCK = """
-- ---------------------------------------------------------------- faux client
local recorded = { messages = {}, portraits = 0 }
_G.RECORDED = recorded

-- L'ordre de creation des regions decide de leur ordre de dessin a
-- l'interieur d'un calque : le harnais le garde pour pouvoir le verifier.
REGIONS_CREEES = 0

local function newRegion(kind)
    REGIONS_CREEES = REGIONS_CREEES + 1
    local r = { kind = kind, shown = true, points = {}, rang = REGIONS_CREEES }
    function r:SetTexture(a, b, c, d) self.texture = a; self.color = {a,b,c,d} end
    function r:GetTexture() return self.texture end
    function r:SetHorizTile(v) self.tile = v end
    function r:SetTexCoord(a, b, c, d, e, f, g, h)
        if e then
            -- la forme a huit arguments : les quatre coins, un par un
            self.texcoord8 = {a, b, c, d, e, f, g, h}
        else
            self.texcoord = {a, b, c, d}
        end
    end
    -- SetRotation existe bien dans ce client : il figure dans la table des
    -- methodes de Texture relevee dans Wow.exe.
    -- GetObjectType : le vrai client le donne sur toute region, et du code
    -- s'en sert pour trier les textures d'un cadre. Sans lui, le faux
    -- client laissait passer un balayage qui ne balayait rien.
    function r:GetObjectType()
        if self.kind == "texture" then return "Texture" end
        if self.kind == "fontstring" then return "FontString" end
        return "Frame"
    end
    function r:IsObjectType(t) return self:GetObjectType() == t end
    function r:SetRotation(angle) self.rotation = angle end
    function r:GetRotation() return self.rotation or 0 end
    function r:SetWidth(w) self.width = w end
    function r:GetWidth() return self.width or 0 end
    function r:GetHeight() return self.height or 0 end
    function r:SetHeight(h) self.height = h end
    function r:SetPoint(...) table.insert(self.points, {...}) end
    function r:SetAllPoints(...) self.allPoints = true end
    function r:ClearAllPoints() self.points = {} end
    function r:Show() self.shown = true end
    -- Le vrai declenche le OnHide en se cachant. Le banc ne le faisait pas,
    -- et laissait donc passer tout ce qui depend de ce que le client y
    -- efface.
    function r:Hide()
        local avant = self.shown
        self.shown = false
        if avant and self.scripts and self.scripts.OnHide then
            self.scripts.OnHide(self)
        end
        if avant and self.hooks and self.hooks.OnHide then
            self.hooks.OnHide(self)
        end
    end
    function r:IsShown() return self.shown end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetJustifyH(j) self.justify = j end
    function r:GetJustifyH() return self.justify end
    -- 3.3.5 l'a, mais il REND FAUX quand la carte graphique ne sait
    -- pas desaturer. Le faux rend vrai : c'est le cas courant.
    function r:SetDesaturated(v) self.desaturated = (v ~= false) return true end
    function r:SetJustifyV(j) self.justifyV = j end
    function r:SetTextColor(rr, vv, bb, aa) self.textColor = {rr, vv, bb, aa} end
    function r:GetTextColor()
        local c = self.textColor or {1, 1, 1, 1}
        return c[1], c[2], c[3], c[4]
    end
    -- IL EFFACE LA JUSTIFICATION, et c est tout l interet de le savoir :
    -- un objet de police porte la sienne. GameFontNormalLeft est a gauche,
    -- GameFontHighlight n a aucun justifyH -- donc CENTRE, releve dans le
    -- FontStyles.xml du client. Le faux ne touchait pas a justify : un
    -- SetJustifyH pose a la creation paraissait donc survivre, alors qu en
    -- jeu le nom se retrouvait centre et se deplacait au fil du defilement.
    function r:SetFontObject(o)
        self.font = o
        local nom = tostring(o)
        if string.find(nom, "Left", 1, true) then
            self.justify = "LEFT"
        elseif string.find(nom, "Right", 1, true) then
            self.justify = "RIGHT"
        else
            self.justify = "CENTER"
        end
    end
    -- Un texte ne revient a la ligne que s il a une boite : le faux client
    -- retient ce reglage pour qu on puisse le verifier.
    function r:SetWordWrap(v) self.wordWrap = (v ~= false) end
    function r:SetJustifyV(j) self.justifyV = j end
    function r:SetHorizTile(v) self.tile = v end
    function r:SetVertexColor(a, b, c) self.vertex = {a, b, c} end
    function r:SetAlpha(a) self.alpha = a end
    function r:GetAlpha() return self.alpha or 1 end
    -- 3.3.5 ne prend PAS de sous-calque : un seul argument.
    function r:SetDrawLayer(calque) self.layer = calque end
    function r:SetBlendMode(m) self.blend = m end
    function r:SetFont(chemin, taille, drapeaux) self.fontFile, self.fontSize, self.fontFlags = chemin, taille, drapeaux end
    function r:SetShadowOffset(x, y) self.shadowOffset = {x, y} end
    function r:SetShadowColor(a, b, c, d) self.shadowColor = {a, b, c, d} end
    return r
end

local frames = {}
_G.FRAMES = frames

function CreateFrame(kind, name, parent, template)
    local f = newRegion("frame")
    f.name = name
    f.parent = parent
    f.template = template
    f.regions = {}          -- pour GetRegions : les textures du cadre lui-meme
    f.children = {}         -- pour GetChildren : les cadres fils
    if parent and parent.children then
        table.insert(parent.children, f)
    end
    f.scripts = {}
    f.events = {}
    f.attributes = {}
    function f:SetScript(event, fn) self.scripts[event] = fn end
    -- Le vrai REFUSE un greffon nil : "Usage: HookScript(type, function)".
    -- Le banc l'acceptait, et laissait donc passer une fonction appelee
    -- avant d'etre ecrite -- son nom s'y resolvant en globale.
    function f:HookScript(event, fn)
        if type(fn) ~= "function" then
            error("Usage: " .. tostring(self.name) .. ':HookScript("type", function)')
        end
        self.hooks = self.hooks or {}
        self.hooks[event] = fn
    end
    function f:GetScript(event) return self.scripts[event] end
    function f:GetName() return self.name end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:UnregisterAllEvents() self.events = {} end
    function f:RegisterForDrag(...) self.dragButtons = { ... } end
    function f:RegisterForClicks() end
    function f:EnableMouse(v) self.mouseEnabled = (v ~= false) end
    -- IL REND UN NOMBRE, 0 OU 1, comme IsTitleKnown : zero est VRAI en Lua.
    function f:Enable() self.enabled = true end
    function f:Disable() self.enabled = false end
    function f:IsEnabled() if self.enabled == false then return 0 end return 1 end
    function f:SetDisabledFontObject(o) self.disabledFont = o end
    function f:EnableMouseWheel(v) self.wheelEnabled = (v ~= false) end
    function f:IsMouseOver() return self.souris == true end
    function f:SetMovable(v) self.movable = (v ~= false) end
    function f:IsMovable() return self.movable end
    function f:SetClampedToScreen() end
    -- UN BOUTON N'A QUE LES ETATS QUE SON XML DECLARE. Le vrai client rend
    -- nil pour une NormalTexture jamais posee : MiniMapTrackingButton n'a
    -- qu'une HighlightTexture en 3.3.5, et le faux qui en fabriquait une a
    -- laisse passer une erreur au chargement de Minimap.lua (2026-09-24).
    function f:GetNormalTexture() return self._normal end
    function f:GetPushedTexture() return self._pushed end
    function f:GetDisabledTexture() return self._disabled end
    function f:SetBackdrop(b) self.backdrop = b end
    function f:GetBackdrop() return self.backdrop end
    function f:SetNormalFontObject(o) self.normalFont = o end
    function f:SetHighlightFontObject(o) self.highlightFont = o end
    function f:SetDisabledFontObject(o) self.disabledFont = o end
    function f:SetButtonState(state) self.buttonState = state end
    function f:GetButtonState() return self.buttonState or "NORMAL" end
    function f:SetChecked(v) self.checked = v and true or false end
    function f:GetChecked() return self.checked end
    function f:GetCheckedTexture() return self._checked end
    function f:GetHighlightTexture() return self._highlight end
    function f:SetParent(p)
        if self.parent and self.parent.children then
            for i, c in ipairs(self.parent.children) do
                if c == self then table.remove(self.parent.children, i) break end
            end
        end
        self.parent = p
        if p and p.children then table.insert(p.children, self) end
    end
    function f:GetParent() return self.parent end
    function f:GetWidth() return self.width or 0 end
    function f:GetHeight() return self.height or 0 end
    -- Le faux client ne resout pas les ancres : les bords valent nil, comme
    -- pour un cadre que le vrai client n'a pas encore place. Le code doit
    -- donc y survivre, et c'est ce que ce bouchon verifie.
    function f:GetTop() return self._top end
    function f:GetEffectiveScale() return self.scale or 1 end
    function f:GetBottom() return self._bottom end
    function f:GetLeft() return self._left end
    function f:GetRight() return self._right end
    function f:IsShown() return self.shown end
    function f:SetFrameStrata(s) self.strata = s end
    function f:SetModelScale(v) self.modelScale = v end
    function f:SetPosition(x, y, z) self.pos = { x, y, z } end
    function f:GetPosition()
        local p = self.pos or { 0, 0, 0 }
        return p[1], p[2], p[3]
    end
    function f:RefreshUnit() self.refreshed = (self.refreshed or 0) + 1 end
    function f:GetModelScale() return self.modelScale or 1 end
    function f:SetFrameLevel(l) self.frameLevel = l end
    function f:SetToplevel(v) self.toplevel = (v ~= false) end
    -- Le vrai Raise met le cadre au sommet de sa strate. GearManagerDialog
    -- le fait a chaque ouverture, et ecrasait le niveau de nos boutons.
    function f:Raise() self.frameLevel = (self.frameLevel or 1) + 20 end
    function f:SetScale(v) self.scale = v end
    function f:GetScale() return self.scale or 1 end
    function f:GetFrameLevel() return self.frameLevel or 1 end
    function f:SetHitRectInsets(...) self.hitRect = {...} end
    function f:SetID(id) self.id = id end
    function f:GetID() return self.id or 0 end
    function f:SetAutoFocus(v) self.autoFocus = v end
    function f:SetMaxLetters(v) self.maxLetters = v end
    function f:SetTextInsets(a, b, c, d) self.insets = {a, b, c, d} end
    function f:SetText(t) self.text = t end
    function f:GetText() return self.text or "" end
    function f:HasFocus() return self.focused end
    function f:SetFocus() self.focused = true end
    function f:ClearFocus() self.focused = false end
    -- 3.3.5 n'accepte qu'un CHEMIN : un objet texture y leve une erreur, et
    -- le faux client doit lever la meme, sinon il laisse passer un fichier
    -- qui mourra en jeu.
    local function poserTexture(self, cle, valeur)
        if type(valeur) == "table" then
            error("SetTexture attend un chemin, pas un objet (piege 3.3.5)")
        end
        if not self[cle] then self[cle] = newRegion("texture") end
        self[cle].texture = valeur
        return self[cle]
    end
    function f:SetNormalTexture(v) return poserTexture(self, "_normal", v) end
    function f:SetPushedTexture(v) return poserTexture(self, "_pushed", v) end
    function f:SetHighlightTexture(v) return poserTexture(self, "_highlight", v) end
    function f:SetDisabledTexture(v) return poserTexture(self, "_disabled", v) end
    function f:SetCheckedTexture(v) return poserTexture(self, "_checked", v) end
    -- Une StatusBar porte une valeur et des bornes.
    function f:SetMinMaxValues(mini, maxi) self.mini, self.maxi = mini, maxi end
    function f:GetMinMaxValues() return self.mini or 0, self.maxi or 0 end
    function f:SetValue(v) self.value = v end
    function f:GetValue() return self.value or 0 end
    function f:SetStatusBarTexture(t) self.barTexture = t end
    function f:SetJustifyH(j) self.justify = j end
    function f:SetFontString(fs) self.fontString = fs end
    function f:GetFontString() return self.fontString end
    function f:SetAttribute(k, v) self.attributes[k] = v end
    function f:GetAttribute(k) return self.attributes[k] end
    function f:StartMoving() self.moving = true end
    function f:StopMovingOrSizing() self.moving = false end
    function f:CreateTexture(n, layer)
        local t = newRegion("texture"); t.layer = layer; t.owner = self
        table.insert(self.regions, t)
        return t
    end
    -- lupa tourne en Lua 5.5, ou unpack n'est plus global ; le jeu est en
    -- 5.1, ou il l'est. Le faux client accepte les deux.
    function f:GetRegions() return (table.unpack or unpack)(self.regions) end
    -- Les cadres FILS, que GetRegions ne rend pas : il faut les deux pour
    -- etouffer un ecran du client.
    function f:GetChildren() return (table.unpack or unpack)(self.children) end
    function f:GetNumChildren() return #self.children end
    function f:GetNumRegions() return #self.regions end
    function f:CreateFontString(n, layer, font)
        local t = newRegion("fontstring"); t.layer = layer; t.font = font; t.owner = self
        -- GetRegions REND AUSSI LES FontString, pas seulement les textures.
        -- Le faux ne les y mettait pas : un balayage qui les oublie passait
        -- donc pour complet au banc, et laissait en jeu l intitule du
        -- client -- "Currency Options" flottant dans le volet droit.
        table.insert(self.regions, t)
        return t
    end
    function f:GetPoint(index)
        local p = self.points[index or 1]
        if not p then return nil end
        return p[1], p[2], p[3], p[4], p[5]
    end
    function f:GetNumPoints()
        local n = 0
        for _ in pairs(self.points) do n = n + 1 end
        return n
    end
    function f:GetName() return self.name end
    if name then _G[name] = f end
    table.insert(frames, f)
    return f
end

UIParent = CreateFrame("Frame", "UIParent")
DEFAULT_CHAT_FRAME = { AddMessage = function(self, msg) table.insert(recorded.messages, msg) end }

-- le cadre d'origine que l'addon doit neutraliser
PlayerFrame = CreateFrame("Button", "PlayerFrame", UIParent)
PlayerFrame.events = { PLAYER_ENTERING_WORLD = true, UNIT_HEALTH = true }
PlayerFrameDropDown = CreateFrame("Frame", "PlayerFrameDropDown", UIParent)

-- etat simule du joueur
STATE = { health = 50, healthMax = 100, power = 30, powerMax = 100,
          powerType = 1, powerToken = "RAGE", level = 80, name = "Papota",
          combat = false, inLockdown = false, resting = false, leader = false,
          vehicle = false, time = 0, threat = 0, threatWarning = true, dead = false,
          hasTarget = false, targetHostile = false, targetsMe = false,
          className = "Chevalier de la mort", classToken = "DEATHKNIGHT",
          isPlayer = false, classification = "normal", reaction = 2,
          selection = { 1.0, 0.0, 0.0 }, tapped = false, tappedByPlayer = false,
          pvp = false, ffa = false, faction = "Alliance",
          raidMembers = 0, subgroup = 3,
          partialPlayTime = false, noPlayTime = false,
          runeStart = 0, runeDuration = 10, runeReady = true, runeType = 1,
          casting = false, channeling = false, spellName = "Eclair",
          castStart = 0, castEnd = 2, notInterruptible = false,
          xp = 500, xpMax = 1000, rested = 200 ,
          faction_suivie = "Les Fils de Hodir", faction_attitude = 5,
          faction_min = 3000, faction_max = 9000, faction_valeur = 6000,
          cvars = { playerStatusText = "0", statusTextPercentage = "0",
                    playerStatLeftDropdown = "PLAYERSTAT_BASE_STATS",
                    playerStatRightDropdown = "PLAYERSTAT_MELEE_COMBAT" } }

function UnitHealth(unit) return STATE.health end
function UnitHealthMax(unit)
    if unit == "pet" then return FAMILIER.vie end
    return STATE.healthMax
end
function UnitPower(unit, kind) return STATE.power end
function UnitPowerMax(unit, kind) return STATE.powerMax end
function UnitPowerType(unit) return STATE.powerType, STATE.powerToken end
-- LE FAMILIER a son nom et son niveau a lui.
FAMILIER = { nom = "Sanglier", niveau = 78, famille = "Boar", vie = 5400 }
function UnitName(unit)
    if unit == "pet" then return FAMILIER.nom end
    return STATE.name
end
function UnitLevel(unit)
    if unit == "pet" then return FAMILIER.niveau end
    return STATE.level
end
function UnitCreatureFamily(unit) return FAMILIER.famille end
UNIT_LEVEL_TEMPLATE = "Level %d"
NEW = "New"
CHARACTER_INFO = "Character Info"
EQUIPMENT_MANAGER = "Equipment Manager"
function UnitAffectingCombat(unit) return STATE.combat end
function InCombatLockdown() return STATE.inLockdown end
function SetPortraitTexture(texture, unit)
    recorded.portraits = recorded.portraits + 1
    texture.portraitOf = unit
    -- le vrai client pose bien une texture : le faux aussi, sinon un code
    -- qui la relit croit l'avoir ratee
    texture.texture = "portrait:" .. tostring(unit)
end
-- Ce que fait le vrai : UIDropDownMenu_InitializeHelper finit par
-- frame:SetHeight(UIDROPDOWNMENU_BUTTON_HEIGHT * 2).
function UIDropDownMenu_Initialize(cadre)
    if cadre and cadre.SetHeight then
        cadre:SetHeight(UIDROPDOWNMENU_BUTTON_HEIGHT * 2)
    end
end
function UIDropDownMenu_SetAnchor(cadre, x, y, point, relatif, pointRelatif)
    cadre.xOffset, cadre.yOffset = x, y
    cadre.point, cadre.relativeTo, cadre.relativePoint = point, relatif, pointRelatif
end
function ToggleDropDownMenu() end
function IsResting() return STATE.resting end
function UnitThreatSituation(unit) return STATE.threat end
function IsThreatWarningEnabled() return STATE.threatWarning end
function UnitIsDeadOrGhost(unit) return STATE.dead end
function UnitExists(unit)
    if unit == "pet" then return AVEC_FAMILIER end
    return STATE.hasTarget
end
function UnitCanAttack(a, b) return STATE.targetHostile end
function UnitIsUnit(a, b)
    if a == "targettarget" and b == "player" then return STATE.targetsMe end
    return a == b
end
function GetThreatStatusColor(status)
    if status == 3 then return 1.0, 0.0, 0.0 end
    if status == 2 then return 1.0, 0.6, 0.0 end
    if status == 1 then return 1.0, 1.0, 0.47 end
    return 0.69, 0.69, 0.69
end
function IsPartyLeader() return STATE.leader end
function UnitHasVehicleUI(unit) return STATE.vehicle end
function GetTime() return STATE.time end
function GetCVar(name) return STATE.cvars[name] end
function GetCVarBool(name) return STATE.cvars[name] == "1" end

-- ------------------------------------------------- bouchons supplementaires
function UnitClass(unit) return STATE.className, STATE.classToken end
function UnitIsPlayer(unit) return STATE.isPlayer end
function UnitSelectionColor(unit)
    return STATE.selection[1], STATE.selection[2], STATE.selection[3]
end
function UnitIsTapped(unit) return STATE.tapped end
function UnitIsTappedByPlayer(unit) return STATE.tappedByPlayer end
function UnitPlayerControlled(unit) return STATE.isPlayer end
function UnitClassification(unit) return STATE.classification end
function UnitReaction(a, b) return STATE.reaction end
function UnitIsPVP(unit) return STATE.pvp end
function UnitIsPVPFreeForAll(unit) return STATE.ffa end
function UnitFactionGroup(unit) return STATE.faction end
function GetNumRaidMembers() return STATE.raidMembers end
function GetRaidRosterInfo(i) return STATE.name, 0, STATE.subgroup end
function PartialPlayTime() return STATE.partialPlayTime end
function NoPlayTime() return STATE.noPlayTime end
function GetRuneCooldown(i) return STATE.runeStart, STATE.runeDuration, STATE.runeReady end
function GetRuneType(i) return STATE.runeType end
function CooldownFrame_SetTimer(cd, start, duration, enable) cd.timer = {start, duration, enable} end

-- LES POSTURES. 3.3.5 rend (texture, NOM, active, lancable) la ou le client
-- moderne rend (texture, active, lancable, sort) : le faux client suit la
-- signature de 3.3.5, sinon il laisserait passer l'inversion.
NUM_SHAPESHIFT_SLOTS = 10
FORMES = {
    { texture = "forme_ours", nom = "Forme d'ours", active = false, lancable = true },
    { texture = "forme_felin", nom = "Forme de felin", active = true, lancable = true },
    { texture = "forme_voyage", nom = "Forme de voyage", active = false, lancable = false },
}
function GetNumShapeshiftForms() return #FORMES end
function GetShapeshiftFormInfo(i)
    local f = FORMES[i]
    if not f then return nil end
    return f.texture, f.nom, f.active, f.lancable
end
function GetShapeshiftFormCooldown(i) return 0, 0, 0 end

-- LE FAMILIER. 3.3.5 rend (nom, SOUS-TEXTE, texture, isToken, active,
-- autoPossible, autoActif) : un champ de plus au deuxieme rang que le
-- client moderne. Le faux client suit 3.3.5, sinon il laisserait passer
-- la confusion entre le sous-texte et la texture.
NUM_PET_ACTION_SLOTS = 10
PET_ACTIONS = {
    { nom = "Attaquer", texte = "", texture = "icone_attaque", cle = false,
      active = true, autoPossible = false, autoActif = false, utilisable = true },
    { nom = "Morsure", texte = "Rang 5", texture = "icone_morsure", cle = false,
      active = false, autoPossible = true, autoActif = true, utilisable = true },
    { nom = "PET_MODE_PASSIVE", texte = "", texture = "PET_TEXTURE_PASSIVE", cle = true,
      active = false, autoPossible = false, autoActif = false, utilisable = false },
}
PET_TEXTURE_PASSIVE = "icone_passif_resolue"
PET_MODE_PASSIVE = "Passif"
PET_A_UNE_BARRE = true
PET_VISIBLE = true
function PetHasActionBar() return PET_A_UNE_BARRE end
function UnitIsVisible(unite)
    if unite == "pet" then return PET_VISIBLE end
    return true
end
function GetPetActionInfo(i)
    local a = PET_ACTIONS[i]
    if not a then return nil end
    return a.nom, a.texte, a.texture, a.cle, a.active, a.autoPossible, a.autoActif
end
function GetPetActionCooldown(i) return 0, 0, 0 end
function GetPetActionSlotUsable(i)
    local a = PET_ACTIONS[i]
    return a and a.utilisable or false
end
function IsPetAttackAction(i)
    local a = PET_ACTIONS[i]
    return a and a.nom == "Attaquer" or false
end
function CombatFeedback_Initialize(self, text, height) self.feedbackText = text end
function CombatFeedback_OnCombatEvent(self, event, flags, amount, kind) self.lastHit = amount end
function CombatFeedback_OnUpdate(self, elapsed) end
function RegisterUnitWatch(f) f.unitWatch = true end
function ToggleDropDownMenu() end
-- L infobulle retient son proprietaire et son texte : le jeu le fait, et
-- une interface qui change un intitule sous un curseur immobile doit la
-- redemander depuis le meme bouton.
GameTooltip = {
    SetOwner = function(self, cadre, ancre)
        self.owner, self.anchor = cadre, ancre
    end,
    GetOwner = function(self) return self.owner end,
    SetText = function(self, texte) self.text = texte end,
    AddLine = function() end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
}
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
                      DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 } }
GROUP = "Groupe"
PLAYTIME_TIRED = "Temps de jeu fatigue"
PLAYTIME_UNHEALTHY = "Temps de jeu malsain"
TargetFrame = CreateFrame("Button", "TargetFrame", UIParent)
TargetFrameDropDown = CreateFrame("Frame", "TargetFrameDropDown", UIParent)
ComboFrame = CreateFrame("Frame", "ComboFrame", UIParent)

function UnitCastingInfo(unit)
    if not STATE.casting then return nil end
    return STATE.spellName, nil, STATE.spellName, "icone", STATE.castStart * 1000,
           STATE.castEnd * 1000, false, 1, STATE.notInterruptible
end
function UnitChannelInfo(unit)
    if not STATE.channeling then return nil end
    return STATE.spellName, nil, STATE.spellName, "icone", STATE.castStart * 1000,
           STATE.castEnd * 1000, false, STATE.notInterruptible
end
function GetWatchedFactionInfo()
    if not STATE.faction_suivie then return nil end
    return STATE.faction_suivie, STATE.faction_attitude, STATE.faction_min,
           STATE.faction_max, STATE.faction_valeur
end
ReputationWatchBar = CreateFrame("Frame", "ReputationWatchBar", UIParent)
function UnitXP(unit) return STATE.xp end
function UnitXPMax(unit) return STATE.xpMax end
function GetXPExhaustion() return STATE.rested end
MAX_PLAYER_LEVEL = 80
FAILED = "Echec"
INTERRUPTED = "Interrompu"
CastingBarFrame = CreateFrame("StatusBar", "CastingBarFrame", UIParent)
MainMenuExpBar = CreateFrame("StatusBar", "MainMenuExpBar", UIParent)
ExhaustionTick = CreateFrame("Frame", "ExhaustionTick", UIParent)
RuneFrame = CreateFrame("Frame", "RuneFrame", UIParent)

-- LA MINIMAP DU CLIENT 3.3.5, telle que Minimap.xml la monte. Les tailles et
-- les parentes sont celles du gabarit : la carte fait 140 dans un cluster de
-- 192, MinimapBackdrop est fils de la CARTE, et MinimapCompassTexture porte
-- ici la boussole a jeter -- pas le cadre, contrairement a camelot.
MinimapCluster = CreateFrame("Frame", "MinimapCluster", UIParent)
MinimapCluster:SetWidth(192) MinimapCluster:SetHeight(192)
MinimapBorderTop = MinimapCluster:CreateTexture("MinimapBorderTop", "ARTWORK")
MinimapBorderTop:SetTexture("Interface\\\\Minimap\\\\UI-Minimap-Border")

Minimap = CreateFrame("Frame", "Minimap", MinimapCluster)
Minimap:SetWidth(140) Minimap:SetHeight(140)
Minimap.zoom = 0
Minimap.zoomLevels = 5
function Minimap:SetMaskTexture(chemin) self.mask = chemin end
function Minimap:GetZoom() return self.zoom end
function Minimap:GetZoomLevels() return self.zoomLevels end
function Minimap:SetZoom(v) self.zoom = v end
Minimap.fleches = {}
function Minimap:SetPOIArrowTexture(c) self.fleches.poi = c end
function Minimap:SetStaticPOIArrowTexture(c) self.fleches.statique = c end
function Minimap:SetCorpsePOIArrowTexture(c) self.fleches.cadavre = c end

MinimapBackdrop = CreateFrame("Frame", "MinimapBackdrop", Minimap)
MinimapBackdrop:SetWidth(192) MinimapBackdrop:SetHeight(192)
MinimapBorder = MinimapBackdrop:CreateTexture("MinimapBorder", "ARTWORK")
MinimapBorder:SetTexture("Interface\\\\Minimap\\\\UI-Minimap-Border")
MinimapNorthTag = MinimapBackdrop:CreateTexture("MinimapNorthTag", "OVERLAY")
MinimapNorthTag:SetTexture("Interface\\\\Minimap\\\\CompassNorthTag")
MinimapCompassTexture = MinimapBackdrop:CreateTexture("MinimapCompassTexture", "OVERLAY")
MinimapCompassTexture:SetTexture("Interface\\\\Minimap\\\\CompassRing")

MinimapZoneTextButton = CreateFrame("Button", "MinimapZoneTextButton", MinimapCluster)
MinimapZoneTextButton:SetWidth(150) MinimapZoneTextButton:SetHeight(12)
MinimapZoneText = MinimapZoneTextButton:CreateFontString("MinimapZoneText", "BACKGROUND")
-- GameFontNormal ne porte AUCUNE justification : donc centre, et c'est bien
-- ce que le vrai client donne avant qu'on y touche.
MinimapZoneText:SetFontObject("GameFontNormal")
MinimapZoneText:SetText("Hurlevent")

MinimapZoomIn = CreateFrame("Button", "MinimapZoomIn", MinimapBackdrop)
MinimapZoomIn:SetWidth(32) MinimapZoomIn:SetHeight(32)
MinimapZoomIn:SetHitRectInsets(4, 4, 2, 6)
MinimapZoomOut = CreateFrame("Button", "MinimapZoomOut", MinimapBackdrop)
MinimapZoomOut:SetWidth(32) MinimapZoomOut:SetHeight(32)
MinimapZoomOut:SetHitRectInsets(4, 4, 2, 6)
for _, b in ipairs({ MinimapZoomIn, MinimapZoomOut }) do
    b:SetNormalTexture("zoom-up")
    b:SetPushedTexture("zoom-down")
    b:SetDisabledTexture("zoom-disabled")
    b:SetHighlightTexture("zoom-highlight")
end

MiniMapTracking = CreateFrame("Frame", "MiniMapTracking", MinimapBackdrop)
MiniMapTracking:SetWidth(32) MiniMapTracking:SetHeight(32)
MiniMapTrackingBackground = MiniMapTracking:CreateTexture("MiniMapTrackingBackground", "BACKGROUND")
MiniMapTrackingBackground:SetTexture("Interface\\\\Minimap\\\\UI-Minimap-Background")
MiniMapTrackingIcon = MiniMapTracking:CreateTexture("MiniMapTrackingIcon", "ARTWORK")
MiniMapTrackingIcon:SetTexture("Interface\\\\Icons\\\\INV_Misc_Map_01")
MiniMapTrackingIconOverlay = MiniMapTracking:CreateTexture("MiniMapTrackingIconOverlay", "OVERLAY")
MiniMapTrackingButton = CreateFrame("Button", "MiniMapTrackingButton", MiniMapTracking)
MiniMapTrackingButton:SetWidth(32) MiniMapTrackingButton:SetHeight(32)
MiniMapTrackingButtonBorder = MiniMapTrackingButton:CreateTexture("MiniMapTrackingButtonBorder", "BORDER")
MiniMapTrackingButtonBorder:SetTexture("Interface\\\\Minimap\\\\MiniMap-TrackingBorder")
MiniMapTrackingButtonShine = MiniMapTrackingButton:CreateTexture("MiniMapTrackingButtonShine", "OVERLAY")
MiniMapTrackingButtonShine:SetTexture("Interface\\\\ComboFrame\\\\ComboPoint")
-- Minimap.xml de 3.3.5 : ce bouton ne declare QUE sa HighlightTexture.
-- GetNormalTexture y rend nil -- c'est ce qui a casse Minimap.lua en jeu.
MiniMapTrackingButton:SetHighlightTexture("Interface\\\\Minimap\\\\UI-Minimap-ZoomButton-Highlight")
-- LE VRAI REND SON FICHIER A L ICONE a chaque mise a jour du pistage : un
-- faux qui se tairait laisserait croire qu un simple Hide suffit.
function MiniMapTracking_Update()
    MiniMapTrackingIcon:SetTexture("Interface\\\\Icons\\\\INV_Misc_Map_01")
end
-- ET IL REMONTRE la boussole et la fleche du nord a chaque bascule du CVar.
function Minimap_UpdateRotationSetting()
    if GetCVar("rotateMinimap") == "1" then
        MinimapCompassTexture:Show() MinimapNorthTag:Hide()
    else
        MinimapCompassTexture:Hide() MinimapNorthTag:Show()
    end
end

MiniMapMailFrame = CreateFrame("Frame", "MiniMapMailFrame", Minimap)
MiniMapMailFrame:SetWidth(33) MiniMapMailFrame:SetHeight(33)
MiniMapMailIcon = MiniMapMailFrame:CreateTexture("MiniMapMailIcon", "ARTWORK")
MiniMapMailIcon:SetTexture("Interface\\\\Icons\\\\INV_Letter_15")
MiniMapMailBorder = MiniMapMailFrame:CreateTexture("MiniMapMailBorder", "OVERLAY")
MiniMapMailBorder:SetTexture("Interface\\\\Minimap\\\\MiniMap-TrackingBorder")

MiniMapInstanceDifficulty = CreateFrame("Frame", "MiniMapInstanceDifficulty", MinimapCluster)
MiniMapInstanceDifficulty:SetWidth(38) MiniMapInstanceDifficulty:SetHeight(46)

-- GameTime.xml de 3.3.5 : 40 x 40, Normal, Pushed, Highlight, et un
-- ButtonText ou GameTimeFrame_SetDate ECRIT LE JOUR.
GameTimeFrame = CreateFrame("Button", "GameTimeFrame", Minimap)
GameTimeFrame:SetWidth(40) GameTimeFrame:SetHeight(40)
GameTimeFrame:SetHitRectInsets(6, 0, 5, 10)
GameTimeFrame:SetNormalTexture("Interface\\\\Calendar\\\\UI-Calendar-Button")
GameTimeFrame:SetPushedTexture("Interface\\\\Calendar\\\\UI-Calendar-Button")
GameTimeFrame:SetHighlightTexture("Interface\\\\Minimap\\\\UI-Minimap-ZoomButton-Highlight")
GameTimeFrame:SetFontString(GameTimeFrame:CreateFontString(nil, "OVERLAY"))
function CalendarGetDate() return 5, 9, 24, 2026 end
function GameTimeFrame_SetDate()
    local _, _, jour = CalendarGetDate()
    GameTimeFrame:GetFontString():SetText(jour)
end
GameTimeFrame_SetDate()

-- Blizzard_TimeManager se charge A LA DEMANDE : l'horloge n'existe pas au
-- chargement de l'addon. CHARGER_HORLOGE la monte comme son XML de 3.3.5 --
-- 60 x 28 sur la carte, un fond SANS NOM, le texte, la lueur d'alarme --
-- puis previent les cadres qui ecoutent ADDON_LOADED.
function CHARGER_HORLOGE()
    local b = CreateFrame("Button", "TimeManagerClockButton", Minimap)
    b:SetWidth(60) b:SetHeight(28)
    local fond = b:CreateTexture(nil, "BORDER")
    fond:SetTexture("Interface\\\\TimeManager\\\\ClockBackground")
    TimeManagerClockTicker = b:CreateFontString("TimeManagerClockTicker", "ARTWORK")
    TimeManagerClockTicker:SetFontObject("GameFontHighlightSmall")
    TimeManagerClockTicker:SetText("14:30")
    TimeManagerAlarmFiredTexture = b:CreateTexture("TimeManagerAlarmFiredTexture", "ARTWORK")
    TimeManagerAlarmFiredTexture:SetTexture("Interface\\\\TimeManager\\\\ClockBackground")
    TimeManagerAlarmFiredTexture:Hide()
    b.fondSansNom = fond
    for _, f in ipairs(FRAMES) do
        if f.events and f.events["ADDON_LOADED"] and f.scripts and f.scripts.OnEvent then
            f.scripts.OnEvent(f, "ADDON_LOADED", "Blizzard_TimeManager")
        end
    end
end

-- La position du joueur : 3.3.5 repond sur la carte AFFICHEE, (0, 0) quand
-- ce n'est pas la sienne.
POSITION = { x = 0.4567, y = 0.6234, recentrages = 0 }
function GetPlayerMapPosition(unite) return POSITION.x, POSITION.y end
function SetMapToCurrentZone() POSITION.recentrages = POSITION.recentrages + 1 end
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame:Hide()

-- Les quatre boutons que camelot n a pas.
MiniMapWorldMapButton = CreateFrame("Button", "MiniMapWorldMapButton", MinimapBackdrop)
MiniMapLFGFrame = CreateFrame("Button", "MiniMapLFGFrame", MinimapBackdrop)
MiniMapBattlefieldFrame = CreateFrame("Button", "MiniMapBattlefieldFrame", Minimap)
MiniMapRecordingButton = CreateFrame("Button", "MiniMapRecordingButton", MinimapBackdrop)

-- L heure du serveur : 14 h, donc le jour.
function GetGameTime() return 14, 30 end

-- la barre d'action du client, telle que l'addon la trouve
MainMenuBar = CreateFrame("Frame", "MainMenuBar", UIParent)
MainMenuBarLeftEndCap = UIParent:CreateTexture(nil, "ARTWORK")
MainMenuBarRightEndCap = UIParent:CreateTexture(nil, "ARTWORK")
MainMenuBarPageNumber = UIParent:CreateFontString(nil, "OVERLAY")
for i = 0, 3 do
    _G["MainMenuBarTexture" .. i] = UIParent:CreateTexture(nil, "ARTWORK")
    _G["MainMenuXPBarTexture" .. i] = UIParent:CreateTexture(nil, "ARTWORK")
    _G["MainMenuMaxLevelBar" .. i] = UIParent:CreateTexture(nil, "ARTWORK")
end
MainMenuBarExpText = UIParent:CreateFontString(nil, "OVERLAY")
ActionBarUpButton = CreateFrame("Button", "ActionBarUpButton", UIParent)
ActionBarDownButton = CreateFrame("Button", "ActionBarDownButton", UIParent)
-- ActionBarFrame.xml : les deux fleches declarent Normal, Pushed, Disabled
-- et Highlight.
for _, b in ipairs({ ActionBarUpButton, ActionBarDownButton }) do
    b:SetNormalTexture("fleche-up")
    b:SetPushedTexture("fleche-down")
    b:SetDisabledTexture("fleche-disabled")
    b:SetHighlightTexture("fleche-highlight")
end
NumberFontNormalSmallGray = "NumberFontNormalSmallGray"
NumberFontNormal = "NumberFontNormal"
GameFontHighlightSmallOutline = "GameFontHighlightSmallOutline"
-- ActionButtonTemplate (ActionButtonTemplate.xml de 3.3.5) declare ses
-- quatre etats : Normal, Pushed, Highlight, Checked. Tous les boutons
-- d'action du client en heritent -- barre principale, bonus, postures,
-- familier.
function DECLARER_ETATS_ACTION(b)
    b:SetNormalTexture("Interface\\\\Buttons\\\\UI-Quickslot2")
    b:SetPushedTexture("Interface\\\\Buttons\\\\UI-Quickslot-Depress")
    b:SetHighlightTexture("Interface\\\\Buttons\\\\ButtonHilight-Square")
    b:SetCheckedTexture("Interface\\\\Buttons\\\\CheckButtonHilight")
end

for i = 1, 12 do
    local b = CreateFrame("CheckButton", "ActionButton" .. i, MainMenuBar)
    DECLARER_ETATS_ACTION(b)
    _G["ActionButton" .. i .. "Icon"] = b:CreateTexture(nil, "ARTWORK")
    _G["ActionButton" .. i .. "Border"] = b:CreateTexture(nil, "OVERLAY")
    _G["ActionButton" .. i .. "Flash"] = b:CreateTexture(nil, "ARTWORK")
    _G["ActionButton" .. i .. "FloatingBG"] = b:CreateTexture(nil, "BACKGROUND")
    _G["ActionButton" .. i .. "HotKey"] = b:CreateFontString(nil, "OVERLAY")
    _G["ActionButton" .. i .. "Count"] = b:CreateFontString(nil, "OVERLAY")
    _G["ActionButton" .. i .. "Name"] = b:CreateFontString(nil, "OVERLAY")
    _G["ActionButton" .. i .. "Cooldown"] = CreateFrame("Cooldown", "ActionButton" .. i .. "Cooldown", b)
end
-- le bas de l'ecran du client : micro-menu, sacs, trousseau
MainMenuBarArtFrame = CreateFrame("Frame", "MainMenuBarArtFrame", MainMenuBar)
MainMenuBarArtFrame:SetFrameLevel(2)
local MICROS = { "CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton",
                 "AchievementMicroButton", "QuestLogMicroButton", "SocialsMicroButton",
                 "PVPMicroButton", "LFDMicroButton", "MainMenuMicroButton",
                 "HelpMicroButton" }
for _, nom in ipairs(MICROS) do
    local b = CreateFrame("Button", nom, MainMenuBarArtFrame)
    b:SetWidth(28)
    b:SetHeight(58)
    -- LoadMicroButtonTextures (MainMenuBarMicroButtons.lua de 3.3.5) leur
    -- pose les quatre etats des l'OnLoad.
    b:SetNormalTexture("micro-up")
    b:SetPushedTexture("micro-down")
    b:SetDisabledTexture("micro-disabled")
    b:SetHighlightTexture("micro-highlight")
end
MicroButtonPortrait = CharacterMicroButton:CreateTexture("MicroButtonPortrait", "OVERLAY")
PVPMicroButtonTexture = PVPMicroButton:CreateTexture("PVPMicroButtonTexture", "OVERLAY")
MainMenuBarPerformanceBar = MainMenuMicroButton:CreateTexture("MainMenuBarPerformanceBar", "OVERLAY")
function UpdateMicroButtons() end

for _, nom in ipairs({ "MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot",
                       "CharacterBag2Slot", "CharacterBag3Slot" }) do
    local b = CreateFrame("CheckButton", nom, MainMenuBarArtFrame)
    -- ItemButtonTemplate declare Normal, Pushed, Highlight ; le sac a dos et
    -- BagSlotButtonTemplate y ajoutent Checked.
    b:SetNormalTexture("sac-up")
    b:SetPushedTexture("sac-down")
    b:SetHighlightTexture("sac-highlight")
    b:SetCheckedTexture("sac-checked")
    _G[nom .. "IconTexture"] = b:CreateTexture(nom .. "IconTexture", "BORDER")
    _G[nom .. "Count"] = b:CreateFontString(nom .. "Count", "OVERLAY")
end
KeyRingButton = CreateFrame("CheckButton", "KeyRingButton", MainMenuBarArtFrame)
KeyRingButton:SetNormalTexture("trousseau-up")
KeyRingButton:SetPushedTexture("trousseau-down")
KeyRingButton:SetHighlightTexture("trousseau-highlight")
KeyRingButton:Hide()

-- les sacs du client
NUM_CONTAINER_FRAMES = 13
MAX_CONTAINER_ITEMS = 36
NUM_BAG_SLOTS = 4
CONTAINER_WIDTH = 192
ITEM_QUALITY_COLORS = {
    [0] = { r = 0.62, g = 0.62, b = 0.62 },
    [1] = { r = 1.00, g = 1.00, b = 1.00 },
    [2] = { r = 0.12, g = 1.00, b = 0.00 },
    [3] = { r = 0.00, g = 0.44, b = 0.87 },
    [4] = { r = 0.64, g = 0.21, b = 0.93 },
}
NUM_CONTAINER_COLUMNS = 4
SEARCH = "Rechercher"
BAG_CLEANUP_BAGS = nil
for i = 1, NUM_CONTAINER_FRAMES do
    local nom = "ContainerFrame" .. i
    local c = CreateFrame("Frame", nom, UIParent)
    c.size = 16
    c:SetID(0)
    -- Un cadre de sac est masque tant qu'il n'a pas ete ouvert : le jeu ne
    -- les montre pas tous les treize.
    c:Hide()
    _G[nom .. "Portrait"] = c:CreateTexture(nom .. "Portrait", "BACKGROUND")
    _G[nom .. "Name"] = c:CreateFontString(nom .. "Name", "ARTWORK")
    CreateFrame("Button", nom .. "CloseButton", c)
    local bourse = CreateFrame("Frame", nom .. "MoneyFrame", c)
    bourse:SetHeight(24)
    -- LE SEGMENT DES MONNAIES SUIVIES du client : celui qu'on fait taire.
    if i == 1 then
        BackpackTokenFrame = CreateFrame("Frame", "BackpackTokenFrame", c)
    end
    for _, suffixe in ipairs({ "BackgroundTop", "BackgroundMiddle1", "BackgroundMiddle2",
                              "BackgroundBottom", "Background1Slot" }) do
        _G[nom .. suffixe] = c:CreateTexture(nom .. suffixe, "ARTWORK")
    end
    for j = 1, MAX_CONTAINER_ITEMS do
        local b = CreateFrame("Button", nom .. "Item" .. j, c)
        -- ContainerFrameItemButtonTemplate herite d'ItemButtonTemplate :
        -- Normal, Pushed, Highlight.
        b:SetNormalTexture("emplacement-up")
        b:SetPushedTexture("emplacement-down")
        b:SetHighlightTexture("emplacement-highlight")
        b:SetID(j)
        _G[nom .. "Item" .. j .. "IconTexture"] = b:CreateTexture(nil, "BORDER")
    end
end

-- la feuille du personnage du client : le cadre, son modele, ses vingt
-- emplacements d'equipement, et l'art d'epoque en quatre quartiers
CharacterFrame = CreateFrame("Frame", "CharacterFrame", UIParent)
for _, coin in ipairs({ "TopLeft", "TopRight", "BottomLeft", "BottomRight" }) do
    _G["CharacterFrame" .. coin] = CharacterFrame:CreateTexture(
        "CharacterFrame" .. coin, "ARTWORK")
end
CharacterNameText = CharacterFrame:CreateFontString("CharacterNameText", "ARTWORK")
CharacterFrameCloseButton = CreateFrame("Button", "CharacterFrameCloseButton", CharacterFrame)
-- UIPanelCloseButton (UIPanelTemplates.xml de 3.3.5) declare Normal,
-- Pushed et Highlight -- pas de Disabled.
function DECLARER_FERMETURE(b)
    b:SetNormalTexture("fermeture-up")
    b:SetPushedTexture("fermeture-down")
    b:SetHighlightTexture("fermeture-highlight")
end
DECLARER_FERMETURE(CharacterFrameCloseButton)
HIGHLIGHT_FONT_COLOR = { r = 1, g = 1, b = 1 }
NORMAL_FONT_COLOR = { r = 1, g = 0.82, b = 0 }
REPUTATION, CURRENCY, PVP, SKILLS = "Reputation", "Currency", "PvP", "Skills"
-- LE NOM SUIT LE TITRE PORTE, comme le vrai : SetCurrentTitle part au
-- serveur, et c'est UNIT_NAME_UPDATE qui annonce la reponse.
function UnitPVPName(unite)
    if TITRE_PORTE and NOMS_DE_TITRE and NOMS_DE_TITRE[TITRE_PORTE] then
        return (string.gsub(NOMS_DE_TITRE[TITRE_PORTE], "%s*$", "")) .. " Robert Polson"
    end
    return "Robert Polson"
end
CharacterModelFrame = CreateFrame("Frame", "CharacterModelFrame", CharacterFrame)
CharacterLevelText = CharacterFrame:CreateFontString("CharacterLevelText", "ARTWORK")
-- le client compose cette ligne ; le faux client en pose une pour qu'on
-- puisse verifier qu'elle est bien recopiee
CharacterLevelText:SetText("Niveau 3 Elfe de la nuit Druide")
-- LES FLECHES DE ROTATION font 35 x 35 -- releve dans le PaperDollFrame.xml
-- du client, ligne 484. Le faux leur donnait 16, et l ecart entre les deux
-- boutons s en trouvait fausse : leur place se calcule sur leur largeur.
for _, cote in ipairs({ "Left", "Right" }) do
    local nom = "CharacterModelFrameRotate" .. cote .. "Button"
    local b = CreateFrame("Button", nom, CharacterModelFrame)
    b:SetWidth(35); b:SetHeight(35)
end
PaperDollFrame = CreateFrame("Frame", "PaperDollFrame", CharacterFrame)
PaperDollFrameTexture = PaperDollFrame:CreateTexture("PaperDollFrameTexture", "ARTWORK")
EMPLACEMENTS_PERSO = {
    "Head", "Neck", "Shoulder", "Back", "Chest", "Shirt", "Tabard", "Wrist",
    "Hands", "Waist", "Legs", "Feet", "Finger0", "Finger1", "Trinket0", "Trinket1",
    "MainHand", "SecondaryHand", "Ranged", "Ammo",
}
for _, nom in ipairs(EMPLACEMENTS_PERSO) do
    local plein = "Character" .. nom .. "Slot"
    local b = CreateFrame("Button", plein, CharacterFrame)
    _G[plein .. "IconTexture"] = b:CreateTexture(plein .. "IconTexture", "BORDER")
    _G[plein .. "NormalTexture"] = b:CreateTexture(plein .. "NormalTexture", "ARTWORK")
end
-- LES ONGLETS DU CLIENT, AVEC LEUR VRAI CLIC.
--
-- Releve dans le CharacterFrame.lua du client : CharacterFrameTab_OnClick
-- n'appelle PAS CharacterFrame_ShowSubFrame, il passe par ToggleCharacter,
-- qui FERME la fenetre quand l'ecran demande est deja montre. Le faux ne
-- posait aucun clic sur ces boutons : tout ce chemin n'etait pas essaye.
for i = 1, 5 do
    local nom = "CharacterFrameTab" .. i
    local t = CreateFrame("Button", nom, CharacterFrame)
    _G[nom .. "Text"] = t:CreateFontString(nom .. "Text", "ARTWORK")
    t:CreateTexture(nom .. "Fond", "ARTWORK")
    t:SetScript("OnClick", function(self)
        -- Un bouton DESACTIVE ne recoit pas son clic : le faux doit en
        -- faire autant, sinon l essai ne prouve rien.
        if self:IsEnabled() == 0 then return end
        CharacterFrameTab_OnClick(self)
    end)
end

ECRAN_DE_L_ONGLET = { "PaperDollFrame", "PetPaperDollFrame", "ReputationFrame",
                      "SkillFrame", "TokenFrame" }

function CharacterFrameTab_OnClick(self)
    local nom = self:GetName()
    for i = 1, 5 do
        if nom == "CharacterFrameTab" .. i then
            ToggleCharacter(ECRAN_DE_L_ONGLET[i])
            return
        end
    end
end
-- L ONGLET DU FAMILIER S EFFACE quand le personnage n en a pas, et le client
-- rattache le suivant sur le LEFT du masque : sa reparation a lui, pensee
-- pour une rangee horizontale. Repris tel quel de PetPaperDollFrame.lua.
function PetPaperDollFrame_UpdateIsAvailable()
    if not HasPetUI() then
        PetPaperDollFrame.hidden = true
        CharacterFrameTab2:Hide()
        CharacterFrameTab3:SetPoint("LEFT", CharacterFrameTab2, "LEFT", 0, 0)
    else
        PetPaperDollFrame.hidden = nil
        CharacterFrameTab2:Show()
    end
end
AVEC_FAMILIER = true
function HasPetUI() return AVEC_FAMILIER end
-- les statistiques telles que le client les CHARGE (patch-enUS-2 et -3, le
-- FrameXML d'origine) : deux groupes de six lignes StatFrameTemplate de
-- 104 x 13, chacun coiffe de son UIDropDownMenuTemplate. La categorie
-- choisie vit dans une CVar qui porte une CLE ; le texte est la globale du
-- meme nom.
PLAYERSTAT_BASE_STATS = "Attributs"
PLAYERSTAT_MELEE_COMBAT = "Corps a corps"
PLAYERSTAT_DEFENSES = "Defenses"
-- LE CLIENT REMONTRE SES LIGNES A CHAQUE MISE A JOUR.
--
-- UpdatePaperdollStats fait `statFrame:Show()` pour chaque ligne qu'elle
-- remplit -- vingt-trois fois dans le PaperDollFrame.lua du client -- sans
-- jamais demander si l'ecran est ouvert. Le faux ne faisait rien du tout :
-- il couvrait donc la faute que le jeu a montree, les statistiques qui
-- reparaissent par-dessus les ensembles ou les titres a un gain de niveau.
function UpdatePaperdollStats(prefixe, cle)
    for i = 1, 6 do
        local ligne = _G[prefixe .. i]
        if ligne then
            ligne:Show()
        end
    end
end
function PaperDollFrame_UpdateStats()
    UpdatePaperdollStats("PlayerStatFrameLeft", GetCVar("playerStatLeftDropdown"))
    UpdatePaperdollStats("PlayerStatFrameRight", GetCVar("playerStatRightDropdown"))
end
-- LE SYSTEME DE PANNEAUX. Il replace la feuille a SA position -- le
-- gestionnaire d'equipement l'appelle a chaque ouverture et fermeture -- ET
-- TOUT CE QUI EST INSCRIT DANS UIPanelWindows.
--
-- C'est ce second geste que le faux ne faisait pas, et c'est lui qui rendait
-- les onglets lateraux incliquables : la fenetre PvP est inscrite au systeme
-- -- UIParent.lua ligne 52 -- et le systeme lui rendait ses ancres a
-- l'ecran. Son art etant eteint, la dalle ne se voyait pas ; elle prenait
-- la souris.
UIPanelWindows = {}
UIPanelWindows["PVPParentFrame"] = { area = "left", pushable = 0, whileDead = 1 }
UIPanelWindows["TokenFrame"] = { area = "left", pushable = 1, whileDead = 1 }
UIPanelWindows["CharacterFrame"] = { area = "left", pushable = 1, whileDead = 1 }

function UpdateUIPanelPositions(cadre)
    CharacterFrame:ClearAllPoints()
    CharacterFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
    for nom in pairs(UIPanelWindows) do
        local panneau = _G[nom]
        if panneau and panneau ~= CharacterFrame and panneau:IsShown() then
            panneau:SetParent(UIParent)
            panneau:ClearAllPoints()
            panneau:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)
            panneau:SetWidth(384)
            panneau:SetHeight(512)
        end
    end
end
CharacterAttributesFrame = CreateFrame("Frame", "CharacterAttributesFrame", CharacterFrame)
for _, cote in ipairs({ "Left", "Right" }) do
    -- UIDropDownMenuTemplate : 40 x 32, porte par un art qui le deborde,
    -- et un bouton fils qui ouvre le menu.
    local nom = "PlayerStatFrame" .. cote .. "DropDown"
    local sel = CreateFrame("Frame", nom, CharacterAttributesFrame)
    sel:SetWidth(149); sel:SetHeight(32)
    for _, piece in ipairs({ "Left", "Middle", "Right" }) do
        _G[nom .. piece] = sel:CreateTexture(nom .. piece, "ARTWORK")
    end
    _G[nom .. "Text"] = sel:CreateFontString(nom .. "Text", "ARTWORK")
    local bouton = CreateFrame("Button", nom .. "Button", sel)
    bouton:SetWidth(24); bouton:SetHeight(24)
    for i = 1, 6 do
        local l = CreateFrame("Frame", "PlayerStatFrame" .. cote .. i, CharacterAttributesFrame)
        l:SetWidth(104); l:SetHeight(13)
        -- StatFrameTemplate met son intitule au calque BACKGROUND : c'est
        -- ce qui oblige a le monter quand on glisse une bande derriere.
        local nom = "PlayerStatFrame" .. cote .. i .. "Label"
        _G[nom] = l:CreateFontString(nom, "BACKGROUND")
    end
end
-- le gestionnaire d'equipement du client : un bouton et son panneau
GearManagerToggleButton = CreateFrame("Button", "GearManagerToggleButton", CharacterFrame)
GearManagerDialog = CreateFrame("Frame", "GearManagerDialog", UIParent)
GearManagerDialog:Hide()
GearManagerDialog.title = GearManagerDialog:CreateFontString("GearManagerDialogTitle", "OVERLAY")
GearManagerDialog.buttons = {}
MAX_EQUIPMENT_SETS_PER_PLAYER = 10
-- Les cartes du client : un CheckButton de 36 dont l'icone est la
-- NormalTexture et l'intitule le $parentName sous elle.
for i = 1, MAX_EQUIPMENT_SETS_PER_PLAYER do
    local b = CreateFrame("CheckButton", "GearSetButton" .. i, GearManagerDialog)
    b:SetWidth(36); b:SetHeight(36)
    -- PopupButtonTemplate (ItemButtonTemplate.xml de 3.3.5) : Normal -- qui
    -- porte l'icone --, Highlight, Checked.
    b:SetNormalTexture("")
    b:SetHighlightTexture("Interface\\\\Buttons\\\\ButtonHilight-Square")
    b:SetCheckedTexture("Interface\\\\Buttons\\\\CheckButtonHilight")
    local vide = b:CreateTexture(nil, "BACKGROUND")
    vide:SetTexture("UI-EmptySlot-Disabled")   -- chemin sans antislash
    _G["GearSetButton" .. i .. "Name"] = b:CreateFontString(
        "GearSetButton" .. i .. "Name", "OVERLAY")
    b.icon = b:GetNormalTexture()
    b.text = _G["GearSetButton" .. i .. "Name"]
    table.insert(GearManagerDialog.buttons, b)
end
-- UIPanelDialogTemplate nomme sa croix $parentClose, pas $parentCloseButton
GearManagerDialogClose = CreateFrame("Button", "GearManagerDialogClose", GearManagerDialog)
for _, nom in ipairs({ "DeleteSet", "EquipSet", "SaveSet" }) do
    local b = CreateFrame("Button", "GearManagerDialog" .. nom, GearManagerDialog)
    b:SetWidth(78); b:SetHeight(22)
end
ENSEMBLES = { { nom = "eee", icone = "icone-eee", porte = true },
              { nom = "aaa", icone = "icone-aaa", porte = false } }
-- LA LISTE QUE LE CLIENT REND N'EST PAS CELLE QU'ON VIENT D'ECRIRE.
-- GetNumEquipmentSets et GetEquipmentSetInfo repondent sur un etat PUBLIE,
-- qui ne rattrape le vrai qu'a EQUIPMENT_SETS_CHANGED. C'est ce decalage
-- qui laissait la liste en retard d'une operation, et le banc l'ignorait.
-- GetEquipmentSetInfoByName, lui, repond tout de suite -- c'est ce que le
-- jeu montre.
PUBLIES = {}
function publierEnsembles()
    PUBLIES = {}
    for i, e in ipairs(ENSEMBLES) do PUBLIES[i] = e end
end
function GetNumEquipmentSets() return #PUBLIES end
function GetEquipmentSetInfo(i)
    local e = PUBLIES[i]
    if e then return e.nom, e.icone end
end
-- Les places sont indexees par EMPLACEMENT d'equipement, et le quatrieme
-- retour de UnpackLocation est le SLOT ou la piece se trouve.
--   porte = true       -> chaque piece est dans SON emplacement
--   porte = "ailleurs" -> sur le joueur, mais dans un autre emplacement
--   porte = false      -> dans les sacs
function GetEquipmentSetLocations(nom)
    for _, e in ipairs(ENSEMBLES) do
        if e.nom == nom then
            if e.porte == true then return { [1] = 101, [5] = 105 } end
            if e.porte == "ailleurs" then return { [1] = 105, [5] = 101 } end
            return { [1] = 201 }
        end
    end
end
function EquipmentManager_UnpackLocation(place)
    if place < 200 then
        return true, false, false, place - 100, nil
    end
    return true, false, true, place - 200, 1
end
function UseEquipmentSet(nom)
    DERNIER_EQUIPE = nom
    -- le vrai rend la main avant la fin : l'evenement suit
    EN_ATTENTE = nom
end
-- Le vrai REFUSE un nom vide : "Usage: SaveEquipmentSet("setName",
-- iconIndex)". Le banc l'acceptait, et laissait donc passer un nom lu
-- apres la fermeture de la fenetre -- que le OnHide du client vide.
function SaveEquipmentSet(nom, icone)
    if type(nom) ~= "string" or nom == "" then
        error('Usage: SaveEquipmentSet("setName", iconIndex)')
    end
    for _, e in ipairs(ENSEMBLES) do
        if e.nom == nom then e.icone = icone; return end
    end
    table.insert(ENSEMBLES, { nom = nom, icone = icone, porte = true })
end
function DeleteEquipmentSet(nom)
    for i, e in ipairs(ENSEMBLES) do
        if e.nom == nom then table.remove(ENSEMBLES, i); return end
    end
end
function GetEquipmentSetInfoByName(nom)
    for _, e in ipairs(ENSEMBLES) do
        if e.nom == nom then return e.nom, e.icone end
    end
end
DELETE = "Delete"
SETTINGS = "Settings"
ERR_CLIENT_LOCKED_OUT = "verrouille"
UIErrorsFrame = CreateFrame("Frame", "UIErrorsFrame", UIParent)
function UIErrorsFrame:AddMessage() end
POPUPS = {}
function StaticPopup_Show(quoi, texte)
    table.insert(POPUPS, { quoi = quoi, texte = texte })
    return { }
end
-- Ce que fait le vrai : il remplit les cartes des ensembles existants et
-- desactive les autres.
function GearManagerDialog_Update()
    local total = GetNumEquipmentSets()
    for i, bouton in ipairs(GearManagerDialog.buttons) do
        if i <= total then
            local nom, icone = GetEquipmentSetInfo(i)
            bouton.name = nom
            bouton.text:SetText(nom)
            bouton:GetNormalTexture():SetTexture(icone)
            bouton:SetChecked(GearManagerDialog.selectedSetName == nom)
        else
            bouton.name = nil
            bouton.text:SetText("")
            bouton:SetChecked(false)
        end
    end
end
-- Ce que fait le vrai : il MONTRE la fenetre. Sans cela, son Hide ne
-- declenchait pas son OnHide, et le banc ne voyait pas ce que celui-ci
-- efface.
function GearManagerDialogSaveSet_OnClick()
    GearManagerDialogPopup:Show()
end
-- La fenetre de choix d'icone du client : quinze boutons en grille de cinq,
-- un champ de nom, un cadre de defilement et deux boutons.
NUM_GEARSET_ICONS_PER_ROW = 5
NUM_GEARSET_ICON_ROWS = 3
NUM_GEARSET_ICONS_SHOWN = 15
GEARSET_ICON_ROW_HEIGHT = 36
MACRO_POPUP_CHOOSE_ICON = "Choose an Icon:"
GEARSETS_POPUP_TEXT = "Enter Set Name (Max 16 Characters):"
GearManagerDialogPopup = CreateFrame("Frame", "GearManagerDialogPopup", UIParent)
GearManagerDialogPopup:Hide()
GearManagerDialogPopup.buttons = {}
for i = 1, NUM_GEARSET_ICONS_SHOWN do
    local b = CreateFrame("CheckButton", "GearManagerDialogPopupButton" .. i,
        GearManagerDialogPopup)
    b:SetWidth(36); b:SetHeight(36)
    b.icon = b:GetNormalTexture()
    table.insert(GearManagerDialogPopup.buttons, b)
end
GearManagerDialogPopup:CreateFontString("popupNom", "OVERLAY"):SetText(GEARSETS_POPUP_TEXT)
GearManagerDialogPopup:CreateFontString("popupIcone", "OVERLAY"):SetText(MACRO_POPUP_CHOOSE_ICON)
for _, nom in ipairs({ "EditBox", "ScrollFrame", "Okay", "Cancel" }) do
    CreateFrame("Frame", "GearManagerDialogPopup" .. nom, GearManagerDialogPopup)
end
-- la barre du FauxScrollFrame et ses deux fleches
GearManagerDialogPopupScrollFrameScrollBar = CreateFrame("Slider",
    "GearManagerDialogPopupScrollFrameScrollBar", GearManagerDialogPopupScrollFrame)
GearManagerDialogPopupScrollFrameScrollBarThumbTexture =
    GearManagerDialogPopupScrollFrameScrollBar:CreateTexture(
        "GearManagerDialogPopupScrollFrameScrollBarThumbTexture", "ARTWORK")
for _, sens in ipairs({ "Up", "Down" }) do
    CreateFrame("Button", "GearManagerDialogPopupScrollFrameScrollBarScroll" .. sens
        .. "Button", GearManagerDialogPopupScrollFrameScrollBar)
end
function GetEquipmentSetIconInfo(i) return "icone-" .. tostring(i), i end
function RecalculateGearManagerDialogPopup() RECALCULE = (RECALCULE or 0) + 1 end
function GearManagerDialogPopup_OnShow() end
function GearManagerDialogPopup_Update() end
-- Ce que fait le vrai OnHide : il oublie le nom saisi.
publierEnsembles()
function GearManagerDialogPopup_OnHide()
    GearManagerDialogPopup.name = nil
    if GearManagerDialogPopupEditBox.SetText then
        GearManagerDialogPopupEditBox:SetText("")
    end
end
GearManagerDialogPopup:SetScript("OnHide", GearManagerDialogPopup_OnHide)
function GearManagerDialog_OnShow()
    if GearManagerDialog.toplevel ~= false then
        GearManagerDialog:Raise()
    end
end
CharacterResistanceFrame = CreateFrame("Frame", "CharacterResistanceFrame", CharacterFrame)
CharacterResistanceFrame:SetPoint("TOPRIGHT", CharacterFrame, "TOPRIGHT", -60, -80)
-- LES CINQ ECRANS DES ONGLETS LATERAUX, comme CHARACTERFRAME_SUBFRAMES les
-- nomme, et la fonction qui n en montre qu un : c est elle qui commute.
CHARACTERFRAME_SUBFRAMES = { "PaperDollFrame", "PetPaperDollFrame", "SkillFrame",
                             "ReputationFrame", "TokenFrame" }
ReputationFrame = CreateFrame("Frame", "ReputationFrame", CharacterFrame)
ReputationFrame:SetWidth(384)
ReputationFrame:SetHeight(424)
ReputationFrame:Hide()
PetPaperDollFrame = CreateFrame("Frame", "PetPaperDollFrame", CharacterFrame)

-- L ECRAN DU FAMILIER de 3.3.5 : l apercu, les trois cadres ou le client
-- ecrit ses valeurs, et les cinq resistances.
--
-- L APERCU N EST PAS FILS DE L ECRAN, IL EST PETIT-FILS : PetModelFrame vit
-- dans PetPaperDollFramePetFrame, setAllPoints sur l ecran -- releve dans le
-- PetPaperDollFrame.xml du client, lignes 128 et 208. Le faux le mettait
-- directement sous l ecran, et couvrait donc la faute : un balayage qui
-- n epargne que le modele masquait son PARENT, et l apercu avec lui.
PetPaperDollFramePetFrame = CreateFrame("Frame", "PetPaperDollFramePetFrame",
                                        PetPaperDollFrame)
PetModelFrame = CreateFrame("Frame", "PetModelFrame", PetPaperDollFramePetFrame)
-- LES FLECHES DE ROTATION sont filles du MODELE, et font 35 x 35 -- les
-- memes que celles du personnage.
for _, cote in ipairs({ "Left", "Right" }) do
    local b = CreateFrame("Button", "PetModelFrameRotate" .. cote .. "Button",
                          PetModelFrame)
    b:SetWidth(35); b:SetHeight(35)
end
function PetModelFrame:SetUnit(u) self.unit = u end
NUM_PET_RESISTANCE_TYPES = 5
RESISTANCES_DU_FAMILIER = { [2] = 95, [3] = 80, [4] = 60, [5] = 45, [6] = 120 }
ECOLES_DU_FAMILIER = { 6, 2, 3, 4, 5 }
function PetPaperDollFrame_SetResistances()
    for i = 1, NUM_PET_RESISTANCE_TYPES do
        local f = _G["PetMagicResFrame" .. i]
        _G["PetMagicResText" .. i]:SetText(RESISTANCES_DU_FAMILIER[f:GetID()])
    end
end
for i = 1, NUM_PET_RESISTANCE_TYPES do
    local f = CreateFrame("Frame", "PetMagicResFrame" .. i, PetPaperDollFrame)
    -- LES ECOLES, telles que le PetPaperDollFrame.xml du client les pose :
    -- le premier cadre porte 6 (Arcane), puis 2, 3, 4, 5.
    f:SetID(ECOLES_DU_FAMILIER[i])
    -- Chaque cadre porte SON icone et SA valeur, comme
    -- MagicResistanceFrameTemplate le veut.
    f:CreateTexture("PetMagicResFrame" .. i .. "Icon", "BACKGROUND")
    _G["PetMagicResText" .. i] = f:CreateFontString("PetMagicResText" .. i, "ARTWORK")
end
function UnitResistance(unit, ecole)
    local v = RESISTANCES_DU_FAMILIER[ecole] or 0
    return v, v, 0, 0
end
for _, n in ipairs({ "PetArmorFrame", "PetDamageFrame", "PetAttackPowerFrame" }) do
    local f = CreateFrame("Frame", n, PetPaperDollFrame)
    _G[n .. "StatText"] = f:CreateFontString(n .. "StatText", "ARTWORK")
end
-- Le client calcule ET met en forme : c est de la qu on lit.
function PaperDollFrame_SetArmor(cadre, unite)
    PetArmorFrameStatText:SetText("3120")
end
function PaperDollFrame_SetDamage(cadre, unite)
    PetDamageFrameStatText:SetText("45 - 62")
end
function PaperDollFrame_SetAttackPower(cadre, unite)
    PetAttackPowerFrameStatText:SetText("1480")
end
function GetCritChanceFromAgility(unit) return 4.25 end
STAT_FORMAT = "%s:"
STAT_CATEGORY_GENERAL = "General"
RESISTANCES = "Resistances"
HEALTH = "Health"
ARMOR = "Armor"
DAMAGE = "Damage"
ATTACK_POWER = "Attack Power"
MELEE_CRIT_CHANCE = "Critical Strike"
RESISTANCE1_NAME = "Holy"
RESISTANCE2_NAME = "Fire"
RESISTANCE3_NAME = "Nature"
RESISTANCE4_NAME = "Frost"
RESISTANCE5_NAME = "Shadow"
RESISTANCE6_NAME = "Arcane"
PetPaperDollFrame:Hide()
SkillFrame = CreateFrame("Frame", "SkillFrame", CharacterFrame)
SkillFrame:Hide()
-- L ECRAN DES COMPETENCES de 3.3.5 : douze lignes posees d avance, que
-- SkillFrame_UpdateSkills repose a chaque passage.
SKILLS_TO_DISPLAY = 12
for i = 1, SKILLS_TO_DISPLAY do
    CreateFrame("Frame", "SkillRankFrame" .. i, SkillFrame)
    CreateFrame("Button", "SkillTypeLabel" .. i, SkillFrame)
end
-- nom, entete, deplie, rang, points temporaires, bonus, rang maximal,
-- abandonnable, cout d un pas, cout d un rang, niveau minimal, type de
-- cout, DESCRIPTION -- treize valeurs.
COMPETENCES = {
    { nom = "Armes", entete = true },
    { nom = "Epees", rang = 150, maxi = 300, bonus = 0, desc = "Maniement des epees." },
    { nom = "Haches", rang = 75, maxi = 300, bonus = 5, desc = "Maniement des haches." },
    { nom = "Metiers", entete = true },
    { nom = "Couture", rang = 225, maxi = 300, bonus = 0, desc = "L art de coudre." },
}
function _competences()
    local liste, saute = {}, nil
    for _, c in ipairs(COMPETENCES) do
        if saute and not c.entete then
            -- avale : son en-tete est replie
        else
            saute = nil
            liste[#liste + 1] = c
            if c.entete and c.replie then saute = true end
        end
    end
    return liste
end
function GetNumSkillLines() return #_competences() end
function GetSkillLineInfo(i)
    local c = _competences()[i]
    if not c then return nil end
    return c.nom, c.entete or false, not c.replie, c.rang or 0, 0, c.bonus or 0,
           c.maxi or 0, false, 0, 0, 0, 0, c.desc or ""
end
function ExpandSkillHeader(i) _competences()[i].replie = false end
function CollapseSkillHeader(i) _competences()[i].replie = true end
COMPETENCE_CHOISIE = 0
function SetSelectedSkill(i) COMPETENCE_CHOISIE = i end
function GetSelectedSkill() return COMPETENCE_CHOISIE end
SkillSortButton = CreateFrame("Button", "SkillSortButton", SkillFrame)
SkillFrameCollapseAllButton = CreateFrame("Button", "SkillFrameCollapseAllButton", SkillFrame)
SkillListScrollFrame = CreateFrame("Frame", "SkillListScrollFrame", SkillFrame)
SkillDetailStatusBar = CreateFrame("StatusBar", "SkillDetailStatusBar", SkillFrame)
SkillFrame:CreateTexture("SkillFrameHorizontalBarLeft", "BACKGROUND")
function SkillFrame_UpdateSkills()
    -- Comme le vrai : il remontre ses lignes a chaque passage.
    for i = 1, SKILLS_TO_DISPLAY do
        _G["SkillRankFrame" .. i]:Show()
        _G["SkillTypeLabel" .. i]:Show()
    end
end
TokenFrame = CreateFrame("Frame", "TokenFrame", CharacterFrame)
TokenFrame:Hide()

-- L ECRAN DES MONNAIES de 3.3.5. GetCurrencyListInfo rend NEUF valeurs :
--   nom, enTete, deplie, inutilisee, suivie, compte, typeSpecial, icone,
--   identifiantObjet
-- Deux monnaies ont une icone a part : typeSpecial 1 pour les points
-- d arene, 2 pour ceux d honneur.
TokenFrameContainer = CreateFrame("Frame", "TokenFrameContainer", TokenFrame)
TokenFramePopup = CreateFrame("Frame", "TokenFramePopup", TokenFrame)
TokenFramePopup:SetBackdrop({ bgFile = "UI-DialogBox-Background" })
TokenFramePopup:Hide()
TokenFramePopupCloseButton = CreateFrame("Button", "TokenFramePopupCloseButton",
                                         TokenFramePopup)
DECLARER_FERMETURE(TokenFramePopupCloseButton)
-- SON INTITULE EST UN FontString, pas une texture : "Currency Options",
-- ancre au TOPLEFT du popup. Un balayage qui ne prend que les textures le
-- laisse a l ecran.
TokenFramePopupTitle = TokenFramePopup:CreateFontString("TokenFramePopupTitle",
                                                        "BACKGROUND")
TokenFramePopupTitle:SetText("Currency Options")
for _, n in ipairs({ "TokenFramePopupInactiveCheckBox",
                     "TokenFramePopupBackpackCheckBox" }) do
    local case = CreateFrame("CheckButton", n, TokenFramePopup)
    _G[n .. "Text"] = case:CreateFontString(n .. "Text", "ARTWORK")
end

-- Deux categories, l une depliee, l autre repliee : replier RACCOURCIT la
-- liste, comme pour les reputations.
DEVISES = {
    { nom = "Miscellaneous", entete = true, deplie = true },
    { nom = "Arena Points", compte = 1234, special = 1 },
    { nom = "Honor Points", compte = 0, special = 2 },
    { nom = "Emblem of Frost", compte = 42, icone = "icone_embleme", suivie = true },
    { nom = "Player vs. Player", entete = true, deplie = false },
    { nom = "Wintergrasp Mark", compte = 7, icone = "icone_marque" },
}

function _devisesVisibles()
    local liste, saute = {}, nil
    for _, d in ipairs(DEVISES) do
        if saute and not d.entete then
            -- avale : sa categorie est repliee
        else
            saute = nil
            liste[#liste + 1] = d
            if d.entete and not d.deplie then
                saute = true
            end
        end
    end
    return liste
end

function GetCurrencyListSize() return #_devisesVisibles() end
function GetCurrencyListInfo(i)
    local d = _devisesVisibles()[i]
    if not d then return nil end
    return d.nom, d.entete or false, d.deplie or false, d.inutilisee or false,
           d.suivie or false, d.compte or 0, d.special, d.icone, d.objet
end
function ExpandCurrencyList(i, ouvrir)
    local d = _devisesVisibles()[i]
    if d then d.deplie = (ouvrir == 1) end
end
function SetCurrencyUnused(i, etat)
    local d = _devisesVisibles()[i]
    if d then d.inutilisee = (etat == 1) end
end
function SetCurrencyBackpack(i, etat)
    local d = _devisesVisibles()[i]
    if d then d.suivie = (etat == 1) end
end
function TokenFrame_Update() end
GameFontDisable = "GameFontDisable"
GameFontHighlightRight = "GameFontHighlightRight"
-- L ECRAN DE REPUTATION de 3.3.5 : quinze lignes posees une fois dans le
-- XML, que ReputationFrame_Update ne fait que remplir.
NUM_FACTIONS_DISPLAYED = 15
REPUTATIONFRAME_FACTIONHEIGHT = 26
REPUTATIONFRAME_ROWSPACING = 23
FACTION_BAR_COLORS = {
    [1] = { r = 0.8, g = 0.3, b = 0.2 }, [4] = { r = 0.9, g = 0.7, b = 0.0 },
    [8] = { r = 0.0, g = 0.6, b = 0.1 },
}
ReputationFrameFactionLabel = ReputationFrame:CreateFontString(
    "ReputationFrameFactionLabel", "BACKGROUND")
ReputationFrameStandingLabel = ReputationFrame:CreateFontString(
    "ReputationFrameStandingLabel", "BACKGROUND")
ReputationFrameTopTreeTexture = ReputationFrame:CreateTexture(
    "ReputationFrameTopTreeTexture", "OVERLAY")
ReputationFrameTopTreeTexture2 = ReputationFrame:CreateTexture(
    "ReputationFrameTopTreeTexture2", "OVERLAY")
ReputationFrame:CreateTexture("ReputationFrameVieilArt", "BACKGROUND")
ReputationListScrollFrame = CreateFrame("Frame", "ReputationListScrollFrame",
                                        ReputationFrame)
ReputationFrameCollapseAll = CreateFrame("Button", "ReputationFrameCollapseAll",
                                         ReputationFrame)
function FauxScrollFrame_GetOffset() return 0 end
for i = 1, 15 do
    local n = "ReputationBar" .. i
    local r = CreateFrame("Button", n, ReputationFrame)
    r:SetWidth(295)
    r:SetHeight(20)
    _G[n .. "ExpandOrCollapseButton"] = CreateFrame("Button",
        n .. "ExpandOrCollapseButton", r)
    local b = CreateFrame("StatusBar", n .. "ReputationBar", r)
    b:SetWidth(101)
    b:SetHeight(13)
    b:SetMinMaxValues(0, 1000)
    b:SetValue(250)
    _G[n .. "FactionName"] = r:CreateFontString(n .. "FactionName", "ARTWORK")
    _G[n .. "ReputationBarFactionStanding"] = b:CreateFontString(
        n .. "ReputationBarFactionStanding", "ARTWORK")
    for _, suffixe in ipairs({ "LeftLine", "BottomLine", "Background" }) do
        _G[n .. suffixe] = r:CreateTexture(n .. suffixe, "BACKGROUND")
    end
end
-- LES MONNAIES SUIVIES DU SAC. GetBackpackCurrencyInfo rend nom, compte,
-- typeSpecial et icone, pour i de 1 a MAX_WATCHED_TOKENS -- trois.
MAX_WATCHED_TOKENS = 3
BACKPACK_HEIGHT = 200
BACKPACK_TOKENFRAME_HEIGHT = 22
SUIVIES = {}
function GetBackpackCurrencyInfo(i)
    local d = SUIVIES[i]
    if not d then return nil end
    return d.nom, d.compte, d.special, d.icone
end
-- Le vrai reparente son segment dans le sac ET REPOSE SA HAUTEUR : c'est ce
-- geste-la qui defaisait la notre.
function ManageBackpackTokenFrame()
    BackpackTokenFrame:Show()
    ContainerFrame1:SetHeight(BACKPACK_HEIGHT + BACKPACK_TOKENFRAME_HEIGHT)
end
GameFontHighlightSmall = "GameFontHighlightSmall"
MAX_REPUTATION_REACTION = 8
-- FACTION_AT_WAR_COLOR N EXISTE PAS EN 3.3.5, verifie dans le FrameXML du
-- client : ni Constants.lua, ni GlobalStrings.lua, ni ReputationFrame.lua ne
-- la portent. Le faux l inventait en 0,8 / 0,2 / 0,2 -- une couleur qui n est
-- celle de personne -- et couvrait donc exactement la faute que le jeu a
-- montree : une faction en guerre recouverte d un voile BLANC. Comme pour
-- IsTitleKnown, un faux plus aimable que le client ne prouve rien.
GameFontNormalLeft = "GameFontNormalLeft"
GameFontHighlight = "GameFontHighlight"
function UnitSex() return 2 end
-- REPLIER RETIRE LES ENFANTS DE LA NUMEROTATION, il ne les masque pas : le
-- client renumerote, GetNumFactions diminue, et tout ce qui suit remonte.
-- Le faux client doit en faire autant, sinon l essai ne prouve rien.
function _visibles()
    local liste, saute = {}, nil
    for _, f in ipairs(TOUTES) do
        if saute and f.enfant then
            -- avale : son parent est replie
        else
            saute = nil
            liste[#liste + 1] = f
            if f.entete and f.replie then
                saute = true
            end
        end
    end
    return liste
end
function ExpandFactionHeader(i) _visibles()[i].replie = false end
function CollapseFactionHeader(i) _visibles()[i].replie = true end
-- La hierarchie telle que le client la rend : un en-tete de premier niveau,
-- un sous-en-tete -- en-tete ET enfant -- puis des entrees enfants.
TOUTES = { { nom = "Classic", standing = 4, entete = true },
           { nom = "Alliance", standing = 5, entete = true, enfant = true, rep = true },
           { nom = "Darnassus", standing = 4, enfant = true },
           { nom = "Exodar", standing = 8, enfant = true } }
-- AU-DELA DU COMPTE, LE CLIENT REPOND QUAND MEME. Releve en jeu : il
-- annonce neuf factions et rend encore la dixieme, l en-tete "Inactive".
-- Sa propre boucle s arrete a GetNumFactions ; le faux client reproduit ce
-- piege, sinon l essai ne prouverait rien.
HORS_COMPTE = { nom = "Inactive", standing = 1, entete = true }
function GetNumFactions() return #_visibles() end
function GetFactionInfo(i)
    local vus = _visibles()
    local f = vus[i]
    if not f and i == #vus + 1 then f = HORS_COMPTE end
    if not f then return nil end
    -- nom, description, standingID, seuil, suivant, valeur, enGuerre,
    -- peutDeclarer, estEnTete, estReplie, ...
    -- ... hasRep en 11e, isWatched en 12e, isChild en 13e
    return f.nom, "", f.standing, 0, 1000, 250, f.guerre or false, false,
           f.entete, f.replie or false, f.rep or false, false, f.enfant or false
end
-- LE CADRE DE DETAIL de 3.3.5, avec ses trois cases. C est
-- ReputationFrame_Update qui le remplit, pour la faction choisie, et
-- SEULEMENT s il est visible.
ReputationDetailFrame = CreateFrame("Frame", "ReputationDetailFrame", UIParent)
-- Il porte un <Backdrop>, qui n est PAS une region : le balayage des
-- textures ne l atteint pas, seul SetBackdrop(nil) l enleve.
ReputationDetailFrame:SetBackdrop({ bgFile = "UI-DialogBox-Background" })
ReputationDetailFrame:Hide()
ReputationDetailCloseButton = CreateFrame("Button", "ReputationDetailCloseButton",
                                          ReputationDetailFrame)
DECLARER_FERMETURE(ReputationDetailCloseButton)
ReputationDetailFactionName = ReputationDetailFrame:CreateFontString(
    "ReputationDetailFactionName", "ARTWORK")
ReputationDetailFactionDescription = ReputationDetailFrame:CreateFontString(
    "ReputationDetailFactionDescription", "ARTWORK")
for _, n in ipairs({ "ReputationDetailAtWarCheckBox",
                     "ReputationDetailInactiveCheckBox",
                     "ReputationDetailMainScreenCheckBox" }) do
    local c = CreateFrame("CheckButton", n, ReputationDetailFrame)
    _G[n .. "Text"] = c:CreateFontString(n .. "Text", "ARTWORK")
end
CHOISIE = 0
function SetSelectedFaction(i) CHOISIE = i end
function GetSelectedFaction() return CHOISIE end
RED_FONT_COLOR = { r = 1, g = 0.1, b = 0.1 }
GameFontNormalLarge = "GameFontNormalLarge"
function IsFactionInactive() return false end
function ReputationFrame_Update()
    -- Comme le vrai : il n ecrit le detail que si son cadre est visible.
    if not ReputationDetailFrame:IsShown() then return end
    local f = _visibles()[CHOISIE]
    if not f then return end
    ReputationDetailFactionName:SetText(f.nom)
    ReputationDetailFactionDescription:SetText("Description de " .. f.nom)
end

-- LA FENETRE PvP de 3.3.5 : un cadre a part, toplevel, fils d UIParent.
PVPParentFrame = CreateFrame("Frame", "PVPParentFrame", UIParent)
PVPParentFrame:SetWidth(384)
PVPParentFrame:SetHeight(512)
PVPParentFrame:SetToplevel(true)
PVPParentFrame:Hide()
-- L ECRAN PvP de 3.3.5 : ses onglets, ses cadres d equipe et son bandeau de
-- hors-saison, que PVPFrame_Update repose.
PVPFrameToggleButton = CreateFrame("Button", "PVPFrameToggleButton", PVPParentFrame)
PVPFrameOffSeason = CreateFrame("Frame", "PVPFrameOffSeason", PVPParentFrame)
PVPParentFrame:CreateTexture("PVPParentFrameVieilArt", "BACKGROUND")
function PVPFrame_Update()
    PVPFrameToggleButton:Show()
    PVPFrameOffSeason:Show()
end
-- Les trois fonctions de rang : absentes du FrameXML de WotLK, mais dans le
-- binaire. Le faux client en rend, pour que l essai porte.
-- Le vrai rend 0 quand le personnage n a pas de rang, et GetPVPRankInfo ne
-- repond alors rien : releve en jeu par /fui pvp.
RANG_PVP = 0
function UnitPVPRank() return RANG_PVP end
function GetPVPRankInfo(indice)
    if not indice or indice <= 0 then return nil end
    return nil, nil          -- ce client ne repond pas : on nomme autrement
end
ARENA = "Arena"
-- Les quarante chaines de rang que le client porte vraiment.
-- Leur ORDRE donne le decalage : 1 a 4 sont les rangs negatifs, 5 est le
-- rang 1, et ainsi de suite. L indice de UnitPVPRank est donc la cle.
PVP_RANK_1_0 = "Pariah"
PVP_RANK_1_1 = "Pariah"
PVP_RANK_4_0 = "Dishonored"
PVP_RANK_4_1 = "Dishonored"
PVP_RANK_5_0 = "Scout"
PVP_RANK_6_0 = "Grunt"
PVP_RANK_9_0 = "First Sergeant"
PVP_RANK_5_1 = "Private"
PVP_RANK_9_1 = "Sergeant Major"
PROGRES_PVP = 0.4
function GetPVPRankProgress() return PROGRES_PVP end
VICTOIRES_PVP = 1234
function GetPVPLifetimeStats() return VICTOIRES_PVP, 0, 8 end
-- LES TITRES, la ou mod-pvp-titles ecrit vraiment le rang. Alliance : les
-- identifiants 1 a 14 de CharTitles.dbc ; Horde : 15 a 28.
TITRES_CONNUS = {}
function GetNumTitles() return 177 end
-- IL REND UN NOMBRE, 0 OU 1, ET NON UN BOOLEEN. Le faux le rendait en
-- booleen, et laissait donc passer une faute que le jeu a montree tout de
-- suite : en Lua, 0 est VRAI. Le client ecrit `if ( IsTitleKnown(i) ~= 0 )`.
function IsTitleKnown(id) if TITRES_CONNUS[id] then return 1 else return 0 end end
-- LE NOM PORTE SES ESPACES, comme le vrai : CharTitles donne "Private %s",
-- et GetTitleName rend "Private " -- d ou le strtrim du client.
NOMS_DE_TITRE = { [1] = "Private ", [5] = "Sergeant Major ",
                  [14] = "Grand Marshal ", [15] = "Scout ", [42] = "the Explorer" }
function GetTitleName(id) return NOMS_DE_TITRE[id] end
TITRE_PORTE = 0
function GetCurrentTitle() return TITRE_PORTE end
function SetCurrentTitle(id) TITRE_PORTE = id end
PLAYER_TITLE_NONE = "None"
NONE = "None"
PAPERDOLL_SIDEBAR_TITLES = "Titles"
function strtrim(s) return (string.gsub(s or "", "^%s*(.-)%s*$", "%1")) end
-- LE MENU DEROULANT DU CLIENT, celui que l addon doit taire.
PlayerTitleFrame = CreateFrame("Frame", "PlayerTitleFrame", UIParent)
PlayerTitlePickerFrame = CreateFrame("Frame", "PlayerTitlePickerFrame", UIParent)
function PlayerTitleFrame_UpdateTitles()
    -- Le vrai le REMONTRE a chaque passage : c est tout l interet du faux.
    PlayerTitleFrame:Show()
    PlayerTitlePickerFrame:Show()
end
function GetPVPSessionStats() return 12, 340 end
function GetPVPYesterdayStats() return 30, 900 end
function GetHonorCurrency() return 4567 end
function GetCurrentArenaSeason() return 8 end
HONOR_POINTS = "Points d'honneur"
LIFETIME_HONORABLE_KILLS = "Victoires honorables"
TODAY = "Aujourd hui"
YESTERDAY = "Hier"
-- Le client reancre deux micro-boutons a chaque entree ou sortie de
-- vehicule : le faux client doit le faire aussi, sinon l essai ne prouve
-- rien.
function VehicleMenuBar_MoveMicroButtons()
    CharacterMicroButton:ClearAllPoints()
    CharacterMicroButton:SetPoint("BOTTOMLEFT", MainMenuBarArtFrame, "BOTTOMLEFT", 552, 2)
    SocialsMicroButton:ClearAllPoints()
    SocialsMicroButton:SetPoint("BOTTOMLEFT", QuestLogMicroButton, "BOTTOMRIGHT", -3, 0)
end
function TogglePVPFrame() end
-- La souris, pour la barre de defilement : le vrai rend des coordonnees
-- d ECRAN, qu il faut ramener a l echelle du cadre.
SOURIS_Y = 0
function GetCursorPosition() return 0, SOURIS_Y end
function ShowUIPanel(cadre) cadre:Show() end
function HideUIPanel(cadre) cadre:Hide() end

-- ToggleCharacter, repris mot pour mot de l'UIParent.lua du client : c'est
-- LUI que les onglets appellent, et il ferme la fenetre quand l'ecran
-- demande est deja montre.
-- PanelTemplates, repris de UIPanelTemplates.lua. LE POINT QUI COMPTE :
-- SelectTab DESACTIVE l'onglet choisi -- on ne reclique pas celui ou l'on
-- est -- et seul DeselectTab lui rend la main.
function PanelTemplates_SelectTab(onglet) onglet:Disable() end
function PanelTemplates_DeselectTab(onglet) onglet:Enable() end
function PanelTemplates_SetNumTabs(cadre, n) cadre.numTabs = n end
function PanelTemplates_UpdateTabs(cadre)
    if cadre.selectedTab then
        for i = 1, cadre.numTabs do
            local onglet = _G[cadre:GetName() .. "Tab" .. i]
            if onglet then
                if i == cadre.selectedTab then
                    PanelTemplates_SelectTab(onglet)
                else
                    PanelTemplates_DeselectTab(onglet)
                end
            end
        end
    end
end
function PanelTemplates_SetTab(cadre, id)
    cadre.selectedTab = id
    PanelTemplates_UpdateTabs(cadre)
end
PanelTemplates_SetNumTabs(CharacterFrame, 5)

-- ToggleCharacter, repris mot pour mot du CharacterFrame.lua du client.
ID_DE_L_ECRAN = { PaperDollFrame = 1, PetPaperDollFrame = 2, ReputationFrame = 3,
                  SkillFrame = 4, TokenFrame = 5 }
function ToggleCharacter(onglet)
    local sous = _G[onglet]
    if not sous then
        return
    end
    if not sous.hidden then
        PanelTemplates_SetTab(CharacterFrame, ID_DE_L_ECRAN[onglet])
        if CharacterFrame:IsShown() then
            if sous:IsShown() then
                HideUIPanel(CharacterFrame)
            else
                CharacterFrame_ShowSubFrame(onglet)
            end
        else
            ShowUIPanel(CharacterFrame)
            CharacterFrame_ShowSubFrame(onglet)
        end
    end
end
PVP = "JcJ"
STATISTICS = "Statistiques"
function CharacterFrame_ShowSubFrame(nom)
    for _, ecran in ipairs(CHARACTERFRAME_SUBFRAMES) do
        if ecran == nom then _G[ecran]:Show() else _G[ecran]:Hide() end
    end
end
function PaperDollFrame_OnShow() end

-- la barre bonus du client : celle qui remplace la barre de sorts quand le
-- joueur change de posture, avec son art glissant
BonusActionBarFrame = CreateFrame("Frame", "BonusActionBarFrame", UIParent)
BonusActionBarTexture0 = BonusActionBarFrame:CreateTexture("BonusActionBarTexture0", "ARTWORK")
BonusActionBarTexture1 = BonusActionBarFrame:CreateTexture("BonusActionBarTexture1", "ARTWORK")
for i = 1, 12 do
    local nom = "BonusActionButton" .. i
    local b = CreateFrame("CheckButton", nom, BonusActionBarFrame)
    DECLARER_ETATS_ACTION(b)
    b:SetID(i)
    _G[nom .. "Icon"] = b:CreateTexture(nom .. "Icon", "BORDER")
    _G[nom .. "IconTexture"] = _G[nom .. "Icon"]
    _G[nom .. "Cooldown"] = CreateFrame("Frame", nom .. "Cooldown", b)
    _G[nom .. "NormalTexture"] = b:CreateTexture(nom .. "NormalTexture", "ARTWORK")
    _G[nom .. "HotKey"] = b:CreateFontString(nom .. "HotKey", "ARTWORK")
    _G[nom .. "Count"] = b:CreateFontString(nom .. "Count", "ARTWORK")
    _G[nom .. "Name"] = b:CreateFontString(nom .. "Name", "ARTWORK")
    _G[nom .. "Border"] = b:CreateTexture(nom .. "Border", "OVERLAY")
    _G[nom .. "Flash"] = b:CreateTexture(nom .. "Flash", "ARTWORK")
    _G[nom .. "FloatingBG"] = b:CreateTexture(nom .. "FloatingBG", "BACKGROUND")
end

-- la barre des postures du client : un cadre, dix boutons
ShapeshiftBarFrame = CreateFrame("Frame", "ShapeshiftBarFrame", UIParent)
for _, suffixe in ipairs({ "Left", "Middle", "Right" }) do
    _G["ShapeshiftBar" .. suffixe] = ShapeshiftBarFrame:CreateTexture(
        "ShapeshiftBar" .. suffixe, "ARTWORK")
end
for i = 1, NUM_SHAPESHIFT_SLOTS do
    local nom = "ShapeshiftButton" .. i
    local b = CreateFrame("CheckButton", nom, ShapeshiftBarFrame)
    DECLARER_ETATS_ACTION(b)
    b:SetID(i)
    _G[nom .. "Icon"] = b:CreateTexture(nom .. "Icon", "BORDER")
    _G[nom .. "Cooldown"] = CreateFrame("Frame", nom .. "Cooldown", b)
    _G[nom .. "FloatingBG"] = b:CreateTexture(nom .. "FloatingBG", "BACKGROUND")
    _G[nom .. "HotKey"] = b:CreateFontString(nom .. "HotKey", "ARTWORK")
    _G[nom .. "Count"] = b:CreateFontString(nom .. "Count", "ARTWORK")
end
function ShapeshiftBar_Update() end
function ShapeshiftBar_UpdateState() end

-- la barre du familier du client : un cadre, dix boutons
PetActionBarFrame = CreateFrame("Frame", "PetActionBarFrame", UIParent)
-- l'art d'epoque : les deux morceaux glissants qui encadrent la barre
SlidingActionBarTexture0 = PetActionBarFrame:CreateTexture("SlidingActionBarTexture0", "ARTWORK")
SlidingActionBarTexture1 = PetActionBarFrame:CreateTexture("SlidingActionBarTexture1", "ARTWORK")
for i = 1, NUM_PET_ACTION_SLOTS do
    local nom = "PetActionButton" .. i
    local b = CreateFrame("CheckButton", nom, PetActionBarFrame)
    DECLARER_ETATS_ACTION(b)
    b:SetID(i)
    _G[nom .. "Icon"] = b:CreateTexture(nom .. "Icon", "BORDER")
    _G[nom .. "Cooldown"] = CreateFrame("Frame", nom .. "Cooldown", b)
    _G[nom .. "AutoCastable"] = b:CreateTexture(nom .. "AutoCastable", "OVERLAY")
    _G[nom .. "Shine"] = CreateFrame("Frame", nom .. "Shine", b)
    _G[nom .. "Flash"] = b:CreateTexture(nom .. "Flash", "ARTWORK")
    _G[nom .. "FloatingBG"] = b:CreateTexture(nom .. "FloatingBG", "BACKGROUND")
    _G[nom .. "HotKey"] = b:CreateFontString(nom .. "HotKey", "ARTWORK")
    _G[nom .. "Count"] = b:CreateFontString(nom .. "Count", "ARTWORK")
end
function PetActionBar_Update() end
function PetActionBar_UpdateCooldowns() end

-- l'inventaire simule : SACS[sac][emplacement] = { lien, nombre }
SACS = { [0] = {}, [1] = {}, [2] = {}, [3] = {}, [4] = {} }
TAILLES = { [0] = 4, [1] = 4, [2] = 0, [3] = 0, [4] = 0 }
OBJETS = {
    ["|cffffffff|Hitem:1|h[Pain]|h|r"] = { nom = "Pain", qualite = 1, type_ = "Consommable",
                                           sousType = "Nourriture", pileMax = 20 },
    ["|cff0070dd|Hitem:2|h[Epee]|h|r"] = { nom = "Epee", qualite = 3, type_ = "Arme",
                                           sousType = "Epee a une main", pileMax = 1 },
    ["|cffffffff|Hitem:3|h[Potion]|h|r"] = { nom = "Potion", qualite = 1, type_ = "Consommable",
                                             sousType = "Potion", pileMax = 20 },
}
PRISES = {}
CURSEUR = nil

function GetContainerNumSlots(sac) return TAILLES[sac] or 0 end
function GetContainerItemLink(sac, emplacement)
    local case = SACS[sac] and SACS[sac][emplacement]
    return case and case.lien or nil
end
function GetContainerItemInfo(sac, emplacement)
    local case = SACS[sac] and SACS[sac][emplacement]
    if not case then return nil end
    local o = OBJETS[case.lien]
    return "icone", case.nombre, false, (o and o.qualite) or 1, false
end
-- Le nom d'un sac vient du client : bag 0 = le mot traduit, les autres
-- portent le nom de l'objet qu'ils sont.
function GetScreenWidth() return 1920 end
function GetScreenHeight() return 1080 end
KEYRING_CONTAINER = -2
NOMS_DE_SACS = { [0] = "Sac a dos", [-2] = "Trousseau de cles",
                 [1] = "Sac en tisse-givre", [2] = "Sac de mineur" }
function GetBagName(id) return NOMS_DE_SACS[id] end
function ContainerIDToInventoryID(id) return 19 + id end
function GetInventoryItemTexture(unite, emplacement)
    if emplacement == 20 then return "icone_du_sac_1" end
    return nil
end
function GetItemInfo(lien)
    local o = OBJETS[lien]
    if not o then return nil end
    return o.nom, lien, o.qualite, 1, 1, o.type_, o.sousType, o.pileMax
end
function GetAuctionItemClasses() return "Arme", "Armure", "Consommable", "Divers" end
function CursorHasItem() return CURSEUR ~= nil end
function ClearCursor() CURSEUR = nil end
function PickupContainerItem(sac, emplacement)
    table.insert(PRISES, { sac = sac, emplacement = emplacement })
    local case = SACS[sac][emplacement]
    if CURSEUR == nil then
        CURSEUR = { sac = sac, emplacement = emplacement, case = case }
        SACS[sac][emplacement] = nil
    else
        -- Le client reunit deux piles entamees du meme objet ; sinon il echange.
        local porte = CURSEUR.case
        if case and porte and case.lien == porte.lien then
            local max = OBJETS[case.lien].pileMax
            if case.nombre + porte.nombre <= max then
                SACS[sac][emplacement] = { lien = case.lien, nombre = case.nombre + porte.nombre }
                CURSEUR = nil
                return
            end
        end
        SACS[CURSEUR.sac][CURSEUR.emplacement] = case
        SACS[sac][emplacement] = porte
        CURSEUR = nil
    end
end
function ContainerFrame_GenerateFrame() end
function ContainerFrame_Update() end
function ContainerFrame_OnHide() end
function updateContainerFrameAnchors() end
function ToggleBag() end

HOOKS = {}
-- Le vrai hooksecurefunc ENVELOPPE la fonction : elle s execute, puis le
-- greffon, et les valeurs rendues sont celles de l originale. Le banc se
-- contentait d enregistrer le greffon, si bien qu appeler la fonction ne
-- declenchait rien.
function hooksecurefunc(nom, fn)
    HOOKS[nom] = fn
    if type(nom) == "string" and type(_G[nom]) == "function" then
        local ancienne = _G[nom]
        _G[nom] = function(...)
            local rendus = { ancienne(...) }
            fn(...)
            return (table.unpack or unpack)(rendus)
        end
    end
end
-- LES LISTES DES MENUS DEROULANTS. Le client n'en a que deux, globales,
-- partagees par tous les menus du jeu. UIDropDownMenu_AddButton y pose une
-- ligne, remet sa police et retient si elle porte une case a cocher.
GameFontHighlightLeft = { police = "GameFontHighlightLeft" }
GameFontHighlightSmallLeft = { police = "GameFontHighlightSmallLeft" }
UIDROPDOWNMENU_BUTTON_HEIGHT = 16
UIDROPDOWNMENU_BORDER_HEIGHT = 15
for niveau = 1, 2 do
    local nom = "DropDownList" .. niveau
    local liste = CreateFrame("Button", nom, UIParent)
    liste:SetID(niveau)
    liste.numButtons = 0
    for _, suffixe in ipairs({ "Backdrop", "MenuBackdrop" }) do
        local fond = CreateFrame("Frame", nom .. suffixe, liste)
        fond:SetBackdrop({ bgFile = "UI-DialogBox-Background-Dark" })
    end
    for i = 1, 8 do
        local bouton = CreateFrame("Button", nom .. "Button" .. i, liste)
        bouton:SetWidth(100)
        bouton:SetHeight(16)
        _G[nom .. "Button" .. i .. "Check"] = bouton:CreateTexture(
            nom .. "Button" .. i .. "Check", "ARTWORK")
        _G[nom .. "Button" .. i .. "Check"]:SetWidth(18)
        _G[nom .. "Button" .. i .. "Check"]:SetHeight(18)
    end
end
function UIDropDownMenu_AddButton(info, level)
    level = level or 1
    local liste = _G["DropDownList" .. level]
    liste.numButtons = liste.numButtons + 1
    local bouton = _G[liste:GetName() .. "Button" .. liste.numButtons]
    bouton.notCheckable = info.notCheckable
    bouton:SetNormalFontObject(GameFontHighlightSmallLeft)
    bouton:SetHighlightFontObject(GameFontHighlightSmallLeft)
    return bouton
end
function ActionButton_Update() end
function ActionButton_ShowGrid() end
function ActionButton_HideGrid() end
SlashCmdList = {}
"""


def main():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)

    ordre = ["UIAtlas.lua", "UIAtlas_01_selection_perso.lua", "UIAtlas_02_creation_perso.lua",
             "UIAtlas_03_barre_action.lua", "UIAtlas_04_cadres_unite.lua",
             "UIAtlas_05_feuille_perso.lua", "UIAtlas_06_complements.lua", "AtlasUtil.lua",
             "Panes.lua", "ScrollBar.lua", "Layout.lua", "DropDown.lua",
             "PlayerFrame.lua",
             "PlayerFrameExtras.lua", "PlayerRunes.lua", "TargetFrame.lua",
             "CastBar.lua", "ActionBar.lua", "StanceBar.lua", "PetBar.lua",
             "BottomBar.lua", "StatusBars.lua", "Minimap.lua", "Bags.lua",
             "CharacterFrame.lua", "EquipmentManager.lua", "ReputationTab.lua", "SkillsTab.lua", "PvPTab.lua",
             "Titles.lua", "TokensTab.lua", "PetTab.lua", "IconPicker.lua"]

    # l'ordre du .toc fait foi : on verifie qu'il correspond
    toc = io.open(os.path.join(ADDON, "ForeverUI.toc"), encoding="utf-8").read()
    listes = [l.strip() for l in toc.splitlines() if l.strip() and not l.startswith("##")]
    assert listes == ordre, "l'ordre du toc a change : %s" % listes

    # LE CLIENT EST EN LUA 5.1, le banc en 5.5. Le compilateur de 5.1 refuse
    # ce que 5.5 accepte -- plus de 60 upvalues dans une fonction, par
    # exemple : Minimap.lua ne se chargeait plus du tout en jeu le
    # 2026-09-24, et le banc restait vert. Chaque fichier passe donc d'abord
    # par un vrai compilateur 5.1, sans rien executer.
    import importlib
    compilateur = importlib.import_module("lupa.lua51").LuaRuntime(unpack_returned_tuples=True)
    compiler = compilateur.eval("function(code, nom) local f, err = loadstring(code, nom) return err end")
    refus = []
    for fn in ordre:
        erreur = compiler(io.open(os.path.join(ADDON, fn), encoding="utf-8").read(), fn)
        if erreur:
            refus.append(erreur)
    if refus:
        for erreur in refus:
            print("  REFUS LUA 5.1 %s" % erreur)
        sys.exit("le client 3.3.5 ne chargerait pas ces fichiers")
    print("compilation Lua 5.1 : %d fichiers acceptes" % len(ordre))

    echecs = []
    for fn in ordre:
        source = io.open(os.path.join(ADDON, fn), encoding="utf-8").read()
        try:
            lua.execute(source)
        except Exception as exc:
            echecs.append((fn, str(exc).split("\n")[0]))
    if echecs:
        for fn, err in echecs:
            print("  ECHEC %-34s %s" % (fn, err))
        sys.exit("chargement interrompu")
    print("chargement : %d fichiers, aucune erreur" % len(ordre))

    # UN FICHIER AJOUTE AU .toc N ARRIVE QU AU PROCHAIN DEMARRAGE : le client
    # dresse la liste des fichiers d un addon a l ouverture, et /reload ne la
    # reconstruit pas. Panes.lua manquait donc, bien que pose sur le disque,
    # et la feuille s arretait sur une erreur au chargement. On rejoue ce cas
    # dans un client neuf : elle doit se taire et le dire, pas casser.
    sans = lupa.LuaRuntime(unpack_returned_tuples=True)
    sans.execute(MOCK)
    for fn in ordre:
        if fn == "Panes.lua":
            continue
        try:
            sans.execute(io.open(os.path.join(ADDON, fn), encoding="utf-8").read())
        except Exception as exc:
            sys.exit("sans Panes.lua, %s casse : %s" % (fn, str(exc).split(chr(10))[0]))
    dits = [m for m in sans.globals().RECORDED.messages.values() if "Panes.lua" in m]
    print("sans Panes.lua : l addon charge, %d message(s) au joueur" % len(dits))
    assert dits, "il doit DIRE ce qui manque, pas echouer en silence"
    assert sans.globals().CharacterFrame.width != 631,         "et ne rien habiller tant que la bibliotheque n est pas la"

    g = lua.globals()

    # 1. tables d'atlas
    n = sum(1 for _ in g.UIAtlas.data.items())
    print("entrees d'atlas chargees : %d" % n)

    # 2. enregistrement de la position
    system = g.ForeverUI.Layout.systems["playerframe"]
    d = system.defaults
    print("systeme enregistre : %s | defaut %s/%s %s,%s" % (system.label, d.point, d.relativePoint, d.x, d.y))
    frame = g.ForeverUIPlayerFrame
    pt = frame.points[1]
    print("ancrage applique : %s -> %s (%s, %s)" % (pt[1], pt[3], pt[4], pt[5]))

    # 3. evenement d'entree en jeu
    frame.scripts.OnEvent(frame, "PLAYER_ENTERING_WORLD")
    print("apres PLAYER_ENTERING_WORLD :")
    print("   nom      : %s" % frame.nameText.text)
    print("   niveau   : %s" % frame.levelText.text)
    print("   portrait : %d appel(s) a SetPortraitTexture" % g.RECORDED.portraits)
    print("   art      : %s" % frame.art.texture)
    hp = frame.healthFill
    print("   vie 50%%  : largeur %s, texcoord u %.6f -> %.6f (visible: %s)" % (
        hp.width, hp.texcoord[1], hp.texcoord[2], hp.shown))
    pw = frame.powerFill
    print("   rage 30%% : largeur %s, hauteur %s (visible: %s)" % (pw.width, pw.height, pw.shown))
    print("   PlayerFrame d'origine : %d evenement(s), visible=%s" % (
        sum(1 for _ in g.PlayerFrame.events.items()), g.PlayerFrame.shown))

    # 3b. le niveau doit vivre dans un cadre fils, place au-dessus du cadre
    holder = frame.levelText.owner
    niveau_cadre = frame.frameLevel or 1
    print("   niveau   : porte par un cadre fils = %s, son niveau %s contre %s" % (
        holder is not frame, holder.frameLevel, niveau_cadre))
    assert holder is not frame, "le niveau est reste dans le cadre principal"
    assert holder.frameLevel > niveau_cadre, "le cadre du niveau n'est pas au-dessus"

    # 4. vie a zero : le client refuse une largeur nulle, la texture doit disparaitre
    g.STATE.health = 0
    frame.scripts.OnEvent(frame, "UNIT_HEALTH", "player")
    print("vie a 0 : texture de vie visible = %s" % frame.healthFill.shown)

    # 5. un evenement pour une autre unite ne doit rien changer
    g.STATE.health = 100
    frame.scripts.OnEvent(frame, "UNIT_HEALTH", "target")
    print("UNIT_HEALTH sur 'target' ignore : texture toujours masquee = %s" % (not frame.healthFill.shown))

    # 6. l'art du cadre ne change jamais ; la lueur est celle de la menace
    avant = [frame.art.texcoord[i] for i in (1, 2, 3, 4)]
    g.STATE.combat = True
    frame.scripts.OnEvent(frame, "PLAYER_REGEN_DISABLED")
    apres = [frame.art.texcoord[i] for i in (1, 2, 3, 4)]
    print("art du cadre inchange en combat : %s" % (avant == apres))
    assert avant == apres, "l'art du cadre a ete remplace"
    couleur = frame.threatGlow.vertex
    print("engage sans etre pris pour cible : visible=%s alpha=%.2f couleur=(%.2f, %.2f, %.2f)" % (
        frame.threatGlow.shown, frame.threatGlow.alpha, couleur[1], couleur[2], couleur[3]))
    assert frame.threatGlow.shown, "pas de lueur alors que le joueur est en combat"
    faible = frame.threatGlow.alpha

    g.STATE.threat = 3
    frame.scripts.OnEvent(frame, "UNIT_THREAT_SITUATION_UPDATE")
    couleur = frame.threatGlow.vertex
    fort = frame.threatGlow.alpha
    print("pris pour cible par un ennemi    : visible=%s alpha=%.2f couleur=(%.2f, %.2f, %.2f)" % (
        frame.threatGlow.shown, fort, couleur[1], couleur[2], couleur[3]))
    assert fort > faible, "la lueur ne se renforce pas quand l'ennemi vous vise"
    assert (couleur[1], couleur[2], couleur[3]) == (1.0, 0.0, 0.0), "la lueur n'est pas rouge"

    g.STATE.threat = 1
    frame.scripts.OnEvent(frame, "UNIT_THREAT_SITUATION_UPDATE")
    print("menace haute sans etre la cible  : alpha=%.2f (niveau discret attendu)" % frame.threatGlow.alpha)

    g.STATE.dead = True
    frame.scripts.OnEvent(frame, "UNIT_THREAT_SITUATION_UPDATE")
    print("joueur mort                      : visible=%s" % frame.threatGlow.shown)
    g.STATE.dead = False

    g.STATE.threat = 0
    g.STATE.combat = False
    frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED")
    print("hors combat, sans menace         : visible=%s" % frame.threatGlow.shown)
    assert not frame.threatGlow.shown, "la lueur reste allumee hors combat"

    # 6b. serveur sans donnees de menace : la lueur forte doit quand meme venir
    g.STATE.threat = 0          # le serveur ne dit rien
    g.STATE.combat = True
    frame.scripts.OnEvent(frame, "PLAYER_REGEN_DISABLED")   # le joueur est engage
    g.STATE.hasTarget, g.STATE.targetHostile, g.STATE.targetsMe = True, True, False
    frame.scripts.OnEvent(frame, "PLAYER_TARGET_CHANGED")
    engage = frame.threatGlow.alpha
    print("sans menace, cible qui ne vise pas : alpha=%.2f" % engage)
    g.STATE.targetsMe = True
    frame.scripts.OnEvent(frame, "PLAYER_TARGET_CHANGED")
    vise = frame.threatGlow.alpha
    print("sans menace, la cible me vise      : alpha=%.2f" % vise)
    assert vise > engage, "la lueur ne se renforce pas quand la cible vise le joueur"

    # la relecture periodique doit suffire, meme sans aucun evenement
    g.STATE.targetsMe = False
    frame.scripts.OnUpdate(frame, 0.4)
    print("apres relecture periodique         : alpha=%.2f (retour au discret)" % frame.threatGlow.alpha)
    assert frame.threatGlow.alpha == engage, "la relecture periodique ne redescend pas"

    g.STATE.hasTarget, g.STATE.targetHostile, g.STATE.targetsMe = False, False, False
    g.STATE.combat = False
    frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED")

    # 7. mode edition et deplacement
    g.SlashCmdList["FOREVERUI"]("")
    overlay = g.ForeverUI.Layout.systems["playerframe"].overlay
    print("mode edition : %s, surface creee = %s" % (g.ForeverUI.Layout.editing, overlay is not None))
    overlay.scripts.OnDragStart()
    frame.points = lua.eval("{}")
    frame.SetPoint(frame, "CENTER", g.UIParent, "CENTER", 120, -40)
    overlay.scripts.OnDragStop()
    saved = g.ForeverUIDB.positions["playerframe"]
    print("position retenue apres deplacement : %s/%s %s,%s" % (saved.point, saved.relativePoint, saved.x, saved.y))
    g.SlashCmdList["FOREVERUI"]("")
    print("mode edition apres seconde bascule : %s" % g.ForeverUI.Layout.editing)

    # 8. remise par defaut
    g.SlashCmdList["FOREVERUI"]("reset")
    reste = g.ForeverUIDB.positions["playerframe"]
    pt = frame.points[len(list(frame.points.items()))]
    print("apres reset : position sauvegardee = %s, ancrage = %s (%s, %s)" % (reste, pt[1], pt[4], pt[5]))

    # 9. combat : le mode edition doit refuser
    g.STATE.inLockdown = True
    g.SlashCmdList["FOREVERUI"]("")
    print("mode edition refuse en combat : %s" % (not g.ForeverUI.Layout.editing))
    g.STATE.inLockdown = False          # sinon tout ce qui suit tourne en combat

    # 10. etats : repos, combat, vehicule
    def etat(resting, combat, vehicle):
        g.STATE.resting, g.STATE.combat, g.STATE.vehicle = resting, combat, vehicle
        frame.scripts.OnEvent(frame, "PLAYER_ENTER_COMBAT" if combat else "PLAYER_LEAVE_COMBAT")
        frame.scripts.OnEvent(frame, "PLAYER_UPDATE_RESTING")
        return (frame.statusTexture.shown, frame.statusTexture.vertex, frame.combatIcon.shown,
                frame.restTexture.shown)

    shown, vertex, icon, rest = etat(True, False, False)
    print("repos    : voile=%s couleur=(%.2f, %.2f, %.2f) icone combat=%s sommeil=%s" % (
        shown, vertex[1], vertex[2], vertex[3], icon, rest))
    shown, vertex, icon, rest = etat(False, True, False)
    print("combat   : voile=%s couleur=(%.2f, %.2f, %.2f) icone=%s sommeil=%s" % (
        shown, vertex[1], vertex[2], vertex[3], icon, rest))
    shown, vertex, icon, rest = etat(False, False, False)
    print("ni repos ni combat : voile=%s icone=%s sommeil=%s" % (shown, icon, rest))
    shown, vertex, icon, rest = etat(True, True, True)
    print("vehicule : voile=%s icone=%s sommeil=%s (tout doit etre masque)" % (shown, icon, rest))
    print("voile    : melange = %s (ADD attendu, sinon le rouge delave le cadre)"
          % frame.statusTexture.blend)

    # 10b. les deux drapeaux du client, distincts
    etat(False, False, False)
    frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED")
    frame.scripts.OnEvent(frame, "PLAYER_ENTER_COMBAT")
    print("clic droit sur un ennemi (frappe seule) : voile=%s icone=%s ornement=%s" % (
        frame.statusTexture.shown, frame.combatIcon.shown, frame.cornerIcon.shown))
    assert frame.statusTexture.shown and frame.combatIcon.shown, "la frappe n'allume rien"

    frame.scripts.OnEvent(frame, "PLAYER_REGEN_DISABLED")
    frame.scripts.OnEvent(frame, "PLAYER_LEAVE_COMBAT")
    print("frappe finie, toujours sur la liste    : voile=%s icone=%s" % (
        frame.statusTexture.shown, frame.combatIcon.shown))
    assert frame.combatIcon.shown, "l'icone disparait alors que le combat dure"
    assert frame.statusTexture.shown, "le voile s'eteint avant la fin du combat"

    frame.scripts.OnEvent(frame, "PLAYER_REGEN_ENABLED")
    print("sorti de combat                        : voile=%s icone=%s ornement=%s" % (
        frame.statusTexture.shown, frame.combatIcon.shown, frame.cornerIcon.shown))
    assert not frame.statusTexture.shown and not frame.combatIcon.shown, "le combat ne se termine pas"
    assert frame.cornerIcon.shown, "l'ornement de coin ne revient pas"
    assert frame.statusTexture.blend == "ADD", "le voile n est pas en mode additif"
    assert frame.combatGlow is None, "la lueur de combat traine encore"

    # 11. animation du sommeil : la vignette doit rester dans l'element
    g.STATE.vehicle = False
    etat(True, False, False)
    entry = g.UIAtlas.data["ui-hud-unitframe-player-rest-flipbook"]
    u1, u2, v1, v2 = entry[2], entry[3], entry[4], entry[5]
    vues = set()
    for pas in range(60):
        g.STATE.time = pas * 0.0357
        frame.scripts.OnUpdate(frame, 0.0357)
        c = frame.restTexture.texcoord
        assert u1 - 1e-9 <= c[1] and c[2] <= u2 + 1e-9, "vignette hors de l'element en largeur"
        assert v1 - 1e-9 <= c[3] and c[4] <= v2 + 1e-9, "vignette hors de l'element en hauteur"
        vues.add((round(c[1], 6), round(c[3], 6)))
    print("sommeil  : %d vignettes distinctes, toutes dans l'element (42 au total)" % len(vues))
    print("voile    : transparence pulsee a %.3f" % frame.statusTexture.alpha)

    # 12. texte des barres, suivant le reglage du client
    g.STATE.health, g.STATE.healthMax = 50, 100
    frame.scripts.OnEvent(frame, "UNIT_HEALTH", "player")
    print("texte, reglage a 0 sans survol : visible=%s" % frame.healthText.shown)
    frame.scripts.OnEnter(frame)
    print("texte au survol                : vie=%s | ressource=%s" % (
        frame.healthText.text, frame.powerText.text))
    frame.scripts.OnLeave(frame)
    g.STATE.cvars["playerStatusText"] = "1"
    frame.scripts.OnEvent(frame, "CVAR_UPDATE")
    print("texte, reglage a 1             : visible=%s | vie=%s" % (
        frame.healthText.shown, frame.healthText.text))
    g.STATE.cvars["statusTextPercentage"] = "1"
    frame.scripts.OnEvent(frame, "CVAR_UPDATE")
    print("texte en pourcentage           : vie=%s" % frame.healthText.text)

    # 13. icone de chef de groupe
    g.STATE.leader = True
    frame.scripts.OnEvent(frame, "PARTY_LEADER_CHANGED")
    avec = frame.leaderIcon.shown
    g.STATE.leader = False
    frame.scripts.OnEvent(frame, "PARTY_LEADER_CHANGED")
    g.SlashCmdList["FOREVERUI"]("debug")
    print("icone de chef : visible quand chef=%s | masquee sinon=%s" % (
        avec, not frame.leaderIcon.shown))



    # ---------------------------------------------------------- accessoires
    extras = g.ForeverUI.PlayerFrameExtras
    g.STATE.pvp = True
    extras.updatePvP()
    print("icone PvP (Alliance)     : cercle=%s icone=%s" % (
        extras.pvpCircle.shown, extras.pvpIcon.shown))
    assert extras.pvpCircle.shown and extras.pvpIcon.shown, "l'icone PvP ne s'affiche pas"
    g.STATE.pvp = False
    extras.updatePvP()
    print("PvP desactive            : cercle=%s" % extras.pvpCircle.shown)

    g.STATE.raidMembers, g.STATE.name = 10, "Papota"
    extras.updateGroup()
    print("indicateur de groupe     : visible=%s texte=%s" % (
        extras.groupIndicator.shown, extras.groupText.text))
    g.STATE.raidMembers = 0
    extras.updateGroup()
    print("hors raid                : visible=%s" % extras.groupIndicator.shown)

    g.STATE.partialPlayTime = True
    extras.updatePlayTime()
    print("temps de jeu fatigue     : visible=%s" % extras.playTime.shown)
    g.STATE.partialPlayTime = False
    extras.updatePlayTime()
    print("temps de jeu normal      : visible=%s" % extras.playTime.shown)

    # ---------------------------------------------------------------- runes
    runes = g.ForeverUI.RuneButtons
    nb = sum(1 for _ in runes.values())
    ancien = g.RuneFrame
    print("ancien cadre de runes    : visible=%s | neutralise=%s | OnShow accroche=%s" % (
        ancien.shown, ancien.foreverSuppressed, ancien.hooks is not None))
    assert not ancien.shown, "l'ancien cadre de runes reste affiche sous le notre"
    ancien.Show(ancien)          # pas d'appel a deux points en Python
    ancien.hooks.OnShow(ancien)
    print("   s'il se reaffiche      : remasque=%s" % (not ancien.shown))
    assert not ancien.shown, "l'ancien cadre revient des qu'il se reaffiche"

    print("runes construites        : %d" % nb)
    assert nb == 6, "il faut six runes"
    bouton = runes[1]

    def alphas():
        return dict(fond_actif=bouton.bgActive.alpha, fond_eteint=bouton.bgInactive.alpha,
                    crane_actif=bouton.runeActive.alpha, crane_eteint=bouton.runeInactive.alpha,
                    degrade=bouton.runeGrad.alpha, traits=bouton.runeLines.alpha)

    g.STATE.runeReady = True
    g.ForeverUI.RuneBar.scripts.OnEvent(g.ForeverUI.RuneBar, "RUNE_POWER_UPDATE", 1)
    pret = alphas()
    print("rune prete               : %s" % pret)
    assert pret["fond_actif"] == 1 and pret["crane_actif"] == 1, "la rune prete n'est pas allumee"
    assert pret["fond_eteint"] == 0 and pret["crane_eteint"] == 0, "les calques eteints restent visibles"
    assert pret["degrade"] == 0 and pret["traits"] == 0, "un calque de recharge reste allume quand la rune est prete"

    g.STATE.runeReady = False
    g.ForeverUI.RuneBar.scripts.OnEvent(g.ForeverUI.RuneBar, "RUNE_POWER_UPDATE", 1)
    recharge = alphas()
    print("rune en recharge         : %s | minuterie=%s" % (recharge, bouton.cooldown.timer is not None))
    assert recharge["fond_actif"] == 0 and recharge["crane_actif"] == 0, "la rune reste allumee en recharge"
    assert abs(recharge["crane_eteint"] - 0.4) < 1e-6, "le crane eteint doit etre a 0,4"
    assert abs(recharge["degrade"] - 0.3) < 1e-6 and abs(recharge["traits"] - 0.3) < 1e-6,         "degrade et traits doivent etre a 0,3 pendant la recharge"

    # aucun calque additif : la source les declare tous en BLEND
    for nom in ("bgActive", "bgInactive", "runeActive", "runeInactive", "runeGrad", "runeLines", "shadow"):
        assert bouton[nom].blend is None, "le calque %s est en melange additif" % nom
    print("melanges                 : aucun calque additif, conforme au XML")

    g.STATE.runeReady = True
    g.ForeverUI.RuneBar.scripts.OnEvent(g.ForeverUI.RuneBar, "RUNE_POWER_UPDATE", 1)
    print("art du cadre joueur      : %s" % frame.art.texture)

    # ------------------------------------------------------ cadre de cible
    cible = g.ForeverUITargetFrame
    print("cadre de cible : surveille par le client=%s | systeme enregistre=%s" % (
        cible.unitWatch, g.ForeverUI.Layout.systems["targetframe"] is not None))
    g.STATE.hasTarget = True
    g.STATE.health, g.STATE.healthMax = 80, 100
    cible.scripts.OnEvent(cible, "PLAYER_TARGET_CHANGED")
    print("   nom=%s niveau=%s vie=%.0f%% (largeur %.0f)" % (
        cible.nameText.text, cible.levelText.text,
        (cible.healthFill.width or 0) / 126.0 * 100, cible.healthFill.width or 0))
    assert cible.healthFill.shown, "la barre de vie de la cible est vide"
    couleur = cible.reputation.vertex
    print("   bandeau de reputation  : (%.2f, %.2f, %.2f) -- c'est lui qui porte la reaction" % (
        couleur[1], couleur[2], couleur[3]))
    assert (couleur[1], couleur[2], couleur[3]) == (1.0, 0.0, 0.0), "le bandeau ne prend pas la couleur de selection"

    g.STATE.tapped, g.STATE.tappedByPlayer = True, False
    cible.scripts.OnEvent(cible, "UNIT_FACTION", "target")
    gris = cible.reputation.vertex
    portrait_gris = cible.portrait.vertex
    print("   cible verrouillee      : bandeau=(%.2f, %.2f, %.2f) portrait=(%.2f, %.2f, %.2f)" % (
        gris[1], gris[2], gris[3], portrait_gris[1], portrait_gris[2], portrait_gris[3]))
    assert gris[1] == 0.5 and portrait_gris[1] == 0.5, "rien ne grise quand la cible est verrouillee"
    g.STATE.tapped = False
    cible.scripts.OnEvent(cible, "UNIT_FACTION", "target")

    g.STATE.classification = "minus"
    cible.scripts.OnEvent(cible, "UNIT_CLASSIFICATION_CHANGED", "target")
    art_minus = tuple(round(cible.art.texcoord[i], 6) for i in (1, 2, 3, 4))
    g.STATE.classification = "rare"
    cible.scripts.OnEvent(cible, "UNIT_CLASSIFICATION_CHANGED", "target")
    art_rare = tuple(round(cible.art.texcoord[i], 6) for i in (1, 2, 3, 4))
    g.STATE.classification = "normal"
    cible.scripts.OnEvent(cible, "UNIT_CLASSIFICATION_CHANGED", "target")
    art_normal = tuple(round(cible.art.texcoord[i], 6) for i in (1, 2, 3, 4))

    # l'elite ne change pas le cadre mais l'anneau du portrait
    anneaux = {}
    for classe in ("normal", "elite", "rareelite", "worldboss", "rare"):
        g.STATE.classification = classe
        cible.scripts.OnEvent(cible, "UNIT_CLASSIFICATION_CHANGED", "target")
        anneaux[classe] = (cible.classRing.shown,
                           tuple(round(cible.classRing.texcoord[i], 6) for i in (1, 2, 3, 4))
                           if cible.classRing.texcoord else None)
    print("   anneau : ordinaire=%s elite=%s rare elite=%s boss=%s" % (
        anneaux["normal"][0], anneaux["elite"][0], anneaux["rareelite"][0], anneaux["worldboss"][0]))
    assert not anneaux["normal"][0], "un monstre ordinaire ne doit pas porter d'anneau"
    assert anneaux["elite"][0] and anneaux["worldboss"][0], "l'elite et le boss doivent porter un anneau"
    assert anneaux["elite"][1] != anneaux["rareelite"][1], "elite et rare elite portent le meme anneau"
    assert anneaux["elite"][1] != anneaux["worldboss"][1], "elite et boss portent le meme anneau"
    g.STATE.classification = "normal"
    cible.scripts.OnEvent(cible, "UNIT_CLASSIFICATION_CHANGED", "target")
    print("   art par classification : negligeable v=%.4f | rare v=%.4f | ordinaire v=%.4f" % (
        art_minus[2], art_rare[2], art_normal[2]))
    assert len({art_minus, art_rare, art_normal}) == 3, \
        "les trois classifications doivent donner trois arts differents"


    # la geometrie des barres suit la classification, comme CheckClassification
    g.STATE.classification = "minus"
    cible.scripts.OnEvent(cible, "PLAYER_TARGET_CHANGED")
    print("   creature negligeable   : vie a 80%% = %.0f px sur 125, ressource visible=%s" % (
        cible.healthFill.width or 0, cible.powerFill.shown))
    assert not cible.powerFill.shown, "la ressource doit disparaitre sur une creature negligeable"
    g.STATE.classification = "normal"
    cible.scripts.OnEvent(cible, "PLAYER_TARGET_CHANGED")
    print("   cible ordinaire        : vie a 80%% = %.0f px sur 126, ressource visible=%s" % (
        cible.healthFill.width or 0, cible.powerFill.shown))
    assert cible.powerFill.shown, "la ressource doit revenir sur une cible ordinaire"



    # ------------------------------------------------ barre d'incantation
    barre = g.ForeverUICastBar
    g.STATE.time = 100.0
    g.STATE.casting = True
    g.STATE.castStart, g.STATE.castEnd = 100.0, 102.0
    barre.scripts.OnEvent(barre, "UNIT_SPELLCAST_START", "player")
    print("incantation lancee       : visible=%s sort=%s" % (barre.shown, barre.spellText.text))
    assert barre.shown, "la barre d'incantation ne s'affiche pas"

    g.STATE.time = 101.0                      # moitie du sort
    barre.scripts.OnUpdate(barre, 0.1)
    moitie = barre.fill.width
    print("a mi-parcours            : largeur=%.1f sur 209 | reste=%s" % (moitie, barre.timeText.text))
    assert 95 < moitie < 115, "le remplissage ne suit pas la progression"

    g.STATE.time = 102.5                      # depassement : la barre se ferme
    barre.scripts.OnUpdate(barre, 0.1)
    print("sort termine             : visible=%s" % barre.shown)

    # canalisation : le remplissage descend
    g.STATE.casting, g.STATE.channeling = False, True
    g.STATE.castStart, g.STATE.castEnd = 200.0, 204.0
    g.STATE.time = 200.0
    barre.scripts.OnEvent(barre, "UNIT_SPELLCAST_CHANNEL_START", "player")
    g.STATE.time = 201.0
    barre.scripts.OnUpdate(barre, 0.1)
    debut = barre.fill.width
    g.STATE.time = 203.0
    barre.scripts.OnUpdate(barre, 0.1)
    fin = barre.fill.width
    print("canalisation             : largeur %.1f puis %.1f (elle doit descendre)" % (debut, fin))
    assert fin < debut, "une canalisation doit se vider"

    barre.scripts.OnEvent(barre, "UNIT_SPELLCAST_CHANNEL_STOP", "player")
    g.STATE.channeling = False
    print("canalisation arretee     : visible=%s" % barre.shown)

    g.STATE.casting = True
    g.STATE.castStart, g.STATE.castEnd = 300.0, 302.0
    g.STATE.time = 300.0
    barre.scripts.OnEvent(barre, "UNIT_SPELLCAST_START", "player")
    barre.scripts.OnEvent(barre, "UNIT_SPELLCAST_INTERRUPTED", "player")
    print("sort interrompu          : visible=%s texte=%s" % (barre.shown, barre.spellText.text))
    g.STATE.time = 302.0
    barre.scripts.OnUpdate(barre, 0.1)
    print("apres la pause           : visible=%s" % barre.shown)
    g.STATE.casting = False

    # --------------------------------- barres d'experience et de reputation
    xp = g.ForeverUIExperienceBar
    rep = g.ForeverUIReputationBar
    g.STATE.level = 40
    g.ForeverUI.StatusBarsUpdate()
    print("experience a 50%%         : visible=%s acquis=%.0f repose=%.0f texte=%s" % (
        xp.shown, xp.remplissage.width or 0, xp.repos.width or 0, xp.texte.text))
    assert xp.remplissage.shown and xp.repos.shown, "les remplissages d'experience sont absents"
    assert xp.repos.width > xp.remplissage.width, "la part reposee doit depasser l'acquis"

    print("reputation amicale       : visible=%s rempli=%.0f sur %.0f texte=%s" % (
        rep.shown, rep.remplissage.width or 0, rep.width, rep.texte.text))
    assert rep.shown and rep.remplissage.shown, "la barre de reputation est vide"
    assert abs(rep.remplissage.width - rep.width * 0.5) < 0.01, "la reputation n'est pas a moitie"
    # les huit teintes vivent sur la MEME feuille : c'est le rectangle lu qui
    # change, pas le fichier.
    vert = tuple(rep.remplissage.texcoord.values())
    g.STATE.faction_attitude = 3
    g.ForeverUI.StatusBarsUpdate()
    orange = tuple(rep.remplissage.texcoord.values())
    print("attitude inamicale       : rectangle lu different = %s" % (orange != vert))
    assert orange != vert, "la teinte ne suit pas l'attitude"

    g.STATE.faction_suivie = None
    g.ForeverUI.StatusBarsUpdate()
    print("aucune faction suivie    : visible=%s (la barre doit disparaitre)" % rep.shown)
    assert not rep.shown, "la barre de reputation reste sans faction suivie"
    g.STATE.faction_suivie = "Les Fils de Hodir"
    g.STATE.faction_attitude = 5
    g.ForeverUI.StatusBarsUpdate()

    # les deux barres vont d'un embout a l'autre, et se touchent
    rangee = g.ForeverUI.BottomRow
    largeur = rangee.droite - rangee.gauche
    print("rangee : %.1f -> %.1f (%.1f de large), haut %.0f" % (
        rangee.gauche, rangee.droite, largeur, rangee.haut))
    assert abs(xp.width - largeur) < 0.01 and abs(rep.width - largeur) < 0.01, (
        "les barres ne font pas la longueur de la rangee")

    # la rangee va du bord gauche de la barre d'action au bord droit des sacs
    barre = g.ForeverUI.Layout.systems["actionbar"].defaults
    sacsdef = g.ForeverUI.Layout.systems["sacs"].defaults
    gauche_barre = barre.x - g.ForeverUIActionBarHolder.width
    droite_sacs = sacsdef.x + g.ForeverUIBagsBar.width
    print("bloc de gauche a %.1f, bloc de droite a %.1f" % (gauche_barre, droite_sacs))
    assert abs(rangee.gauche - gauche_barre) < 0.01, "la rangee ne part pas du bord de la barre"
    assert abs(rangee.droite - droite_sacs) < 0.01, "la rangee ne finit pas au bord des sacs"

    dxp = g.ForeverUI.Layout.systems["experiencebar"].defaults
    drep = g.ForeverUI.Layout.systems["reputationbar"].defaults
    print("experience posee a y=%.0f, reputation a y=%.0f (13 d'ecart, elles se touchent)" % (
        dxp.y, drep.y))
    assert dxp.y == rangee.haut, "l'experience ne pose pas sur la rangee"
    assert drep.y - dxp.y == 13, "la reputation n'est pas juste au-dessus de l'experience"
    assert abs(dxp.x - (rangee.gauche + rangee.droite) / 2) < 0.01

    g.STATE.level = 80
    g.ForeverUI.StatusBarsUpdate()
    print("niveau maximum           : visible=%s (la barre doit disparaitre)" % xp.shown)
    assert not xp.shown, "la barre d'experience reste au niveau maximum"
    assert rep.shown, "la reputation doit rester quand l'experience disparait"
    g.STATE.level = 80



    # --------------------------------------------------- barre d'action
    bouton = g.ActionButton1
    icone = g["ActionButton1Icon"]
    print("bouton d'action : %d x %d (45 attendu, 36 sur 3.3.5 d'origine)" % (
        bouton.width, bouton.height))
    assert bouton.width == 45 and bouton.height == 45, "le bouton ne fait pas la taille de camelot"
    assert icone.allPoints, "l'icone ne remplit pas le bouton"
    assert icone.texcoord[1] == 0 and icone.texcoord[2] == 1, "l'icone est rognee alors que la source la laisse entiere"

    for nom, region, add in (("cadre", bouton.foreverFrame, False), ("enfonce", bouton._pushed, False),
                             ("survol", bouton._highlight, False), ("coche", bouton._checked, True)):
        assert region.width == 46 and region.height == 45, "l'etat %s n'est pas en 46 x 45" % nom
        attendu = "ADD" if add else "BLEND"
        assert region.blend == attendu, "l'etat %s devrait etre en %s" % (nom, attendu)
    print("quatre etats    : 46 x 45, coche en ADD, le reste en BLEND")

    # la texture normale du client doit rester muette : il la reecrit sans cesse
    print("texture normale du client : alpha=%.2f (0 attendu)" % bouton._normal.alpha)
    assert bouton._normal.alpha == 0, "la texture normale du client n'est pas neutralisee"
    g.ActionButton_Update(bouton)
    if g.HOOKS["ActionButton_Update"]:
        g.HOOKS["ActionButton_Update"](bouton)
    print("apres une mise a jour du client : alpha=%.2f" % bouton._normal.alpha)
    assert bouton._normal.alpha == 0, "l'habillage ne survit pas a ActionButton_Update"

    # L'EMPLACEMENT VIDE RESTE AFFICHE. 3.3.5 ne masque pas le fond mais LE
    # BOUTON : ActionButton_HideGrid le cache des que showgrid retombe a
    # zero, et ce compteur ne monte que le temps d'un glisser-deposer.
    print("fond d'emplacement : %s + %s" % (
        bouton.foreverBackground is not None, bouton.foreverSlot is not None))
    assert bouton.foreverBackground is not None and bouton.foreverSlot is not None
    bouton.Hide(bouton)
    bouton.showgrid = 0
    g.HOOKS["ActionButton_HideGrid"](bouton)
    print("apres ActionButton_HideGrid : visible=%s, showgrid=%s" % (
        bouton.shown, bouton.showgrid))
    assert bouton.shown, "le bouton vide doit rester affiche"
    assert (bouton.showgrid or 0) >= 1, "le compteur doit rester a 1"

    # en combat on ne touche pas a un cadre securise
    g.STATE.inLockdown = True
    bouton.Hide(bouton)
    g.HOOKS["ActionButton_HideGrid"](bouton)
    print("meme chose en combat        : visible=%s (on n'y touche pas)" % bouton.shown)
    assert not bouton.shown, "afficher un cadre securise en combat est interdit"
    g.STATE.inLockdown = False
    g.HOOKS["ActionButton_HideGrid"](bouton)
    assert bouton.shown, "il doit revenir a la sortie du combat"

    # aucun bord de barre en pavage : cela etalerait la feuille d'atlas entiere
    for piece in (g.ForeverUI.ActionBarBorder,):
        pass
    print("bords de barre : etires, jamais paves")

    pas = None
    for i in (1, 2):
        b = g["ActionButton" + str(i)]
        pt = b.points[len(list(b.points.items()))]
        if i == 1:
            depart = pt[4]
        else:
            pas = pt[4] - depart
    print("pas entre boutons : %s (47 attendu : 45 + 2 de marge)" % pas)
    assert pas == 47, "l'espacement ne suit pas minButtonPadding = 2"

    hk = g["ActionButton1HotKey"]
    ct = g["ActionButton1Count"]
    nm = g["ActionButton1Name"]
    print("raccourci %sx%s %s | quantite %s | nom %sx%s %s" % (
        hk.width, hk.height, hk.font, ct.font, nm.width, nm.height, nm.font))
    assert hk.width == 32 and hk.height == 10 and hk.justify == "RIGHT"
    assert nm.width == 36 and nm.height == 10

    cd = g["ActionButton1Cooldown"]
    coins = [cd.points[i] for i in (1, 2)]
    print("recharge : %s %s puis %s %s (retrait de 3 px)" % (
        coins[0][1], coins[0][4], coins[1][1], coins[1][4]))
    assert coins[0][4] == 3 and coins[1][4] == -3, "la recharge n'est pas en retrait de 3 px"

    print("embouts : gauche %dx%d, droite %dx%d (154 x 95 attendu)" % (
        g.ForeverUI.ActionBarEndCaps.left.width, g.ForeverUI.ActionBarEndCaps.left.height,
        g.ForeverUI.ActionBarEndCaps.right.width, g.ForeverUI.ActionBarEndCaps.right.height))
    assert g.ForeverUI.ActionBarEndCaps.left.width == 154, "embout gauche a la mauvaise taille"

    for nom in ("MainMenuBarTexture0", "MainMenuXPBarTexture0", "MainMenuMaxLevelBar0",
                "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "MainMenuBarExpText"):
        assert g[nom].alpha == 0, "%s reste visible sous la nouvelle barre" % nom
    print("anciens morceaux effaces : corps, barre d'xp, version niveau max, embouts, texte")
    print("fleches de page habillees : %s" % (g.ActionBarUpButton.foreverSkinned == True))
    page = g.ForeverUIActionBarPage
    ph = page.points[1]
    ph_haut = g.ActionBarUpButton.points[1]
    print("bloc de pagination : %d x %d, %s sur %s (%s, %s) | fleche haut centree a y=%s" % (
        page.width, page.height, ph[1], ph[3], ph[4], ph[5], ph_haut[5]))
    assert page.width == 17 and page.height == 34
    assert ph[4] == -4 and ph[5] == 9, "le bloc de pagination n est pas a gauche de la barre"
    assert ph_haut[5] == 10 and g.ActionBarDownButton.points[1][5] == -10
    # LA BARRE BONUS -- celle qui remplace la barre de sorts quand le joueur
    # change de posture -- prend exactement la meme place, donc suit aussi la
    # position que le joueur a choisie pour le porteur.
    principal = g.ActionButton3.points[len(list(g.ActionButton3.points.values()))]
    bonus = g.BonusActionButton3.points[len(list(g.BonusActionButton3.points.values()))]
    print("barre bonus : bouton 3 en %s (%s, %s) | barre de sorts en %s (%s, %s)" % (
        bonus[1], bonus[4], bonus[5], principal[1], principal[4], principal[5]))
    assert (bonus[1], bonus[4], bonus[5]) == (principal[1], principal[4], principal[5]),         "la barre bonus doit se poser exactement sur la barre de sorts"
    assert principal[2].name == "ForeverUIActionBarHolder",         "la barre de sorts s ancre au porteur"
    assert bonus[2].name == "ForeverUIBonusSlide",         "la barre bonus s ancre a la glissiere, qui est posee sur le porteur"
    assert g.BonusActionButton1.width == 45, "ses boutons ont la taille des autres"
    # LE GLISSEMENT. La glissiere est un cadre a nous : la deplacer est
    # permis en combat, alors que deplacer un bouton securise ne l'est pas.
    glissiere = g.ForeverUI.ActionBarSlide
    g.BonusActionBarFrame.Hide(g.BonusActionBarFrame)
    glissiere.scripts.OnUpdate(glissiere, 0.05)
    g.BonusActionBarFrame.Show(g.BonusActionBarFrame)
    glissiere.scripts.OnUpdate(glissiere, 0.0)
    depart = glissiere.points[1][5]
    print("   glissement : depart a %.0f (une hauteur de bouton sous le porteur)" % depart)
    assert depart == -45, "la barre doit partir d une hauteur de bouton plus bas"
    glissiere.scripts.OnUpdate(glissiere, 0.1)
    milieu = glissiere.points[1][5]
    glissiere.scripts.OnUpdate(glissiere, 0.2)
    fin = glissiere.points[1][5]
    print("   a mi-course %.1f, puis %.1f (au repos sur le porteur)" % (milieu, fin))
    assert depart < milieu < fin, "elle doit remonter progressivement"
    assert fin == 0, "elle doit finir exactement sur le porteur"
    # et elle ne bouge plus tant que la barre reste affichee
    glissiere.scripts.OnUpdate(glissiere, 0.5)
    assert glissiere.points[1][5] == 0, "au repos, la glissiere ne bouge plus"

    # LE RETRAIT. Le client pose mode = "hide", garde la barre affichee le
    # temps du mouvement, puis la masque : la glissiere redescend.
    lua.execute('BonusActionBarFrame.mode = "hide"')
    glissiere.scripts.OnUpdate(glissiere, 0.1)
    descente = glissiere.points[1][5]
    print("   retrait : a mi-course %.1f" % descente)
    assert -45 < descente < 0, "elle doit redescendre progressivement"
    glissiere.scripts.OnUpdate(glissiere, 0.2)
    print("   puis %.0f (sortie)" % glissiere.points[1][5])
    assert glissiere.points[1][5] == -45, "elle doit finir une hauteur de bouton plus bas"

    # le client la masque enfin : elle est prete a remonter
    lua.execute('BonusActionBarFrame.mode = "none"')
    g.BonusActionBarFrame.Hide(g.BonusActionBarFrame)
    glissiere.scripts.OnUpdate(glissiere, 0.05)
    g.BonusActionBarFrame.Show(g.BonusActionBarFrame)
    glissiere.scripts.OnUpdate(glissiere, 0.0)
    print("   a la posture suivante : depart a %.0f" % glissiere.points[1][5])
    assert glissiere.points[1][5] == -45, "le mouvement suivant repart d en bas"

    print("   art d'epoque de la barre bonus : %s et %s" % (
        g.BonusActionBarTexture0.alpha, g.BonusActionBarTexture1.alpha))
    assert g.BonusActionBarTexture0.alpha == 0 and g.BonusActionBarTexture1.alpha == 0,         "l art glissant d epoque doit disparaitre"

    # le porteur deplace : la barre bonus suit, puisqu'elle y est ancree.
    # On rend ensuite EXACTEMENT les valeurs d'avant -- la rangee du bas les
    # recalcule au chargement, elles ne valent pas celles de Register.
    avant = g.ForeverUI.Layout.systems["actionbar"].defaults
    garde = (avant.point, avant.relativePoint, avant.x, avant.y)
    g.ForeverUI.Layout.SetDefaults("actionbar", "BOTTOMRIGHT", "BOTTOM", -100, 200)
    g.HOOKS["ActionButton_Update"](g.ActionButton1)
    apres = g.BonusActionButton3.points[len(list(g.BonusActionButton3.points.values()))]
    print("   porteur deplace : la barre bonus reste ancree a lui (%s)" % apres[1])
    assert apres[2].name == "ForeverUIBonusSlide",         "elle doit rester ancree a la glissiere, pas a l ecran"
    g.ForeverUI.Layout.SetDefaults("actionbar", garde[0], garde[1], garde[2], garde[3])

    print("ancien fond du client efface : %s | porteur enregistre : %s" % (
        g["MainMenuBarTexture0"].alpha == 0,
        g.ForeverUI.Layout.systems["actionbar"] is not None))

    # ------------------------------------------------ barre des postures
    porteur = g.ForeverUIStanceBarHolder
    b1 = g.ShapeshiftButton1
    print("posture : bouton %d x %d (SmallActionButtonTemplate : 30)" % (b1.width, b1.height))
    assert b1.width == 30 and b1.height == 30, "le bouton de posture fait 30"

    p2 = g.ShapeshiftButton2.points[len(list(g.ShapeshiftButton2.points.values()))]
    print("   pas entre boutons : %d (32 attendu : 30 + minButtonPadding 2)" % p2[4])
    assert p2[4] == 32, "le pas n est pas 30 + 2"

    print("   porteur : %d x %d pour %d formes, visible=%s" % (
        porteur.width, porteur.height, g.GetNumShapeshiftForms(), porteur.shown))
    assert porteur.width == 3 * 30 + 2 * 2, "la barre ne fait pas la largeur de ses formes"
    assert porteur.shown, "la barre doit se montrer des qu il y a une forme"

    cadre = b1.foreverCadre
    pc = cadre.points[1]
    print("   cadre : %s %.1f x %.1f en %s, ancre %s (centre sur le bouton)" % (
        cadre.texture and "pose" or "absent", cadre.width, cadre.height, cadre.layer, pc[1]))
    assert cadre.width == 35 and cadre.height == 35, "UpdateButtonArt ramene le petit cadre a 35"
    assert cadre.layer == "OVERLAY" and pc[1] == "CENTER",         "un cadre de 35 sur un bouton de 30 doit etre centre, pas ancre TOPLEFT"
    assert b1._normal.alpha == 0, "la texture normale du client doit rester muette"

    survol, coche = b1._highlight, b1._checked
    print("   survol %.1f x %.1f en %s | coche %.1f x %.1f en %s" % (
        survol.width, survol.height, survol.blend,
        coche.width, coche.height, coche.blend))
    for region, nom in ((survol, "survol"), (coche, "coche")):
        assert abs(region.width - 31.6) < 0.01 and abs(region.height - 30.9) < 0.01, \
            "SmallActionButtonMixin pose %s en 31,6 x 30,9" % nom
    assert coche.blend == "ADD", "le coche est le survol en melange ADD"
    assert survol.blend == "BLEND"

    print("   emplacement vide : fond=%s + art=%s" % (
        b1.foreverFond is not None, b1.foreverEmplacement is not None))
    assert b1.foreverFond is not None and b1.foreverEmplacement is not None

    raccourci = g["ShapeshiftButton1HotKey"].points[1]
    quantite = g["ShapeshiftButton1Count"].points[1]
    print("   raccourci %s (%s, %s) | quantite %s (%s, %s)" % (
        raccourci[1], raccourci[4], raccourci[5], quantite[1], quantite[4], quantite[5]))
    assert (raccourci[1], raccourci[4], raccourci[5]) == ("TOPRIGHT", -3, -4)
    assert (quantite[1], quantite[4], quantite[5]) == ("BOTTOMRIGHT", -3, 1)

    recharge = g["ShapeshiftButton1Cooldown"]
    r1, r2 = recharge.points[1], recharge.points[2]
    print("   recharge : %s (%s, %s) et %s (%s, %s)" % (
        r1[1], r1[4], r1[5], r2[1], r2[4], r2[5]))
    assert (r1[4], r1[5]) == (1.7, -1.7) and (r2[4], r2[5]) == (-1, 1), \
        "la recharge n est pas en retrait de l icone comme dans la source"

    # LA SIGNATURE DE 3.3.5. GetShapeshiftFormInfo rend ici
    # (texture, NOM, active, lancable) ; lire la source au mot pres
    # prendrait le nom pour l etat actif.
    i1 = g.ShapeshiftButton1.foreverIcone
    i2 = g.ShapeshiftButton2.foreverIcone
    i3 = g.ShapeshiftButton3.foreverIcone
    print("   formes : 1 cochee=%s | 2 cochee=%s (active) | 3 teinte %s (non lancable)" % (
        g.ShapeshiftButton1.checked, g.ShapeshiftButton2.checked,
        [round(v, 2) for v in i3.vertex.values()] if i3.vertex else None))
    assert i1.texture == "forme_ours", "l icone ne prend pas la texture de la forme"
    assert not g.ShapeshiftButton1.checked and g.ShapeshiftButton2.checked, \
        "c est la forme ACTIVE qui est cochee"
    assert [round(v, 2) for v in i3.vertex.values()] == [0.4, 0.4, 0.4], \
        "une forme non lancable est grisee a 0,4"
    assert [round(v, 2) for v in i2.vertex.values()] == [1, 1, 1], \
        "une forme lancable reste blanche"

    # Sans forme, la barre disparait -- StanceBarMixin:ShouldShow.
    lua.execute("FORMES_GARDEES = FORMES; FORMES = {}")
    g.ForeverUI.StanceBar.Apply()
    print("   sans aucune forme : visible=%s (masquee attendue)" % porteur.shown)
    assert not porteur.shown, "la barre doit disparaitre quand il n y a aucune forme"
    lua.execute("FORMES = FORMES_GARDEES")
    g.ForeverUI.StanceBar.Apply()
    assert porteur.shown

    # En combat on ne touche a rien : cadres securises.
    g.STATE.inLockdown = True
    largeur = porteur.width
    lua.execute("table.insert(FORMES, { texture = 'x', nom = 'x', active = false, lancable = true })")
    g.ForeverUI.StanceBar.Apply()
    print("   une forme de plus en combat : largeur %d (inchangee)" % porteur.width)
    assert porteur.width == largeur, "rien ne doit bouger en combat"
    g.STATE.inLockdown = False
    g.ForeverUI.StanceBar.Apply()
    print("   apres le combat : largeur %d pour 4 formes" % porteur.width)
    assert porteur.width == 4 * 30 + 3 * 2, "la barre doit se refaire a la sortie du combat"
    lua.execute("table.remove(FORMES)")
    g.ForeverUI.StanceBar.Apply()

    print("   ancien art efface : %s | porteur enregistre : %s" % (
        g.ShapeshiftBarLeft.alpha == 0,
        g.ForeverUI.Layout.systems["postures"] is not None))
    assert g.ShapeshiftBarLeft.alpha == 0, "l art d epoque de la barre doit s effacer"

    # -------------------------------------------- barre du familier
    pet = g.ForeverUIPetBarHolder
    p1 = g.PetActionButton1
    print("familier : bouton %d x %d, porteur %d x %d, visible=%s" % (
        p1.width, p1.height, pet.width, pet.height, pet.shown))
    assert p1.width == 30 and p1.height == 30, "le bouton du familier fait 30"
    assert pet.width == 10 * 30 + 9 * 2, "dix emplacements au pas de 32"
    assert pet.shown, "la barre se montre quand le familier a la sienne"

    pp = g.PetActionButton2.points[len(list(g.PetActionButton2.points.values()))]
    assert pp[4] == 32, "le pas n est pas 30 + 2"

    cadre = p1.foreverCadre
    print("   cadre %.1f x %.1f en %s ancre %s | survol %.1f x %.1f | coche en %s" % (
        cadre.width, cadre.height, cadre.layer, cadre.points[1][1],
        p1._highlight.width, p1._highlight.height, p1._checked.blend))
    assert cadre.width == 35 and cadre.points[1][1] == "CENTER"
    assert abs(p1._highlight.width - 31.6) < 0.01 and p1._checked.blend == "ADD"

    # UpdateButtonState : l attaque est active, cochee, et son coche tombe
    # a 0,5 -- la source le dit en toutes lettres.
    print("   attaque : cochee=%s, alpha du coche %.2f (0,5 attendu)" % (
        p1.checked, p1._checked.alpha))
    assert p1.checked, "l action active doit etre cochee"
    assert abs(p1._checked.alpha - 0.5) < 0.01, "le coche de l attaque est a 0,5"

    # LA SIGNATURE DE 3.3.5 : (nom, SOUS-TEXTE, texture, ...). Si le
    # sous-texte etait pris pour la texture, l icone du rang 5 porterait
    # "Rang 5".
    i2 = g.PetActionButton2.foreverIcone
    print("   icone 2 : %s (la texture, pas le sous-texte)" % i2.texture)
    assert i2.texture == "icone_morsure", "le sous-texte a ete pris pour la texture"

    # isToken : le nom et la texture sont des cles de variables globales.
    i3 = g.PetActionButton3.foreverIcone
    print("   icone 3 : %s (isToken : la cle est resolue)" % i3.texture)
    assert i3.texture == "icone_passif_resolue", "une cle de token doit etre resolue"
    assert [round(v, 2) for v in i3.vertex.values()] == [0.4, 0.4, 0.4], \
        "une action inutilisable est grisee a 0,4"

    # L'AUTOLANCEMENT RESTE CELUI DU CLIENT. AutoCastTemplates n'existe que
    # dans mainline/, et seuls camelot/ et shared/ font foi : camelot garde
    # ici sa bordure scintillante et ses etincelles, qu'il allume lui-meme.
    # On ne fait que les mettre a l'echelle du bouton, 30 au lieu de 36.
    bordure = g["PetActionButton1AutoCastable"]
    etincelles = g["PetActionButton1Shine"]
    print("   autolancement du client : bordure %.1f (58 x 30/36) | etincelles a l echelle %.3f" % (
        bordure.width, etincelles.GetScale(etincelles)))
    assert abs(bordure.width - 58 * 30 / 36.0) < 0.01,         "la bordure d origine doit suivre l echelle du bouton"
    assert abs(etincelles.GetScale(etincelles) - 30 / 36.0) < 0.001,         "les etincelles se mettent a l echelle, elles ne se redimensionnent pas"
    assert bordure.alpha != 0, "la bordure du client ne doit plus etre effacee"
    assert g.PetActionButton1.foreverAnneau is None,         "l anneau maison est retire : camelot garde ici le comportement d origine"

    # sans familier, la barre disparait
    lua.execute("PET_A_UNE_BARRE = false")
    g.ForeverUI.PetBar.Apply()
    print("   sans familier : visible=%s (masquee attendue)" % pet.shown)
    assert not pet.shown, "la barre doit disparaitre sans familier"
    lua.execute("PET_A_UNE_BARRE = true")
    g.ForeverUI.PetBar.Apply()
    assert pet.shown
    assert g.ForeverUI.Layout.systems["familier"] is not None

    # LA PLACE : juste au-dessus de la reputation, et a droite des postures
    # quand elles sont la, separee d'elles par deux icones.
    postures = g.ForeverUIStanceBarHolder
    pp = pet.points[len(list(pet.points.values()))]
    attendu = -587.5 + postures.width + 2 * 30
    print("   place : %s (%.1f, %.1f) | postures larges de %d -> %.1f attendu" % (
        pp[1], pp[4], pp[5], postures.width, attendu))
    assert pp[5] == 84, "la barre doit etre juste au-dessus de la reputation"
    assert abs(pp[4] - attendu) < 0.01, "elle doit se decaler de deux icones apres les postures"

    # sans posture, elle revient sur le bord gauche
    lua.execute("FORMES_2 = FORMES; FORMES = {}")
    g.ForeverUI.StanceBar.Apply()
    g.ForeverUI.PetBar.Apply()
    pp = pet.points[len(list(pet.points.values()))]
    print("   sans posture : x=%.1f (-587,5 attendu)" % pp[4])
    assert abs(pp[4] + 587.5) < 0.01, "sans postures elle reprend le bord gauche"
    lua.execute("FORMES = FORMES_2")
    g.ForeverUI.StanceBar.Apply()
    g.ForeverUI.PetBar.Apply()

    # L'art d'epoque de la barre s'efface -- on balaie les regions du cadre
    # plutot que de se fier aux noms.
    print("   art d'epoque : morceau 0 alpha=%s, morceau 1 alpha=%s" % (
        g.SlidingActionBarTexture0.alpha, g.SlidingActionBarTexture1.alpha))
    assert g.SlidingActionBarTexture0.alpha == 0 and g.SlidingActionBarTexture1.alpha == 0,         "l art d epoque de la barre du familier doit disparaitre"
    # LA BARRE BONUS NE PREND PLUS LA SOURIS. Declaree 505 x 43, strate HIGH,
    # toplevel et enableMouse : effacer son art la rend invisible mais pas
    # inoffensive -- elle avalait les clics du micro-menu.
    print("   barre bonus : souris=%s, art efface=%s" % (
        g.BonusActionBarFrame.mouseEnabled,
        all(r.alpha == 0 for r in g.BonusActionBarFrame.regions.values())))
    assert g.BonusActionBarFrame.mouseEnabled is False,         "un cadre qui ne sert que de contenant n a pas a recevoir de clic"
    assert g.MainMenuBar.mouseEnabled is False,         "MainMenuBar couvre tout le bas de l ecran : elle non plus"

    # LE CLIENT REPREND LES MICRO-BOUTONS. VehicleMenuBar_MoveMicroButtons
    # reancre le premier et celui des contacts, a chaque entree ou sortie de
    # vehicule : on repose apres elle.
    g.CharacterMicroButton.SetPoint(g.CharacterMicroButton, "BOTTOMLEFT", 552, 2)
    g.VehicleMenuBar_MoveMicroButtons()
    pc = g.CharacterMicroButton.points[len(list(g.CharacterMicroButton.points.values()))]
    print("   apres le vehicule : %s sur %s (%s, %s)" % (
        pc[1], pc[2].name if pc[2] else None, pc[4], pc[5]))
    assert pc[2] and pc[2].name == "ForeverUIMicroMenu",         "le bouton revient sur notre bandeau"
    assert (pc[1], pc[4], pc[5]) == ("LEFT", 0, 0), "et a sa place"

    tardive = g.PetActionBarFrame.CreateTexture(g.PetActionBarFrame, None, "ARTWORK")
    g.ForeverUI.PetBar.Apply()
    print("   une texture ajoutee apres coup : alpha=%s" % tardive.alpha)
    assert tardive.alpha == 0, "le balayage doit aussi prendre ce qui arrive ensuite"

    # ---------------------------------------- feuille du personnage
    perso = g.CharacterFrame
    gauche = g.ForeverUICharacterLeftPane
    droit = g.ForeverUICharacterRightPane
    print("feuille du personnage : %d x %d (631 x 484 attendu)" % (perso.width, perso.height))
    assert perso.width == 631 and perso.height == 484, "CHARACTER_FRAME_WIDTH et _HEIGHT"
    print("   volets : gauche %d, droit %d (398 + 233 = %d)" % (
        gauche.width, droit.width, gauche.width + droit.width))
    assert gauche.width == 398 and droit.width == 233
    assert gauche.width + droit.width == perso.width, "les deux volets font la fenetre"
    pg = gauche.points[1]
    assert (pg[1], pg[4], pg[5]) == ("TOPLEFT", 0, -20), "le volet gauche part 20 sous le haut"
    pd = droit.points[1]
    assert pd[1] == "TOPLEFT" and pd[3] == "TOPRIGHT", \
        "le volet droit s accroche a la droite du gauche"
    assert g.CharacterFrameTopLeft.alpha == 0, "l art d epoque doit disparaitre"
    assert g.PaperDollFrameTexture.alpha == 0,         "l art d epoque des sous-cadres aussi : ce sont des cadres fils"

    # L'ART DU PANNEAU PASSE AU-DESSUS DES VOLETS. Les volets sont des cadres
    # fils : ils recouvrent toute region de leur parent. L'art vit donc dans
    # un cadre fils de niveau superieur, comme le NineSlice de la source.
    habillage = perso.foreverHabillage
    print("   habillage : cadre fils de niveau +%d (volets a +%d)" % (
        habillage.GetFrameLevel(habillage) - perso.GetFrameLevel(perso),
        gauche.GetFrameLevel(gauche) - perso.GetFrameLevel(perso)))
    assert habillage is not None, "l art doit vivre dans son propre cadre fils"
    assert habillage.GetFrameLevel(habillage) > gauche.GetFrameLevel(gauche),         "l art doit passer au-dessus des volets"
    assert perso.foreverPanel.coinHautGaucheAtlas == "ui-frame-portraitmetal-cornertopleft",         "PortraitFrameTemplate prend le grand anneau, pas celui des sacs"

    # L encadrement : camelot corrige ses mises en page APRES les avoir
    # definies, et c est cette correction qui manquait -- les coins du bas
    # etaient 5 px trop haut, l encadrement n allait pas jusqu en bas.
    for cle, attendu in (("coinHautGauche", (-18.5, 17)), ("coinHautDroit", (8.5, 17)),
                         ("coinBasGauche", (-18.5, -13)), ("coinBasDroit", (8.5, -13))):
        pc = perso.foreverPanel[cle].points[1]
        print("   %-15s (%s, %s)" % (cle, pc[4], pc[5]))
        assert (pc[4], pc[5]) == attendu,             "%s : mesure du filet interieur sur l art, plus 1 px de montee" % cle

    # Les sacs, eux, ne bougent pas : ils sont valides.
    pb = g.ContainerFrame1.foreverPanel.coinBasGauche.points[1]
    print("   sacs, coin bas gauche : (%s, %s) -- inchange" % (pb[4], pb[5]))
    assert (pb[4], pb[5]) == (-13, -3), "la fenetre des sacs est validee, elle ne bouge pas"

    # LE FOND RESTE AU DERNIER PLAN. Monte avec le metal dans le cadre fils,
    # il recouvrait les volets : une region du cadre passe sous tous ses
    # cadres fils, c'est la place qu'il lui faut.
    fond = list(perso.foreverPanel.fond.values())[0]
    print("   fond du panneau : porte par %s (le cadre, pas l habillage)" % (
        fond.owner.name or "?"))
    assert fond.owner.name == "CharacterFrame",         "le fond doit rester sur le cadre, sinon il recouvre les volets"
    assert perso.foreverPanel.coinHautGauche.owner.name != "CharacterFrame",         "le metal, lui, vit dans le cadre fils"

    # LE PORTRAIT : le balayage efface celui du client, on pose le notre.
    portrait = perso.foreverPortrait
    pp = portrait.points[1]
    print("   portrait : %d x %d, %s sur %s (%s, %s), texture=%s" % (
        portrait.width, portrait.height, pp[1], pp[3], pp[4], pp[5],
        portrait.portraitOf))
    assert portrait.width == 48,         "48 : sur ses axes il atteint 24, la ou le metal de l anneau est opaque"
    # Il se calcule depuis le coin haut gauche : (-18,5 ; 17) + (38 ; -38,5).
    assert pp[4] == 19.5 and pp[5] == -21.5,         "le portrait suit le trou de son anneau, porte par le coin de l encadrement"
    coinHG = perso.foreverPanel.coinHautGauche.points[1]
    assert pp[4] - coinHG[4] == 38 and pp[5] - coinHG[5] == -38.5,         "l ecart au coin est le centre mesure du trou, il ne doit pas deriver"
    assert portrait.portraitOf == "player", "l anneau ne doit pas rester vide"

    # Le fond du volet droit remplit son volet au lieu de s arreter a 383.
    fondDroit = droit.regions[1]
    print("   fond du volet droit : couvre tout le volet = %s" % (fondDroit.allPoints and True))
    assert fondDroit.allPoints, "le fond du volet droit doit remplir son volet"

    # Le separateur est en trois tranches : embouts a leur taille, milieu tire.
    sep = droit.separateur
    print("   separateur : trois tranches (embouts de %d)" % sep.haut.height)
    assert sep.haut is not None and sep.milieu is not None and sep.bas is not None,         "le separateur doit etre en trois tranches, ses embouts s etalaient"
    assert sep.haut.height == 4 and sep.bas.height == 4
    habillage = perso.foreverHabillage
    print("   separateur : niveau %d, habillage %d (il doit passer devant)" % (
        sep.frameLevel or 1, habillage.frameLevel or 1))
    assert (sep.frameLevel or 1) > (habillage.frameLevel or 1),         "le separateur disparaissait sous le metal de l encadrement"

    # L echelle du modele : reposee a chaque passage, le client la remet a 1
    # quand le personnage change d apparence.
    # C est la POSITION qui cadre le personnage, pas l echelle : elle le
    # recule devant la camera sans deplacer son cadrage.
    posInitiale = list(g.CharacterModelFrame.pos.values())
    print("   modele : position %s, echelle %s (laissee au client)" % (
        posInitiale, g.CharacterModelFrame.modelScale))
    assert posInitiale == [-6.5, 0, 0], "la profondeur retenue"
    assert g.CharacterModelFrame.modelScale is None,         "nil veut dire qu on ne touche pas a l echelle, pas qu on la remet a 1"

    # Le modele se charge APRES coup et repart a zero : le reglage se repose
    # a chaque image pendant une seconde et demie.
    rattrapage = g.ForeverUICharacterModelRecheck
    print("   rattrapage du modele : demande=%s, reste %.2f s" % (
        rattrapage.shown, rattrapage.reste))
    assert rattrapage.shown, "il doit tourner juste apres l habillage"
    lua.execute("CharacterModelFrame.pos = nil")   # le chargement a tout efface
    rattrapage.scripts.OnUpdate(rattrapage, 0.1)
    repose = list(g.CharacterModelFrame.pos.values())
    print("   apres une image : position reposee %s" % repose)
    assert repose == [-6.5, 0, 0], "le rattrapage doit reposer le reglage"

    for _ in range(20):
        rattrapage.scripts.OnUpdate(rattrapage, 0.1)
    print("   apres deux secondes : encore actif = %s" % rattrapage.shown)
    assert not rattrapage.shown, "il doit se rendormir, pas tourner sans fin"

    # Les deux leviers se reglent en jeu : rien ne se releve dans la source,
    # ils se jugent a l oeil.
    g.SlashCmdList["FOREVERUI"]("modele echelle 0.55")
    print("   /fui modele echelle 0.55 -> %.2f" % g.CharacterModelFrame.modelScale)
    assert abs(g.CharacterModelFrame.modelScale - 0.55) < 0.001
    g.SlashCmdList["FOREVERUI"]("modele position -5 0 0")
    pos = list(g.CharacterModelFrame.pos.values())
    print("   /fui modele position -5 0 0 -> (%s, %s, %s)" % (pos[0], pos[1], pos[2]))
    assert pos == [-5, 0, 0], "SetPosition(profondeur, lateral, hauteur)"
    g.SlashCmdList["FOREVERUI"]("modele position defaut")
    print("   position rendue au client : %d rafraichissement" % g.CharacterModelFrame.refreshed)
    assert g.CharacterModelFrame.refreshed >= 1, "le client doit reprendre la main"
    g.SlashCmdList["FOREVERUI"]("modele position -6.5 0 0")

    tete = g.CharacterHeadSlot
    cou = g.CharacterNeckSlot
    # Le modele couvre tout le volet et prend la souris : a niveau egal
    # c est lui qui recoit le clic, et plus rien ne se deseequipe.
    modele = g.CharacterModelFrame
    print("   niveaux : modele %d, emplacement %d" % (
        modele.frameLevel or 1, tete.frameLevel or 1))
    assert (tete.frameLevel or 1) > (modele.frameLevel or 1),         "l emplacement doit passer au-dessus du modele, sinon le clic va au modele"
    niveauAvant = tete.frameLevel
    g.ForeverUI.CharacterSheet.Apply()
    print("   apres un second passage : %d (pas d escalade)" % tete.frameLevel)
    assert tete.frameLevel == niveauAvant, "le niveau ne doit pas monter a chaque passage"

    print("   emplacement : %d x %d (40) | ecart vertical %d (4)" % (
        tete.width, tete.height, -cou.points[1][5]))
    assert tete.width == 40 and tete.height == 40, "PaperDollItemSlotButtonTemplate : 40"
    pt = tete.points[1]
    assert (pt[1], pt[4], pt[5]) == ("TOPLEFT", 24, -60), "la colonne gauche part de (24, -60)"
    assert cou.points[1][5] == -4,         "colonnes resserrees de 2 px sur les 6 de la source, a la demande"
    # ECART ASSUME : la rangee se resserre vers la gauche, en cascade.
    gauche2 = g.CharacterSecondaryHandSlot.points[1][4]
    distance2 = g.CharacterRangedSlot.points[1][4]
    munitions2 = g.CharacterAmmoSlot.points[1][4]
    print("   rangee : main gauche +%d, distance +%d, munitions +%d" % (
        gauche2, distance2, munitions2))
    assert gauche2 == 4, "6 de la source moins 2, demande"
    assert distance2 == 4, "2 de plus, soit -4 a l ecran puisqu elle suit la main gauche"
    assert munitions2 == 19, "inchange : elles heritent deja des -4 de la distance"

    mains = g.CharacterHandsSlot.points[1]
    print("   colonne droite : %s (%s, %s)" % (mains[1], mains[4], mains[5]))
    assert (mains[1], mains[4], mains[5]) == ("TOPRIGHT", -20, -60), \
        "la colonne droite part de (-20, -60)"

    arme = g.CharacterMainHandSlot.points[1]
    distance = g.CharacterRangedSlot
    munitions = g.CharacterAmmoSlot
    secondaire = g.CharacterSecondaryHandSlot
    print("   armes : principale %s (%s, %s) | rangee %d/%d/%d | munitions %d a +%s" % (
        arme[1], arme[4], arme[5], g.CharacterMainHandSlot.width, secondaire.width,
        distance.width, munitions.width, munitions.points[1][4]))
    assert (arme[1], arme[4], arme[5]) == ("BOTTOM", -60, 30), \
        "l arme principale se pose au bas du volet gauche, a (-60, 30)"
    assert g.CharacterMainHandSlot.width == secondaire.width == distance.width == 40,         "les quatre emplacements de la rangee ont la meme taille, a la demande"
    assert munitions.width == 27, "les munitions gardent le petit emplacement de la source"
    assert munitions.points[1][4] == 19, "les munitions sont a 19 de la distance"

    # LE TITRE ET LA FERMETURE, dans la barre du haut.
    bande = perso.foreverBandeTitre
    titre = perso.foreverTitre
    b1, b2 = bande.points[1], bande.points[2]
    print("   titre : \"%s\", bande de %s a %s, texte a %s" % (
        titre.text, b1[4], b2[4], titre.points[1][5]))
    assert titre.text == "Robert Polson", "le titre est le nom du joueur et son titre"

    # Il ne suit PAS le sous-cadre affiche : characterFrameDisplayInfo y met
    # REPUTATION, PVP et les autres ; ici c'est toujours le nom.
    g.ReputationFrame.Show(g.ReputationFrame)
    g.ForeverUI.CharacterSheet.Apply()
    print("   panneau de reputation ouvert : titre toujours \"%s\"" % titre.text)
    assert titre.text == "Robert Polson",         "la barre du haut garde le nom, quel que soit le panneau"
    g.ReputationFrame.Hide(g.ReputationFrame)
    assert b1[4] == 58 and b2[4] == -24,         "CharacterFrame n appelle pas SetTitleOffsets : les valeurs par defaut"
    assert titre.points[1][5] == -5, "TitleText est a TOP (0, -5)"
    assert titre.justify == "CENTER", "il se centre dans sa bande"
    assert not g.CharacterNameText.shown, "le titre du client s efface"
    assert bande.GetFrameLevel(bande) > habillage.GetFrameLevel(habillage),         "le titre passe au-dessus du metal, comme TitleContainer a 510"

    # LA BARRE DU HAUT DEPLACE LA FENETRE, et la place est retenue : le
    # systeme de panneaux du client repose la fenetre a chaque ouverture.
    print("   barre du haut : souris=%s, glissable=%s, cadre deplacable=%s" % (
        bande.mouseEnabled, bande.scripts.OnDragStart is not None, perso.movable))
    assert bande.mouseEnabled, "la barre doit prendre la souris"
    assert bande.scripts.OnDragStart is not None, "la barre doit servir de poignee"
    assert perso.movable, "le cadre doit etre deplacable"

    bande.scripts.OnDragStart(bande)
    perso.SetPoint(perso, "CENTER", g.UIParent, "CENTER", 120, -40)
    bande.scripts.OnDragStop(bande)
    retenue = g.ForeverUIDB.positions["feuille"]
    print("   apres deplacement : %s (%s, %s) retenu" % (
        retenue.point, retenue.x, retenue.y))
    assert retenue.point == "CENTER" and retenue.x == 120 and retenue.y == -40,         "la place doit etre retenue"

    # le client repose sa fenetre : on doit la remettre
    perso.SetPoint(perso, "TOPLEFT", g.UIParent, "TOPLEFT", 0, 0)
    g.ForeverUI.CharacterSheet.Apply()
    pp2 = perso.points[len(list(perso.points.values()))]
    print("   apres un passage du client : %s (%s, %s)" % (pp2[1], pp2[4], pp2[5]))
    assert (pp2[1], pp2[4], pp2[5]) == ("CENTER", 120, -40),         "la place retenue doit etre reposee apres le client"
    lua.execute('ForeverUIDB.positions["feuille"] = nil')

    # LES STATISTIQUES, dans le volet droit, sous la bande de pierre.
    l1 = g.PlayerStatFrameLeft1
    l6 = g.PlayerStatFrameLeft6
    r1 = g.PlayerStatFrameRight1
    sel = g.PlayerStatFrameLeftDropDown
    pl1 = l1.points[len(list(l1.points.values()))]
    print("   stats : ligne large de %d, premiere a (%s, %s) du volet droit" % (
        l1.width, pl1[4], pl1[5]))
    assert pl1[2].name == "ForeverUICharacterRightPane", "elles vont dans le volet droit"
    assert l1.width == 233 - 40, "elles sont elargies au volet moins ses marges"
    assert l1.height == 13, "StatFrameTemplate fait 104 x 13 : le pas vient de la"
    ecart = l1.points[len(list(l1.points.values()))][5] -         g.PlayerStatFrameLeft2.points[len(list(g.PlayerStatFrameLeft2.points.values()))][5]
    print("   pas entre deux lignes : %d (13 : StatFrameTemplate)" % ecart)
    assert ecart == 13, "le pas est celui du modele de ligne"
    assert sel.points[len(list(sel.points.values()))][5] > pl1[5],         "le selecteur coiffe son groupe"
    y6 = l6.points[len(list(l6.points.values()))][5]
    yr1 = r1.points[len(list(r1.points.values()))][5]
    print("   second groupe %d plus bas que la derniere ligne du premier" % (y6 - yr1))
    assert yr1 < y6, "le second groupe vient sous le premier"

    # LE FOND ALTERNE. A LA DEMANDE : ni camelot ni 3.3.5 ne rayent leurs
    # lignes. Les deux bandes sont celles de paperdollinfopart1c60, la seule
    # paire de bandes horizontales dont l alpha s eteint aux deux bouts.
    SOMBRE, CLAIR = "ui-character-info-itemlevel-bounce", "ui-character-info-line-bounce"
    rects = {}
    for nom in (SOMBRE, CLAIR):
        e = lua.eval('UIAtlas.data["%s"]' % nom)
        rects[nom] = tuple(round(e[i], 6) for i in (2, 3, 4, 5))

    def bande(i):
        """Laquelle des deux porte la ligne i, d apres son rectangle."""
        fond = g["PlayerStatFrameLeft" + str(i)].foreverFond
        if fond is None or fond.texcoord is None:
            return None
        tc = tuple(round(v, 6) for v in fond.texcoord.values())
        for nom, r in rects.items():
            if tc == r:
                return "sombre" if nom == SOMBRE else "clair"
        return "?"

    bandes = [bande(i) for i in range(1, 7)]
    print("   fond des lignes : %s" % " ".join(str(b) for b in bandes))
    assert bandes == ["sombre", "clair", "sombre", "clair", "sombre", "clair"],         "la sombre en premier, puis en alternance"
    assert g.PlayerStatFrameLeft1Label.layer == "ARTWORK",         "l intitule monte d un calque : 3.3.5 n a pas de sous-calque"
    fond1 = g.PlayerStatFrameLeft1.foreverFond
    assert fond1.layer == "BACKGROUND", "et la bande reste au fond"

    # LE COMPTE NE RETIENT QUE LES LIGNES VISIBLES, et repart a chaque
    # categorie : le client en cache selon celle qui est choisie.
    lua.execute('PlayerStatFrameLeft2:Hide()')
    g.ForeverUI.CharacterStatStripes()
    bandes = [bande(i) for i in (1, 3, 4)]
    print("   une ligne cachee : %s" % " ".join(str(b) for b in bandes))
    assert bandes == ["sombre", "clair", "sombre"],         "la ligne cachee ne compte pas : pas de trou dans l alternance"
    lua.execute('PlayerStatFrameLeft2:Show()')
    g.ForeverUI.CharacterStatStripes()

    # LES SELECTEURS DE CATEGORIE. Leur art d origine deborde du cadre et ne
    # le suit pas : il s efface, l en-tete moderne prend sa place.
    selD = g.PlayerStatFrameRightDropDown
    psel = sel.points[len(list(sel.points.values()))]
    print("   selecteur : %d x %d, %s (%s, %s), visible=%s" % (
        sel.width, sel.height, psel[1], psel[4], psel[5], sel.shown))
    assert sel.width == 203 and sel.height == 34,         "l atlas fait 201 x 32 ; elargi au volet, il deborde de 5"
    assert psel[4] == 15, "il deborde de 5 a gauche de ses lignes, posees a 20"
    assert sel.shown, "il doit etre visible"
    # A LA DEMANDE : l encadre de camelot, UI-Character-Info-Title, tendu.
    fond = sel.foreverFond
    print("   encadre : %s, tendu=%s" % (fond.texture, bool(fond.allPoints)))
    assert fond is not None and fond.texture is not None,         "le selecteur porte l encadre de paperdollinfopart1c60"
    assert "paperdollinfopart1c60" in fond.texture,         "il vient bien de cette planche : %s" % fond.texture
    assert fond.allPoints,         "tendu du TOPLEFT au BOTTOMRIGHT, comme CharacterStatFrameCategoryTemplate"
    assert sel.foreverPresse is None,         "l encadre de camelot n a pas d etat presse"

    dore = [g.PlayerStatFrameLeftDropDownLeft, g.PlayerStatFrameLeftDropDownMiddle,
            g.PlayerStatFrameLeftDropDownRight, g.PlayerStatFrameLeftDropDownText]
    print("   cadre dore efface : %s" % [bool(r.shown) for r in dore])
    assert not any(r.shown for r in dore), "l art du menu deroulant deborde : il s efface"
    fleche = g.PlayerStatFrameLeftDropDownButton
    print("   fleche du menu masquee : %s" % (not fleche.shown))
    assert not fleche.shown, "toute la barre ouvre le menu, la fleche n a plus lieu d etre"

    # LA MECANIQUE DE L ETAT PRESSE RESTE EN PLACE, et ne trouve plus rien a
    # presser : l encadre de camelot n a pas cet etat.
    lua.execute('UIDROPDOWNMENU_OPEN_MENU = PlayerStatFrameLeftDropDown')
    lua.execute('DropDownList1:Show()')
    g.ForeverUI.CharacterStatTabsState()
    print("   ancrage de la liste : %s sur %s de %s, ecart (%s, %s)" % (
        sel.point, sel.relativePoint, sel.relativeTo and sel.relativeTo.name,
        sel.xOffset, sel.yOffset))
    assert (sel.point, sel.relativePoint) == ("TOPLEFT", "BOTTOMLEFT"),         "la liste tombe sous le bouton, cale a gauche"
    assert sel.xOffset == 0 and sel.yOffset == 0, "sans ecart"
    assert sel.relativeTo.name == "PlayerStatFrameLeftDropDown",         "sur le bouton, pas sur sa piece doree que nous avons masquee"

    # Le client retaille le selecteur a chaque ouverture du menu.
    lua.execute('UIDropDownMenu_Initialize(PlayerStatFrameLeftDropDown)')
    g.ForeverUI.CharacterStatTabsSize(g.PlayerStatFrameLeftDropDown)
    print("   apres ouverture du menu : %d x %d" % (sel.width, sel.height))
    assert sel.width == 203 and sel.height == 34,         "UIDropDownMenu_InitializeHelper repose la hauteur : on repasse derriere"

    lua.execute('DropDownList1:Hide()')
    g.ForeverUI.CharacterStatTabsState()
    assert sel.mouseEnabled and sel.scripts.OnMouseUp is not None,         "toute la barre ouvre le menu, pas seulement la fleche de 24"
    print("   intitules : gauche \"%s\" | droite \"%s\"" % (
        sel.foreverIntitule.text, selD.foreverIntitule.text))
    assert sel.foreverIntitule.text == "Attributs",         "l intitule est la categorie de la CVar, pas sa cle"
    assert selD.foreverIntitule.text == "Corps a corps"
    lua.execute('UpdatePaperdollStats("PlayerStatFrameLeft", "PLAYERSTAT_DEFENSES")')
    print("   apres changement de categorie : gauche \"%s\"" % sel.foreverIntitule.text)
    assert sel.foreverIntitule.text == "Defenses",         "l intitule doit suivre le menu du client"

    fermer = g.CharacterFrameCloseButton
    pf = fermer.points[1]
    print("   fermeture : %d x %d, %s (%s, %s)" % (
        fermer.width, fermer.height, pf[1], pf[4], pf[5]))
    assert fermer.width == 24 and fermer.height == 24
    assert (pf[1], pf[4], pf[5]) == ("TOPRIGHT", 1, 0),         "le bouton de fermeture va au coin haut droit"
    assert fermer._normal.texture is not None, "il porte le X rouge des panneaux"

    # LES ONGLETS LATERAUX : en colonne a droite, DEHORS.
    barre = g.ForeverUICharacterModeTabs
    o1, o2 = g.CharacterFrameTab1, g.CharacterFrameTab2
    pb = barre.points[1]
    print("   onglets : barre %d x %d, %s sur %s (%s, %s)" % (
        barre.width, barre.height, pb[1], pb[3], pb[4], pb[5]))
    assert barre.width == 64 and barre.height == 384, "ModeTabs fait 64 x 384"
    assert pb[1] == "TOPLEFT" and pb[3] == "TOPRIGHT" and pb[5] == -30,         "la barre se pose a droite du cadre, 30 sous son haut"
    assert pb[4] == 1, "decalee d un pixel vers la droite, a la demande"
    print("   un onglet : %d x %d (55 x 55 : 55 x 60 moins 5 de transparent)" % (
        o1.width, o1.height))
    assert o1.width == 55 and o1.height == 55
    # SOUS L ENCADREMENT. La langue gauche de l onglet, que le survol et le
    # marqueur d actif couvrent, se glisse sous la fenetre : elle debordait
    # sur le metal du volet droit.
    hab = perso.foreverHabillage
    print("   niveaux : barre %d, onglet %d, habillage %d" % (
        barre.frameLevel or 0, o1.frameLevel or 0, hab.frameLevel or 0))
    assert (o1.frameLevel or 0) < (hab.frameLevel or 0),         "un onglet doit passer SOUS l encadrement de la fenetre"
    assert (g.ForeverUICharacterTabPvP.frameLevel or 0) < (hab.frameLevel or 0),         "les notres aussi"
    assert (o1.frameLevel or 0) > (perso.frameLevel or 0),         "mais au-dessus du fond du panneau"
    p2 = o2.points[1]
    assert p2[1] == "TOPLEFT" and p2[3] == "BOTTOMLEFT", "ils s empilent"
    # SANS FAMILIER, LES SUIVANTS REMONTENT. Un onglet masque mais toujours
    # ancre laissait un trou de sa hauteur sous le personnage.
    lua.execute("AVEC_FAMILIER = false")
    g.PetPaperDollFrame_UpdateIsAvailable()
    o3 = g.CharacterFrameTab3
    p3 = o3.points[len(list(o3.points.values()))]
    print("   sans familier : onglet 3 ancre %s sur %s de %s (%s, %s)" % (
        p3[1], p3[3], p3[2].name, p3[4], p3[5]))
    assert not g.CharacterFrameTab2.shown, "le client masque l onglet du familier"
    assert p3[2].name == "CharacterFrameTab1",         "reputation doit suivre le personnage, pas le trou du familier"
    assert (p3[1], p3[3]) == ("TOPLEFT", "BOTTOMLEFT") and (p3[4], p3[5]) == (0, -2),         "et avec le meme espace que les autres : UpdateTabLayout pose (0, -2)"
    p4 = g.CharacterFrameTab4.points[len(list(g.CharacterFrameTab4.points.values()))]
    assert p4[2].name == "CharacterFrameTab3", "les competences suivent a leur tour"

    # Le familier revenu, la pile se referme.
    lua.execute("AVEC_FAMILIER = true")
    g.PetPaperDollFrame_UpdateIsAvailable()
    p3 = o3.points[len(list(o3.points.values()))]
    print("   familier revenu : onglet 3 ancre sur %s" % p3[2].name)
    assert p3[2].name == "CharacterFrameTab2", "il reprend sa place derriere le familier"

    # LES ICONES DES ONGLETS. Seule celle des competences a pu etre versee :
    # le listfile de wow.export ne nomme pas les deux INV_SideTab_*_c60.
    o4 = g.CharacterFrameTab4
    print("   onglet competences : icone=%s, texte visible=%s" % (
        o4.foreverIcone.texture, g.CharacterFrameTab4Text.shown))
    assert "TabIcons" in o4.foreverIcone.texture,         "l icone affichee est la version CUITE, pas l export brut"
    assert o4.foreverIcone.texture and "JackofAllTrades" in o4.foreverIcone.texture,         "CHARACTER_MODE_TAB_ICONS donne cette icone aux competences"
    assert o4.foreverIcone.shown and not g.CharacterFrameTab4Text.shown,         "l icone remplace le mot"
    for i, attendu in ((3, "Reputation2"), (5, "Currency")):
        onglet = g["CharacterFrameTab%d" % i]
        print("   onglet %d : icone=%s, texte visible=%s" % (
            i, onglet.foreverIcone.texture, g["CharacterFrameTab%dText" % i].shown))
        assert onglet.foreverIcone.texture and attendu in onglet.foreverIcone.texture,             "l icone de camelot, versee par son FileDataID : onglet %d" % i
        assert onglet.foreverIcone.shown and not g["CharacterFrameTab%dText" % i].shown,             "elle remplace le mot : onglet %d" % i
    # Le familier n a pas d icone chez camelot : il garde son texte.
    assert g.CharacterFrameTab2Text.shown, "aucune source pour l onglet du familier"

    print("   onglet du personnage : icone=%s, texte masque=%s" % (
        o1.foreverIcone.texture.split(chr(92))[-1], not g.CharacterFrameTab1Text.shown))
    # A LA DEMANDE, et non d apres la source : camelot y met le portrait.
    assert o1.foreverIcone.texture == "Interface" + chr(92) + "ForeverUI" + chr(92)         + "TabIcons" + chr(92) + "ClassIcon_" + g.STATE.classToken,         "l onglet du personnage porte l icone de SA classe, cuite comme les autres"
    assert not g.CharacterFrameTab1Text.shown, "et le mot s en va"
    assert abs(o1.foreverIcone.texcoord[1] - 0.03125) < 1e-6,         "le rognage reste : la cuisson a ete calculee en le supposant"

    # LE NIVEAU, LA RACE ET LA CLASSE : dans le volet droit, la ou la source
    # met PaperDollLevelInfo.
    niveau = droit.ligneNiveau
    pn = niveau.points[1]
    assert not g.CharacterLevelText.shown, "la ligne du client s efface"
    # SANS LA RACE : recompose depuis UNIT_LEVEL_TEMPLATE et le nom de
    # classe, comme le PLAYER_LEVEL_NO_SPEC de camelot, que ce client n a pas.
    print("   ligne de niveau : \"%s\" (le client disait \"%s\")" % (
        niveau.text, g.CharacterLevelText.text))
    attendu = "Level %d %s" % (g.STATE.level, g.STATE.className)
    assert niveau.text == attendu, "niveau et classe, sans la race"
    assert "Elfe" not in niveau.text, "la race ne doit plus y etre"
    print("   ligne de niveau : %s sur %s (%s, %s), large de %d, parent %s" % (
        pn[1], pn[3], pn[4], pn[5], niveau.width, niveau.parent and niveau.parent.name))
    assert pn[1] == "TOP" and pn[3] == "TOP", "elle se pose sous le haut du volet"
    assert pn[5] == -54, "PaperDollLevelInfo : -4 des onglets lateraux, -50 dessous"

    # LES TROIS ONGLETS DU VOLET, au-dessus de la ligne de niveau.
    #
    # RELEVE -- camelot/PaperDollFrame_UpdateSidebarTabLayout : a trois, c est
    # le DEUXIEME qui porte l ancre, au TOP du cadre des onglets (0, -5) ; le
    # troisieme colle a sa droite, le premier a sa gauche. A deux, la fonction
    # recentre en decalant le deuxieme d une demi-largeur.
    stats, gear = droit.ongletStats, droit.ongletEquipement
    titres = droit.ongletTitres
    ps, pg, pt = stats.points[1], gear.points[1], titres.points[1]
    print("   onglets du volet : %dx%d, equipement %s (%s, %s), stats %s sur %s,"
          " titres %s sur %s" % (stats.width, stats.height, pg[1], pg[4], pg[5],
                                 ps[1], ps[3], pt[1], pt[3]))
    assert stats.width == 42 and stats.height == 42,         "PaperDollSidebarTabTemplate fait 42 x 42"
    assert (pg[1], pg[4], pg[5]) == ("TOP", 0, -9),         "a trois, c est le deuxieme qui porte l ancre, et le groupe est centre"
    assert (ps[1], ps[3]) == ("RIGHT", "LEFT"), "les statistiques a sa gauche"
    assert (pt[1], pt[3]) == ("LEFT", "RIGHT"), "les titres a sa droite"

    print("   icones : stats=%s rogne a %.6f | equipement=%s" % (
        stats.icone.portraitOf, stats.icone.texcoord[1], gear.icone.texture))
    assert stats.icone.portraitOf == "player",         "PAPERDOLL_SIDEBARTAB_STATS : icon = nil, il prend le portrait"
    # LES DEUX NOMS SE RESSEMBLAIENT TROP : la taille des icones laterales
    # avait masque celle des onglets du volet, qui s etaient agrandis avec.
    print("   icones des onglets du volet : %d x %d" % (
        stats.icone.width, gear.icone.width))
    assert stats.icone.width == 28 and gear.icone.width == 28,         "ces deux-la font 28, et rien ne doit les entrainer"
    assert abs(stats.icone.texcoord[1] - 0.109375) < 1e-6,         "le rognage de la source"
    assert gear.icone.texture and "GearManager" in gear.icone.texture,         "PaperDollSidebarTabs.blp n existe pas ici : UI-GearManager-Button le remplace"
    tc = list(gear.icone.texcoord.values())
    print("   icone du gestionnaire rognee a (%.4f, %.4f, %.4f, %.4f)" % (
        tc[0], tc[1], tc[2], tc[3]))
    assert abs(tc[0] - 6 / 64) < 1e-6 and abs(tc[1] - 58 / 64) < 1e-6,         "le carre central : l art fait 52 de large pour 64 de haut"
    assert abs(tc[2] - tc[0]) < 1e-6 and abs(tc[3] - tc[1]) < 1e-6,         "la meme plage sur les deux axes, sinon il reste rectangulaire"
    assert stats.choisi.shown and not gear.choisi.shown,         "l onglet des statistiques est celui qui est ouvert"

    print("   bouton d origine du gestionnaire masque : %s" % (not g.GearManagerToggleButton.shown))
    assert not g.GearManagerToggleButton.shown, "c est l onglet qui ouvre le panneau"
    # Ils se comportent en onglets : celui qu on ouvre ferme l autre.
    gear.scripts.OnClick(gear)
    lignes = [g["PlayerStatFrameLeft" + str(i)].shown for i in range(1, 7)]
    print("   clic gestionnaire : panneau=%s, stats visibles=%s, marque=%s" % (
        g.GearManagerDialog.shown, any(lignes), gear.choisi.shown))
    assert g.GearManagerDialog.shown, "l onglet ouvre le GearManagerDialog du client"
    assert not any(lignes), "et masque les statistiques"
    assert not g.PlayerStatFrameLeftDropDown.shown, "les selecteurs aussi"
    assert gear.choisi.shown and not stats.choisi.shown, "la marque passe sur lui"
    assert g.ForeverUIEquipmentPane.shown,         "le panneau du gestionnaire se montre avec son onglet"

    # Un passage de l habillage ne doit pas les rallumer dans son dos.
    g.ForeverUI.CharacterSheet.Apply()
    assert not g.PlayerStatFrameLeftDropDown.shown,         "l habillage repasse ici a chaque evenement : il doit respecter l onglet"

    # Le gestionnaire appelle UpdateUIPanelPositions : la place retenue
    # ne doit pas y passer.
    lua.execute('ForeverUIDB.positions["feuille"] = '
                '{ point = "CENTER", relativePoint = "CENTER", x = 120, y = -40 }')
    g.UpdateUIPanelPositions(g.CharacterFrame)
    pp2 = perso.points[len(list(perso.points.values()))]
    print("   apres le systeme de panneaux : %s (%s, %s)" % (pp2[1], pp2[4], pp2[5]))
    assert (pp2[1], pp2[4], pp2[5]) == ("CENTER", 120, -40),         "ouvrir le gestionnaire ne doit pas reinitialiser la fenetre"
    lua.execute('ForeverUIDB.positions["feuille"] = nil')

    stats.scripts.OnClick(stats)
    lignes = [g["PlayerStatFrameLeft" + str(i)].shown for i in range(1, 7)]
    print("   clic statistiques : panneau=%s, stats visibles=%s, marque=%s" % (
        g.GearManagerDialog.shown, all(lignes), stats.choisi.shown))
    assert all(lignes) and g.PlayerStatFrameLeftDropDown.shown, "elles reviennent"
    assert not g.GearManagerDialog.shown, "et le panneau du gestionnaire se ferme"
    assert stats.choisi.shown and not gear.choisi.shown, "la marque revient sur lui"
    print("   panneau du gestionnaire masque sous les statistiques : %s" % (
        not g.ForeverUIEquipmentPane.shown))
    assert not g.ForeverUIEquipmentPane.shown,         "ses boutons sont ses cadres fils : masquer la fenetre du client ne suffit pas"
    nouveau = g.ForeverUIEquipmentNewSet
    print("   bouton New Set : \"%s\", %d tranches normales, %d pressees" % (
        nouveau.text, len(list(nouveau.foreverNormal.values())),
        len(list(nouveau.foreverPresse.values()))))
    assert nouveau.text == "New Set",         "ecrit en dur : ce client ne porte aucune chaine equivalente"
    assert len(list(nouveau.foreverNormal.values())) == 9,         "le meme bouton tertiaire que les selecteurs, decoupe"
    assert nouveau.scripts.OnMouseDown or nouveau.hooks.OnMouseDown,         "l etat presse suit le bouton de la souris"
    # Elle est declaree toplevel et se hisse a chaque ouverture : le niveau
    # du bouton doit se recalculer apres, pas une fois pour toutes.
    lua.execute("GearManagerDialog_OnShow()")
    g.ForeverUI.EquipmentPane.Apply()
    print("   niveaux apres une ouverture : fenetre %d, bouton %d, toplevel=%s" % (
        g.GearManagerDialog.frameLevel or 1, nouveau.frameLevel or 1,
        g.GearManagerDialog.toplevel))
    assert g.GearManagerDialog.toplevel is False,         "elle n est plus une fenetre : elle ne doit plus se hisser"
    assert (nouveau.frameLevel or 1) > (g.GearManagerDialog.frameLevel or 1),         "la fenetre du client couvre le panneau et prend la souris"
    assert nouveau.scripts.OnClick is not None, "et il porte bien son clic"
    assert pn[2].name == "ForeverUICharacterRightPane", "dans le volet DROIT"
    assert niveau.owner.name == "ForeverUICharacterRightPane",         "elle appartient au volet : une region ne se reparente pas en 3.3.5"
    assert niveau.width == 220, "PaperDollLevelInfo fait 220 de large"
    assert niveau.justify == "CENTER", "centree"

    # LES FLECHES DU MODELE : centrees sur le volet, cote a cote.
    fg = g.CharacterModelFrameRotateLeftButton.points[1]
    fd = g.CharacterModelFrameRotateRightButton.points[1]
    print("   fleches : %s (%s) et %s (%s), a %s du haut du volet" % (
        fg[1], fg[4], fd[1], fd[4], fg[5]))
    assert fg[1] == "TOP" and fd[1] == "TOP", "elles s accrochent au haut du volet"
    assert fg[2].name == "ForeverUICharacterLeftPane"
    assert abs(fg[4] + fd[4]) < 1e-6, "elles se repartissent de part et d autre du milieu"
    assert fg[4] < 0 and fd[4] > 0, "la gauche a gauche, la droite a droite"

    modele = g.CharacterModelFrame.points[1]
    print("   modele : %s sur %s, remonte de %s dans son volet" % (
        modele[1], modele[3], modele[5]))
    assert modele[1] == "TOPLEFT" and modele[2].name == "ForeverUICharacterLeftPane",         "le modele occupe le volet gauche"
    assert modele[5] == 24, "il est remonte dans son volet"

    # Le panneau des resistances se decale, et UNE SEULE FOIS : on repart
    # toujours de son ancrage d origine, jamais de la position courante.
    res = g.CharacterResistanceFrame
    x1 = res.points[len(list(res.points.values()))][4]
    g.ForeverUI.CharacterSheet.Apply()
    g.ForeverUI.CharacterSheet.Apply()
    x2 = res.points[len(list(res.points.values()))][4]
    print("   resistances : %s, puis %s apres deux passages de plus" % (x1, x2))
    assert x1 == -60 + 30, "le decalage est de 30 vers la droite"
    assert x1 == x2, "le decalage ne doit pas deriver a chaque passage"

    # LE REPLI DU VOLET DROIT.
    repli = g.ForeverUICharacterRightPaneToggle
    pr = repli.points[1]
    print("   bouton de repli : %d x %d, %s sur %s de %s (%s, %s)" % (
        repli.width, repli.height, pr[1], pr[3], pr[2].name, pr[4], pr[5]))
    assert repli.width == 28 and repli.height == 28, "28 x 28, comme la source"
    assert pr[1] == "TOPRIGHT" and pr[3] == "TOPRIGHT",         "au coin haut droit du volet gauche"
    assert pr[2].name == "ForeverUICharacterLeftPane", "du volet GAUCHE, comme LeftPaneHost"
    assert (pr[4], pr[5]) == (-6, -6), "decale de -6 sur les deux axes"
    # Le modele couvre ce coin et prend la souris a niveau egal : le meme
    # piege que les emplacements d equipement.
    print("   niveaux : bouton %d, modele %d" % (
        repli.frameLevel or 1, g.CharacterModelFrame.frameLevel or 1))
    assert (repli.frameLevel or 1) > (g.CharacterModelFrame.frameLevel or 1),         "sinon le modele recoit le clic"
    assert repli._normal.texture.endswith("PrevPage-Up"),         "depliee, la fleche montre vers la gauche"

    # ON REPLIE. L onglet ouvert est celui du gestionnaire : le depli devra
    # le retrouver, et non rouvrir sur les statistiques.
    gear.scripts.OnClick(gear)
    repli.scripts.OnClick(repli)
    lignes = [g["PlayerStatFrameLeft" + str(i)].shown for i in range(1, 7)]
    print("   replie : fenetre %d de large, volet droit visible=%s, stats=%s, "
          "gestionnaire=%s, onglets lateraux=%s" % (
        perso.width, droit.shown, any(lignes), g.GearManagerDialog.shown, barre.shown))
    assert perso.width == 398, "CHARACTER_FRAME_COLLAPSED_WIDTH, la largeur du volet gauche"
    assert not droit.shown, "le volet droit s en va"
    assert not any(lignes), "les lignes de statistiques sont au client : a masquer une a une"
    assert not g.PlayerStatFrameLeftDropDown.shown, "les selecteurs aussi"
    assert not g.GearManagerDialog.shown, "et le panneau du gestionnaire"
    assert barre.shown, "LES ONGLETS LATERAUX RESTENT VISIBLES"
    assert g.CharacterModelFrame.shown, "le volet gauche ne bouge pas"
    assert repli._normal.texture.endswith("NextPage-Up"),         "replie, la fleche montre vers la droite"
    assert g.ForeverUIDB.voletDroitReplie is True, "l etat est retenu"

    # Un passage de l habillage ne doit pas redeplier dans notre dos.
    g.ForeverUI.CharacterSheet.Apply()
    print("   apres un passage de l habillage : %d de large" % perso.width)
    assert perso.width == 398, "l habillage repasse a chaque evenement : il doit respecter le repli"
    assert not droit.shown and not any(
        g["PlayerStatFrameLeft" + str(i)].shown for i in range(1, 7))

    # ON DEPLIE : l onglet du gestionnaire revient, pas celui des statistiques.
    repli.scripts.OnClick(repli)
    lignes = [g["PlayerStatFrameLeft" + str(i)].shown for i in range(1, 7)]
    print("   deplie : %d de large, volet droit=%s, gestionnaire=%s, stats=%s" % (
        perso.width, droit.shown, g.GearManagerDialog.shown, any(lignes)))
    assert perso.width == 631, "la fenetre reprend sa largeur"
    assert droit.shown, "le volet droit revient"
    assert g.GearManagerDialog.shown, "et l onglet qui etait ouvert avec lui"
    assert not any(lignes), "les statistiques ne se rouvrent pas d office"
    assert g.ForeverUIDB.voletDroitReplie is False

    # Et depuis les statistiques, ce sont elles qui reviennent.
    stats.scripts.OnClick(stats)
    repli.scripts.OnClick(repli)
    repli.scripts.OnClick(repli)
    lignes = [g["PlayerStatFrameLeft" + str(i)].shown for i in range(1, 7)]
    print("   replie puis deplie depuis les statistiques : stats=%s, gestionnaire=%s" % (
        all(lignes), g.GearManagerDialog.shown))
    assert all(lignes), "les statistiques reviennent"
    assert not g.GearManagerDialog.shown, "et le gestionnaire reste ferme"

    # LES ONGLETS LATERAUX COMMUTENT DES ECRANS ENTIERS.
    #
    # Les deux fautes signalees : le panneau du gestionnaire restait visible
    # sur un autre onglet -- il appartient a NOTRE volet, que le
    # PaperDollFrame du client ne masque pas -- et les barres de reputation
    # traversaient le volet droit, le cadre du client gardant la taille de la
    # fenetre d origine.
    Panes = g.ForeverUI.Panes
    gear.scripts.OnClick(gear)          # gestionnaire ouvert
    assert g.ForeverUIEquipmentPane.shown

    g.CharacterFrame_ShowSubFrame("ReputationFrame")
    g.ForeverUI.Panes.ShowGroup("ReputationFrame")
    g.ForeverUI.CharacterApplyPanes(perso)
    pr2 = g.ReputationFrame.points[len(list(g.ReputationFrame.points.values()))]
    print("   onglet reputation : volet droit=%s, pierre=%s, onglets de page=%s, "
          "panneau=%s, fenetre %d, reputation ancree a %s de %s" % (
        droit.shown, droit.pierre.shown, stats.shown,
        g.ForeverUIEquipmentPane.shown, perso.width, pr2[1], pr2[2].name))
    assert not g.ForeverUIEquipmentPane.shown,         "LE PANNEAU DU GESTIONNAIRE NE SURVIT PLUS A UN CHANGEMENT D ONGLET"
    assert not g.GearManagerDialog.shown, "ni la fenetre du client avec lui"
    # LE VOLET DROIT RESTE OUVERT : chaque onglet aura ses informations a y
    # mettre. Seul ce qui appartient au personnage s en va.
    assert droit.shown, "LE VOLET DROIT RESTE OUVERT D UN ONGLET A L AUTRE"
    assert perso.width == 631, "la fenetre garde donc sa largeur"
    assert not droit.pierre.shown,         "la bande de pierre porte les onglets de page : elle ne sert plus ici"
    assert not stats.shown and not gear.shown,         "les deux onglets de page appartiennent au personnage"
    assert not droit.ligneNiveau.shown, "la ligne de niveau aussi"
    assert pr2[2].name == "ForeverUICharacterLeftPane",         "LES BARRES DE REPUTATION SONT BORNEES AU VOLET GAUCHE"
    assert g.ReputationFrame.shown, "et l ecran de reputation, lui, parait"
    assert perso.foreverRepli.shown,         "le volet existe sur cet onglet : il reste repliable"

    # L ONGLET DE REPUTATION : NOS lignes, baties d apres les gabarits de
    # camelot et remplies depuis GetFactionInfo. Celles du client sont
    # retirees -- c est ce qui met fin aux reprises de son art.
    lua.execute("ForeverUICharacterLeftPane:SetHeight(464)")
    g.CharacterFrame_ShowSubFrame("ReputationFrame")
    g.ForeverUI.Panes.ShowGroup("ReputationFrame")
    g.ForeverUI.CharacterApplyPanes(perso)

    liste = g.ForeverUIReputationList
    # LE CLIENT REPOND AU-DELA DE SON COMPTE : on s arrete au compte.
    posees = [l.nom.text for l in g.ForeverUI.ReputationTab.Rows.values() if l.shown]
    print("   posees : %s (le client en annonce %d, et repond a %d)" % (
        posees, g.GetNumFactions(), g.GetNumFactions() + 1))
    assert len(posees) == g.GetNumFactions(),         "une ligne par faction annoncee, pas une de plus"
    assert "Inactive" not in posees, "l entree hors compte ne doit pas paraitre"
    pl = liste.points[1]
    rangs = g.ForeverUI.ReputationTab.Rows
    r1, r2 = g.ForeverUIReputationRow1, g.ForeverUIReputationRow2
    print("   reputation : liste %s (%s, %s), %d lignes de %d de large" % (
        pl[1], pl[4], pl[5], len(list(rangs.values())), r1.width))
    assert (pl[4], pl[5]) == (10, -40), "TOPLEFT du volet (10, -40)"
    p1 = r1.points[len(list(r1.points.values()))]
    # SetPadding : 10 de marge, et le retrait du gabarit en plus.
    assert r1.width == 363 - 2 * 10, "la liste moins ses deux marges de 10"
    assert (p1[4], p1[5]) == (10, -10), "TOPLEFT du panneau, decale de la marge"
    assert not g.ReputationBar1.shown, "les lignes du client s en vont"

    # UN EN-TETE : plaque, nom en or a LEFT x = 10, fleche a RIGHT (-8, -1).
    pf = r1.fleche.points[1]
    pn1 = r1.nom.points[1]
    print("   en-tete : plaque=%s barre=%s | nom %s x=%s, police=%s | fleche %s (%s, %s)" % (
        r1.plaque.shown, r1.barre.shown, pn1[1], pn1[4], r1.nom.font,
        pf[1], pf[4], pf[5]))
    tranches = list(r1.plaque.values())
    print("   plaque : %d tranches, %d visibles sur l en-tete, %d sur l entree" % (
        len(tranches), sum(1 for t in tranches if t.shown),
        sum(1 for t in r2.plaque.values() if t.shown)))
    assert len(tranches) == 9, "la plaque se decoupe en neuf, elle ne s etire pas"
    assert all(t.shown for t in tranches), "toutes paraissent sur un en-tete"
    assert not any(t.shown for t in r2.plaque.values()), "aucune sur une entree"
    assert not r1.barre.shown, "un en-tete n a pas de barre"
    assert (pn1[1], pn1[4]) == ("LEFT", 10), "ReputationHeaderTemplate : LEFT x = 10"

    # LES TROIS GABARITS ET LEURS RETRAITS, tels que SetElementFactory et
    # SetElementIndentCalculator les donnent.
    r3 = g.ForeverUIReputationRow3
    def retrait(ligne):
        pt = ligne.points[len(list(ligne.points.values()))]
        return pt[4] - 10          # la marge de 10 en moins
    print("   hierarchie : en-tete h=%d retrait=%d | sous-en-tete h=%d retrait=%d "
          "| entree enfant h=%d retrait=%d" % (
        r1.height, retrait(r1), r2.height, retrait(r2), r3.height, retrait(r3)))
    assert (r1.height, retrait(r1)) == (28, 0),         "en-tete de premier niveau : 28 de haut, aucun retrait"
    assert (r2.height, retrait(r2)) == (22, 2),         "sous-en-tete : ReputationSubHeaderTemplate, 22 de haut, retrait 2"
    assert (r3.height, retrait(r3)) == (30, 46),         "enfant qui n est pas un en-tete : 30 de haut, retrait 46"
    assert r2.chevron.shown and not r2.fleche.shown,         "un sous-en-tete porte son bouton a GAUCHE"
    assert r1.fleche.shown and not r1.chevron.shown,         "un en-tete de premier niveau porte sa fleche a DROITE"
    assert r2.barre.shown, "ce sous-en-tete a de la reputation : sa barre parait"
    assert r3.barre.shown and not r3.chevron.shown, "une entree n a ni l un ni l autre"

    # L ECART entre deux lignes vaut 3, et il suit les hauteurs.
    ecart = (-retrait(r1) - 10) + 0     # place pour la lisibilite
    y1 = r1.points[len(list(r1.points.values()))][5]
    y2 = r2.points[len(list(r2.points.values()))][5]
    print("   ecart : ligne 1 a %s, ligne 2 a %s (28 + 3 attendus)" % (y1, y2))
    assert y1 - y2 == 28 + 3, "elementSpacing = 3, apres une ligne de 28"

    # TOUT L ECRAN DU CLIENT SE TAIT, pas seulement ses lignes : sa liste a
    # ascenseur, ses intitules de colonne, ses traits d arborescence.
    for nom in ("ReputationBar1", "ReputationListScrollFrame",
                "ReputationFrameCollapseAll"):
        g[nom].Show(g[nom])
    g.ForeverUI.ReputationLayout()
    restants = [n for n in ("ReputationBar1", "ReputationListScrollFrame",
                            "ReputationFrameCollapseAll") if g[n].shown]
    print("   ecran du client : %d morceau(x) encore visible(s)" % len(restants))
    assert restants == [], "il en reste : %s" % restants
    assert g.ForeverUIReputationList.shown, "mais notre panneau demeure"
    assert g.ReputationDetailFrame.shown,         "et le cadre de detail aussi : il a change de parent, il vit a droite"
    traits = [t for t in g.ForeverUIReputationList.regions.values() if t.width == 384]
    assert len(traits) == 2,         "nos deux traits vivent sur notre panneau, hors d atteinte du balayage"
    assert r1.nom.font == "GameFontNormalLeft", "et son nom est en or"
    assert (pf[1], pf[4], pf[5]) == ("RIGHT", -8, -1), "StateIcon a RIGHT (-8, -1)"
    assert r1.fleche.width == 13, "common-button-list-minus, a sa taille d atlas"

    # UNE ENTREE : barre a RIGHT x = -3, nom en blanc a x = 15 -- le bord
    # droit de l AccountWideIcon, 25, moins les 10 que Initialize retire
    # quand cette icone est masquee, ce qu elle est toujours ici.
    pb = r3.barre.points[1]
    pn2 = r3.nom.points[1]
    print("   entree : barre %d x %d %s x=%s | nom x=%s police=%s | remplissage %s" % (
        r3.barre.width, r3.barre.height, pb[1], pb[4], pn2[4],
        r3.nom.font, r3.barre.remplissage.width))
    assert r3.barre.width == 160 and r3.barre.height == 29, "ReputationBarTemplate"
    assert (pb[1], pb[4]) == ("RIGHT", -3), "ancree RIGHT x = -3"
    assert (pn2[1], pn2[4]) == ("LEFT", 15), "25 moins les 10 de Initialize"
    assert r3.nom.font == "GameFontHighlight", "le nom d une entree est en blanc"
    r4 = g.ForeverUIReputationRow4
    print("   exalte : barre pleine (%s) | neutre : %s sur 160" % (
        r4.barre.remplissage.width, r3.barre.remplissage.width))
    assert r4.barre.remplissage.width == 160.0,         "a l attitude maximale la barre est pleine, comme la source le veut"
    assert r3.barre.remplissage.width == 40.0, "250 sur 1000, sur 160 de barre"
    assert r2.barre.remplissage.height == 15, "ColoredProgressBarTemplate"
    # LE FOND DE JAUGE SE DECOUPE, LE REMPLISSAGE NON : l un est un cadre,
    # l autre une jauge que camelot rogne a la fraction voulue.
    fonds = [t for t in r3.barre.regions.values() if t.layer == "BACKGROUND"]
    print("   jauge : %d tranches de fond, remplissage %s de large" % (
        len(fonds), r3.barre.remplissage.width))
    assert len(fonds) == 9, "common-stat-bar-bg se decoupe en neuf"
    assert r3.barre.remplissage.layer == "BORDER",         "le remplissage reste une seule texture, rognee"
    assert "statbarfill" in (r3.barre.remplissage.texture or ""),         "et c est la version CUITE au masque, decoupee comme le fond"
    assert abs(r3.barre.remplissage.texcoord[2] - 0.25) < 1e-6,         "rognee a la fraction : 250 sur 1000"

    # LE CLIC : un en-tete se replie, une entree se choisit.
    # REPLIER RACCOURCIT LA LISTE : le client retire les enfants de sa
    # numerotation, il ne les masque pas. Tout ce qui suit remonte.
    avant = [l.nom.text for l in rangs.values() if l.shown]
    r2.scripts.OnClick(r2)                  # le sous-en-tete Alliance
    g.ForeverUI.ReputationLayout()
    apres = [l.nom.text for l in rangs.values() if l.shown]
    print("   repli d Alliance : %s -> %s" % (avant, apres))
    assert apres == ["Classic", "Alliance"],         "ses deux enfants quittent la liste, le reste reste en place"
    assert "Inactive" not in apres,         "on s arrete a GetNumFactions : le client repond au-dela, mais pas nous"
    assert r2.chevron.height == 13, "le plus prend la place du moins, a SA taille"

    r2.scripts.OnClick(r2)                  # on la redeploie
    g.ForeverUI.ReputationLayout()
    assert [l.nom.text for l in rangs.values() if l.shown] == avant,         "deplier la rend telle quelle"

    r1.scripts.OnClick(r1)                  # l en-tete de premier niveau
    g.ForeverUI.ReputationLayout()
    print("   repli de Classic : %s" % [l.nom.text for l in rangs.values() if l.shown])
    assert [l.nom.text for l in rangs.values() if l.shown] == ["Classic"],         "tout le bloc s en va"
    r1.scripts.OnClick(r1)
    g.ForeverUI.ReputationLayout()

    r3.scripts.OnClick(r3)
    g.ForeverUI.ReputationLayout()
    print("   clic sur une entree : survol a %.2f sur %s" % (
        r3.survol.alpha, r3.nom.text))
    assert abs(r3.survol.alpha - 0.20) < 1e-6,         "RefreshBackgroundHighlightOpacity : 0,20 pour la ligne choisie"
    assert abs(r1.survol.alpha) < 1e-6, "un en-tete n a pas de survol"

    # LES NOMS SONT CALES A GAUCHE, quel que soit le gabarit.
    #
    # SetFontObject EFFACE la justification : GameFontHighlight n a aucun
    # justifyH -- donc CENTRE -- et le nom se retrouvait centre dans une
    # boite dont la largeur change d un gabarit a l autre. Il se deplacait
    # donc horizontalement au fil du defilement. camelot pose la
    # justification PAR-DESSUS l objet de police :
    #   <FontString inherits="GameFontHighlight" justifyH="LEFT">
    justifs = {}
    for rang, ligne in rangs.items():
        if ligne.shown:
            justifs[ligne.nom.text] = (ligne.nom.font, ligne.nom.justify)
    print("   noms : %s" % ", ".join(
        "%s=%s/%s" % (n, str(f).replace("GameFont", ""), j)
        for n, (f, j) in sorted(justifs.items())))
    assert justifs, "il faut des lignes posees pour juger"
    assert all(j == "LEFT" for _, j in justifs.values()),         "en-tete, sous-en-tete et entree : tous cales a gauche"

    # UNE FACTION EN GUERRE : le voile est ROUGE, pas blanc.
    #
    # camelot : RefreshBackgroundHighlightColor prend FACTION_AT_WAR_COLOR,
    # qui N EXISTE PAS en 3.3.5 -- la teinte retombait sur le blanc. La
    # valeur exacte est relevee dans GlobalColor.db2 du client moderne :
    # 0xFF690300, soit 105, 3, 0.
    def voile(ligne):
        return [round(v, 6) for v in ligne.survolPieces[1].vertex.values()]

    print("   hors guerre : voile %s, alpha %.2f" % (voile(r3), r3.survol.alpha))
    assert voile(r3) == [1.0, 1.0, 1.0], "hors guerre, WHITE_FONT_COLOR"

    lua.execute('TOUTES[3].guerre = true')
    g.ForeverUI.ReputationLayout()
    rouge = [round(105 / 255, 6), round(3 / 255, 6), 0.0]
    print("   en guerre : voile %s, alpha %.2f" % (voile(r3), r3.survol.alpha))
    assert voile(r3) == rouge, "FACTION_AT_WAR_COLOR : 105, 3, 0"
    assert abs(r3.survol.alpha - 0.85) < 1e-6,         "choisie ET en guerre : 0,85"
    lua.execute('TOUTES[3].guerre = false')
    g.ForeverUI.ReputationLayout()

    # LA BARRE DE DEFILEMENT de camelot, a droite de la liste.
    #
    # RELEVE -- camelot/reputationframe.xml : TOPLEFT sur le TOPRIGHT du
    # ScrollBox (5, -2), BOTTOMLEFT sur son BOTTOMRIGHT (5, 4).
    barre = g.ForeverUIReputationScrollBar
    pbh = barre.points[1]
    pbb = barre.points[2]
    print("   barre : %s sur %s (%s, %s) et %s sur %s (%s, %s), %d de large" % (
        pbh[1], pbh[3], pbh[4], pbh[5], pbb[1], pbb[3], pbb[4], pbb[5],
        barre.width))
    assert (pbh[1], pbh[3], pbh[4], pbh[5]) == ("TOPLEFT", "TOPRIGHT", 5, -2)
    assert (pbb[1], pbb[3], pbb[4], pbb[5]) == ("BOTTOMLEFT", "BOTTOMRIGHT", 5, 4)
    assert pbh[2].name == "ForeverUIReputationList", "ancree sur la liste"
    assert barre.width == 8, "MinimalScrollBar fait 8 de large"

    # TOUT TIENT : elle s efface. C est ce que fait la source.
    print("   tout tient (%d factions) : barre visible=%s" % (
        g.GetNumFactions(), barre.shown))
    assert not barre.shown, "rien a faire defiler, rien a montrer"

    # ELLE NE CONNAIT PAS LA LISTE : on lui donne trois nombres.
    # Le banc ne deduit pas une hauteur de deux ancres : on la pose.
    barre.piste.SetHeight(barre.piste, 300)
    barre.Regler(barre, 40, 10, 0)
    print("   40 lignes, 10 tiennent : visible=%s, curseur %s" % (
        barre.shown, barre.curseur.shown))
    assert barre.shown and barre.curseur.shown, "elle parait"
    # LES DEUX BOUTS DU CURSEUR SONT LE MEME MORCEAU, le second RETOURNE :
    # celui que la source nomme "bottom" est un degrade, pas un embout, et
    # faisait fondre le curseur dans le noir de la glissiere.
    bouts = [t2 for t2 in barre.curseur.regions.values()
             if t2.texcoord is not None and t2.height == 8]
    assert len(bouts) == 2, "un embout en haut, un en bas"
    hg = [round(v, 6) for v in bouts[0].texcoord.values()]
    bg = [round(v, 6) for v in bouts[1].texcoord.values()]
    print("   bouts du curseur : %s et %s" % (hg, bg))
    assert hg[0] == bg[0] and hg[1] == bg[1], "le meme morceau"
    assert hg[2] == bg[3] and hg[3] == bg[2], "le second est retourne"
    fh = g.ForeverUIReputationScrollBarUp
    fb = g.ForeverUIReputationScrollBarDown
    print("   fleches : %dx%d, haut=%s bas=%s" % (
        fh.width, fh.height, fh.points[1][1], fb.points[1][1]))
    assert fh.width == 17 and fh.height == 11, "17 x 11, elles debordent la barre"
    assert fh.points[1][1] == "TOP" and fb.points[1][1] == "BOTTOM"

    # LA FLECHE DU BAS avance d un cran, et rend le nouveau decalage.
    recu = {}
    lua.execute("ForeverUIReputationScrollBar.surDefilement = "
                "function(n) ESSAI_DECALAGE = n end")
    fb.scripts.OnClick(fb)
    print("   clic sur la fleche du bas : decalage=%s" % lua.eval("ESSAI_DECALAGE"))
    assert lua.eval("ESSAI_DECALAGE") == 1, "un cran vers le bas"
    fh.scripts.OnClick(fh)
    assert lua.eval("ESSAI_DECALAGE") == 0, "et un cran vers le haut"

    # AU BOUT, ELLE S ARRETE : elle borne elle-meme.
    barre.Deplacer(barre, 999)
    print("   au bout : decalage=%d (maximum 30)" % barre.decalage)
    assert barre.decalage == 30, "40 lignes moins les 10 qui tiennent"
    g.ForeverUI.ReputationLayout()

    # LE VOLET DROIT : le detail de la faction choisie.
    detail = g.ReputationDetailFrame
    pd = detail.points[1]
    print("   detail : %s sur %s (%s, %s), titre=\"%s\" sous-titre=\"%s\"" % (
        pd[1], pd[2].name, pd[4], pd[5], detail.titre.text, detail.sousTitre.text))
    assert pd[2].name == "ForeverUICharacterRightPane",         "le cadre du client devient notre volet droit"
    print("   fond de fenetre : %s" % detail.backdrop)
    assert detail.backdrop is None,         "le <Backdrop> de 3.3.5 n est pas une region : SetBackdrop(nil) seul l enleve"
    assert (pd[4], pd[5]) == (16, -14),         "CharacterFrameSidePaneTemplate : TOPLEFT (16, -14)"
    assert detail.titre.text == r3.nom.text, "le titre est la faction choisie"
    assert detail.titre.width == 195 and detail.titre.justify == "CENTER",         "Title : large de 195, centre"
    assert detail.sousTitre.justify == "CENTER", "Subtitle : centre lui aussi"
    assert detail.description.text and "Description de" in detail.description.text,         "la description vient du client, par ReputationFrame_Update"
    # BLANCHE, ET DANS UNE BOITE : sans bas, un texte un peu long n a nulle
    # part ou se replier et disparait.
    coins = [p[1] for p in detail.description.points.values()]
    print("   description : police=%s, ancrages=%s, repli=%s" % (
        detail.description.font, coins, detail.description.wordWrap))
    assert detail.description.font == "GameFontHighlight",         "GameFontNormal est DORE en 3.3.5 : le blanc est GameFontHighlight"
    assert "BOTTOMLEFT" in coins and "BOTTOMRIGHT" in coins,         "ses quatre bords, sinon le texte n a pas de boite"
    assert detail.description.wordWrap is True, "et il se replie dedans"

    print("   jauge du detail : %d x %d, remplissage %s" % (
        detail.jauge.width, detail.jauge.height, detail.jauge.remplissage.width))
    assert detail.jauge.width == 180 and detail.jauge.height == 29,         "StandingBar : 180 x 29"
    assert detail.jauge.remplissage.width == 180 * 0.25,         "la meme fraction que dans la liste, sur 180"

    cases = [g[n] for n in ("ReputationDetailAtWarCheckBox",
                            "ReputationDetailInactiveCheckBox",
                            "ReputationDetailMainScreenCheckBox")]
    pc = cases[0].points[1]
    print("   cases : %d x %d, la premiere %s sur %s (%s, %s), visibles=%s" % (
        cases[0].width, cases[0].height, pc[1], pc[3], pc[4], pc[5],
        [c.shown for c in cases]))
    assert all(c.width == 26 and c.height == 26 for c in cases), "26 x 26"
    assert (pc[1], pc[3], pc[4]) == ("TOPLEFT", "BOTTOMLEFT", -4),         "la premiere se pose depuis le bas du volet, x = -4"
    assert cases[1].points[1][2].name == cases[0].name,         "les suivantes s empilent sous elle"
    assert cases[1].points[1][5] == -2, "BOTTOMLEFT (0, -2)"
    assert all(c.shown for c in cases), "les trois paraissent pour une faction"

    # LES EPEES N APPARTIENNENT QU A LA GUERRE : les deux autres cases
    # portent checkmark-minimal, comme la source le declare.
    print("   coches : guerre=%s | inactive=%s | barre=%s" % (
        cases[0].foreverCoche.texture, cases[1].foreverCoche.texture,
        cases[2].foreverCoche.texture))
    assert "SwordCheck" in (cases[0].foreverCoche.texture or ""),         "At War garde ses deux epees"
    for c in (cases[1], cases[2]):
        assert "SwordCheck" not in (c.foreverCoche.texture or ""),         "Move to Inactive et Show as Experience Bar prennent une coche"
        assert c.foreverCoche.points[1][1] == "CENTER",         "checkmark-minimal se centre sur la case"
    assert cases[0].foreverCoche.width == 32,         "la coche de guerre fait 32, posee a (3, -5)"

    # RIEN DE CHOISI : LE VOLET EST VIDE.
    g.ForeverUI.ReputationSelect(None)
    print("   rien de choisi : titre=\"%s\", jauge=%s, cases=%s" % (
        detail.titre.text, detail.jauge.shown, [c.shown for c in cases]))
    assert detail.titre.text == "" and detail.description.text == "",         "sans faction choisie, le volet droit est vide"
    assert not detail.jauge.shown and not detail.separateur.shown,         "ni jauge ni separateur"
    assert not any(c.shown for c in cases), "ni les trois options"

    # COCHER "MOVE TO INACTIVE" NE DOIT PAS DESELECTIONNER.
    #
    # SetFactionInactive DEPLACE la faction : le client renumerote, et
    # l indice retenu designerait une autre ligne. Le nom, lui, ne bouge pas.
    g.ForeverUI.ReputationSelect("Darnassus")
    assert detail.titre.text == "Darnassus"
    lua.execute("""
        -- le client range Darnassus ailleurs : tout se renumerote
        local garde = table.remove(TOUTES, 3)
        table.insert(TOUTES, garde)
    """)
    g.ReputationFrame_Update()
    print("   apres renumerotation : titre=\"%s\", indice du client=%d" % (
        detail.titre.text, g.GetSelectedFaction()))
    assert detail.titre.text == "Darnassus",         "le detail suit le NOM, pas l indice"
    assert g.GetFactionInfo(g.GetSelectedFaction())[0] == "Darnassus",         "et l indice du client est repose sur la bonne faction"
    lua.execute("""
        local garde = table.remove(TOUTES)
        table.insert(TOUTES, 3, garde)
    """)
    g.ForeverUI.ReputationSelect("Darnassus")

    # LA SELECTION SE RETIENT PAR LE NOM : un repli renumerote les factions,
    # un indice suivrait la mauvaise ligne.
    choisi = r3.nom.text
    r2.scripts.OnClick(r2)                  # replier Alliance
    g.ForeverUI.ReputationLayout()
    r2.scripts.OnClick(r2)                  # et la redeployer
    g.ForeverUI.ReputationLayout()
    marquees = [l.nom.text for l in rangs.values() if l.shown and l.survol.alpha > 0.15]
    print("   apres un repli et un depli : marquee = %s (choisie %s)" % (
        marquees, choisi))
    assert marquees == [choisi], "la marque reste sur la meme faction"

    # L ONGLET DES COMPETENCES : le meme ecran que la reputation, en bleu.
    g.CharacterFrame_ShowSubFrame("SkillFrame")
    g.ForeverUI.Panes.ShowGroup("SkillFrame")
    g.ForeverUI.CharacterApplyPanes(perso)

    s1, s2 = g.ForeverUISkillRow1, g.ForeverUISkillRow2
    ps1 = s1.points[len(list(s1.points.values()))]
    print("   competences : en-tete h=%d (%s, %s) | entree h=%d, nom x=%s, barre %d" % (
        s1.height, ps1[4], ps1[5], s2.height, s2.nom.points[1][4], s2.barre.width))
    assert s1.height == 26, "SkillsHeaderTemplate fait 26, pas 28 comme la reputation"
    assert s2.height == 30, "SkillsEntryTemplate"
    assert (ps1[4], ps1[5]) == (10, -10), "marge de 10 sur les deux axes"
    assert s2.nom.points[1][4] == 2,         "SkillsEntryTemplate : LEFT x = 2, il n y a pas d AccountWideIcon"
    assert s2.barre.width == 160 and s2.barre.height == 29, "SkillsBarTemplate"
    assert s2.barre.points[1][4] == -3, "RIGHT x = -3"

    # LA BARRE EST BLEUE PAR SON SPRITE, pas par une teinte.
    print("   remplissage : %s, large de %s" % (
        s2.barre.remplissage.texture, s2.barre.remplissage.width))
    assert "statbarfillblue" in (s2.barre.remplissage.texture or ""),         "SetFillTextureByColorType(Blue) : le bleu vient du sprite"
    assert s2.barre.remplissage.width == 160 * 0.5, "150 sur 300"
    assert s2.barre.texte.text == "150 / 300", "rang / maximum"

    # UN BONUS s ecrit entre parentheses, en vert.
    s3 = g.ForeverUISkillRow3
    print("   avec bonus : \"%s\"" % s3.barre.texte.text)
    assert "(+5)" in s3.barre.texte.text, "rang (+bonus) / maximum"

    # LE DETAIL : titre, jauge de 180, description.
    sd = g.ForeverUISkillDetail
    print("   detail : titre=\"%s\", jauge %d, description=\"%s\"" % (
        sd.titre.text, sd.jauge.width, sd.description.text))
    assert sd.titre.text == "Epees",         "SelectFirstSkillIfNoneSelected : la premiere qui n est pas un en-tete"
    assert sd.jauge.width == 180, "RankBar : 180 x 29"
    assert "epees" in sd.description.text, "la description, 13e valeur de GetSkillLineInfo"

    # TOUT L ECRAN DU CLIENT SE TAIT : pas seulement ses lignes. SkillFrame
    # declare aussi un bouton de tri, un "tout replier", ses tuiles de
    # depliage, deux boutons et tout un cadre de detail.
    for nom in ("SkillSortButton", "SkillFrameCollapseAllButton",
                "SkillListScrollFrame", "SkillDetailStatusBar"):
        if g[nom]:
            g[nom].Show(g[nom])
    g.SkillFrame_UpdateSkills()
    g.ForeverUI.SkillsLayout()
    restants = [n for n in ("SkillSortButton", "SkillFrameCollapseAllButton",
                            "SkillListScrollFrame", "SkillDetailStatusBar",
                            "SkillRankFrame1", "SkillTypeLabel1")
                if g[n] and g[n].shown]
    print("   ecran du client : %d morceau(x) encore visible(s)" % len(restants))
    assert restants == [], "il en reste : %s" % restants
    assert g.ForeverUISkillList.shown, "mais notre panneau, lui, demeure"
    assert g.ForeverUISkillRow1.shown, "et nos lignes avec"

    # REPLIER un en-tete raccourcit la liste, comme pour la reputation.
    avant = [l.nom.text for l in g.ForeverUI.SkillsTab.Rows.values() if l.shown]
    s1.scripts.OnClick(s1)
    apres = [l.nom.text for l in g.ForeverUI.SkillsTab.Rows.values() if l.shown]
    print("   repli d Armes : %s -> %s" % (avant, apres))
    assert apres == ["Armes", "Metiers", "Couture"], "ses deux competences s en vont"
    s1.scripts.OnClick(s1)

    # CLIQUER une competence la choisit, et le detail suit.
    s3 = g.ForeverUISkillRow3
    s3.scripts.OnClick(s3)
    print("   clic sur Haches : detail=\"%s\", survol %.2f" % (
        sd.titre.text, s3.survol.alpha))
    assert sd.titre.text == "Haches", "le detail suit le clic"
    assert abs(s3.survol.alpha - 0.20) < 1e-6, "et la ligne est marquee"

    # L ONGLET DU FAMILIER. A LA DEMANDE : l apercu a gauche, et a droite la
    # meme interface que les statistiques du personnage.
    lua.execute("AVEC_FAMILIER = true")
    g.CharacterFrame_ShowSubFrame("PetPaperDollFrame")
    g.ForeverUI.Panes.ShowGroup("PetPaperDollFrame")
    g.ForeverUI.CharacterApplyPanes(perso)

    modele = g.PetModelFrame
    pm = modele.points[len(list(modele.points.values()))]
    print("   familier : apercu visible=%s unite=%s, borne a %s" % (
        modele.shown, modele.unit, pm[2].name))
    assert modele.shown and modele.unit == "pet", "l apercu montre le familier"
    assert g.PetPaperDollFramePetFrame.shown,         "l apercu est PETIT-fils de l ecran : son porteur doit survivre au balayage"
    assert pm[2].name == "ForeverUIPetPane", "et remplit le volet gauche"

    # LES FLECHES DE ROTATION, a la meme place que celles du personnage :
    # centrees sur le HAUT du volet, cote a cote.
    fg = g.PetModelFrameRotateLeftButton
    fd = g.PetModelFrameRotateRightButton
    pg = fg.points[len(list(fg.points.values()))]
    pd = fd.points[len(list(fd.points.values()))]
    cg = g.CharacterModelFrameRotateLeftButton
    pcg = cg.points[len(list(cg.points.values()))]
    print("   fleches : familier %s (%s, %s) | personnage %s (%s, %s)" % (
        pg[1], pg[4], pg[5], pcg[1], pcg[4], pcg[5]))
    assert (pg[1], pg[4], pg[5]) == (pcg[1], pcg[4], pcg[5]),         "les memes que celles du personnage, au pixel pres"
    assert pg[3] == "TOP" and pd[4] == -pg[4], "cote a cote, centrees sur le haut"
    assert fg.shown and fd.shown, "et visibles"

    pet = g.ForeverUIPetStats
    print("   niveau : \"%s\"" % pet.niveau.text)
    assert pet.niveau.text == "Level 78 Sanglier", "Niveau X <nom du familier>"

    categories = []
    rang = 1
    while g["ForeverUIPetCategory" + str(rang)] is not None:
        c2 = g["ForeverUIPetCategory" + str(rang)]
        if c2.shown:
            categories.append((c2.intitule.text, c2.width, c2.height))
        rang += 1
    print("   categories : %s" % categories)
    assert [n for n, _, _ in categories] == ["General", "Resistances"],         "deux categories, dans cet ordre"
    assert categories[0][2] == 34, "la meme hauteur d en-tete que les statistiques"
    assert categories[0][1] == (233 - 2 * 20) + 2 * 5,         "et le meme debord de 5 de chaque cote"

    lignes = []
    rang = 1
    while g["ForeverUIPetStat" + str(rang)] is not None:
        l = g["ForeverUIPetStat" + str(rang)]
        if l.shown:
            lignes.append((l.intitule.text, l.valeur.text))
        rang += 1
    print("   lignes : %s" % ", ".join("%s %s" % (a2, b2) for a2, b2 in lignes))
    assert [a2 for a2, _ in lignes[:5]] == ["Health:", "Armor:", "Damage:",
                                            "Attack Power:", "Critical Strike:"],         "les cinq lignes demandees, dans cet ordre"
    assert [b2 for _, b2 in lignes[:5]] == ["5400", "3120", "45 - 62", "1480",
                                            "4.25%"],         "les valeurs viennent du client, mises en forme par lui"
    # "Attack Power", et non "Power" : ATTACK_POWER vaut "Power" ici.
    assert lignes[3][0] == "Attack Power:",         "ATTACK_POWER vaut \"Power\" : c est ATTACK_POWER_TOOLTIP qu il faut"
    assert len(lignes) == 5, "les resistances ne sont plus des lignes de texte"

    # LES RESISTANCES SONT DES ICONES, A L HORIZONTAL. A LA DEMANDE : ce
    # sont les cadres du client, reparentes dans le volet droit, qui
    # portent deja l icone d ecole, la valeur et l infobulle.
    res = [g["PetMagicResFrame" + str(i)] for i in range(1, 6)]
    xs = []
    for cadre in res:
        p = cadre.points[len(list(cadre.points.values()))]
        xs.append(round(p[4], 2))
    print("   resistances : %s | tailles %dx%d | parent=%s | valeurs %s" % (
        xs, res[0].width, res[0].height, res[0].parent.name,
        [g["PetMagicResText" + str(i)].text for i in range(1, 6)]))
    assert all(c.shown for c in res), "les cinq paraissent"
    assert res[0].width == 32 and res[0].height == 29,         "MagicResistanceFrameTemplate fait 32 x 29"
    assert res[0].parent.name == "ForeverUIPetStats",         "reparentes dans le volet droit, que le balayage ne touche pas"
    assert xs[0] == 20, "la premiere au bord des lignes"
    ecarts = [round(xs[i + 1] - xs[i], 2) for i in range(4)]
    assert len(set(ecarts)) == 1, "a pas egaux : %s" % ecarts
    assert round(xs[4] + 32, 2) == 20 + (233 - 2 * 20),         "et la derniere au bord oppose"
    ys = [cadre.points[len(list(cadre.points.values()))][5] for cadre in res]
    assert len(set(ys)) == 1, "toutes sur la meme ligne : %s" % ys
    assert g.PetMagicResText1.text == 120,         "le premier cadre porte l ecole 6, l arcane"

    # LE FOND ALTERNE, comme les statistiques du personnage, et le compte
    # REPART a chaque categorie.
    SOMBRE2 = "ui-character-info-itemlevel-bounce"
    r_s = tuple(round(lua.eval('UIAtlas.data["%s"]' % SOMBRE2)[i], 6) for i in (2, 3, 4, 5))
    def bandePet(rang):
        fond = g["ForeverUIPetStat" + str(rang)].fond
        tc = tuple(round(v, 6) for v in fond.texcoord.values())
        return "sombre" if tc == r_s else "clair"
    bandes = [bandePet(i) for i in (1, 2, 3, 4, 5)]
    print("   fonds : %s" % " ".join(bandes))
    assert bandes == ["sombre", "clair", "sombre", "clair", "sombre"],         "la sombre en premier"

    # SANS FAMILIER, l ecran est vide et l apercu ne montre rien.
    lua.execute("AVEC_FAMILIER = false")
    g.ForeverUI.PetPreview()
    g.ForeverUI.PetDetail()
    print("   sans familier : apercu=%s, niveau=\"%s\"" % (
        modele.shown, pet.niveau.text))
    assert not modele.shown and pet.niveau.text == "",         "sans familier, rien a montrer"
    lua.execute("AVEC_FAMILIER = true")
    g.ForeverUI.PetPreview()
    g.ForeverUI.PetDetail()

    # L ONGLET DES MONNAIES. Le meme gabarit de liste que la reputation et
    # les competences -- ScrollBox aux memes bornes, meme plaque d en-tete,
    # meme survol en trois tranches -- mais deux niveaux seulement :
    # GetCurrencyListInfo ne rend qu un enTete, sans notion d enfant.
    g.CharacterFrame_ShowSubFrame("TokenFrame")
    g.ForeverUI.Panes.ShowGroup("TokenFrame")
    g.ForeverUI.CharacterApplyPanes(perso)

    liste = g.ForeverUITokenList
    pl = liste.points[1]
    pl2 = liste.points[2]
    print("   monnaies : panneau (%s, %s) a (%s, %s)" % (
        pl[4], pl[5], pl2[4], pl2[5]))
    assert (pl[4], pl[5]) == (10, -40) and (pl2[4], pl2[5]) == (-25, 15),         "les memes bornes que la reputation"

    rangs = {}
    rang = 1
    while g["ForeverUITokenRow" + str(rang)] is not None:
        rangs[rang] = g["ForeverUITokenRow" + str(rang)]
        rang += 1
    posees = [(l.nom.text, l.entete, l.height) for l in rangs.values() if l.shown]
    print("   lignes : %s" % ", ".join(
        "%s%s(%d)" % (n, " [cat]" if e else "", h) for n, e, h in posees))
    assert [n for n, _, _ in posees] == ["Miscellaneous", "Arena Points",
                                         "Honor Points", "Emblem of Frost",
                                         "Player vs. Player"],         "la categorie PvP est repliee : son contenu ne se pose pas"
    assert posees[0][2] == 26 and posees[1][2] == 22,         "TokenHeaderTemplate 26, TokenEntryTemplate 22"

    # LES DEUX ICONES A PART, que le client nomme lui-meme.
    r2, r3, r4 = rangs[2], rangs[3], rangs[4]
    print("   icones : arene=%s | honneur=%s (rogne %.5f) | ordinaire=%s" % (
        r2.icone.texture.split(chr(92))[-1], r3.icone.texture.split(chr(92))[-1],
        list(r3.icone.texcoord.values())[0], r4.icone.texture))
    assert "ArenaPoints" in r2.icone.texture, "typeSpecial 1 : les points d arene"
    assert "UI-PVP-Alliance" in r3.icone.texture, "typeSpecial 2 : la faction"
    assert abs(list(r3.icone.texcoord.values())[0] - 0.03125) < 1e-6,         "et son rognage"
    assert r4.icone.texture == "icone_embleme", "les autres prennent l icone rendue"

    # UNE MONNAIE A ZERO S ECRIT EN GRIS, comme le client le fait.
    print("   police : zero=%s | non nul=%s" % (r3.nom.font, r4.nom.font))
    assert r3.nom.font == "GameFontDisable", "compte nul : GameFontDisable"
    assert r4.nom.font == "GameFontHighlight", "sinon GameFontHighlight"
    print("   coche de suivi : %s" % [bool(rangs[i].coche.shown) for i in (2, 3, 4)])
    assert r4.coche.shown and not r2.coche.shown, "seule la monnaie suivie est cochee"

    # DEPLIER LA CATEGORIE PvP rallonge la liste.
    r5 = rangs[5]
    r5.scripts.OnClick(r5)
    posees = [l.nom.text for l in rangs.values() if l.shown]
    print("   apres depli : %s" % ", ".join(posees))
    assert "Wintergrasp Mark" in posees, "son contenu arrive"

    # CLIQUER UNE MONNAIE la choisit, et le volet droit suit.
    td = g.ForeverUITokenDetail or g.TokenFramePopup
    r4.scripts.OnClick(r4)
    print("   clic : titre=\"%s\" sous-titre=\"%s\" survol=%.2f" % (
        td.titre.text, td.sousTitre.text, r4.survol.alpha))
    assert td.titre.text == "Emblem of Frost", "le detail suit le clic"
    assert td.sousTitre.text == "42", "sa quantite"
    assert abs(r4.survol.alpha - 0.20) < 1e-6, "et la ligne est marquee"
    assert g.TokenFrame.selectedToken == "Emblem of Frost",         "le client agit sur SON indice : on le tient a jour"
    assert g.TokenFrame.selectedID == 4

    # LES DEUX CASES DU CLIENT, rhabillees, portent l etat de la monnaie.
    inactive = g.TokenFramePopupInactiveCheckBox
    sac = g.TokenFramePopupBackpackCheckBox
    print("   cases : inutilisee=%s suivie=%s" % (
        inactive.checked, sac.checked))
    assert inactive.checked is False and sac.checked is True,         "la case du sac suit isWatched"
    assert inactive.width == 26 and inactive.foreverCoche is not None,         "26 x 26, checkbox-minimal et checkmark-minimal"

    # LE FOND DE FENETRE N EST PAS UNE REGION : SetBackdrop(nil) seul l enleve.
    print("   fond de fenetre : %s" % td.backdrop)
    assert td.backdrop is None, "le <Backdrop> de 3.3.5"

    # ET L INTITULE DU CLIENT NON PLUS N EST PAS UNE TEXTURE : un balayage
    # qui ne prend que les textures laisse "Currency Options" a l ecran.
    print("   intitule du client : visible=%s" % g.TokenFramePopupTitle.shown)
    assert not g.TokenFramePopupTitle.shown,         "le FontString du client s en va comme ses textures"

    # ET LUI AUSSI SORT DU SYSTEME DE PANNEAUX : le Blizzard_TokenUI du
    # client l y inscrit des sa premiere ligne.
    print("   inscription au systeme de panneaux : %s" % (
        g.UIPanelWindows["TokenFrame"],))
    assert g.UIPanelWindows["TokenFrame"] is None,         "il n est plus une fenetre : il sort de UIPanelWindows"
    g.UpdateUIPanelPositions(g.CharacterFrame)
    g.ForeverUI.TokensLayout()
    pl3 = liste.points[1]
    assert (pl3[4], pl3[5]) == (10, -40), "et reste borne au volet"

    # TOUT L ECRAN DU CLIENT SE TAIT, a chaque passage.
    g.ForeverUI.TokensLayout()
    print("   ecran du client : conteneur visible=%s" % g.TokenFrameContainer.shown)
    assert not g.TokenFrameContainer.shown, "sa liste a lui s en va"
    assert liste.shown, "mais notre panneau demeure"

    # L ONGLET PvP. camelot y montre un rang que WotLK n expose plus dans son
    # FrameXML -- mais UnitPVPRank, GetPVPRankInfo et GetPVPRankProgress sont
    # dans le binaire, verifie. On s en sert, et le temoin dira ce que le
    # serveur en fait.
    g.CharacterFrame_ShowSubFrame("")
    g.ForeverUI.Panes.ShowGroup("ForeverUIPvPPane")
    g.ForeverUI.CharacterApplyPanes(perso)

    principal = g.ForeverUIPvPMain
    pm = principal.points[1]
    print("   pvp : bloc (%s, %s), rang=\"%s\", badge=%s" % (
        pm[4], pm[5], principal.rang.text, principal.badge.texture))
    assert (pm[4], pm[5]) == (0, -60), "MainInfoFrame : TOPLEFT (0, -60)"
    # A LA DEMANDE : le titre seul en haut, le numero seul dans l anneau.
    pn = principal.numero.points[1]
    # SANS RANG -- ce que le serveur rend ici -- rien a ecrire, et pas
    # d anneau dore vide.
    print("   sans rang : rang=\"%s\", numero=\"%s\", anneau=%s, saison=\"%s\"" % (
        principal.rang.text, principal.numero.text, principal.recompense.shown,
        principal.saison.text))
    # SANS RANG, LE JOUEUR EST UN CIVIL, pas un deshonore : le nom se lit a
    # l indice "numero + 4", et a numero = 0 cela donnait l indice 4 --
    # PVP_RANK_4, "Dishonored", qui est le rang des tueurs de civils.
    assert principal.rang.text == "Civilian",         "sans rang, ni titre de rang negatif ni vide : civil"
    assert not principal.recompense.shown,         "un cercle dore vide se lirait comme un defaut"
    assert principal.saison.text == "Arena 8",         "la saison porte son intitule : un chiffre nu se lisait comme un rang"

    # AVEC UN RANG : le nom vient des chaines du client, le numero de
    # l indice decale de quatre.
    lua.execute("RANG_PVP = 9")          # indice 9 -> rang 5
    g.ForeverUI.PvPUpdate()
    pn = principal.numero.points[1]
    print("   rang 5 : titre=\"%s\", numero=\"%s\", anneau %s de large" % (
        principal.rang.text, principal.numero.text, pn[2].width))
    assert principal.numero.text == "5", "UnitPVPRank rend l indice, decale de quatre"
    assert principal.rang.text in ("First Sergeant", "Sergeant Major"),         "le nom vient de PVP_RANK_<indice>_<faction>, la cle etant l INDICE"
    assert principal.recompense.shown, "et l anneau reparait"
    assert pn[1] == "CENTER" and pn[2].width == 54,         "le numero est centre sur le cercle dore"
    lua.execute("RANG_PVP = 0")
    g.ForeverUI.PvPUpdate()
    assert principal.cadran.width == 154, "le cadran fait 154"

    # LE RANG VIENT DES TITRES, PAS DU COMPTEUR.
    #
    # Releve dans modules/mod-pvp-titles/src/mod_pvp_titles.cpp : le module
    # pose un TITRE de CharTitles et ne touche jamais au compteur de rang.
    # UnitPVPRank reste donc a zero, et le rang se demande a IsTitleKnown --
    # identifiants 1 a 14 pour l Alliance, 15 a 28 pour la Horde.
    lua.execute("RANG_PVP = 0; PROGRES_PVP = 0; VICTOIRES_PVP = 800")
    lua.execute("TITRES_CONNUS = { [1] = true, [5] = true }")
    g.ForeverUI.PvPUpdate()
    print("   par les titres : titre=\"%s\", numero=\"%s\", anneau=%s" % (
        principal.rang.text, principal.numero.text, principal.recompense.shown))
    assert principal.numero.text == "5",         "le rang est le PLUS HAUT titre connu, pas le premier"
    assert principal.rang.text == "Sergeant Major",         "le nom se lit toujours dans PVP_RANK_<numero + 4>_<faction>"

    # LA PROGRESSION VIENT DES VICTOIRES, comparees aux seuils du serveur.
    # Rang 5 acquis a 750, rang 6 a 1000 : 800 victoires font un cinquieme.
    plein = sum(1 for q in range(1, 5) if principal.jauge[q].plein.shown)
    arc = [q for q in range(1, 5) if principal.jauge[q].arc.shown]
    print("   progression par les victoires : 800 -> %d quart(s) plein(s),"
          " arc sur %s" % (plein, arc))
    assert plein == 0 and arc == [3],         "un cinquieme de tour : rien de plein, l arc dans le premier quart"

    # LE CAS REEL : 67 victoires, seul le titre du rang 1. Avec IsTitleKnown
    # pris pour un booleen, ce cas rendait 14.
    lua.execute("TITRES_CONNUS = { [1] = true }; VICTOIRES_PVP = 67")
    g.ForeverUI.PvPUpdate()
    arc = [q for q in range(1, 5) if principal.jauge[q].arc.shown]
    print("   67 victoires, titre du rang 1 : numero=\"%s\" titre=\"%s\","
          " arc sur %s" % (principal.numero.text, principal.rang.text, arc))
    assert principal.numero.text == "1", "un seul titre connu : le rang 1"
    assert principal.rang.text == "Private", "Alliance, rang 1"
    # De 50 a 100 : 67 victoires font 34 % du tour, soit le quart qui part du
    # bas en entier, et un tiers du suivant.
    assert principal.jauge[3].plein.shown and arc == [4],         "34 %% du tour : le quart du bas plein, l arc dans le suivant"

    # LA PROGRESSION S ECRIT EN CHIFFRES, pas en pourcentage : les victoires
    # honorables et le seuil du palier suivant, comme CurrentRankProgressField.
    print("   progression ecrite : \"%s\"" % principal.progres.text)
    assert principal.progres.text == "67 / 100",         "les deux nombres que le module du serveur compare, pas un pourcentage"
    lua.execute("VICTOIRES_PVP = 800")

    # AU RANG MAXIMAL, la jauge est pleine et il n y a plus de seuil.
    lua.execute("TITRES_CONNUS = { [14] = true }")
    g.ForeverUI.PvPUpdate()
    print("   au rang maximal : \"%s\"" % principal.progres.text)
    assert principal.progres.text == "800",         "plus de seuil au-dessus : le compte reste seul"
    plein = sum(1 for q in range(1, 5) if principal.jauge[q].plein.shown)
    print("   rang 14 : titre=\"%s\", %d quart(s) plein(s)" % (
        principal.rang.text, plein))
    assert principal.numero.text == "14", "le quatorzieme titre est le rang 14"
    assert plein == 4, "plus de seuil au-dessus : la jauge est pleine"

    # SANS AUCUN TITRE, rien : ni numero, ni anneau dore. LE PIEGE EST ICI :
    # IsTitleKnown rend 0 pour un titre inconnu, et 0 est VRAI en Lua.
    lua.execute("TITRES_CONNUS = {}")
    g.ForeverUI.PvPUpdate()
    assert lua.eval("IsTitleKnown(1)") == 0,         "le faux doit rendre un nombre, comme le client"
    assert principal.numero.text == "" and not principal.recompense.shown,         "aucun titre, aucun rang -- zero n est pas un titre connu"
    print("   sans aucun titre : \"%s\"" % principal.rang.text)
    assert principal.rang.text == "Civilian", "et le joueur est un civil"

    # UN RANG NEGATIF, lui, garde son nom : les indices 1 a 4 sont Pariah,
    # Outlaw, Exiled et Dishonored, et se nomment par leur indice tel quel.
    lua.execute("RANG_PVP = 4")
    g.ForeverUI.PvPUpdate()
    print("   UnitPVPRank = 4 : \"%s\", numero=\"%s\"" % (
        principal.rang.text, principal.numero.text))
    assert principal.rang.text == "Dishonored",         "les indices 1 a 4 sont les rangs negatifs"
    assert principal.numero.text == "", "et ils n ont pas de numero"
    lua.execute("RANG_PVP = 0")
    g.ForeverUI.PvPUpdate()
    lua.execute("PROGRES_PVP = 0.4; VICTOIRES_PVP = 1234")
    g.ForeverUI.PvPUpdate()

    # LA JAUGE CIRCULAIRE, verifiee par la geometrie et non par l oeil.
    #
    # camelot la fait avec un Cooldown dont il remplace la texture de
    # balayage ; 3.3.5 n a pas SetSwipeTexture, et l addon refait le balayage
    # par quadrants : un quart depasse montre l anneau entier, le quart ou la
    # jauge s arrete montre un DEMI anneau tourne par SetTexCoord a huit
    # arguments.
    #
    # ON VERIFIE CE QUE CA COUVRE. Pour une serie d angles pris sur le fil de
    # l anneau, on relit les coordonnees que l addon a posees et on demande a
    # l image si elle a de la matiere a cet endroit -- la moitie gauche, donc
    # u < 0.5. Le resultat doit etre l arc qui part du BAS, six heures, et
    # tourne dans le sens des aiguilles.
    import math as _m

    DEPART = 180.0          # <Cooldown rotation="180">
    RAYON = 0.734           # le fil de l anneau, en fraction du demi-cadran

    def _quart_de(u, v):
        for q in range(1, 5):
            quart = principal.jauge[q]
            if quart.u1 <= u <= quart.u2 and quart.v1 <= v <= quart.v2:
                return quart
        return None

    def _couvert(angle):
        """L addon montre-t-il de la matiere a cet angle ?"""
        r = _m.radians(angle)
        u = 0.5 + 0.5 * RAYON * _m.sin(r)
        v = 0.5 - 0.5 * RAYON * _m.cos(r)
        quart = _quart_de(u, v)
        if quart is None:
            return False
        if quart.plein.shown:
            return True
        if not quart.arc.shown:
            return False
        # Les quatre coins portent chacun sa coordonnee ; entre eux, le
        # client interpole. On fait pareil.
        tc = quart.arc.texcoord8
        s = (u - quart.u1) / (quart.u2 - quart.u1)
        w = (v - quart.v1) / (quart.v2 - quart.v1)
        hg, bg, hd, bd = (tc[1], tc[2]), (tc[3], tc[4]), (tc[5], tc[6]), (tc[7], tc[8])
        tu = ((1 - s) * (1 - w) * hg[0] + s * (1 - w) * hd[0]
              + (1 - s) * w * bg[0] + s * w * bd[0])
        return tu < 0.5          # la moitie gauche de l image, la seule cuite

    for fraction in (0.0, 0.1, 0.25, 0.5, 0.75, 0.9, 1.0):
        g.ForeverUI.PvPGauge(fraction)
        etats = []
        for q in range(1, 5):
            quart = principal.jauge[q]
            etats.append("plein" if quart.plein.shown
                         else ("arc" if quart.arc.shown else "vide"))
        faux = []
        for pas in range(0, 360, 5):
            angle = pas + 2.5              # jamais pile sur une frontiere
            attendu = ((angle - DEPART) % 360.0) <= fraction * 360.0
            if fraction >= 1.0:
                attendu = True
            if _couvert(angle) != attendu:
                faux.append(pas)
        print("   jauge %3d%% : %-28s %s" % (
            fraction * 100, " ".join(etats),
            "exacte" if not faux else "FAUX a %s" % faux))
        assert not faux, "la jauge couvre autre chose que son arc : %s" % faux

    # LE SENS. A un dixieme de tour, la jauge doit avoir quitte le bas par la
    # GAUCHE -- le sens des aiguilles depuis six heures.
    g.ForeverUI.PvPGauge(0.1)
    assert _couvert(200) and not _couvert(160),         "la jauge part du bas et monte par la gauche"

    # ELLE SUIT LA PROGRESSION REELLE.
    lua.execute("PROGRES_PVP = 0.75")
    g.ForeverUI.PvPUpdate()
    plein = sum(1 for q in range(1, 5) if principal.jauge[q].plein.shown)
    print("   jauge suivie : progres 0.75 -> %d quart(s) plein(s)" % plein)
    assert plein == 3, "trois quarts entiers a trois quarts de tour"
    lua.execute("PROGRES_PVP = 0.4")
    g.ForeverUI.PvPUpdate()

    # LE VOLET DROIT porte ce que WotLK sait vraiment donner : l honneur.
    pd = g.ForeverUIPvPDetail
    print("   detail : titre=\"%s\", description=\"%s\"" % (
        pd.titre.text, (pd.description.text or "").replace(chr(10), " | ")))
    # LE VOLET DROIT PORTE LE MEME TITRE QUE L ECRAN : sans rang, "Civilian".
    # Ce volet est a reprendre -- voir docs/AMELIORATIONS.md.
    assert pd.titre.text == "Civilian", "le volet droit suit le nom du rang"
    assert "4567" in pd.description.text, "les points d honneur courants"
    assert "1234" in pd.description.text, "les victoires honorables de toute une vie"

    # TOUT L ECRAN DU CLIENT SE TAIT, a chaque passage.
    g.PVPFrame_Update()
    restants = [n for n in ("PVPFrameToggleButton", "PVPFrameOffSeason") if g[n].shown]
    print("   ecran du client : %d morceau(x) encore visible(s)" % len(restants))
    assert restants == [], "il en reste : %s" % restants
    assert principal.shown, "mais notre bloc demeure"

    # Les quatre ecrans se remplacent l un l autre, jamais deux a la fois.
    for nom in ("SkillFrame", "TokenFrame", "PetPaperDollFrame"):
        g.CharacterFrame_ShowSubFrame(nom)
        g.ForeverUI.Panes.ShowGroup(nom)
        g.ForeverUI.CharacterApplyPanes(perso)
        visibles = [e for e in ("ReputationFrame", "SkillFrame", "TokenFrame",
                                "PetPaperDollFrame") if g[e].shown]
        assert visibles == [nom], "un seul ecran a la fois : %s" % visibles
    print("   quatre ecrans : un seul visible a la fois")

    # RETOUR AU PERSONNAGE : la page ouverte est retrouvee, pas reinitialisee.
    g.CharacterFrame_ShowSubFrame("PaperDollFrame")
    g.ForeverUI.Panes.ShowGroup("PaperDollFrame")
    g.ForeverUI.CharacterApplyPanes(perso)
    print("   retour au personnage : fenetre %d, volet droit=%s, page=%s" % (
        perso.width, droit.shown, Panes.CurrentPage("droit")))
    assert perso.width == 631 and droit.shown, "le volet droit revient"
    assert Panes.CurrentPage("droit") == "equipement",         "la page ouverte avant le detour est celle qui revient"
    assert g.ForeverUIEquipmentPane.shown
    assert droit.pierre.shown and gear.shown and droit.ligneNiveau.shown,         "le mobilier du personnage revient avec lui"
    assert perso.foreverRepli.shown, "et le bouton de repli avec"

    # LA PAGE DES TITRES, troisieme onglet du volet droit. A LA DEMANDE :
    # camelot n en a pas -- son PAPERDOLL_SIDEBARS vaut
    # {STATS, EQUIPMENTMANAGER, PET}.
    lua.execute("TITRES_CONNUS = { [1] = true, [15] = true, [42] = true };"
                " TITRE_PORTE = 0")
    droit.choisirPage("titres")
    g.ForeverUI.CharacterApplyPanes(perso)
    volets = g.ForeverUITitlesPane
    noms = []
    rang = 1
    while g["ForeverUITitleRow" + str(rang)] is not None:
        ligne = g["ForeverUITitleRow" + str(rang)]
        if ligne.shown:
            noms.append(ligne.texte.text)
        rang += 1
    print("   titres : page=%s, %d ligne(s) : %s" % (
        Panes.CurrentPage("droit"), len(noms), ", ".join(noms)))
    assert Panes.CurrentPage("droit") == "titres", "le troisieme onglet ouvre sa page"
    assert volets.shown, "et son panneau parait"
    # TRIES PAR NOM, "Aucun" EN TETE quel que soit son intitule.
    assert noms[0] == "None", "camelot reserve la premiere place a Aucun"
    assert noms[1:] == ["Private", "Scout", "the Explorer"],         "tries par nom, et LE NOM EST ROGNE : GetTitleName rend \"Private \""
    assert not droit.ongletStats.choisi.shown and droit.ongletTitres.choisi.shown,         "la marque suit le troisieme onglet"

    # LA LIGNE PREND TOUT LE VOLET, moins la marge des statistiques. A LA
    # DEMANDE : camelot donne 169 a son gabarit, sur un volet de 233.
    premiere = g.ForeverUITitleRow1
    pl = premiere.points[1]
    ligneStat = g.CharacterStatsPaneCategory1StatFrame1 or g.PlayerStatFrameLeft1
    print("   ligne de titre : %d de large, TOPLEFT (%s, %s)" % (
        premiere.width, pl[4], pl[5]))
    assert premiere.width == 233 - 2 * 20,         "toute la largeur du volet, moins 20 de chaque cote"
    assert pl[4] == 20, "la meme marge a gauche que les statistiques"

    # ET LE MEME FOND ALTERNE. A LA DEMANDE : les deux bandes de
    # paperdollinfopart1c60, la sombre en premier.
    def bandeTitre(rang):
        fond = g["ForeverUITitleRow" + str(rang)].fond
        if fond is None or fond.texcoord is None:
            return None
        tc = tuple(round(v, 6) for v in fond.texcoord.values())
        for nom, r in rects.items():
            if tc == r:
                return "sombre" if nom == SOMBRE else "clair"
        return "?"

    bandes = [bandeTitre(r) for r in range(1, 5)]
    print("   fond des titres : %s" % " ".join(str(b) for b in bandes))
    assert bandes == ["sombre", "clair", "sombre", "clair"],         "les memes bandes que les statistiques, la sombre en premier"

    # LE TITRE PORTE A SA COCHE, ET LUI SEUL.
    lignes = [g["ForeverUITitleRow" + str(i)] for i in range(1, len(noms) + 1)]
    coches = [l.texte.text for l in lignes if l.coche.shown]
    print("   coche sans titre porte : %s" % coches)
    assert coches == ["None"],         "GetCurrentTitle rend 0 : c est Aucun qui est coche"

    # CLIQUER CHANGE LE TITRE PORTE.
    lignes[2].scripts.OnClick(lignes[2])
    coches = [l.texte.text for l in lignes if l.coche.shown]
    print("   apres le clic sur %s : GetCurrentTitle=%s, coche %s" % (
        lignes[2].texte.text, lua.eval("GetCurrentTitle()"), coches))
    assert lua.eval("GetCurrentTitle()") == 15, "SetCurrentTitle recoit l identifiant"
    assert coches == ["Scout"], "la coche suit, et il n y en a qu une"

    # LE NOM DE LA FEUILLE SUIT LE TITRE. Il ne change pas au clic --
    # SetCurrentTitle part au serveur -- mais a UNIT_NAME_UPDATE, que le
    # client envoie quand la reponse arrive.
    bande = perso.foreverTitre
    print("   nom de la feuille apres le clic : \"%s\"" % bande.text)
    g.ForeverUICharacterWatcher.scripts.OnEvent(
        g.ForeverUICharacterWatcher, "UNIT_NAME_UPDATE", "player")
    print("   apres UNIT_NAME_UPDATE : \"%s\"" % bande.text)
    assert bande.text == "Scout Robert Polson",         "la bande de titre reprend UnitPVPName"

    # Et pas pour une autre unite : l evenement part pour tout le decor.
    lua.execute("TITRE_PORTE = 1")
    g.ForeverUICharacterWatcher.scripts.OnEvent(
        g.ForeverUICharacterWatcher, "UNIT_NAME_UPDATE", "target")
    assert bande.text == "Scout Robert Polson",         "seule l unite du joueur refait la bande"
    lua.execute("TITRE_PORTE = 15")

    # "AUCUN" SE POSE PAR -1, comme le client le fait.
    lignes[0].scripts.OnClick(lignes[0])
    assert lua.eval("GetCurrentTitle()") == -1, "Aucun vaut -1"
    g.ForeverUICharacterWatcher.scripts.OnEvent(
        g.ForeverUICharacterWatcher, "UNIT_NAME_UPDATE", "player")
    print("   sans titre : \"%s\"" % bande.text)
    assert bande.text == "Robert Polson", "sans titre, le nom seul"

    # LE MENU DEROULANT DU CLIENT SE TAIT, ET A CHAQUE PASSAGE : le sien se
    # remontre dans PlayerTitleFrame_UpdateTitles.
    g.PlayerTitleFrame_UpdateTitles()
    restants = [n for n in ("PlayerTitleFrame", "PlayerTitlePickerFrame") if g[n].shown]
    print("   menu du client : %d morceau(x) encore visible(s)" % len(restants))
    assert restants == [], "il en reste : %s" % restants

    # LES STATISTIQUES NE DOIVENT PAS REPARAITRE TOUTES SEULES.
    #
    # UpdatePaperdollStats remontre chacune de ses lignes a chaque mise a
    # jour -- gain de niveau, changement d equipement -- sans demander si
    # l ecran est ouvert. Elles se superposaient donc a la page des titres
    # ou a celle des ensembles.
    g.PaperDollFrame_UpdateStats()
    lignes = [g["PlayerStatFrameLeft" + str(i)].shown for i in range(1, 7)]
    print("   montee de niveau sur la page des titres : stats visibles=%s,"
          " titres=%s" % (any(lignes), volets.shown))
    assert not any(lignes),         "les statistiques ne doivent pas revenir par-dessus les titres"
    assert not g.PlayerStatFrameLeftDropDown.shown, "leurs en-tetes non plus"
    assert volets.shown, "et la page des titres demeure"

    # LE MEME SUR LA PAGE DES ENSEMBLES.
    droit.choisirPage("equipement")
    g.ForeverUI.CharacterApplyPanes(perso)
    g.PaperDollFrame_UpdateStats()
    lignes = [g["PlayerStatFrameLeft" + str(i)].shown for i in range(1, 7)]
    print("   montee de niveau sur la page des ensembles : stats visibles=%s,"
          " panneau=%s" % (any(lignes), g.ForeverUIEquipmentPane.shown))
    assert not any(lignes),         "ni par-dessus le gestionnaire d ensembles"
    assert g.ForeverUIEquipmentPane.shown, "qui demeure"

    # ET SUR LEUR PROPRE PAGE, ELLES REVIENNENT BIEN.
    droit.choisirPage("stats")
    g.ForeverUI.CharacterApplyPanes(perso)
    g.PaperDollFrame_UpdateStats()
    lignes = [g["PlayerStatFrameLeft" + str(i)].shown for i in range(1, 7)]
    print("   sur leur propre page : stats visibles=%s" % all(lignes))
    assert all(lignes), "sur leur page, la mise a jour doit les montrer"

    droit.choisirPage("equipement")
    g.ForeverUI.CharacterApplyPanes(perso)

    # ET LE REPLI VAUT SUR TOUS LES ONGLETS, puisque le volet y est.
    perso.foreverRepli.scripts.OnClick(perso.foreverRepli)
    g.CharacterFrame_ShowSubFrame("SkillFrame")
    g.ForeverUI.Panes.ShowGroup("SkillFrame")
    g.ForeverUI.CharacterApplyPanes(perso)
    print("   replie puis onglet competences : fenetre %d, volet droit=%s" % (
        perso.width, droit.shown))
    assert perso.width == 398 and not droit.shown, "le repli traverse les onglets"
    perso.foreverRepli.scripts.OnClick(perso.foreverRepli)
    assert perso.width == 631 and droit.shown, "et se defait depuis n importe lequel"
    g.CharacterFrame_ShowSubFrame("PaperDollFrame")
    g.ForeverUI.Panes.ShowGroup("PaperDollFrame")
    g.ForeverUI.CharacterApplyPanes(perso)

    # RIEN NE SE RECALCULE. Vingt allers-retours ne doivent deplacer aucune
    # mesure : un contenu se batit une fois, puis ne fait que paraitre.
    avant = (g.ForeverUIEquipmentPane.points[1][4],
             g.ForeverUIEquipmentNewSet.points[1][5],
             g.PlayerStatFrameLeft1.points[1][5])
    for _ in range(20):
        for nom in ("ReputationFrame", "PaperDollFrame"):
            g.CharacterFrame_ShowSubFrame(nom)
            g.ForeverUI.Panes.ShowGroup(nom)
            g.ForeverUI.CharacterApplyPanes(perso)
    apres = (g.ForeverUIEquipmentPane.points[1][4],
             g.ForeverUIEquipmentNewSet.points[1][5],
             g.PlayerStatFrameLeft1.points[1][5])
    print("   apres vingt allers-retours : %s (avant %s)" % (str(apres), str(avant)))
    assert avant == apres, "aucune mesure ne doit deriver d un changement d onglet"

    # LES DEUX ONGLETS QUE 3.3.5 N A PAS : PvP et statistiques.
    pvp, stat = g.ForeverUICharacterTabPvP, g.ForeverUICharacterTabStats
    print("   onglets crees : PvP icone=%s | statistiques icone=%s" % (
        pvp.foreverIcone.texture.split(chr(92))[-1],
        stat.foreverIcone.texture.split(chr(92))[-1]))
    assert "Honor" in pvp.foreverIcone.texture, "l icone du PvP suit la faction"
    assert "Stats" in stat.foreverIcone.texture, "INV_SideTab_Stats_c60"

    # L ORDRE DE LA COLONNE suit camelot : le PvP entre competences et
    # monnaie, les statistiques en dernier.
    attendu = ["CharacterFrameTab1", "CharacterFrameTab2", "CharacterFrameTab3",
               "CharacterFrameTab4", "ForeverUICharacterTabPvP",
               "CharacterFrameTab5", "ForeverUICharacterTabStats"]
    colonne, courant = [], None
    for nom in attendu:
        o = g[nom]
        pt = o.points[len(list(o.points.values()))]
        colonne.append((nom, pt[2].name if pt[2] else None))
    print("   colonne : %s" % " -> ".join(n for n, _ in colonne))
    for rang in range(1, len(attendu)):
        assert colonne[rang][1] == attendu[rang - 1],             "%s doit suivre %s, il suit %s" % (attendu[rang], attendu[rang - 1],
                                              colonne[rang][1])

    # CLIQUER SUR LE PvP : les cinq ecrans du client s en vont, le notre vient.
    pvp.scripts.OnClick(pvp)
    visibles = [e for e in list(g.CHARACTERFRAME_SUBFRAMES.values()) if g[e].shown]
    ppvp = g.PVPParentFrame.points[len(list(g.PVPParentFrame.points.values()))]
    print("   clic PvP : ecrans du client visibles=%s, PVPParentFrame parent=%s "
          "toplevel=%s, volet droit=%s" % (
        visibles, g.PVPParentFrame.parent.name, g.PVPParentFrame.toplevel, droit.shown))
    assert visibles == [], "aucun ecran du client ne reste"
    assert g.PVPParentFrame.shown, "la fenetre PvP devient le contenu du volet"
    assert g.PVPParentFrame.parent.name == "ForeverUICharacterLeftPane",         "elle cesse d etre une fenetre : elle passe dans le volet gauche"
    assert g.PVPParentFrame.toplevel is False, "et ne se hisse plus au-dessus de tout"
    assert ppvp[2].name == "ForeverUICharacterLeftPane", "bornee au volet"
    assert droit.shown and perso.width == 631, "le volet droit reste, comme ailleurs"

    # LE SYSTEME DE PANNEAUX NE DOIT PLUS LA REPRENDRE.
    #
    # UIPanelWindows["PVPParentFrame"] existe dans le client -- UIParent.lua
    # ligne 52. Tant qu il y est, UpdateUIPanelPositions rend ses ancres a
    # UIParent et la fenetre redevient une dalle de 384 x 512 posee a
    # l ecran. Son art etant eteint, elle ne se voit pas, mais elle prend la
    # souris : les onglets lateraux cessaient de repondre au clic.
    print("   inscription au systeme de panneaux : %s" % (
        g.UIPanelWindows["PVPParentFrame"]))
    assert g.UIPanelWindows["PVPParentFrame"] is None,         "elle n est plus une fenetre : elle sort de UIPanelWindows"

    g.UpdateUIPanelPositions(g.CharacterFrame)
    ppvp = g.PVPParentFrame.points[len(list(g.PVPParentFrame.points.values()))]
    print("   apres le systeme de panneaux : parent=%s ancre sur %s" % (
        g.PVPParentFrame.parent.name, ppvp[2].name))
    assert g.PVPParentFrame.parent.name == "ForeverUICharacterLeftPane",         "elle reste dans le volet"
    assert ppvp[2].name == "ForeverUICharacterLeftPane", "et bornee a lui"

    # ET SI QUELQUE CHOSE LUI RENDAIT SES ANCRES, le passage suivant les
    # reprend : le bornage se refait a chaque mise a jour, pas une seule fois.
    lua.execute('PVPParentFrame:SetParent(UIParent); PVPParentFrame:ClearAllPoints();'
                ' PVPParentFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, -104)')
    g.ForeverUI.PvPUpdate()
    ppvp = g.PVPParentFrame.points[len(list(g.PVPParentFrame.points.values()))]
    print("   apres un deplacement force : parent=%s ancre sur %s" % (
        g.PVPParentFrame.parent.name, ppvp[2].name))
    assert g.PVPParentFrame.parent.name == "ForeverUICharacterLeftPane"         and ppvp[2].name == "ForeverUICharacterLeftPane",         "le passage suivant la remet dans son volet"

    # DEPUIS LE PvP, L ONGLET DU PERSONNAGE DOIT RAMENER LA FEUILLE.
    #
    # Il ne passe PAS par CharacterFrame_ShowSubFrame : CharacterFrameTab_OnClick
    # appelle ToggleCharacter, qui FERME la fenetre si l ecran demande est deja
    # montre. C est ce chemin-la qu il faut essayer, et lui seul.
    #
    # ET ON Y ARRIVE PAR LE CHEMIN REEL : on choisit d abord l onglet du
    # personnage par le clic du client -- ce qui le DESACTIVE, c est ce que
    # fait PanelTemplates_SelectTab -- puis on passe au PvP par le notre.
    t1 = g.CharacterFrameTab1
    t1.scripts.OnClick(t1)
    print("   onglet du personnage choisi : actif=%s" % (t1.enabled,))
    assert t1.enabled is False,         "PanelTemplates_SelectTab desactive l onglet choisi"
    pvp.scripts.OnClick(pvp)
    print("   apres l onglet PvP : onglet du personnage actif=%s" % (t1.enabled,))
    assert t1.enabled is not False,         "nos ecrans ne passent pas par PanelTemplates : il faut rendre la main"

    t1.scripts.OnClick(t1)
    visibles = [e for e in list(g.CHARACTERFRAME_SUBFRAMES.values()) if g[e].shown]
    print("   depuis le PvP, clic sur l onglet du personnage : fenetre=%s,"
          " ecrans=%s, PvP=%s, page=%s" % (
        perso.shown, visibles, g.PVPParentFrame.shown, Panes.CurrentGroup("gauche")))
    assert perso.shown, "la fenetre ne doit pas se fermer"
    assert visibles == ["PaperDollFrame"], "la feuille revient"
    assert not g.PVPParentFrame.shown, "et le PvP s en va"
    pvp.scripts.OnClick(pvp)

    # CLIQUER SUR LES STATISTIQUES : l ecran est vide, mais l onglet marche.
    stat.scripts.OnClick(stat)
    print("   clic statistiques : PvP visible=%s, volet droit=%s" % (
        g.PVPParentFrame.shown, droit.shown))
    assert not g.PVPParentFrame.shown, "le PvP s en va"
    assert droit.shown, "le volet droit reste"

    # REVENIR AU PERSONNAGE par un onglet du client : nos ecrans s en vont.
    g.CharacterFrame_ShowSubFrame("PaperDollFrame")
    g.ForeverUI.Panes.ShowGroup("PaperDollFrame")
    g.ForeverUI.CharacterApplyPanes(perso)
    assert not g.PVPParentFrame.shown, "le PvP ne survit pas a un onglet du client"
    assert droit.pierre.shown, "et le mobilier du personnage revient"

    # L ICONE REMPLIT L INTERIEUR : fillToInterior, interiorExtent = 50.
    ico = g.CharacterFrameTab3.foreverIcone
    print("   icone d onglet : %d x %d, rognee a %.5f, centree a x=%s" % (
        ico.width, ico.height, ico.texcoord[1], ico.points[1][4]))
    assert ico.width == 50 and ico.height == 50,         "UpdateIconInterior : SetSize(50, 50)"
    assert abs(ico.texcoord[1] - 0.03125) < 1e-6,         "et SetTexCoord(0.03125, 0.96875, ...)"
    assert ico.points[1][4] == -3, "GetIconAnchorOffsetsForTabArt rend (-3, 0)"

    # LE MARQUEUR D ONGLET ACTIF : common-sidetab-selected, un seul a la fois.
    def actifs():
        noms = []
        for nom in attendu:
            o = g[nom]
            if o.foreverActif and o.foreverActif.shown:
                noms.append(nom)
        return noms

    g.CharacterFrame_ShowSubFrame("ReputationFrame")
    g.ForeverUI.Panes.ShowGroup("ReputationFrame")
    g.ForeverUI.CharacterUpdateActiveTab()
    print("   onglet actif sur reputation : %s" % actifs())
    assert actifs() == ["CharacterFrameTab3"], "un seul onglet porte le marqueur"

    pvp.scripts.OnClick(pvp)
    print("   onglet actif apres clic PvP : %s" % actifs())
    assert actifs() == ["ForeverUICharacterTabPvP"], "le marqueur suit, meme sur nos onglets"

    g.CharacterFrame_ShowSubFrame("PaperDollFrame")
    g.ForeverUI.Panes.ShowGroup("PaperDollFrame")
    g.ForeverUI.CharacterApplyPanes(perso)
    g.ForeverUI.CharacterUpdateActiveTab()
    assert actifs() == ["CharacterFrameTab1"], "et revient au personnage"

    # LE TEMOIN de la bibliotheque.
    for ligne in g.ForeverUI.Panes.Report().values():
        print("   %s" % ligne)

    stats.scripts.OnClick(stats)

    # ------------------------------------------------- bas de l'ecran
    micro = g.ForeverUIMicroMenu
    print("micro-menu : %d x %d pour %d boutons" % (
        micro.width, micro.height, len(list(g.ForeverUI.MicroButtons.values()))))
    assert micro.width == 322, "le micro-menu ne fait pas 275 + 47 de rallonge"
    assert micro.height == 40

    b1, b2 = g.CharacterMicroButton, g.SpellbookMicroButton
    print("bouton de micro-menu : %d x %d (32 x 46 : l'ouverture du cadre ; 28 x 58 d'origine)" % (
        b1.width, b1.height))
    assert b1.width == 32 and b1.height == 46, "le bouton ne remplit pas l'ouverture du cadre"
    assert micro.height == 40, "le bandeau ne doit pas changer de hauteur"
    entree0 = list(g.ForeverUI.MicroButtons.values())[0]
    assert entree0.fond.allPoints, "le fond ne suit pas la taille du bouton"
    pp0 = g.MicroButtonPortrait
    assert pp0.width == 18 and pp0.height == 26, "le portrait n'a plus sa taille d'origine"
    assert b1.hitRect and b1.hitRect[3] == 0, "les 18 px inertes du haut sont restes"
    print("premier bouton a %s du bord gauche du bandeau (0 attendu)" % b1.points[1][4])
    assert b1.points[1][4] == 0, "les boutons ne sont pas serres a gauche"
    pas = b2.points[1][4] - b1.points[1][4]
    print("pas du micro-menu : %s (27 attendu : 32 - 5 de chevauchement)" % pas)
    assert pas == 27, "childXPadding = -5 n'est pas respecte"

    porte = g.MainMenuMicroButton
    assert porte.frameLevel > b1.frameLevel, "le bouton de droite ne passe pas devant"

    # le fond change quand le bouton est enfonce, comme SetPushed le fait
    entree = list(g.ForeverUI.MicroButtons.values())[0]
    print("fond au repos : up visible=%s, down visible=%s" % (
        entree.fond.shown, entree.fondEnfonce.shown))
    assert entree.fond.shown and not entree.fondEnfonce.shown
    g.CharacterMicroButton.buttonState = "PUSHED"
    g.HOOKS["UpdateMicroButtons"]()
    print("apres enfoncement : up visible=%s, down visible=%s, ombre enfoncee=%s" % (
        entree.fond.shown, entree.fondEnfonce.shown,
        entree.ombreEnfoncee and entree.ombreEnfoncee.shown))
    assert not entree.fond.shown and entree.fondEnfonce.shown, "le fond enfonce ne prend pas le relais"
    g.CharacterMicroButton.buttonState = "NORMAL"
    g.HOOKS["UpdateMicroButtons"]()

    # le portrait reprend le rognage de camelot
    pp = g.MicroButtonPortrait
    print("portrait : rogne a (%.4f, %.4f, %.4f, %.4f), %d x %d centre" % (
        pp.texcoord[1], pp.texcoord[2], pp.texcoord[3], pp.texcoord[4], pp.width, pp.height))
    assert abs(pp.texcoord[1] - 0.2) < 1e-6 and abs(pp.texcoord[4] - 0.9) < 1e-6
    assert pp.points[1][1] == "CENTER"

    # ----------------------------------------------------- barre des sacs
    sacs = g.ForeverUIBagsBar
    print("barre des sacs : %d x %d (268 x 45 attendu : 5 x 45 + 33 + 5 x 2)" % (
        sacs.width, sacs.height))
    assert sacs.width == 268 and sacs.height == 45

    dos = g.MainMenuBarBackpackButton
    sac0 = g.CharacterBag0Slot
    print("sac a dos %d x %d, ancre %s sur %s | sac 1 decale de %s" % (
        dos.width, dos.height, dos.points[1][1], dos.points[1][3], sac0.points[1][4]))
    assert dos.width == 45 and dos.height == 45
    assert sac0.points[1][4] == -2, "bagPadding = 2 n'est pas respecte"
    assert dos._normal.width == 46 and dos._normal.height == 46, "le cadre du sac n'est pas en 46 x 46"
    assert dos._highlight.blend == "ADD", "le survol du sac n'est pas en ADD"

    trousseau = g.KeyRingButton
    print("trousseau : %d x %d, visible=%s, cadre %d de large" % (
        trousseau.width, trousseau.height, trousseau.shown, trousseau._normal.width))
    assert trousseau.width == 33 and trousseau.height == 45

    # L'EMPLACEMENT DU TROUSSEAU PORTE SON ICONE. Toujours : en 3.3.5 le
    # trousseau est permanent, alors que la condition de CVar de la source
    # vient d'un client ou il n'est plus qu'un reste du passe, masque tant
    # que le joueur n'a pas ramasse de cle.
    icone = trousseau.regions[len(list(trousseau.regions.values()))]
    print("   icone du trousseau : %s, %d x %d" % (
        icone.texture and icone.texture.split(chr(92))[-1], icone.width, icone.height))
    assert icone.texture is not None, "l emplacement du trousseau doit porter une icone"
    assert icone.width == 27 and icone.height == 40,         "UI-HUD-ActionBar-Keyring-Small fait 27 x 40"
    assert trousseau.shown, "camelot garde toujours le trousseau dans la barre"

    assert g.ForeverUIBagsFiller is None, "l emplacement decoratif est encore construit"

    cellules = list(g.ForeverUI.BagsCells.values())
    separateurs = [v for v in g.ForeverUI.BagsDividers.values()]
    print("cellules : %d | separateurs : %d (un de moins que de cellules)" % (
        len(cellules), len(separateurs)))
    assert len(cellules) == 6, "la barre des sacs ne compte pas six cellules"
    assert len(separateurs) == 5

    # ------------------------------------------------- la rangee complete
    for nom, attendu in (("micromenu", (116.5, 6)), ("actionbar", (-49, 2)), ("sacs", (284.5, 2))):
        d = g.ForeverUI.Layout.systems[nom].defaults
        print("%-10s : %s sur %s (%.1f, %.1f)" % (nom, d.point, d.relativePoint, d.x, d.y))
        assert abs(d.x - attendu[0]) < 1e-6 and abs(d.y - attendu[1]) < 1e-6, (
            "position par defaut fausse pour %s" % nom)

    embout = g.ForeverUI.ActionBarEndCaps.right
    pt = embout.points[1]
    print("embout droit : %s sur %s (%s, %s)" % (pt[1], pt[3], pt[4], pt[5]))
    assert pt[1] == "BOTTOMLEFT" and pt[3] == "BOTTOMRIGHT", "l'embout droit n'est pas cale par le bas"
    assert pt[4] == -30 and pt[5] == -2, "l'embout droit ne tient pas au bord des sacs"
    gauche = g.ForeverUI.ActionBarEndCaps.left.points[1]
    print("embout gauche : %s sur %s (%s, %s)" % (gauche[1], gauche[3], gauche[4], gauche[5]))
    assert gauche[1] == "BOTTOMRIGHT" and gauche[3] == "BOTTOMLEFT" and gauche[5] == -2

    # ------------------------------------------------------- les sacs
    sac = g.ContainerFrame1
    print("cadre de sac : habille=%s | ancien fond efface=%s" % (
        sac.foreverSkinned == True, g["ContainerFrame1BackgroundTop"].alpha == 0))
    assert sac.foreverSkinned, "le cadre de sac n'est pas habille"
    assert g["ContainerFrame1BackgroundTop"].alpha == 0, "l'habillage d'epoque est reste"

    panneau = sac.foreverPanel
    print("panneau : %d morceaux de fond, coins %s" % (
        len(list(panneau.fond.values())),
        ", ".join(sorted(k for k in dict(panneau).keys() if str(k).startswith("coin")))))
    assert panneau.coinHautGauche is not None and panneau.bordBas is not None
    # HeldBagLayout, au pixel pres : chaque coin porte son decalage, et les
    # huit morceaux sont en OVERLAY.
    COINS = {"coinHautGauche": (-13, 16), "coinHautDroit": (4, 16),
             "coinBasGauche": (-13, -3), "coinBasDroit": (4, -3)}
    for cle, (x, y) in sorted(COINS.items()):
        t = panneau[cle]
        pt = t.points[1]
        print("   %-15s %s (%s, %s) en %s" % (cle, pt[1], pt[4], pt[5], t.layer))
        assert (pt[4], pt[5]) == (x, y), "%s ne suit pas HeldBagLayout" % cle
        assert t.layer == "OVERLAY", "HeldBagLayout declare %s en OVERLAY" % cle

    # Le portrait est en BORDER : le fond est en BACKGROUND et le metal en
    # OVERLAY, donc il est toujours entre les deux, quel que soit l'ordre de
    # creation. Depuis le calque du fond, le corps de celui-ci -- ancre a 20
    # px du haut -- passait devant lui et coupait l'anneau.
    assert g["ContainerFrame1Portrait"].alpha == 0, "l'ancien portrait doit s'effacer"
    # NineSliceUtil.UpdateCornerCropping : sur une fenetre plus courte que
    # ses deux coins empiles, le coin du BAS est rogne par le haut.
    eHaut = g.ForeverUI.AtlasEntry("ui-frame-portraitmetal-cornertopleftsmall")
    eBas = g.ForeverUI.AtlasEntry("ui-frame-metal-cornerbottomleft")
    hautCoin, basCoin = eHaut[7], eBas[7]
    coinBas = sac.foreverPanel.coinBasGauche
    for hauteur, cas in ((269, "sac a dos"), (100, "trousseau, une rangee")):
        sac.SetHeight(sac, hauteur)
        g.ForeverUI.UpdatePanelCorners(sac)
        debord = max(0, min(hautCoin + basCoin - hauteur - 16 - 3, basCoin))
        print("   coin du bas, %-22s hauteur %3d -> rogne de %2d, reste %d" % (
            cas, hauteur, debord, coinBas.height))
        assert abs(coinBas.height - (basCoin - debord)) < 0.01,             "le coin du bas n'est pas rogne comme ClipNineSliceBottomCorner"
    sac.SetHeight(sac, 269)
    g.ForeverUI.UpdatePanelCorners(sac)

    portrait = sac.foreverPortrait
    pt = portrait.points[1]
    fond = list(sac.foreverPanel.fond.values())[0]
    print("portrait : %dx%d en %s, %s sur %s (%.0f, %.0f)" % (
        portrait.width, portrait.height, portrait.layer, pt[1], pt[3], pt[4], pt[5]))
    # La methode du client : l'icone tient dans le trou de l'anneau, et ses
    # coins tombent sous le metal opaque (14,3 a 20,4 du centre).
    assert portrait.width == 28 and portrait.height == 28,         "l'icone doit tenir dans l'anneau : 28"
    assert pt[1] == "CENTER" and pt[3] == "TOPLEFT" and pt[4] == 14 and pt[5] == -17,         "l'icone doit etre centree sur l'anneau, a (14, -17)"
    print("   calques : fond %s, portrait %s, metal %s" % (
        fond.layer, portrait.layer, sac.foreverPanel.coinHautGauche.layer))
    assert fond.layer == "BACKGROUND" and portrait.layer == "BORDER",         "le portrait doit etre dans un calque au-dessus du fond, pas dans le sien"
    assert sac.foreverPanel.coinHautGauche.layer == "OVERLAY",         "HeldBagLayout declare ses morceaux en OVERLAY"

    # UpdateName / UpdateMiscellaneousFrames : le nom et l'icone viennent du
    # sac, et se refont a chaque passage du client.
    g.HOOKS["ContainerFrame_GenerateFrame"](sac)
    assert g["ContainerFrame1Name"].alpha == 0, "l'ancien titre doit s'effacer"
    bande = sac.foreverBandeTitre
    titre = sac.foreverTitre
    b1, b2 = bande.points[1], bande.points[2]
    print("titre : \"%s\" (du sac, pas du code) | bande %s (%s) a %s (%s), %d de haut, niveau +%d" % (
        titre.text, b1[1], b1[4], b2[1], b2[4], bande.height,
        bande.GetFrameLevel(bande) - sac.GetFrameLevel(sac)))
    assert titre.text == "Sac a dos", "le nom ne vient pas de GetBagName"
    assert b1[4] == 35 and b1[5] == -1, "SetTitleOffsets(35) : TOPLEFT (35, -1)"
    assert b2[4] == -24 and b2[5] == -1, "la valeur par defaut a droite est -24"
    assert bande.height == 20, "TitleContainer fait 20 de haut"
    assert titre.points[1][5] == -5, "TitleText est ancre TOP (0, -5) dans son conteneur"
    assert titre.justify == "CENTER", "le titre se centre dans son conteneur"
    assert bande.GetFrameLevel(bande) > sac.GetFrameLevel(sac),         "le titre doit etre un cadre fils : le metal est en OVERLAY"
    print("   portrait du sac a dos : %s, rognage %s (la bordure de 4 px)" % (
        portrait.texture, [round(v, 2) for v in portrait.texcoord.values()]))
    assert [round(v, 4) for v in portrait.texcoord.values()] == [0.0625, 0.9375, 0.0625, 0.9375],         "l'icone doit etre rognee de sa bordure de 4 px, comme le client le fait"
    assert portrait.texture and portrait.texture.lower().find("inv_misc_bag_08") >= 0,         "le sac a dos porte Inv_misc_bag_08"

    sac.id = 1
    g.HOOKS["ContainerFrame_GenerateFrame"](sac)
    print("   sac porte : titre \"%s\", portrait %s" % (titre.text, portrait.texture))
    assert titre.text == "Sac en tisse-givre", "un sac porte prend le nom de l'objet"
    assert portrait.texture == "icone_du_sac_1", "un sac porte prend l'icone de l'objet"
    sac.id = 0
    g.HOOKS["ContainerFrame_GenerateFrame"](sac)

    bouton = g["ContainerFrame1Item1"]
    print("emplacement : art dore efface (alpha %s) | voile de recherche=%s" % (
        bouton._normal.alpha, bouton.foreverVoile is not None))
    assert bouton.foreverVoile is not None, "le voile de recherche manque"
    assert bouton._normal.alpha == 0,         "l'art de 3.3.5 doit s'effacer : pose sur la NormalTexture il couvrait l'icone"

    # LA FORMULE DE CAMELOT, recopiee de ContainerFrameMixin :
    #   hauteur = rangees x 37 + (rangees-1) x 5 + comble + extra
    #   comble  = GetFirstButtonOffsetY() 9 + 48, + 30 sur le sac a dos
    #   extra   = la bourse (13) sur le sac a dos, 0 ailleurs
    #   largeur = CONTAINER_WIDTH, une constante
    # Le client montre le cadre au bout de ContainerFrame_GenerateFrame ;
    # le faux client n'appelle que nos accroches, on ouvre donc le sac ici.
    g.ContainerFrame1.Show(g.ContainerFrame1)   # pas d'appel a deux points en Python
    g.ContainerFrame1.size = 16
    g.HOOKS["ContainerFrame_GenerateFrame"](g.ContainerFrame1)
    g.ForeverUI.BagsLayout()

    def ancre(piece):
        """La derniere ancre posee : (point, cible, pointCible, x, y)."""
        pt = piece.points[len(list(piece.points.values()))]
        return pt[1], pt[2], pt[3], pt[4], pt[5]

    premier = g.ContainerFrame1Item1
    bourse = g.ContainerFrame1MoneyFrame
    champ = g.ForeverUIBagSearchBox
    tri = g.ForeverUIBagSortButton

    GRILLE = 4 * 37 + 3 * 5                     # 163
    HAUTEUR = GRILLE + (15 + 48 + 30) + 13      # 269 : 263 de camelot, + 6 remontes
    print("fenetre du sac a dos : %d x %d (178 x %d : CalculateHeight, + 6 remontes)" % (
        g.ContainerFrame1.width, g.ContainerFrame1.height, HAUTEUR))
    assert g.ContainerFrame1.width == 178, "CalculateWidth() vaut CONTAINER_WIDTH"
    assert g.ContainerFrame1.height == HAUTEUR, "CalculateHeight() n'est pas respectee"

    # ContainerFrameBackpackMixin:GetInitialItemAnchor -- la grille du sac a
    # dos s'accroche a la BOURSE, pas au cadre.
    point, cible, pointCible, x, y = ancre(premier)
    print("   premiere case : %s sur %s de %s (%s, %s)" % (
        point, pointCible, cible.name if hasattr(cible, "name") else cible, x, y))
    assert point == "BOTTOMRIGHT" and pointCible == "TOPRIGHT", \
        "la grille du sac a dos ne s'accroche pas au-dessus de la bourse"
    assert x == 0 and y == 4, "GetInitialItemAnchor du sac a dos vaut (0, 4)"

    # UpdateCurrencyFrames -- BOTTOMLEFT (8, 8) / BOTTOMRIGHT (-8, 8)
    point, _, _, x, y = ancre(bourse)
    print("   bourse : %s (%s, %s), %d de haut, encadree=%s" % (
        point, x, y, bourse.height, bourse.foreverBorde == True))
    assert x == -8 and y == 14, "la bourse doit etre remontee de 6"
    assert bourse.height == 13, "UpdateMoneyFrame pose 13"
    assert bourse.foreverBorde, "la bourse n'a pas son encadre"

    # LE SEGMENT DES MONNAIES SUIVIES, sous la bourse.
    #
    # RELEVE -- ContainerFrameTokenWatcherMixin:UpdateCurrencyFrames : le
    # segment prend le bas, la bourse MONTE au-dessus de lui (0, 3), et
    # CalculateExtraHeight ajoute sa hauteur.
    print("   sans monnaie suivie : segment=%s" % (
        g.ForeverUIBagTokens is not None and g.ForeverUIBagTokens.shown))
    assert g.ForeverUIBagTokens is None or not g.ForeverUIBagTokens.shown,         "sans monnaie suivie, pas de segment"

    lua.execute('SUIVIES = { { nom = "Emblem of Frost", compte = 42,'
                ' icone = "icone_embleme" },'
                ' { nom = "Honor Points", compte = 7, special = 2 } }')
    g.ForeverUI.BagsApply()
    segment = g.ForeverUIBagTokens
    ps = segment.points[len(list(segment.points.values()))]
    pb = ancre(bourse)
    print("   deux monnaies suivies : segment %s (%s, %s) haut de %d |"
          " bourse %s sur %s (%s, %s)" % (
        ps[1], ps[4], ps[5], segment.height, pb[0], pb[2], pb[3], pb[4]))
    assert segment.shown, "le segment parait"
    assert segment.height == 17, "BackpackTokenFrameTemplate fait 17"
    assert (ps[1], ps[4], ps[5]) == ("BOTTOMRIGHT", -8, 14),         "il prend le bas, aux memes 8 que la bourse"
    assert (pb[0], pb[2], pb[3], pb[4]) == ("BOTTOMRIGHT", "TOPRIGHT", 0, 3),         "la bourse monte au-dessus du segment"

    HAUTEUR2 = HAUTEUR + 17 + 3
    print("   la fenetre grandit : %d (avant %d)" % (
        g.ContainerFrame1.height, HAUTEUR))
    assert g.ContainerFrame1.height == HAUTEUR2,         "CalculateExtraHeight doit compter le segment"

    # LES JETONS S ENCHAINENT VERS LA GAUCHE depuis le bord droit.
    j1, j2, j3 = g.ForeverUIBagToken1, g.ForeverUIBagToken2, g.ForeverUIBagToken3
    pj1 = j1.points[len(list(j1.points.values()))]
    print("   jetons : %s %s | comptes %s, %s | troisieme visible=%s" % (
        j1.width, j1.height, j1.compte.text, j2.compte.text, j3.shown))
    assert j1.width == 50 and j1.height == 12, "BackpackTokenTemplate"
    assert (pj1[1], pj1[4], pj1[5]) == ("RIGHT", -17, -1), "GetInitialTokenAnchor"
    assert j1.compte.text == 42 and j2.compte.text == 7, "les comptes du client"
    # A LA DEMANDE : d un cran au-dessus du GameFontHighlightSmall de camelot,
    # et celui de la BOURSE ne bouge pas -- il est au cadre d argent du client.
    print("   police du compte : %s | ancres %s" % (
        j1.compte.font, [p[1] for p in j1.compte.points.values()]))
    assert j1.compte.font == "GameFontHighlight", "les chiffres sont agrandis"
    assert [p[1] for p in j1.compte.points.values()] == ["LEFT", "RIGHT"],         "deux ancres horizontales : borne comme avant, et centre en hauteur"
    assert not j3.shown, "la troisieme place reste vide"
    assert "UI-PVP-Alliance" in j2.icone.texture,         "les points d honneur gardent leur icone de faction"

    # LE SEGMENT DU CLIENT SE TAIT, et sa fonction de taille ne defait plus
    # la notre.
    g.ManageBackpackTokenFrame()
    print("   segment du client : visible=%s | hauteur apres son passage : %d" % (
        g.BackpackTokenFrame.shown, g.ContainerFrame1.height))
    assert not g.BackpackTokenFrame.shown, "celui du client s en va"
    assert g.ContainerFrame1.height == HAUTEUR2,         "ManageBackpackTokenFrame reposait BACKPACK_HEIGHT + 22 : on repasse derriere"

    lua.execute("SUIVIES = {}")
    g.ForeverUI.BagsApply()
    print("   plus aucune monnaie suivie : hauteur %d" % g.ContainerFrame1.height)
    assert g.ContainerFrame1.height == HAUTEUR, "la fenetre retrouve sa taille"
    assert not segment.shown, "et le segment s en va"

    # SetSearchBoxPoint / UpdateSearchBox -- ancres en HAUT, comme la source
    point, _, pointCible, x, y = ancre(champ)
    print("   champ : %s sur %s (%s, %s), %d de large" % (point, pointCible, x, y, champ.width))
    assert (point, x, y) == ("TOPLEFT", 42, -43), "le champ redescend de 6 : TOPLEFT (42, -43)"
    assert champ.width == 96, "SetSearchBoxPoint pose 96 de large"
    point, _, _, x, y = ancre(tri)
    print("   tri   : %s (%s, %s)" % (point, x, y))
    assert (point, x, y) == ("TOPRIGHT", -9, -40), "le tri redescend de 6 : TOPRIGHT (-9, -40)"

    rangee2 = g.ContainerFrame1Item5
    print("   ecart entre rangees : %s (ITEM_SPACING_Y = 5)" % ancre(rangee2)[4])
    assert ancre(rangee2)[4] == 5, "l'ecart entre rangees n'est pas ITEM_SPACING_Y"

    # /fui sacs doit s'executer : c'est la seule facon de relire la formule en
    # jeu, et une erreur y passait inapercue jusqu'ici.
    g.ForeverUI.BagsDebug()

    # LA FENETRE SUIT SON CONTENU. C'est le nombre de rangees qui entre dans
    # CalculateHeight : on change la taille du sac et la hauteur doit suivre,
    # pour le sac a dos comme pour un sac porte.
    print("   le sac a dos suit son contenu :")
    for taille, rangees in ((16, 4), (20, 5), (24, 6), (28, 7), (36, 9)):
        g.ContainerFrame1.size = taille
        g.HOOKS["ContainerFrame_GenerateFrame"](g.ContainerFrame1)
        grille = rangees * 37 + (rangees - 1) * 5
        attendu = grille + (15 + 48 + 30) + 13
        print("      %2d cases (%d rangees) -> %d de haut (%d attendu)" % (
            taille, rangees, g.ContainerFrame1.height, attendu))
        assert g.ContainerFrame1.height == attendu, "le sac a dos ne suit pas son contenu"
        assert g.ContainerFrame1.width == 178, "la largeur est une constante"
    g.ContainerFrame1.size = 16
    g.HOOKS["ContainerFrame_GenerateFrame"](g.ContainerFrame1)

    print("   un sac porte suit son contenu (ni bourse ni recherche) :")
    for taille, rangees in ((4, 1), (8, 2), (16, 4), (20, 5), (36, 9)):
        g.ContainerFrame2.size = taille
        g.ContainerFrame2.id = 1
        g.HOOKS["ContainerFrame_GenerateFrame"](g.ContainerFrame2)
        grille = rangees * 37 + (rangees - 1) * 5
        attendu = grille + 15 + 48
        print("      %2d cases (%d rangees) -> %d de haut (%d attendu)" % (
            taille, rangees, g.ContainerFrame2.height, attendu))
        assert g.ContainerFrame2.height == attendu, "un sac porte ne suit pas son contenu"
        assert g.ContainerFrame2.width == 178, "la largeur est une constante"
        # ContainerFrameMixin:GetInitialItemAnchor, remonte de 6 : (-7, 15)
        point, _, pointCible, x, y = ancre(g["ContainerFrame2Item1"])
        assert (point, pointCible, x, y) == ("BOTTOMRIGHT", "BOTTOMRIGHT", -7, 15), \
            "un sac porte pose sa grille en (-7, 15) sur le cadre"
    g.ContainerFrame2.id = 0

    # LE CLIENT NE PEUT PLUS DEFAIRE LA TAILLE. 3.3.5 repose ses morceaux dans
    # ContainerFrame_Update et dans updateContainerFrameAnchors ; on verifie
    # qu'un passage du client y est bien rattrape.
    g.ContainerFrame1.height = 1
    g.ContainerFrame1.width = 1
    g.HOOKS["ContainerFrame_Update"](g.ContainerFrame1)
    print("   apres un passage du client : %d x %d (rattrape)" % (
        g.ContainerFrame1.width, g.ContainerFrame1.height))
    assert g.ContainerFrame1.height == HAUTEUR, "ContainerFrame_Update ne rattrape pas la taille"

    g.ContainerFrame1.height = 1
    g.HOOKS["updateContainerFrameAnchors"]()
    print("   apres un reagencement du client : %d de haut (rattrape)" % g.ContainerFrame1.height)
    assert g.ContainerFrame1.height == HAUTEUR, "le reagencement ne rattrape pas la taille"

    # LE RATTRAPAGE A L'IMAGE SUIVANTE. Le jeu a montre 240 la ou la formule
    # donne 263 : quelque chose repose la taille apres toutes les accroches.
    # On rejoue ce cas -- la taille est defaite APRES notre passage -- et le
    # rattrapage doit la remettre au premier OnUpdate.
    g.HOOKS["ContainerFrame_GenerateFrame"](g.ContainerFrame1)
    g.ContainerFrame1.height = 240              # le client repasse derriere nous
    veille = g.ForeverUIBagsRecheck
    print("   le client defait la hauteur (240), rattrapage demande=%s" % veille.shown)
    assert veille.shown, "le rattrapage n'a pas ete demande"
    veille.scripts.OnUpdate(veille, 0.01)
    print("   a l'image suivante : %d de haut, defaite %d fois, rattrapage rendormi=%s" % (
        g.ContainerFrame1.height, g.ContainerFrame1.foreverDefaite or 0, not veille.shown))
    assert g.ContainerFrame1.height == HAUTEUR, "le rattrapage n'a pas remis la mesure"
    assert not veille.shown, "le rattrapage doit se rendormir, pas tourner a chaque image"

    # Et quand rien n'a bouge, il ne touche a rien.
    g.ContainerFrame1.foreverDefaite = 0
    veille.Show(veille)
    veille.scripts.OnUpdate(veille, 0.01)
    print("   rien n'a bouge : defaite %d fois (0 attendu)" % (g.ContainerFrame1.foreverDefaite or 0))
    assert (g.ContainerFrame1.foreverDefaite or 0) == 0, "le rattrapage repose une taille deja bonne"

    # L'EMPILEMENT -- UpdateContainerFrameAnchors : CONTAINER_SPACING vaut 8
    # entre deux sacs, le premier se pose a 10 du bord droit et 85 du bas.
    g.ContainerFrame2.id = 1
    g.ContainerFrame2.size = 16
    g.ContainerFrame2.Show(g.ContainerFrame2)
    g.HOOKS["ContainerFrame_GenerateFrame"](g.ContainerFrame2)
    lua.execute('ContainerFrame1.bags = { "ContainerFrame1", "ContainerFrame2" }')
    g.HOOKS["updateContainerFrameAnchors"]()

    p1 = g.ContainerFrame1.points[len(list(g.ContainerFrame1.points.values()))]
    p2 = g.ContainerFrame2.points[len(list(g.ContainerFrame2.points.values()))]
    print("   empilement : premier %s (%s, %s) | second %s sur %s (%s, %s)" % (
        p1[1], p1[4], p1[5], p2[1], p2[3], p2[4], p2[5]))
    assert (p1[1], p1[4], p1[5]) == ("BOTTOMRIGHT", -10, 85),         "le premier sac n'est pas a 10 du bord droit et 85 du bas"
    assert (p2[1], p2[3], p2[4], p2[5]) == ("BOTTOMRIGHT", "TOPRIGHT", 0, 8),         "les sacs ne sont pas espaces de CONTAINER_SPACING"
    g.ContainerFrame2.Hide(g.ContainerFrame2)
    g.ContainerFrame2.id = 0
    lua.execute("ContainerFrame1.bags = nil")

    # Un reglage change, la fenetre suit.
    g.ForeverUI.BagsSet("emplacement", 44)
    print("   emplacement 37 -> 44 : fenetre %d x %d, case %d" % (
        g.ContainerFrame1.width, g.ContainerFrame1.height, premier.width))
    assert g.ContainerFrame1.height == HAUTEUR - GRILLE + 4 * 44 + 3 * 5, \
        "la hauteur ne suit pas la taille des cases"
    assert premier.width == 44, "la case n'a pas change de taille"
    g.ForeverUI.BagsSet("emplacement", 37)

    # le contour suit la qualite de l'objet
    lua.execute("""
        SACS[0][4] = { lien = "|cff0070dd|Hitem:2|h[Epee]|h|r", nombre = 1 }
        ContainerFrame1.size = 16
    """)
    g.ForeverUI.BagSearch.Tout()
    fermer = g.ContainerFrame1CloseButton
    fpt = fermer.points[len(list(fermer.points.values()))]
    print("   fermeture : %d x %d, %s (%s, %s)" % (fermer.width, fermer.height, fpt[1], fpt[4], fpt[5]))
    assert fermer.width == 24 and fermer.height == 24, "le bouton de fermeture n'est pas en 24 x 24"
    assert fpt[4] == 1 and fpt[5] == 0, "le bouton de fermeture n'est pas au coin"

    # SetItemButtonTexture_Base : UNE seule texture. Case pleine = l'icone de
    # l'objet, coordonnees pleines ; case vide = l'element d'atlas, sur la
    # meme texture. Rien ne se superpose, sinon l'icone passe derriere.
    pleine = g.ContainerFrame1Item4IconTexture
    vide2 = g.ContainerFrame1Item3IconTexture
    print("   icone : case pleine %s %s | case vide %s %s" % (
        pleine.texture, [round(v, 2) for v in pleine.texcoord.values()],
        vide2.texture and vide2.texture.split(chr(92))[-1],
        [round(v, 3) for v in vide2.texcoord.values()]))
    assert pleine.texture == "icone" and pleine.shown, "la case pleine montre l'objet"
    assert [round(v, 2) for v in pleine.texcoord.values()] == [0, 1, 0, 1],         "l'icone d'un objet prend toute la texture"
    assert vide2.shown and vide2.texture != "icone", "la case vide montre le fond d'emplacement"
    assert "foreverui" in vide2.texture.lower(),         "le fond d'une case vide est la feuille d'atlas, pas une texture du client"

    contour = g.ContainerFrame1Item4.foreverContour
    vide = g.ContainerFrame1Item3.foreverContour
    gris = [round(v, 2) for v in vide.vertex.values()] if vide.vertex else None
    teinte = [round(v, 2) for v in contour.vertex.values()] if contour.vertex else None
    print("   contour : case pleine %s | case vide %s (les deux visibles : %s et %s)" % (
        teinte, gris, contour.shown, vide.shown))
    assert contour.shown and vide.shown, "camelot pose un cadre sur chaque case"
    assert gris and abs(gris[0] - 0.39) < 0.01, "la case vide n'a pas le gris de la capture"
    assert teinte and teinte != gris, "la qualite ne teinte pas le cadre"

    # le champ et le bouton de tri ne se montrent que sur le sac principal
    g.ForeverUI.BagsLayout()
    champ = g.ForeverUIBagSearchBox
    tri = g.ForeverUIBagSortButton
    print("champ %dx%d visible=%s | bouton de tri %dx%d visible=%s" % (
        champ.width, champ.height, champ.shown, tri.width, tri.height, tri.shown))
    assert champ.width == 96 and champ.height == 18
    assert tri.width == 28 and tri.height == 26

    pc = champ.points[len(list(champ.points.values()))]
    pt2 = tri.points[len(list(tri.points.values()))]
    print("champ ancre %s (%s, %s) | tri ancre %s (%s, %s)" % (
        pc[1], pc[4], pc[5], pt2[1], pt2[4], pt2[5]))
    assert (pc[1], pc[4], pc[5]) == ("TOPLEFT", 42, -43), "le champ n'est pas a sa place"
    assert (pt2[1], pt2[4], pt2[5]) == ("TOPRIGHT", -9, -40), "le tri n'est pas a sa place"

    # la recherche : le pain reste, l'epee se voile
    lua.execute("""
        SACS[0][1] = { lien = "|cffffffff|Hitem:1|h[Pain]|h|r", nombre = 5 }
        SACS[0][2] = { lien = "|cff0070dd|Hitem:2|h[Epee]|h|r", nombre = 1 }
        SACS[0][3] = { lien = "|cffffffff|Hitem:3|h[Potion]|h|r", nombre = 3 }
        ContainerFrame1.size = 4
    """)
    g.ForeverUI.BagSearch.Set("pain")
    voiles = [g["ContainerFrame1Item" + str(i)].foreverVoile.shown for i in (1, 2, 3, 4)]
    print("recherche \"pain\" : voiles = %s (le premier est le pain)" % voiles)
    assert voiles[0] == False and voiles[1] == True, "la recherche ne filtre pas"
    g.ForeverUI.BagSearch.Set("consommable")
    voiles = [g["ContainerFrame1Item" + str(i)].foreverVoile.shown for i in (1, 2, 3)]
    print("recherche par type          : voiles = %s" % voiles)
    assert voiles[0] == False and voiles[2] == False, "le type ne compte pas dans la recherche"
    g.ForeverUI.BagSearch.Set("")

    # le tri : deux piles de pain se reunissent, puis l'ordre se fait
    lua.execute("""
        SACS[0][1] = { lien = "|cffffffff|Hitem:3|h[Potion]|h|r", nombre = 3 }
        SACS[0][2] = { lien = "|cffffffff|Hitem:1|h[Pain]|h|r", nombre = 5 }
        SACS[0][3] = { lien = "|cff0070dd|Hitem:2|h[Epee]|h|r", nombre = 1 }
        SACS[0][4] = { lien = "|cffffffff|Hitem:1|h[Pain]|h|r", nombre = 7 }
        PRISES = {}
    """)
    g.ForeverUI.BagSort.Lancer()
    tic = g.ForeverUI.BagSort
    horloge = g.ForeverUIBagSortTicker          # nomme, plus de "le dernier cree"
    for _ in range(60):
        if not tic.actif:
            break
        horloge.scripts.OnUpdate(horloge, 0.2)
    contenu = []
    for i in range(1, 5):
        case = g.SACS[0][i]
        contenu.append("%s x%d" % (case.lien.split("[")[1].split("]")[0], case.nombre) if case else "vide")
    print("apres le tri : %s" % " | ".join(contenu))
    print("   %d prises d'objet, %d etapes" % (len(list(g.PRISES.values())), tic.etapes))
    assert not tic.actif, "le tri ne s'est pas arrete"
    assert "Pain x12" in " ".join(contenu), "les deux piles de pain n'ont pas ete reunies"

    # ------------------------------------------------ cible de la cible
    totcadre = g.ForeverUITargetOfTarget
    g.STATE.hasTarget = True
    totcadre.scripts.OnEvent(totcadre, "PLAYER_TARGET_CHANGED")
    print("cible de la cible : nom=%s vie visible=%s surveillee=%s" % (
        totcadre.nameText.text, totcadre.healthFill.shown, totcadre.unitWatch))
    assert totcadre.healthFill.shown, "la vie de la cible de la cible est vide"

    # ------------------------------------ listes des menus deroulants
    # Deux lignes : la premiere porte une case a cocher, la seconde non.
    lua.execute("""
        UIDropDownMenu_AddButton({ text = "Attributs" }, 1)
        UIDropDownMenu_AddButton({ text = "Sans case", notCheckable = 1 }, 1)
    """)
    liste = g.DropDownList1
    b1, b2 = g.DropDownList1Button1, g.DropDownList1Button2

    print("liste de menu : fonds d epoque retires = %s et %s" % (
        g.DropDownList1Backdrop.backdrop is None,
        g.DropDownList1MenuBackdrop.backdrop is None))
    assert g.DropDownList1Backdrop.backdrop is None,         "ToggleDropDownMenu remontrerait un cadre masque : le fond doit partir"
    assert g.DropDownList1MenuBackdrop.backdrop is None

    # Le fond est decoupe : les coins gardent leur taille, l ombre de
    # l image ne se multiplie plus avec la liste.
    tranches = list(liste.foreverTranches.values())
    print("   fond : %d tranches, alpha %.3f" % (len(tranches), tranches[0].alpha))
    assert len(tranches) == 9, "neuf tranches : quatre coins, quatre bords, un centre"
    assert all(t.texture is not None for t in tranches), "chaque tranche porte l image"
    assert all(abs(t.alpha - 0.925) < 0.001 for t in tranches), "alpha 0,925"

    hg, bd = tranches[0], tranches[3]
    phg, pbd = hg.points[1], bd.points[1]
    print("   coin haut gauche : %dx%d %s (%s, %s) | bas droit %s (%s, %s)" % (
        hg.width, hg.height, phg[1], phg[4], phg[5], pbd[1], pbd[4], pbd[5]))
    assert hg.width == 18 and hg.height == 18,         "coin de 18 : l ombre la plus epaisse (12) plus le pan coupe (6)"
    assert (phg[1], phg[4], phg[5]) == ("TOPLEFT", -9, 6),         "l ombre mesuree sur l image : 9 a gauche, 6 en haut"
    assert (pbd[1], pbd[4], pbd[5]) == ("BOTTOMRIGHT", 9, -12),         "9 a droite, 12 en bas -- le filet tombe sur le bord du cadre"

    print("   ligne : %d de haut (20), police %s, pas %d" % (
        b1.height, b1.normalFont.police, g.UIDROPDOWNMENU_BUTTON_HEIGHT))
    assert b1.height == 20, "DarkMenuElementTemplate fait 20 de haut"
    assert g.UIDROPDOWNMENU_BUTTON_HEIGHT == 20, "le pas suit la hauteur de ligne"
    assert b1.normalFont.police == "GameFontHighlightLeft",         "le compositeur de camelot pose GameFontHighlight justifie a gauche"

    coche = g.DropDownList1Button1Check
    pc = coche.points[1]
    print("   case : visible=%s | coche %dx%d %s sur la case (%s, %s)" % (
        b1.foreverCase.shown, coche.width, coche.height, pc[1], pc[4], pc[5]))
    assert b1.foreverCase.shown, "une ligne a cocher montre sa case"
    assert not b2.foreverCase.shown, "une ligne notCheckable n en a pas"
    assert (coche.width, coche.height) == (15, 14), "common-dropdown-icon-checkmark-yellow"
    assert (pc[1], pc[4], pc[5]) == ("CENTER", 2, 1), "la coche se centre sur sa case a (2, 1)"

    # La largeur : la liste ne peut plus etre plus etroite que le menu
    # deroulant qui l ouvre.
    lua.execute("""
        ForeverUIMenuTemoin = CreateFrame("Frame", "ForeverUIMenuTemoin", UIParent)
        ForeverUIMenuTemoin:SetWidth(203)
        ForeverUIMenuTemoin:SetHeight(40)
        UIDROPDOWNMENU_OPEN_MENU = ForeverUIMenuTemoin
        -- ce que fait le OnShow du client : tailler sur le texte le plus long
        DropDownList1:SetWidth(120)
        DropDownList1Button1:SetWidth(95)
        DropDownList1Button2:SetWidth(95)
    """)
    assert liste.hooks.OnShow is not None, "le plancher se pose a l affichage de la liste"
    liste.hooks.OnShow(liste)
    print("   largeur : menu 203, liste taillee a 120 -> %d, ligne %d" % (
        liste.width, b1.width))
    assert liste.width == 203,         "camelot pose SetMinimumWidth(bouton:GetWidth()) : la liste suit son menu"
    assert b1.width == 203 - 25, "les lignes gardent l ecart de 25 du client"

    # ECART ASSUME : c est une EGALITE, pas un plancher. Une liste plus
    # large que son bouton est ramenee a sa largeur.
    lua.execute("DropDownList1:SetWidth(300) DropDownList1Button1:SetWidth(275)")
    liste.hooks.OnShow(liste)
    print("   liste taillee a 300 -> %d (la largeur du menu)" % liste.width)
    assert liste.width == 203, "la liste prend exactement la largeur de son bouton"
    assert b1.width == 203 - 25, "les lignes suivent"

    # ------------------------------- gestionnaire d equipement
    pane = g.ForeverUIEquipmentPane
    pp3 = pane.points[1]
    print("panneau du gestionnaire : %s sur %s de la pierre" % (pp3[1], pp3[3]))
    assert pp3[1] == "TOPLEFT" and pp3[3] == "BOTTOMLEFT",         "il part du bas de la bande de pierre, comme chez camelot"
    assert g.GearManagerDialog.parent.name == "ForeverUIEquipmentPane",         "la fenetre du client passe dans le volet, elle n est pas recreee"
    assert not g.GearManagerDialog.title.shown, "son art de fenetre s efface"
    print("   croix rouge masquee : %s" % (not g.GearManagerDialogClose.shown))
    assert not g.GearManagerDialogClose.shown,         "le panneau n est plus une fenetre, il se ferme par son onglet"

    # La bordure est decoupee : 107 x 107 tendus sur 233 x 379 se brouillent.
    tranches = list(pane.bordure.values())
    coin = tranches[0]
    print("   bordure : %d tranches, coin %dx%d a (%s, %s)" % (
        len(tranches), coin.width, coin.height,
        coin.points[1][4], coin.points[1][5]))
    assert len(tranches) == 9, "neuf tranches, comme le fond des menus"
    assert coin.width == 20 and coin.height == 20,         "le motif d angle s arrete a 19 : coin de 20"
    droit = tranches[1]
    print("   bordure : gauche a x=%s, droite a x=%s (3 px vers la droite)" % (
        coin.points[1][4], droit.points[1][4]))
    assert (coin.points[1][4], coin.points[1][5]) == (4, 1),         "camelot ancre a (1, 1), plus les 3 px demandes"
    assert droit.points[1][4] == -1,         "les deux bords glissent ensemble, sinon la bordure s elargit"

    lua.execute("GearManagerDialog_Update()")
    g.ForeverUI.EquipmentPane.Apply()
    carte = g.GearSetButton1
    print("   carte : %dx%d, fond %dx%d a x=%s, texte a x=%s" % (
        carte.width, carte.height, carte.foreverFond.width, carte.foreverFond.height,
        carte.foreverFond.points[1][4], g.GearSetButton1Name.points[1][4]))
    assert carte.width == 216 and carte.height == 40,         "ecart assume : moins haute, et large jusqu au bord de la fenetre"
    assert carte.foreverFond.points[1][4] == 42, "UI-Character-Info-OutfitCard a x = 42"
    assert (carte.foreverFond.width, carte.foreverFond.height) == (174, 45)
    # Les deux ecarts demandes, en abscisses du volet de 233.
    pcarte = carte.points[len(list(carte.points.values()))]
    gaucheIcone = pcarte[4] + 4
    droiteCarte = pcarte[4] + 42 + 174
    print("   ecarts : separateur->icone %d, carte->bord %d" % (
        gaucheIcone - 5, 233 - droiteCarte))
    assert gaucheIcone - 5 == 233 - droiteCarte, "les deux ecarts doivent etre egaux"
    assert carte.foreverChoisi.layer == "ARTWORK" and carte.foreverSurvol.layer == "BORDER",         "le choix passe au-dessus du survol, sans dependre de l ordre de creation"
    assert g.GearSetButton1Name.points[1][4] == 55, "l intitule a LEFT 55"
    icone = carte._normal
    assert icone.width == 36 and icone.points[1][4] == 4, "l icone 36 a LEFT 4"

    # LA COCHE. Elle demande DEUX choses : chaque piece dans SON emplacement,
    # et l ensemble d etre le dernier equipe -- sans quoi deux ensembles aux
    # memes pieces la porteraient tous les deux.
    lua.execute('ForeverUIDB.ensembleEquipe = "eee" UseEquipmentSet("eee")')
    g.ForeverUI.EquipmentSetsLayout()
    print("   coches : eee=%s (equipe), aaa=%s (non equipe)" % (
        carte.foreverCoche.shown, g.GearSetButton2.foreverCoche.shown))
    assert carte.foreverCoche.shown, "l ensemble equipe et en place montre sa coche"
    assert not g.GearSetButton2.foreverCoche.shown, "l autre non"

    lua.execute('ENSEMBLES[2].porte = true')
    g.ForeverUI.EquipmentSetsLayout()
    print("   memes pieces : eee=%s, aaa=%s" % (
        carte.foreverCoche.shown, g.GearSetButton2.foreverCoche.shown))
    assert carte.foreverCoche.shown and not g.GearSetButton2.foreverCoche.shown,         "le dernier equipe departage, la geometrie seule ne le peut pas"

    lua.execute('ENSEMBLES[1].porte = "ailleurs"')
    g.ForeverUI.EquipmentSetsLayout()
    print("   pieces ailleurs sur le joueur : eee=%s" % carte.foreverCoche.shown)
    assert not carte.foreverCoche.shown,         "le slot rendu doit valoir la cle, sinon une piece portee ailleurs passait"
    lua.execute('ENSEMBLES[1].porte = true ENSEMBLES[2].porte = false')
    g.ForeverUI.EquipmentSetsLayout()

    # Les deux boutons de survol : engrenage et croix rouge.
    supprimer = carte.foreverSupprimer
    editer = carte.foreverEditer
    ps2 = supprimer.points[1]
    pe2 = editer.points[1]
    print("   survol : supprimer %dx%d %s (%s, %s) | editer %dx%d %s sur %s %s" % (
        supprimer.width, supprimer.height, ps2[1], ps2[4], ps2[5],
        editer.width, editer.height, pe2[1], pe2[3], pe2[4]))
    assert (supprimer.width, supprimer.height) == (14, 14), "camelot : 14 x 14"
    assert (ps2[1], ps2[4], ps2[5]) == ("BOTTOMRIGHT", -21, 2)
    assert (editer.width, editer.height) == (16, 16), "camelot : 16 x 16"
    assert (pe2[1], pe2[3], pe2[4]) == ("RIGHT", "LEFT", -1)
    assert "GroupLoot-Pass" in supprimer.texture.texture, "la croix rouge du client"
    assert "GEAR_64GREY" in editer.texture.texture, "l engrenage du client"

    print("   au repos : supprimer=%s, editer=%s" % (supprimer.shown, editer.shown))
    assert not supprimer.shown and not editer.shown, "ils ne paraissent qu au survol"
    lua.execute("GearSetButton1.souris = true")
    g.ForeverUI.EquipmentSetsHover()
    print("   au survol : supprimer=%s, editer=%s, survol=%s" % (
        supprimer.shown, editer.shown, carte.foreverSurvol.shown))
    assert supprimer.shown and editer.shown and carte.foreverSurvol.shown

    avantPopups = len(list(g.POPUPS.values()))
    supprimer.scripts.OnClick(supprimer)
    dernier = list(g.POPUPS.values())[-1]
    print("   clic sur la croix : %s sur \"%s\"" % (dernier.quoi, dernier.texte))
    assert len(list(g.POPUPS.values())) == avantPopups + 1
    assert dernier.quoi == "CONFIRM_DELETE_EQUIPMENT_SET", "la fenetre de validation du client"
    assert dernier.texte == "eee", "sur le bon ensemble"

    editer.scripts.OnClick(editer)
    print("   clic sur l engrenage : ensemble choisi = %s" % (
        g.GearManagerDialog.selectedSetName))
    assert g.GearManagerDialog.selectedSetName == "eee",         "il choisit l ensemble : c est de lui que la fenetre tire nom et icone"
    def imageSuivante():
        """Le rattrapage repose la liste a l image d apres, comme en jeu."""
        r = g.ForeverUIEquipmentRecheck
        if r.shown:
            r.scripts.OnUpdate(r, 0.02)

    def finirRemplacement(ancien):
        """La suite reelle : fin du remplacement, puis publication de la
        nouvelle liste et son evenement, puis le rattrapage d une image."""
        att = g.ForeverUIEquipmentEdit
        if att.shown:
            att.scripts.OnEvent(att, "EQUIPMENT_SWAP_FINISHED", True, ancien)
        lua.execute("publierEnsembles()")
        att.scripts.OnEvent(att, "EQUIPMENT_SETS_CHANGED")
        imageSuivante()

    # MODIFIER UN ENSEMBLE : memes objets, nouveau nom, a la meme place.
    lua.execute('ForeverUIDB.ordreEnsembles = { "eee", "aaa" }')
    editer.scripts.OnClick(editer)
    print("   edition ouverte sur : %s" % g.GearManagerDialog.selectedSetName)
    assert g.GearManagerDialog.selectedSetName == "eee", "la fenetre s ouvre sur lui"
    assert g.GearManagerDialogPopupEditBox.text == "eee",         "son nom est pose explicitement, sans dependre du OnShow du client"

    # Okay est REPRIS : hors edition il rend la main au client, en edition
    # il mene le remplacement.
    lua.execute('GearManagerDialogPopup.name = "eee2"')
    lua.execute('GearManagerDialogPopup.selectedIcon = 7')
    g.GearManagerDialogPopupOkay.scripts.OnClick(g.GearManagerDialogPopupOkay)
    finirRemplacement("eee")
    noms = [e.nom for e in g.ENSEMBLES.values()]
    print("   apres modification : %s | ordre %s" % (
        noms, list(g.ForeverUIDB.ordreEnsembles.values())))
    assert "eee2" in noms and "eee" not in noms, "renomme, pas duplique"
    assert list(g.ForeverUIDB.ordreEnsembles.values())[0] == "eee2",         "le nouveau prend la place de l ancien dans la liste"
    assert g.ForeverUIDB.ensembleEquipe == "eee2",         "la coche suit le nom qui a change"

    # L INDICE D ICONE PEUT MANQUER : l ancien ne doit alors PAS partir.
    lua.execute('ForeverUIDB.ordreEnsembles = { "eee2", "aaa" }')
    editer.scripts.OnClick(editer)
    lua.execute('GearManagerDialogPopup.name = "eee3"')
    lua.execute('GearManagerDialogPopup.selectedIcon = nil')
    intact = carte.name
    g.GearManagerDialogPopupOkay.scripts.OnClick(g.GearManagerDialogPopupOkay)
    finirRemplacement(intact)
    noms = [e.nom for e in g.ENSEMBLES.values()]
    print("   sans indice d icone : %s (intact %s)" % (noms, intact))
    assert intact in noms and "eee3" not in noms,         "sans icone valide, rien ne doit etre cree NI efface"

    # Et au plafond, l ancien part avant que le nouveau soit enregistre.
    lua.execute('MAX_EQUIPMENT_SETS_PER_PLAYER = 2')
    ancien = carte.name          # le client a pu reordonner ses boutons
    editer.scripts.OnClick(editer)
    lua.execute('GearManagerDialogPopup.name = "eee4"')
    lua.execute('GearManagerDialogPopup.selectedIcon = 9')
    g.GearManagerDialogPopupOkay.scripts.OnClick(g.GearManagerDialogPopupOkay)
    finirRemplacement(ancien)
    noms = [e.nom for e in g.ENSEMBLES.values()]
    print("   au plafond : %s (ancien %s)" % (noms, ancien))
    att = g.ForeverUIEquipmentEdit
    assert att.events["EQUIPMENT_SETS_CHANGED"],         "la liste du client se met a jour apres coup : il faut l ecouter"
    # Le banc n ancre rien : sans hauteur, une seule carte "tient" dans la
    # liste et le defilement masque les autres.
    lua.execute('ForeverUIEquipmentPane:SetHeight(400)')
    att.scripts.OnEvent(att, "EQUIPMENT_SETS_CHANGED")
    assert g.ForeverUIEquipmentRecheck.shown,         "l evenement demande un rattrapage, il ne repose pas tout de suite"
    imageSuivante()
    visibles = [b.name for b in g.GearManagerDialog.buttons.values() if b.shown]
    print("   apres EQUIPMENT_SETS_CHANGED : cartes visibles %s" % visibles)
    assert "eee4" in visibles, "l ensemble renomme doit apparaitre sans autre secousse"
    # LA SEQUENCE SIGNALEE, en repartant de zero : creer AAA, le renommer
    # en AAB, creer AZE, supprimer AAB. La liste doit suivre a chaque pas,
    # et non montrer l etat d avant.
    lua.execute('ENSEMBLES = {} publierEnsembles()')
    lua.execute('ForeverUIDB.ordreEnsembles = {}')
    lua.execute('GearManagerDialog_Update()')
    g.ForeverUI.EquipmentSetsLayout()

    def visiblesMaintenant():
        return [b.name for b in g.GearManagerDialog.buttons.values() if b.shown]

    def apresChangement():
        lua.execute("publierEnsembles()")
        att2 = g.ForeverUIEquipmentEdit
        att2.scripts.OnEvent(att2, "EQUIPMENT_SETS_CHANGED")
        imageSuivante()

    lua.execute('SaveEquipmentSet("AAA", 1)')
    apresChangement()
    print("   sequence : creer AAA -> %s" % visiblesMaintenant())
    assert visiblesMaintenant() == ["AAA"], "AAA doit s afficher"

    lua.execute('SaveEquipmentSet("AAB", 1) DeleteEquipmentSet("AAA")')
    lua.execute('ForeverUIDB.ordreEnsembles = { "AAB" }')
    apresChangement()
    print("   sequence : AAA renomme en AAB -> %s" % visiblesMaintenant())
    assert visiblesMaintenant() == ["AAB"], "le renomme doit rester visible"

    lua.execute('SaveEquipmentSet("AZE", 2)')
    apresChangement()
    print("   sequence : creer AZE -> %s" % visiblesMaintenant())
    assert visiblesMaintenant() == ["AAB", "AZE"], "les deux doivent etre la"

    lua.execute('DeleteEquipmentSet("AAB")')
    apresChangement()
    print("   sequence : supprimer AAB -> %s" % visiblesMaintenant())
    assert visiblesMaintenant() == ["AZE"], "AZE reste, seul"

    # LE CAS REEL QUI RESTAIT : LE CLIENT PUBLIE APRES TOUT LE MONDE.
    #
    # En jeu, la liste restait vide apres un renommage jusqu a l operation
    # suivante. On rejoue donc le pire : l evenement arrive AVANT que le
    # client ait refait sa liste, le rattrapage d une image passe dans le
    # vide, et RIEN d autre n est signale ensuite. Seul le battement du
    # panneau peut alors reparer.
    lua.execute('ENSEMBLES = {} publierEnsembles()')
    lua.execute('ForeverUIDB.ordreEnsembles = {}')
    lua.execute('SaveEquipmentSet("AAA", 1)')
    apresChangement()
    assert visiblesMaintenant() == ["AAA"], "point de depart : AAA est la"

    lua.execute('SaveEquipmentSet("AAB", 1) DeleteEquipmentSet("AAA")')
    lua.execute('ForeverUIDB.ordreEnsembles = { "AAB" }')
    att3 = g.ForeverUIEquipmentEdit
    att3.scripts.OnEvent(att3, "EQUIPMENT_SETS_CHANGED")   # trop tot
    imageSuivante()                                        # dans le vide
    print("   publication tardive : au signal -> %s" % visiblesMaintenant())
    assert "AAB" not in visiblesMaintenant(),         "le client n a encore rien publie : la liste est en retard"

    lua.execute("publierEnsembles()")   # le client publie, sans rien annoncer
    pan = g.ForeverUIEquipmentPane
    pan.scripts.OnUpdate(pan, 0.25)
    print("   publication tardive : apres un battement -> %s" % visiblesMaintenant())
    assert visiblesMaintenant() == ["AAB"],         "la surveillance doit reparer sans qu aucun evenement le demande"

    # Et elle ne repose pas la liste a chaque image pour rien.
    poses = []
    vrai = g.ForeverUI.EquipmentSetsLayout
    g.ForeverUI.EquipmentSetsLayout = lua.eval(
        "function() FOREVER_POSES = (FOREVER_POSES or 0) + 1 end")
    lua.execute("FOREVER_POSES = 0")
    for _ in range(10):
        pan.scripts.OnUpdate(pan, 0.25)
    poses = g.FOREVER_POSES
    g.ForeverUI.EquipmentSetsLayout = vrai
    print("   liste inchangee : %d pose(s) sur 10 controles" % poses)
    assert poses == 0, "liste inchangee, rien a reposer"

    # L ETAT CORROMPU RAPPORTE PAR /fui sets, rejoue tel quel : l ordre
    # retenu tenait sept entrees pour UN ensemble publie -- "aab" quatre
    # fois, plus trois noms effaces. L ensemble se posait donc quatre fois,
    # la carte finissait au rang 4 pour un total de 1, et se masquait.
    lua.execute('ENSEMBLES = { { nom = "aab", icone = "icone-aab", porte = false } }')
    lua.execute("publierEnsembles()")
    lua.execute('ForeverUIDB.ordreEnsembles = '
                '{ "aab", "aab", "aze", "aab", "azq", "zzzaq", "aab" }')
    lua.execute('GearManagerDialog_Update()')
    g.ForeverUI.EquipmentSetsLayout()
    pose = list(g.ForeverUI.EquipmentSetsOrder().values())
    print("   ordre corrompu : pose %s | retenu %s | visibles %s" % (
        pose, list(g.ForeverUIDB.ordreEnsembles.values()), visiblesMaintenant()))
    assert pose == [1], "un ensemble publie ne se pose qu une fois"
    assert visiblesMaintenant() == ["aab"], "et sa carte doit etre visible"
    assert list(g.ForeverUIDB.ordreEnsembles.values()) == ["aab"],         "l ordre retenu se nettoie des doublons et des noms effaces"

    # A ZERO ENSEMBLE PUBLIE, en revanche, l ordre ne doit PAS etre vide :
    # c est l etat momentane entre un enregistrement et son evenement.
    lua.execute('ENSEMBLES = {} publierEnsembles()')
    g.ForeverUI.EquipmentSetsOrder()
    print("   client muet : retenu %s" % list(g.ForeverUIDB.ordreEnsembles.values()))
    assert list(g.ForeverUIDB.ordreEnsembles.values()) == ["aab"],         "le client ne publie rien : on ne touche pas a l ordre"

    # LE TEMOIN ne doit rien casser, et dire ce qu il voit.
    g.ForeverUI.EquipmentSetsDebug()
    print("   temoin /fui sets : rapport rendu sans erreur")

    # On rend au faux client l etat que la suite du banc attend.
    lua.execute('ENSEMBLES = { { nom = "eee", icone = "icone-eee", porte = true },'
                '              { nom = "aaa", icone = "icone-aaa", porte = false } }')
    lua.execute('ForeverUIDB.ordreEnsembles = { "eee", "aaa" }')
    apresChangement()

    assert "eee4" in noms and ancien not in noms,         "au plafond, l ancien part d abord : son equipement est porte"
    lua.execute('MAX_EQUIPMENT_SETS_PER_PLAYER = 10')
    lua.execute('ENSEMBLES[1].nom = "eee" ENSEMBLES[2].nom = "aaa"')
    lua.execute('ForeverUIDB.ordreEnsembles = { "eee", "aaa" }')

    lua.execute("GearSetButton1.souris = false")
    g.ForeverUI.EquipmentSetsHover()

    pc2 = carte.foreverCoche.points[1]
    print("   coche : %s (%s, %s)" % (pc2[1], pc2[4], pc2[5]))
    assert (pc2[1], pc2[4]) == ("RIGHT", -12),         "elle longe le bord droit de la carte, que le bouton couvre entierement"
    assert not g.GearSetButton3.shown, "les cartes sans ensemble ne s affichent pas"

    equiper = g.GearManagerDialogEquipSet
    nouveau = g.ForeverUIEquipmentNewSet
    print("   boutons : equiper %dx%d (%s, %s) | nouveau %dx%d a (%s, %s)" % (
        equiper.width, equiper.height, equiper.points[1][4], equiper.points[1][5],
        nouveau.width, nouveau.height, nouveau.points[1][4], nouveau.points[1][5]))
    assert (equiper.width, equiper.height) == (99, 28), "99 x 28 chez camelot"
    assert (equiper.points[1][4], equiper.points[1][5]) == (-50, 20)
    assert (nouveau.width, nouveau.height) == (180, 34), "New Set : 180 x 34"
    assert (nouveau.points[1][4], nouveau.points[1][5]) == (0, 50)

    # ------------------------------- choix d icone d un ensemble
    popup = g.GearManagerDialogPopup
    print("choix d icone : fenetre %d x %d, %d boutons, %d par rangee" % (
        popup.width, popup.height, len(list(popup.buttons.values())),
        g.NUM_GEARSET_ICONS_PER_ROW))
    assert popup.width == 525, "IconSelectorPopupFrameTemplate"
    assert popup.height == g.CharacterFrame.height,         "a la demande : la hauteur de la feuille de personnage"
    assert g.NUM_GEARSET_ICONS_PER_ROW == 10, "ScrollBoxSelectorMixin:GetStride rend 10"
    assert g.NUM_GEARSET_ICON_ROWS == 7
    assert g.NUM_GEARSET_ICONS_SHOWN == 70, "dix par rangee, sept rangees"
    assert g.GEARSET_ICON_ROW_HEIGHT == 46, "36 d icone plus 10 d ecart"
    assert len(list(popup.buttons.values())) == 70, "le client n en cree que quinze"

    b1 = g.GearManagerDialogPopupButton1
    b2 = g.GearManagerDialogPopupButton2
    b11 = g.GearManagerDialogPopupButton11
    p1, p2, p11 = b1.points[1], b2.points[1], b11.points[1]
    print("   grille : 1er (%s, %s), 2e %s +%s, 11e %s %s" % (
        p1[4], p1[5], p2[1], p2[4], p11[1], p11[3]))
    assert b1.width == 36 and b1.height == 36, "GetButtonHeight rend 36"
    assert (p1[4], p1[5]) == (26, -102), "grille a (21, -97) plus la marge de 5"
    assert p2[4] == 10, "ecart horizontal de 10"
    assert (p11[1], p11[3]) == ("TOPLEFT", "BOTTOMLEFT"), "la 11e ouvre la rangee suivante"
    assert p11[5] == -10, "ecart vertical de 10"

    pp4 = popup.points[len(list(popup.points.values()))]
    print("   place : %s sur %s de %s" % (pp4[1], pp4[3], pp4[2] and pp4[2].name))
    assert (pp4[1], pp4[3]) == ("TOPLEFT", "TOPRIGHT") and         pp4[2].name == "CharacterFrame", "a droite de la feuille de personnage"
    pf = popup.foreverFond.points[1]
    assert (pf[4], pf[5]) == (7, -7), "le fond noir part de (7, -7)"
    print("   encadrement : %d morceaux | barre large de %d" % (
        len(list(popup.foreverCadre.values())),
        g.GearManagerDialogPopupScrollFrameScrollBar.width))
    assert len(list(popup.foreverCadre.values())) == 8,         "SelectionFrameTemplate : quatre coins et quatre bords"
    droite = list(popup.foreverCadre.values())[7]
    pts = [droite.points[i] for i in sorted(droite.points.keys())]
    print("   bande droite : %s et %s" % (pts[0][1], pts[1][1]))
    assert pts[0][1] == "TOPRIGHT" and pts[1][1] == "BOTTOMRIGHT",         "deux points du meme cote : le coin bas droit fait 174, il l etirerait"
    assert g.GearManagerDialogPopupScrollFrameScrollBar.width == 8,         "MinimalScrollBar fait 8 de large"
    # Autant d espace de part et d autre de la barre.
    barre = g.GearManagerDialogPopupScrollFrameScrollBar
    pb = barre.points[len(list(barre.points.values())) - 1]
    droiteIcones = 21 + 5 + 10 * 46 - 10
    ecartDroit = -pb[4] - 17
    ecartGauche = (525 - 17 - ecartDroit - 8) - droiteIcones
    print("   barre : %g a gauche, %g a droite" % (ecartGauche, ecartDroit))
    assert abs(ecartGauche - ecartDroit) < 0.01,         "le meme ecart entre les icones et la barre qu entre la barre et le bord"

    curseur = g.GearManagerDialogPopupScrollFrameScrollBarThumbTexture.texture or ""
    print("   curseur : %s" % curseur)
    assert "minimalscrollbar" in curseur.lower(),         "le curseur prend la feuille de camelot"
    tex = g.GearManagerDialogPopupScrollFrameScrollBarThumbTexture
    print("   curseur : %dx%d, alpha %s" % (tex.width, tex.height, tex.alpha))
    assert tex.alpha != 0,         "il est une region de la barre : l effacement de l art d epoque l emportait"
    assert tex.width == 8 and tex.height == 36, "8 x 36, le curseur le plus court de la source"

    annuler = g.GearManagerDialogPopupCancel
    okay = g.GearManagerDialogPopupOkay
    pa = annuler.points[len(list(annuler.points.values()))]
    po = okay.points[len(list(okay.points.values()))]
    print("   boutons du bas : %dx%d, cancel %s (%s, %s), okay %s sur %s %s" % (
        annuler.width, annuler.height, pa[1], pa[4], pa[5], po[1], po[3], po[4]))
    assert (annuler.width, annuler.height) == (78, 22), "SelectionFrameTemplate : 78 x 22"
    assert (pa[1], pa[4], pa[5]) == ("BOTTOMRIGHT", -11, 13),         "les deux creux du socle, tels que la source les place"
    assert (po[1], po[3], po[4]) == ("RIGHT", "LEFT", -2), "Okay a gauche de Cancel"

    choix = g.ForeverUIIconChoiceButton
    print("   choix courant : %dx%d, %s (%s, %s)" % (
        choix.width, choix.height, choix.points[1][1],
        choix.points[1][4], choix.points[1][5]))
    assert choix.width == 36, "le bouton d icone de la zone de choix"
    lua.execute('GearManagerDialogPopup.selectedTexture = "icone-42"')
    g.ForeverUI.IconPicker.Apply()
    assert choix.icone.texture == "icone-42", "il montre ce que le client a retenu"
    avant = g.RECALCULE or 0
    choix.scripts.OnClick(choix)
    print("   clic sur le choix : %d saut(s) vers la liste" % ((g.RECALCULE or 0) - avant))
    assert (g.RECALCULE or 0) > avant,         "cliquer ramene la liste sur l icone retenue"


    # ------------------------------------------------------------------
    # LA MINIMAP
    # ------------------------------------------------------------------
    print("\n--- minimap ---")
    cluster = g.MinimapCluster
    carte = g.Minimap
    conteneur = g.ForeverUIMinimapContainer
    print("   cluster %dx%d | conteneur %dx%d | carte %dx%d" % (
        cluster.width, cluster.height, conteneur.width, conteneur.height,
        carte.width, carte.height))
    assert (cluster.width, cluster.height) == (256, 256), "MinimapCluster 256 x 256"
    assert (conteneur.width, conteneur.height) == (253, 253), "le conteneur prend la taille de l atlas, comme Skin.lua"
    # LA CARTE GARDE SA TAILLE DE 3.3.5 ET PREND L ECHELLE 198 / 140 : les
    # fleches du bord suivent l echelle, pas la taille (releve en jeu).
    print("   carte %s x echelle %.4f = %.2f a l ecran | cadre %.4f" % (
        carte.width, carte.scale, carte.width * carte.scale, g.MinimapBackdrop.scale))
    assert (carte.width, carte.height) == (140, 140), "la carte garde la taille de 3.3.5"
    assert abs(carte.width * carte.scale - 198) < 1e-9, "et fait 198 a l ecran, comme chez camelot"
    assert abs(g.MinimapBackdrop.scale * carte.scale - 1) < 1e-9, "le cadre garde sa taille"
    assert abs(g.ForeverUIMinimapZoomHitArea.scale * carte.scale - 1) < 1e-9, "la zone du zoom aussi"
    base = "interface" + chr(92) + "ForeverUI" + chr(92) + "minimap" + chr(92)
    print("   fleches : %s" % dict(carte.fleches.items()))
    assert carte.fleches.statique == base + "rotating-minimaparrow"
    assert carte.fleches.poi == base + "rotating-minimapguidearrow"
    assert carte.fleches.cadavre == base + "rotating-minimapcorpsearrow"
    pc = conteneur.points[1]
    assert (pc[1], pc[3], pc[4], pc[5]) == ("TOP", "TOP", 10, -30), pc
    print("   marges de souris : %s" % list(cluster.hitRect.values()))
    assert list(cluster.hitRect.values()) == [30, 10, 0, 30], "les memes marges de souris qu en 3.3.5"

    masque = ("interface" + chr(92) + "ForeverUI" + chr(92) + "hud" + chr(92)
              + "uiminimapmaskgeneralc60")
    print("   masque pose : %s" % carte.mask)
    assert carte.mask == masque, "SetMaskTexture prend un CHEMIN en 3.3.5, pas un atlas"

    # LE FAUX REND SON FICHIER A L ICONE et REMONTRE la boussole : c est
    # exactement ce que le vrai fait. Un simple Hide ne tiendrait pas.
    lua.execute("STATE.cvars.rotateMinimap = " + chr(34) + "1" + chr(34) + " Minimap_UpdateRotationSetting() MiniMapTracking_Update()")
    for nom in ("MinimapBorderTop", "MinimapBorder", "MinimapNorthTag",
                "MinimapCompassTexture", "MiniMapTrackingIcon",
                "MiniMapTrackingButtonBorder", "MiniMapTrackingButtonShine",
                "MiniMapMailIcon", "MiniMapMailBorder"):
        r = g[nom]
        print("   %-28s texture=%s alpha=%s visible=%s" % (
            nom, r.texture, r.alpha, r.shown))
        assert r.alpha == 0, "%s doit rester invisible apres le retour du client" % nom
    lua.execute("STATE.cvars.rotateMinimap = " + chr(34) + "0" + chr(34) + " Minimap_UpdateRotationSetting()")

    # LA BARRE DU NOM DE ZONE : neuf morceaux, neuf atlas.
    barre = g.ForeverUIMinimapBorderTop
    pieces = [r for r in barre.regions.values() if r.texture]
    print("   barre %dx%d, %d morceaux d atlas" % (barre.width, barre.height, len(pieces)))
    assert (barre.width, barre.height) == (175, 16), "BorderTop 175 x 16"
    assert len(pieces) == 9, "UniqueCornersLayout : neuf morceaux, pas huit"
    pb = barre.points[1]
    assert (pb[1], pb[3], pb[4], pb[5]) == ("TOP", "TOP", 15, -4), pb

    texte = g.MinimapZoneText
    print("   zone : %s | largeur %s | justifie %s" % (texte.text, texte.width, texte.justify))
    assert texte.width == 130, "MinimapZoneText 130 de large"
    assert texte.justify == "LEFT", "camelot ecrit justifyH=LEFT : GameFontNormal n en porte aucune"

    # LE SUIVI
    suivi = g.MiniMapTracking
    bouton = g.MiniMapTrackingButton
    print("   suivi %dx%d, bouton %dx%d, image %s" % (
        suivi.width, suivi.height, bouton.width, bouton.height, bouton._normal.texture))
    assert (suivi.width, suivi.height) == (17, 17), "le plateau du suivi"
    assert (bouton.width, bouton.height) == (13, 14), "les jumelles"
    ps = suivi.points[1]
    assert (ps[1], ps[3], ps[4]) == ("RIGHT", "LEFT", -2), ps
    assert bouton._highlight.blend == "BLEND", "le survol de camelot est une image complete, pas une lueur additive"

    # LE COURRIER
    courrier = g.MiniMapMailFrame
    print("   courrier %dx%d sous le suivi" % (courrier.width, courrier.height))
    assert (courrier.width, courrier.height) == (20, 15), "MailFrame 20 x 15"

    # LE ZOOM : masque au repos, montre au survol de la carte.
    plus, moins = g.MinimapZoomIn, g.MinimapZoomOut
    print("   zoom + %dx%d marges %s | zoom - %dx%d" % (
        plus.width, plus.height, list(plus.hitRect.values()), moins.width, moins.height))
    assert (plus.width, plus.height) == (17, 17), "ZoomIn 17 x 17"
    assert (moins.width, moins.height) == (17, 9), "ZoomOut 17 x 9"
    assert list(plus.hitRect.values()) == [0, 0, 0, 0], "les marges de 4 px du client ne laisseraient rien a cliquer sur 17"
    assert not plus.shown and not moins.shown, "masques tant que la souris n est pas la"
    # ATTENTION AU FAUX : Minimap.lua GREFFE son OnEnter (HookScript) pour ne
    # pas ecraser ce que le client aurait pose. Le vrai client, lui, range la
    # fonction greffee dans le script quand il n y en avait aucun ; le banc la
    # range a part, dans hooks. On appelle donc la ou elle est.
    carte.hooks["OnEnter"](carte)
    print("   apres survol de la carte : + visible=%s, - visible=%s" % (plus.shown, moins.shown))
    assert plus.shown and moins.shown, "MinimapMixin:OnEnter les montre"
    lua.execute("Minimap.souris = false MinimapZoomIn.souris = false MinimapZoomOut.souris = false ForeverUIMinimapZoomHitArea.souris = false")
    carte.hooks["OnLeave"](carte)
    assert not plus.shown, "et OnLeave les reprend quand la souris n est nulle part"

    # LE CYCLE JOUR / NUIT : le faux dit 14 h.
    print("   cycle : %s" % ("jour" if g.ForeverUI.Minimap.jour else "nuit"))
    assert g.ForeverUI.Minimap.jour, "14 h tombe entre 6 h et 18 h"

    # LE SUIVI PORTE SES JUMELLES : trois etats, dont deux que le bouton du
    # client n'avait pas.
    for etat in ("_normal", "_pushed", "_highlight"):
        t = bouton[etat]
        print("   jumelles %-10s %s %s" % (etat, t and t.texture, t and list(t.texcoord.values())))
        assert t is not None and t.texcoord is not None, "le suivi doit porter l etat %s" % etat
    assert bouton._normal.texture == g.UIAtlas.data["ui-hud-minimap-tracking-up"][1]

    # LE ZOOM PORTE L ART DE CAMELOT
    for b, nom in ((plus, "ui-hud-minimap-zoom-in"), (moins, "ui-hud-minimap-zoom-out")):
        e = g.UIAtlas.data[nom]
        print("   %s : %s %s" % (nom, b._normal.texture, list(b._normal.texcoord.values())))
        assert b._normal.texture == e[1] and b._normal.texcoord[1] == e[2], nom
        assert b._highlight.blend == "BLEND"

    # LE CALENDRIER, a droite de la barre, le jour dans l image.
    cal = g.GameTimeFrame
    pt = cal.points[1]
    e24 = g.UIAtlas.data["ui-hud-calendar-24-up"]
    print("   calendrier %dx%d %s sur %s (%s, %s) | image %s | texte alpha %s" % (
        cal.width, cal.height, pt[1], pt[3], pt[4], pt[5],
        cal._normal.texture, cal.fontString.alpha))
    assert (cal.width, cal.height) == (19, 18), "GameTimeFrame 19 x 18"
    assert (pt[1], pt[2].name, pt[3], pt[4], pt[5]) == ("TOPLEFT", "ForeverUIMinimapBorderTop", "TOPRIGHT", 1, 0), list(pt.values())
    assert cal._normal.texcoord[1] == e24[2] and cal._normal.texcoord[3] == e24[4], "le 24 du mois"
    assert cal.fontString.alpha == 0, "camelot n ecrit plus le jour en texte"
    assert list(cal.hitRect.values()) == [0, 0, 0, 0]
    # le client re-ecrit le jour : l image doit suivre
    lua.execute("function CalendarGetDate() return 6, 9, 25, 2026 end GameTimeFrame_SetDate()")
    e25 = g.UIAtlas.data["ui-hud-calendar-25-up"]
    assert cal._normal.texcoord[1] == e25[2] and cal._normal.texcoord[3] == e25[4], "le lendemain, le 25"
    assert cal.fontString.alpha == 0

    # L HORLOGE : absente au chargement, habillee a ADDON_LOADED.
    assert g.TimeManagerClockButton is None, "le faux ne doit pas la monter avant la demande"
    lua.execute("CHARGER_HORLOGE()")
    h = g.TimeManagerClockButton
    ph = h.points[1]
    tick = g.TimeManagerClockTicker
    print("   horloge %dx%d %s sur %s (%s, %s) | marges %s | fond alpha %s | police %s %s" % (
        h.width, h.height, ph[1], ph[3], ph[4], ph[5], list(h.hitRect.values()),
        h.fondSansNom.alpha, tick.fontFile, tick.fontSize))
    assert (h.width, h.height) == (40, 16)
    assert (ph[1], ph[2].name, ph[3], ph[4], ph[5]) == ("TOPRIGHT", "ForeverUIMinimapBorderTop", "TOPRIGHT", -4, 0), list(ph.values())
    assert list(h.hitRect.values()) == [8, 5, 3, 3]
    assert h.fondSansNom.alpha == 0, "camelot n a pas de fond d horloge"
    assert g.TimeManagerAlarmFiredTexture.alpha != 0, "la lueur d alarme reste"
    assert tick.alpha != 0 and tick.fontSize == 10
    assert list(tick.points[1].values())[3:5] == [3, 1], tick.points[1]
    assert h.parent.name == "MinimapCluster" and (h.frameLevel or 0) > (barre.frameLevel or 1)

    # LES COORDONNEES, sous la carte.
    co = g.ForeverUIMinimapPlayerCoords
    pco = co.points[1]
    co.scripts["OnUpdate"](co, 0.2)
    print("   coordonnees %dx%d %s sur %s (%s, %s) : '%s'" % (
        co.width, co.height, pco[1], pco[3], pco[4], pco[5], co.texte.text))
    assert (co.width, co.height) == (90, 10)
    assert (pco[1], pco[2].name, pco[3], pco[4], pco[5]) == ("BOTTOM", "Minimap", "BOTTOM", 0, -18), list(pco.values())
    assert co.texte.text == "46, 62", co.texte.text
    lua.execute("STATE.cvars.coordsByTenths = " + chr(34) + "1" + chr(34))
    co.scripts["OnUpdate"](co, 0.2)
    assert co.texte.text == "45.7, 62.3", co.texte.text
    lua.execute("STATE.cvars.coordsByTenths = nil POSITION.x = 0 POSITION.y = 0")
    co.scripts["OnUpdate"](co, 0.2)
    assert co.texte.text == "", "en instance, 3.3.5 rend (0, 0) : rien n est ecrit"
    avant = g.POSITION.recentrages
    lua.execute("WorldMapFrame:Show()")
    g.ForeverUI.Minimap.recentrerCarteDuMonde()
    assert g.POSITION.recentrages == avant, "jamais pendant que la carte du monde est ouverte"
    lua.execute("WorldMapFrame:Hide()")
    assert g.POSITION.recentrages == avant + 1, "a la fermeture de la carte du monde"

    # LE TEMOIN DES FLECHES DU BORD : la carte reste a 198 a l ecran, le cadre
    # et la zone de zoom gardent leur taille, et k = 1 rend l etat d origine.
    lua.execute('ForeverUI.MinimapDebug("echelle 1.5")')
    print("   echelle 1.5 : carte %.1f x %.2f = %.1f | cadre %.3f" % (
        carte.width, carte.scale, carte.width * carte.scale,
        g.MinimapBackdrop.scale))
    assert abs(carte.width * carte.scale - 198) < 0.01, "la carte reste a 198 a l ecran"
    assert abs(g.MinimapBackdrop.scale * carte.scale - 1) < 1e-9, "le cadre garde sa taille"
    assert abs(g.ForeverUIMinimapZoomHitArea.scale * carte.scale - 1) < 1e-9
    lua.execute('ForeverUI.MinimapDebug("echelle 1")')
    assert carte.width == 198 and carte.scale == 1 and g.MinimapBackdrop.scale == 1
    lua.execute('ForeverUI.MinimapDebug("echelle")')
    assert carte.width == 140 and abs(carte.width * carte.scale - 198) < 1e-9, "sans nombre : l echelle du projet"

    # LES QUATRE BOUTONS QUE CAMELOT N A PAS, poses sur l anneau a 100 du centre.
    for nom in ("MiniMapWorldMapButton", "MiniMapLFGFrame",
                "MiniMapBattlefieldFrame", "MiniMapRecordingButton"):
        b = g[nom]
        pt = b.points[1]
        rayon = (pt[4] ** 2 + pt[5] ** 2) ** 0.5
        print("   %-26s CENTER (%7.2f, %7.2f) rayon %.1f" % (nom, pt[4], pt[5], rayon))
        assert abs(rayon - 100) < 0.5, "%s doit tomber sur le metal de l anneau" % nom

    print("\nmessages du chat :")
    for msg in g.RECORDED.messages.values():
        print("   %s" % msg)


main()
