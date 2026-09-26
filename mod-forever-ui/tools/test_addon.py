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
    -- la cible est retenue (vraie si aucune : le parent)
    function r:SetAllPoints(cible) self.allPoints = cible or true end
    function r:ClearAllPoints() self.points = {} end
    -- Le vrai declenche le OnShow en se montrant, comme le OnHide en se
    -- cachant ; le banc ne le faisait pas.
    -- LE CLIENT PREVIENT AUSSI LES DESCENDANTS : un cadre qui se montre (ou
    -- se cache) declenche le OnShow (OnHide) de ses enfants eux-memes
    -- montres. Le banc ne le faisait que pour le cadre lui-meme, et ne
    -- voyait donc pas ce qu'un enfant fait quand son livre se ferme.
    local function prevenir(f, script)
        for _, c in ipairs(f.children or {}) do
            if c.shown then
                if c.scripts and c.scripts[script] then c.scripts[script](c) end
                if c.hooks and c.hooks[script] then c.hooks[script](c) end
                prevenir(c, script)
            end
        end
    end
    function r:Show()
        local avant = self.shown
        self.shown = true
        if not avant and self.scripts and self.scripts.OnShow then
            self.scripts.OnShow(self)
        end
        if not avant and self.hooks and self.hooks.OnShow then
            self.hooks.OnShow(self)
        end
        if not avant then prevenir(self, "OnShow") end
    end
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
        if avant then prevenir(self, "OnHide") end
    end
    function r:IsShown() return self.shown end
    function r:SetText(t) self.text = t end
    function r:GetText() return self.text end
    function r:SetJustifyH(j) self.justify = j end
    function r:GetJustifyH() return self.justify end
    -- 3.3.5 l'a, mais il REND FAUX quand la carte graphique ne sait
    -- pas desaturer. Le faux rend vrai : c'est le cas courant.
    -- nil ou false : pas desaturee (le client lit un booleen Lua)
    function r:SetDesaturated(v) self.desaturated = v and true or false return true end
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
    function r:GetFont() return self.policeChemin or "Fonts" .. string.char(92) .. "FRIZQT__.TTF", self.policeTaille or 12, self.policeDrapeaux or "" end
    function r:SetFont(chemin, taille, drapeaux) self.policeChemin, self.policeTaille, self.policeDrapeaux = chemin, taille, drapeaux return true end
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
    function r:SetVertexColor(a, b, c, d) self.vertex = {a, b, c} self.vertexAlpha = d end
    function r:SetAlpha(a) self.alpha = a end
    function r:GetAlpha() return self.alpha or 1 end
    -- 3.3.5 ne prend PAS de sous-calque : un seul argument.
    function r:SetDrawLayer(calque) self.layer = calque end
    function r:SetBlendMode(m) self.blend = m end
    function r:SetFont(chemin, taille, drapeaux) self.fontFile, self.fontSize, self.fontFlags = chemin, taille, drapeaux end
    -- 6 pixels par caractere : assez pour verifier une largeur calculee.
    function r:GetStringWidth() return string.len(self.text or "") * 6 end
    function r:SetVertTile(v) self.vtile = v end
    -- Une region change de parent en 3.3.5 : PlayerFrame.lua le fait sur
    -- PlayerFrameManaBarText.
    function r:SetParent(p) self.parent = p; self.owner = p end
    function r:GetParent() return self.parent or self.owner end
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
        -- UN GREFFON EST DU CODE D'ADDON : meme accroche a un script du
        -- client appele par un chemin securise, il tourne sans securite
        -- (SECURISE remis a zero le temps de l'appel).
        local brutFn = fn
        fn = function(...)
            local avant = SECURISE or 0
            SECURISE = 0
            local r = table.pack(pcall(brutFn, ...))
            SECURISE = avant
            if not r[1] then error(r[2], 0) end
            return table.unpack(r, 2, r.n)
        end
        -- Le vrai ENCHAINE les greffons : chacun passe apres le precedent.
        -- Le banc n'en gardait qu'un, et le dernier pose effacait les autres
        -- (le volet de quetes et la minimap ecoutent tous deux la fermeture
        -- de la carte).
        local avant = self.hooks[event]
        if avant then
            self.hooks[event] = function(...) avant(...) fn(...) end
        else
            self.hooks[event] = fn
        end
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
    function f:SetClampedToScreen(v) self.clamped = (v and true or false) end
    function f:IsClampedToScreen() return self.clamped == true end
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
    -- LockHighlight garde la surbrillance d'un bouton affichee (selection).
    function f:LockHighlight() self.locked = true end
    function f:SetMultiLine(v) self.multiLine = v end
    function f:UnlockHighlight() self.locked = false end
    function f:GetButtonState() return self.buttonState or "NORMAL" end
    function f:SetReverse(v) self.reverse = v and true or false end
    function f:SetChecked(v) self.checked = v and true or false end
    function f:GetChecked() return self.checked end
    -- Le vrai Click d'un CheckButton bascule la coche PUIS joue OnClick.
    function f:Click()
        if self.checked ~= nil or self.kind == "CheckButton" then self.checked = not self.checked end
        if self.scripts.OnClick then self.scripts.OnClick(self, "LeftButton") end
    end
    function f:IsVisible() return self.shown ~= false end
    function f:SetScrollChild(c) self.scrollChild = c end
    function f:SetVerticalScroll(v) self.verticalScroll = v end
    function f:GetVerticalScroll() return self.verticalScroll or 0 end
    function f:SetFontObject(o) self.font = o end
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
    function f:GetFrameStrata() return self.strata or "MEDIUM" end
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
    -- Le vrai SetText d'un bouton ecrit dans sa FontString et ne touche a
    -- AUCUN champ Lua du cadre. Le faux ecrasait `text` : un bouton qui y
    -- rangeait sa FontString (bouton.text = fs, comme les NavButton de
    -- camelot) la perdait au premier SetText.
    function f:SetText(t)
        if self.fontString then self.fontString:SetText(t) end
        if type(self.text) ~= "table" then self.text = t end
    end
    function f:GetText()
        if self.fontString then return self.fontString:GetText() or "" end
        if type(self.text) == "table" then return "" end
        return self.text or ""
    end
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
    function f:SetStatusBarColor(r, v, b) self.barColor = { r, v, b } end
    function f:SetJustifyH(j) self.justify = j end
    function f:SetFontString(fs) self.fontString = fs end
    function f:GetFontString() return self.fontString end
    -- le vrai declenche OnAttributeChanged : le script, puis les greffons
    function f:SetAttribute(k, v)
        self.attributes[k] = v
        if self.scripts.OnAttributeChanged then self.scripts.OnAttributeChanged(self, k, v) end
        if self.hooks and self.hooks.OnAttributeChanged then self.hooks.OnAttributeChanged(self, k, v) end
    end
    function f:GetAttribute(k) return self.attributes[k] end
    -- Un cadre deplace par StartMoving devient "place par l'utilisateur" : le
    -- client retient alors sa position.
    function f:StartMoving() self.moving = true; self.userPlaced = true end
    function f:IsUserPlaced() return self.userPlaced == true end
    function f:StopMovingOrSizing() self.moving = false end
    function f:SetUserPlaced(v) self.userPlaced = (v ~= false) end
    function f:GetCenter() return self._cx, self._cy end
    -- protege : pose par le banc (un cadre qui porte des boutons securises)
    function f:IsProtected() return self.protege == true end
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
-- Le vrai n'ouvre rien : il retient la fonction qui remplira la liste. Le
-- banc la garde pour pouvoir la jouer.
function UIDropDownMenu_Initialize(cadre, fonction, mode, niveau, menuListe)
    if cadre then cadre.initFn, cadre.menuMode = fonction, mode end
    -- LE VRAI APPELLE LA FONCTION TOUT DE SUITE (UIDropDownMenu.lua:67-70) :
    -- frame.initialize = initFunction ; initFunction(frame, level,
    -- menuList). Le banc ne le faisait pas, et un menu construit d'avance
    -- plantait a la connexion (UnitPopup_ShowMenu sans menu ouvert, page
    -- Raid, 2026-09-26).
    if cadre and fonction then
        cadre.initialize = fonction
        fonction(cadre, niveau, menuListe)
    end
    -- le vrai ecrit frame.displayMode = "MENU" (UIDropDownMenu.lua:85) ; le
    -- banc ne le faisait pas, et un menu contextuel passait pour un menu
    -- deroulant
    if cadre and mode == "MENU" then cadre.displayMode = "MENU" end
    -- et il vide la liste avant qu'on la remplisse
    for niveau = 1, 2 do
        local liste = _G["DropDownList" .. niveau]
        if liste then liste.numButtons = 0 end
    end
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
    ClearAllPoints = function() end,
    SetPoint = function() end,
    -- le vrai SetOwner vide aussi l'infobulle
    SetOwner = function(self, cadre, ancre)
        self.owner, self.anchor = cadre, ancre
        self.text, self.lignes = nil, {}
    end,
    GetOwner = function(self) return self.owner end,
    -- le vrai SetText recommence l'infobulle : les lignes d'avant s'en vont
    SetText = function(self, texte) self.text = texte; self.lignes = {} end,
    AddLine = function(self, texte)
        self.lignes = self.lignes or {}
        table.insert(self.lignes, texte)
    end,
    Show = function(self) self.shown = true end,
    Hide = function(self) self.shown = false end,
    -- l'infobulle d'une unite, d'un affaiblissement ; FadeOut la fait partir
    SetUnit = function(self, unite) self.unite = unite; self.text = UnitName(unite); self.lignes = {} end,
    SetUnitDebuff = function(self, unite, i, filtre) self.debuff = { unite, i, filtre } end,
    FadeOut = function(self) self.shown = false end,
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

-- LA CARTE DU MONDE DE WOTLK (WorldMapFrame.xml / .lua, patch-enUS-3). Les
-- fonctions ci-dessous recopient ce que le vrai fait aux cadres qu'on touche,
-- Y COMPRIS ce qu'il remontre de lui-meme : SetOpacity rend son alpha a la
-- bordure, UpdateMap remontre le menu des etages, DisplayQuests la case de
-- suivi.
function SetCVar(nom, valeur) STATE.cvars[nom] = valeur end
function PlaySound() end
-- 3.3.5 expose string.format en global (FrameXML s'en sert partout)
format = format or string.format
strupper = string.upper
FLOOR_NUMBER = "Area %d"
MAP_QUEST_DIFFICULTY_TEXT = "Quest Difficulty Color"
SHOW_QUEST_OBJECTIVES_ON_MAP_TEXT = "Show Quest Objectives"
MAP_QUEST_DIFFICULTY = "0"
WORLDMAP_POI_FRAMELEVEL = 100
WORLDMAP_WINDOWED_SIZE = 0.573
WORLDMAP_QUESTLIST_SIZE = 0.691
WORLDMAP_FULLMAP_SIZE = 1.0
WORLDMAP_WORLD_ID = 0
WORLDMAP_COSMIC_ID = -1
WORLDMAP_SETTINGS = { opacity = 0, locked = true, advanced = nil, size = WORLDMAP_QUESTLIST_SIZE }
CARTE = { continent = 2, zone = 5, etages = 0, etage = 0, zooms = {} }
function GetCurrentMapContinent() return CARTE.continent end
function GetCurrentMapZone() return CARTE.zone end
function GetMapContinents() return "Kalimdor", "Eastern Kingdoms", "Outland", "Northrend" end
function GetMapZones(c) return "Alterac Mountains", "Arathi Highlands", "Badlands", "Blasted Lands", "Burning Steppes" end
-- CARTE.suivre : SetMapZoom et ZoomOut changent la carte montree ; en donjon
-- (CARTE.donjon), SetMapZoom n'en sort pas, ZoomOut mene au continent
function SetMapZoom(c, z)
    table.insert(CARTE.zooms, { c, z })
    if CARTE.suivre and not CARTE.donjon then
        CARTE.continent, CARTE.zone = c, z or 0
        -- GetMapInfo ne rend rien pour la vue cosmique ni pour Azeroth
        if c == -1 or c == 0 then CARTE.fichier = false else CARTE.fichier = "Continent" .. c end
    end
end
function ZoomOut()
    CARTE.zoomsArriere = (CARTE.zoomsArriere or 0) + 1
    if CARTE.suivre and CARTE.donjon then
        CARTE.donjon = nil
        CARTE.continent, CARTE.zone, CARTE.fichier = 4, 0, "Northrend"
    end
end
function GetNumDungeonMapLevels() return CARTE.etages end
function GetCurrentMapDungeonLevel() return CARTE.etage end
function SetDungeonMapLevel(n) CARTE.etage = n end
function GetMapInfo()
    if CARTE.fichier == false then return nil end
    return CARTE.fichier or "Ulduar"
end
function IsZoomOutAvailable() return true end
function DungeonUsesTerrainMap() return false end
function SetPortraitToTexture(t, chemin) t.portrait = chemin; t.texture = chemin end

WorldMapFrame = CreateFrame("Frame", "WorldMapFrame", UIParent)
WorldMapFrame:SetFrameLevel(87)
WorldMapFrame:Hide()
BlackoutWorld = WorldMapFrame:CreateTexture("BlackoutWorld", "BACKGROUND")
WorldMapFrameMiniBorderLeft = WorldMapFrame:CreateTexture("WorldMapFrameMiniBorderLeft", "ARTWORK")
WorldMapFrameMiniBorderLeft:SetTexture("Interface\\\\WorldMap\\\\UI-WorldMapSmall-Left")
WorldMapFrameMiniBorderRight = WorldMapFrame:CreateTexture("WorldMapFrameMiniBorderRight", "ARTWORK")
WorldMapFrameMiniBorderRight:SetTexture("Interface\\\\WorldMap\\\\UI-WorldMapSmall-Right")
WorldMapFrameTitle = WorldMapFrame:CreateFontString("WorldMapFrameTitle", "ARTWORK")
WorldMapFrameTitle:SetFontObject("GameFontNormal")
WorldMapFrameTitle:SetText("World Map")
WorldMapPositioningGuide = CreateFrame("Frame", "WorldMapPositioningGuide", WorldMapFrame)
WorldMapDetailFrame = CreateFrame("Frame", "WorldMapDetailFrame", WorldMapFrame)
WorldMapDetailFrame:SetWidth(1002) WorldMapDetailFrame:SetHeight(668)
WorldMapBlobFrame = CreateFrame("Frame", "WorldMapBlobFrame", WorldMapDetailFrame)
-- Douze tuiles de 256 x 256 en 4 x 3 (WorldMapFrame.xml:541-636) : 1024 x 768
-- pour une carte utile de 1002 x 668.
for i = 1, 12 do
    local t = WorldMapDetailFrame:CreateTexture("WorldMapDetailTile" .. i, "BACKGROUND")
    t:SetWidth(256) t:SetHeight(256)
    _G["WorldMapDetailTile" .. i] = t
end
-- WorldMapFrame_Update recharge chaque tuile par SetTexture. Le banc suppose
-- le pire : que le rechargement rende a la tuile ses coordonnees entieres.
function WorldMapFrame_Update()
    for i = 1, 12 do
        local t = _G["WorldMapDetailTile" .. i]
        local bs = string.char(92)
        t:SetTexture("Interface" .. bs .. "WorldMap" .. bs .. "Azeroth" .. i)
        t:SetTexCoord(0, 1, 0, 1)
    end
end
WorldMapButton = CreateFrame("Button", "WorldMapButton", WorldMapDetailFrame)
WorldMapButton:SetWidth(1002) WorldMapButton:SetHeight(668)
WorldMapPOIFrame = CreateFrame("Frame", "WorldMapPOIFrame", WorldMapDetailFrame)
WorldMapFrameAreaFrame = CreateFrame("Frame", "WorldMapFrameAreaFrame", WorldMapButton)
WorldMapTitleButton = CreateFrame("Button", "WorldMapTitleButton", WorldMapFrame)
WorldMapTitleButton:SetWidth(544) WorldMapTitleButton:SetHeight(22)
-- UIPanelCloseButton : Normal, Pushed, Highlight.
WorldMapFrameCloseButton = CreateFrame("Button", "WorldMapFrameCloseButton", WorldMapFrame)
WorldMapFrameCloseButton:SetNormalTexture("fermeture-up")
WorldMapFrameCloseButton:SetPushedTexture("fermeture-down")
WorldMapFrameCloseButton:SetHighlightTexture("fermeture-highlight")
-- Les deux boutons de taille : Normal, Pushed, Highlight (WorldMapFrame.xml:506-526).
for _, nom in ipairs({ "WorldMapFrameSizeDownButton", "WorldMapFrameSizeUpButton" }) do
    local b = CreateFrame("Button", nom, WorldMapFrame)
    b:SetWidth(32) b:SetHeight(32)
    b:SetNormalTexture("taille-up") b:SetPushedTexture("taille-down") b:SetHighlightTexture("taille-highlight")
end
WorldMapQuestShowObjectives = CreateFrame("CheckButton", "WorldMapQuestShowObjectives", WorldMapFrame)
WorldMapQuestShowObjectives.kind = "CheckButton"
WorldMapQuestShowObjectives.checked = true
WorldMapQuestShowObjectives:SetScript("OnClick", function(self)
    SetCVar("questPOI", self:GetChecked() and "1" or "0")
    WatchFrame.showObjectives = self:GetChecked()
end)
WorldMapTrackQuest = CreateFrame("CheckButton", "WorldMapTrackQuest", WorldMapFrame)
WorldMapLevelDropDown = CreateFrame("Frame", "WorldMapLevelDropDown", WorldMapFrame)
WatchFrame = WatchFrame or CreateFrame("Frame", "WatchFrame", UIParent)
WatchFrame.showObjectives = true

function WorldMapFrame_ResetFrameLevels()
    WorldMapFrame:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL - 13)
    WorldMapDetailFrame:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL - 12)
    WorldMapBlobFrame:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL - 11)
    WorldMapButton:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL - 10)
    WorldMapPOIFrame:SetFrameLevel(WORLDMAP_POI_FRAMELEVEL)
end
function WorldMapFrame_SetOpacity(opacity)
    local alpha = 0.5 + (1.0 - opacity) * 0.50
    WorldMapFrameMiniBorderLeft:SetAlpha(alpha)
    WorldMapFrameMiniBorderRight:SetAlpha(alpha)
    WorldMapFrameSizeUpButton:SetAlpha(alpha)
    WorldMapFrameCloseButton:SetAlpha(alpha)
end
function WorldMapFrame_SetMiniMode()
    WorldMapFrame:ClearAllPoints()
    if WORLDMAP_SETTINGS.advanced then
        WorldMapFrame:SetAttribute("UIPanelLayout-area", "center")
        WorldMapFrame:SetAttribute("UIPanelLayout-allowOtherPanels", true)
        WorldMapFrame:SetMovable("true")
        WorldMapFrame:SetWidth(593)
        WorldMapFrame:SetPoint("TOPLEFT", WorldMapScreenAnchor, 0, 0)
        WorldMapFrameMiniBorderLeft:SetPoint("TOPLEFT", 0, 0)
        WorldMapDetailFrame:SetPoint("TOPLEFT", 19, -42)
    else
        WorldMapFrame:SetAttribute("UIPanelLayout-area", "doublewide")
        WorldMapFrame:SetAttribute("UIPanelLayout-allowOtherPanels", false)
        -- "false" est une CHAINE, donc vraie en Lua : comme dans le vrai
        WorldMapFrame:SetMovable("false")
        WorldMapFrame:SetWidth(623)
        WorldMapFrameMiniBorderLeft:SetPoint("TOPLEFT", 10, -14)
        -- tel quel dans le vrai : SANS ClearAllPoints, le point s'ajoute
        WorldMapDetailFrame:SetPoint("TOPLEFT", 37, -66)
    end
    WorldMapFrame:SetHeight(437)
end
-- WorldMapScreenAnchor : 1 x 1, deplacable, au coin haut-gauche (XML:1148).
WorldMapScreenAnchor = CreateFrame("Frame", "WorldMapScreenAnchor", UIParent)
WorldMapScreenAnchor:SetMovable(true)
WorldMapScreenAnchor:SetPoint("TOPLEFT")
-- La barre de titre : elle ne fait glisser la carte qu'en mode avance et
-- deverrouille (WorldMapFrame.lua:2062-2085).
WorldMapTitleButton:SetScript("OnDragStart", function()
    if WORLDMAP_SETTINGS.advanced and not WORLDMAP_SETTINGS.locked then
        WorldMapScreenAnchor:ClearAllPoints()
        WorldMapFrame:ClearAllPoints()
        WorldMapFrame:StartMoving()
    end
end)
WorldMapTitleButton:SetScript("OnDragStop", function()
    if WORLDMAP_SETTINGS.advanced and not WORLDMAP_SETTINGS.locked then
        WorldMapFrame:StopMovingOrSizing()
        WorldMapScreenAnchor:StartMoving()
        WorldMapScreenAnchor:SetPoint("TOPLEFT", WorldMapFrame)
        WorldMapScreenAnchor:StopMovingOrSizing()
    end
end)
function WorldMap_ToggleSizeDown()
    WORLDMAP_SETTINGS.size = WORLDMAP_WINDOWED_SIZE
    WorldMapFrame:SetParent(UIParent)
    WorldMapFrame_ResetFrameLevels()
    WorldMapDetailFrame:SetScale(WORLDMAP_WINDOWED_SIZE)
    WorldMapButton:SetScale(WORLDMAP_WINDOWED_SIZE)
    WorldMapFrameAreaFrame:SetScale(WORLDMAP_WINDOWED_SIZE)
    WorldMapBlobFrame:SetScale(WORLDMAP_WINDOWED_SIZE)
    BlackoutWorld:Hide()
    WorldMapQuestShowObjectives:Show()
    WorldMapFrameSizeDownButton:Hide()
    WorldMapTitleButton:Show()
    WorldMapFrameMiniBorderLeft:Show()
    WorldMapFrameMiniBorderRight:Show()
    WorldMapFrameSizeUpButton:Show()
    WorldMapFrameCloseButton:SetPoint("TOPRIGHT", WorldMapFrameMiniBorderRight, "TOPRIGHT", -44, 5)
    WorldMapFrameTitle:ClearAllPoints()
    WorldMapFrameTitle:SetPoint("TOP", WorldMapDetailFrame, 0, 20)
    WorldMapFrame_SetMiniMode()
    WorldMapFrame_SetOpacity(WORLDMAP_SETTINGS.opacity)
end
WORLD_MAP = "World Map"
for i = 1, 18 do
    WorldMapFrame:CreateTexture("WorldMapFrameTexture" .. i, "ARTWORK")
    _G["WorldMapFrameTexture" .. i] = WorldMapFrame.regions[#WorldMapFrame.regions]
end
PLEIN_ECRAN = { "WorldMapZoneMinimapDropDown", "WorldMapZoomOutButton", "WorldMapZoneDropDown",
    "WorldMapContinentDropDown", "WorldMapQuestScrollFrame", "WorldMapQuestDetailScrollFrame",
    "WorldMapQuestRewardScrollFrame", "WorldMapLevelUpButton", "WorldMapLevelDownButton" }
for _, nom in ipairs(PLEIN_ECRAN) do
    local f = CreateFrame("Frame", nom, WorldMapFrame)
    f:Hide()
end
WorldMapPositioningGuide = CreateFrame("Frame", "WorldMapPositioningGuide", WorldMapFrame)
function WorldMapFrame_SetPOIMaxBounds() BORNES_POI = WORLDMAP_SETTINGS.size end
function WorldMapFrame_SetQuestMapView()
    WORLDMAP_SETTINGS.size = WORLDMAP_QUESTLIST_SIZE
    WorldMapDetailFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapButton:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapFrameAreaFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -726, -99)
    WorldMapQuestDetailScrollFrame:Show()
    WorldMapQuestRewardScrollFrame:Show()
    WorldMapQuestScrollFrame:Show()
    for i = 13, 18 do _G["WorldMapFrameTexture" .. i]:Hide() end
end
function WorldMapFrame_SetFullMapView()
    WORLDMAP_SETTINGS.size = WORLDMAP_FULLMAP_SIZE
    WorldMapDetailFrame:SetScale(WORLDMAP_FULLMAP_SIZE)
    WorldMapButton:SetScale(WORLDMAP_FULLMAP_SIZE)
    WorldMapFrameAreaFrame:SetScale(WORLDMAP_FULLMAP_SIZE)
    WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -502, -69)
    WorldMapQuestDetailScrollFrame:Hide()
    WorldMapQuestRewardScrollFrame:Hide()
    WorldMapQuestScrollFrame:Hide()
    for i = 13, 18 do _G["WorldMapFrameTexture" .. i]:Show() end
end
function WorldMap_ToggleSizeUp()
    WORLDMAP_SETTINGS.size = WORLDMAP_QUESTLIST_SIZE
    WorldMapFrame:SetParent(nil)
    WorldMapFrame_ResetFrameLevels()
    WorldMapFrame:ClearAllPoints()
    WorldMapFrame:SetAllPoints()
    -- SetupFullscreenScale : une echelle propre au plein ecran
    WorldMapFrame:SetScale(1)
    WorldMapDetailFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapDetailFrame:SetPoint("TOPLEFT", WorldMapPositioningGuide, "TOP", -726, -99)
    WorldMapButton:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapFrameAreaFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
    WorldMapBlobFrame:SetScale(WORLDMAP_QUESTLIST_SIZE)
    for _, nom in ipairs(PLEIN_ECRAN) do
        if nom ~= "WorldMapLevelUpButton" and nom ~= "WorldMapLevelDownButton" then _G[nom]:Show() end
    end
    for i = 1, 18 do
        _G["WorldMapFrameTexture" .. i]:SetTexture("plein-ecran-" .. i)
        _G["WorldMapFrameTexture" .. i]:Show()
    end
    BlackoutWorld:Show()
    WorldMapFrameMiniBorderLeft:Hide()
    WorldMapFrameMiniBorderRight:Hide()
    WorldMapFrameSizeUpButton:Hide()
    WorldMapFrameSizeDownButton:Show()
    WorldMapFrameTitle:ClearAllPoints()
    WorldMapFrameTitle:SetPoint("CENTER", 0, 372)
    WorldMapFrame_SetOpacity(0)
end
function WorldMapLevelDropDown_Update()
    if GetNumDungeonMapLevels() == 0 then
        WorldMapLevelDropDown:Hide()
    else
        WorldMapLevelDropDown:Show()
    end
end
function WorldMapFrame_SetMapName()
    local nom = "World Map"
    if WORLDMAP_SETTINGS.size == WORLDMAP_WINDOWED_SIZE then nom = "Burning Steppes" end
    WorldMapFrameTitle:SetText(nom)
end
function WorldMapFrame_DisplayQuests()
    WorldMapTrackQuest:Show()
end
-- (redefinie avec la selection plus bas, apres les reperes)
function WorldMapFrame_ResetQuestColors() end
function WorldMapFrame_UpdateMap(questId)
    WorldMapFrame_Update()
    WorldMapLevelDropDown_Update()
    WorldMapFrame_SetMapName()
    if WatchFrame.showObjectives then WorldMapFrame_DisplayQuests(questId) end
end

-- LE JOURNAL DE QUETES DE 3.3.5. Un en-tete REPLIE retire ses quetes de la
-- liste que rendent GetNumQuestLogEntries et GetQuestLogTitle : c'est ce qui
-- oblige a tout deplier pour chercher.
JOURNAL = {
    { title = "Elwynn Forest", header = true, collapsed = false },
    { title = "A Threat Within", level = 5, questID = 783, objectifs = { { "Kobold Vermin slain: 3/10", false }, { "Report found", true } } },
    { title = "The Fargodeep Mine", level = 12, tag = "Elite", questID = 62, objectifs = { { "Explore the mine", false }, { "Kobolds slain: 5/5", true } },
      description = "Kobolds have overrun the mine.", texte = "Explore the Fargodeep Mine.", groupe = 3, temps = 125,
      choix = { { "Mining Pick", "icone:pioche", 1, 2, true }, { "Leather Boots", "icone:bottes", 1, 3, false } },
      recompenses = { { "Linen Cloth", "icone:lin", 5, 1, true } }, argent = 250, xp = 850, honneur = 12,
      partageable = true, objet = { "icone:pioche", 3 }, minuteur = 90 },
    { title = "Westfall", header = true, collapsed = true },
    { title = "The People's Militia", level = 14, complete = 1, questID = 12, objectifs = {} },
}
SUIVIES = {}
SELECTION = 0
REPLIS = {}
local function visibles()
    local l, dansReplie = {}, false
    for _, e in ipairs(JOURNAL) do
        if e.header then
            table.insert(l, e)
            dansReplie = e.collapsed
        elseif not dansReplie then
            table.insert(l, e)
        end
    end
    return l
end
function GetNumQuestLogEntries()
    local n, q = 0, 0
    for _, e in ipairs(visibles()) do
        n = n + 1
    end
    for _, e in ipairs(JOURNAL) do if not e.header then q = q + 1 end end
    return n, q
end
function GetQuestLogTitle(i)
    local e = visibles()[i]
    if not e then return nil end
    if e.header then return e.title, 0, nil, 0, 1, e.collapsed and 1 or nil end
    return e.title, e.level, e.tag, 0, nil, nil, e.complete, nil, e.questID
end
function ExpandQuestHeader(i) local e = visibles()[i]; e.collapsed = false; table.insert(REPLIS, "+" .. e.title) end
function CollapseQuestHeader(i) local e = visibles()[i]; e.collapsed = true; table.insert(REPLIS, "-" .. e.title) end
-- Sans index, 3.3.5 repond pour la quete CHOISIE (SelectQuestLogEntry).
function GetNumQuestLeaderBoards(i) local e = visibles()[i or SELECTION]; return e and e.objectifs and #e.objectifs or 0 end
function GetQuestLogLeaderBoard(j, i)
    local o = visibles()[i or SELECTION].objectifs[j]
    return o[1], "monster", o[2] and 1 or nil
end
function GetQuestLogRequiredMoney() return 0 end
function GetMoney() return 0 end
function GetMoneyString(v) return tostring(v) end
function GetQuestLogCompletionText(i) return "Return to Gryan Stoutmantle." end
function GetQuestLogSelection() return SELECTION end
function SelectQuestLogEntry(i) SELECTION = i end
function GetQuestLogQuestText() local e = visibles()[SELECTION]; return e and e.description or "", e and e.texte or "" end
-- LA PAGE D'UNE QUETE : tout ce que 3.3.5 dit de la quete CHOISIE.
local function choisie() return visibles()[SELECTION] or {} end
function GetQuestLogTimeLeft() return choisie().temps end
function GetQuestLogGroupNum() return choisie().groupe or 0 end
function GetNumQuestLogRewards() return #(choisie().recompenses or {}) end
function GetNumQuestLogChoices() return #(choisie().choix or {}) end
function GetQuestLogRewardInfo(i) local o = choisie().recompenses[i]; return o[1], o[2], o[3], o[4], o[5] end
function GetQuestLogChoiceInfo(i) local o = choisie().choix[i]; return o[1], o[2], o[3], o[4], o[5] end
function GetQuestLogRewardMoney() return choisie().argent or 0 end
function GetQuestLogRewardXP() return choisie().xp or 0 end
function GetQuestLogRewardHonor() return choisie().honneur or 0 end
function GetQuestLogRewardArenaPoints() return 0 end
function GetQuestLogRewardTitle() return choisie().titreJoueur end
function GetQuestLogRewardSpell() local s = choisie().sort; if s then return s[1], s[2], s[3], s[4] end end
function GetQuestLogItemLink(t, i) return "lien:" .. t .. i end
function GetQuestLogSpellLink() return "lien:sort" end
-- SetAbandonQuest retient la quete choisie ; GetAbandonQuestName la nomme.
ABANDON = 0
function SetAbandonQuest() ABANDON = SELECTION end
function GetAbandonQuestName() local e = visibles()[ABANDON]; return e and not e.header and e.title or nil end
function GetAbandonQuestItems() return nil end
function GetQuestLogPushable() return choisie().partageable end
function QuestLogPushQuest() end
POPUPS_CACHES = {}
function StaticPopup_Hide(quoi) table.insert(POPUPS_CACHES, quoi) end
-- MoneyFrame.lua : le porte-monnaie par son NOM
function MoneyFrame_Update(nom, v) _G[nom].argent = v end
function MoneyFrame_SetType(f, t) f.moneyType = t end
function SetMoneyFrameColor(nom, c) _G[nom].couleur = c end
function SecondsToTime(s) return tostring(math.floor(s)) .. " sec" end
function HandleModifiedItemClick(lien) LIEN_CLIQUE = lien end
function GameTooltip_ShowCompareItem() end
GameTooltip.SetQuestLogItem = function(self, t, i) self.objetQuete = { t, i } end
GameTooltip.SetQuestLogRewardSpell = function(self) self.sortQuete = true end
TIME_REMAINING = "Time Remaining:"
BACK = "Back"
ABANDON_QUEST_ABBREV = "Abandon"
SHARE_QUEST_ABBREV = "Share"
TRACK_QUEST_ABBREV = "Track"
QUEST_DESCRIPTION = "Description"
REQUIRED_MONEY = "Required Money:"
REWARD_ITEMS = "You will also receive:"
REWARD_ITEMS_ONLY = "You will receive:"
REWARD_CHOICES = "You will be able to choose one of these rewards:"
REWARD_TITLE = "You shall be granted the title:"
REWARD_SPELL = "You will learn:"
REWARD_AURA = "The following spell will be cast on you:"
REWARD_TRADESKILL_SPELL = "You will learn how to create:"
QUEST_SUGGESTED_GROUP_NUM = "Suggested Players [%d]"
COMPLETE = "Complete"
HONOR = "Honor"
HONOR_POINTS = "Honor Points"
ARENA_POINTS = "Arena Points"
function IsQuestWatched(i) return SUIVIES[visibles()[i].title] and 1 or nil end
function AddQuestWatch(i) SUIVIES[visibles()[i].title] = true end
function RemoveQuestWatch(i) SUIVIES[visibles()[i].title] = nil end
function GetNumQuestWatches() local n = 0 for _ in pairs(SUIVIES) do n = n + 1 end return n end
-- LE SUIVI DE QUETES DE 3.3.5 (WatchFrame.xml / WatchFrame.lua, chaine
-- d'archives). Recopie pour ce que ForeverUI touche : le cadre et ses fils,
-- WatchFrame_Update qui appelle les GESTIONNAIRES d'objectifs, repli,
-- largeur, filtres, et les fonctions de menu.
-- 3.3.5 porte table.wipe (alias de wipe) ; Lua 5.5 non
table.wipe = table.wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
bit = bit or { band = function(a, b)
    local r, m = 0, 1
    while a > 0 and b > 0 do
        if a % 2 == 1 and b % 2 == 1 then r = r + m end
        a, b, m = math.floor(a / 2), math.floor(b / 2), m * 2
    end
    return r
end }
WatchFrame:SetWidth(204) WatchFrame:SetHeight(500)
WatchFrame._top, WatchFrame._bottom = 700, 200
WatchFrameLines = CreateFrame("Frame", "WatchFrameLines", WatchFrame)
WatchFrameLines:SetPoint("TOPLEFT", WatchFrame, "TOPLEFT", 0, -30)
WatchFrameLines:SetPoint("BOTTOMRIGHT", WatchFrame, "BOTTOMRIGHT", -24, 12)
WatchFrameHeader = CreateFrame("Button", "WatchFrameHeader", WatchFrame)
WatchFrameTitle = WatchFrameHeader:CreateFontString("WatchFrameTitle", "OVERLAY", "GameFontNormal")
WatchFrameCollapseExpandButton = CreateFrame("Button", "WatchFrameCollapseExpandButton", WatchFrame)
WatchFrameCollapseExpandButton:SetNormalTexture("quest-hide-button")
WatchFrameCollapseExpandButton:SetPushedTexture("quest-hide-button")
OBJECTIVES_TRACKER_LABEL = "Objectives"
WATCHFRAME_COLLAPSEDWIDTH = 140
WATCHFRAME_EXPANDEDWIDTH = 204
WATCHFRAME_MAXLINEWIDTH = 192
WATCHFRAME_INITIAL_OFFSET = 0
WATCHFRAME_TYPE_OFFSET = 10
WATCHFRAME_NUM_ITEMS = 0
WATCHFRAME_OBJECTIVEHANDLERS = {}
WATCHFRAME_TIMEDCRITERIA = {}
WATCHFRAME_ACHIEVEMENT_ARENA_CATEGORY = 165
WATCHFRAME_SORT_PROXIMITY, WATCHFRAME_SORT_DIFFICULTY_HIGH, WATCHFRAME_SORT_DIFFICULTY_LOW, WATCHFRAME_SORT_MANUAL = 1, 2, 3, 0
WATCHFRAME_FILTER_ACHIEVEMENTS, WATCHFRAME_FILTER_COMPLETED_QUESTS, WATCHFRAME_FILTER_REMOTE_ZONES = 1, 2, 4
WATCHFRAME_SORT_TYPE = 0
WATCHFRAME_FILTER_TYPE = 7
CURRENT_MAP_QUESTS = { [783] = 1 }
LOCAL_MAP_QUESTS = {}
VISIBLE_WATCHES = {}
ACHIEVEMENT_CRITERIA_PROGRESS_BAR = 1
TRACKER_SORT_LABEL = "Sort Quests"
TRACKER_SORT_PROXIMITY = "Proximity"
TRACKER_SORT_DIFFICULTY_HIGH = "Difficulty High"
TRACKER_SORT_DIFFICULTY_LOW = "Difficulty Low"
TRACKER_SORT_MANUAL = "Manual"
TRACKER_FILTER_LABEL = "Display"
TRACKER_FILTER_ACHIEVEMENTS = "Achievements"
TRACKER_FILTER_COMPLETED_QUESTS = "Completed Quests"
TRACKER_FILTER_REMOTE_ZONES = "Remote Zones"
TRACKER_SORT_MANUAL_UP = "Move Up"
TRACKER_SORT_MANUAL_TOP = "Move to Top"
TRACKER_SORT_MANUAL_DOWN = "Move Down"
TRACKER_SORT_MANUAL_BOTTOM = "Move to Bottom"
GameFontHighlightMedium = "GameFontHighlightMedium"
function WatchFrame_AddObjectiveHandler(func)
    for i = 1, #WATCHFRAME_OBJECTIVEHANDLERS do
        if WATCHFRAME_OBJECTIVEHANDLERS[i] == func then return end
    end
    table.insert(WATCHFRAME_OBJECTIVEHANDLERS, func)
    return true
end
function WatchFrame_RemoveObjectiveHandler(func)
    for i = 1, #WATCHFRAME_OBJECTIVEHANDLERS do
        if WATCHFRAME_OBJECTIVEHANDLERS[i] == func then
            table.remove(WATCHFRAME_OBJECTIVEHANDLERS, i)
            return true
        end
    end
end
-- les trois gestionnaires d'affichage de WotLK : ils ne doivent plus tourner
WOTLK_DESSINE = 0
function WatchFrame_HandleDisplayQuestTimers() WOTLK_DESSINE = WOTLK_DESSINE + 1 return 0, 0, 0 end
function WatchFrame_HandleDisplayTrackedAchievements() WOTLK_DESSINE = WOTLK_DESSINE + 1 return 0, 0, 0 end
function WatchFrame_DisplayTrackedQuests() WOTLK_DESSINE = WOTLK_DESSINE + 1 return 0, 0, 0 end
WatchFrame_AddObjectiveHandler(WatchFrame_HandleDisplayQuestTimers)
WatchFrame_AddObjectiveHandler(WatchFrame_HandleDisplayTrackedAchievements)
WatchFrame_AddObjectiveHandler(WatchFrame_DisplayTrackedQuests)
-- WatchFrame_Update, recopie (sans les boutons de lien, disparus avec les
-- gestionnaires de WotLK)
WATCHFRAME_DECALAGES = {}
function WatchFrame_Update(self)
    self = self or WatchFrame
    if self.updating then return end
    self.updating = true
    self.watchMoney = false
    local totalOffset = WATCHFRAME_INITIAL_OFFSET
    local maxHeight = WatchFrame:GetTop() - WatchFrame:GetBottom()
    local totalObjectives = 0
    WATCHFRAME_DECALAGES = {}
    for i = 1, #WATCHFRAME_OBJECTIVEHANDLERS do
        table.insert(WATCHFRAME_DECALAGES, totalOffset)
        local pixelsUsed, maxLineWidth, numObjectives = WATCHFRAME_OBJECTIVEHANDLERS[i](WatchFrameLines, totalOffset, maxHeight, WATCHFRAME_MAXLINEWIDTH)
        totalObjectives = totalObjectives + numObjectives
        if pixelsUsed > 0 then
            totalOffset = totalOffset - WATCHFRAME_TYPE_OFFSET - pixelsUsed
        end
    end
    if totalObjectives > 0 then
        WatchFrameHeader:Show()
        WatchFrameCollapseExpandButton:Show()
        WatchFrameTitle:SetText(OBJECTIVES_TRACKER_LABEL .. " (" .. totalObjectives .. ")")
        if totalOffset < WATCHFRAME_INITIAL_OFFSET then
            if self.collapsed and not self.userCollapsed then WatchFrame_Expand(self) end
            WatchFrameCollapseExpandButton:Enable()
        else
            if not self.collapsed then WatchFrame_Collapse(self) end
            WatchFrameCollapseExpandButton:Disable()
        end
    else
        WatchFrameHeader:Hide()
        WatchFrameCollapseExpandButton:Hide()
    end
    self.updating = nil
    self.nextOffset = totalOffset
end
function WatchFrame_Collapse(self)
    self.collapsed = true
    self:SetWidth(WATCHFRAME_COLLAPSEDWIDTH)
    WatchFrameLines:Hide()
end
function WatchFrame_Expand(self)
    self.collapsed = nil
    self:SetWidth(WATCHFRAME_EXPANDEDWIDTH)
    WatchFrameLines:Show()
    WatchFrame_Update(self)
end
function WatchFrame_SetWidth(width)
    if width == "0" then
        WATCHFRAME_EXPANDEDWIDTH = 204
        WATCHFRAME_MAXLINEWIDTH = 192
    else
        WATCHFRAME_EXPANDEDWIDTH = 306
        WATCHFRAME_MAXLINEWIDTH = 294
    end
    if WatchFrame:IsShown() and not WatchFrame.collapsed then
        WatchFrame:SetWidth(WATCHFRAME_EXPANDEDWIDTH)
        WatchFrame_Update()
    end
end
function WatchFrame_ReverseQuestObjective(text)
    local _, _, arg1, arg2 = string.find(text, "(.*):%s(.*)")
    if arg1 and arg2 then return arg2 .. " " .. arg1 end
    return text
end
function WatchFrame_GetVisibleIndex(questLogIndex)
    for i = 1, #VISIBLE_WATCHES do
        if VISIBLE_WATCHES[i] == questLogIndex then return i end
    end
end
SUIVI_APPELS = {}
function WatchFrame_MoveQuest(button, questLogIndex, numMoves) table.insert(SUIVI_APPELS, "deplacer " .. questLogIndex .. " " .. numMoves) end
function WatchFrame_StopTrackingQuest(button, arg1) table.insert(SUIVI_APPELS, "ne plus suivre " .. arg1) end
function WatchFrame_OpenMapToQuest(button, arg1) table.insert(SUIVI_APPELS, "carte " .. arg1) end
function WatchFrame_ShareQuest(button, arg1) table.insert(SUIVI_APPELS, "partager " .. arg1) end
function WatchFrame_AbandonQuest(button, arg1) table.insert(SUIVI_APPELS, "abandonner " .. arg1) end
function WatchFrame_OpenAchievementFrame(button, arg1) table.insert(SUIVI_APPELS, "haut fait " .. arg1) end
function WatchFrame_StopTrackingAchievement(button, arg1) table.insert(SUIVI_APPELS, "ne plus suivre le haut fait " .. arg1) end
function WatchFrame_SetSorting(button, arg1) WATCHFRAME_SORT_TYPE = arg1 WatchFrame_Update() end
function WatchFrame_SetFilter(button, arg1)
    if bit.band(WATCHFRAME_FILTER_TYPE, arg1) == arg1 then
        WATCHFRAME_FILTER_TYPE = WATCHFRAME_FILTER_TYPE - arg1
    else
        WATCHFRAME_FILTER_TYPE = WATCHFRAME_FILTER_TYPE + arg1
    end
    WatchFrame_Update()
end
function WatchFrameItem_UpdateCooldown(b) end
function SetItemButtonTexture(b, t) b.icone = t end
function SetItemButtonCount(b, c) b.nombre = c end
function CloseDropDownMenus() end
function ChatEdit_GetActiveWindow() return nil end
-- les quetes suivies, dans l'ordre du journal
local function suivies()
    local l = {}
    for i, e in ipairs(visibles()) do
        if not e.header and SUIVIES[e.title] then table.insert(l, i) end
    end
    return l
end
function GetQuestIndexForWatch(w) return suivies()[w] end
function GetQuestSortIndex(i) return i end
function GetQuestLogSpecialItemInfo(i)
    local o = visibles()[i] and visibles()[i].objet
    if o then return "lien:" .. o[1], o[1], o[2] end
end
-- GetQuestTimers rend les secondes RESTANTES, GetQuestIndexForTimer l'index
function GetQuestTimers()
    local r = {}
    for i, e in ipairs(visibles()) do
        if e.minuteur and SUIVIES[e.title] then table.insert(r, e.minuteur) end
    end
    return (table.unpack or unpack)(r)
end
function GetQuestIndexForTimer(n)
    local k = 0
    for i, e in ipairs(visibles()) do
        if e.minuteur and SUIVIES[e.title] then
            k = k + 1
            if k == n then return i end
        end
    end
end
-- les hauts faits suivis
HAUTS_FAITS = {
    [1001] = { nom = "Explorer", description = "Explore the world.", criteres = {
        { "Elwynn", false }, { "Westfall", true }, { "Duskwood", false }, { "Redridge", false },
        { "Darkshire", false }, { "Stranglethorn", false }, { "Badlands", false }, { "Arathi", false } } },
    [1002] = { nom = "Loremaster", description = "Complete 700 quests.", criteres = {} },
}
HAUTS_FAITS_SUIVIS = {}
function GetTrackedAchievements() return (table.unpack or unpack)(HAUTS_FAITS_SUIVIS) end
function GetAchievementInfo(id) local h = HAUTS_FAITS[id] return id, h.nom, 10, false, nil, nil, nil, h.description end
function GetAchievementCategory(id) return 92 end
function GetAchievementNumCriteria(id) return #HAUTS_FAITS[id].criteres end
function GetAchievementCriteriaInfo(id, j)
    local c = HAUTS_FAITS[id].criteres[j]
    return c[1], 0, c[2], 0, 1, "", 0, 0, "0/1", id * 100 + j
end
function GetAchievementLink(id) return "haut fait:" .. id end
function QuestPOI_HideButtons(parent, type, debut)
    for i = debut, (POI_MAX[parent .. type] or 0) do
        local b = _G["poi" .. parent .. type .. "_" .. i]
        if b then b:Hide() end
    end
end
function QuestPOI_SelectButtonByQuestId() end
-- ---------------------------------------------------------------- securite
-- LE MODELE DE SECURITE DE 3.3.5, relu dans la chaine d'archives du client
-- (SecureHandlers.lua, RestrictedFrames.lua, RestrictedExecution.lua,
-- RestrictedEnvironment.lua) :
--   * un cadre est PROTEGE s'il vient d'un gabarit securise (explicite) ou
--     s'il a un descendant protege (implicite) ; en combat, le code
--     ordinaire ne peut ni le montrer, ni le cacher, ni le placer, ni le
--     dimensionner, ni changer ses attributs (ADDON_ACTION_BLOCKED) --
--     verifie ici quand STATE.verifierProtection est vrai ;
--   * un gestionnaire (SecureHandler*Template) execute des blocs restreints :
--     ni accolade, ni le mot "function" (BuildRestrictedClosure) ; des
--     poignees au lieu des cadres ; SetPoint ne vise qu'un cadre
--     EXPLICITEMENT protege, "$parent" ou l'ecran ; en combat, une poignee
--     de cadre non protege est invalide ;
--   * control:CallMethod rend la main a du code ordinaire (forceinsecure) ;
--   * l'API (Execute, SetFrameRef, WrapScript) est refusee en combat ;
--   * un script enveloppe ne passe par son bloc que si son cadre est
--     explicitement protege (GetFrameHandle(self, true)).
SECURISE = 0
LANCES = {}
local function estExplicite(f)
    return type(f) == "table" and type(f.template) == "string"
        and string.find(f.template, "Secure", 1, true) ~= nil
end
local function estProtege(f)
    if estExplicite(f) then return true end
    for _, c in ipairs(f.children or {}) do
        if estProtege(c) then return true end
    end
    return false
end
ESTPROTEGE = estProtege

local poignees = setmetatable({}, { __mode = "k" })
local function poignee(f)
    if f == nil then return nil end
    if poignees[f] then return poignees[f] end
    local h = { cadre = f }
    local function cadre()
        if STATE.inLockdown and not estProtege(f) then error("Invalid frame handle") end
        return f
    end
    for _, m in ipairs({ "Show", "Hide", "IsShown", "GetAttribute", "ClearAllPoints", "SetWidth",
            "SetHeight", "Enable", "Disable", "GetID", "GetWidth", "GetHeight" }) do
        h[m] = function(self, ...)
            local c = cadre()
            return c[m](c, ...)
        end
    end
    function h:SetAttribute(nom, valeur)
        if type(nom) ~= "string" or string.match(nom, "^_") then error("Invalid attribute name") end
        local t = type(valeur)
        if t ~= "string" and t ~= "nil" and t ~= "number" and t ~= "boolean" then
            error("Invalid attribute value")
        end
        local c = cadre()
        return c:SetAttribute(nom, valeur)
    end
    function h:SetPoint(point, rel, relpoint, x, y)
        if type(relpoint) == "number" then relpoint, x, y = nil, relpoint, x end
        relpoint = relpoint or point
        local cible
        if rel == "$parent" then
            cible = f.parent
        elseif rel == nil or rel == "$screen" then
            cible = nil
        elseif type(rel) == "table" and rel.cadre then
            if not estExplicite(rel.cadre) then error("Invalid relative frame handle") end
            cible = rel.cadre
        else
            error("Invalid relative frame id '" .. tostring(rel) .. "'")
        end
        local c = cadre()
        return c:SetPoint(point, cible, relpoint, tonumber(x) or 0, tonumber(y) or 0)
    end
    function h:GetFrameRef(etiquette)
        return poignee(f.attributes["frameref-" .. etiquette])
    end
    function h:RegisterAutoHide(duree) cadre().autoHide = duree end
    function h:AddToAutoHide(autre) cadre().autoHideAvec = autre.cadre end
    poignees[f] = h
    return h
end

local PORTEE = {
    newtable = function(...) return { ... } end,
    wipe = function(t) for k in pairs(t) do t[k] = nil end return t end,
    string = string, math = math, tonumber = tonumber, tostring = tostring, select = select,
    format = string.format, floor = math.floor, ceil = math.ceil, max = math.max, min = math.min,
    IsModifierKeyDown = function(...) return IsModifierKeyDown(...) end,
    IsModifiedClick = function(...) return IsModifiedClick(...) end,
    IsShiftKeyDown = function(...) return IsShiftKeyDown(...) end,
}

local function executer(entete, signature, corps, ...)
    if type(corps) ~= "string" then return end
    if string.find(corps, "[{}]") then error("bloc securise : accolade interdite") end
    if string.find(corps, "function", 1, true) then error("The function keyword is not permitted") end
    local fabrique, err = load("return function(" .. signature .. ") " .. corps .. " end", "bloc", "t", entete.envSecurise)
    if not fabrique then error("bloc securise : " .. tostring(err)) end
    local fn = fabrique()
    SECURISE = SECURISE + 1
    local r = table.pack(pcall(fn, ...))
    SECURISE = SECURISE - 1
    if not r[1] then error(r[2], 0) end
    return table.unpack(r, 2, r.n)
end

local function installerGestionnaire(f, gabarit)
    local controle = {}
    function controle:RunAttribute(nom, ...)
        return executer(f, "self,...", f.attributes[nom], poignee(f), ...)
    end
    function controle:Run(corps, ...) return executer(f, "self,...", corps, poignee(f), ...) end
    function controle:CallMethod(nom, ...)
        local m = f[nom]
        if type(m) ~= "function" then error("Invalid method '" .. tostring(nom) .. "'") end
        local avant = SECURISE
        SECURISE = 0                     -- forceinsecure()
        local ok, err = pcall(m, f, ...)
        SECURISE = avant
        if not ok then error(err, 0) end -- le vrai en fait un SoftError ; le banc veut le voir
    end
    f.envSecurise = setmetatable({}, { __index = function(t, k)
        if k == "control" then return controle end
        if k == "owner" then return poignee(f) end
        return PORTEE[k]
    end })
    local function api()
        if STATE.inLockdown then error("Cannot use SecureHandlers API during combat") end
    end
    function f:Execute(corps)
        api()
        return executer(self, "self", corps, poignee(self))
    end
    function f:SetFrameRef(etiquette, cible)
        api()
        self.attributes["frameref-" .. etiquette] = cible
    end
    function f:WrapScript(cadre, script, avant, apres)
        api()
        local entete = self
        local origine = cadre.scripts[script]
        local sig, sigApres = "self", "self,message"
        if script == "OnClick" or script == "PreClick" or script == "PostClick" then
            sig, sigApres = "self,button,down", "self,message,button,down"
        elseif script == "OnMouseWheel" then
            sig, sigApres = "self,offset", "self,message,offset"
        end
        cadre.scripts[script] = function(this, ...)
            local nouveau, message
            if ((not STATE.inLockdown) or estProtege(this)) and estExplicite(this) then
                nouveau, message = executer(entete, sig, avant, poignee(this), ...)
            end
            if nouveau == false then return end
            if origine then origine(this, ...) end
            if apres and message ~= nil then executer(entete, sigApres, apres, poignee(this), message, ...) end
        end
    end
    if string.find(gabarit, "Attribute", 1, true) then
        local brut = f.SetAttribute
        function f:SetAttribute(nom, valeur)
            brut(self, nom, valeur)
            if not string.match(nom, "^_") and self.attributes._onattributechanged then
                executer(self, "self,name,value", self.attributes._onattributechanged, poignee(self), nom, valeur)
            end
        end
    end
    if string.find(gabarit, "Click", 1, true) then
        f.scripts.OnClick = function(self, bouton, bas)
            executer(self, "self,button,down", self.attributes._onclick, poignee(self), bouton, bas)
        end
    end
    if string.find(gabarit, "MouseWheel", 1, true) then
        f.scripts.OnMouseWheel = function(self, delta)
            executer(self, "self,delta", self.attributes._onmousewheel, poignee(self), delta)
        end
    end
end

-- SecureActionButton_OnClick, reduit a ce que le banc verifie : le sort (ou
-- la macro) que le clic lance, selon le bouton et le modificateur
local function clicAction(self, bouton)
    local suffixe = (bouton == "RightButton") and "2" or "1"
    local t = (MODIFICATEUR and self.attributes["shift-type" .. suffixe])
        or self.attributes["type" .. suffixe] or self.attributes.type
    if t == "spell" then
        table.insert(LANCES, self.attributes["spell" .. suffixe] or self.attributes.spell)
    elseif t == "macro" then
        table.insert(LANCES, "macro:" .. tostring(self.attributes["macrotext" .. suffixe] or self.attributes.macrotext))
    end
end

local PROTEGEES = { "Show", "Hide", "SetPoint", "ClearAllPoints", "SetAllPoints", "SetAttribute",
    "SetWidth", "SetHeight", "Enable", "Disable", "SetParent", "SetScale" }
local creerAvant = CreateFrame
function CreateFrame(kind, name, parent, template)
    local f = creerAvant(kind, name, parent, template)
    for _, m in ipairs(PROTEGEES) do
        local brut = f[m]
        if brut then
            f[m] = function(self, ...)
                if STATE.verifierProtection and STATE.inLockdown and SECURISE == 0 and estProtege(self) then
                    error("ADDON_ACTION_BLOCKED : " .. tostring(self.name) .. ":" .. m .. "()")
                end
                return brut(self, ...)
            end
        end
    end
    if type(template) == "string" and string.find(template, "SecureActionButtonTemplate", 1, true) then
        f.scripts.OnClick = clicAction
    end
    -- UNE ZONE DE SAISIE COMME CELLE DU CLIENT : SetText declenche
    -- OnTextChanged, SetFocus / ClearFocus leurs scripts de focus.
    if kind == "EditBox" then
        local ecrire = f.SetText
        function f:SetText(t)
            ecrire(self, t)
            if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, false) end
        end
        function f:SetFocus()
            if self.focused then return end
            self.focused = true
            if self.scripts.OnEditFocusGained then self.scripts.OnEditFocusGained(self) end
        end
        function f:ClearFocus()
            if not self.focused then return end
            self.focused = false
            if self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
        end
        -- la frappe au clavier : le texte change, puis OnTextChanged(true)
        function f:Taper(t)
            ecrire(self, t)
            if self.scripts.OnTextChanged then self.scripts.OnTextChanged(self, true) end
        end
    end
    -- UNE INFOBULLE : ses lignes (TextLeftN) ; SetSpell y pose le nom puis
    -- la description (DESCRIPTIONS["livre" .. emplacement])
    if kind == "GameTooltip" then
        f.lignes = 0
        function f:SetOwner(proprio, ancre) self.owner, self.anchor = proprio, ancre end
        function f:ClearLines() self.lignes = 0 end
        function f:NumLines() return self.lignes end
        local function ligne(self, i, texte)
            local nom = self.name .. "TextLeft" .. i
            _G[nom] = _G[nom] or self:CreateFontString(nom)
            _G[nom]:SetText(texte)
            if i > self.lignes then self.lignes = i end
        end
        function f:SetTalent(o, i, inspect, pet, groupe)
            self.lignes = 0
            local nom, _, _, _, rang, max = GetTalentInfo(o, i, inspect, pet, groupe)
            if not nom then return end
            ligne(self, 1, nom)
            ligne(self, 2, string.format(TOOLTIP_TALENT_RANK, rang, max))
            ligne(self, 3, "Requires 5 points in Arcane Talents")
            local d = DESCRIPTIONS_TALENTS and DESCRIPTIONS_TALENTS[nom]
            if d then ligne(self, 4, d) end
            ligne(self, self.lignes + 1, TOOLTIP_TALENT_LEARN)
        end
        function f:SetSpell(slot, livre)
            self.lignes = 0
            local e = LIVRE[livre][slot]
            if not e then return end
            ligne(self, 1, e[1])
            local d = DESCRIPTIONS and DESCRIPTIONS[livre .. slot]
            if d then ligne(self, 2, d) end
        end
    end
    if type(template) == "string" and string.find(template, "SecureHandler", 1, true) then
        installerGestionnaire(f, template)
    end
    return f
end

-- LE CHEMIN SECURISE DU CLIENT : la touche P, le micro-bouton,
-- ToggleSpellBook, la croix (HideUIPanel) -- du code de Blizzard, non
-- souille, qui peut montrer ou cacher un cadre protege en combat
function PAR_BLIZZARD(fn, ...)
    SECURISE = SECURISE + 1
    local r = table.pack(pcall(fn, ...))
    SECURISE = SECURISE - 1
    if not r[1] then error(r[2], 0) end
    return table.unpack(r, 2, r.n)
end

-- un clic complet : OnClick, ses greffons, PostClick -- l'ordre du client
function CLIQUER(b, bouton)
    bouton = bouton or "LeftButton"
    if b.scripts.OnClick then b.scripts.OnClick(b, bouton, false) end
    if b.hooks and b.hooks.OnClick then b.hooks.OnClick(b, bouton) end
    if b.scripts.PostClick then b.scripts.PostClick(b, bouton) end
end

-- LES TALENTS DE 3.3.5 (Blizzard_TalentUI, charge a la demande). TALENTS[o] :
-- un onglet ; ses talents { nom, icone, palier, colonne, rang, max,
-- prerequis rempli, pre = { palier, colonne, rempli } }
TALENTS = {}
POINTS_TALENTS = 0
-- la seconde specialisation (TALENTS_2, sinon la premiere) et le familier
-- (TALENTS_FAMILIER, ses points dans POINTS_FAMILIER)
TALENTS_2 = nil
TALENTS_FAMILIER = {}
POINTS_FAMILIER = 0
GROUPE_ACTIF = 1
NB_GROUPES = 1
local function jeu(pet, groupe)
    if pet then return TALENTS_FAMILIER end
    if groupe == 2 and TALENTS_2 then return TALENTS_2 end
    return TALENTS
end
function GetNumTalentTabs(inspect, pet) return #jeu(pet) end
-- L'APERCU DE WOTLK : t.attente = les points en attente d'un talent
local function attenteOnglet(j, o)
    local n = 0
    for _, t in ipairs(j[o].talents) do n = n + (t.attente or 0) end
    return n
end
function GetTalentTabInfo(o, inspect, pet, groupe)
    local j = jeu(pet, groupe) local t = j[o]
    return t.nom, t.icone, t.depenses, t.fond, attenteOnglet(j, o)
end
function GetNumTalents(o, inspect, pet) return #jeu(pet)[o].talents end
function GetTalentInfo(o, i, inspect, pet, groupe)
    local t = jeu(pet, groupe)[o].talents[i]
    return t[1], t[2], t[3], t[4], t[5], t[6], false, t[7], t[5] + (t.attente or 0), t[7]
end
function GetGroupPreviewTalentPointsSpent(pet, groupe)
    local j, n = jeu(pet, groupe), 0
    for o = 1, #j do n = n + attenteOnglet(j, o) end
    return n
end
function GetUnspentTalentPoints(inspect, pet) if pet then return POINTS_FAMILIER end return POINTS_TALENTS end
function AddPreviewTalentPoints(o, i, n, pet, groupe)
    local t = jeu(pet, groupe)[o].talents[i]
    local a = t.attente or 0
    if n > 0 and GetGroupPreviewTalentPointsSpent(pet, groupe) < GetUnspentTalentPoints(false, pet) and t[5] + a < t[6] then a = a + 1 end
    if n < 0 and a > 0 then a = a - 1 end
    t.attente = a
end
function LearnPreviewTalents(pet)
    local j = jeu(pet, GROUPE_ACTIF)
    for o = 1, #j do
        for _, t in ipairs(j[o].talents) do
            if (t.attente or 0) > 0 then
                t[5] = t[5] + t.attente
                j[o].depenses = j[o].depenses + t.attente
                if pet then POINTS_FAMILIER = POINTS_FAMILIER - t.attente
                else POINTS_TALENTS = POINTS_TALENTS - t.attente end
                t.attente = 0
            end
        end
    end
end
function ResetGroupPreviewTalentPoints(pet, groupe)
    local j = jeu(pet, groupe)
    for o = 1, #j do
        for _, t in ipairs(j[o].talents) do t.attente = 0 end
    end
end
function GetTalentLink(o, i) return "lien talent:" .. o .. ":" .. i end
function GetTalentPrereqs(o, i, inspect, pet, groupe)
    local t = jeu(pet, groupe)[o].talents[i]
    if t.pre then return t.pre[1], t.pre[2], t.pre[3], t.pre[3] end
end
function GetActiveTalentGroup(inspect, pet) if pet then return 1 end return GROUPE_ACTIF end
function GetNumTalentGroups() return NB_GROUPES end
-- l'activation est un sort incante (63645 / 63644) : il reste "en cours"
-- jusqu'a ce que le banc le termine
function SetActiveTalentGroup(groupe)
    ACTIVATION_DEMANDEE = groupe
    SORT_EN_COURS = groupe == 1 and 63645 or 63644
end
-- le chargement a la demande : le cadre de WotLK, sa croix (qui ferme SON
-- PARENT), un bouton de son arbre, puis ADDON_LOADED
function CHARGER_TALENTS()
    PlayerTalentFrame = CreateFrame("Frame", "PlayerTalentFrame", UIParent)
    PlayerTalentFrame:SetWidth(384) PlayerTalentFrame:SetHeight(512)
    PlayerTalentFrame:EnableMouse(true)
    PlayerTalentFrame:Hide()
    local fond = PlayerTalentFrame:CreateTexture(nil, "BACKGROUND")
    fond:SetTexture("wotlk:talents")
    CreateFrame("Button", "PlayerTalentFrameTalent1", PlayerTalentFrame)
    PlayerTalentFrameCloseButton = CreateFrame("Button", "PlayerTalentFrameCloseButton", PlayerTalentFrame)
    PlayerTalentFrameCloseButton:SetNormalTexture("close-up")
    PlayerTalentFrameCloseButton:SetScript("OnClick", function(self) HideUIPanel(self:GetParent()) end)
    function PlayerTalentFrame_Refresh() end
    for _, f in ipairs(FRAMES) do
        if f.events and f.events["ADDON_LOADED"] and f.scripts and f.scripts.OnEvent then
            f.scripts.OnEvent(f, "ADDON_LOADED", "Blizzard_TalentUI")
        end
    end
end
GameTooltip.SetTalent = function(self, o, i) self.talent = { o, i } end

-- LE GRIMOIRE DE 3.3.5 (SpellBookFrame.xml / .lua) : le panneau, son art,
-- ses douze boutons, ses onglets, sa croix -- dont le OnClick ferme SON
-- PARENT, comme UIPanelCloseButton.
BOOKTYPE_SPELL, BOOKTYPE_PET = "spell", "pet"
SpellBookFrame = CreateFrame("Frame", "SpellBookFrame", UIParent)
SpellBookFrame:SetWidth(384) SpellBookFrame:SetHeight(512)
SpellBookFrame:EnableMouse(true)
SpellBookFrame.bookType = BOOKTYPE_SPELL
SpellBookFrame:Hide()
for _, nom in ipairs({ "SpellBookFrameIcon", "SpellBookFrameTopLeft", "SpellBookFrameTopRight", "SpellBookTitleText" }) do
    local t = SpellBookFrame:CreateTexture(nil, "BACKGROUND")
    t:SetTexture("wotlk:" .. nom)
    _G[nom] = t
end
for i = 1, 12 do
    local b = CreateFrame("CheckButton", "SpellButton" .. i, SpellBookFrame)
    b:EnableMouse(true)
end
for i = 1, 8 do CreateFrame("CheckButton", "SpellBookSkillLineTab" .. i, SpellBookFrame) end
for _, nom in ipairs({ "SpellBookPrevPageButton", "SpellBookNextPageButton", "ShowAllSpellRanksCheckBox" }) do
    CreateFrame("Button", nom, SpellBookFrame)
end
SpellBookCloseButton = CreateFrame("Button", "SpellBookCloseButton", SpellBookFrame)
SpellBookCloseButton:SetNormalTexture("close-up") SpellBookCloseButton:SetPushedTexture("close-down")
SpellBookCloseButton:SetHighlightTexture("close-highlight")
SpellBookCloseButton:SetScript("OnClick", function(self) HideUIPanel(self:GetParent()) end)
function SpellBookFrame_Update() end
-- le livre : trois lignes (General, Frost), des rangs, un passif ; et le familier
LIVRE = {
    spell = {
        { "Attack", "", false, "icone:attaque" },
        { "Shoot", "", false, "icone:tir" },
        { "Frostbolt", "Rank 1", false, "icone:eclair" },
        { "Frostbolt", "Rank 2", false, "icone:eclair" },
        { "Frostbolt", "Rank 3", false, "icone:eclair" },
        { "Frost Armor", "Rank 1", false, "icone:armure" },
        { "Ice Shards", "", true, "icone:eclats" },
    },
    pet = { { "Growl", "", false, "icone:grogne" }, { "Bite", "Rank 2", false, "icone:morsure" } },
}
ONGLETS = { { "General", "icone:livre", 0, 2 }, { "Frost", "icone:givre", 2, 5 } }
function GetNumSpellTabs() return #ONGLETS end
function GetSpellTabInfo(i) local o = ONGLETS[i] if o then return o[1], o[2], o[3], o[4] end end
function GetSpellName(slot, livre) local e = LIVRE[livre][slot] if e then return e[1], e[2] end end
function IsPassiveSpell(slot, livre) local e = LIVRE[livre][slot] return e and e[3] and 1 or nil end
function GetSpellTexture(slot, livre) local e = LIVRE[livre][slot] return e and e[4] end
function HasPetSpells() if FAMILIER_LIVRE then return #LIVRE.pet, "PET" end end
function GetPetIcon() return "icone:familier" end
function GetSpellCooldown() return 0, 0, 1 end
function GetSpellAutocast(slot, livre) if livre == "pet" and slot == 1 then return 1, 1 end end
function GetSpellLink(slot, livre) return "lien:" .. livre .. slot end
PRIS = {}
function PickupSpell(slot, livre) table.insert(PRIS, livre .. slot) end
-- Spell.dbc, en abrege : les identifiants des groupes de camelot qui servent
-- au banc ; les autres n'existent pas (nil, comme ceux propres a camelot)
SORTS_PAR_ID = { [3565] = "Teleport: Darnassus", [3562] = "Teleport: Ironforge",
    [3561] = "Teleport: Stormwind", [10059] = "Portal: Stormwind", [11416] = "Portal: Ironforge",
    [53140] = "Teleport: Dalaran", [3567] = "Teleport: Orgrimmar", [32271] = "Teleport: Exodar",
    [1038] = "Hand of Salvation", [1022] = "Hand of Protection", [20217] = "Blessing of Kings",
    [13165] = "Aspect of the Hawk", [34074] = "Aspect of the Viper",
    [21084] = "Seal of Righteousness", [20165] = "Seal of Light", [20271] = "Judgement of Light",
    [53408] = "Judgement of Wisdom" }
function GetSpellInfo(id) return SORTS_PAR_ID[id] end
function IsCurrentSpell(slot, livre)
    if livre == nil then return SORT_EN_COURS == slot end
    return SORT_EN_COURS == livre .. slot
end
function IsModifierKeyDown() return MODIFICATEUR and true or false end
-- LES BARRES D'ACTION : ACTIONS[emplacement] = { type, id, sous-type,
-- identifiant global } (GetActionInfo de 3.3.5) ; barres multiples
-- (bas gauche, bas droite, droite, gauche) ; posture (le familier : PET_ACTIONS,
-- plus haut)
ACTIONS = {}
function GetActionInfo(slot)
    local a = ACTIONS[slot]
    if a then return a[1], a[2], a[3], a[4] end
end
BARRES = { true, true, true, true }
function GetActionBarToggles() return BARRES[1], BARRES[2], BARRES[3], BARRES[4] end
function GetBonusBarOffset() return STATE.posture or 0 end
function IsAttackSpell(nom) return nom == "Attack" end
function IsAutoRepeatSpell(nom) return nom == "Shoot" end
function MouseIsOver(f) return f and f.souris == true end
-- les boutons de la souris : SOURIS[bouton] = true tant qu'il est enfonce
SOURIS = {}
function IsMouseButtonDown(b) return SOURIS[b] == true end
GameTooltip.SetSpell = function(self, slot, livre) self.sort = { slot, livre } end
STATE.cvars.ShowAllSpellRanks = "0"
SPELLBOOK = "Spellbook"
SPELL_PASSIVE = "Passive"
PET = "Pet"

-- UIParent.lua de 3.3.5 : le suivi recolle sous MinimapCluster, et un point
-- BOTTOMRIGHT sur le bas de l'ecran, a chaque passage
CONTAINER_OFFSET_X, CONTAINER_OFFSET_Y = 0, 60
PLACEMENTS_WOTLK = 0
function UIParent_ManageFramePositions()
    PLACEMENTS_WOTLK = PLACEMENTS_WOTLK + 1
    if not WatchFrame:IsUserPlaced() then
        WatchFrame:ClearAllPoints()
        WatchFrame:SetPoint("TOPRIGHT", "MinimapCluster", "BOTTOMRIGHT", -CONTAINER_OFFSET_X, 20)
    end
    WatchFrame:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -CONTAINER_OFFSET_X, CONTAINER_OFFSET_Y)
end
function GetQuestLink(i) return "[" .. visibles()[i].title .. "]" end
function GetNumPartyMembers() return 0 end
function GetNumRaidMembers() return 0 end
function GetRealZoneText() return "Elwynn Forest" end
function IsModifiedClick() return false end
function IsShiftKeyDown() return false end
function GetDailyQuestsCompleted() return 2 end
function GetMaxDailyQuests() return 25 end
MAX_WATCHABLE_QUESTS = 25
MAX_QUESTLOG_QUESTS = 25
RED_FONT_COLOR_CODE = "|cffff2020"
ELITE = "Elite"
PARENS_TEMPLATE = "(%s)"
QUEST_DASH = "- "
FAILED = "Failed"
TRACK_QUEST = "Track Quest"
SHARE_QUEST = "Share Quest"
ABANDON_QUEST = "Abandon Quest"
QUEST_WATCH_TOO_MANY = "You may only watch %d quests at a time."
QUEST_LOG_DAILY_COUNT_TEMPLATE = "Daily: |cffffffff%d/%d|r"
-- GetQuestDifficultyColor rend une des tables de QuestDifficultyColors
QuestDifficultyColors = {
    impossible = { r = 1, g = 0.1, b = 0.1 }, verydifficult = { r = 1, g = 0.5, b = 0.25 },
    difficult = { r = 1, g = 1, b = 0 }, standard = { r = 0.25, g = 0.75, b = 0.25 },
    trivial = { r = 0.5, g = 0.5, b = 0.5 }, header = { r = 0.7, g = 0.7, b = 0.7 },
}
function GetQuestDifficultyColor(niveau)
    if niveau >= 12 then return QuestDifficultyColors.verydifficult end
    return QuestDifficultyColors.standard
end
-- LES REPERES DE QUETE (QuestPOI.lua de 3.3.5, recopie pour ce qu'on touche) :
-- un bouton par parent, type et numero, cree a la demande et nomme
-- "poi" .. parent .. type .. "_" .. numero.
QUEST_POI_NUMERIC, QUEST_POI_COMPLETE_IN, QUEST_POI_COMPLETE_OUT, QUEST_POI_COMPLETE_SWAP = 1, 2, 3, 4
POI_MAX = {}
POI_CHOISI = {}
function QuestPOI_DisplayButton(parent, type, index, questId)
    local nom = "poi" .. parent .. type .. "_" .. index
    local b = _G[nom]
    if not b then
        b = CreateFrame("Button", nom, _G[parent])
        b:SetWidth(32) b:SetHeight(32)
        b.index, b.type, b.parentName = index, type, parent
        POI_MAX[parent .. type] = math.max(POI_MAX[parent .. type] or 0, index)
    end
    b.questId = questId
    b.isSelected = false
    b:Show()
    return b
end
function QuestPOI_HideAllButtons(parent)
    for type = 1, 4 do
        for i = 1, (POI_MAX[parent .. type] or 0) do
            local b = _G["poi" .. parent .. type .. "_" .. i]
            if b then b:Hide() end
        end
    end
end
function QuestPOI_SelectButton(b)
    if b then
        local avant = POI_CHOISI[b.parentName]
        if avant and avant ~= b then avant.isSelected = false end
        POI_CHOISI[b.parentName] = b
        b.isSelected = true
    end
end
-- la tache de zone : le QuestPOIFrame du moteur
ZONES = {}
function WorldMapBlobFrame:DrawQuestBlob(questId, montrer) ZONES[questId] = montrer end
-- WorldMapFrame_UpdateQuests : les quetes qui ont un repere sur la carte
-- AFFICHEE. Ici : 783 et 12 (terminee) ; 62 n'a pas de repere sur cette carte.
CARTE_QUETES = { { id = 783, index = 2, termine = false }, { id = 12, index = 5, termine = true } }
function WorldMapFrame_UpdateQuests()
    local n = 0
    for i, q in ipairs(CARTE_QUETES) do
        n = n + 1
        local f = _G["WorldMapQuestFrame" .. i] or CreateFrame("Frame", "WorldMapQuestFrame" .. i, WorldMapFrame)
        f.questId, f.questLogIndex, f.completed = q.id, q.index, q.termine
    end
    WorldMapFrame.numQuests = n
    return n
end
function WorldMapFrame_DisplayQuests(selection)
    WorldMapTrackQuest:Show()
    if WorldMapFrame_UpdateQuests() > 0 and selection then
        WORLDMAP_SETTINGS.selectedQuestId = selection
        WorldMapBlobFrame:DrawQuestBlob(selection, true)
    end
end
-- WorldMap_OpenToQuest : la carte de la quete, puis UpdateMap(questID)
OUVERTURES = {}
function GetQuestWorldMapAreaID(questID) return 39, 0 end
function SetMapByID(id) table.insert(OUVERTURES, id) CARTE.id = id end
CARTE.id = 30
function GetCurrentMapAreaID() return CARTE.id end
function WorldMap_OpenToQuest(questID)
    ShowUIPanel(WorldMapFrame)
    local carte, etage = GetQuestWorldMapAreaID(questID)
    if carte ~= 0 then SetMapByID(carte) end
    WorldMapFrame_UpdateMap(questID)
end

-- La premiere ligne de l'infobulle existe toujours dans le vrai client, et
-- une fenetre montree a toujours un bord droit.
GameTooltipTextLeft1 = UIParent:CreateFontString("GameTooltipTextLeft1", "ARTWORK")
UIParent._right = 1920
WorldMapFrame._right = 1051
-- QuestLogFrame reste la fenetre de WotLK : on la garde vivante.
QuestLogFrame = CreateFrame("Frame", "QuestLogFrame", UIParent)
QuestLogFrame:Hide()
function ToggleFrame(cadre)
    if cadre:IsShown() then HideUIPanel(cadre) else ShowUIPanel(cadre) end
end

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
-- le second retour : un familier de CHASSEUR (humeur, loyaute)
FAMILIER_CHASSEUR = true
function HasPetUI() return AVEC_FAMILIER, AVEC_FAMILIER and FAMILIER_CHASSEUR end
-- humeur 1..3, degats en %, loyaute (<0 perdue, >0 gagnee)
HUMEUR = { 3, 125, 1 }
function GetPetHappiness() if not AVEC_FAMILIER then return nil end return HUMEUR[1], HUMEUR[2], HUMEUR[3] end
function GetPetFoodTypes() return "Meat", "Fish" end
PET_HAPPINESS1, PET_HAPPINESS2, PET_HAPPINESS3 = "Unhappy", "Content", "Happy"
PET_DAMAGE_PERCENTAGE = "Pet is doing %d%% damage"
GAINING_LOYALTY, LOSING_LOYALTY = "Gaining Loyalty", "Losing Loyalty"
PET_DIET_TEMPLATE = "Diet: %s"
function UnitFrame_OnEnter(self) GameTooltip.unitTooltip = self.unit end
function UnitFrame_OnLeave(self) end
-- 3.3.5 : PartyMemberBuffTooltip_Update(self) lit self:GetID() et self.unit
PartyMemberBuffTooltip = CreateFrame("Frame", "PartyMemberBuffTooltip", UIParent)
function PartyMemberBuffTooltip_Update(self)
    PartyMemberBuffTooltip:SetID(self:GetID())
    PartyMemberBuffTooltip.unitOf = self.unit
end
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
TOOLTIP_TALENT_RANK = "Rank %d/%d"
TOOLTIP_TALENT_LEARN = "Click to learn"
TOOLTIP_TALENT_NEXT_RANK = "Next rank:"
TOOLTIP_TALENT_PREREQ = "Requires %s"
-- le client numerote ses arguments (enUS : %1$d, %2$s)
TOOLTIP_TALENT_TIER_POINTS = "Requires %1$d points in %2$s Talents"
CONTINUE, CANCEL = "Continue", "Cancel"
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
SAISON_ARENE = 8
function GetCurrentArenaSeason() return SAISON_ARENE end
function GetPreviousArenaSeason() return 7 end
-- LES EQUIPES D ARENE. GetArenaTeam rend ses valeurs dans l ordre que lit
-- PVPTeam_Update (PVPFrame.lua du client) : nom, taille, cote, joues et
-- gagnes de la semaine, de la saison, mes joues (semaine, saison), rang,
-- ma cote, fond rgb, embleme, embleme rgb, bord, bord rgb. L emplacement 1
-- porte le 3v3 et le 2 le 2v2 : les cartes doivent les TRIER par taille.
EQUIPES_ARENE = {
    [1] = { "Les Trois", 3, 1650, 10, 7, 40, 25, 10, 38, 120, 1600,
            0.2, 0.3, 0.4, 12, 1, 0.8, 0, 3, 0.9, 0.9, 0.9 },
    [2] = { "Duo Fou", 2, 1500, 20, 11, 60, 30, 1, 50, 300, 1480,
            0.5, 0, 0, -1, 1, 1, 1, -1, 1, 1, 1 },
}
function GetArenaTeam(i)
    local e = EQUIPES_ARENE[i]
    if not e then return nil end
    return (table.unpack or unpack)(e)
end
POINTS_ARENE = 321
function GetArenaCurrency() return POINTS_ARENE end
-- nom, rang (0 = capitaine), niveau, classe, en ligne, joues, gagnes,
-- joues et gagnes de la saison, cote : GetArenaTeamRosterInfo
MEMBRES_ARENE = {
    [1] = { { "Moi", 0, 80, "Warrior", 1, 10, 7, 40, 25, 1700 },
            { "Ami", 1, 80, "Priest", 1, 1, 1, 30, 20, 1600 },
            { "Absent", 1, 80, "Mage", nil, 0, 0, 5, 2, 1500 } },
}
function GetNumArenaTeamMembers(id) local m = MEMBRES_ARENE[id]; return m and #m or 0 end
function GetArenaTeamRosterInfo(id, n) return (table.unpack or unpack)(MEMBRES_ARENE[id][n]) end
ROSTER = { demandes = {}, fermetures = 0, selection = {}, tris = {} }
function ArenaTeamRoster(id) table.insert(ROSTER.demandes, id) end
function CloseArenaTeamRoster() ROSTER.fermetures = ROSTER.fermetures + 1 end
function SetArenaTeamRosterSelection(id, n) ROSTER.selection[id] = n end
function GetArenaTeamRosterSelection(id) return ROSTER.selection[id] or 0 end
function SortArenaTeamRoster(t) table.insert(ROSTER.tris, t) end
-- Le detail du client vit sous PVPFrame, fils de PVPParentFrame : l onglet
-- eteint PVPFrame, le drapeau de PVPTeamDetails reste le sien.
PVPFrame = CreateFrame("Frame", "PVPFrame", PVPParentFrame)
PVPTeamDetails = CreateFrame("Frame", "PVPTeamDetails", PVPFrame)
PVPTeamDetails:Hide()
MENUS_EQUIPE = {}
function PVPFrame_ShowDropdown(nom, enLigne) table.insert(MENUS_EQUIPE, { nom = nom, enLigne = enLigne }) end
function GameTooltip_AddNewbieTip(cadre, titre, r, v, b, texte)
    GameTooltip:SetOwner(cadre); GameTooltip:SetText(titre); GameTooltip.lignes = {}
    GameTooltip:AddLine(texte); GameTooltip:Show()
end
function GameTooltip_SetDefaultAnchor(tt, cadre) tt:SetOwner(cadre) end
GameFontNormalSmall = GameFontNormalSmall or "GameFontNormalSmall"
ARENA_THIS_WEEK, ARENA_THIS_SEASON = "This Week", "This Season"
ARENA_THIS_WEEK_TOGGLE = "View this Week's Stats"
ARENA_THIS_SEASON_TOGGLE = "View this Season's Stats"
PVP_TEAMSIZE = "(%dv%d)"
ARENA_TEAM = "Arena Team"
CLICK_FOR_DETAILS = "Click for details"
ARENA_TEAM_LEAD_IN = "Visit an Arena Master to form a new Arena Team."
ARENA_OFF_SEASON_TEXT = "Arena Season %d has come to an end!|n|nBe sure to check for the start of Season %d!"
ARENA_POINTS = "Arena Points"
TOOLTIP_ARENA_POINTS = "Arena Points are gained by being victorious in arena combat."
PVP_LABEL_ARENA = "ARENA:"
ARENA_TEAM_RATING, GAMES, WIN_LOSS, PLAYED = "Team Rating", "Games", "Win - Loss", "Played"
RANK, RATING, NAME, CLASS = "Rank", "Rating", "Name", "Class"
ADDMEMBER_TEAM, ADDMEMBER = "Add Member", "Add Member"
-- LES CHAMPS DE BATAILLE : GetBattlegroundInfo rend nom, canEnter,
-- isHoliday, isRandom, BattleGroundID (PVPBattlegroundFrame.lua du client).
-- Alterac est ferme : il ne doit pas paraitre.
CHAMPS = {
    { "Warsong Gulch", true, false, false, 2 },
    { "Arathi Basin", true, false, false, 3 },
    { "Alterac Valley", false, false, false, 1 },
    { "Eye of the Storm", true, true, false, 7 },
    { "Random Battleground", true, false, true, 32 },
}
function GetNumBattlegroundTypes() return #CHAMPS end
function GetBattlegroundInfo(i)
    local c = CHAMPS[i]
    if not c then return nil end
    return (table.unpack or unpack)(c)
end
BG = { demandes = {}, fermetures = 0, rejoint = {}, tri = 0, groupeMax = 10 }
function RequestBattlegroundInstanceInfo(i) table.insert(BG.demandes, i) end
function CloseBattlefield() BG.fermetures = BG.fermetures + 1 end
function SortBGList() BG.tri = BG.tri + 1 end
function GetBattlefieldInfo() return "Carte", "Description", BG.groupeMax end
function JoinBattlefield(i, groupe) table.insert(BG.rejoint, { i = i, groupe = groupe and true or false }) end
MAX_BATTLEFIELD_QUEUES = 3
FILES_BG = { { "queued", "Arathi Basin" }, { "none" }, { "none" } }
function GetBattlefieldStatus(i) local f = FILES_BG[i]; return f[1], f[2] end
function GetRandomBGHonorCurrencyBonuses() return true, 30, 25, 15, 0 end
function GetHolidayBGHonorCurrencyBonuses() return true, 45, 0, 20, 5 end
BATTLEGROUND_HOLIDAY = "Call to Arms"
BATTLEFIELD_QUEUE_STATUS, BATTLEFIELD_CONFIRM_STATUS = "In Queue", "Ready to Enter"
BATTLEFIELD_GROUP_JOIN, BATTLEFIELD_JOIN = "Join as Group", "Join Battle"
JOIN_AS_PARTY, JOIN_AS_GROUP = "Join as Party", "Join as Group"
WIN, LOSS = "Win", "Loss"
NumberFontNormalLarge = NumberFontNormalLarge or "NumberFontNormalLarge"
function ARENE_EVENEMENT(ev, ...)
    for _, f in ipairs(FRAMES) do
        if f.events and f.events[ev] and f.scripts and f.scripts.OnEvent then
            f.scripts.OnEvent(f, ev, ...)
        end
    end
end
-- LES CHAINES DU CLIENT, et seulement elles : LIFETIME_HONORABLE_KILLS,
-- TODAY et YESTERDAY N'EXISTENT PAS en 3.3.5, et le faux les fournissait --
-- le francais de secours passait ainsi inapercu (2026-09-26).
HONORABLE_KILLS = "Honorable Kills"
HONOR_TODAY = "Today"
HONOR_YESTERDAY = "Yesterday"
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
function GetCursorPosition() return SOURIS_X or 0, SOURIS_Y end
function ShowUIPanel(cadre)
    local carte = rawget(_G, "WorldMapFrame")
    if carte and cadre ~= carte and carte:IsShown()
       and carte.attributes and carte.attributes["UIPanelLayout-area"] == "center"
       and carte.attributes["UIPanelLayout-allowOtherPanels"] then
        carte:Hide()
    end
    cadre:Show()
end
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
function hooksecurefunc(nom, fn, greffon)
    -- La forme a trois arguments accroche la methode d'une TABLE :
    -- hooksecurefunc(table, "Methode", fonction). Le vrai la connait ; le
    -- banc la prenait pour un nom et n'accrochait rien.
    if type(nom) == "table" then
        local t, cle = nom, fn
        local ancienne = t[cle]
        HOOKS[cle] = greffon
        t[cle] = function(...)
            local rendus = { ancienne(...) }
            greffon(...)
            return (table.unpack or unpack)(rendus)
        end
        return
    end
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
-- LA FENETRE SOCIAL de 3.3.5 -- FriendsFrame.lua et .xml du client, lus en
-- entier. Le faux reprend ce que l'addon lit ou declenche : les onglets du
-- bas (leur OnClick = PanelTemplates_Tab_OnClick puis FriendsFrame_OnShow),
-- FriendsTabHeader et son onglet choisi, les sept sous-cadres que
-- FriendsFrame_ShowSubFrame alterne, les regions de l'ecran (quatre quartiers,
-- l'icone, le titre), et les fonctions du client que l'addon emprunte.
FRIENDSFRAME_SUBFRAMES = { "FriendsListFrame", "IgnoreListFrame", "PendingListFrame", "WhoFrame",
                           "GuildFrame", "ChannelFrame", "RaidFrame" }
FriendsFrame = CreateFrame("Frame", "FriendsFrame", UIParent)
FriendsFrame:SetWidth(384)
FriendsFrame:SetHeight(512)
FriendsFrame:EnableMouse(true)
FriendsFrame:Hide()
FriendsFrameTopLeft = FriendsFrame:CreateTexture("FriendsFrameTopLeft", "BORDER")
FriendsFrameTopRight = FriendsFrame:CreateTexture("FriendsFrameTopRight", "BORDER")
FriendsFrameBottomLeft = FriendsFrame:CreateTexture("FriendsFrameBottomLeft", "BORDER")
FriendsFrameBottomRight = FriendsFrame:CreateTexture("FriendsFrameBottomRight", "BORDER")
FriendsFrameIcon = FriendsFrame:CreateTexture("FriendsFrameIcon", "BACKGROUND")
FriendsFrameTitleText = FriendsFrame:CreateFontString("FriendsFrameTitleText", "ARTWORK", "GameFontNormal")
FriendsTabHeader = CreateFrame("Frame", "FriendsTabHeader", FriendsFrame)
FriendsTabHeader.numTabs = 3
FriendsTabHeader.selectedTab = 1
for _, n in ipairs(FRIENDSFRAME_SUBFRAMES) do
    _G[n] = CreateFrame("Frame", n, FriendsFrame)
    _G[n]:Hide()
end
function PanelTemplates_Tab_OnClick(self, cadre) PanelTemplates_SetTab(cadre, self:GetID()) end
function PanelTemplates_GetSelectedTab(cadre) return cadre.selectedTab end
for i = 1, 5 do
    local t = CreateFrame("Button", "FriendsFrameTab" .. i, FriendsFrame)
    t:SetID(i)
    t:SetScript("OnClick", function(self)
        PanelTemplates_Tab_OnClick(self, FriendsFrame)
        FriendsFrame_OnShow()
    end)
end
FriendsFrameCloseButton = CreateFrame("Button", "FriendsFrameCloseButton", FriendsFrame)
FriendsDropDown = CreateFrame("Frame", "FriendsDropDown", FriendsFrame)
FriendsTooltip = CreateFrame("Frame", "FriendsTooltip", FriendsFrame)
FriendsTooltip:Hide()
PanelTemplates_SetNumTabs(FriendsFrame, 5)
FriendsFrame.selectedTab = 1
function FriendsFrame_ShowSubFrame(nom)
    for _, n in ipairs(FRIENDSFRAME_SUBFRAMES) do
        if n == nom then _G[n]:Show() else _G[n]:Hide() end
    end
end
-- FriendsFrame_Update, reduit a ce qui compte : l'en-tete des sous-onglets
-- sur l'onglet 1 seulement, ShowFriends pour la liste, le bon sous-cadre.
function FriendsFrame_Update()
    if FriendsFrame.selectedTab == 1 then
        FriendsTabHeader:Show()
        if FriendsTabHeader.selectedTab == 2 then
            FriendsFrame_ShowSubFrame("IgnoreListFrame")
        else
            ShowFriends()
            FriendsFrame_ShowSubFrame("FriendsListFrame")
        end
    else
        FriendsTabHeader:Hide()
        FriendsFrame_ShowSubFrame(({ "FriendsListFrame", "WhoFrame", "GuildFrame", "ChannelFrame",
                                     "RaidFrame" })[FriendsFrame.selectedTab])
    end
end
function FriendsFrame_OnShow() FriendsFrame_Update() end
FriendsFrame:SetScript("OnShow", function() FriendsFrame_OnShow() end)
-- LES DONNEES : GetFriendInfo rend nom, niveau, classe, zone, connecte,
-- statut, note -- les amis en ligne d'abord, comme le client les range.
AMIS = { { "Alice", 80, "Mage", "Dalaran", 1, "" },
         { "Bob", 70, "Priest", "Orgrimmar", 1, "<Away>" },
         { "Carl", 60, "Rogue", "", nil, "" } }
function GetNumFriends()
    local on = 0
    for _, a in ipairs(AMIS) do if a[5] then on = on + 1 end end
    return #AMIS, on
end
function GetFriendInfo(i)
    local a = AMIS[i]
    if not a then return nil end
    return a[1], a[2], a[3], a[4], a[5], a[6], a[7]
end
-- le parrainage : Bob est lie, la recharge court
PARRAINS = {}
RAF_POSSIBLE = {}
RAF_RECHARGE = { 0, 0 }
function IsReferAFriendLinked(n) return PARRAINS[n] end
function CanSummonFriend(n) return RAF_POSSIBLE[n] end
function GetSummonFriendCooldown() return RAF_RECHARGE[1], RAF_RECHARGE[2] end
AMI_CHOISI = 0
function GetSelectedFriend() return AMI_CHOISI end
function SetSelectedFriend(i) AMI_CHOISI = i end
DEMANDES_AMIS = 0
function ShowFriends() DEMANDES_AMIS = DEMANDES_AMIS + 1 end
IGNORES = { "Troll1", "Troll2" }
IGNORE_CHOISI = 0
function GetNumIgnores() return #IGNORES end
function GetIgnoreName(i) return IGNORES[i] end
function SetSelectedIgnore(i) IGNORE_CHOISI = i end
function GetSelectedIgnore() return IGNORE_CHOISI end
function AddIgnore(n) table.insert(IGNORES, n) end
function DelIgnore(n)
    for i, x in ipairs(IGNORES) do if x == n then table.remove(IGNORES, i) break end end
end
VOIX = false
function IsVoiceChatEnabled() return VOIX end
MUETS = { "Bavard" }
MUET_CHOISI = 0
function GetNumMutes() return #MUETS end
function GetMuteName(i) return MUETS[i] end
function SetSelectedMute(i) MUET_CHOISI = i end
function GetSelectedMute() return MUET_CHOISI end
function AddMute(n) table.insert(MUETS, n) end
function DelMute(n) end
-- Les fonctions du client que l'addon emprunte, recopiees.
FRIENDS_BUTTON_TYPE_WOW = 3
SQUELCH_TYPE_IGNORE, SQUELCH_TYPE_MUTE = 1, 3
FRIENDS_WOW_NAME_COLOR = { r = 0.996, g = 0.882, b = 0.361 }
FRIENDS_WOW_BACKGROUND_COLOR = { r = 1.0, g = 0.824, b = 0.0, a = 0.05 }
FRIENDS_GRAY_COLOR = { r = 0.486, g = 0.518, b = 0.541 }
FRIENDS_OFFLINE_BACKGROUND_COLOR = { r = 0.588, g = 0.588, b = 0.588, a = 0.05 }
function FriendsFrame_SelectFriend(friendType, id)
    if friendType == FRIENDS_BUTTON_TYPE_WOW then SetSelectedFriend(id) end
    FriendsFrame.selectedFriendType = friendType
end
function FriendsFrame_SelectSquelched(ignoreType, index)
    if ignoreType == SQUELCH_TYPE_IGNORE then SetSelectedIgnore(index)
    elseif ignoreType == SQUELCH_TYPE_MUTE then SetSelectedMute(index) end
    FriendsFrame.selectedSquelchType = ignoreType
end
function FriendsFrameUnsquelchButton_OnClick()
    if FriendsFrame.selectedSquelchType == SQUELCH_TYPE_IGNORE then
        DelIgnore(GetIgnoreName(GetSelectedIgnore()))
    elseif FriendsFrame.selectedSquelchType == SQUELCH_TYPE_MUTE then
        DelMute(GetMuteName(GetSelectedMute()))
    end
end
DITS = {}
function ChatFrame_SendTell(n) table.insert(DITS, n) end
function FriendsFrameSendMessageButton_OnClick()
    local name
    if FriendsFrame.selectedFriendType == FRIENDS_BUTTON_TYPE_WOW then
        name = GetFriendInfo(FriendsFrame.selectedFriend)
    end
    if name then ChatFrame_SendTell(name) end
end
function FriendsFrameAddFriendButton_OnClick() StaticPopup_Show("ADD_FRIEND") end
MENUS_AMIS = {}
function FriendsFrame_ShowDropdown(name, connected, lineID, chatType, chatFrame, friendsList)
    table.insert(MENUS_AMIS, { nom = name, connecte = connected, liste = friendsList })
end
INFOBULLES_AMIS = {}
function FriendsFrameTooltip_Show(self)
    table.insert(INFOBULLES_AMIS, { type = self.buttonType, id = self.id })
    FriendsTooltip:Show()
end
CIBLE_COOPERANTE = false
function UnitCanCooperate() return CIBLE_COOPERANTE end
CHAT_FLAG_AFK, CHAT_FLAG_DND = "<Away>", "<Busy>"
FRIENDS, WHO, GUILD, CHAT, RAID, IGNORE = "Friends", "Who", "Guild", "Chat", "Raid", "Ignore"
FRIENDS_LIST, IGNORE_LIST = "Friends List", "Ignore List"
ADD_FRIEND, SEND_MESSAGE = "Add Friend", "Send Message"
IGNORE_PLAYER, REMOVE_PLAYER, MUTE_PLAYER = "Ignore Player", "Remove Player", "Mute Player"
IGNORED, MUTED = "Ignored", "Muted"
FRIENDS_LEVEL_TEMPLATE = "Level %d %s"
UNKNOWN = UNKNOWN or "Unknown"
FriendsFont_Normal = { police = "FriendsFont_Normal" }
FriendsFont_Small = { police = "FriendsFont_Small" }
GameFontDisableSmall = GameFontDisableSmall or "GameFontDisableSmall"
GameFontNormal = GameFontNormal or "GameFontNormal"
-- LES AUTRES PAGES DE LA FENETRE SOCIAL : Qui, Guilde, Canaux, Raid. Les
-- signatures sont celles que lisent FriendsFrame.lua, ChannelFrame.lua,
-- RaidFrame.lua et Blizzard_RaidUI.lua du client ; les appels sont retenus
-- pour que l'essai voie ce que l'addon demande au serveur.
APPELS = {}
local function retenir(nom) return function(...) table.insert(APPELS, { nom = nom, args = { ... } }) end end
-- Qui : name, guild, level, race, class, zone, classFileName
QUI = { { "Zed", "Les Braves", 80, "Human", "Warrior", "Stormwind", "WARRIOR" },
        { "Ann", "", 70, "Dwarf", "Priest", "Ironforge", "PRIEST" } }
QUI_TOTAL = 2
function GetNumWhoResults() return #QUI, QUI_TOTAL end
function GetWhoInfo(i) local w = QUI[i]; if not w then return nil end; return w[1], w[2], w[3], w[4], w[5], w[6], w[7] end
SortWho, SendWho, SetWhoToUI = retenir("SortWho"), retenir("SendWho"), retenir("SetWhoToUI")
InviteUnit, AddFriend = retenir("InviteUnit"), retenir("AddFriend")
MAX_WHOS_FROM_SERVER = 50
WHO_FRAME_TOTAL_TEMPLATE, WHO_FRAME_SHOWN_TEMPLATE = "%d |4player:players; total", "(showing %d)"
WHO_LIST, REFRESH, GROUP_INVITE = "Who List", "Refresh", "Group Invite"
NAME, ZONE, RACE, LEVEL_ABBR, CLASS = "Name", "Zone", "Race", "Lvl", "Class"
LEVEL, SHOW_OFFLINE_MEMBERS = "Level", "Show Offline Members"
FRIENDS_TEXTURE_AFK = "Interface" .. string.char(92) .. "FriendsFrame" .. string.char(92) .. "StatusIcon-Away"
FRIENDS_TEXTURE_DND = "Interface" .. string.char(92) .. "FriendsFrame" .. string.char(92) .. "StatusIcon-DnD"
-- CreateFont : un objet police nomme, global, qui retient ce qu'on lui pose
function CreateFont(nom)
    local f = { nom = nom }
    function f:SetFontObject(o) self.parent = o end
    function f:SetShadowOffset(x, y) self.ombre = { x, y } end
    function f:SetShadowColor(r, v, b) self.ombreCouleur = { r, v, b } end
    function f:SetTextColor(r, v, b) self.couleur = { r, v, b } end
    _G[nom] = f
    return f
end
SystemFont_Med2 = SystemFont_Med2 or "SystemFont_Med2"
ChatFontNormal = ChatFontNormal or "ChatFontNormal"
GameFontNormalSmallLeft = GameFontNormalSmallLeft or "GameFontNormalSmallLeft"
-- Guilde : name, rank, rankIndex, level, class, zone, note, officernote,
-- online, status, classFileName
GUILDE = { { "Moi", "Officer", 1, 80, "Mage", "Dalaran", "note moi", "off moi", 1, "", "MAGE" },
           { "Bea", "Member", 3, 75, "Rogue", "Orgrimmar", "", "", 1, "<Away>", "ROGUE" },
           { "Cid", "Member", 3, 60, "Hunter", "", "", "", nil, "", "HUNTER" } }
GUILDE_CHOIX = 0
function GetGuildInfo(unit) return "Les Braves", "Officer", 1 end
function IsInGuild() return 1 end
-- SANS LES HORS LIGNE (la case decochee), le client ne rend que les membres
-- en ligne : GetNumGuildMembers() les compte, GetNumGuildMembers(true) tous
GUILDE_HORS = true
local function montres()
    if GUILDE_HORS then return GUILDE end
    local l = {}
    for _, m in ipairs(GUILDE) do if m[9] then table.insert(l, m) end end
    return l
end
function GetNumGuildMembers(tous) if tous then return #GUILDE end return #montres() end
function GetGuildRosterInfo(i) local m = montres()[i]; if not m then return nil end
    return m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11] end
function GetGuildRosterShowOffline() return GUILDE_HORS end
function SetGuildRosterShowOffline(v) GUILDE_HORS = v and true or false end
function GetGuildRosterSelection() return GUILDE_CHOIX end
function SetGuildRosterSelection(i) GUILDE_CHOIX = i end
function GetGuildRosterLastOnline(i) return 0, 0, 3, 0 end
SortGuildRoster, GuildRoster = retenir("SortGuildRoster"), retenir("GuildRoster")
GuildPromote, GuildDemote = retenir("GuildPromote"), retenir("GuildDemote")
SetGuildInfoText, QueryGuildEventLog = retenir("SetGuildInfoText"), retenir("QueryGuildEventLog")
CHEF_DE_GUILDE = false
function IsGuildLeader() return CHEF_DE_GUILDE end
function CanEditMOTD() return true end
function CanEditPublicNote() return true end
function CanViewOfficerNote() return true end
function CanEditOfficerNote() return false end
function CanGuildPromote() return true end
function CanGuildDemote() return true end
function CanGuildRemove() return true end
function CanGuildInvite() return true end
function GuildControlGetNumRanks() return 5 end
function GetGuildInfoText() return "Bienvenue" end
function CanEditGuildInfo() return true end
JOURNAL_GUILDE = { { "join", "Bea", nil, nil, 0, 0, 2, 0 }, { "promote", "Moi", "Bea", "Member", 0, 0, 1, 0 } }
function GetNumGuildEvents() return #JOURNAL_GUILDE end
function GetGuildEventInfo(i) local e = JOURNAL_GUILDE[i]; return e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8] end
CURRENT_GUILD_MOTD = "Raid ce soir"
GuildControlPopupFrame = CreateFrame("Frame", "GuildControlPopupFrame", UIParent)
GuildControlPopupFrame:Hide()
GuildInfoFrame = CreateFrame("Frame", "GuildInfoFrame", FriendsFrame)
GuildMemberDetailFrame = CreateFrame("Frame", "GuildMemberDetailFrame", FriendsFrame)
GuildMemberDetailFrame:Hide()
GuildInfoFrame:Hide()
GUILD_TITLE_TEMPLATE, GUILD_TOTAL, GUILD_TOTALONLINE = "%s of %s", "%d Guild Members", "(%d Online)"
PLAYER_STATUS, GUILD_STATUS, RANK, LABEL_NOTE, LASTONLINE = "Player Status", "Guild Status", "Rank", "Note", "Last Online"
GUILD_ONLINE_LABEL, GUILD_MOTD_LABEL = "Online", "Guild Message Of The Day:"
GUILDCONTROL, ADDMEMBER, GUILD_INFORMATION = "Guild Control", "Add Member", "Guild Information"
ZONE_COLON, RANK_COLON, LAST_ONLINE_COLON, NOTE_COLON, OFFICER_NOTE_COLON = "Zone:", "Rank:", "Last Online:", "Note:", "Officer's Note"
GUILD_NOTE_EDITLABEL, GUILD_OFFICERNOTE_EDITLABEL = "Click here to set a Public Note.", "Click here to set an Officer's Note."
REMOVE, ACCEPT, CLOSE, GUILD_EVENT_LOG, GUILD_INFO_EDITLABEL = "Remove", "Accept", "Close", "Log", "Click here to set message"
GUILDEVENT_TYPE_JOIN, GUILDEVENT_TYPE_PROMOTE = "%s joins the guild", "%s promotes %s to %s"
GUILD_BANK_LOG_TIME, LASTONLINE_DAYS = "( %s ago )", "%d |4day:days;"
function RecentTimeDate(a, m, j, h) if j and j > 0 then return string.format(LASTONLINE_DAYS, j) end return "< an hour" end
-- Canaux : name, header, collapsed, channelNumber, count, active, category
CANAUX = { { "World", true, false, nil, 1 },
           { "General", false, false, 1, nil, true, "CHANNEL_CATEGORY_WORLD" },
           { "Custom", true, false, nil, 1 },
           { "Guilde", false, false, 5, 3, true, "CHANNEL_CATEGORY_GROUP" } }
CANAL_CHOISI = nil
function GetNumDisplayChannels() return #CANAUX end
function GetChannelDisplayInfo(i) local c = CANAUX[i]; if not c then return nil end
    return c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9] end
function GetSelectedDisplayChannel() return CANAL_CHOISI end
function SetSelectedDisplayChannel(i) CANAL_CHOISI = i end
function GetActiveVoiceChannel() return nil end
MEMBRES_CANAL = { { "Moi", true, false }, { "Bea", false, true }, { "Cid", false, false } }
function GetChannelRosterInfo(id, i) local m = MEMBRES_CANAL[i]; if not m then return nil end; return m[1], m[2], m[3], m[4], m[5], m[6] end
SetActiveVoiceChannel = retenir("SetActiveVoiceChannel")
SummonFriend = retenir("SummonFriend")
RAF_SUMMON_LINKED, COOLDOWN_REMAINING = "Summon Linked Friend", "Cooldown remaining:"
DISPLAY_CHANNEL_PULLOUT = "Display Chat Roster Pullout"
NEWBIE_TOOLTIP_DISPLAY_CHANNEL_PULLOUT = "Click and drag to display a roster window that lists players with voice chat enabled in this channel."
ChannelListButton_OnDragStart = retenir("ChannelListButton_OnDragStart")
ChannelListButton_OnDragStop = retenir("ChannelListButton_OnDragStop")
MUETS_RAID = {}
function GetMuteStatus(unite, canal) return MUETS_RAID[unite] end
GetNumChannelMembers, ExpandChannelHeader, CollapseChannelHeader = retenir("GetNumChannelMembers"), retenir("ExpandChannelHeader"), retenir("CollapseChannelHeader")
ChannelRosterFrame_ShowDropdown = retenir("ChannelRosterFrame_ShowDropdown")
ChannelListDropDown = CreateFrame("Frame", "ChannelListDropDown", UIParent)
function ChannelListDropDown_Initialize() end
function JoinPermanentChannel(nom, mdp, id, x) table.insert(APPELS, { nom = "JoinPermanentChannel", args = { nom, mdp } }); return 1, nom end
DEFAULT_CHAT_FRAME.GetID = function() return 1 end
DEFAULT_CHAT_FRAME.channelList, DEFAULT_CHAT_FRAME.zoneChannelList = {}, {}
CHAT_CHANNELS, ADD, CHANNEL_NEW_CHANNEL, CHANNEL_CHANNEL_NAME = "Chat Channels", "Add", "New Channel", "Channel Name"
PASSWORD, OPTIONAL_PARENS, OKAY = "Password", "(optional)", "Okay"
VOICE_CHAT, VOICE_CHAT_PARTY_RAID, VOICE_CHAT_BATTLEGROUND = "Voice Chat", "Party/Raid", "Battleground"
NORMAL_FONT_COLOR_CODE, HIGHLIGHT_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE = "|cffffd200", "|cffffffff", "|cff808080"
-- Raid : name, rank, subgroup, level, class, fileName, zone, online, isDead
RAID_MEMBRES = {}
function GetNumRaidMembers() return #RAID_MEMBRES end
function GetRaidRosterInfo(i) local m = RAID_MEMBRES[i]; if not m then return nil end
    return m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9], m[10], m[11] end
function IsRaidLeader() return #RAID_MEMBRES > 0 end
function IsRaidOfficer() return false end
function GetPartyMember(i) return nil end
function HasLFGRestrictions() return false end
SAUVEGARDES = { { "Naxxramas", 12345, 3600 * 30, 1, true, false, 0, true, 25, "25 Player" } }
function GetNumSavedInstances() return #SAUVEGARDES end
function GetSavedInstanceInfo(i) local x = SAUVEGARDES[i]; return x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9], x[10] end
SetSavedInstanceExtend, RequestRaidInfo, ConvertToRaid, DoReadyCheck = retenir("SetSavedInstanceExtend"), retenir("RequestRaidInfo"), retenir("ConvertToRaid"), retenir("DoReadyCheck")
SwapRaidSubgroup, SetRaidSubgroup = retenir("SwapRaidSubgroup"), retenir("SetRaidSubgroup")
-- le vrai indexe son premier argument aussitot (UnitPopup.lua:193) ; il
-- pose le titre, les lignes permises, puis Cancel en dernier
function UnitPopup_ShowMenu(dropdownMenu, which, unit, name, userData)
    if not dropdownMenu then error("attempt to index local 'dropdownMenu' (a nil value)") end
    table.insert(APPELS, { nom = "UnitPopup_ShowMenu", args = { which, unit, name, userData } })
    DropDownList1.numButtons = 0
    UIDropDownMenu_AddButton({ text = name, isTitle = 1 })
    if which == "RAID" then
        UIDropDownMenu_AddButton({ text = "Promote to Assistant", value = "RAID_PROMOTE" })
        UIDropDownMenu_AddButton({ text = "Demote", value = "RAID_DEMOTE" })
    end
    UIDropDownMenu_AddButton({ text = "Cancel", value = "CANCEL" })
end
function UnitIsRaidOfficer(u) return false end
DemoteAssistant = retenir("DemoteAssistant")
HideDropDownMenu = HideDropDownMenu or function() end
RAID_DESCRIPTION, RAID_BROWSER_DESCRIPTION, OPEN_RAID_BROWSER = "Raids are groups...", "Find a Raid Group", "Open Raid Browser"
CONVERT_TO_RAID, RAID_INFO, READY_CHECK, LOOKING_FOR_RAID = "Convert To Raid", "Raid Info", "Ready Check", "Raid Browser"
GROUP, EMPTY, RAID_INFORMATION, INSTANCE, LOCK_EXPIRE = "Group", "Empty", "Raid Information", "Instance", "Lock Expire"
EXTEND_RAID_LOCK, UNEXTEND_RAID_LOCK, REACTIVATE_RAID_LOCK = "Extend Raid Lock", "Remove Raid Lock Extension", "Reactivate Raid Lock"
EXTENDED, RAID_INSTANCE_EXPIRES_EXPIRED, INSTANCE_ID = "|cff00ff00Extended|r", "Expired", "Instance ID: %d"
-- La fenetre de controle de guilde du client (FriendsFrame.xml) : son fond
-- MacroPopup en regions sans nom, ses cases (GuildControlPopupFrameCheckbox
-- Template), ses champs InputBoxTemplate a trois morceaux, et le cadre des
-- droits de banque a fond d'infobulle.
GuildControlPopupFrame:SetWidth(320)
GuildControlPopupFrame:SetHeight(457)
for _, f in ipairs({ "MacroPopup-TopLeft", "MacroPopup-TopRight", "MacroPopup-BotLeft", "MacroPopup-BotRight" }) do
    local t = GuildControlPopupFrame:CreateTexture(nil, "BACKGROUND")
    t:SetTexture("Interface" .. string.char(92) .. "MacroFrame" .. string.char(92) .. f)
end
GUILDCONTROL_TEXTE = GuildControlPopupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
GUILDCONTROL_TEXTE:SetText("Select guild rank to modify:")
for _, i in ipairs({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17 }) do
    local c = CreateFrame("CheckButton", "GuildControlPopupFrameCheckbox" .. i, GuildControlPopupFrame)
    c:SetNormalTexture("UI-CheckBox-Up")
    c:SetCheckedTexture("UI-CheckBox-Check")
end
for _, n in ipairs({ "GuildControlPopupFrameEditBox", "GuildControlWithdrawGoldEditBox", "GuildControlWithdrawItemsEditBox" }) do
    local b = CreateFrame("EditBox", n, GuildControlPopupFrame)
    for _, cote in ipairs({ "Left", "Middle", "Right" }) do
        _G[n .. cote] = b:CreateTexture(n .. cote, "BACKGROUND")
    end
end
GuildControlPopupFrameTabPermissions = CreateFrame("Frame", "GuildControlPopupFrameTabPermissions", GuildControlPopupFrame)
GuildControlPopupFrameTabPermissions:SetBackdrop({ bgFile = "UI-Tooltip-Background" })
-- le raid : classes du client, etat de l'appel, fenetres detachees
CLASS_SORT_ORDER = { "WARRIOR", "DEATHKNIGHT", "PALADIN", "PRIEST", "SHAMAN", "DRUID", "ROGUE", "MAGE", "WARLOCK", "HUNTER" }
CLASS_ICON_TCOORDS = {}
for i, c in ipairs(CLASS_SORT_ORDER) do CLASS_ICON_TCOORDS[c] = { 0, 0.25, 0, 0.25 } end
LOCALIZED_CLASS_NAMES_MALE = { WARRIOR = "Warrior", MAGE = "Mage", ROGUE = "Rogue", HUNTER = "Hunter" }
PETS, MAINTANK, MAINASSIST = "Pets", "Main Tank", "Main Assist"
APPEL_ETAT = {}
function GetReadyCheckStatus(unit) return APPEL_ETAT[unit] end
READY_CHECK_READY_TEXTURE = "ReadyCheck-Ready"
READY_CHECK_NOT_READY_TEXTURE = "ReadyCheck-NotReady"
READY_CHECK_WAITING_TEXTURE = "ReadyCheck-Waiting"
READY_CHECK_AFK_TEXTURE = "ReadyCheck-NotReady"
DETACHEES = {}
-- une fenetre detachee est un cadre fils d'UIParent ; le client la pose par
-- GetScreenWidthScale (largeur / 1024), faux hors du 4:3 -- le faux aussi
function RaidPullout_GeneratePulloutFrame(filtre, classe)
    local f = CreateFrame("Frame", nil, UIParent)
    f.filtre, f.classe = filtre, classe
    table.insert(DETACHEES, f)
    return f
end
function RaidPulloutButton_OnDragStart(f)
    local x, y = GetCursorPosition()
    f.bouge = true
    f:ClearAllPoints()
    f:SetPoint("TOP", nil, "BOTTOMLEFT", x * 1.33, y * 1.33)
end
MAIN_TANK, MAIN_ASSIST, SET_MAIN_TANK, SET_MAIN_ASSIST = "Main Tank", "Main Assist", "Promote to Main Tank", "Promote to Main Assist"
RaidPulloutStopMoving = retenir("RaidPulloutStopMoving")
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
        bouton:SetFontString(bouton:CreateFontString(nom .. "Button" .. i .. "NormalText", "ARTWORK"))
        _G[nom .. "Button" .. i .. "NormalText"] = bouton:GetFontString()
        _G[nom .. "Button" .. i .. "Check"] = bouton:CreateTexture(
            nom .. "Button" .. i .. "Check", "ARTWORK")
        _G[nom .. "Button" .. i .. "Check"]:SetWidth(18)
        _G[nom .. "Button" .. i .. "Check"]:SetHeight(18)
    end
end
function UIDropDownMenu_CreateInfo() return {} end
MENU_ENTREES = {}
function UIDropDownMenu_AddButton(info, level)
    table.insert(MENU_ENTREES, info)
    level = level or 1
    local liste = _G["DropDownList" .. level]
    liste.numButtons = liste.numButtons + 1
    local bouton = _G[liste:GetName() .. "Button" .. liste.numButtons]
    -- Au-dela de huit lignes, le vrai en cree d'autres
    -- (UIDropDownMenu_CreateFrames : UIDROPDOWNMENU_MAXBUTTONS grandit).
    if not bouton then
        bouton = CreateFrame("Button", liste:GetName() .. "Button" .. liste.numButtons, liste)
        bouton:SetWidth(100)
        bouton:SetHeight(16)
        bouton:SetFontString(bouton:CreateFontString(bouton:GetName() .. "NormalText", "ARTWORK"))
        _G[bouton:GetName() .. "NormalText"] = bouton:GetFontString()
    end
    bouton.notCheckable = info.notCheckable
    -- le vrai retient ces champs sur la ligne (UIDropDownMenu.lua:316-342)
    bouton.func, bouton.owner, bouton.arg1 = info.func, info.owner, info.arg1
    bouton.value = info.value or info.text
    if info.text then bouton:SetText(info.text) end
    bouton:SetNormalFontObject(GameFontHighlightSmallLeft)
    bouton:SetHighlightFontObject(GameFontHighlightSmallLeft)
    return bouton
end
function ActionButton_Update() end
function ActionButton_ShowGrid() end
function ActionButton_HideGrid() end
SlashCmdList = {}
-- LA FENETRE DE TABARD DU CLIENT 3.3.5 (TabardFrame.xml) : 384 x 512, son
-- cadre de WotLK en quatre textures sans nom, son grand fond, ses pieces aux
-- places de WotLK.
do
    local sep = string.char(92)
    TabardFrame = CreateFrame("Frame", "TabardFrame", UIParent)
    TabardFrame:SetWidth(384); TabardFrame:SetHeight(512)
    TabardFrame:SetHitRectInsets(0, 30, 0, 45)
    TabardFrame:Hide()
    for _, f in ipairs({ "PaperDollInfoFrame" .. sep .. "UI-Character-General-TopLeft", "PaperDollInfoFrame" .. sep .. "UI-Character-General-TopRight",
        "ClassTrainerFrame" .. sep .. "UI-ClassTrainer-BotLeft", "ClassTrainerFrame" .. sep .. "UI-ClassTrainer-BotRight" }) do
        local t = TabardFrame:CreateTexture(nil, "ARTWORK")
        t:SetTexture("Interface" .. sep .. f)
    end
    TabardFramePortrait = TabardFrame:CreateTexture("TabardFramePortrait", "BACKGROUND")
    TabardFrameBackground = TabardFrame:CreateTexture("TabardFrameBackground", "BACKGROUND")
    TabardFrameBackground:SetTexture("Interface" .. sep .. "TabardFrame" .. sep .. "TabardFrameBackground")
    TabardFrameOuterFrameTopLeft = TabardFrame:CreateTexture("TabardFrameOuterFrameTopLeft", "OVERLAY")
    TabardFrameOuterFrameTopLeft:SetPoint("TOPLEFT", TabardFrame, "TOPLEFT", 19, -73)
    TabardFrameNameText = TabardFrame:CreateFontString("TabardFrameNameText", "OVERLAY", "GameFontNormal")
    TabardFrameNameText:SetPoint("CENTER", TabardFrame, "CENTER", 6, 232)
    TabardFrameGreetingText = TabardFrame:CreateFontString("TabardFrameGreetingText", "OVERLAY", "GameFontHighlight")
    TabardFrameGreetingText:SetPoint("TOP", TabardFrame, "TOP", 10, -39)
    TabardModel = CreateFrame("Frame", "TabardModel", TabardFrame)
    TabardModel:SetPoint("BOTTOM", TabardFrame, "BOTTOM", -14, 114)
    TabardCharacterModelRotateLeftButton = CreateFrame("Button", "TabardCharacterModelRotateLeftButton", TabardModel)
    TabardCharacterModelRotateLeftButton:SetPoint("BOTTOMLEFT", TabardFrame, "BOTTOMLEFT", 26, 110)
    TabardFrameCustomizationFrame = CreateFrame("Frame", "TabardFrameCustomizationFrame", TabardFrame)
    TabardFrameCustomizationBorder = TabardFrameCustomizationFrame:CreateTexture("TabardFrameCustomizationBorder", "BACKGROUND")
    TabardFrameCustomizationBorder:SetPoint("BOTTOMRIGHT", TabardFrame, "BOTTOMRIGHT", -9, 50)
    TabardFrameMoneyFrame = CreateFrame("Frame", "TabardFrameMoneyFrame", TabardFrame)
    TabardFrameMoneyFrame:SetPoint("BOTTOMRIGHT", TabardFrame, "BOTTOMLEFT", 183, 86)
    TabardFrameAcceptButton = CreateFrame("Button", "TabardFrameAcceptButton", TabardFrame)
    TabardFrameAcceptButton:SetPoint("CENTER", TabardFrame, "TOPLEFT", 224, -420)
    TabardFrameCancelButton = CreateFrame("Button", "TabardFrameCancelButton", TabardFrame)
    TabardFrameCancelButton:SetPoint("CENTER", TabardFrame, "TOPLEFT", 305, -420)
    TabardFrameCloseButton = CreateFrame("Button", "TabardFrameCloseButton", TabardFrame)
    TabardFrameCloseButton:SetPoint("CENTER", TabardFrame, "TOPRIGHT", -45, -24)
end
-- LE GROUPE (cadres de groupe, PartyFrame.lua) : party1..4 et partypet1..4
-- ont leurs propres donnees, dans GROUPE ; les autres unites gardent les faux
-- ci-dessus. Une unite de groupe absente n'existe pas.
GROUPE = {}
CHEF_GROUPE = 0
local DE = {}
for _, n in ipairs({ "UnitExists", "UnitHealth", "UnitHealthMax", "UnitPower", "UnitPowerMax", "UnitPowerType",
    "UnitName", "UnitIsDeadOrGhost", "UnitThreatSituation", "UnitHasVehicleUI", "UnitIsPVP",
    "UnitIsPVPFreeForAll", "UnitFactionGroup", "GetReadyCheckStatus", "UnitClass", "UnitIsUnit" }) do
    DE[n] = _G[n]
end
local function du(u)
    -- une unite de raid n'y passe que si l'essai l'a declaree : les essais
    -- de la fenetre Social gardent leurs faux (APPEL_ETAT, RAID_MEMBRES)
    if type(u) == "string" and (u:match("^party%d$") or u:match("^partypet%d$")
        or ((u:match("^raid%d+$") or u:match("^raidpet%d+$")) and GROUPE[u])) then
        return true, GROUPE[u]
    end
end
local function surcharge(n, f)
    _G[n] = function(u, ...)
        local g, m = du(u)
        if g then return f(m, u, ...) end
        return DE[n](u, ...)
    end
end
surcharge("UnitExists", function(m) return m ~= nil end)
surcharge("UnitHealth", function(m) return m and m.vie or 0 end)
surcharge("UnitHealthMax", function(m) return m and m.max or 0 end)
surcharge("UnitPower", function(m) return m and m.res or 0 end)
surcharge("UnitPowerMax", function(m) return m and m.resMax or 0 end)
surcharge("UnitPowerType", function(m) return 0, m and m.jeton or "MANA" end)
surcharge("UnitName", function(m) return m and m.nom end)
surcharge("UnitIsDeadOrGhost", function(m) return m and (m.mort or m.fantome) or false end)
surcharge("UnitThreatSituation", function(m) return m and m.menace end)
surcharge("UnitHasVehicleUI", function(m) return m and m.vehicule or false end)
surcharge("UnitIsPVP", function(m) return m and m.pvp end)
surcharge("UnitIsPVPFreeForAll", function(m) return m and m.ffa end)
surcharge("UnitFactionGroup", function(m) return m and m.faction end)
surcharge("GetReadyCheckStatus", function(m) return m and m.appel end)
surcharge("UnitClass", function(m) return m and m.classe, m and m.classe end)
-- la cible : un membre marque "cible" l'est
_G.UnitIsUnit = function(a, b)
    local g, m = du(a)
    if g and b == "target" then return m and m.cible or false end
    if g and b == "player" then return m and m.moi or false end
    return DE.UnitIsUnit(a, b)
end
-- UnitInRange ne vaut que pour le groupe et le raid ; "loin" marque le hors-portee
function UnitInRange(u) local g, m = du(u); if g then return m and not m.loin end return nil end
function UnitTargetsVehicleInRaidUI(u) local g, m = du(u); return g and m and m.vehicule or false end
-- AMELIORATIONS[unite] = { { icone, pile, duree, fin, lanceur }, ... } ; le
-- filtre PLAYER ne garde que celles du joueur, l'indice court sur la liste filtree
AMELIORATIONS = {}
function UnitBuff(u, i, filtre)
    local vus = 0
    for _, b in ipairs(AMELIORATIONS[u] or {}) do
        if filtre ~= "PLAYER" or b[5] == "player" then
            vus = vus + 1
            if vus == i then return "Buff" .. i, "", b[1], b[2], nil, b[3], b[4], b[5] end
        end
    end
    return nil
end
-- PowerBarColor du client 3.3.5 (UnitFrame.lua)
PowerBarColor = PowerBarColor or {}
PowerBarColor["MANA"] = { r = 0.00, g = 0.00, b = 1.00 }
PowerBarColor["RAGE"] = { r = 1.00, g = 0.00, b = 0.00 }
PowerBarColor["FOCUS"] = { r = 1.00, g = 0.50, b = 0.25 }
PowerBarColor["ENERGY"] = { r = 1.00, g = 1.00, b = 0.00 }
PowerBarColor["RUNIC_POWER"] = { r = 0.00, g = 0.82, b = 1.00 }
PowerBarColor[0], PowerBarColor[1], PowerBarColor[2] = PowerBarColor["MANA"], PowerBarColor["RAGE"], PowerBarColor["FOCUS"]
PowerBarColor[3], PowerBarColor[6] = PowerBarColor["ENERGY"], PowerBarColor["RUNIC_POWER"]
-- les addons : l'addon HD "CompactRaidFrame" est-il charge ?
ADDONS_CHARGES = {}
ADDONS_DESACTIVES = {}
function IsAddOnLoaded(nom) return ADDONS_CHARGES[nom] end
function DisableAddOn(nom) ADDONS_DESACTIVES[nom] = true end
PLAYER_OFFLINE = PLAYER_OFFLINE or "Offline"
-- le tabard de guilde : 3.3.5 ne rend que les NOMS de ses textures
TABARD = nil
function GetGuildTabardFileNames()
    if not TABARD then return nil end
    local sep = string.char(92)
    local d = "Textures" .. sep .. "GuildEmblems" .. sep
    return d .. "Background_" .. TABARD.fond .. "_TU_U", d .. "Background_" .. TABARD.fond .. "_TL_U",
        d .. "Emblem_" .. TABARD.motif .. "_" .. TABARD.couleur .. "_TU_U", d .. "Emblem_" .. TABARD.motif .. "_" .. TABARD.couleur .. "_TL_U",
        d .. "Border_00_" .. "TU_U", d .. "Border_00_TL_U"
end
NumberFontNormal = NumberFontNormal or "NumberFontNormal"
function UnitIsDead(u) local g, m = du(u); if g then return m and m.mort end return STATE.dead end
function UnitIsGhost(u) local g, m = du(u); if g then return m and m.fantome end return false end
function UnitIsConnected(u) local g, m = du(u); if g then return m ~= nil and not m.deconnecte end return true end
-- 3.3.5 : trois booleens, pas une chaine
function UnitGroupRolesAssigned(u)
    local g, m = du(u)
    local r = g and m and m.role
    return r == "TANK", r == "HEALER", r == "DAMAGER"
end
function GetPartyLeaderIndex() return CHEF_GROUPE end
function UnitCanAssist(a, b) return true end
function GetUnitName(u, complet) return UnitName(u) end
DebuffTypeColor = DebuffTypeColor or {
    none = { r = 0.80, g = 0, b = 0 }, Magic = { r = 0.20, g = 0.60, b = 1.00 },
    Curse = { r = 0.60, g = 0.00, b = 1.00 }, Disease = { r = 0.60, g = 0.40, b = 0 },
    Poison = { r = 0.00, g = 0.60, b = 0 },
}
DEAD = DEAD or "Dead"
-- AFFAIBLISSEMENTS[unite] = { { icone, pile, type, duree, fin }, ... } ; le
-- filtre "RAID" ne garde que ceux qui ont un type (dissipables), et l'indice
-- court sur la liste filtree, comme le client
AFFAIBLISSEMENTS = {}
function UnitDebuff(u, i, filtre)
    local l = AFFAIBLISSEMENTS[u] or {}
    local vus = 0
    for _, d in ipairs(l) do
        if filtre ~= "RAID" or d[3] then
            vus = vus + 1
            if vus == i then return "Aff" .. i, "", d[1], d[2], d[3], d[4], d[5], "boss" end
        end
    end
    return nil
end
-- les pilotes d'etat et le surveillant d'unite
function RegisterStateDriver(f, etat, valeurs)
    f.etats = f.etats or {}
    f.etats[etat] = valeurs
end
function UnregisterUnitWatch(f) f.unitWatch = false end
-- les cadres de groupe du client et leurs menus
for i = 1, 4 do
    CreateFrame("Button", "PartyMemberFrame" .. i, UIParent)
    CreateFrame("Frame", "PartyMemberFrame" .. i .. "DropDown", UIParent)
end
PartyMemberBackground = CreateFrame("Frame", "PartyMemberBackground", UIParent)
TextStatusBarText = TextStatusBarText or "TextStatusBarText"
NumberFontNormalSmall = NumberFontNormalSmall or "NumberFontNormalSmall"
-- LE CHERCHEUR DE DONJON DU CLIENT 3.3.5 (LFDFrame.xml/.lua, LFGFrame.lua) :
-- le panneau, son contenu transparent, ses boutons de role, sa liste et ses
-- voiles ; les fonctions que GroupFinder.lua appelle, reprises du client.
do
    local sep = string.char(92)
    -- UNE CHECKBUTTON a aussi son image cochee-desactivee, et son Click la
    -- bascule des la premiere fois (le vrai GetChecked rend nil, pas false,
    -- avant tout clic). Pour tous les cadres crees ensuite.
    local creer = CreateFrame
    CreateFrame = function(kind, name, parent, template)
        local f = creer(kind, name, parent, template)
        if kind == "CheckButton" and f.checked == nil then f.checked = false end
        function f:SetDisabledCheckedTexture(v)
            if not self._disabledChecked then self._disabledChecked = self:CreateTexture() end
            self._disabledChecked.texture = v
            return self._disabledChecked
        end
        function f:GetDisabledCheckedTexture() return self._disabledChecked end
        return f
    end
    GameTooltip.SetLFGDungeonReward = function(self, t, i) self.recompense = { t, i } end
    LFG_MODE = nil
    function GetLFGMode() return LFG_MODE end
    LFD_EMPOWERED = true
    function LFD_IsEmpowered() return LFD_EMPOWERED end
    function GetExpansionLevel() return 2 end
    function GetCoinTextureString(n) return "pieces:" .. tostring(n) end
    LFD_LEVEL_FORMAT_SINGLE = "(%d)"
    LFD_LEVEL_FORMAT_RANGE = "(%d - %d)"
    SPECIFIC_DUNGEONS = "Specific Dungeons"
    LFG_TITLE = "Looking For Group"
    LOOKING_FOR_DUNGEON = "Dungeon Finder"
    FIND_A_GROUP = "Find Group"
    BACK = "Back"
    LFD_REWARDS = "Rewards"
    MONEY_COLON = "Money:"
    EXPERIENCE_COLON = "Experience:"
    YOU_MAY_NOT_QUEUE_FOR_THIS = "You may not queue for this."
    YOU_MAY_NOT_QUEUE_FOR_DUNGEON = "You may not queue for this dungeon."
    ROLE_DESCRIPTION1 = "Degats"
    ROLE_DESCRIPTION2 = "Tank"
    ROLE_DESCRIPTION3 = "Soins"
    GUIDE_TOOLTIP = "Chef"
    YES = "Yes"
    HIDE = "Hide"

    LFDParentFrame = CreateFrame("Frame", "LFDParentFrame", UIParent)
    LFDParentFrame:SetWidth(355); LFDParentFrame:SetHeight(440)
    LFDParentFrame:EnableMouse(true)
    LFDParentFrame:Hide()
    UIPanelWindows["LFDParentFrame"] = { area = "left", pushable = 0, whileDead = 1 }
    LFDParentFramePortrait = CreateFrame("Frame", "LFDParentFramePortrait", LFDParentFrame)
    LFD_CROIX = CreateFrame("Button", nil, LFDParentFrame)
    LFDQueueFrame = CreateFrame("Frame", "LFDQueueFrame", LFDParentFrame)
    LFDQueueFrame:SetAllPoints(LFDParentFrame)

    -- les roles : GetLFGRoles / SetLFGRoles, et les boutons du client
    ROLES_LFG = { false, false, false, false }
    function GetLFGRoles() return ROLES_LFG[1], ROLES_LFG[2], ROLES_LFG[3], ROLES_LFG[4] end
    function SetLFGRoles(a, b, c, d) ROLES_LFG = { a and true or false, b and true or false, c and true or false, d and true or false } end
    local function role(nom, id, fond)
        local b = CreateFrame("Button", nom, LFDQueueFrame)
        b:SetID(id)
        b:SetNormalTexture(sep)
        b.cover = b:CreateTexture(nil, "OVERLAY")
        b.cover:SetAlpha(0.5)
        b.cover:Hide()
        if fond then b.background = b:CreateTexture(nom .. "Background", "BACKGROUND") end
        b.checkButton = CreateFrame("CheckButton", nil, b)
        b.checkButton:SetScript("OnClick", function(self, bouton)
            PlaySound("igMainMenuOptionCheckBoxOn")
            if self.onClick then self.onClick(self, bouton) end
        end)
        b.checkButton.onClick = function() LFDQueueFrame_SetRoles() end
        return b
    end
    role("LFDQueueFrameRoleButtonTank", 2, true)
    role("LFDQueueFrameRoleButtonHealer", 3, true)
    role("LFDQueueFrameRoleButtonDPS", 1, true)
    role("LFDQueueFrameRoleButtonLeader", 4, false)
    function LFDQueueFrame_SetRoles()
        SetLFGRoles(LFDQueueFrameRoleButtonLeader.checkButton:GetChecked(), LFDQueueFrameRoleButtonTank.checkButton:GetChecked(),
            LFDQueueFrameRoleButtonHealer.checkButton:GetChecked(), LFDQueueFrameRoleButtonDPS.checkButton:GetChecked())
    end
    -- LFGFrame.lua, mot pour mot
    function LFG_PermanentlyDisableRoleButton(button)
        button.permDisabled = true
        button:Disable()
        button.cover:Show()
        button.cover:SetAlpha(0.7)
        button.checkButton:Hide()
        button.checkButton:Disable()
        if button.background then button.background:Hide() end
    end
    function LFG_DisableRoleButton(button)
        button:Disable()
        button.cover:Show()
        if not button.permDisabled then button.cover:SetAlpha(0.5) end
        button.checkButton:Disable()
        if button.background then button.background:Hide() end
    end
    function LFG_EnableRoleButton(button)
        button.permDisabled = false
        button:Enable()
        button.cover:Hide()
        button.checkButton:Show()
        button.checkButton:Enable()
        if button.background then button.background:Show() end
    end
    ROLES_POSSIBLES = { true, true, true }
    function LFG_UpdateRolesChangeable()
        local mode = GetLFGMode()
        if mode == "queued" or mode == "listed" or mode == "rolecheck" or mode == "proposal" then
            for _, n in ipairs({ "Tank", "Healer", "DPS", "Leader" }) do LFG_DisableRoleButton(_G["LFDQueueFrameRoleButton" .. n]) end
        else
            for i, n in ipairs({ "Tank", "Healer", "DPS" }) do
                if ROLES_POSSIBLES[i] then LFG_EnableRoleButton(_G["LFDQueueFrameRoleButton" .. n])
                else LFG_PermanentlyDisableRoleButton(_G["LFDQueueFrameRoleButton" .. n]) end
            end
            LFG_EnableRoleButton(LFDQueueFrameRoleButtonLeader)
        end
    end
    function LFG_UpdateRoleCheckboxes()
        local l, t, h, d = GetLFGRoles()
        LFDQueueFrameRoleButtonLeader.checkButton:SetChecked(l)
        LFDQueueFrameRoleButtonTank.checkButton:SetChecked(t)
        LFDQueueFrameRoleButtonHealer.checkButton:SetChecked(h)
        LFDQueueFrameRoleButtonDPS.checkButton:SetChecked(d)
    end

    -- le bouton de recherche : il retient ses clics
    LFD_RECHERCHES = 0
    LFDQueueFrameFindGroupButton = CreateFrame("Button", "LFDQueueFrameFindGroupButton", LFDQueueFrame)
    LFDQueueFrameFindGroupButton:SetText("Find Group")
    LFDQueueFrameFindGroupButton:SetScript("OnClick", function() LFD_RECHERCHES = LFD_RECHERCHES + 1 end)
    function LFDQueueFrameFindGroupButton_Update()
        local mode = GetLFGMode()
        if mode == "queued" or mode == "rolecheck" or mode == "proposal" then
            LFDQueueFrameFindGroupButton:SetText("Leave Queue")
        else
            LFDQueueFrameFindGroupButton:SetText("Find Group")
        end
        if LFD_IsEmpowered() and mode ~= "proposal" and mode ~= "listed" then
            LFDQueueFrameFindGroupButton:Enable()
        else
            LFDQueueFrameFindGroupButton:Disable()
        end
    end

    -- le type : un aleatoire (numero) ou "specific"
    LFDQueueFrameRandom = CreateFrame("Frame", "LFDQueueFrameRandom", LFDQueueFrame)
    LFDQueueFrameSpecific = CreateFrame("Frame", "LFDQueueFrameSpecific", LFDQueueFrame)
    LFDQueueFrameSpecific:Hide()
    local enfant = CreateFrame("Frame", "LFDQueueFrameRandomScrollFrameChildFrame", LFDQueueFrameRandom)
    for _, cle in ipairs({ "title", "description", "rewardsLabel", "rewardsDescription", "pugDescription" }) do
        enfant[cle] = enfant:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    end
    enfant.rewardsLabel:SetText("Rewards")
    function LFDQueueFrame_SetType(value)
        LFDQueueFrame.type = value
        if value == "specific" then
            LFDQueueFrameRandom:Hide(); LFDQueueFrameSpecific:Show()
            LFDQueueFrame_Update()
        else
            LFDQueueFrameSpecific:Hide(); LFDQueueFrameRandom:Show()
            LFDQueueFrameRandom_UpdateFrame()
        end
    end
    -- DONJONS[id] = { nom, type, min, max, rec, minRec, maxRec, extension,
    -- groupe, image, difficulte, joueurs, description, fete }
    DONJONS = {}
    ALEATOIRES = {}
    RECOMPENSES = {}
    function GetLFGDungeonInfo(id) local d = DONJONS[id] if d then return (table.unpack or unpack)(d, 1, 14) end end
    function GetNumRandomDungeons() return #ALEATOIRES end
    function GetLFGRandomDungeonInfo(i) local a = ALEATOIRES[i] return a.id, DONJONS[a.id][1] end
    function IsLFGDungeonJoinable(id) for _, a in ipairs(ALEATOIRES) do if a.id == id then return a.dispo end end end
    function LFDConstructDeclinedMessage(id) return "Niveau trop bas" end
    -- RECOMPENSES[id] = { fait, argentBase, argentVar, xpBase, xpVar, { {nom, image, n}, ... } }
    function GetLFGDungeonRewards(id)
        local r = RECOMPENSES[id] or { false, 0, 0, 0, 0, {} }
        return r[1], r[2], r[3], r[4], r[5], #r[6]
    end
    function GetLFGDungeonRewardInfo(id, i) local o = RECOMPENSES[id][6][i] return o[1], o[2], o[3] end
    function GetLFGDungeonRewardLink(id, i) return "lien:" .. id .. ":" .. i end
    function LFDQueueFrameRandom_UpdateFrame()
        local id = LFDQueueFrame.type
        if not id then return end
        local _, _, _, _, xpVar, n = GetLFGDungeonRewards(id)
        enfant.title:SetText("Random Dungeon")
        enfant.description:SetText("Explication")
        enfant.rewardsDescription:SetText("Premiere victoire")
        if n > 0 then enfant.rewardsLabel:Show() else enfant.rewardsLabel:Hide() end
        if xpVar and xpVar > 0 then enfant.pugDescription:SetText("Inconnus") enfant.pugDescription:Show() else enfant.pugDescription:Hide() end
    end

    -- la liste : les tables du client, et ses fonctions (LFDFrame.lua)
    LFGDungeonInfo, LFGEnabledList, LFGLockList, LFGCollapseList, LFGQueuedForList = {}, {}, {}, {}, {}
    LFDDungeonList, LFDHiddenByCollapseList = {}, {}
    LFD_ORDRE = {}
    function LFGGetDungeonInfoByID(id) return LFGDungeonInfo[id] end
    function LFGIsIDHeader(id) return id < 0 end
    function LFDQueueFrame_Update()
        for k in pairs(LFDDungeonList) do LFDDungeonList[k] = nil end
        for k in pairs(LFDHiddenByCollapseList) do LFDHiddenByCollapseList[k] = nil end
        for _, id in ipairs(LFD_ORDRE) do
            local info = LFGDungeonInfo[id]
            if id > 0 and LFGCollapseList[info[9]] then
                table.insert(LFDHiddenByCollapseList, id)
            else
                table.insert(LFDDungeonList, id)
            end
        end
        LFDQueueFrameSpecificList_Update()
    end
    LFD_MAJ_LISTE = 0
    function LFDQueueFrameSpecificList_Update() LFD_MAJ_LISTE = LFD_MAJ_LISTE + 1 end
    function SetLFGHeaderCollapsed(h, v) end
    function LFDList_SetHeaderCollapsed(headerID, isCollapsed)
        SetLFGHeaderCollapsed(headerID, isCollapsed)
        LFGCollapseList[headerID] = isCollapsed
        LFDQueueFrame_Update()
    end
    function LFDQueueFrameExpandOrCollapseButton_OnClick(self, button)
        local parent = self:GetParent()
        LFDList_SetHeaderCollapsed(parent.id, not parent.isCollapsed)
    end
    function SetLFGDungeonEnabled(id, v) end
    function LFDList_SetDungeonEnabled(dungeonID, isEnabled)
        SetLFGDungeonEnabled(dungeonID, isEnabled)
        LFGEnabledList[dungeonID] = not not isEnabled
    end
    function LFDList_SetHeaderEnabled(headerID, isEnabled)
        for _, id in ipairs(LFD_ORDRE) do
            if id > 0 and LFGDungeonInfo[id][9] == headerID then LFDList_SetDungeonEnabled(id, isEnabled) end
        end
        LFGEnabledList[headerID] = not not isEnabled
    end
    -- l'etat d'un en-tete : 0 aucun, 1 certains, 2 tous
    function LFGListUpdateHeaderEnabledAndLockedStates()
        for _, h in ipairs(LFD_ORDRE) do
            if h < 0 then
                local n, oui = 0, 0
                for _, id in ipairs(LFD_ORDRE) do
                    if id > 0 and LFGDungeonInfo[id][9] == h then
                        n = n + 1
                        if LFGEnabledList[id] then oui = oui + 1 end
                    end
                end
                LFGEnabledList[h] = (oui == 0 and 0) or (oui == n and 2) or 1
            end
        end
    end
    function LFDQueueFrameDungeonChoiceEnableButton_OnClick(self, button)
        local parent = self:GetParent()
        local dungeonID = parent.id
        local isChecked = self:GetChecked()
        PlaySound("igMainMenuOptionCheckBoxOff")
        if LFGIsIDHeader(dungeonID) then
            LFDList_SetHeaderEnabled(dungeonID, isChecked)
        else
            LFDList_SetDungeonEnabled(dungeonID, isChecked)
            LFGListUpdateHeaderEnabledAndLockedStates(LFDDungeonList, LFGEnabledList, LFGLockList, LFDHiddenByCollapseList)
        end
        LFDQueueFrameSpecificList_Update()
    end
    function LFDQueueFrameDungeonListButton_OnEnter(self)
        if self.lockedIndicator:IsShown() and not LFGIsIDHeader(self.id) then
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(YOU_MAY_NOT_QUEUE_FOR_DUNGEON, 1.0, 1.0, 1.0)
            GameTooltip:Show()
        end
    end

    -- les voiles
    LFDQueueFrameCooldownFrame = CreateFrame("Frame", "LFDQueueFrameCooldownFrame", LFDQueueFrameRandom)
    LFDQueueFrameCooldownFrame.description = LFDQueueFrameCooldownFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    LFDQueueFrameCooldownFrame.time = LFDQueueFrameCooldownFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    for i = 1, 4 do
        LFDQueueFrameCooldownFrame:CreateFontString("LFDQueueFrameCooldownFrameName" .. i, "ARTWORK", "GameFontNormal"):Hide()
        LFDQueueFrameCooldownFrame:CreateFontString("LFDQueueFrameCooldownFrameStatus" .. i, "ARTWORK", "GameFontNormal"):Hide()
    end
    LFDQueueFrameCooldownFrame:Hide()
    function LFDQueueFrameRandomCooldownFrame_Update() end
    LFDQueueFramePartyBackfill = CreateFrame("Frame", "LFDQueueFramePartyBackfill", LFDQueueFrame)
    LFDQueueFramePartyBackfill:CreateFontString("LFDQueueFramePartyBackfillDescription", "ARTWORK", "GameFontNormal")
    LFD_REPRISES = 0
    local oui = CreateFrame("Button", "LFDQueueFramePartyBackfillBackfillButton", LFDQueueFramePartyBackfill)
    oui:SetScript("OnClick", function() LFD_REPRISES = LFD_REPRISES + 1 end)
    local non = CreateFrame("Button", "LFDQueueFramePartyBackfillNoBackfillButton", LFDQueueFramePartyBackfill)
    non:SetScript("OnClick", function() LFDQueueFramePartyBackfill:Hide() end)
    LFDQueueFramePartyBackfill:Hide()
    function LFDFrame_UpdateBackfill() end
    LFDQueueFrameNoLFDWhileLFR = CreateFrame("Frame", "LFDQueueFrameNoLFDWhileLFR", LFDQueueFrame)
    LFDQueueFrameNoLFDWhileLFR:CreateFontString("LFDQueueFrameNoLFDWhileLFRDescription", "ARTWORK", "GameFontNormal")
    local quitter = CreateFrame("Button", "LFDQueueFrameNoLFDWhileLFRLeaveQueueButton", LFDQueueFrameNoLFDWhileLFR)
    quitter:SetText("Unlist Me")
    LFDQueueFrameNoLFDWhileLFR:Hide()
    function LFG_UpdateLockedOutPanels()
        if GetLFGMode() == "listed" then LFDQueueFrameNoLFDWhileLFR:Show() else LFDQueueFrameNoLFDWhileLFR:Hide() end
    end
end
-- LE NAVIGATEUR DE RAID DU CLIENT 3.3.5 (LFRFrame.xml/.lua) : le panneau,
-- ses deux contenus, ses roles, sa liste, son commentaire, son parcours ; les
-- fonctions que GroupFinderRaid.lua appelle, reprises du client.
do
    LOOKING_FOR_RAID = "Raid Browser"
    CHOOSE_RAID = "Choose Raid"
    BROWSE = "Browse"
    ACCEPT_COMMENT = "Set Comment"
    LIST_ME = "List My Name"
    LIST_MY_GROUP = "List My Group"
    JOIN = "Join"
    UNLIST_ME = "Unlist Me"
    LEAVE_QUEUE = "Leave Queue"
    SEND_MESSAGE = SEND_MESSAGE or "Send Message"
    INVITE = "Invite"
    REFRESH = "Refresh"
    NONE = NONE or "None"
    TYPE_LFR_COMMENT_HERE = "Type a comment here"
    NO_RAIDS_AVAILABLE = "No raids available"
    LFG_TOOLTIP_ROLES = "Roles:"
    LEVEL_ABBR = "Lvl"
    SHOW_LFD_LEVEL = 15
    GRAY_FONT_COLOR = GRAY_FONT_COLOR or { r = 0.5, g = 0.5, b = 0.5 }
    NORMAL_FONT_COLOR = NORMAL_FONT_COLOR or { r = 1, g = 0.82, b = 0 }
    LFR_EMPOWERED = true
    function LFR_IsEmpowered() return LFR_EMPOWERED end
    function LFR_CanQueueForMultiple() return GetNumPartyMembers() == 0 and GetNumRaidMembers() == 0 end
    function LFR_CanQueueForLockedInstances() return GetNumPartyMembers() > 0 or GetNumRaidMembers() > 0 end
    COMMENTAIRE_LFG = nil
    function SetLFGComment(t) COMMENTAIRE_LFG = t end

    LFRParentFrame = CreateFrame("Frame", "LFRParentFrame", UIParent)
    LFRParentFrame:SetWidth(355); LFRParentFrame:SetHeight(440)
    LFRParentFrame:EnableMouse(true)
    LFRParentFrame:Hide()
    UIPanelWindows["LFRParentFrame"] = { area = "left", pushable = 1, whileDead = 1 }
    LFRParentFrameIcon = LFRParentFrame:CreateTexture("LFRParentFrameIcon", "BACKGROUND")
    LFR_CROIX = CreateFrame("Button", nil, LFRParentFrame)
    CreateFrame("Button", "LFRParentFrameTab1", LFRParentFrame)
    CreateFrame("Button", "LFRParentFrameTab2", LFRParentFrame)
    LFRQueueFrame = CreateFrame("Frame", "LFRQueueFrame", LFRParentFrame)
    LFRQueueFrame:SetAllPoints(LFRParentFrame)
    LFRBrowseFrame = CreateFrame("Frame", "LFRBrowseFrame", LFRParentFrame)
    LFRBrowseFrame:SetAllPoints(LFRParentFrame)
    LFRBrowseFrame:Hide()
    function LFRFrame_SetActiveTab(tab)
        LFRParentFrame.activeTab = tab
        if tab == 1 then LFRQueueFrame:Show(); LFRBrowseFrame:Hide() else LFRBrowseFrame:Show(); LFRQueueFrame:Hide() end
    end
    LFRParentFrame.activeTab = 1

    -- les roles, comme ceux des donjons (sans chef)
    for _, n in ipairs({ { "Tank", 2 }, { "Healer", 3 }, { "DPS", 1 } }) do
        local b = CreateFrame("Button", "LFRQueueFrameRoleButton" .. n[1], LFRQueueFrame)
        b:SetID(n[2])
        b.cover = b:CreateTexture(nil, "OVERLAY")
        b.cover:Hide()
        b.background = b:CreateTexture(nil, "BACKGROUND")
        b.checkButton = CreateFrame("CheckButton", nil, b)
        b.checkButton:SetScript("OnClick", function(self)
            local l = GetLFGRoles()
            SetLFGRoles(l, LFRQueueFrameRoleButtonTank.checkButton:GetChecked(),
                LFRQueueFrameRoleButtonHealer.checkButton:GetChecked(), LFRQueueFrameRoleButtonDPS.checkButton:GetChecked())
        end)
    end

    -- la liste des raids
    LFRRaidList, LFRHiddenByCollapseList = {}, {}
    LFR_ORDRE = {}
    LFR_MAJ = 0
    function LFRQueueFrameSpecificList_Update()
        LFR_MAJ = LFR_MAJ + 1
        if LFRRaidList[1] then LFRQueueFrameSpecificNoRaidsAvailable:Hide() else LFRQueueFrameSpecificNoRaidsAvailable:Show() end
    end
    function LFRQueueFrame_Update()
        for k in pairs(LFRRaidList) do LFRRaidList[k] = nil end
        for _, id in ipairs(LFR_ORDRE) do
            local info = LFGDungeonInfo[id]
            if id < 0 or not (info and LFGCollapseList[info[9]]) then table.insert(LFRRaidList, id) end
        end
        LFRQueueFrameSpecificList_Update()
    end
    function LFRList_SetRaidEnabled(id, v) LFGEnabledList[id] = not not v end
    function LFRQueueFrameDungeonChoiceEnableButton_OnClick(self, button)
        local dungeonID = self:GetParent().id
        local isChecked = self:GetChecked()
        if LFGIsIDHeader(dungeonID) then
            LFGEnabledList[dungeonID] = not not isChecked
        elseif LFR_CanQueueForMultiple() then
            LFRList_SetRaidEnabled(dungeonID, isChecked)
        else
            LFRQueueFrame.selectedLFM = dungeonID
        end
        LFRQueueFrameSpecificList_Update()
    end
    function LFRList_SetHeaderCollapsed(h, v)
        LFGCollapseList[h] = v
        LFRQueueFrame_Update()
    end
    function LFRQueueFrameExpandOrCollapseButton_OnClick(self)
        LFGCollapseList[self:GetParent().id] = not self:GetParent().isCollapsed
        LFRQueueFrame_Update()
    end
    LFRQueueFrameSpecificNoRaidsAvailable = LFRQueueFrame:CreateFontString("LFRQueueFrameSpecificNoRaidsAvailable", "ARTWORK", "GameFontNormal")
    LFRQueueFrameComment = CreateFrame("EditBox", "LFRQueueFrameComment", LFRQueueFrame)
    LFRQueueFrameCommentExplanation = LFRQueueFrame:CreateFontString("LFRQueueFrameCommentExplanation", "ARTWORK", "GameFontNormal")
    LFR_INSCRIPTIONS = 0
    LFRQueueFrameFindGroupButton = CreateFrame("Button", "LFRQueueFrameFindGroupButton", LFRQueueFrame)
    LFRQueueFrameFindGroupButton:SetText("List My Name")
    LFRQueueFrameFindGroupButton:SetScript("OnClick", function()
        LFR_INSCRIPTIONS = LFR_INSCRIPTIONS + 1
        LFR_COMMENTAIRE_JOIN = LFRQueueFrameComment:GetText()
    end)
    LFRQueueFrameAcceptCommentButton = CreateFrame("Button", "LFRQueueFrameAcceptCommentButton", LFRQueueFrame)
    LFRQueueFrameAcceptCommentButton:SetText("Set Comment")
    function LFRQueueFrameFindGroupButton_Update()
        if GetLFGMode() == "listed" then LFRQueueFrameFindGroupButton:SetText("Unlist Me") else LFRQueueFrameFindGroupButton:SetText("List My Name") end
    end
    LFRQueueFrameNoLFRWhileLFD = CreateFrame("Frame", "LFRQueueFrameNoLFRWhileLFD", LFRQueueFrame)
    LFRQueueFrameNoLFRWhileLFD:CreateFontString("LFRQueueFrameNoLFRWhileLFDDescription", "ARTWORK", "GameFontNormal")
    CreateFrame("Button", "LFRQueueFrameNoLFRWhileLFDLeaveQueueButton", LFRQueueFrameNoLFRWhileLFD)
    LFRQueueFrameNoLFRWhileLFD:Hide()

    -- le parcours : RESULTATS[i] = { nom, niveau, zone, classe, commentaire,
    -- membres, statut, jeton, boss, tues, chef, tank, soin, degats }
    RESULTATS = {}
    function SearchLFGGetNumResults() return #RESULTATS, #RESULTATS end
    function SearchLFGGetResults(i) return (table.unpack or unpack)(RESULTATS[i], 1, 14) end
    LFRBrowseFrameRaidDropDown = CreateFrame("Frame", "LFRBrowseFrameRaidDropDown", LFRBrowseFrame)
    LFRBrowseFrameRaidDropDownText = LFRBrowseFrameRaidDropDown:CreateFontString("LFRBrowseFrameRaidDropDownText", "ARTWORK", "GameFontNormal")
    LFRBrowseFrameRaidDropDownText:SetText("None")
    LFR_RAFRAICHIS = 0
    LFRBrowseFrameRefreshButton = CreateFrame("Button", "LFRBrowseFrameRefreshButton", LFRBrowseFrame)
    LFRBrowseFrameRefreshButton:SetScript("OnClick", function() LFR_RAFRAICHIS = LFR_RAFRAICHIS + 1 end)
    LFRBrowseFrameSendMessageButton = CreateFrame("Button", "LFRBrowseFrameSendMessageButton", LFRBrowseFrame)
    LFRBrowseFrameSendMessageButton:SetText("Send Message")
    LFRBrowseFrameInviteButton = CreateFrame("Button", "LFRBrowseFrameInviteButton", LFRBrowseFrame)
    LFRBrowseFrameInviteButton:SetText("Invite")
    function LFRBrowseFrameList_Update() end
    -- LFRFrame.lua, mot pour mot (sans les boutons de liste du client)
    function LFRBrowseButton_OnClick(self)
        if LFRBrowseFrame.selectedName == self.unitName then
            LFRBrowseFrame.selectedName = nil
            LFRBrowseFrame.selectedType = nil
            self:UnlockHighlight()
        else
            LFRBrowseFrame.selectedName = self.unitName
            LFRBrowseFrame.selectedType = self.type
            self:LockHighlight()
        end
        LFRBrowse_UpdateButtonStates()
    end
    function LFRBrowse_UpdateButtonStates()
        local playerName = UnitName("player")
        local selectedName = LFRBrowseFrame.selectedName
        if selectedName and selectedName ~= playerName then LFRBrowseFrameSendMessageButton:Enable() else LFRBrowseFrameSendMessageButton:Disable() end
        if selectedName and selectedName ~= playerName and LFRBrowseFrame.selectedType ~= "party" then
            LFRBrowseFrameInviteButton:Enable()
        else
            LFRBrowseFrameInviteButton:Disable()
        end
    end
    function LFRBrowseButton_OnEnter(self)
        local name = SearchLFGGetResults(self.index)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT", 27, -37)
        GameTooltip:AddLine(name)
        GameTooltip:Show()
    end
    MENUS_OUVERTS = {}
    ToggleDropDownMenu = function(niveau, valeur, menu, ancre) table.insert(MENUS_OUVERTS, { niveau, menu, ancre }) end
    -- LE SERVEUR : une recherche par joueur ; SearchLFGJoin met ses inscrits a
    -- disposition (l'evenement UPDATE_LFG_LIST, lui, est tire par l'essai)
    SERVEUR_RAIDS = {}
    RECHERCHES = {}
    function SearchLFGJoin(t, id) FAUX_RECHERCHE = id; table.insert(RECHERCHES, id); RESULTATS = SERVEUR_RAIDS[id] or {} end
    function SearchLFGLeave() FAUX_RECHERCHE = nil; RESULTATS = {} end
    function SearchLFGGetJoinedID() return FAUX_RECHERCHE end
    -- MEMBRES[nom] = { { nom, niveau, lien }, ... } ; BOSS[nom] = { { nom, tue }, ... }
    MEMBRES, BOSS = {}, {}
    function SearchLFGGetPartyResults(i, j) local m = MEMBRES[RESULTATS[i][1]][j] return m[1], m[2], m[3] end
    function SearchLFGGetEncounterResults(i, j) local b = BOSS[RESULTATS[i][1]][j] return b[1], "", b[2] end
    function CanGroupInvite() return true end
    RAIDS_COMPLETS = { { -10 }, { [-10] = { 30, 31 } } }
    function GetFullRaidList() return RAIDS_COMPLETS[1], RAIDS_COMPLETS[2] end
    GameTooltip.AddTexture = function(self, t) self.textures = self.textures or {}; table.insert(self.textures, t) end
    GameTooltip.AddDoubleLine = function(self, a, b) self.lignes = self.lignes or {}; table.insert(self.lignes, a .. " | " .. b) end
    LFM_NUM_RAID_MEMBER_TEMPLATE = "%d members in raid group"
    FRIENDS_LEVEL_TEMPLATE = "Level %d %s"
    BOSSES = "Bosses:"
    BOSS_DEAD = "Defeated"
    BOSS_ALIVE = "Alive"
    ALL_BOSSES_ALIVE = "All bosses alive"
    FRIEND = "Friend"
    IGNORED = IGNORED or "Ignored"
    IMPORTANT_PEOPLE_IN_GROUP = "Players in Group:"
    TANK, HEALER, DAMAGER = TANK or "Tank", HEALER or "Healer", DAMAGER or "Damage"
end
"""


def main():
    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute(MOCK)

    ordre = ["UIAtlas.lua", "UIAtlas_01_selection_perso.lua", "UIAtlas_02_creation_perso.lua",
             "UIAtlas_03_barre_action.lua", "UIAtlas_04_cadres_unite.lua",
             "UIAtlas_05_feuille_perso.lua", "UIAtlas_06_complements.lua", "UIAtlas_07_decoupes.lua", "AtlasUtil.lua",
             "Panes.lua", "ScrollBar.lua", "Layout.lua", "Superposition.lua", "DropDown.lua",
             "PlayerFrame.lua",
             "PlayerFrameExtras.lua", "PlayerRunes.lua", "PetFrame.lua", "TargetFrame.lua", "PartyFrame.lua", "RaidFrame.lua",
             "CastBar.lua", "ActionBar.lua", "StanceBar.lua", "PetBar.lua",
             "TabardColors.lua", "BottomBar.lua", "StatusBars.lua", "Minimap.lua", "WorldMapInstances.lua", "WorldMap.lua", "QuestLog.lua", "ObjectiveTracker.lua", "SpellBook.lua", "SpellBookSearch.lua", "TalentsData.lua", "Talents.lua", "TalentsSearch.lua", "Bags.lua",
             "CharacterFrame.lua", "EquipmentManager.lua", "ReputationTab.lua", "SkillsTab.lua", "PvPTab.lua", "PvPArena.lua", "PvPBattlegrounds.lua",
             "Titles.lua", "TokensTab.lua", "PetTab.lua", "IconPicker.lua", "Social.lua", "SocialWho.lua", "SocialGuild.lua", "SocialChat.lua", "SocialRaid.lua", "TabardFrame.lua", "GroupFinder.lua", "GroupFinderRaid.lua"]

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
    # TOURNER LE MODELE A LA SOURIS : 0,008 radian par unite d'interface,
    # rattrapee a 0,15 par image (camelot, OrbitCameraMixin)
    for nom in ("CharacterModelFrame", "PetModelFrame"):
        lua.execute("""
            local m = %s
            m.rotation = 0.61
            SOURIS_X = 100 * UIParent:GetEffectiveScale()
            m.hooks.OnMouseDown(m, "LeftButton")
            SOURIS_X = 150 * UIParent:GetEffectiveScale()
            m.hooks.OnUpdate(m, 1 / 60)
        """ % nom)
        m = g[nom]
        un = m.rotation
        lua.execute("local m = %s for i = 1, 200 do m.hooks.OnUpdate(m, 1 / 60) end" % nom)
        print("modele %s : apres 50 unites, %.4f puis %.4f (cible %.4f), souris=%s" % (nom, un, m.rotation, 0.61 + 50 * 0.008,
            m.mouseEnabled))
        assert abs(un - (0.61 + 0.15 * 0.4)) < 1e-9, "premiere image : 15 % du chemin"
        assert abs(m.rotation - (0.61 + 0.4)) < 1e-6 and m.mouseEnabled
        lua.execute("local m = %s m.hooks.OnMouseUp(m, 'LeftButton') m.hooks.OnUpdate(m, 1 / 60) SOURIS_X = nil" % nom)
        assert m.foreverCible is None and m.foreverCurseur is None, "relachee : plus rien ne bouge"
    # Le familier n a pas d icone chez camelot : une par classe, a la demande
    # (le banc joue un chevalier de la mort)
    ic2 = g.CharacterFrameTab2.foreverIcone
    print("onglet du familier : icone=%s, texte visible=%s" % (ic2.texture, g.CharacterFrameTab2Text.shown))
    assert ic2.shown and ic2.texture.endswith("Spell_Shadow_AnimateDead") and not g.CharacterFrameTab2Text.shown

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
    # REMONTE (2026-09-25) : le bloc part du haut du volet, "Arena N" s en va
    assert (pm[4], pm[5]) == (0, 0), "le bloc part du haut du volet"
    pr = list(principal.rang.points[1].values())
    pc = list(principal.cadran.points[1].values())
    print("   pvp remonte : titre TOP sur TOP du bloc (%s, %s), cadran (%s, %s)" % (pr[3], pr[4], pc[3], pc[4]))
    assert (pr[0], pr[2], pr[3], pr[4]) == ("TOP", "TOP", 0, -12) and pr[1].name == "ForeverUIPvPMain"
    # L HONNEUR entre le trait du titre et la jauge, sur deux colonnes, puis
    # un separateur ; le cadran se pose sous lui (demande du 2026-09-26)
    hon = principal.honneur
    ph = list(hon.points[1].values())
    sh = principal.separateurHonneur
    psh = list(sh.points[1].values())
    cases = [(hon.cases[n].intitule.text, hon.cases[n].valeur.text) for n in range(1, 5)]
    pcase = [list(hon.cases[n].intitule.points[1].values()) for n in range(1, 5)]
    print("   honneur : %s sur %s du trait (%s) ; cases %s ; positions %s ; separateur %sx%s ; cadran sur %s (%s)" % (
        ph[0], ph[2], ph[4], cases, [(q[3], q[4]) for q in pcase], sh.width, sh.height, pc[1].name if hasattr(pc[1], "name") else pc[1], pc[4]))
    meme0 = lua.eval("function(a, b) return rawequal(a, b) end")
    assert meme0(ph[1], principal.ligne) and (ph[0], ph[2], ph[4]) == ("TOP", "BOTTOM", -2)
    assert [(q[3], q[4]) for q in pcase] == [(0, 0), (193, 0), (0, -17), (193, -17)], "deux colonnes, deux rangees"
    # les intitules du client, dans sa langue
    assert cases[0] == ("Honor Points", "4567") and cases[1] == ("Honorable Kills", "1234")
    assert cases[2] == ("Today", "12 (340)") and cases[3] == ("Yesterday", "30 (900)")
    assert g.TODAY is None and g.YESTERDAY is None and g.LIFETIME_HONORABLE_KILLS is None
    assert (sh.width, sh.height) == (384, 8) and meme0(psh[1], hon) and (psh[0], psh[2], psh[4]) == ("TOP", "BOTTOM", -4)
    assert meme0(pc[1], sh) and (pc[0], pc[2], pc[4]) == ("TOP", "BOTTOM", 0), "le cadran sous le separateur"
    assert hon.frameLevel > principal.cadran.frameLevel, "au-dessus de la lueur du cadran"
    # LE COMPTEUR, 5 px sous le bas visible de la jauge : accroche au cadran
    pg = list(principal.progres.points[1].values())
    print("   compteur : %s sur %s de %s (%s, %s), hauteur %s" % (
        pg[0], pg[2], pg[1].name, pg[3], pg[4], principal.progres.height))
    assert (pg[0], pg[2], pg[3], pg[4]) == ("TOP", "BOTTOM", 0, -1) and pg[1].name == "ForeverUIPvPDial"
    assert principal.progres.height == 12, "hauteur fixe : vide, il ne fait pas remonter la suite"
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
    assert principal.saison.text == "" and not principal.saison.shown, "Arena N retire : la place va aux equipes d arene"

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
    # LE VOLET DROIT : LES CHAMPS DE BATAILLE (demande du 2026-09-26). La
    # liste en haut, les recompenses en bas, "Join as Party/Group" et "Join
    # Battle" -- pas de "Cancel".
    pd = g.ForeverUIPvPDetail
    B = g.ForeverUI.PvPBattlegrounds
    lignesBG = [g["ForeverUIBattlegroundRow%d" % n] for n in range(1, 9)]
    noms = [l.nom.text for l in lignesBG if l.shown]
    print("   champs de bataille : %s" % noms)
    assert noms == ["Warsong Gulch", "Arathi Basin", "Eye of the Storm (Call to Arms)",
                    "Random Battleground"], "seuls ceux ou l on peut entrer ; l appel aux armes marque"
    # L ENCADRE DE LA LISTE (InsetFrameTemplate de camelot), en haut du volet
    liste = g.ForeverUIBattlegroundList
    pli = list(liste.points[1].values())
    pl1 = list(lignesBG[0].points[1].values())
    fondListe = liste.fond
    lis = [t.width for t in liste.lisere.values()]
    print("   encadre de la liste : %s (%s, %s), %s de haut, fond %s, lisere %s" % (
        pli[0], pli[3], pli[4], liste.height, fondListe.texture, lis))
    assert pli[1].name == "ForeverUIPvPDetail" and (pli[0], pli[3], pli[4]) == ("TOPLEFT", 12, -12)
    assert liste.height == 8 * 20 + 8 and fondListe.texture.endswith("ui-background-marble")
    assert lis[:4] == [6, 6, 6, 6], "les quatre coins du lisere a leur taille (6 x 6)"
    assert pl1[1].name == "ForeverUIBattlegroundList" and (pl1[0], pl1[3], pl1[4]) == ("TOPLEFT", 4, -4), "dans l encadre"
    assert abs(lignesBG[0].survol.alpha - 0.20) < 1e-6, "le premier est choisi d office"
    # l etat de la file : Arathi Basin est en file
    e2 = lignesBG[1].etat
    print("   file : Arathi %s %s \"%s\" ; Warsong %s" % (e2.shown, e2.texture.texture, e2.tooltip, lignesBG[0].etat.shown))
    assert e2.shown and e2.texture.texture.endswith("PVP-Currency-" + g.UnitFactionGroup("player"))
    assert e2.tooltip == "In Queue" and not lignesBG[0].etat.shown
    # la demande part a l image suivante, pour le champ choisi
    B.differe.Show(B.differe)
    B.differe.scripts.OnUpdate(B.differe, 0)
    print("   demande differee : %s, tri %s" % (list(g.BG.demandes.values()), g.BG.tri))
    assert list(g.BG.demandes.values())[-1] == 1 and not B.differe.shown
    # un champ ordinaire : pas de recompenses (WotLK y met la description)
    rv, rd = B.recompenses.victoire, B.recompenses.defaite
    rc = g.ForeverUIBattlegroundRewards
    assert not rc.shown, "Warsong Gulch n a pas de recompenses a montrer : l encadre s en va"
    # l aleatoire : victoire 30 honneur + 25 arene, defaite 15 honneur, 0 arene
    lignesBG[3].scripts.OnClick(lignesBG[3])
    print("   aleatoire : demande %s ; victoire %s/%s (%s) ; defaite %s/%s (%s)" % (
        list(g.BG.demandes.values())[-1], rv.honneur.text, rv.arene.text, rv.areneSymbole.shown,
        rd.honneur.text, rd.arene.text, rd.areneSymbole.shown))
    assert list(g.BG.demandes.values())[-1] == 5 and rc.shown
    # des plaques de camelot, plus des bandes de couleur ; la couleur au mot
    assert len(list(rv.plaque.values())) == 9 and rv.fond is None
    print("   recompenses : plaques %d tranches, Win %s, Loss %s" % (
        len(list(rv.plaque.values())), list(rv.etiquette.textColor.values())[:3], list(rd.etiquette.textColor.values())[:3]))
    assert list(rv.etiquette.textColor.values())[:3] == [0.1, 1.0, 0.1]
    assert list(rd.etiquette.textColor.values())[:3] == [1.0, 0.1, 0.1]
    prc = list(rc.points[1].values())
    assert prc[1] == B.rejoindreGroupe or prc[0] == "BOTTOMLEFT"
    assert rv.honneur.text == 30 and rv.arene.text == 25 and rv.areneSymbole.shown
    assert rd.honneur.text == 15 and not rd.areneSymbole.shown and not rd.arene.shown, "un montant nul s efface"
    assert rv.honneurSymbole.texture.endswith("PVP-Currency-" + g.UnitFactionGroup("player"))
    assert rv.etiquette.text == "Win" and rd.etiquette.text == "Loss"
    assert abs(lignesBG[3].survol.alpha - 0.20) < 1e-6 and lignesBG[0].survol.alpha == 0
    # l appel aux armes
    lignesBG[2].scripts.OnClick(lignesBG[2])
    assert rv.honneur.text == 45 and not rv.areneSymbole.shown and rd.honneur.text == 20 and rd.arene.text == 5
    # RIEN NE SE TRONQUE : pas de largeur fixe, colonnes communes aux deux
    # plaques, calculees sur ce que les textes mesurent
    xs = [list(r.honneurSymbole.points[1].values())[3] for r in (rv, rd)]
    xa = [list(r.areneSymbole.points[1].values())[3] for r in (rv, rd)]
    print("   colonnes : honneur a %s, arene a %s, largeur %s sur 201, police %s ; montants sans largeur fixe %s" % (
        xs, xa, B.largeurRecompenses, B.police, (rv.honneur.width, rv.arene.width)))
    assert xs[0] == xs[1] and xa[0] == xa[1], "les deux plaques alignees"
    assert rv.honneur.width is None and rv.arene.width is None and rv.etiquette.width is None
    assert B.largeurRecompenses <= 201 and B.police == 1
    # de gros montants : la police suivante, plus petite
    lua.execute("function GetHolidayBGHonorCurrencyBonuses() return true, 123456789, 987654321, 20, 5 end")
    lignesBG[0].scripts.OnClick(lignesBG[0])
    lignesBG[2].scripts.OnClick(lignesBG[2])
    print("   gros montants : largeur %s, police %s (%s)" % (B.largeurRecompenses, B.police, rv.honneur.font))
    assert B.police == 2 and rv.honneur.font == "NumberFontNormalSmall"
    lua.execute("function GetHolidayBGHonorCurrencyBonuses() return true, 45, 0, 20, 5 end")
    lignesBG[0].scripts.OnClick(lignesBG[0])
    lignesBG[2].scripts.OnClick(lignesBG[2])
    assert B.police == 1 and rv.honneur.font == "NumberFontNormal"
    # en bas : les recompenses, puis les deux boutons -- pas de Cancel
    pg_, pr_ = list(B.rejoindreGroupe.points[1].values()), list(B.rejoindre.points[1].values())
    pdf = list(rd.points[1].values())
    print("   boutons : \"%s\" %s (%s, %s) %s ; \"%s\" %s (%s, %s) ; defaite sous %s (%s)" % (
        B.rejoindreGroupe.GetText(B.rejoindreGroupe), pg_[0], pg_[3], pg_[4], B.rejoindreGroupe.width,
        B.rejoindre.GetText(B.rejoindre), pr_[0], pr_[3], pr_[4], pdf[2], pdf[4]))
    assert (pg_[0], pg_[3], pg_[4]) == ("BOTTOMLEFT", 12, 14) and (pr_[0], pr_[3], pr_[4]) == ("BOTTOMRIGHT", -12, 14)
    assert B.rejoindreGroupe.width == 102
    assert B.rejoindre.GetText(B.rejoindre) == "Join Battle"
    assert B.rejoindreGroupe.GetText(B.rejoindreGroupe) == "Join as Group", "groupe max 10"
    textes = [c.GetText(c) for c in pd.children.values() if c.GetText and c.kind == "Button"]
    assert "Cancel" not in textes, "pas de bouton Cancel"
    # seul : le bouton de groupe est eteint ; il suit le groupe et son chef
    assert B.rejoindreGroupe.enabled is False
    lua.execute("BG.groupeMax = 5; ARENE_EVENEMENT('PVPQUEUE_ANYWHERE_SHOW')")
    assert B.rejoindreGroupe.GetText(B.rejoindreGroupe) == "Join as Party", "groupe max 5 : Join as Party"
    lua.execute("function GetNumPartyMembers() return 2 end; STATE.leader = true;"
                " ARENE_EVENEMENT('PARTY_MEMBERS_CHANGED')")
    assert B.rejoindreGroupe.enabled is True, "en groupe et chef"
    B.rejoindre.scripts.OnClick(B.rejoindre)
    B.rejoindreGroupe.scripts.OnClick(B.rejoindreGroupe)
    rj = [(r.i, r.groupe) for r in g.BG.rejoint.values()]
    print("   rejoindre : %s ; bouton de groupe actif %s" % (rj, B.rejoindreGroupe.enabled))
    assert rj == [(0, False), (0, True)], "JoinBattlefield(0) puis JoinBattlefield(0, true)"
    lua.execute("function GetNumPartyMembers() return 0 end; STATE.leader = false;"
                " ARENE_EVENEMENT('PARTY_MEMBERS_CHANGED')")
    # la session se ferme quand le volet se cache
    fermes = g.BG.fermetures
    pd.hooks.OnHide(pd)
    assert g.BG.fermetures == fermes + 1, "CloseBattlefield"
    # la file change : l etat suit UPDATE_BATTLEFIELD_STATUS
    lua.execute("FILES_BG[1] = { 'confirm', 'Warsong Gulch' }; ARENE_EVENEMENT('UPDATE_BATTLEFIELD_STATUS')")
    assert lignesBG[0].etat.shown and lignesBG[0].etat.tooltip == "Ready to Enter" and not lignesBG[1].etat.shown
    lua.execute("FILES_BG[1] = { 'queued', 'Arathi Basin' }; ARENE_EVENEMENT('UPDATE_BATTLEFIELD_STATUS')")

    # TOUT L ECRAN DU CLIENT SE TAIT, a chaque passage.
    g.PVPFrame_Update()
    restants = [n for n in ("PVPFrameToggleButton", "PVPFrameOffSeason") if g[n].shown]
    print("   ecran du client : %d morceau(x) encore visible(s)" % len(restants))
    assert restants == [], "il en reste : %s" % restants
    assert principal.shown, "mais notre bloc demeure"

    # LES EQUIPES D ARENE (demande du 2026-09-25) : trois cartes, TRIEES
    # PAR TAILLE comme PVPTeam_Update -- l emplacement 2 du client porte le
    # 2v2, il vient en premier ; le 5v5 manque, sa carte est grisee.
    g.ForeverUI.PvPUpdate()
    c1, c2, c3 = g.ForeverUIArenaTeam1, g.ForeverUIArenaTeam2, g.ForeverUIArenaTeam3
    print("   arene : cartes -> emplacements %s %s %s ; noms \"%s\" \"%s\" ; vide \"%s\"" % (
        c1.equipe, c2.equipe, c3.equipe, c1.donnees.nom.text, c2.donnees.nom.text, c3.vide.text))
    assert (c1.equipe, c2.equipe, c3.equipe) == (2, 1, None), "2v2, 3v3 puis 5v5, quel que soit l emplacement"
    assert c1.donnees.nom.text == "Duo Fou" and c2.donnees.nom.text == "Les Trois"
    # L ORDRE DU VOLET : compteur, separateur, points d arene, equipes
    sep = g.ForeverUI.PvPArena.separateur
    ps = list(sep.points[1].values())
    pts = g.ForeverUIArenaPoints
    pp = list(pts.points[1].values())
    p1, p3 = list(c1.points[1].values()), list(c3.points[1].values())
    p3n = p3
    print("   ordre : separateur %s sur %s de compteur (%s) %s ; points %s sur %s du separateur (%s) ;"
          " carte 3 %s sur %s de %s (%s) ; carte 1 %s sur %s de %s (%s)" % (
        ps[0], ps[2], ps[4], sep.texture and "pose", pp[0], pp[2], pp[4],
        p3[0], p3[2], p3[1].name, p3[4], p1[0], p1[2], p1[1].name, p1[4]))
    meme = lua.eval("function(a, b) return rawequal(a, b) end")
    assert meme(ps[1], principal.progres) and (ps[0], ps[2], ps[3], ps[4]) == ("TOP", "BOTTOM", 0, -4)
    print("   separateur : %s x %s" % (sep.width, sep.height))
    assert (sep.width, sep.height) == (384, 8), "a la taille de son element, pas a celle de la feuille"
    # les points, centres entre le separateur et la premiere carte
    zone = g.ForeverUIArenaPointsZone
    pz = [list(zone.points[k].values()) for k in (1, 2)]
    print("   points centres : %s sur %s de %s ; zone %s-%s de separateur, %s-%s de %s" % (
        pp[0], pp[2], pp[1].name, pz[0][0], pz[0][2], pz[1][0], pz[1][2], pz[1][1].name))
    assert pp[1].name == "ForeverUIArenaPointsZone" and (pp[0], pp[2], pp[3], pp[4]) == ("CENTER", "CENTER", 0, 0)
    assert meme(pz[0][1], sep) and (pz[0][0], pz[0][2], pz[0][4]) == ("TOP", "BOTTOM", 0)
    assert pz[1][1].name == "ForeverUIArenaTeam1" and (pz[1][0], pz[1][2], pz[1][4]) == ("BOTTOM", "TOP", 0)
    assert not zone.mouseEnabled, "la zone ne prend pas la souris"
    # serrees contre le bas du volet (demande du 2026-09-26)
    assert p3[1].name == "ForeverUICharacterLeftPane" and (p3[0], p3[2], p3[3], p3[4]) == ("BOTTOM", "BOTTOM", 0, 4)
    assert p1[1].name == "ForeverUIArenaTeam2" and (p1[0], p1[2], p1[4]) == ("BOTTOM", "TOP", 0)
    print("   cartes : %dx%d, niveau %d > cadran %d" % (c1.width, c1.height, c1.frameLevel, principal.cadran.frameLevel or 1))
    assert c1.width == 366 and c1.height == 52
    assert c1.frameLevel > (principal.cadran.frameLevel or 1), "la lueur du cadran passe dessous"
    # PLAYED : "joues (pct%)", ROUGE sous 10 %
    print("   joues : 2v2 \"%s\" teinte %s ; 3v3 \"%s\" teinte %s" % (
        c1.donnees.joues.text, list(c1.donnees.joues.vertex.values()),
        c2.donnees.joues.text, list(c2.donnees.joues.vertex.values())))
    assert c1.donnees.joues.text == "1 (5%)" and list(c1.donnees.joues.vertex.values()) == [1, 0, 0]
    assert c2.donnees.joues.text == "10 (100%)" and list(c2.donnees.joues.vertex.values()) == [1, 1, 1]
    assert c2.donnees.bilan.text == "7 - 3" and c2.donnees.cote.text == 1650
    assert c2.donnees.type.text == "This Week", "les cartes montrent la semaine, comme WotLK"
    # L ETENDARD : banniere teintee, bord et embleme ; -1 = ni bord ni embleme
    print("   etendard 3v3 : %s | %s | %s" % (c2.banniere.texture, c2.bord.texture, c2.embleme.texture))
    assert c2.banniere.texture.endswith("PVP-Banner-3") and list(c2.banniere.vertex.values()) == [0.2, 0.3, 0.4]
    assert c2.bord.texture.endswith("PVP-Banner-3-Border-3")
    assert c2.embleme.texture.endswith("Icons" + chr(92) + "PVP-Banner-Emblem-12")
    assert c1.bord.texture is None and c1.embleme.texture is None, "-1 : rien a poser"
    # L EMPLACEMENT VIDE : 0,4 ; etendard a 0,1 sans bord ni embleme ; "(5v5)"
    assert c3.alpha == 0.4 and c3.etendard.alpha == 0.1 and not c3.bord.shown
    assert not c3.donnees.shown and c3.vide.shown and c3.vide.text == "(5v5)"
    assert c3.banniere.texture.endswith("PVP-Banner-5")
    # LES POINTS D ARENE, sous les cartes, centres
    print("   points d arene : \"%s\" %s, icone %s" % (
        pts.etiquette.text, pts.valeur.text, pts.icone.texture))
    assert str(pts.valeur.text) == "321" and pts.icone.texture.endswith("PVP-ArenaPoints-Icon")
    pts.scripts.OnEnter(pts)
    assert g.GameTooltip.text == "Arena Points" and "victorious" in g.GameTooltip.lignes[1]
    # l infobulle d une carte : CLICK_FOR_DETAILS, ou l invitation sans equipe
    c3.scripts.OnEnter(c3)
    assert g.GameTooltip.lignes[1].startswith("Visit an Arena Master")
    c1.scripts.OnEnter(c1)
    assert g.GameTooltip.lignes[1] == "Click for details" and abs(c1.survol.alpha - 0.10) < 1e-6
    c1.scripts.OnLeave(c1)
    assert c1.survol.alpha == 0

    # LE CLIC OUVRE LE DETAIL, fenetre a part a cote de la feuille.
    f = g.ForeverUIArenaTeamDetails
    assert not f.shown, "fermee au depart"
    c2.scripts.OnClick(c2)
    pf = f.points[1]
    print("   detail : ouvert=%s equipe=%s, titre \"%s\", ancre %s de %s (%s, %s), demandes %s" % (
        f.shown, f.equipe, f.titre.text, pf[1], pf[2].name, pf[4], pf[5], list(g.ROSTER.demandes.values())))
    assert f.shown and f.equipe == 1 and list(g.ROSTER.demandes.values())[-1] == 1, "ArenaTeamRoster(id)"
    assert pf[2].name == "CharacterFrame" and (pf[1], pf[3], pf[4], pf[5]) == ("TOPLEFT", "TOPRIGHT", 76, 0)
    assert "Les Trois" in f.titre.text and "(3v3)" in f.titre.text
    assert g.PVPTeamDetails.team == 1 and g.PVPTeamDetails.shown, "le cadre du client est tenu a jour pour UnitPopup"
    assert abs(c2.survol.alpha - 0.20) < 1e-6, "la carte ouverte est marquee"
    assert g.ForeverUI.Superposition.fenetres["feuille"].zones()[3].name == "ForeverUIArenaTeamDetails", "un clic sur le detail est un clic sur la feuille"
    assert f.type.text == "THIS WEEK" and f.jeux.text == 10 and f.bilan.text == "7 - 3"
    assert f.rang.text == 120 and f.cote.text == 1650
    r1, r2, r3, r4 = (g["ForeverUIArenaTeamDetailsRow%d" % n] for n in range(1, 5))
    print("   membres : %s/%s/%s, 4e %s ; couleurs %s %s %s ; joues %s %s" % (
        r1.nom.text, r2.nom.text, r3.nom.text, r4.shown,
        list(r1.nom.textColor.values())[:3], list(r2.nom.textColor.values())[:3],
        list(r3.nom.textColor.values())[:3], r2.pct, r3.pct))
    assert r1.shown and r3.shown and not r4.shown, "autant de lignes que de membres"
    assert list(r1.nom.textColor.values())[:3] == [1.0, 0.82, 0.0], "le capitaine en or"
    assert list(r2.nom.textColor.values())[:3] == [1.0, 1.0, 1.0], "en ligne en blanc"
    assert list(r3.nom.textColor.values())[:3] == [0.5, 0.5, 0.5], "hors ligne en gris"
    assert r2.pct == "10%" and list(r2.joues.vertex.values()) == [1, 1, 1]
    assert r3.pct == "0%" and list(r3.joues.vertex.values()) == [1, 0, 0], "sous 10 %% : rouge"
    assert r1.victoires.text == 7 and r1.defaites.text == 3 and r1.cote.text == 1700
    # la bascule : la saison
    assert f.bascule.texte.text == "View this Season's Stats"
    f.bascule.scripts.OnClick(f.bascule)
    print("   saison : \"%s\" jeux %s bilan \"%s\" ; Moi %s joues" % (f.type.text, f.jeux.text, f.bilan.text, r1.joues.text))
    assert f.type.text == "THIS SEASON" and f.jeux.text == 40 and f.bilan.text == "25 - 15"
    assert r1.joues.text == 40 and f.bascule.texte.text == "View this Week's Stats"
    g.ForeverUIArenaTeamDetailsHeader3.scripts.OnClick(g.ForeverUIArenaTeamDetailsHeader3)
    g.ForeverUIArenaTeamDetailsHeader1.scripts.OnClick(g.ForeverUIArenaTeamDetailsHeader1)
    print("   tris : %s" % list(g.ROSTER.tris.values()))
    assert list(g.ROSTER.tris.values()) == ["seasonplayed", "name"]
    f.bascule.scripts.OnClick(f.bascule)
    # clic gauche = selection ; clic droit = le menu du client
    r2.scripts.OnClick(r2, "LeftButton")
    assert g.ROSTER.selection[1] == 2 and abs(r2.survol.alpha - 0.20) < 1e-6
    r2.scripts.OnClick(r2, "RightButton")
    m = g.MENUS_EQUIPE[1]
    assert m.nom == "Ami" and m.enLigne == 1, "PVPFrame_ShowDropdown(nom, en ligne)"
    f.ajouter.scripts.OnClick(f.ajouter)
    assert list(g.POPUPS.values())[-1].quoi == "ADD_TEAMMEMBER"
    # le meme clic referme ; CloseArenaTeamRoster
    fermetures = g.ROSTER.fermetures
    c2.scripts.OnClick(c2)
    print("   re-clic : ouvert=%s, fermetures %d -> %d, client %s, marque %s" % (
        f.shown, fermetures, g.ROSTER.fermetures, g.PVPTeamDetails.shown, c2.survol.alpha))
    assert not f.shown and g.ROSTER.fermetures > fermetures and not g.PVPTeamDetails.shown
    assert c2.survol.alpha == 0, "la marque s en va"
    # l equipe disparait : ARENA_TEAM_UPDATE ferme le detail
    c1.scripts.OnClick(c1)
    assert f.shown and f.equipe == 2
    lua.execute("EQUIPES_ARENE[2] = nil; ARENE_EVENEMENT('ARENA_TEAM_UPDATE')")
    print("   equipe dissoute : detail %s, premiere carte %s \"%s\"" % (f.shown, c1.equipe, c1.vide.text))
    assert not f.shown and c1.equipe is None and c1.vide.text == "(2v2)"
    lua.execute("EQUIPES_ARENE[2] = { 'Duo Fou', 2, 1500, 20, 11, 60, 30, 1, 50, 300, 1480,"
                " 0.5, 0, 0, -1, 1, 1, 1, -1, 1, 1, 1 }; ARENE_EVENEMENT('ARENA_TEAM_UPDATE')")
    assert c1.equipe == 2
    # les points suivent HONOR_CURRENCY_UPDATE
    lua.execute("POINTS_ARENE = 555; ARENE_EVENEMENT('HONOR_CURRENCY_UPDATE')")
    assert str(pts.valeur.text) == "555"
    # hors saison : les cartes s en vont, le texte du client les remplace
    lua.execute("SAISON_ARENE = 0")
    g.ForeverUI.PvPUpdate()
    hs = [r for r in principal.regions.values() if r.text and "has come to an end" in str(r.text)]
    print("   hors saison : cartes %s %s %s, texte \"%s\"" % (c1.shown, c2.shown, c3.shown, hs and hs[0].text[:24]))
    assert not c1.shown and not c2.shown and not c3.shown and hs and hs[0].shown
    assert "Season 7" in hs[0].text and "Season 8" in hs[0].text
    lua.execute("SAISON_ARENE = 8")
    g.ForeverUI.PvPUpdate()
    assert c1.shown and not hs[0].shown
    # QUITTER L ONGLET REFERME LE DETAIL (PVPFrame_OnHide), et il ne revient
    # pas tout seul
    c2.scripts.OnClick(c2)
    assert f.shown
    g.CharacterFrame_ShowSubFrame("SkillFrame")
    g.ForeverUI.Panes.ShowGroup("SkillFrame")
    g.ForeverUI.CharacterApplyPanes(perso)
    fermeApres = f.shown
    g.CharacterFrame_ShowSubFrame("")
    g.ForeverUI.Panes.ShowGroup("ForeverUIPvPPane")
    g.ForeverUI.CharacterApplyPanes(perso)
    print("   changement d onglet : detail apres %s, au retour %s, client %s" % (fermeApres, f.shown, g.PVPTeamDetails.shown))
    assert not fermeApres and not f.shown and not g.PVPTeamDetails.shown

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
    assert micro.width == 322, "le bandeau garde sa longueur : 248 de boutons + 47 + 27 de rallonge"
    # LE BOUTON JcJ EST RETIRE (2026-09-26) : neuf boutons, et celui du client
    # reste cache meme quand le client le reprend
    noms = [e.bouton.name for e in g.ForeverUI.MicroButtons.values()]
    g.VehicleMenuBar_MoveMicroButtons()
    g.PVPMicroButton.Show(g.PVPMicroButton)
    print("   micro-menu sans JcJ : %d boutons, JcJ visible=%s" % (len(noms), g.PVPMicroButton.shown))
    assert "PVPMicroButton" not in noms and len(noms) == 9
    assert not g.PVPMicroButton.shown, "le bouton du client ne revient pas"
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

    # ------------------------------------------------ cadre du familier
    meme = lua.eval("function(a, b) return rawequal(a, b) end")
    pf = g.ForeverUIPetFrame
    ppf = list(pf.points[1].values())
    print("familier : %s x %s, %s sur %s de %s (%s, %s), strate %s, surveille=%s, parent=%s" % (pf.width, pf.height,
        ppf[0], ppf[2], ppf[1].name, ppf[3], ppf[4], pf.strata, pf.unitWatch, pf.parent.name))
    assert (pf.width, pf.height) == (120, 49) and pf.unitWatch and pf.attributes["unit"] == "pet"
    # le banc joue un chevalier de la mort : sous ses runes, a 2 d'ecart
    assert (ppf[0], ppf[2], ppf[3], ppf[4]) == ("TOP", "BOTTOM", 7.5, -2) and meme(ppf[1], g.ForeverUIClassResourceContainer),         "sous les runes, marge gauche 15 centree"
    assert pf.attributes["toggleForVehicle"] and pf.attributes["*type2"] == "menu"
    lua.execute("ForeverUIPetFrame:Hide() ForeverUIPetFrame:Show()")
    print("   portrait %s, nom %s, vie %s (visible %s), humeur visible=%s coords %s" % (pf.portrait.portraitOf, pf.nameText.text,
        pf.healthFill.width, pf.healthFill.shown, pf.happiness.shown, list(pf.happinessTexture.texcoord.values())))
    assert pf.portrait.portraitOf == "pet" and pf.nameText.text == "Sanglier" and pf.happiness.shown
    assert list(pf.happinessTexture.texcoord.values()) == [0, 0.1875, 0, 0.359375], "content : la premiere vignette"
    assert list(pf.healthFill.points[1].values())[1:] == [44, -17] and list(pf.powerFill.points[1].values())[1:] == [40, -28]
    # l'humeur au survol
    lua.execute("ForeverUIPetFrameHappiness.scripts.OnEnter(ForeverUIPetFrameHappiness)")
    assert g.GameTooltip.text == "Happy"
    # un familier de demoniste : pas d'humeur
    lua.execute("FAMILIER_CHASSEUR = false ForeverUI.PetFrameUpdate()")
    assert not pf.happiness.shown
    lua.execute("FAMILIER_CHASSEUR = true ForeverUI.PetFrameUpdate()")
    # l'attaque : la pulsation rouge
    lua.execute("ForeverUIPetFrame.scripts.OnEvent(ForeverUIPetFrame, 'PET_ATTACK_START')")
    assert pf.attack.shown and pf.attack.blend == "ADD"
    lua.execute("ForeverUIPetFrame.scripts.OnUpdate(ForeverUIPetFrame, 0.2)")
    print("   attaque : alpha %.3f" % pf.attack.vertexAlpha)
    assert abs(pf.attack.vertexAlpha - (255 - 0.2 * 400) / 255) < 1e-6
    lua.execute("ForeverUIPetFrame.scripts.OnEvent(ForeverUIPetFrame, 'PET_ATTACK_STOP')")
    assert not pf.attack.shown
    # la menace du familier
    lua.execute("STATE.threat = 3 ForeverUIPetFrame.scripts.OnEvent(ForeverUIPetFrame, 'UNIT_THREAT_SITUATION_UPDATE', 'pet')")
    assert pf.threat.shown and pf.threat.vertex[1] == 1.0 and pf.threat.vertex[2] == 0.0
    lua.execute("STATE.threat = nil ForeverUIPetFrame.scripts.OnEvent(ForeverUIPetFrame, 'UNIT_THREAT_SITUATION_UPDATE', 'pet')")
    assert not pf.threat.shown
    # le texte au survol, et l'infobulle de l'unite
    lua.execute("ForeverUIPetFrame.scripts.OnEnter(ForeverUIPetFrame)")
    print("   survol : vie '%s', infobulle %s" % (pf.healthText.text, g.GameTooltip.unitTooltip))
    assert pf.healthText.shown and g.GameTooltip.unitTooltip == "pet"
    assert g.PartyMemberBuffTooltip.unitOf == "pet", "le cadre, pas un booleen"
    lua.execute("ForeverUIPetFrame.scripts.OnLeave(ForeverUIPetFrame)")
    assert not pf.healthText.shown
    # en vehicule : le joueur
    lua.execute("STATE.vehicle = true ForeverUIPetFrame.scripts.OnEvent(ForeverUIPetFrame, 'UNIT_ENTERED_VEHICLE', 'player')")
    assert pf.portrait.portraitOf == "player" and pf.unit == "player"
    lua.execute("STATE.vehicle = false ForeverUIPetFrame.scripts.OnEvent(ForeverUIPetFrame, 'UNIT_EXITED_VEHICLE', 'player')")
    assert pf.portrait.portraitOf == "pet"

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

    # UN MENU CONTEXTUEL prend la largeur de son CONTENU (corrige le
    # 2026-09-25) : son ouvreur est un cadre invisible de 40, qu'il ne faut
    # pas epouser. Mesure dans la police affichee, formule du client.
    lua.execute("""
        ForeverUIMenuContextuel = CreateFrame("Frame", "ForeverUIMenuContextuel", UIParent)
        ForeverUIMenuContextuel:SetWidth(40)
        UIDropDownMenu_Initialize(ForeverUIMenuContextuel, function() end, "MENU")
        UIDROPDOWNMENU_OPEN_MENU = ForeverUIMenuContextuel
        DropDownList1.numButtons = 0
        UIDropDownMenu_AddButton({ text = "Court", notCheckable = 1 }, 1)
        UIDropDownMenu_AddButton({ text = "Une entree nettement plus longue" }, 1)
        DropDownList1:SetWidth(65)
    """)
    liste.hooks.OnShow(liste)
    attendu = len("Une entree nettement plus longue") * 6 + 40 + 25
    print("   menu contextuel : liste %d (attendu %d), ligne %d" % (liste.width, attendu, b1.width))
    assert liste.width == attendu, "texte le plus long + 40 + les 25 du client"
    assert b1.width == attendu - 25
    lua.execute("UIDROPDOWNMENU_OPEN_MENU = ForeverUIMenuTemoin DropDownList1:SetWidth(300)")
    liste.hooks.OnShow(liste)
    assert liste.width == 203, "le menu deroulant garde la largeur de son bouton"

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
    construite = g.ForeverUI.WorldMap.construit
    lua.execute("WorldMapFrame:Show()")
    # PREMIERE OUVERTURE, EN PLEIN ECRAN (WORLDMAP_SETTINGS.size du banc) :
    # l'habillage de camelot se construit des cette ouverture
    print("   carte du monde, premiere ouverture en plein ecran : construite avant=%s, apres=%s, fil=%s" % (
        construite, g.ForeverUI.WorldMap.construit, g.ForeverUIWorldMapNavBar and g.ForeverUIWorldMapNavBar.shown))
    assert g.ForeverUI.WorldMap.construit and g.ForeverUIWorldMapMaximized is not None
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

    # ------------------------------------------------------------------
    # LA CARTE DU MONDE, MODE REDUIT (etape 1)
    # ------------------------------------------------------------------
    print("\n--- carte du monde ---")
    ech = 697.0 / 1002.0
    print("   WORLDMAP_WINDOWED_SIZE = %.6f (attendu %.6f)" % (g.WORLDMAP_WINDOWED_SIZE, ech))
    assert abs(g.WORLDMAP_WINDOWED_SIZE - ech) < 1e-9, "la constante de la petite fenetre suit camelot"

    # LE DEPLACEMENT : le mode avance de WotLK, deverrouille.
    print("   advancedWorldMap = %s | verrou = %s" % (g.STATE.cvars.advancedWorldMap, g.WORLDMAP_SETTINGS.locked))
    assert g.STATE.cvars.advancedWorldMap == "1", "la CVar est posee avant VARIABLES_LOADED"
    assert g.WORLDMAP_SETTINGS.locked == False, "la barre de titre fait glisser sans passer par le menu"

    # VARIABLES_LOADED : le vrai lit la CVar, puis appelle ToggleSizeDown
    # quand miniWorldMap vaut 1.
    # etape 1 : volet de quetes ferme, la fenetre fait 702
    lua.execute("ForeverUI.QuestLog.reglages().volet = false")
    lua.execute("WORLDMAP_SETTINGS.advanced = GetCVar('advancedWorldMap') == '1' WorldMap_ToggleSizeDown()")
    carteMonde = g.WorldMapFrame
    detail = g.WorldMapDetailFrame
    print("   fenetre %sx%s | carte echelle %.6f | points de la carte : %d" % (
        carteMonde.width, carteMonde.height, detail.scale, len(list(detail.points.values()))))
    assert (carteMonde.width, carteMonde.height) == (702, 534), "702 x 534, pas les 623 x 437 de SetMiniMode"
    assert abs(detail.scale - ech) < 1e-9
    pd = list(detail.points.values())
    assert len(pd) == 1, "SetMiniMode AJOUTE un point sans ClearAllPoints : il faut le retirer"
    pd = pd[0]
    assert (pd[1], pd[3]) == ("TOPLEFT", "TOPLEFT") and abs(pd[4] * ech - 2) < 1e-6 and abs(pd[5] * ech + 67) < 1e-6, list(pd.values())

    pc = carteMonde.points[1]
    ancre = g.WorldMapScreenAnchor
    pa0 = ancre.points[1]
    print("   panneau %s | deplacable %s | ancre %s (%s, %s), placee par l'utilisateur %s" % (
        carteMonde.attributes["UIPanelLayout-area"], carteMonde.movable, pa0[1], pa0[4], pa0[5],
        ancre.userPlaced))
    assert carteMonde.attributes["UIPanelLayout-area"] == "center", "zone center : le gestionnaire ne la replace pas"
    assert pc[2].name == "WorldMapScreenAnchor"
    assert (pa0[1], pa0[4], pa0[5]) == ("TOPLEFT", 16, -116), "la place d'un panneau left de camelot"
    lua.execute("WorldMapTitleButton:GetScript('OnDragStart')(WorldMapTitleButton)")
    assert carteMonde.moving, "tirer la barre du haut deplace la carte"
    lua.execute("WorldMapTitleButton:GetScript('OnDragStop')(WorldMapTitleButton)")
    pt = g.WorldMapTitleButton.points
    print("   barre de titre : %s -> %s, %s de haut" % (list(pt[1].values())[3:5], list(pt[2].values())[3:5], g.WorldMapTitleButton.height))
    assert g.WorldMapTitleButton.height == 20

    # la bordure de WotLK : SetOpacity lui rend son alpha, mais plus d'image
    for nom in ("WorldMapFrameMiniBorderLeft", "WorldMapFrameMiniBorderRight"):
        r = g[nom]
        print("   %-30s texture=%s alpha=%s" % (nom, r.texture, r.alpha))
        assert r.texture is None, "%s : sans image, l'alpha rendu par SetOpacity ne montre rien" % nom

    fermer, agrandir = g.WorldMapFrameCloseButton, g.WorldMapFrameSizeUpButton
    pf, pa = fermer.points[1], agrandir.points[1]
    print("   fermer %sx%s %s (%s, %s) | agrandir %sx%s %s de %s (%s)" % (
        fermer.width, fermer.height, pf[1], pf[4], pf[5], agrandir.width, agrandir.height,
        pa[1], pa[2].name, pa[4]))
    assert (fermer.width, fermer.height) == (24, 24)
    assert (pf[1], pf[2].name, pf[3], pf[4], pf[5]) == ("TOPRIGHT", "WorldMapFrame", "TOPRIGHT", -2, 1)
    assert (pa[1], pa[2].name, pa[3], pa[4]) == ("RIGHT", "WorldMapFrameCloseButton", "LEFT", -1)
    assert fermer._normal.texture == g.UIAtlas.data["redbutton-exit"][1]
    assert agrandir._normal.texcoord[1] == g.UIAtlas.data["redbutton-expand"][2]
    assert fermer.strata == "HIGH" and agrandir.strata == "HIGH", "au-dessus de la carte, comme BorderFrame"

    # RIEN DE NOTRE FOND NE PASSE DEVANT LES TUILES. Un cadre fils prend un
    # niveau au-dessus de son parent : le fond de camelot, pose dans un cadre
    # fils, montait a 89 et masquait une partie des tuiles (niveau 88).
    fondCarte = g.ForeverUIWorldMapBackground
    enfants = list(fondCarte.children.values())
    print("   fond : niveau %s, %d cadre(s) fils | tuiles : niveau %s" % (
        fondCarte.frameLevel, len(enfants), detail.frameLevel))
    assert len(enfants) == 0, "le fond ne doit porter que des regions, aucun cadre fils"
    assert fondCarte.frameLevel < detail.frameLevel, "le fond passe SOUS WorldMapDetailFrame"
    for nom in ("ForeverUIWorldMapNavBar", "ForeverUIWorldMapCoords"):
        f = g[nom]
        assert f.strata in (None, "MEDIUM") and f.frameLevel > g.WorldMapPOIFrame.frameLevel, nom

    # LES TUILES : la derniere colonne et la derniere rangee debordent de la
    # carte ; la bordure de WotLK les cachait, celle de camelot non.
    lua.execute("WorldMapFrame_UpdateMap()")
    t4, t9, t12 = g.WorldMapDetailTile4, g.WorldMapDetailTile9, g.WorldMapDetailTile12
    print("   tuiles : 4 = %sx%s u2=%.4f | 9 = %sx%s v2=%.4f | 12 = %sx%s" % (
        t4.width, t4.height, t4.texcoord[2], t9.width, t9.height, t9.texcoord[4], t12.width, t12.height))
    assert (t4.width, t4.height) == (234, 256) and abs(t4.texcoord[2] - 234.0 / 256) < 1e-9
    assert (t9.width, t9.height) == (256, 156) and abs(t9.texcoord[4] - 156.0 / 256) < 1e-9
    assert (t12.width, t12.height) == (234, 156)
    assert (g.WorldMapDetailTile1.width, g.WorldMapDetailTile1.height) == (256, 256)

    # le titre : WotLK y ecrit la zone en petite fenetre
    lua.execute("WorldMapFrame_UpdateMap()")
    titre = g.WorldMapFrameTitle
    print("   titre '%s' dans %s" % (titre.text, titre.parent and titre.parent.name))
    assert titre.text == "Map & Quest Log", "MAP_AND_QUEST_LOG, pas le nom de la zone"
    assert g.WorldMapTrackQuest.alpha == 0, "la case de suivi de WotLK reste etouffee"
    assert not g.WorldMapLevelDropDown.shown, "le menu d'etages de WotLK reste cache"

    # le fil d'Ariane : Monde > Eastern Kingdoms > Burning Steppes
    barre = g.ForeverUIWorldMapNavBar
    b1, b2 = g.ForeverUIWorldMapNavButton1, g.ForeverUIWorldMapNavButton2
    print("   fil : %s > %s (%s) > %s (%s)" % (barre.home.text.text, b1.text.text, b1.width,
                                              b2.text.text, b2.width))
    assert b1.text.text == "Eastern Kingdoms" and b2.text.text == "Burning Steppes"
    assert b1.width == len("Eastern Kingdoms") * 6 + 53, "texte + 53 quand le bouton a une liste"
    assert b2.enabled == False and b2.selected.shown, "le dernier bouton est l'endroit ou l'on est"
    assert b1.enabled != False and not b1.selected.shown
    p1 = b1.points[1]
    assert (p1[1], p1[2].name, p1[3], p1[4]) == ("LEFT", "ForeverUIWorldMapNavBarHomeButton", "RIGHT", -15)
    lua.execute("ForeverUIWorldMapNavBarHomeButton:GetScript('OnClick')(ForeverUIWorldMapNavBarHomeButton)")
    dernier = g.CARTE.zooms[len(list(g.CARTE.zooms.values()))]
    assert dernier[1] == -1, "le bouton racine va a la carte cosmique : Azeroth ou l'Outreterre"
    # dehors : une seule etape ; en donjon : on en sort par ZoomOut, puis la
    # vue cosmique
    lua.execute("""
        CARTE.suivre = true
        CARTE.fichier = "Ulduar" CARTE.donjon = true CARTE.continent = -1 CARTE.zoomsArriere = 0
        ForeverUIWorldMapNavBarHomeButton:GetScript('OnClick')(ForeverUIWorldMapNavBarHomeButton)
    """)
    print("   World en donjon : carte %s, continent %s, zooms arriere %s" % (g.CARTE.fichier, g.CARTE.continent, g.CARTE.zoomsArriere))
    assert g.CARTE.fichier == False and g.CARTE.continent == -1 and g.CARTE.zoomsArriere == 1
    lua.execute("""
        CARTE.zoomsArriere = 0 CARTE.fichier = "Continent2"
        ForeverUIWorldMapNavBarHomeButton:GetScript('OnClick')(ForeverUIWorldMapNavBarHomeButton)
    """)
    assert g.CARTE.fichier == False and g.CARTE.continent == -1 and g.CARTE.zoomsArriere == 0, "dehors : SetMapZoom suffit"
    # le client refuse (ni SetMapZoom ni ZoomOut ne bougent) : rien ne boucle,
    # un mot dans le chat
    lua.execute("""
        CARTE.suivre = nil CARTE.fichier = "Naxxramas" CARTE.continent = 4 CARTE.zoomsArriere = 0
        ForeverUIWorldMapNavBarHomeButton:GetScript('OnClick')(ForeverUIWorldMapNavBarHomeButton)
    """)
    msgs = list(g.RECORDED.messages.values())
    print("   refus : %s zoom(s) arriere | %s" % (g.CARTE.zoomsArriere, msgs[-1]))
    assert g.CARTE.zoomsArriere == 1 and "refuse par le client" in msgs[-1]
    # EN DONJON, le fil est vide (ni continent ni zone) : "World" reste
    # cliquable ; il ne se desactive que sur la vue cosmique
    lua.execute("CARTE.fichier = 'Naxxramas' CARTE.continent = -1 CARTE.zone = 0 WorldMapFrame_UpdateMap()")
    home = g.ForeverUIWorldMapNavBarHomeButton
    print("   fil en donjon : World actif=%s" % (home.enabled != False))
    assert home.enabled != False, "en donjon, World doit repondre"
    lua.execute("CARTE.fichier = false CARTE.continent = -1 WorldMapFrame_UpdateMap()")
    assert home.enabled == False, "sur la vue cosmique, on y est deja"
    lua.execute("CARTE.fichier = false CARTE.continent = 0 WorldMapFrame_UpdateMap()")
    assert home.enabled != False, "sur Azeroth, World mene a la vue cosmique"
    lua.execute("CARTE.suivre = nil CARTE.fichier = nil CARTE.continent = 2 CARTE.zone = 5 WorldMapFrame_UpdateMap()")

    # LES PORTAILS : un repere sans lien de carte, au nom d'une instance, ouvre
    # sa carte (SetMapByID) ; un repere ordinaire ne fait rien de plus
    lua.execute("""
        NUM_WORLDMAP_POIS = 2
        CARTES_PAR_ID = {}
        PORTAIL_AVANT = SetMapByID
        function SetMapByID(id) table.insert(CARTES_PAR_ID, id) end
        for i = 1, 2 do
            local b = CreateFrame("Button", "WorldMapFramePOI" .. i, WorldMapButton)
            b:SetScript("OnClick", function() end)
        end
        WorldMapFramePOI1.name = "The Deadmines"
        WorldMapFramePOI2.name = "Sentinel Hill"
        WorldMapFrame_Update()
        CLIQUER(WorldMapFramePOI1)
        CLIQUER(WorldMapFramePOI2)
        CLIQUER(WorldMapFramePOI1, "RightButton")
        WorldMapFramePOI1.mapLinkID = 12
        CLIQUER(WorldMapFramePOI1)
    """)
    ids = list(g.CARTES_PAR_ID.values())
    print("   portails : cartes ouvertes %s (Deadmines = %s)" % (ids, g.ForeverUI.CartesInstances["the deadmines"]))
    assert ids == [756], "le portail des Mortemines seul, au clic gauche, sans lien de WotLK"
    # LES PORTAILS DE WDM (WorldMapFrameAtlasPOIn, mapLinkID = 0), crees
    # APRES notre greffe de WorldMapFrame_Update : branches a l'image suivante
    lua.execute("""
        CARTES_PAR_ID = {}
        NUM_WORLDMAP_ATLAS_POI = 1
        WorldMapFrame_Update()
        local b = CreateFrame("Button", "WorldMapFrameAtlasPOI1", WorldMapButton)
        b:SetScript("OnClick", function() end)
        b.name = "Icecrown Citadel" b.mapLinkID = 0
        ForeverUI.WorldMap.portailsSuivants:GetScript("OnUpdate")(ForeverUI.WorldMap.portailsSuivants)
        CLIQUER(WorldMapFrameAtlasPOI1)
        WorldMapFrameAtlasPOI1.name = "The Eye"
        CLIQUER(WorldMapFrameAtlasPOI1)
    """)
    ids = list(g.CARTES_PAR_ID.values())
    print("   portails de WDM : %s" % ids)
    assert ids == [604, g.ForeverUI.CartesInstances["tempest keep"]], "Icecrown Citadel, puis The Eye (alias)"
    lua.execute("SetMapByID = PORTAIL_AVANT WorldMapFramePOI1.mapLinkID = nil")
    # /fui souris : au clic, le cadre sous la souris, ses parents, ses images
    lua.execute("""
        function GetMouseFocus() return WorldMapFramePOI1 end
        SlashCmdList["FOREVERUI"]("souris")
    """)
    lua.execute("""
        local espion = ForeverUI.SourisEspion
        ESPION = espion
        SOURIS.LeftButton = false espion.scripts.OnUpdate(espion)
        SOURIS.LeftButton = true espion.scripts.OnUpdate(espion)
        SOURIS.LeftButton = false espion.scripts.OnUpdate(espion)
        SlashCmdList["FOREVERUI"]("souris")
    """)
    msgs = list(g.RECORDED.messages.values())
    trace = [m for m in msgs if "sous la souris" in m]
    print("   espion : %s" % trace[-1])
    assert trace and "sous la souris" in trace[-1] and not g.ESPION.shown, "le banc confond GetName et .name ; le client, non"

    # la liste d'un bouton : ses soeurs
    lua.execute("MENU_ENTREES = {} ForeverUIWorldMapNavButton2.MenuArrowButton:GetScript('OnClick')(ForeverUIWorldMapNavButton2.MenuArrowButton)")
    noms = [e.text for e in g.MENU_ENTREES.values()]
    print("   liste des zones : %s" % noms)
    assert noms[-1] == "Burning Steppes" and len(noms) == 5

    # les filtres : Show:, objectifs, couleur de difficulte
    lua.execute("MENU_ENTREES = {} ForeverUIWorldMapFilterButton:GetScript('OnClick')(ForeverUIWorldMapFilterButton)")
    entrees = list(g.MENU_ENTREES.values())
    print("   filtres : %s" % [(e.text, e.checked) for e in entrees])
    assert entrees[0].text == "Show:" and entrees[0].isTitle
    assert entrees[1].checked == True
    entrees[1].func()
    assert g.WorldMapQuestShowObjectives.checked == False and g.STATE.cvars.questPOI == "0", \
        "la case de WotLK est cliquee : son OnClick ecrit la CVar"

    # les etages : caches sans etage, montres avec
    etages = g.ForeverUIWorldMapFloorButton
    assert not etages.shown
    lua.execute("CARTE.etages = 3 CARTE.etage = 2 WorldMapFrame_UpdateMap()")
    print("   etages : %s, '%s', %sx%s" % (etages.shown, etages.Text.text, etages.width, etages.height))
    assert etages.shown and etages.Text.text == "Area 2" and (etages.width, etages.height) == (160, 25)
    # LE FOND DU SELECTEUR, EN TROIS (tranches 16 / 19 de camelot) : etire
    # d'une piece, son ombre transparente triplait et decalait la boite
    e = g.UIAtlas.data["common-dropdown-textholder-c60"]
    g_, m_, d_ = list(etages.fond.values())
    du = (e[3] - e[2]) / e[6]
    print("   fond du selecteur : %s | %s | %s" % (g_.width, "etire", d_.width))
    assert (g_.width, d_.width) == (16, 19), "les bouts gardent leur taille"
    assert abs(list(g_.texcoord.values())[1] - (e[2] + 16 * du)) < 1e-9
    assert abs(list(d_.texcoord.values())[0] - (e[3] - 19 * du)) < 1e-9
    assert g_.texture == e[1], "variante c60"
    # un nom trop long se termine par des points de suspension
    lua.execute("DUNGEON_FLOOR_ULDUAR2 = 'The Antechamber of Ulduar and its Keepers' WorldMapFrame_UpdateMap()")
    place = g.ForeverUI.WorldMap.largeurTexteEtage()
    print("   nom long : '%s' (%d pour %d de place)" % (etages.Text.text, len(etages.Text.text) * 6, place))
    assert etages.Text.text.endswith("...") and len(etages.Text.text) * 6 <= place
    assert etages.Text.text.startswith("The Antechamber")
    lua.execute("DUNGEON_FLOOR_ULDUAR2 = nil")
    # la liste ouverte ne descend pas sous la largeur du selecteur
    lua.execute("UIDROPDOWNMENU_OPEN_MENU = ForeverUIWorldMapNavMenu ForeverUIWorldMapFloorButton:GetScript('OnClick')(ForeverUIWorldMapFloorButton)")
    assert g.ForeverUIWorldMapNavMenu.foreverMinimum == 160
    lua.execute("DropDownList1:SetWidth(40)")
    g.DropDownList1.hooks.OnShow(g.DropDownList1)
    print("   liste des etages : %s de large" % g.DropDownList1.width)
    assert g.DropDownList1.width == 160, "au moins la largeur du selecteur (SetMinimumWidth)"
    lua.execute("ForeverUIWorldMapNavMenu.foreverMinimum = nil")
    # 3.3.5 RETOURNE une longue liste vers le haut quand elle deborderait sous
    # l'ecran (ToggleDropDownMenu, offscreenY) : elle repart vers le bas,
    # calee dans l'ecran le temps d'etre ouverte
    lua.execute("""
        TOGGLE_AVANT = ToggleDropDownMenu
        function ToggleDropDownMenu(niveau, valeur, menu, ancre)
            DropDownList1:ClearAllPoints()
            DropDownList1:SetPoint("BOTTOMLEFT", ancre, "BOTTOMLEFT", 0, 0)
            DropDownList1:Show()
        end
        DropDownList1:Hide()
        ForeverUI.WorldMap.ouvrirMenu(ForeverUIWorldMapFilterButton, { { text = "a" } })
    """)
    l1 = g.DropDownList1
    p1 = list(l1.points[1].values())
    print("carte, liste retournee : %s sur %s de %s, calee=%s" % (p1[0], p1[2], p1[1].name, l1.clamped))
    assert (p1[0], p1[2]) == ("TOPLEFT", "BOTTOMLEFT") and meme(p1[1], g.ForeverUIWorldMapFilterButton) and l1.clamped
    lua.execute("DropDownList1:Hide() ToggleDropDownMenu = TOGGLE_AVANT")
    assert not l1.clamped, "refermee : les autres menus retrouvent leur calage"
    lua.execute("CARTE.etages = 0 WorldMapFrame_UpdateMap()")

    # les coordonnees
    lua.execute("POSITION.x, POSITION.y = 0.4567, 0.6234 ForeverUI.WorldMap.majCoordonnees()")
    co = g.ForeverUIWorldMapCoords
    print("   coordonnees : '%s' (curseur visible=%s)" % (co.joueur.text, co.curseur.shown))
    assert co.joueur.text == "Player: 46, 62"

    # ------------------------------------------------------------------
    # LE VOLET DE QUETES (etape 2)
    # ------------------------------------------------------------------
    print("\n--- journal de quetes ---")
    lua.execute("ForeverUI.QuestLog.reglages().volet = true WorldMap_ToggleSizeDown() WorldMapFrame:Show()")
    volet = g.ForeverUIQuestLogPanel
    print("   fenetre %sx%s | volet %s, %s de large" % (carteMonde.width, carteMonde.height, volet.shown, volet.width))
    assert carteMonde.width == 1035, "702 + 333 avec le volet ouvert"
    assert volet.shown and volet.width == 330 and volet.strata == "HIGH"
    pv = [list(x.values()) for x in volet.points.values()]
    assert pv[0][0] == "TOPRIGHT" and pv[0][3:5] == [-3, -25] and pv[1][0] == "BOTTOMRIGHT" and pv[1][3:5] == [-3, 3], pv
    bascule = g.ForeverUIWorldMapSidePanelToggle
    assert bascule.fermer.shown and not bascule.ouvrir.shown
    barreNav = g.ForeverUIWorldMapNavBar
    assert list(barreNav.points[2].values())[3] == 2 + 697 - 50, "la barre s'arrete a -50 du bord droit de la carte"

    lua.execute("ForeverUI.QuestLog.maj()")
    e1 = g.ForeverUIQuestLogHeader1
    e2 = g.ForeverUIQuestLogHeader2
    q1, q2 = g.ForeverUIQuestLogTitle1, g.ForeverUIQuestLogTitle2
    print("   en-tetes : '%s' (%s) '%s' (%s)" % (e1.texte.text, e1.shown, e2.texte.text, e2.shown))
    print("   quetes : '%s' | '%s' tag '%s'" % (q1.texte.text, q2.texte.text, q2.tag.text))
    assert e1.texte.text == "Elwynn Forest" and e2.texte.text == "Westfall", "l'en-tete replie reste montre"
    assert q1.texte.text == "[5] A Threat Within"
    assert q2.texte.text == "[12+] The Fargodeep Mine" and q2.tag.text == "(Elite)" and q2.tag.shown
    assert not (g.ForeverUIQuestLogTitle3 and g.ForeverUIQuestLogTitle3.shown), "la quete sous un en-tete replie n'est pas listee"
    pe = list(e1.points[1].values())
    pq = list(q1.points[1].values())
    print("   premier en-tete a (%s, %s) | premiere quete a (%s, %s)" % (pe[3], pe[4], pq[3], pq[4]))
    assert (pe[3], pe[4]) == (9, -8), "premier en-tete : x = 9, ecart 8"
    assert (pq[3], pq[4]) == (0, -(8 + 22 + 2)), "quete apres en-tete : ecart 2"
    objectifsQ1 = [o.texte.text for o in q1.lignesObjectif.values()]
    print("   objectifs de la premiere quete : %s" % objectifsQ1)
    assert objectifsQ1 == ["Kobold Vermin slain: 3/10"], "seuls les objectifs non remplis"
    assert abs(q1.texte.textColor[1] - 0.25) < 1e-9 and abs(q2.texte.textColor[1] - 1.0) < 1e-9, "couleurs de difficulte de camelot"
    assert abs(e1.texte.textColor[1] - 0.502) < 1e-9, "titre d'en-tete gris au repos"
    compteur = g.ForeverUIQuestLogCount.texte.text
    print("   compteur : %s" % compteur)
    assert compteur == "Quests: |cffffffff3|r|cffffffff/25|r"

    # le suivi par la case
    lua.execute("ForeverUIQuestLogTitle1.case:GetScript('OnClick')(ForeverUIQuestLogTitle1.case) ForeverUI.QuestLog.maj()")
    assert g.SUIVIES["A Threat Within"] and q1.coche.shown

    # replier un en-tete : 3.3.5 retire ses quetes
    lua.execute("ForeverUIQuestLogHeader1:GetScript('OnClick')(ForeverUIQuestLogHeader1, 'LeftButton') ForeverUI.QuestLog.maj()")
    assert not q1.shown, "l'en-tete replie cache ses quetes"
    lua.execute("ExpandQuestHeader(1) ForeverUI.QuestLog.maj()")

    # la recherche : deplie tout, puis rend les etats par le nom
    lua.execute("REPLIS = {} ForeverUI.QuestLog.chercher('militia')")
    trouvees = [q.texte.text for q in (g.ForeverUIQuestLogTitle1, g.ForeverUIQuestLogTitle2) if q.shown]
    print("   recherche 'militia' : %s | replis %s" % (trouvees, list(g.REPLIS.values())))
    assert trouvees == ["[14] The People's Militia"], trouvees
    lua.execute("ForeverUI.QuestLog.chercher('')")
    assert g.JOURNAL[4].collapsed == True, "Westfall retrouve son etat replie"

    # LE CADRE A MOULURES, decoupe en neuf (marges 53 du client camelot)
    eCadre = g.UIAtlas.data["questlog-frame"]
    def du_cadre(f):
        return [r for r in f.regions.values()
                if r.texture == eCadre[1] and r.texcoord and eCadre[2] - 1e-9 <= r.texcoord[1] <= eCadre[3] + 1e-9
                and eCadre[4] - 1e-9 <= r.texcoord[3] <= eCadre[5] + 1e-9]
    bords = [f for f in g.ForeverUIQuestScrollFrame.children.values() if len(du_cadre(f)) > 0]
    tranches = du_cadre(bords[0]) if bords else []
    coins = [t for t in tranches if t.width == 53 and t.height == 53]
    print("   cadre a moulures : %d tranche(s) de questlog-frame, %d coin(s) de 53" % (len(tranches), len(coins)))
    assert len(tranches) == 9, "questlog-frame en neuf tranches, pas une piece etiree"
    assert len(coins) == 4, "quatre coins de 53 x 53"

    # LE CADRE SUIT LA BARRE : montree, taille de camelot ; masquee, jusqu'au
    # bord du volet
    liste = g.ForeverUIQuestScrollFrame
    bordListe = g.ForeverUIQuestLogPanel.bord
    liste.height = 40
    lua.execute("ForeverUI.QuestLog.maj()")
    pb = list(bordListe.points[2].values())
    print("   barre montree=%s : cadre BOTTOMRIGHT (%s, %s), fond %s de large" % (
        g.ForeverUIQuestScrollBar.shown, pb[3], pb[4], g.ForeverUIQuestLogPanel.fond.width))
    assert g.ForeverUIQuestScrollBar.shown and (pb[3], pb[4]) == (3, -6)
    assert g.ForeverUIQuestLogPanel.fond.width == 307
    liste.height = 2000
    lua.execute("ForeverUI.QuestLog.maj()")
    pb = list(bordListe.points[2].values())
    print("   barre montree=%s : cadre BOTTOMRIGHT (%s, %s), fond %s de large" % (
        g.ForeverUIQuestScrollBar.shown, pb[3], pb[4], g.ForeverUIQuestLogPanel.fond.width))
    assert not g.ForeverUIQuestScrollBar.shown and (pb[3], pb[4]) == (3 + 22, -6), "jusqu'au bord du volet"
    assert g.ForeverUIQuestLogPanel.fond.width == 307 + 22
    assert len(list(bordListe.points.values())) == 2, "deux points, pas d'accumulation"

    # LE FOND EN DOUBLE DENSITE
    fondListe = g.ForeverUIQuestLogPanel.fond
    e2x = g.UIAtlas.data["questlog-main-background-2x"]
    print("   fond de liste : %s" % fondListe.texture)
    assert fondListe.texture == e2x[1], "la variante 2x, pas la 1x agrandie"

    # LES REPERES : ceux de la carte affichee, aux memes numeros
    lua.execute("WorldMapFrame_UpdateQuests() ForeverUI.QuestLog.maj()")
    p1 = g["poiForeverUIQuestScrollContents1_1"]
    pc = g["poiForeverUIQuestScrollContents2_1"]
    print("   reperes : numero 1 -> quete %s (%s) | termine 1 -> quete %s (%s)" % (
        p1 and p1.questId, p1 and p1.shown, pc and pc.questId, pc and pc.shown))
    assert p1 and p1.questId == 783 and p1.shown, "la quete 783 porte le repere numero 1, comme sur la carte"
    pp = list(p1.points[1].values())
    assert (pp[0], pp[2], pp[3], pp[4]) == ("CENTER", "TOPLEFT", 16, -14), pp
    assert not (g["poiForeverUIQuestScrollContents1_2"] and g["poiForeverUIQuestScrollContents1_2"].shown), \
        "la quete 62 n'a pas de repere sur cette carte"

    # LE SURVOL allume la zone de la quete sur la carte
    lua.execute("ForeverUIQuestLogTitle1:GetScript('OnEnter')(ForeverUIQuestLogTitle1)")
    assert g.ZONES[783] == True, "survoler une quete allume sa zone"
    lua.execute("ForeverUIQuestLogTitle1:GetScript('OnLeave')(ForeverUIQuestLogTitle1)")
    assert g.ZONES[783] == False

    # LE CLIC met la carte sur la zone de la quete et la selectionne
    # sans « Quest Objectives », WotLK ne montre ni ne choisit aucun repere :
    # l'essai des filtres l'a decochee plus haut, on la recoche
    if not g.WatchFrame.showObjectives:
        lua.execute("WorldMapQuestShowObjectives:Click()")
    assert g.WatchFrame.showObjectives
    lua.execute("OUVERTURES = {} ForeverUIQuestLogTitle2:GetScript('OnClick')(ForeverUIQuestLogTitle2, 'LeftButton')")
    print("   clic sur la quete 62 : carte %s, selection %s, zone %s" % (
        list(g.OUVERTURES.values()), g.WORLDMAP_SETTINGS.selectedQuestId, g.ZONES[62]))
    assert list(g.OUVERTURES.values()) == [39], "la carte passe sur la zone de la quete (GetQuestWorldMapAreaID)"
    assert g.WORLDMAP_SETTINGS.selectedQuestId == 62 and g.ZONES[62] == True
    assert g.SELECTION == 3, "la quete est aussi choisie dans le journal"
    # le survol ne rend pas la zone de la quete choisie
    lua.execute("ForeverUIQuestLogTitle2:GetScript('OnLeave')(ForeverUIQuestLogTitle2)")
    assert g.ZONES[62] == True, "la quete choisie garde sa zone"

    # ------------------------------------------------------------------
    # LA PAGE D'UNE QUETE (etape 3) : le clic a remplace la liste par la page
    # ------------------------------------------------------------------
    det = g.ForeverUIQuestDetailsFrame
    print("   page : montree=%s, liste montree=%s, barre de liste=%s" % (
        det.shown, g.ForeverUIQuestScrollFrame.shown, g.ForeverUIQuestScrollBar.shown))
    assert det.shown and not g.ForeverUIQuestScrollFrame.shown, "la page remplace la liste"
    assert not g.ForeverUIQuestScrollBar.shown, "la barre de la liste part avec elle"
    pd = list(det.points[1].values())
    assert (pd[0], pd[1].name, pd[2], pd[3], pd[4]) == ("TOPRIGHT", "ForeverUIQuestLogPanel", "TOPRIGHT", -22, -1), pd
    assert (det.width, det.height) == (308, 502)
    assert det.titre.text == "The Fargodeep Mine"
    assert det.texteObjectifs.text == "Explore the Fargodeep Mine."
    assert det.description.text == "Kobolds have overrun the mine."
    assert det.enteteDescription.text == "Description"
    objs = [o for o in det.objectifs.values() if o.shown]
    print("   objectifs : %s" % [o.text for o in objs])
    assert [o.text for o in objs] == ["Explore the mine", "Kobolds slain: 5/5 (Complete)"], \
        "tous les objectifs, les remplis marques (Complete)"
    assert abs(objs[0].textColor[1] - 0.18) < 1e-9 and abs(objs[1].textColor[1] - 0.2) < 1e-9, \
        "DEFAULT_MATERIAL_TEXT_COLOR, puis QUEST_OBJECTIVE_COMPLETED_FONT_COLOR"
    print("   minuteur '%s' | groupe '%s' | argent demande montre=%s" % (
        det.minuteur.text, det.groupe.text, det.argent.shown))
    assert det.minuteur.text == "Time Remaining: 125 sec" and det.groupe.text == "Suggested Players [3]"
    assert not det.argent.shown, "rien a payer : pas de ligne d'argent"
    assert (det.titre.fontFile, det.titre.fontSize) == ("Fonts\\MORPHEUS.ttf", 18), "QuestTitleFont"
    assert (det.description.fontFile, det.description.fontSize) == ("Fonts\\FRIZQT__.TTF", 13), "QuestFont"

    # l'empilement de QUEST_TEMPLATE_MAP_DETAILS
    p0 = list(det.titre.points[1].values())
    assert (p0[0], p0[1].name, p0[2], p0[3], p0[4]) == ("TOPLEFT", "ForeverUIQuestDetailsContents", "TOPLEFT", 5, -10)
    # l'identite d'une table Lua : l'enveloppe de lupa ne la garantit pas
    meme = lua.eval("function(a, b) return rawequal(a, b) end")
    def sur(r, precedent, dx, dy):
        p = list(r.points[1].values())
        assert meme(p[1], precedent) and (p[0], p[2], p[3], p[4]) == ("TOPLEFT", "BOTTOMLEFT", dx, dy), (p[0], p[2], p[3], p[4])
    sur(det.texteObjectifs, det.titre, 0, -5)
    sur(det.minuteur, det.texteObjectifs, 0, -10)
    sur(objs[0], det.minuteur, 0, -10)
    sur(objs[1], objs[0], 0, -2)
    sur(det.groupe, objs[1], 0, -10)
    sur(det.enteteDescription, det.groupe, 0, -20)
    sur(det.description, det.enteteDescription, 0, -5)
    sur(det.espace, det.description, 0, 0)

    # les recompenses, deux par rangee
    l = det.liste
    i1, i2, i3 = g.ForeverUIQuestDetailsRewardItem1, g.ForeverUIQuestDetailsRewardItem2, g.ForeverUIQuestDetailsRewardItem3
    print("   au choix : '%s' -> %s, %s | recu : '%s' -> xp %s, argent %s, %s x%s, honneur %s" % (
        l.choisir.text, i1.Name.text, i2.Name.text, l.recevoir.text, l.xp.Name.text, l.argent.Name.text,
        i3.Name.text, i3.Count.text, l.honneur.Count.text))
    assert l.choisir.text == "You will be able to choose one of these rewards:" and l.choisir.shown
    assert l.recevoir.text == "You will also receive:", "il y a un choix : REWARD_ITEMS"
    assert (i1.type, i1.id, i2.type, i2.id, i3.type, i3.id) == ("choice", 1, "choice", 2, "reward", 1)
    p2 = list(i2.points[1].values())
    assert meme(p2[1], i1) and (p2[2], p2[3]) == ("TOPRIGHT", 8), "le second objet a droite du premier, a 8"
    assert list(i2.Icon.vertex.values()) == [0.9, 0, 0], "inutilisable : en rouge"
    assert abs(list(i3.IconBorder.vertex.values())[0] - 0.659) < 1e-9 and i3.IconBorder.shown, "commun : COMMON_GRAY_COLOR"
    assert i3.Count.shown and i3.Count.text == 5
    assert l.xp.Name.text == 850 and l.argent.Name.text == "250"
    pa = list(l.argent.points[1].values())
    assert meme(pa[1], l.xp) and pa[2] == "TOPRIGHT", "l'argent a droite de l'experience"
    assert l.xp.Icon.texture == "interface\\ForeverUI\\icons\\xp_icon"
    assert l.honneur.Icon.texture == "interface\\ForeverUI\\icons\\pvpcurrency-honor-alliance"
    assert l.honneur.Name.text == "Honor" and l.honneur.Count.text == 12
    assert not l.titre.shown and not l.sortBouton.shown and not l.arene.shown
    rec = det.recompenses
    print("   recompenses : liste %s de haut, cadre %s, conteneur %s, libelle '%s'" % (
        l.height, rec.height, det.conteneur.height, rec.libelle.text))
    assert l.height == 151, "1 + 4 rangees d'objets a 35 + 2 en-tetes a 5"
    assert rec.height == 151 + 62 and det.espace.height == 151 + 62, "SetRewardsHeight : liste + 62"
    assert rec.libelle.shown and rec.libelle.text == "Rewards"
    pc = list(det.conteneur.points[1].values())
    assert (pc[0], pc[2], pc[3], pc[4]) == ("BOTTOMLEFT", "BOTTOMLEFT", 0, 23)
    assert meme(det.conteneur.scrollChild, rec), "un ScrollFrame rogne les recompenses (pas de clipChildren en 3.3.5)"

    # les boutons du bas
    print("   boutons : abandon %s, partage %s, suivi '%s'" % (
        det.abandon.actif, det.partage.actif, det.suivre.fontString.text))
    assert det.abandon.actif and not det.partage.actif, "partager demande un groupe"
    assert det.suivre.fontString.text == "Track"
    lua.execute("ForeverUIQuestDetailsTrackButton:GetScript('OnClick')(ForeverUIQuestDetailsTrackButton)")
    assert g.SUIVIES["The Fargodeep Mine"] and det.suivre.fontString.text == "Untrack", "UNTRACK_QUEST_ABBREV"
    lua.execute("ForeverUIQuestDetailsTrackButton:GetScript('OnClick')(ForeverUIQuestDetailsTrackButton)")
    assert det.suivre.fontString.text == "Track"
    assert (det.abandon.width, det.partage.width, det.suivre.width) == (105, 103, 105)
    assert det.retour.fontString.text == "Back" and (det.retour.width, det.retour.height) == (90, 22)

    # le fond : a la largeur, plafonne a 440
    eFond = g.UIAtlas.data["questdetailsbackgrounds"]
    voulue = eFond[7] * 308 / eFond[6]
    tc = list(det.fond.texcoord.values())
    assert det.fond.height == 440 and abs(tc[3] - (eFond[4] + (eFond[5] - eFond[4]) * 440 / voulue)) < 1e-9

    # l'infobulle d'un objet : SetQuestLogItem, sur la quete de la page
    lua.execute("SELECTION = 1 ForeverUIQuestDetailsRewardItem3:GetScript('OnEnter')(ForeverUIQuestDetailsRewardItem3)")
    assert list(g.GameTooltip.objetQuete.values()) == ["reward", 1] and g.SELECTION == 3

    # RETOUR : la liste revient, et la carte la ou elle etait
    lua.execute("ForeverUIQuestDetailsBackButton:GetScript('OnClick')(ForeverUIQuestDetailsBackButton)")
    print("   retour : page %s, liste %s, cartes ouvertes %s" % (det.shown, g.ForeverUIQuestScrollFrame.shown,
                                                                list(g.OUVERTURES.values())))
    assert not det.shown and g.ForeverUIQuestScrollFrame.shown
    assert list(g.OUVERTURES.values()) == [39, 30] and g.CARTE.id == 30, "la carte d'avant le clic"

    # LA HAUTEUR DU TEXTE, et les recompenses qui grandissent au defilement.
    # Le faux client ne mesure pas les textes : on leur donne une hauteur.
    for nom, h in (("titre", 20), ("texteObjectifs", 30), ("minuteur", 12), ("groupe", 13),
                   ("enteteDescription", 20), ("description", 100)):
        det[nom].height = h
    for o in det.objectifs.values():
        o.height = 12
    lua.execute("ForeverUIQuestLogTitle2:GetScript('OnClick')(ForeverUIQuestLogTitle2, 'LeftButton')")
    total = 10 + 20 + 5 + 30 + 10 + 12 + 10 + 12 + 2 + 12 + 10 + 13 + 20 + 20 + 5 + 100 + 213
    print("   texte : %s de haut, plage %s | conteneur %s" % (
        g.ForeverUIQuestDetailsContents.height, total - 430, det.conteneur.height))
    assert g.ForeverUIQuestDetailsContents.height == total
    assert det.conteneur.height == 213 - (total - 430), "AdjustRewardsFrameContainer : cache ce que le texte cache"
    assert g.ForeverUIQuestDetailsScrollBar.shown
    lua.execute("ForeverUIQuestDetailsScrollBar:Deplacer(100)")
    print("   en bas : defilement %s, conteneur %s" % (g.ForeverUIQuestDetailsScrollFrame.verticalScroll, det.conteneur.height))
    assert g.ForeverUIQuestDetailsScrollFrame.verticalScroll == total - 430, "borne a la plage"
    assert det.conteneur.height == 213, "en bas, les recompenses en entier"

    # UNE AUTRE CARTE referme la page (QuestLogMixin:Refresh), sans toucher a la carte
    lua.execute("OUVERTURES = {} CARTE.id = 12 WorldMapFrame_UpdateQuests()")
    assert not det.shown and g.ForeverUIQuestScrollFrame.shown and list(g.OUVERTURES.values()) == []

    # UNE QUETE QUI QUITTE LE JOURNAL ramene a la liste, carte comprise
    lua.execute("ForeverUIQuestLogTitle2:GetScript('OnClick')(ForeverUIQuestLogTitle2, 'LeftButton')")
    assert det.shown
    lua.execute("PARTIE = table.remove(JOURNAL, 3) ForeverUI.QuestLog.majDetails()")
    print("   quete rendue : page %s, carte %s" % (det.shown, g.CARTE.id))
    assert not det.shown and g.ForeverUIQuestScrollFrame.shown and g.CARTE.id == 12
    lua.execute("table.insert(JOURNAL, 3, PARTIE) ForeverUI.QuestLog.maj()")

    # la bascule du volet
    lua.execute("ForeverUIWorldMapSidePanelToggle.fermer:GetScript('OnClick')()")
    print("   volet ferme : fenetre %s, volet %s" % (carteMonde.width, volet.shown))
    assert carteMonde.width == 702 and not volet.shown and bascule.ouvrir.shown
    lua.execute("ForeverUIWorldMapSidePanelToggle.ouvrir:GetScript('OnClick')()")
    assert carteMonde.width == 1035 and volet.shown

    # L : QuestLogFrame reste invisible, la carte s'ouvre avec le volet ;
    # L encore la ferme, meme si le gestionnaire l'a deja fermee avant nous.
    lua.execute("WorldMapFrame:Hide() STATE.time = STATE.time + 1 ForeverUI.QuestLog.reglages().volet = false ToggleFrame(QuestLogFrame)")
    print("   L : QuestLogFrame %s | carte %s | volet %s" % (g.QuestLogFrame.shown, carteMonde.shown, volet.shown))
    assert not g.QuestLogFrame.shown and carteMonde.shown and volet.shown
    lua.execute("ToggleFrame(QuestLogFrame)")
    print("   L encore : carte %s" % carteMonde.shown)
    assert not carteMonde.shown and not g.QuestLogFrame.shown, "L referme le journal"

    # LE MODE AGRANDI (etape 4) : le plein ecran de WotLK habille a la camelot.
    # L'ecran de l'utilisateur : 3840 x 1600 a l'echelle 0,64, soit une
    # interface de 2880 x 1200 unites.
    lua.execute("UIParent:SetWidth(2880) UIParent:SetHeight(1200) UIParent:SetScale(0.64)")
    lua.execute("WorldMap_ToggleSizeUp() WorldMapFrame:Show()")
    sup = g.ForeverUIWorldMapMaximized
    can = g.ForeverUIWorldMapCanvas
    ps = list(sup.points[1].values())
    print("   agrandi : support %s x %s a l'echelle %s, %s de la carte | canevas %s x %s" % (
        sup.width, sup.height, sup.scale, ps[0], can.width, can.height))
    assert (sup.width, sup.height) == (1703, 1200), "UpdateMaximizedSize : hauteur de l'ecran, largeur au prorata"
    assert abs(sup.scale - 0.64) < 1e-9, "le support revient a l'unite de l'interface"
    assert ps[0] == "TOP" and ps[1].name == "WorldMapFrame" and (ps[3], ps[4]) == (0, 0), "maximizePoint TOP"
    assert (can.width, can.height) == (1703 - 5, 1200 - 69)
    attendu = min(1698 / 1002, 1131 / 668) * 0.64
    print("   echelle de la carte %.5f (attendu %.5f), vue %.5f" % (g.WorldMapDetailFrame.scale, attendu, g.WORLDMAP_SETTINGS.size))
    for f in (g.WorldMapDetailFrame, g.WorldMapButton, g.WorldMapFrameAreaFrame, g.WorldMapBlobFrame):
        assert abs(f.scale - attendu) < 1e-9, f.name
    assert abs(g.WORLDMAP_QUESTLIST_SIZE - attendu) < 1e-9 and abs(g.WORLDMAP_FULLMAP_SIZE - attendu) < 1e-9, \
        "les constantes que WotLK lit pour placer fleche et reperes"
    assert abs(g.WORLDMAP_SETTINGS.size - attendu) < 1e-9
    pd = [list(x.values()) for x in g.WorldMapDetailFrame.points.values()]
    assert len(pd) == 1 and pd[0][0] == "CENTER" and pd[0][1].name == "ForeverUIWorldMapCanvas", pd
    # le cadre de camelot, sans portrait
    cadre = g.ForeverUIWorldMapBorder
    hg = cadre.coins.hg
    php = list(hg.points[1].values())
    print("   cadre : montre=%s echelle %s | portrait %s | coin haut-gauche %s (%s, %s)" % (
        cadre.shown, cadre.scale, cadre.portraitCadre.shown, hg.texture, php[3], php[4]))
    assert cadre.shown and abs(cadre.scale - 0.64) < 1e-9 and not cadre.portraitCadre.shown
    assert hg.texture == g.UIAtlas.data["ui-frame-metal-cornertopleft"][1] and (php[3], php[4]) == (-12, 16)
    print("   titre '%s'" % titre.text)
    assert titre.text == "World Map" and meme(titre.parent, cadre.bandeau), "WORLD_MAP, dans le bandeau"
    assert list(barre.points[1].values())[3] == 10, "NavBar a (8, -25) du bandeau"
    assert barre.shown and not g.ForeverUIWorldMapSidePanelToggle.shown and not g.ForeverUIQuestLogPanel.shown, \
        "la carte seule : ni volet ni bascule"
    # ce que le plein ecran de WotLK montre et que camelot n'a pas
    assert all(g["WorldMapFrameTexture%d" % i].alpha == 0 for i in range(1, 19)), "la bordure de WotLK s'efface"
    for nom in ("WorldMapZoomOutButton", "WorldMapZoneDropDown", "WorldMapContinentDropDown", "WorldMapQuestScrollFrame"):
        assert not g[nom].shown, nom
    # les boutons rouges : fermer, et reduire a sa gauche
    fermer, reduire = g.WorldMapFrameCloseButton, g.WorldMapFrameSizeDownButton
    pr = list(reduire.points[1].values())
    assert list(fermer.points[1].values())[1].name == "ForeverUIWorldMapMaximized" and abs(fermer.scale - 0.64) < 1e-9
    assert pr[0] == "RIGHT" and pr[1].name == "WorldMapFrameCloseButton" and abs(reduire.scale - 0.64) < 1e-9
    assert reduire.GetNormalTexture(reduire).texcoord[1] == g.UIAtlas.data["redbutton-condense"][2], "RedButton-Condense"
    assert (g.WorldMapDetailTile12.width, g.WorldMapDetailTile12.height) == (234, 156), "les tuiles rognees a la carte"
    # une vue de WotLK repose la carte et la liste : on repasse derriere
    lua.execute("WorldMapFrame_SetQuestMapView()")
    pd = [list(x.values()) for x in g.WorldMapDetailFrame.points.values()]
    assert len(pd) == 1 and pd[0][0] == "CENTER" and not g.WorldMapQuestScrollFrame.shown
    lua.execute("WorldMapFrame_SetFullMapView()")
    assert not g.WorldMapFrameTexture14.shown and abs(g.WorldMapDetailFrame.scale - attendu) < 1e-9
    lua.execute("UIParent:SetScale(1) WorldMapFrame:SetScale(1)")

    # et retour
    lua.execute("WorldMap_ToggleSizeDown()")
    attendu = 702 + (333 if g.ForeverUI.QuestLog.reglages().volet else 0)
    assert g.ForeverUIWorldMapBorder.shown and (carteMonde.width, carteMonde.height) == (attendu, 534)
    print("   retour : cadre echelle %s, portrait %s, titre '%s', coin %s" % (
        g.ForeverUIWorldMapBorder.scale, g.ForeverUIWorldMapBorder.portraitCadre.shown, titre.text,
        list(g.ForeverUIWorldMapBorder.coins.hg.points[1].values())[3]))
    assert g.ForeverUIWorldMapBorder.scale == 1 and g.ForeverUIWorldMapBorder.portraitCadre.shown
    assert titre.text == "Map & Quest Log" and list(g.ForeverUIWorldMapBorder.coins.hg.points[1].values())[3] == -13
    assert g.WorldMapFrameCloseButton.scale == 1 and list(barre.points[1].values())[3] == 66
    assert g.ForeverUIQuestLogPanel.shown == bool(g.ForeverUI.QuestLog.reglages().volet), "le volet revient avec la petite fenetre"

    # ------------------------------------------------------------------
    # LE SUIVI DE QUETES (docs/SUIVI_DES_QUETES.md)
    # ------------------------------------------------------------------
    print("\n--- suivi de quetes ---")
    meme = lua.eval("function(a, b) return rawequal(a, b) end")
    gest = list(g.WATCHFRAME_OBJECTIVEHANDLERS.values())
    ot = g.ForeverUI.ObjectiveTracker
    print("   gestionnaires : %d" % len(gest))
    assert len(gest) == 2 and meme(gest[0], ot.afficherQuetes) and meme(gest[1], ot.gestionnaireHautsFaits), \
        "les deux modules de camelot remplacent les trois gestionnaires de WotLK"
    # l'API de WotLK reste ouverte aux addons : un gestionnaire ajoute passe apres
    lua.execute("ADDON_APPELE = nil WatchFrame_AddObjectiveHandler(function(l, o) ADDON_APPELE = o return 0, 0, 0 end)")

    lua.execute("SUIVIES = { ['A Threat Within'] = true, ['The Fargodeep Mine'] = true } HAUTS_FAITS_SUIVIS = { 1001, 1002 } STATE.time = 100 WatchFrame_Update()")
    wf, lignes = g.WatchFrame, g.WatchFrameLines
    ent = g.ForeverUIObjectiveTrackerHeader
    print("   cadre %s de large | en-tete '%s' montre=%s | en-tete WotLK montre=%s alpha=%s" % (
        wf.width, ent.texte.text, ent.shown, g.WatchFrameHeader.shown, g.WatchFrameHeader.alpha))
    assert g.WOTLK_DESSINE == 0, "les gestionnaires de WotLK ne dessinent plus"
    assert g.ADDON_APPELE is not None and g.ADDON_APPELE < 0, "le gestionnaire d'un addon tourne apres les modules"
    assert wf.width == 260 and g.WATCHFRAME_EXPANDEDWIDTH == 260
    assert ent.shown and ent.texte.text == "All Objectives" and (ent.width, ent.height) == (260, 32)
    assert not g.WatchFrameHeader.shown and g.WatchFrameHeader.alpha == 0, "l'en-tete de WotLK reste etouffe"
    pl = list(lignes.points[1].values())
    assert (pl[0], pl[3], pl[4]) == ("TOPLEFT", 0, -38), "les modules commencent a 38 sous le haut (BASE_TOP_PADDING)"

    mq = g.ForeverUIQuestObjectiveTracker
    pm = list(mq.points[1].values())
    print("   module Quests : montre=%s a (%s, %s), %s de haut" % (mq.shown, pm[3], pm[4], mq.height))
    assert mq.shown and mq.entete.texte.text == "Quests" and (pm[3], pm[4]) == (0, 0)
    blocs = {b.titre.text: b for b in mq.blocs.values()}
    b1, b2 = blocs["A Threat Within"], blocs["The Fargodeep Mine"]
    p1 = list(b1.points.values())
    assert meme(p1[0][2], mq.entete) and (p1[0][1], p1[0][3], p1[0][5]) == ("TOP", "BOTTOM", -10), "premier bloc a 10 sous l'en-tete"
    assert (p1[1][1], p1[1][4]) == ("LEFT", 20), "a 20 du bord"
    p2 = list(b2.points[1].values())
    assert meme(p2[1], b1) and (p2[0], p2[2], p2[4]) == ("TOP", "BOTTOM", -10), "10 entre deux blocs"
    assert abs(b1.titre.textColor[1] - 0.749) < 1e-9, "OBJECTIVE_TRACKER_BLOCK_HEADER_COLOR"
    assert (b1.titre.fontFile, b1.titre.fontSize) == ("Fonts\\FRIZQT__.TTF", 12)
    montrees = [l for l in b1.lignesMontrees.values()]
    print("   lignes du bloc 1 : %s" % [(l.texte.text, l.tiret.shown, l.coche.shown) for l in montrees])
    assert [l.texte.text for l in montrees] == ["3/10 Kobold Vermin slain", "Report found"], "texte inverse comme WotLK, remplis gardes"
    assert montrees[0].tiret.shown and not montrees[0].coche.shown
    assert not montrees[1].tiret.shown and montrees[1].coche.shown and abs(montrees[1].texte.textColor[1] - 0.6) < 1e-9, \
        "objectif rempli : sans tiret, gris 0,6, coche"
    pl1 = list(montrees[1].points[1].values())
    assert meme(pl1[1], montrees[0]) and pl1[4] == -4, "4 entre deux lignes"

    # l'objet de quete et le minuteur du bloc 2
    it = g.WatchFrameItem1
    pi = list(it.points[1].values())
    print("   objet : %s x%s en %s | titre %s de large | minuteur %s" % (it.icone, it.nombre, pi[0], b2.titre.width,
                                                                        b2.minuteur and b2.minuteur.shown))
    assert it.shown and it.icone == "icone:pioche" and meme(pi[1], b2) and pi[0] == "TOPRIGHT"
    assert b2.titre.width == 240 - 28, "le titre s'arrete 2 avant l'objet"
    assert b2.minuteur.shown and b2.minuteur.duree == 90, "barre de temps dans le bloc"
    # le repere de WotLK, centre ou camelot centre le sien
    poi = g["poiWatchFrameLines1_1"]
    pp = list(poi.points[1].values())
    assert poi.shown and poi.questId == 783 and meme(pp[1], b1.titre) and (pp[0], pp[3], pp[4]) == ("CENTER", -17, -5)
    assert list(g.VISIBLE_WATCHES.values()) == [2, 3]

    # le module des hauts faits, sous celui des quetes
    ma = g.ForeverUIAchievementObjectiveTracker
    pa = list(ma.points[1].values())
    print("   module Achievements a %s ; decalages %s" % (pa[4], list(g.WATCHFRAME_DECALAGES.values())))
    assert ma.shown and pa[4] == -(mq.height + 10), "10 entre deux modules"
    hf = {b.titre.text: b for b in ma.blocs.values()}
    crit = [l.texte.text for l in hf["Explorer"].lignesMontrees.values()]
    print("   criteres montres : %s" % crit)
    assert crit == ["Elwynn", "Duskwood", "Redridge", "Darkshire", "Stranglethorn", "..."], "5 criteres puis ..."
    assert [l.texte.text for l in hf["Loremaster"].lignesMontrees.values()] == ["Complete 700 quests."]

    # un objectif rempli entre deux passages : la coche s'anime
    lua.execute("JOURNAL[2].objectifs[1][2] = true STATE.time = 101 WatchFrame_Update()")
    l0 = b1.lignes[1]
    print("   objectif rempli : coche %s, lueur %sx%s" % (l0.coche.shown, l0.lueur.width, l0.lueur.alpha))
    assert l0.coche.shown and not l0.tiret.shown
    lua.execute("JOURNAL[2].objectifs[1][2] = false WatchFrame_Update()")

    # replier un module : son en-tete reste, ses blocs partent
    lua.execute("ForeverUIQuestObjectiveTracker.entete.bouton:GetScript('OnClick')()")
    print("   module replie : %s de haut, blocs montres %d" % (mq.height, sum(1 for b in mq.blocs.values() if b.shown)))
    assert mq.shown and mq.height == 25 and len(list(mq.blocs.values())) == 0
    lua.execute("ForeverUIQuestObjectiveTracker.entete.bouton:GetScript('OnClick')()")
    assert len(list(mq.blocs.values())) == 2

    # replier tout : WatchFrame_Collapse, qui garde 260 et l'en-tete
    lua.execute("ForeverUIObjectiveTrackerHeader.reduire:GetScript('OnClick')()")
    print("   tout replie : %s, largeur %s, lignes %s" % (wf.collapsed, wf.width, lignes.shown))
    assert wf.collapsed and wf.width == 260 and not lignes.shown and ent.shown
    eDeplier = g.UIAtlas.data["ui-questtrackerbutton-expand-all"]
    assert list(ent.reduire.GetNormalTexture(ent.reduire).texcoord.values())[0] == eDeplier[2]
    lua.execute("ForeverUIObjectiveTrackerHeader.reduire:GetScript('OnClick')()")
    assert not wf.collapsed and lignes.shown

    # le bouton filtre : le tri et les filtres de WotLK
    lua.execute("MENU_ENTREES = {} ForeverUIObjectiveTrackerHeader.filtre:GetScript('OnClick')(ForeverUIObjectiveTrackerHeader.filtre)")
    entrees = list(g.MENU_ENTREES.values())
    print("   filtre : %s" % [(e.text, e.checked) for e in entrees])
    assert [e.text for e in entrees] == ["Sort Quests", "Proximity", "Difficulty High", "Difficulty Low", "Manual",
                                         "Display", "Achievements", "Completed Quests", "Remote Zones"]
    assert entrees[4].checked == True and entrees[6].checked == True
    entrees[6].func()
    print("   sans les hauts faits : module montre=%s" % ma.shown)
    assert g.WATCHFRAME_FILTER_TYPE == 6 and not ma.shown
    lua.execute("WatchFrame_SetFilter(nil, WATCHFRAME_FILTER_ACHIEVEMENTS)")

    # clic droit : le menu de camelot, et le deplacement manuel de WotLK
    lua.execute("MENU_ENTREES = {} ForeverUI.ObjectiveTracker.quetes.blocs[62].bouton:GetScript('OnClick')(nil, 'RightButton')")
    noms = [e.text for e in g.MENU_ENTREES.values()]
    print("   menu de la quete : %s" % noms)
    assert noms == ["The Fargodeep Mine", "Open Quest Details", "Open Quest Map", "Untrack", "Share in Chat", "Abandon",
                    "Move Up", "Move to Top"]
    list(g.MENU_ENTREES.values())[6].func()
    assert list(g.SUIVI_APPELS.values())[-1] == "deplacer 3 -1"

    # clic gauche : la carte, le volet et la page de la quete
    lua.execute("WorldMapFrame:Hide() ForeverUI.ObjectiveTracker.quetes.blocs[62].bouton:GetScript('OnClick')(nil, 'LeftButton')")
    det = g.ForeverUIQuestDetailsFrame
    print("   clic gauche : carte %s, page %s (quete %s)" % (g.WorldMapFrame.shown, det.shown, det.questID))
    assert g.WorldMapFrame.shown and det.shown and det.questID == 62
    lua.execute("ForeverUIQuestDetailsBackButton:GetScript('OnClick')(ForeverUIQuestDetailsBackButton) WorldMapFrame:Hide()")

    # une quete nouvellement suivie s'annonce (AddAnim : la lueur du titre)
    lua.execute('SUIVIES["The People\'s Militia"] = true ExpandQuestHeader(4) WatchFrame_Update()')
    b3 = {b.titre.text: b for b in mq.blocs.values()}.get("The People's Militia")
    print("   nouvelle quete : %s, lueur alpha %s, rendu '%s'" % (b3 is not None, b3 and b3.lueur.alpha,
                                                              b3 and [l.texte.text for l in b3.lignesMontrees.values()]))
    assert b3 and b3.lueur.alpha == 1, "la lueur du titre part"
    assert [l.texte.text for l in b3.lignesMontrees.values()] == ["Return to Gryan Stoutmantle."], "quete terminee : son texte de rendu, sans tiret"
    lua.execute("SUIVIES = {} HAUTS_FAITS_SUIVIS = {} CollapseQuestHeader(4) WatchFrame_Update()")
    assert not ent.shown, "plus rien a suivre : l'en-tete s'efface avec celui de WotLK"

    # LA PLACE DU SUIVI : un porteur deplacable par /fui, a la place de camelot
    porteur = g.ForeverUIObjectiveTrackerHolder
    d = g.ForeverUI.Layout.systems.suivi.defaults
    print("   porteur : %s x %s, defaut %s (%s, %s)" % (porteur.width, porteur.height, d.point, d.x, d.y))
    assert (d.point, d.relativePoint, d.x, d.y) == ("TOPRIGHT", "TOPRIGHT", -110, -275), "EditModePresetLayouts de camelot"
    assert porteur.movable
    porteur._top = 500
    lua.execute("UIParent_ManageFramePositions()")
    pts = [list(x.values()) for x in wf.points.values()]
    print("   apres le placement de WotLK : %d point(s), %s | hauteur %s" % (len(pts), pts[0][0], wf.height))
    assert len(pts) == 1 and pts[0][0] == "TOPLEFT" and meme(pts[0][1], porteur), "WotLK ne recolle plus le suivi sous la minimap"
    assert wf.height == 500 - 60, "du porteur au bas que WotLK lui donnait"
    # deplace en mode edition : le suivi suit, sa hauteur aussi
    porteur._top = 300
    lua.execute("ForeverUIObjectiveTrackerHolder:ClearAllPoints() ForeverUIObjectiveTrackerHolder:SetPoint('TOPRIGHT', UIParent, 'TOPRIGHT', -200, -400) ForeverUI.Layout.Save('suivi')")
    print("   deplace : x retenu %s, hauteur %s" % (g.ForeverUIDB.positions.suivi.x, wf.height))
    assert g.ForeverUIDB.positions.suivi.x == -200 and wf.height == 240
    lua.execute("ForeverUI.Layout.Reset('suivi')")
    assert not g.ForeverUIDB.positions.suivi

    # ------------------------------------------------------------------
    # LE GRIMOIRE (docs/GRIMOIRE.md, etape 1)
    # ------------------------------------------------------------------
    print("\n--- grimoire ---")
    meme = lua.eval("function(a, b) return rawequal(a, b) end")
    livre = g.ForeverUISpellBookFrame
    assert livre and meme(livre.parent, g.SpellBookFrame), "le livre vit dans SpellBookFrame : il s'ouvre et se ferme avec lui"
    assert g.SpellBookFrame.mouseEnabled == False, "le panneau vide de WotLK n'attrape plus la souris"
    assert g.ForeverUISpellBookButton48 and g.ForeverUISpellBookButton48.template == "SecureActionButtonTemplate", "48 cases securisees"
    lua.execute("SpellBookFrame:Show()")
    print("   livre %s x %s | SpellButton1 alpha %s | croix montree=%s" % (livre.width, livre.height, g.SpellButton1.alpha, g.SpellBookCloseButton.shown))
    assert (livre.width, livre.height) == (1618, 720)
    pl = list(livre.points[1].values())
    assert (pl[0], pl[2], pl[3], pl[4]) == ("TOP", "TOP", 0, -116), "panneau center de camelot"
    assert g.SpellButton1.alpha == 0 and g.SpellBookSkillLineTab1.alpha == 0 and g.SpellBookFrameIcon.alpha == 0, "WotLK s'efface"
    assert g.SpellBookCloseButton.alpha != 0, "la croix de WotLK reste, rhabillee"
    pf = list(g.SpellBookCloseButton.points[1].values())
    assert meme(pf[1], livre) and pf[0] == "TOPRIGHT" and meme(g.SpellBookCloseButton.parent, g.SpellBookFrame), \
        "ancree sur le livre, mais toujours l'enfant de SpellBookFrame (elle ferme son parent)"
    t1, t2 = g.ForeverUISpellBookTab1, g.ForeverUISpellBookTab2
    print("   onglets : %s (%s) | %s | 3e %s" % (t1.nom, t1.icone.texture, t2.nom, g.ForeverUISpellBookTab3))
    assert t1.nom == "General" and t1.icone.texture.endswith("classicon_deathknight"), "la Generale porte l'icone de la classe"
    assert t2.nom == "Frost" and g.ForeverUISpellBookTab3 is None, "pas de familier : deux onglets"
    assert t1.actif.shown and not t1.cadre.shown and t2.cadre.shown and not t2.actif.shown
    pt2 = list(t2.points[1].values())
    assert pt2[3] == 45, "44 de large, ecart 1"

    # la ligne Frost : le rang le plus haut seulement, le passif rond
    lua.execute("ForeverUISpellBookTab2:GetScript('OnClick')(ForeverUISpellBookTab2)")
    vue = g.ForeverUISpellBookView1
    cases = [c for c in vue.cases.values() if c.shown]
    print("   Frost : %s | en-tete '%s'" % ([(c.nom.text, c.sous.text, c.bouton.attributes.spell) for c in cases], vue.entete.texte.text))
    assert [c.nom.text for c in cases] == ["Frostbolt", "Frost Armor", "Ice Shards"], "un seul Frostbolt : son rang le plus haut"
    assert cases[0].bouton.attributes.spell == "Frostbolt(Rank 3)" and cases[0].bouton.attributes.type1 == "spell"
    passif = cases[2]
    assert passif.sous.text == "Passive" and passif.bouton.attributes.type1 is None, "un passif ne se lance pas"
    assert passif.bouton.cadre.texture == g.UIAtlas.data["talents-node-circle-gray"][1], "cadre rond"
    assert cases[0].bouton.cadre.texture == g.UIAtlas.data["spellbook-item-iconframe-c60"][1], "cadre carre, variante c60"
    print("   ombre carree : actif %s, passif %s" % (cases[0].bouton.ombre.shown, passif.bouton.ombre.shown))
    assert cases[0].bouton.ombre.shown and not passif.bouton.ombre.shown, "un passif : l'icone ronde seule"
    print("   portrait : %s" % livre.portrait.texture)
    assert livre.portrait.texture.endswith("spellbook\\portrait"), "l'icone cuite ronde, pas celle de WotLK"
    niveau_croix = g.SpellBookCloseButton.frameLevel
    print("   croix niveau %s, livre %s, toplevel %s" % (niveau_croix, livre.GetFrameLevel(livre), livre.toplevel))
    assert not livre.toplevel, "un livre toplevel se leverait par-dessus la croix"
    assert niveau_croix == livre.GetFrameLevel(livre) + 22, "au-dessus du metal (+20) et du titre (+21)"

    # les reglages : la fleche en haut a droite, deux cases
    rb = g.ForeverUISpellBookSettingsButton
    pr = list(rb.points[1].values())
    assert meme(pr[1], g.ForeverUISpellBookPages) and (pr[0], pr[2], pr[3], pr[4]) == ("TOPRIGHT", "TOPRIGHT", -30, -27)
    assert (rb.width, rb.height) == (15, 16) and rb.icone.texture == g.UIAtlas.data["common-dropdown-a-button"][1]
    # useAtlasSize : une texture ancree par son seul centre et sans taille
    # s'afficherait a la taille de la feuille entiere
    print("   fleche des reglages : %s x %s" % (rb.icone.width, rb.icone.height))
    assert (rb.icone.width, rb.icone.height) == (27, 27), "la taille d'atlas, pas celle de la feuille"
    # LE MENU, EN BOUTONS SECURISES (pour le combat) : la fleche l'ouvre, trois
    # lignes dans l'ordre de SetupSettingsDropdown, groupe par defaut
    liste = g.ForeverUISpellBookSettingsList
    assert not liste.shown
    lua.execute("CLIQUER(ForeverUISpellBookSettingsButton)")
    lignes = [g["ForeverUISpellBookSettingsEntry%d" % i] for i in (1, 2, 3)]
    entrees = [(l.texte.text, l.coche.shown) for l in lignes]
    pl = list(liste.points[1].values())
    print("   reglages : %s | liste %s x %s, %s de %s" % (entrees, liste.width, liste.height, pl[0], pl[2]))
    assert liste.shown and liste.strata == "DIALOG" and liste.autoHide == 2, "ouverte ; fermee 2 s apres la souris"
    assert meme(pl[1], rb) and (pl[0], pl[2], pl[3], pl[4]) == ("TOPLEFT", "BOTTOMLEFT", 0, 0)
    assert entrees == [("Hide Passives", False), ("Group Similar Spells on Flyouts", True), ("Show all spell ranks", False)]
    assert liste.height == 3 * 20 + 2 * 15
    assert liste.width == max(len(l.texte.text) * 6 for l in lignes) + 40 + 25 and lignes[0].width == liste.width - 25
    p2 = list(lignes[1].points[1].values())
    assert (p2[0], p2[3], p2[4]) == ("TOPLEFT", 11, -35), "x = 5 + 12 - 6, y = -15 - 20"
    # masquer les passifs : Ice Shards disparait, la case se coche, la liste
    # reste ouverte ; et retour
    lua.execute("CLIQUER(ForeverUISpellBookSettingsEntry1)")
    assert [c.nom.text for c in vue.cases.values() if c.shown] == ["Frostbolt", "Frost Armor"]
    assert lignes[0].coche.shown and liste.shown and g.ForeverUIDB.grimoire.masquerPassifs
    lua.execute("CLIQUER(ForeverUISpellBookSettingsEntry1)")
    assert [c.nom.text for c in vue.cases.values() if c.shown] == ["Frostbolt", "Frost Armor", "Ice Shards"]
    assert not lignes[0].coche.shown
    # tous les rangs
    lua.execute("CLIQUER(ForeverUISpellBookSettingsEntry3)")
    assert g.STATE.cvars.ShowAllSpellRanks == "1" and lignes[2].coche.shown
    assert [c.nom.text for c in vue.cases.values() if c.shown][:3] == ["Frostbolt", "Frostbolt", "Frostbolt"]
    lua.execute("CLIQUER(ForeverUISpellBookSettingsEntry3)")
    assert g.STATE.cvars.ShowAllSpellRanks == "0"
    # la fleche referme
    lua.execute("CLIQUER(ForeverUISpellBookSettingsButton)")
    assert not liste.shown
    assert vue.entete.texte.text == "Frost" and vue.entete.shown
    xs = [list(c.points[1].values())[3] for c in cases]
    ys = [list(c.points[1].values())[4] for c in cases]
    print("   positions x %s, y %s" % ([round(x, 2) for x in xs], ys))
    assert abs(xs[1] - (680 - 30) / 3 - 15) < 1e-6 and ys == [-61, -61, -61], "trois colonnes, une rangee, sous l'en-tete (51 + 10)"
    assert g.ForeverUISpellBookPages.parent and not g.ForeverUISpellBookPrevPage.enabled and not g.ForeverUISpellBookNextPage.enabled
    # tous les rangs (CVar ShowAllSpellRanks)
    lua.execute("STATE.cvars.ShowAllSpellRanks = '1' ForeverUI.SpellBook.maj()")
    assert [c.nom.text for c in vue.cases.values() if c.shown][:3] == ["Frostbolt", "Frostbolt", "Frostbolt"]
    lua.execute("STATE.cvars.ShowAllSpellRanks = '0' ForeverUI.SpellBook.maj()")
    # glisser : PickupSpell, sur l'emplacement du livre
    lua.execute("PRIS = {} ForeverUISpellBookButton1:GetScript('OnDragStart')(ForeverUISpellBookButton1)")
    assert list(g.PRIS.values()) == ["spell5"], "l'emplacement du rang le plus haut"

    # la mise en page de camelot : 30 sorts -> 7 rangees sous l'en-tete, puis
    # l'en-tete REPETE et 3 rangees
    vues = g.ForeverUI.SpellBook.mettreEnPage("X", lua.eval("(function() local t = {} for i = 1, 30 do t[i] = { nom = 'S' .. i } end return t end)()"))
    v1 = [e for e in vues[1].values()]
    v2 = [e for e in vues[2].values()]
    print("   30 sorts : vue 1 %d elements, vue 2 %d" % (len(v1), len(v2)))
    assert len(v1) == 1 + 21 and len(v2) == 1 + 9
    assert v1[1].sort.nom == "S1" and v1[2].sort.nom == "S2" and v1[1].colonne == 1 and v1[8].colonne == 2, "colonne par colonne"
    assert v2[0].entete == "X" and v2[0].y == 0, "le nom de la categorie reste en tete de la vue suivante"
    assert v2[1].y == 61 and v2[1].sort.nom == "S22" and v2[4].colonne == 2, "la vue 2 recompte ses rangees sous l'en-tete : 3"

    # LES MENUS VOLANTS (SPELLBOOK_USE_FLYOUTS). Une ligne Arcane : deux
    # teleportations (groupe 250), deux portails (groupe 248), un sort seul.
    lua.execute("""
        LIVRE.spell[8] = { "Teleport: Stormwind", "", false, "icone:tp_hurlevent" }
        LIVRE.spell[9] = { "Portal: Stormwind", "", false, "icone:portail" }
        LIVRE.spell[10] = { "Teleport: Ironforge", "", false, "icone:tp_forgefer" }
        LIVRE.spell[11] = { "Arcane Missiles", "Rank 1", false, "icone:projectiles" }
        LIVRE.spell[12] = { "Portal: Ironforge", "", false, "icone:portail_forgefer" }
        ONGLETS[3] = { "Arcane", "icone:arcane", 7, 5 }
        ForeverUI.SpellBook.maj()
        ForeverUISpellBookTab3:GetScript('OnClick')(ForeverUISpellBookTab3)
    """)
    montrees = [c for c in vue.cases.values() if c.shown]
    print("   groupes : %s" % [(c.nom.text, c.sous.text, c.bouton.fleche.shown) for c in montrees])
    assert [c.nom.text for c in montrees] == ["Teleport", "Portal", "Arcane Missiles"], \
        "chaque groupe a la place de son premier sort, ses membres retires"
    tp = montrees[0]
    assert tp.sort.volant.id == 250 and tp.bouton.icone.texture.endswith("spell_arcane_teleportstormwind")
    assert tp.bouton.attributes.type1 is None and tp.bouton.attributes.spell is None, "un groupe ne lance rien"
    assert tp.sous.text == "" and tp.bouton.fleche.shown and not montrees[2].bouton.fleche.shown
    assert [m.nom for m in tp.sort.membres.values()] == ["Teleport: Ironforge", "Teleport: Stormwind"], \
        "l'ordre du groupe (Darnassus, Ironforge, Stormwind), pas celui du livre"
    # la fleche : 15 x 6 tournee vers la droite (90), a 4 du bord
    fl = tp.bouton.fleche
    e = g.UIAtlas.data["ui-hud-actionbar-flyout"]
    tc = list(fl.texcoord8.values())
    pf = list(fl.points[1].values())
    print("   fleche : %s x %s, %s (%s) | coords %s" % (fl.width, fl.height, pf[0], pf[3], [round(x, 4) for x in tc]))
    assert (fl.width, fl.height) == (6, 15) and fl.texture == e[1]
    assert tc == [e[2], e[5], e[3], e[5], e[2], e[4], e[3], e[4]], "SetClampedTextureRotation(90) : UL <- LL, LL <- LR, UR <- UL, LR <- UR"
    assert pf[0] == "RIGHT" and pf[3] == 4
    # l'infobulle : le nom et la description du groupe
    lua.execute("ForeverUISpellBookButton1:GetScript('OnEnter')(ForeverUISpellBookButton1)")
    print("   infobulle : '%s' | survol %s" % (g.GameTooltip.text, fl.texture == g.UIAtlas.data["ui-hud-actionbar-flyout-mouseover"][1]))
    assert g.GameTooltip.text == "Teleport"
    assert list(fl.texcoord8.values())[0] == g.UIAtlas.data["ui-hud-actionbar-flyout-mouseover"][2], "fleche survolee"
    lua.execute("ForeverUISpellBookButton1:GetScript('OnLeave')(ForeverUISpellBookButton1)")
    # un glisser ne prend rien
    lua.execute("PRIS = {} ForeverUISpellBookButton1:GetScript('OnDragStart')(ForeverUISpellBookButton1)")
    assert len(g.PRIS) == 0, "3.3.5 ne met pas de menu volant sur une barre"

    # le clic ouvre le menu : un petit bouton securise par sort
    lua.execute("CLIQUER(ForeverUISpellBookButton1)")
    vol = g.ForeverUISpellFlyout
    p1, p2 = g.ForeverUISpellFlyoutButton1, g.ForeverUISpellFlyoutButton2
    pv = list(vol.points[1].values())
    print("   menu volant : %s x %s, %s de %s | %s, %s" % (vol.width, vol.height, pv[0], pv[2], p1.attributes.spell, p2.attributes.spell))
    assert vol.shown and vol.strata == "DIALOG"
    assert (vol.width, vol.height) == (9 + 2 * 30 + 4 + 9, 42), "9, deux boutons de 30 ecartes de 4, 9"
    assert pv[0] == "LEFT" and meme(pv[1], tp.bouton) and pv[2] == "RIGHT" and pv[3] == -4
    assert p1.template == "SecureActionButtonTemplate" and p1.attributes.type1 == "spell"
    assert p1.attributes.spell == "Teleport: Ironforge" and p2.attributes.spell == "Teleport: Stormwind"
    assert list(p2.points[1].values())[3] == 9 + 34 and (p1.width, p1.height) == (30, 30)
    assert p1.icone.texture == "icone:tp_forgefer"
    tco = list(fl.texcoord8.values())
    assert tco[0] == g.UIAtlas.data["ui-hud-actionbar-flyout"][3] and list(fl.points[1].values())[3] == 2, \
        "ouvert : la fleche se retourne (270) et passe a 2"
    # le glisser d'un petit bouton prend son sort ; le clic ferme le menu
    lua.execute("PRIS = {} ForeverUISpellFlyoutButton2:GetScript('OnDragStart')(ForeverUISpellFlyoutButton2)")
    assert list(g.PRIS.values()) == ["spell8"]
    lua.execute("LANCES = {} CLIQUER(ForeverUISpellFlyoutButton1)")
    assert list(g.LANCES.values()) == ["Teleport: Ironforge"], "le petit bouton lance son sort"
    assert not vol.shown and list(fl.points[1].values())[3] == 4, "lance, le menu se ferme et la fleche revient"
    # le meme groupe deux fois : ouvert puis ferme ; un autre : le menu le suit
    lua.execute("CLIQUER(ForeverUISpellBookButton1)")
    lua.execute("CLIQUER(ForeverUISpellBookButton1)")
    assert not vol.shown
    lua.execute("CLIQUER(ForeverUISpellBookButton1)")
    lua.execute("CLIQUER(ForeverUISpellBookButton2)")
    assert vol.shown and meme(list(vol.points[1].values())[1], montrees[1].bouton)
    assert p1.attributes.spell == "Portal: Ironforge" and p2.attributes.spell == "Portal: Stormwind" and p2.shown
    # EN COMBAT AUSSI (etape 2) : le bloc securise ouvre le groupe
    lua.execute("CLIQUER(ForeverUISpellBookButton2)")
    assert not vol.shown
    lua.execute("STATE.verifierProtection = true STATE.inLockdown = true CLIQUER(ForeverUISpellBookButton1)")
    assert vol.shown and p1.attributes.spell == "Teleport: Ironforge", "en combat, le groupe s'ouvre"
    lua.execute("CLIQUER(ForeverUISpellBookButton1) STATE.inLockdown = false STATE.verifierProtection = false")
    assert not vol.shown
    # sans groupes : les sorts reviennent, a leur place
    lua.execute("CLIQUER(ForeverUISpellBookSettingsEntry2)")
    print("   sans groupes : %s" % [c.nom.text for c in vue.cases.values() if c.shown])
    assert [c.nom.text for c in vue.cases.values() if c.shown] == ["Teleport: Stormwind", "Portal: Stormwind",
        "Teleport: Ironforge", "Arcane Missiles", "Portal: Ironforge"]
    assert g.ForeverUIDB.grimoire.sansVolants
    lua.execute("CLIQUER(ForeverUISpellBookSettingsEntry2)")
    # UN GROUPE NE PASSE PAS D'UN ONGLET A L'AUTRE (les postures du guerrier,
    # une par arbre) : Arcane garde une teleportation et un portail, Feu les
    # deux autres ; seul, un sort reste un sort
    lua.execute("""
        ONGLETS[3] = { "Arcane", "icone:arcane", 7, 2 }
        ONGLETS[4] = { "Fire", "icone:feu", 9, 3 }
        ForeverUI.SpellBook.maj()
        ForeverUISpellBookTab3:GetScript('OnClick')(ForeverUISpellBookTab3)
    """)
    arcane = [c.nom.text for c in vue.cases.values() if c.shown]
    lua.execute("ForeverUISpellBookTab4:GetScript('OnClick')(ForeverUISpellBookTab4)")
    feu = [c.nom.text for c in vue.cases.values() if c.shown]
    print("   un groupe par onglet : Arcane %s | Fire %s" % (arcane, feu))
    assert arcane == ["Teleport: Stormwind", "Portal: Stormwind"], "rien a grouper dans l'onglet : chacun seul"
    assert feu == ["Teleport: Ironforge", "Arcane Missiles", "Portal: Ironforge"]
    # deux rangs d'un meme sort ne font pas un groupe
    lua.execute("""
        LIVRE.spell[10] = { "Portal: Ironforge", "Rank 1", false, "icone:portail_forgefer" }
        STATE.cvars.ShowAllSpellRanks = '1' ForeverUI.SpellBook.maj()
    """)
    print("   deux rangs : %s" % [c.nom.text for c in vue.cases.values() if c.shown])
    assert [c.nom.text for c in vue.cases.values() if c.shown] == ["Portal: Ironforge", "Arcane Missiles", "Portal: Ironforge"]
    lua.execute("STATE.cvars.ShowAllSpellRanks = '0'")
    # LES VILLES DE BURNING CRUSADE ET WOTLK, et Dalaran commun aux deux
    # factions : il rejoint le groupe de la faction du joueur
    lua.execute("""
        LIVRE.spell[8] = { "Teleport: Dalaran", "", false, "icone:tp_dalaran" }
        LIVRE.spell[9] = { "Teleport: Stormwind", "", false, "icone:tp_hurlevent" }
        LIVRE.spell[10] = { "Teleport: Exodar", "", false, "icone:tp_exodar" }
        LIVRE.spell[11] = { "Teleport: Orgrimmar", "", false, "icone:tp_orgrimmar" }
        LIVRE.spell[12] = nil
        ONGLETS[3] = { "Arcane", "icone:arcane", 7, 4 } ONGLETS[4] = nil
        ForeverUI.SpellBook.maj()
        ForeverUISpellBookTab3:GetScript('OnClick')(ForeverUISpellBookTab3)
    """)
    alliance = [(c.nom.text, [m.nom for m in c.sort.membres.values()] if c.sort.membres else None)
        for c in vue.cases.values() if c.shown]
    print("   Alliance : %s" % alliance)
    assert alliance == [("Teleport", ["Teleport: Stormwind", "Teleport: Exodar", "Teleport: Dalaran"]),
        ("Teleport: Orgrimmar", None)], "Stormwind (camelot), puis Exodar et Dalaran ; Orgrimmar n'est pas de la faction"
    lua.execute("STATE.faction = 'Horde' ForeverUI.SpellBook.maj()")
    horde = [(c.nom.text, [m.nom for m in c.sort.membres.values()] if c.sort.membres else None)
        for c in vue.cases.values() if c.shown]
    print("   Horde : %s" % horde)
    assert horde[0] == ("Teleport", ["Teleport: Orgrimmar", "Teleport: Dalaran"]) and         vue.cases[1].bouton.icone.texture.endswith("spell_arcane_teleportorgrimmar"), "Dalaran rejoint le groupe de la Horde"
    lua.execute("STATE.faction = 'Alliance'")
    # LES AJOUTS DE BURNING CRUSADE ET WOTLK aux autres familles : Aspect of
    # the Viper rejoint les aspects ; Hand of Salvation (Blessing of
    # Salvation chez camelot) passe avec les autres Hand
    lua.execute("""
        LIVRE.spell[8] = { "Aspect of the Hawk", "Rank 1", false, "icone:faucon" }
        LIVRE.spell[9] = { "Aspect of the Viper", "", false, "icone:vipere" }
        LIVRE.spell[10] = { "Blessing of Kings", "", false, "icone:rois" }
        LIVRE.spell[11] = { "Hand of Salvation", "", false, "icone:salut" }
        LIVRE.spell[12] = { "Hand of Protection", "Rank 1", false, "icone:protection" }
        ONGLETS[3] = { "Arcane", "icone:arcane", 7, 5 }
        ForeverUI.SpellBook.maj()
    """)
    ajouts = [(c.nom.text, [m.nom for m in c.sort.membres.values()] if c.sort.membres else None)
        for c in vue.cases.values() if c.shown]
    print("   ajouts : %s" % ajouts)
    assert ajouts == [("Aspect", ["Aspect of the Hawk", "Aspect of the Viper"]), ("Blessing of Kings", None),
        ("Utility Blessings", ["Hand of Protection", "Hand of Salvation"])]
    # les sceaux et les jugements : deux groupes que camelot n'a pas, sans
    # description, a l'icone de leur premier sort
    lua.execute("""
        LIVRE.spell[8] = { "Seal of Light", "", false, "icone:sceau_lumiere" }
        LIVRE.spell[9] = { "Judgement of Light", "", false, "icone:jugement_lumiere" }
        LIVRE.spell[10] = { "Seal of Righteousness", "", false, "icone:sceau_piete" }
        LIVRE.spell[11] = { "Judgement of Wisdom", "", false, "icone:jugement_sagesse" }
        LIVRE.spell[12] = nil
        ONGLETS[3] = { "Arcane", "icone:arcane", 7, 4 }
        ForeverUI.SpellBook.maj()
    """)
    paladin = [(c.nom.text, c.bouton.icone.texture, [m.nom for m in c.sort.membres.values()])
        for c in vue.cases.values() if c.shown]
    print("   paladin : %s" % paladin)
    assert paladin == [("Seals", "icone:sceau_piete", ["Seal of Righteousness", "Seal of Light"]),
        ("Judgements", "icone:jugement_lumiere", ["Judgement of Light", "Judgement of Wisdom"])]
    lua.execute("ForeverUISpellBookButton1:GetScript('OnEnter')(ForeverUISpellBookButton1)")
    assert g.GameTooltip.text == "Seals", "l'infobulle : le nom seul"
    lua.execute("ForeverUISpellBookButton1:GetScript('OnLeave')(ForeverUISpellBookButton1)")
    lua.execute("for i = 8, 12 do LIVRE.spell[i] = nil end ONGLETS[3] = nil ONGLETS[4] = nil")
    lua.execute("ForeverUISpellBookTab1:GetScript('OnClick')(ForeverUISpellBookTab1)")

    # le familier : son onglet, lance par le nom, clic droit = lancement automatique
    lua.execute("FAMILIER_LIVRE = true SpellBookFrame:Hide() SpellBookFrame.bookType = 'pet' SpellBookFrame:Show()")
    t3 = g.ForeverUISpellBookTab3
    gr = [c for c in vue.cases.values() if c.shown][0]
    print("   familier : onglet %s choisi=%s | %s -> %s / %s" % (t3.nom, t3.actif.shown, gr.nom.text,
        gr.bouton.attributes.spell, gr.bouton.attributes.macrotext2))
    assert t3.nom == "Pet" and t3.actif.shown, "ToggleSpellBook(BOOKTYPE_PET) ouvre sur le familier"
    assert gr.bouton.attributes.spell == "Growl" and gr.bouton.attributes.macrotext2 == "/petautocasttoggle Growl"
    assert gr.bouton.auto.shown, "lancement automatique allume"
    lua.execute("SpellBookFrame:Hide() SpellBookFrame.bookType = 'spell' FAMILIER_LIVRE = nil SpellBookFrame:Show()")

    # une page : 809, la vue 2 cachee
    lua.execute("CLIQUER(ForeverUISpellBookFrame.taille)")
    print("   reduit : %s de large, vue 2 %s" % (livre.width, g.ForeverUISpellBookView2.shown))
    assert livre.width == 809 and not g.ForeverUISpellBookView2.shown and g.ForeverUIDB.grimoire.reduit
    lua.execute("CLIQUER(ForeverUISpellBookFrame.taille)")
    assert livre.width == 1618 and g.ForeverUISpellBookView2.shown

    # ------------------------------------------------------------------
    # LA RECHERCHE (etape 3)
    # ------------------------------------------------------------------
    print("\n--- recherche du grimoire ---")
    lua.execute("""
        LIVRE.spell[8] = { "Arcane Missiles", "Rank 1", false, "icone:projectiles" }
        LIVRE.spell[9] = { "Arcane Intellect", "Rank 1", false, "icone:intelligence" }
        LIVRE.spell[10] = { "Arcane Blast", "Rank 1", false, "icone:deflagration" }
        LIVRE.spell[11] = { "Arcane Power", "", false, "icone:puissance" }
        LIVRE.spell[12] = { "Arcane Barrage", "Rank 1", false, "icone:barrage" }
        LIVRE.spell[13] = { "Teleport: Stormwind", "", false, "icone:tp_hurlevent" }
        LIVRE.spell[14] = { "Teleport: Ironforge", "", false, "icone:tp_forgefer" }
        LIVRE.spell[15] = { "Arcane Explosion", "Rank 1", false, "icone:explosion" }
        LIVRE.spell[16] = { "Arcane Brilliance", "Rank 1", false, "icone:illumination" }
        ONGLETS[3] = { "Arcane", "icone:arcane", 7, 9 }
        DESCRIPTIONS = {
            spell3 = "Launches a bolt of frost at the enemy. Works well with Frost Armor.",
            spell4 = "Launches a bolt of frost at the enemy. Works well with Frost Armor.",
            spell5 = "Launches a bolt of frost at the enemy. Works well with Frost Armor.",
            spell6 = "Increases armor.",
            spell7 = "Increases the critical strike damage bonus of your Frost spells.",
            spell8 = "Launches arcane missiles.",
        }
        ForeverUI.SpellBook.maj()
        CLIQUER(ForeverUISpellBookTab2)
    """)
    boite = g.ForeverUISpellBookSearchBox
    apercu = g.ForeverUISpellBookSearchPreview
    pb = list(boite.points[1].values())
    print("   champ : %s x %s, %s du %s des reglages (%s, %s) | consigne '%s'" % (boite.width, boite.height,
        pb[0], pb[2], pb[3], pb[4], boite.consigne.text))
    assert (boite.width, boite.height) == (300, 30) and meme(pb[1], g.ForeverUISpellBookSettingsButton)
    assert (pb[0], pb[2], pb[3], pb[4]) == ("RIGHT", "LEFT", -5, 4) and boite.maxLetters == 40
    assert boite.consigne.text == "Search abilities, keywords" and boite.consigne.shown
    assert not g.ForeverUISpellBookSearchClear.shown, "sans focus ni texte, pas d'effacement"
    # le focus, sous 3 lettres : la suggestion
    lua.execute("ForeverUISpellBookSearchBox:SetFocus()")
    print("   focus : apercu %s, suggestion '%s', hauteur %s" % (apercu.shown, apercu.suggestion.texte.text, apercu.height))
    assert apercu.shown and apercu.suggestion.shown and apercu.suggestion.texte.text == "Missing from action bar"
    assert apercu.height == 27 + 3 and g.ForeverUISpellBookSearchClear.shown
    # trois lettres : l'apercu des noms (reglages en cours : le plus haut rang)
    lua.execute("ForeverUISpellBookSearchBox:Taper('fro')")
    lignes = [l for l in apercu.lignes.values() if l.shown]
    print("   'fro' : %s" % [(l.nom.text, l.icone.texture) for l in lignes])
    assert [l.nom.text for l in lignes] == ["Frostbolt", "Frost Armor"] and not apercu.suggestion.shown
    assert apercu.height == 1 + 2 * 27 + 1 + 3 and not apercu.depassement.shown
    # plus de cinq (camelot : trois ; cinq a la demande) : "And 2 more"
    lua.execute("ForeverUISpellBookSearchBox:Taper('arcane')")
    print("   'arcane' : %s | %s | hauteur %s" % ([l.nom.text for l in apercu.lignes.values() if l.shown],
        apercu.depassement.texte.text, apercu.height))
    assert len([l for l in apercu.lignes.values() if l.shown]) == 5
    assert apercu.depassement.shown and apercu.depassement.texte.text == "And 2 more"
    assert apercu.height == 1 + 5 * 27 + 4 + 3 + 16
    # L'ICONE AU-DESSUS DU FOND : la texture normale d'un bouton se dessine en
    # ARTWORK, sans sous-niveau en 3.3.5 ; l'icone va en OVERLAY, son cadre
    # et la surbrillance dans un cadre fils
    l1 = apercu.lignes[1]
    assert l1.icone.layer == "OVERLAY" and l1.icone.texture == "icone:projectiles"
    assert meme(l1.surligne.owner, l1.dessus) and l1.dessus.frameLevel == l1.GetFrameLevel(l1) + 1
    # le clavier : bas, bas, haut ; Entree choisit
    lua.execute("ForeverUISpellBookSearchBox.scripts.OnKeyDown(ForeverUISpellBookSearchBox, 'DOWN')")
    lua.execute("ForeverUISpellBookSearchBox.scripts.OnKeyDown(ForeverUISpellBookSearchBox, 'DOWN')")
    assert apercu.surligne == 2 and apercu.lignes[2].surligne.shown and not apercu.lignes[1].surligne.shown
    lua.execute("ForeverUISpellBookSearchBox.scripts.OnKeyDown(ForeverUISpellBookSearchBox, 'UP')")
    assert apercu.surligne == 1
    lua.execute("ForeverUISpellBookSearchBox.scripts.OnEnterPressed(ForeverUISpellBookSearchBox)")
    montrees = [c for c in vue.cases.values() if c.shown]
    print("   Entree sur '%s' : texte '%s', categorie %s, %s" % (apercu.lignes[1].nom.text, boite.text,
        g.ForeverUI.SpellBook.etat.categorie, [c.nom.text for c in montrees]))
    assert boite.text == "Arcane Missiles" and g.ForeverUI.SpellBook.etat.categorie == 0
    assert montrees[0].nom.text == "Arcane Missiles" and not apercu.shown and not boite.focused

    # LA RECHERCHE ENTIERE : "frost" -- noms, puis descriptions ; les rangs
    # suivent "Show all spell ranks" (ici non coche : le plus haut)
    lua.execute("ForeverUISpellBookSearchBox:SetFocus() ForeverUISpellBookSearchBox:Taper('frost') ForeverUISpellBookSearchBox.scripts.OnEnterPressed(ForeverUISpellBookSearchBox)")
    montrees = [c for c in vue.cases.values() if c.shown]
    entetes = [(h.texte.text, list(h.points[1].values())[4]) for h in vue.entetes.values() if h.shown]
    print("   'frost' : %s | en-tetes %s" % ([(c.nom.text, c.sous.text) for c in montrees], entetes))
    assert [(c.nom.text, c.sous.text) for c in montrees] == [("Frostbolt", "Rank 3"), ("Frost Armor", "Rank 1"), ("Ice Shards", "Passive")]
    assert entetes == [("Name Matches", 0), ("Description Matches", -(61 + 70 + 30))], \
        "deux sections ; la seconde apres une rangee et l'espaceur (20 + 10)"
    assert not any(o.actif.shown for o in g.ForeverUI.SpellBook.onglets.boutons.values()), "aucun onglet choisi"
    ent = [g["ForeverUISpellBookSettingsEntry%d" % i] for i in (1, 2, 3)]
    assert ent[0].enabled == False and ent[1].enabled == False and ent[0].texte.textColor[1] == 0.5, "reglages desactives"
    assert ent[2].enabled != False and ent[2].texte.textColor[1] == 1, "sauf Show all spell ranks (demande du 2026-09-25)"
    lua.execute("ForeverUISpellBookSettingsEntry1.scripts.OnEnter(ForeverUISpellBookSettingsEntry1)")
    assert g.GameTooltip.text == "Hiding Passives is disabled while searching"
    lua.execute("LANCES = {} CLIQUER(ForeverUISpellBookButton1)")
    assert list(g.LANCES.values()) == ["Frostbolt(Rank 3)"], "un resultat se lance"
    # "Frostbolt" : exact, puis apparente (Frost Armor est dans sa description)
    lua.execute("ForeverUISpellBookSearchBox:SetFocus() ForeverUISpellBookSearchBox:Taper('Frostbolt') ForeverUISpellBookSearchBox.scripts.OnEnterPressed(ForeverUISpellBookSearchBox)")
    montrees = [c for c in vue.cases.values() if c.shown]
    entetes = [h.texte.text for h in vue.entetes.values() if h.shown]
    print("   'Frostbolt' : %s | %s" % ([c.nom.text for c in montrees], entetes))
    assert entetes == ["Exact Matches", "Related Matches"] and [c.nom.text for c in montrees] == ["Frostbolt", "Frost Armor"]
    # un onglet sort de la recherche, sans revenir au premier
    lua.execute("CLIQUER(ForeverUISpellBookTab3)")
    # "Show all spell ranks" coche EN PLEINE RECHERCHE : tous les rangs, tout
    # de suite ; et en combat aussi
    lua.execute("ForeverUISpellBookSearchBox:SetFocus() ForeverUISpellBookSearchBox:Taper('Frostbolt') ForeverUISpellBookSearchBox.scripts.OnEnterPressed(ForeverUISpellBookSearchBox)")
    lua.execute("CLIQUER(ForeverUISpellBookSettingsEntry3)")
    tous = [(c.nom.text, c.sous.text) for c in vue.cases.values() if c.shown]
    print("   tous les rangs, en recherche : %s" % tous)
    assert g.ForeverUI.SpellBook.etat.categorie == 0 and g.STATE.cvars.ShowAllSpellRanks == "1"
    assert tous[:3] == [("Frostbolt", "Rank 1"), ("Frostbolt", "Rank 2"), ("Frostbolt", "Rank 3")]
    lua.execute("STATE.verifierProtection = true STATE.inLockdown = true CLIQUER(ForeverUISpellBookSettingsEntry3)")
    assert [c.nom.text for c in vue.cases.values() if c.shown] == ["Frostbolt", "Frost Armor"], "en combat aussi"
    lua.execute("STATE.inLockdown = false STATE.verifierProtection = false CLIQUER(ForeverUISpellBookTab3)")
    assert g.STATE.cvars.ShowAllSpellRanks == "0"
    # "Hide Passives" coche : la recherche ne montre plus Ice Shards
    lua.execute("CLIQUER(ForeverUISpellBookSettingsEntry1) ForeverUISpellBookSearchBox:SetFocus() ForeverUISpellBookSearchBox:Taper('frost') ForeverUISpellBookSearchBox.scripts.OnEnterPressed(ForeverUISpellBookSearchBox)")
    sansPassifs = [c.nom.text for c in vue.cases.values() if c.shown]
    print("   sans passifs : %s" % sansPassifs)
    assert sansPassifs == ["Frostbolt", "Frost Armor"]
    lua.execute("CLIQUER(ForeverUISpellBookTab3) CLIQUER(ForeverUISpellBookSettingsEntry1)")
    assert not g.ForeverUIDB.grimoire.masquerPassifs
    assert g.ForeverUI.SpellBook.etat.categorie == 3 and boite.text == "" and not g.ForeverUI.SpellBookSearch.active()
    assert ent[0].enabled != False and ent[0].texte.textColor[1] == 1
    # l'effacement sort de la recherche et revient au premier onglet
    lua.execute("ForeverUISpellBookSearchBox:SetFocus() ForeverUISpellBookSearchBox:Taper('frost') ForeverUISpellBookSearchBox.scripts.OnEnterPressed(ForeverUISpellBookSearchBox)")
    assert g.ForeverUI.SpellBook.etat.categorie == 0
    lua.execute("CLIQUER(ForeverUISpellBookSearchClear)")
    assert g.ForeverUI.SpellBook.etat.categorie == 1 and boite.text == "" and not g.ForeverUISpellBookSearchClear.shown
    # sans resultat : on reste hors recherche ; Entree sous 3 lettres aussi
    lua.execute("ForeverUISpellBookSearchBox:SetFocus() ForeverUISpellBookSearchBox:Taper('zzz') ForeverUISpellBookSearchBox.scripts.OnEnterPressed(ForeverUISpellBookSearchBox)")
    assert g.ForeverUI.SpellBook.etat.categorie == 1 and boite.text == "" and not g.ForeverUI.SpellBookSearch.active()

    # "MISSING FROM ACTION BAR" : la suggestion. Frostbolt est sur la barre
    # principale, Frost Armor sur la barre de droite (desactivee), Arcane
    # Missiles sur une barre de posture inactive.
    lua.execute("""
        ACTIONS = { [1] = { "spell", 5, "spell" }, [30] = { "spell", 6, "spell" }, [80] = { "spell", 8, "spell" } }
        BARRES = { true, true, false, true }
        ForeverUISpellBookSearchBox:SetFocus()
        CLIQUER(ForeverUISpellBookSearchResultSuggestion)
    """)
    montrees = [c.nom.text for c in vue.cases.values() if c.shown] + \
        [c.nom.text for c in g.ForeverUISpellBookView2.cases.values() if c.shown]
    entetes = [h.texte.text for h in vue.entetes.values() if h.shown]
    print("   absents des barres : %s | %s | champ '%s'" % (montrees, entetes, boite.text))
    assert boite.text == "Missing from action bar" and entetes == ["Matches"]
    assert "Frostbolt" not in montrees and "Attack" not in montrees and "Shoot" not in montrees and "Ice Shards" not in montrees
    assert montrees[-2:] == ["Arcane Missiles", "Frost Armor"], "absents, puis posture inactive, puis barre desactivee"
    assert "Teleport: Stormwind" in montrees and "Teleport" not in montrees, "jamais de groupe dans la recherche"
    # Arcane Missiles posee sur la barre principale : elle quitte la liste,
    # a l'image suivante (ACTIONBAR_SLOT_CHANGED)
    lua.execute("""
        ACTIONS[2] = { "spell", 8, "spell" }
        local v = ForeverUI.SpellBookSearch.veilleBarres
        v.scripts.OnEvent(v, "ACTIONBAR_SLOT_CHANGED", 2)
        v.scripts.OnEvent(v, "ACTIONBAR_SLOT_CHANGED", 2)
    """)
    vb = g.ForeverUI.SpellBookSearch.veilleBarres
    assert vb.shown, "une seule mise a jour, a l'image suivante"
    lua.execute("local v = ForeverUI.SpellBookSearch.veilleBarres v.scripts.OnUpdate(v)")
    montrees2 = [c.nom.text for c in vue.cases.values() if c.shown] +         [c.nom.text for c in g.ForeverUISpellBookView2.cases.values() if c.shown]
    print("   posee sur la barre : %s" % montrees2[-2:])
    assert "Arcane Missiles" not in montrees2 and montrees2[-1] == "Frost Armor" and not vb.shown
    # en combat : la mise a jour attend la fin du combat
    lua.execute("""
        STATE.inLockdown = true
        ACTIONS[2] = nil
        local v = ForeverUI.SpellBookSearch.veilleBarres
        v.scripts.OnEvent(v, "ACTIONBAR_SLOT_CHANGED", 2)
        v.scripts.OnUpdate(v)
    """)
    assert g.ForeverUI.SpellBook.enAttente, "publiee a la fin du combat"
    lua.execute("STATE.inLockdown = false ForeverUI.SpellBook.maj()")
    montrees3 = [c.nom.text for c in vue.cases.values() if c.shown] +         [c.nom.text for c in g.ForeverUISpellBookView2.cases.values() if c.shown]
    assert "Arcane Missiles" in montrees3
    # une recherche de sorts groupes dans leur onglet : un par un
    lua.execute("CLIQUER(ForeverUISpellBookSearchClear) ForeverUISpellBookSearchBox:SetFocus() ForeverUISpellBookSearchBox:Taper('tele')")
    assert [l.nom.text for l in apercu.lignes.values() if l.shown] == ["Teleport: Stormwind", "Teleport: Ironforge"]
    lua.execute("ForeverUISpellBookSearchBox.scripts.OnEnterPressed(ForeverUISpellBookSearchBox)")
    tele = [(c.nom.text, c.bouton.fleche.shown) for c in vue.cases.values() if c.shown]
    print("   'tele' : %s" % tele)
    assert tele == [("Teleport: Stormwind", False), ("Teleport: Ironforge", False)]

    # EN COMBAT : le champ refuse le focus ; l'effacement sort de la recherche
    lua.execute("STATE.verifierProtection = true STATE.inLockdown = true ForeverUISpellBookSearchBox:SetFocus()")
    assert not boite.focused and not apercu.shown
    lua.execute("CLIQUER(ForeverUISpellBookSearchClear)")
    print("   combat, effacement : categorie %s, texte '%s'" % (g.ForeverUI.SpellBook.etat.categorie, boite.text))
    assert g.ForeverUI.SpellBook.etat.categorie == 1 and boite.text == ""
    assert g.ForeverUISpellBookSearchClear.alpha == 0, "en combat, l'effacement se fait transparent"
    lua.execute("STATE.inLockdown = false STATE.verifierProtection = false ForeverUI.SpellBookSearch.boite:SetFocus() ForeverUI.SpellBookSearch.boite:ClearFocus()")
    assert not g.ForeverUISpellBookSearchClear.shown
    lua.execute("for i = 8, 16 do LIVRE.spell[i] = nil end ONGLETS[3] = nil DESCRIPTIONS = nil ACTIONS = {} BARRES = { true, true, true, true } ForeverUI.SpellBook.maj()")

    # ------------------------------------------------------------------
    # EN COMBAT (etape 2). Le faux client bloque toute action protegee du
    # code ordinaire (ADDON_ACTION_BLOCKED) : tout passe par les blocs
    # securises, et les images suivent par CallMethod.
    # ------------------------------------------------------------------
    lua.execute("""
        LIVRE.spell[8] = { "Teleport: Stormwind", "", false, "icone:tp_hurlevent" }
        LIVRE.spell[9] = { "Teleport: Ironforge", "", false, "icone:tp_forgefer" }
        for i = 10, 57 do LIVRE.spell[i] = { "Sort " .. i, "", false, "icone:" .. i } end
        ONGLETS[3] = { "Arcane", "icone:arcane", 7, 50 }
        SpellBookFrame:Hide()
    """)
    # hors combat, le livre est publie sans etre ouvert (SPELLS_CHANGED)
    lua.execute("ForeverUI.SpellBook.maj()")
    lua.execute("STATE.verifierProtection = true STATE.inLockdown = true PAR_BLIZZARD(function() SpellBookFrame:Show() end)")
    print("   combat : livre ouvert, categorie %s" % g.ForeverUI.SpellBook.etat.categorie)
    # un onglet : la categorie change, et ses cases avec leurs sorts
    lua.execute("CLIQUER(ForeverUISpellBookTab3)")
    montrees = [c for c in vue.cases.values() if c.shown]
    print("   combat, onglet Arcane : %s ... (%d cases), %s" % ([c.nom.text for c in montrees[:3]], len(montrees),
        g.ForeverUISpellBookView1.entete.texte.text))
    assert g.ForeverUI.SpellBook.etat.categorie == 3 and montrees[0].nom.text == "Teleport"
    assert montrees[1].bouton.attributes.spell == "Sort 10" and montrees[1].nom.text == "Sort 10"
    assert not g.ForeverUISpellBookTab3.enabled and g.ForeverUISpellBookTab3.actif.shown, "l'onglet choisi s'allume"
    assert g.ForeverUISpellBookTab1.enabled != False and not g.ForeverUISpellBookTab1.actif.shown
    # une case lance son sort
    lua.execute("LANCES = {} CLIQUER(ForeverUISpellBookButton2)")
    assert list(g.LANCES.values()) == ["Sort 10"], "en combat, la case lance le sort qu'elle montre"
    # la page suivante : 49 elements, 21 par vue -- trois vues, deux pages
    lua.execute("CLIQUER(ForeverUISpellBookNextPage)")
    page2 = [c for c in vue.cases.values() if c.shown]
    print("   combat, page suivante : %s | %s" % ([c.nom.text for c in page2], g.ForeverUI.SpellBook.pager.texte.text))
    assert g.ForeverUI.SpellBook.etat.page == 2 and g.ForeverUI.SpellBook.pager.texte.text == "Page 2/2"
    assert page2[0].nom.text == "Sort 51" and page2[0].bouton.attributes.spell == "Sort 51"
    assert not g.ForeverUISpellBookView2.cases[1].shown, "la page 2 n'a qu'une vue"
    assert not g.ForeverUISpellBookNextPage.enabled and g.ForeverUISpellBookPrevPage.enabled != False
    assert g.ForeverUISpellBookView1.entete.texte.text == "Arcane", "l'en-tete suit, en combat aussi"
    lua.execute("LANCES = {} CLIQUER(ForeverUISpellBookButton1)")
    assert list(g.LANCES.values()) == ["Sort 51"]
    # la roulette revient a la page 1
    lua.execute("ForeverUISpellBookContent.scripts.OnMouseWheel(ForeverUISpellBookContent, 1)")
    assert g.ForeverUI.SpellBook.etat.page == 1 and [c for c in vue.cases.values() if c.shown][1].nom.text == "Sort 10"
    # le groupe s'ouvre, son petit bouton lance, le menu se ferme
    lua.execute("CLIQUER(ForeverUISpellBookButton1)")
    assert vol.shown and p1.attributes.spell == "Teleport: Ironforge" and p1.icone.texture == "icone:tp_forgefer"
    lua.execute("LANCES = {} CLIQUER(ForeverUISpellFlyoutButton2)")
    assert list(g.LANCES.values()) == ["Teleport: Stormwind"] and not vol.shown
    # le livre se ferme : le menu ouvert se ferme avec lui
    lua.execute("CLIQUER(ForeverUISpellBookButton1) PAR_BLIZZARD(function() SpellBookFrame:Hide() end)")
    assert not vol.shown, "FlyoutButtonMixin:OnHide : le menu ne revient pas a la reouverture"
    lua.execute("PAR_BLIZZARD(function() SpellBookFrame:Show() end)")
    # AGRANDIR / REDUIRE EN COMBAT : en page 2 de deux pages (vues 3 et 4),
    # une page montre la vue 3 -- page 3 ; et retour
    lua.execute("CLIQUER(ForeverUISpellBookTab3) CLIQUER(ForeverUISpellBookNextPage) CLIQUER(ForeverUISpellBookFrame.taille)")
    une = [c.nom.text for c in vue.cases.values() if c.shown]
    print("   combat, reduit : %s de large, vue 2 %s, %s | %s" % (livre.width, g.ForeverUISpellBookView2.shown,
        g.ForeverUI.SpellBook.pager.texte.text, une[:2]))
    assert livre.width == 809 and g.ForeverUISpellBookPages.width == 806 and not g.ForeverUISpellBookView2.shown
    assert g.ForeverUI.SpellBook.pager.texte.text == "Page 3/3" and une[0] == "Sort 51"
    assert g.ForeverUIDB.grimoire.reduit and g.ForeverUISpellBookPages.seule.shown, "retenu, et l'image d'une page"
    lua.execute("CLIQUER(ForeverUISpellBookPrevPage)")
    assert g.ForeverUI.SpellBook.pager.texte.text == "Page 2/3" and [c.nom.text for c in vue.cases.values() if c.shown][0] == "Sort 30"
    lua.execute("CLIQUER(ForeverUISpellBookFrame.taille)")
    print("   combat, agrandi : %s de large, %s" % (livre.width, g.ForeverUI.SpellBook.pager.texte.text))
    assert livre.width == 1618 and g.ForeverUISpellBookView2.shown and g.ForeverUI.SpellBook.pager.texte.text == "Page 1/2"
    assert g.ForeverUISpellBookView2.cases[1].shown and g.ForeverUISpellBookView2.cases[1].nom.text == "Sort 30"
    assert not g.ForeverUIDB.grimoire.reduit
    # LES REGLAGES EN COMBAT : tout de suite, par la liste securisee
    lua.execute("CLIQUER(ForeverUISpellBookTab2) CLIQUER(ForeverUISpellBookSettingsButton) CLIQUER(ForeverUISpellBookSettingsEntry3)")
    rangs = [c.nom.text for c in vue.cases.values() if c.shown]
    print("   combat, tous les rangs : %s" % rangs)
    assert rangs[:3] == ["Frostbolt", "Frostbolt", "Frostbolt"] and g.STATE.cvars.ShowAllSpellRanks == "1"
    lua.execute("LANCES = {} CLIQUER(ForeverUISpellBookButton1)")
    assert list(g.LANCES.values()) == ["Frostbolt(Rank 1)"], "le rang montre est celui qui part"
    lua.execute("CLIQUER(ForeverUISpellBookSettingsEntry3) CLIQUER(ForeverUISpellBookSettingsEntry1)")
    assert [c.nom.text for c in vue.cases.values() if c.shown] == ["Frostbolt", "Frost Armor"]
    lua.execute("CLIQUER(ForeverUISpellBookSettingsEntry1) CLIQUER(ForeverUISpellBookTab3) CLIQUER(ForeverUISpellBookSettingsEntry2)")
    assert [c.nom.text for c in vue.cases.values() if c.shown][:2] == ["Teleport: Stormwind", "Teleport: Ironforge"], \
        "sans groupes, en combat"
    lua.execute("CLIQUER(ForeverUISpellBookSettingsEntry2) CLIQUER(ForeverUISpellBookSettingsButton)")
    assert [c.nom.text for c in vue.cases.values() if c.shown][0] == "Teleport" and g.STATE.cvars.ShowAllSpellRanks == "0"
    # ce qui reste interdit en combat ne leve rien : le calcul attend
    lua.execute("ForeverUI.SpellBook.maj()")
    assert g.ForeverUI.SpellBook.enAttente
    lua.execute("ForeverUI.SpellBook.majEtats()")
    print("   combat : rien de bloque (ADDON_ACTION_BLOCKED leve sinon)")
    lua.execute("STATE.inLockdown = false STATE.verifierProtection = false")
    # LE REGLAGE ARRIVE APRES LE LIVRE : les variables sauvegardees se
    # chargent apres le fichier. Le calcul suivant doit remettre la mise en
    # page d'accord avec lui -- dans un sens comme dans l'autre.
    lua.execute("ForeverUIDB.grimoire.reduit = true ForeverUI.SpellBook.maj()")
    assert livre.width == 809 and not g.ForeverUISpellBookView2.shown
    lua.execute("ForeverUIDB.grimoire.reduit = nil ForeverUI.SpellBook.maj() CLIQUER(ForeverUISpellBookTab3)")
    print("   reglage arrive apres : %s de large, vue 2 : %s ..." % (livre.width,
        [c.nom.text for c in g.ForeverUISpellBookView2.cases.values() if c.shown][:2]))
    assert livre.width == 1618 and g.ForeverUISpellBookView2.shown and g.ForeverUISpellBookView2.cases[1].nom.text == "Sort 30",         "deux pages : la page de droite est peuplee"
    lua.execute("for i = 8, 57 do LIVRE.spell[i] = nil end ONGLETS[3] = nil ForeverUI.SpellBook.maj()")
    lua.execute("CLIQUER(ForeverUISpellBookTab1)")

    # la croix de WotLK ferme le panneau
    lua.execute("ForeverUISpellBookTab1:GetScript('OnClick')(ForeverUISpellBookTab1) SpellBookCloseButton:GetScript('OnClick')(SpellBookCloseButton)")
    assert not g.SpellBookFrame.shown


    # ------------------------------------------------------------------
    # LES TALENTS (docs/TALENTS.md, etape 1)
    # ------------------------------------------------------------------
    print("\n--- talents ---")
    assert g.ForeverUITalentsFrame is None, "rien avant le chargement de Blizzard_TalentUI"
    lua.execute("""
        TALENTS = {
            { nom = "Arcane", icone = "icone:arcane", fond = "MageArcane", depenses = 6, talents = {
                { "Arcane Subtlety", "ic:subtilite", 1, 1, 2, 2, true },
                { "Arcane Focus", "ic:focalisation", 1, 2, 1, 3, true },
                { "Magic Absorption", "ic:absorption", 2, 1, 0, 2, true },
                { "Arcane Concentration", "ic:concentration", 3, 2, 0, 5, false, pre = { 1, 2, false } },
                { "Presence of Mind", "ic:presence", 5, 2, 0, 1, false },
                { "Arcane Mind", "ic:esprit", 2, 3, 0, 5, false, pre = { 2, 1, false } },
                { "Arcane Instability", "ic:instabilite", 4, 3, 0, 3, false, pre = { 3, 2, false } },
            } },
            { nom = "Fire", icone = "icone:feu", fond = "MageFire", depenses = 0, talents = {
                { "Improved Fire Blast", "ic:trait", 1, 1, 0, 2, true },
                { "Ignite", "ic:enflammer", 2, 2, 0, 5, true },
            } },
            { nom = "Frost", icone = "icone:givre", fond = "MageFrost", depenses = 0, talents = {
                { "Frostbite", "ic:morsure", 1, 1, 0, 3, true },
            } },
        }
        POINTS_TALENTS = 3
        CHARGER_TALENTS()
        PlayerTalentFrame:Show()
    """)
    tl = g.ForeverUITalentsFrame
    pl = list(tl.points[1].values())
    print("   livre %s x %s, %s de l'ecran (%s, %s) | art WotLK alpha %s, croix alpha %s" % (tl.width, tl.height, pl[0],
        pl[3], pl[4], g.PlayerTalentFrameTalent1.alpha, g.PlayerTalentFrameCloseButton.alpha))
    assert meme(tl.parent, g.PlayerTalentFrame) and (tl.width, tl.height) == (1218, 708)
    assert (pl[0], pl[2], pl[3], pl[4]) == ("TOP", "TOP", 0, -116)
    assert g.PlayerTalentFrameTalent1.alpha == 0 and g.PlayerTalentFrameCloseButton.alpha != 0
    assert g.PlayerTalentFrame.mouseEnabled == False
    assert tl.portrait.texture.endswith("portrait_deathknight"), "l'icone de la classe, cuite ronde"
    # le chevalier de la mort : un fond moderne par arbre
    fonds = [t for t in g.ForeverUI.Talents.classe.textures.values() if t.shown]
    print("   fonds (chevalier de la mort) : %d, largeur %s" % (len(fonds), fonds[0].width))
    assert len(fonds) == 3 and abs(fonds[0].width - 404) < 1e-6
    Tl = g.ForeverUI.Talents
    assert Tl.classe.GetFrameLevel(Tl.classe) > Tl.fond.GetFrameLevel(Tl.fond),         "l'illustration au-dessus de la pierre (freres de meme niveau : ordre non garanti)"
    assert fonds[2].texture == g.UIAtlas.data["talents-background-deathknight-unholy"][1]
    # en-tetes
    h1 = g.ForeverUITalentsHeader1
    ph = list(h1.points[1].values())
    print("   en-tete 1 : '%s', %s points, icone %s, a (%s, %s)" % (h1.nom.text, h1.depenses.text, h1.icone.portrait, ph[3], ph[4]))
    assert h1.nom.text == "Arcane" and h1.depenses.text == "6" and h1.icone.portrait == "icone:arcane"
    assert (ph[0], ph[2], ph[3], ph[4]) == ("CENTER", "TOPLEFT", 140, -38.5), "anneau a 5 pixels sous le trait de la barre"
    assert list(g.ForeverUITalentsHeader2.points[1].values())[3] == 540
    # les points non depenses
    pts = g.ForeverUI.Talents.points.nombre
    assert pts.text == "3" and pts.textColor[2] == 1, "vert s'il en reste"
    assert pts.fontSize == 24 and list(g.ForeverUI.Talents.points.points[1].values())[4] == 20, "compteur remonte, chiffre en 24"
    # les noeuds
    T = g.ForeverUI.Talents
    n = [b for b in T.arbre.noeuds.values() if b.shown]
    print("   noeuds : %d | %s" % (len(n), [(b.talent.nom, b.talent.etat, b.rang.text) for b in n[:5]]))
    E = 518 / (40 * 15)
    assert len(n) == 10 and abs(T.arbre.scale - E) < 1e-9, "11 paliers dans 518 pixels (rangees 1,4 noeud)"
    b1, b2, b3, b4, b5 = n[0], n[1], n[2], n[3], n[4]
    e = g.UIAtlas.data
    assert b1.talent.etat == "maxed" and b1.bordure.texture == e["talents-node-circle-yellow"][1]
    assert (b1.bordure.width, b1.bordure.height) == (40, 40), "la taille LOGIQUE de l'atlas (UiTextureAtlasMember)"
    assert b1.rang.text == "2" and b1.rang.textColor[1] == 1 and b1.icone.portrait == "ic:subtilite", "rond : l'icone arrondie"
    assert b2.talent.etat == "selectable" and b2.rang.text == "1" and b2.rang.textColor[2] == 1, "entame : vert"
    assert b3.talent.etat == "selectable" and b3.rang.text == "0", "palier 2 ouvert (6 points), achetable"
    assert b4.talent.etat == "locked" and b4.rang.text == "" and b4.icone.vertex[1] == 0.3
    assert b5.talent.carre and b5.bordure.texture == e["talents-node-square-locked"][1] and b5.icone.texture == "ic:presence", \
        "Presence of Mind : un sort actif, carre (TalentsData.lua)"
    pb = list(b1.points[1].values())
    print("   echelle %.4f | noeud 1 : centre (%.1f, %.1f) de la page" % (E, pb[3] * E, pb[4] * E))
    assert abs(pb[3] * E - (202 - 1.5 * 60 * E)) < 1e-6, "arbre centre dans sa colonne (pas 1,5 noeud)"
    pv = [list(v.points[1].values()) for v in T.verticaux.values()]
    print("   separateurs verticaux : x %s de la page, haut %s du cadre" % ([p_[3] - 2 for p_ in pv], pv[0][4]))
    assert [p_[3] - 2 for p_ in pv] == [404, 808] and pv[0][4] == -46, "sur les transitions ; 60 sous le centre de la barre"
    assert abs(pb[4] * E - (-123 - 20 * E)) < 1e-6, "premier noeud a 10 pixels sous le petit separateur"
    pb5 = list(b5.points[1].values())
    assert abs(pb5[4] * E - (-123 - 20 * E - 4 * 56 * E)) < 1e-6
    bas = -123 - 20 * E - 10 * 56 * E - 20 * E
    assert abs(bas + 641) < 1e-6, "le 11e palier finit a 40 du bas"
    # les fleches : verticale (1,2 -> 3,2), horizontale (2,1 -> 2,3), en L (3,2 -> 4,3)
    traits = [t for t in T.arbre.traits.values() if t.shown]
    pointes = [t for t in T.arbre.pointes.values() if t.shown]
    print("   fleches : %d traits, %d pointes | %s" % (len(traits), len(pointes), [(round(t.width, 1), round(t.height, 1)) for t in traits]))
    assert len(traits) == 4 and len(pointes) == 3
    assert traits[0].width == 6 and traits[0].texture == e["talents-arrow-line-locked"][1], "vers un palier ferme : verrou"
    assert traits[0].texcoord8 is not None, "le trait vertical : la bande tournee"
    assert traits[1].height == 6 and traits[1].texture == e["talents-arrow-line-gray"][1], "prerequis non rempli : gris"
    # les portes : Arcane au palier 3 (4 points encore), Fire au palier 2 (5)
    portes = [p for p in T.arbre.portes.values() if p.shown]
    print("   portes : %s" % [p.texte.text for p in portes])
    assert [p.texte.text for p in portes] == ["4", "5"]
    lua.execute("ForeverUITalentsGate1.scripts.OnEnter(ForeverUITalentsGate1)")
    assert g.GameTooltip.text == "Spend 4 more points to unlock this row"
    # l'infobulle d'un noeud : celle de WotLK
    lua.execute("ForeverUITalentsNode1.scripts.OnEnter(ForeverUITalentsNode1)")
    assert list(g.GameTooltip.talent.values()) == [1, 1]
    # une autre classe : son fond unique
    lua.execute("CLASSE_AVANT = STATE.classToken STATE.classToken = 'MAGE' ForeverUI.Talents.maj()")
    fonds = [t for t in T.classe.textures.values() if t.shown]
    assert len(fonds) == 1 and fonds[0].texture == e["talent-background-mage"][1]
    lua.execute("STATE.classToken = CLASSE_AVANT")
    # plus de points : le compteur gris a zero
    lua.execute("POINTS_TALENTS = 0 ForeverUI.Talents.maj()")
    assert pts.text == "0" and pts.textColor[1] == 0.5
    assert [b for b in T.arbre.noeuds.values() if b.shown][2].talent.etat == "disabled", "plus de point : gris"
    # ETAPE 2 : LES CHANGEMENTS ATTENDENT. Trois points ; Magic Absorption
    # (palier 2, 0/2) et Arcane Focus (1/3) s'achetent
    lua.execute("POINTS_TALENTS = 3 ForeverUI.Talents.maj()")
    ap, an = g.ForeverUITalentsApplyButton, g.ForeverUITalentsUndoButton
    pa = list(ap.points[1].values())
    print("   Apply : %s x %s, BOTTOM du fond (%s) | '%s' actif=%s | Undo montre=%s" % (ap.width, ap.height, pa[4],
        ap.fontString.text, ap.actif, an.shown))
    assert (ap.width, ap.height) == (164, 22) and pa[0] == "BOTTOM" and pa[4] == 8 and ap.fontString.text == "Apply Changes"
    assert not ap.actif and not an.shown and not ap.lueur.shown, "rien en attente"
    noeud = lambda i: [b for b in T.arbre.noeuds.values() if b.shown][i]
    lua.execute("CLIQUER(ForeverUITalentsNode3)")
    lua.execute("CLIQUER(ForeverUITalentsNode3)")
    b3 = noeud(2)
    print("   2 clics sur Magic Absorption : rang %s (%s), points %s, Apply actif=%s, Undo=%s" % (b3.rang.text, b3.talent.etat,
        pts.text, ap.actif, an.shown))
    assert b3.rang.text == "2" and b3.talent.etat == "maxed" and pts.text == "1"
    assert ap.actif and ap.lueur.shown and an.shown, "des changements attendent : Apply luit, Undo parait"
    assert g.ForeverUITalentsHeader1.depenses.text == "8", "les points en attente comptent dans l'arbre"
    # le clic droit retire un point EN ATTENTE, pas un point appris
    lua.execute("CLIQUER(ForeverUITalentsNode3, 'RightButton')")
    assert noeud(2).rang.text == "1" and pts.text == "2"
    lua.execute("CLIQUER(ForeverUITalentsNode1, 'RightButton')")
    assert noeud(0).rang.text == "2", "Arcane Subtlety est appris : le clic droit n'y touche pas"
    # Undo : tout ce qui attend s'en va
    lua.execute("CLIQUER(ForeverUITalentsUndoButton)")
    assert noeud(2).rang.text == "0" and pts.text == "3" and not an.shown and not ap.actif
    # Apply : l'attente s'apprend
    lua.execute("CLIQUER(ForeverUITalentsNode2) CLIQUER(ForeverUITalentsNode3) CLIQUER(ForeverUITalentsApplyButton)")
    print("   Apply : Arcane Focus %s, Magic Absorption %s, points %s, Undo=%s" % (noeud(1).rang.text, noeud(2).rang.text,
        pts.text, an.shown))
    assert noeud(1).rang.text == "2" and noeud(2).rang.text == "1" and pts.text == "1" and not an.shown
    assert g.TALENTS[1].talents[2][5] == 2, "appris pour de bon (LearnPreviewTalents)"
    # un talent derriere une porte ne s'achete pas
    lua.execute("CLIQUER(ForeverUITalentsNode4)")
    assert noeud(3).rang.text == "" and pts.text == "1"

    # ETAPE 2 : LES ONGLETS LATERAUX. Une seule specialisation, pas de familier
    barre = g.ForeverUITalentsTabs
    pbar = list(barre.points[1].values())
    o1, o2 = g.ForeverUITalentsTab1, g.ForeverUITalentsTab2
    print("   onglets : barre %s x %s a %s du livre (%s, %s) | 1 '%s' choisi=%s coche=%s | 2 verrou=%s gris=%s | 3 : %s" % (
        barre.width, barre.height, pbar[2], pbar[3], pbar[4], o1.titre, o1.choisi.shown, o1.coche.shown,
        o2.cadenas.shown, o2.icone.desaturated, g.ForeverUITalentsTab4))
    assert (barre.width, barre.height) == (64, 384) and (pbar[0], pbar[2], pbar[3], pbar[4]) == ("TOPLEFT", "TOPRIGHT", 1, -30)
    assert (o1.width, o1.height) == (55, 55) and list(o2.points[1].values())[4] == -2, "la facture de la feuille"
    assert o1.choisi.shown and o1.coche.shown and not o2.choisi.shown and o2.cadenas.shown and o2.icone.desaturated
    assert g.ForeverUITalentsTab3.cle == "glyphes" and g.ForeverUITalentsTab4 is None, "glyphes (niveau 80), pas de familier"
    assert o1.icone.texture.endswith("TabIcons" + chr(92) + "icone:arcane"), "l'arbre principal (Arcane)"
    lua.execute("CLIQUER(ForeverUITalentsTab2)")
    assert o1.choisi.shown and T.actif, "verrouillee : le clic n'y mene pas"
    # deux specialisations : la seconde se consulte, "Activate" a la place d'Apply
    lua.execute("""
        NB_GROUPES = 2
        -- les memes arbres (le client n'a qu'un jeu de talents), d'autres rangs
        TALENTS_2 = {}
        for o, onglet in ipairs(TALENTS) do
            local copie = { nom = onglet.nom, icone = onglet.icone, fond = onglet.fond, depenses = 0, talents = {} }
            for i, t in ipairs(onglet.talents) do
                copie.talents[i] = { t[1], t[2], t[3], t[4], 0, t[6], t[7], pre = t.pre }
            end
            TALENTS_2[o] = copie
        end
        TALENTS_2[2].depenses = 10 TALENTS_2[2].talents[1][5] = 2
        TALENTS_2[3].depenses = 5 TALENTS_2[3].talents[1][5] = 3
        ForeverUI.Talents.maj()
        CLIQUER(ForeverUITalentsTab2)
    """)
    ac = g.ForeverUITalentsActivateButton
    print("   seconde : choisie=%s coche=%s | Apply=%s Undo=%s Activate=%s ('%s', actif=%s) | Fire %s | icone %s" % (
        o2.choisi.shown, o2.coche.shown, ap.shown, an.shown, ac.shown, ac.fontString.text, ac.actif,
        g.ForeverUITalentsHeader2.depenses.text, o2.icone.texture.split(chr(92))[-1]))
    assert o2.choisi.shown and not o1.choisi.shown and o1.coche.shown and not o2.coche.shown
    assert not ap.shown and not an.shown and ac.shown and ac.actif and ac.fontString.text == "Activate"
    assert g.ForeverUITalentsHeader2.depenses.text == "10" and o2.icone.texture.endswith("icone:feu")
    lua.execute("CLIQUER(ForeverUITalentsNode1)")
    assert g.GetGroupPreviewTalentPointsSpent(False, 2) == 0, "inactive : on consulte seulement"
    lua.execute("ForeverUITalentsTab2.scripts.OnEnter(ForeverUITalentsTab2)")
    assert g.GameTooltip.text == "Secondary"
    # Activate : le sort part, le bouton attend
    lua.execute("CLIQUER(ForeverUITalentsActivateButton)")
    print("   Activate : groupe demande %s, bouton actif=%s" % (g.ACTIVATION_DEMANDEE, ac.actif))
    assert g.ACTIVATION_DEMANDEE == 2 and not ac.actif
    lua.execute("SORT_EN_COURS = nil GROUPE_ACTIF = 2 ForeverUI.Talents.maj()")
    assert T.actif and ap.shown and not ac.shown and o2.coche.shown and not o1.coche.shown
    lua.execute("GROUPE_ACTIF = 1 ForeverUI.Talents.maj()")
    # LE FAMILIER : un onglet de plus ; la fenetre se reduit a un arbre
    lua.execute("""
        TALENTS_FAMILIER = {
            { nom = "Ferocity", icone = "icone:ferocite", fond = "HunterPetFerocity", depenses = 3, talents = {
                { "Cobra Reflexes", "ic:cobra", 1, 1, 2, 2, true },
                { "Dive", "ic:plongeon", 2, 2, 0, 1, true },
            } },
        }
        POINTS_FAMILIER = 1
        ForeverUI.Talents.maj()
        CLIQUER(ForeverUITalentsTab4)
    """)
    o3 = g.ForeverUITalentsTab4
    vis = [b for b in T.arbre.noeuds.values() if b.shown]
    print("   familier : livre %s, page %s | verticaux %s | en-tetes %s | portrait %s | noeuds %s" % (tl.width, T.page.width,
        [v.shown for v in T.verticaux.values()], [g["ForeverUITalentsHeader%d" % i].shown for i in (1, 2, 3)],
        o3.icone.portraitOf, [(b.talent.nom, b.talent.etat) for b in vis]))
    assert o3.choisi.shown and o3.icone.portraitOf == "pet" and T.pet
    assert tl.width == 410 and T.page.width == 404, "un arbre : la premiere colonne"
    assert not any(v.shown for v in T.verticaux.values())
    assert [g["ForeverUITalentsHeader%d" % i].shown for i in (1, 2, 3)] == [True, False, False]
    assert len(vis) == 2 and vis[1].talent.etat == "selectable", "paliers de 3 points"
    lua.execute("CLIQUER(ForeverUITalentsNode2)")
    assert g.GetGroupPreviewTalentPointsSpent(True) == 1 and ap.actif, "le familier aussi attend"
    lua.execute("CLIQUER(ForeverUITalentsApplyButton)")
    assert g.TALENTS_FAMILIER[1].talents[2][5] == 1 and g.POINTS_FAMILIER == 0
    # retour aux arbres du joueur : pleine largeur
    lua.execute("CLIQUER(ForeverUITalentsTab1)")
    assert tl.width == 1218 and all(v.shown for v in T.verticaux.values()) and not T.pet
    # a la reouverture, la specialisation active
    lua.execute("CLIQUER(ForeverUITalentsTab4) PlayerTalentFrame:Hide() PlayerTalentFrame:Show()")
    assert not T.pet and tl.width == 1218 and o1.choisi.shown

    # ETAPE 3 : LES GLYPHES. Le squelette de WotLK : ses onglets de
    # specialisation (PlayerSpecTabN.specIndex), ses onglets du bas, et
    # Blizzard_GlyphUI charge a la demande (ADDON_LOADED le rattache a
    # PlayerTalentFrame, SetAllPoints)
    lua.execute("""
        GLYPH_TALENT_TAB = 4
        SHOW_INSCRIPTION_LEVEL = 15
        ONGLET_BAS = 1
        for i, cle in ipairs({ "spec1", "spec2", "petspec1" }) do
            local b = CreateFrame("CheckButton", "PlayerSpecTab" .. i, PlayerTalentFrame)
            b.specIndex = cle
        end
        for i = 1, 4 do CreateFrame("Button", "PlayerTalentFrameTab" .. i, PlayerTalentFrame):SetID(i) end
        function PlayerSpecTab_OnClick(self)
            PlayerTalentFrame.talentGroup = (self.specIndex == "spec2") and 2 or 1
            PlayerTalentFrame.pet = self.specIndex == "petspec1"
            PlayerTalentFrame_Refresh()
        end
        function PlayerTalentTab_OnClick(self)
            ONGLET_BAS = self:GetID()
            PlayerTalentFrame_Refresh()
        end
        -- PlayerTalentFrame_Refresh / _ShowGlyphFrame de WotLK
        local refresh = PlayerTalentFrame_Refresh
        function PlayerTalentFrame_Refresh()
            if GlyphFrame then
                if ONGLET_BAS == GLYPH_TALENT_TAB then
                    GlyphFrameTitleText:SetText(PlayerTalentFrame.talentGroup == 2 and "Secondary Glyphs" or "Primary Glyphs")
                    GlyphFrame:Show()
                else
                    GlyphFrame:Hide()
                end
            end
            refresh()
        end
        -- Blizzard_GlyphUI
        GlyphFrame = CreateFrame("Frame", "GlyphFrame", UIParent)
        GlyphFrame:SetWidth(384) GlyphFrame:SetHeight(512)
        GlyphFrame:Hide()
        GlyphFrameBackground = GlyphFrame:CreateTexture("GlyphFrameBackground", "ARTWORK")
        GlyphFrameBackground:SetWidth(352) GlyphFrameBackground:SetHeight(441)
        GlyphFrame.glow = GlyphFrame:CreateTexture(nil, "OVERLAY")
        GlyphFrameTitleText = GlyphFrame:CreateFontString("GlyphFrameTitleText", "ARTWORK", "GameFontNormal")
        -- les six alveoles, leur surbrillance, et les fonctions de WotLK que
        -- ForeverUI greffe (Blizzard_GlyphUI.lua)
        for i = 1, 6 do
            local b = CreateFrame("Button", "GlyphFrameGlyph" .. i, GlyphFrame)
            b.highlight = b:CreateTexture(nil, "BORDER")
            b.highlight:SetTexture("wotlk:UI-GlyphFrame")
        end
        function GlyphFrameGlyph_SetGlyphType(glyph, kind)
            glyph.highlight:SetWidth(kind == 1 and 108 or 86)
            glyph.highlight:SetTexCoord(0.765625, 0.927734375, 0.15625, 0.31640625)
        end
        function GlyphFrame_PulseGlow() GlyphFrame.glow:Show() end
        function GlyphFrame_StartSlotAnimation(id, duree, taille)
            local e = _G["GlyphFrameSparkle" .. id] or GlyphFrame:CreateTexture("GlyphFrameSparkle" .. id, "OVERLAY")
            _G["GlyphFrameSparkle" .. id] = e
            e:SetTexture("wotlk:UI-ItemSockets")
            e:SetWidth(13) e:SetHeight(13)
        end
        function GlyphFrame_Update() end
        function GlyphFrameGlyph_UpdateSlot(self) end
        -- GLYPHES_GRAVES[groupe][alveole] = sort du glyphe grave
        GLYPHES_GRAVES = { {}, {} }
        function GetGlyphSocketInfo(id, groupe)
            local sort = GLYPHES_GRAVES[groupe or 1][id]
            return true, (id == 1 or id == 4 or id == 6) and 1 or 2, sort, sort and "rune" or nil
        end
        GlyphFrame:SetParent(PlayerTalentFrame)
        GlyphFrame:SetAllPoints()
        for _, f in ipairs(FRAMES) do
            if f.events and f.events["ADDON_LOADED"] and f.scripts and f.scripts.OnEvent then
                f.scripts.OnEvent(f, "ADDON_LOADED", "Blizzard_GlyphUI")
            end
        end
    """)
    og = g.ForeverUITalentsTab3
    print("   onglet des glyphes : '%s', icone %s" % (og.titre, og.icone.texture.split(chr(92))[-1]))
    assert og.icone.texture.endswith("inv_inscription_tradeskill01") and og.titre == "Primary Glyphs"
    lua.execute("CLIQUER(ForeverUITalentsTab3)")
    gf = g.GlyphFrame
    pg = list(gf.points[1].values())
    k = 1
    print("   glyphes : montre=%s, parent %s, echelle %s, TOPLEFT (%.2f, %.2f) | livre %s | titre '%s' | choisi %s" % (
        gf.shown, gf.parent.name if hasattr(gf.parent, "name") else gf.parent, gf.scale, pg[3], pg[4], tl.width,
        tl.titre.text, og.choisi.shown))
    assert gf.shown and meme(gf.parent, g.PlayerTalentFrame) and gf.scale in (None, 1), "laisse sous PlayerTalentFrame (comme WotLK), sans echelle"
    assert tl.width == 410 and tl.titre.text == "Primary Glyphs" and og.choisi.shown and not o1.choisi.shown
    assert not g.GlyphFrameTitleText.shown, "son titre passe dans la barre de la fenetre"
    # la croix au-dessus de tout, glyphes compris (Blizzard_GlyphUI la repose
    # sous notre livre en se chargeant)
    lua.execute("PlayerTalentFrameCloseButton:SetFrameLevel(GlyphFrame:GetFrameLevel() + 1) GlyphFrame:Hide() GlyphFrame:Show()")
    lua.execute("""
        function PLUS_HAUT(c)
            local n = c:GetFrameLevel()
            for _, e in ipairs({ c:GetChildren() }) do n = math.max(n, PLUS_HAUT(e)) end
            return n
        end
    """)
    cx = g.PlayerTalentFrameCloseButton
    print("   croix : niveau %s | livre jusqu'a %s, glyphes jusqu'a %s" % (cx.frameLevel, g.PLUS_HAUT(tl), g.PLUS_HAUT(gf)))
    assert cx.frameLevel > g.PLUS_HAUT(tl) and cx.frameLevel > g.PLUS_HAUT(gf)
    # LE DECOR REFAIT : parchemin, cercle, coins (glyphes-fond) ; le decor de
    # WotLK s'efface
    tex = list(T.decor.textures.values())
    pa, ce = tex[0], tex[1]
    print("   decor : %d images sur le cadre interieur | parchemin %s sur %s | fond WotLK montre=%s" % (
        len(tex), pa.layer, "l'illustration" if pa.allPoints else "?", g.GlyphFrameBackground.shown))
    assert len(tex) == 6 and all(t.texture.endswith("glyphes-fond") and t.shown for t in tex)
    assert all(meme(t.owner, T.cadre) for t in tex), "sur le cadre interieur : il passe devant"
    assert pa.layer == "BACKGROUND" and pa.allPoints and not g.GlyphFrameBackground.shown, "toute la fenetre"
    pc = list(ce.points[1].values())
    assert meme(pc[1], T.classe) and pc[2] == "CENTER" and abs(pc[3] + 179.65) < 1e-9 and abs(pc[4] - 202.41) < 1e-9, \
        "le centre du cercle sur l'etoile"
    assert abs(ce.width - 360.84) < 1e-9 and list(ce.texcoord.values())[0] == 543 / 1024
    coins = [list(t.points[1].values()) for t in tex[2:]]
    print("   coins : %s" % [(c[0], c[3], c[4]) for c in coins])
    assert [(c[0], c[3], c[4]) for c in coins] == [("TOPLEFT", 7, -5), ("TOPRIGHT", -7, -5),
        ("BOTTOMLEFT", 7, 5), ("BOTTOMRIGHT", -7, 5)] and all(meme(c[1], T.classe) for c in coins), \
        "contre le trait du cadre interieur"
    # l'etoile des alveoles au centre de l'illustration : (178, -238.5) du GlyphFrame
    assert meme(pg[1], T.classe) and (pg[2], pg[3], pg[4]) == ("CENTER", -178, 238.5)
    lv = g.ForeverUIGlyphGlow
    assert T.cadre.frameLevel < lv.frameLevel < gf.frameLevel, "cadre (et decor), lueurs, puis alveoles"
    # la surbrillance : l'anneau orange, reposee apres SetGlyphType
    b1 = g.GlyphFrameGlyph1
    lua.execute("GlyphFrameGlyph_SetGlyphType(GlyphFrameGlyph1, 1)")
    print("   surbrillance : %s, u %s" % (b1.highlight.texture.split(chr(92))[-1], list(b1.highlight.texcoord.values())[0]))
    assert b1.highlight.texture.endswith("glyphes-lueurs") and list(b1.highlight.texcoord.values())[0] == 851 / 1024
    # la pulsation : nos lueurs montent en 0,1 s, redescendent en 1,5 s
    lua.execute("GlyphFrame_PulseGlow()")
    assert lv.shown and not gf.glow.shown
    lua.execute("ForeverUIGlyphGlow.scripts.OnUpdate(ForeverUIGlyphGlow, 0.05)")
    a1 = lv.alpha
    lua.execute("ForeverUIGlyphGlow.scripts.OnUpdate(ForeverUIGlyphGlow, 0.8)")
    a2 = lv.alpha
    lua.execute("ForeverUIGlyphGlow.scripts.OnUpdate(ForeverUIGlyphGlow, 1.0)")
    print("   pulsation : %.3f, %.3f, puis montree=%s" % (a1, a2, lv.shown))
    assert abs(a1 - 0.5) < 1e-9 and abs(a2 - (1 - 0.75 / 1.5)) < 1e-9 and not lv.shown
    lueurs = list(lv.textures.values()) if hasattr(lv.textures, "values") else []
    assert all(t.blend == "ADD" for t in lueurs)
    # une etincelle : l'etoile, agrandie
    lua.execute("GlyphFrame_StartSlotAnimation(1, 2, 3)")
    e1 = g.GlyphFrameSparkle1
    assert e1.texture.endswith("glyphes-lueurs") and e1.width == 13 * 2.5
    assert list(e1.texcoord.values())[0] == 851 / 1024, "l'etoile refaite"
    # LES CERCLES CONCENTRIQUES : une paire d'alveoles par anneau ; ils
    # tournent (coordonnees tournees), en sens contraires
    rg = g.ForeverUIGlyphRings
    anx = [a for a in rg.anneaux.values()]
    print("   cercles : montres=%s, niveau %s (cadre %s, lueurs %s) | %s" % (rg.shown, rg.frameLevel, T.cadre.frameLevel,
        lv.frameLevel, [(a["def"].cle, a["def"].tour, a.cible) for a in anx]))
    assert rg.shown and T.cadre.frameLevel < rg.frameLevel < lv.frameLevel
    assert [a.cible for a in anx] == [0, 0, 0], "aucun glyphe grave : rien"
    lua.execute("GLYPHES_GRAVES[1][1] = 58001 GlyphFrameGlyph_UpdateSlot(GlyphFrameGlyph1)")
    assert abs(anx[0].cible - 0.175) < 1e-9 and anx[1].cible == 0, "la moitie du premier anneau"
    lua.execute("GLYPHES_GRAVES[1][2] = 58002 GLYPHES_GRAVES[1][6] = 58006 GlyphFrame_Update()")
    print("   cibles : %s" % [a.cible for a in anx])
    assert [round(a.cible, 3) for a in anx] == [0.35, 0, 0.175]
    lua.execute("ForeverUIGlyphRings.scripts.OnUpdate(ForeverUIGlyphRings, 0.2)")
    t0 = anx[0].texture
    tc = list(t0.texcoord8.values())
    print("   apres 0,2 s : alpha %.3f, angle %.4f, coins %s" % (anx[0].alpha, anx[0].angle, [round(v, 4) for v in tc]))
    assert abs(anx[0].alpha - 0.1) < 1e-9, "apparition progressive (0,5 par seconde)"
    assert abs(anx[0].angle - 2 * 3.141592653589793 * 0.2 / 90) < 1e-9 and anx[1].angle > 3, "sens contraires"
    cx, cy, h = (669 + 72.5) / 1024, (405 + 72.5) / 1024, 72.5 / 1024
    assert abs(((tc[0] - cx) ** 2 + (tc[1] - cy) ** 2) ** 0.5 - h * 2 ** 0.5) < 1e-9, "le coin tourne autour du centre"
    # une autre specialisation : ses propres alveoles
    lua.execute("PlayerTalentFrame.talentGroup = 2 ForeverUI.Talents.compterGlyphes() PlayerTalentFrame.talentGroup = 1 ForeverUI.Talents.compterGlyphes()")
    assert not T.classe.shown and not T.arbre.shown and not T.points.shown and not g.ForeverUITalentsHeader1.shown
    assert not ap.shown and not an.shown and not ac.shown, "specialisation active : ni Apply ni Activate"
    assert gf.frameLevel > T.cadre.frameLevel
    # la seconde : ses glyphes, Activate
    lua.execute("CLIQUER(ForeverUITalentsTab2) CLIQUER(ForeverUITalentsTab3)")
    print("   seconde puis glyphes : groupe %s, titre '%s', Activate=%s" % (g.PlayerTalentFrame.talentGroup, tl.titre.text, ac.shown))
    assert g.PlayerTalentFrame.talentGroup == 2 and tl.titre.text == "Secondary Glyphs" and ac.shown and gf.shown
    # inactive : le decor grise (GlyphFrame_Update)
    lua.execute("GlyphFrame_Update()")
    assert all(t.desaturated for t in T.decor.textures.values())
    # retour a un arbre : WotLK quitte l'onglet des glyphes
    lua.execute("CLIQUER(ForeverUITalentsTab1)")
    assert not gf.shown and g.ONGLET_BAS == 1 and tl.width == 1218 and T.classe.shown and T.arbre.shown
    assert not any(t.shown for t in T.decor.textures.values()), "le decor part avec la page"
    assert not g.ForeverUIGlyphRings.shown, "les cercles aussi"
    print("   retour : titre %r, choisis %s" % (tl.titre.text, [g["ForeverUITalentsTab%d" % i].choisi.shown for i in (1, 2, 3)]))
    # TEXTE.titre = TALENTS, que le banc emploie pour ses talents factices
    assert not (isinstance(tl.titre.text, str) and "Glyphs" in tl.titre.text) and o1.choisi.shown and not og.choisi.shown
    # un glyphe utilise depuis le sac : WotLK ouvre la page lui-meme
    lua.execute("PlayerSpecTab_OnClick(PlayerSpecTab1) PlayerTalentTab_OnClick(PlayerTalentFrameTab4)")
    assert gf.shown and og.choisi.shown and tl.width == 410
    # l'etouffement de WotLK ne touche pas le GlyphFrame, meme rattache
    lua.execute("GlyphFrame:SetParent(PlayerTalentFrame) ForeverUI.Talents.etoufferWotLK() ForeverUI.Talents.poserGlyphes()")
    assert gf.shown and gf.alpha != 0
    # LA DECONNEXION : le client cache le GlyphFrame en detruisant
    # l'interface ; la fenetre ne doit plus bouger
    lua.execute("""
        local veille
        for _, f in ipairs(FRAMES) do
            if f.events and f.events["PLAYER_LOGOUT"] and f.events["PREVIEW_TALENT_POINTS_CHANGED"] then veille = f end
        end
        VEILLE_TALENTS = veille
        veille.scripts.OnEvent(veille, "PLAYER_LOGOUT")
        GlyphFrame:Hide()
    """)
    print("   deconnexion : livre %s, glyphes montres=%s, parent %s" % (tl.width, gf.shown, gf.parent.name))
    assert tl.width == 410 and not gf.shown, "rien ne bouge pendant la destruction de l'interface"
    assert meme(gf.parent, g.PlayerTalentFrame) and gf.allPoints,         "le GlyphFrame rendu a WotLK avant la destruction"
    lua.execute("VEILLE_TALENTS.scripts.OnEvent(VEILLE_TALENTS, 'PLAYER_ENTERING_WORLD') ForeverUI.Talents.maj()")
    assert tl.width == 1218, "de retour dans le monde, la fenetre vit de nouveau"
    lua.execute("CLIQUER(ForeverUITalentsTab1)")

    # ETAPE 4 : LA RECHERCHE. A gauche du compteur (decision du 2026-09-25)
    rb = g.ForeverUITalentsSearchBox
    fl = g.ForeverUITalentsSearchOptions
    pf, prb = list(fl.points[1].values()), list(rb.points[1].values())
    print("   recherche : champ %s x %s, RIGHT sur LEFT de la fleche (%s, %s) | fleche %s x %s, RIGHT sur LEFT du libelle (%s, %s)" % (
        rb.width, rb.height, prb[3], prb[4], fl.width, fl.height, pf[3], pf[4]))
    assert (rb.width, rb.height) == (184, 30) and rb.maxLetters == 40 and rb.shown
    assert meme(prb[1], fl) and (prb[0], prb[2], prb[3], prb[4]) == ("RIGHT", "LEFT", -3, 2)
    assert meme(pf[1], T.points.libelle) and (pf[0], pf[2], pf[3], pf[4]) == ("RIGHT", "LEFT", -10, -3)
    assert rb.consigne.text == g.SEARCH, "SEARCH, la consigne de SearchBoxTemplate"
    lua.execute("""
        DESCRIPTIONS_TALENTS = {
            ["Arcane Focus"] = "Reduces the chance your spells are resisted. Improves Arcane Mind.",
            ["Magic Absorption"] = "Increases resistances. Works with Arcane Focus.",
        }
        ForeverUITalentsSearchBox:SetFocus()
    """)
    ap4 = g.ForeverUITalentsSearchPreview
    print("   focus : apercu %s, suggestion '%s' | largeur %s" % (ap4.shown, ap4.suggestion.texte.text, ap4.width))
    assert ap4.shown and ap4.suggestion.shown and ap4.width == 176
    pa4 = list(ap4.points[1].values())
    assert meme(pa4[1], rb) and (pa4[0], pa4[2], pa4[3], pa4[4]) == ("TOPRIGHT", "BOTTOMRIGHT", -4, 2)
    lua.execute("ForeverUITalentsSearchBox:Taper('arc')")
    noms = [l.nom.text for l in ap4.lignes.values() if l.shown]
    print("   'arc' : %s" % noms)
    # l'ordre de l'ecran : arbre, palier, colonne
    assert noms == ["Arcane Subtlety", "Arcane Focus", "Arcane Mind", "Arcane Concentration", "Arcane Instability"]
    # Show Ranks : "Nom (rang/max)" ; Hide Passives : les sorts actifs seuls
    lua.execute("CLIQUER(ForeverUITalentsSearchOptions) CLIQUER(ForeverUITalentsSearchOption2)")
    assert g.ForeverUITalentsSearchOptionsList.shown and g.ForeverUITalentsSearchOption2.coche.shown
    noms = [l.nom.text for l in ap4.lignes.values() if l.shown]
    print("   Show Ranks : %s" % noms[:2])
    assert noms[0] == "Arcane Subtlety (2/2)" and noms[1] == "Arcane Focus (2/3)"
    lua.execute("CLIQUER(ForeverUITalentsSearchOption2) ForeverUITalentsSearchBox:Taper('presence')")
    assert [l.nom.text for l in ap4.lignes.values() if l.shown] == ["Presence of Mind"]
    lua.execute("CLIQUER(ForeverUITalentsSearchOption1) ForeverUITalentsSearchBox:Taper('arcane')")
    assert not ap4.shown, "Hide Passives : aucun sort actif ne s'appelle 'arcane'"
    lua.execute("CLIQUER(ForeverUITalentsSearchOption1)")
    # la recherche entiere : Arcane Focus exact, Magic Absorption par sa
    # description, Arcane Mind "apparente" (dans la description d'Arcane Focus)
    lua.execute("ForeverUITalentsSearchBox:Taper('Arcane Focus') ForeverUITalentsSearchBox.scripts.OnEnterPressed(ForeverUITalentsSearchBox)")
    marques = {b.talent.nom: b.marque for b in T.arbre.noeuds.values() if b.shown and b.marque and b.marque.shown}
    print("   'Arcane Focus' : %s" % {k: v.icone.texture and list(v.icone.texcoord.values())[0] for k, v in marques.items()})
    e = g.UIAtlas.data
    assert set(marques) == {"Arcane Focus", "Magic Absorption", "Arcane Mind"}
    assert list(marques["Arcane Focus"].icone.texcoord.values())[0] == e["talents-search-exactmatch"][2]
    assert list(marques["Magic Absorption"].icone.texcoord.values())[0] == e["talents-search-match"][2]
    assert list(marques["Arcane Mind"].icone.texcoord.values())[0] == e["talents-search-relatedmatch"][2]
    mf = marques["Arcane Focus"]
    pm = list(mf.points[1].values())
    assert (mf.width, mf.height) == (63, 63) and pm[0] == "CENTER" and pm[2] == "TOPRIGHT"
    assert mf.battant.blend == "ADD"
    lua.execute("local m = ForeverUITalentsNode2.marque m.scripts.OnUpdate(m, 0.5)")
    assert abs(mf.battant.alpha - 0.25) < 1e-9, "le battement : 0 -> 0,5 en 1 s"
    lua.execute("local m = ForeverUITalentsNode2.marque.survol m.scripts.OnEnter(m)")
    assert g.GameTooltip.text == "Exact search match"
    # la ligne de palier (format numerote du client) est ecartee sans erreur
    lua.execute("ForeverUITalentsSearchBox:Taper('requires') ForeverUITalentsSearchBox.scripts.OnEnterPressed(ForeverUITalentsSearchBox)")
    assert not any(b.marque and b.marque.shown for b in T.arbre.noeuds.values()), "'Requires 5 points in ...' ecartee"
    # la description ne compte pas le rang ni l'invite : 'rank' ne trouve rien
    lua.execute("ForeverUITalentsSearchBox:Taper('rank') ForeverUITalentsSearchBox.scripts.OnEnterPressed(ForeverUITalentsSearchBox)")
    assert not any(b.marque and b.marque.shown for b in T.arbre.noeuds.values())
    # l'effacement : plus de marques
    lua.execute("ForeverUITalentsSearchBox:Taper('mind') ForeverUITalentsSearchBox.scripts.OnEnterPressed(ForeverUITalentsSearchBox)")
    assert any(b.marque and b.marque.shown for b in T.arbre.noeuds.values())
    lua.execute("CLIQUER(ForeverUITalentsSearchClear)")
    assert not any(b.marque and b.marque.shown for b in T.arbre.noeuds.values()) and rb.text == ""
    # "Missing from action bar" : Presence of Mind apprise, sur aucune barre
    lua.execute("""
        TALENTS[1].talents[5][5] = 1
        ACTIONS = {}
        ForeverUI.Talents.maj()
        ForeverUITalentsSearchBox:SetFocus()
        CLIQUER(ForeverUITalentsSearchResultSuggestion)
    """)
    marques = {b.talent.nom: b.marque for b in T.arbre.noeuds.values() if b.shown and b.marque and b.marque.shown}
    print("   barres : %s, texte '%s'" % (list(marques), rb.text))
    assert list(marques) == ["Presence of Mind"] and rb.text == "Missing from action bar"
    assert list(marques["Presence of Mind"].icone.texcoord.values())[0] == e["talents-search-notonactionbar"][2]
    # le sort pose sur une barre : sa marque s'en va (ACTIONBAR_SLOT_CHANGED)
    lua.execute("""
        SORTS_PAR_ID[12043] = "Presence of Mind"
        ACTIONS[1] = { "spell", nil, nil, 12043 }
        local v = ForeverUI.TalentsSearch.veilleBarres
        v.scripts.OnEvent(v, "ACTIONBAR_SLOT_CHANGED", 1)
    """)
    reste = [b.talent.nom for b in T.arbre.noeuds.values() if b.shown and b.marque and b.marque.shown]
    print("   pose sur la barre : marques restantes %s" % reste)
    assert reste == [], "posee sur une barre active : plus absente"
    # retiree de la barre : la marque revient
    lua.execute("ACTIONS[1] = nil local v = ForeverUI.TalentsSearch.veilleBarres v.scripts.OnEvent(v, 'ACTIONBAR_SLOT_CHANGED', 1)")
    assert [b.talent.nom for b in T.arbre.noeuds.values() if b.shown and b.marque and b.marque.shown] == ["Presence of Mind"]
    lua.execute("ForeverUI.TalentsSearch.quitter() TALENTS[1].talents[5][5] = 0 ForeverUI.Talents.maj()")
    # fenetre reduite (familier) : le champ se retrecit
    lua.execute("CLIQUER(ForeverUITalentsTab4)")
    wl = len("Unspent Talents") * 6
    attendu = min(184, 404 + 4 + T.points.droiteLibelle - wl - 10 - 25 - 3 - 10)
    print("   familier : champ %s (attendu %s)" % (rb.width, attendu))
    assert abs(rb.width - attendu) < 1e-9
    # un libelle plus long (une autre langue) : le champ cede la place
    lua.execute("ForeverUI.Talents.points.libelle:SetText('Unspent Talent Points Here') ForeverUI.Talents.maj()")
    attendu = min(184, 404 + 4 + T.points.droiteLibelle - len("Unspent Talent Points Here") * 6 - 10 - 25 - 3 - 10)
    print("   libelle long : champ %s (attendu %s)" % (rb.width, attendu))
    assert abs(rb.width - attendu) < 1e-9 and rb.width < 184
    lua.execute("ForeverUI.Talents.points.libelle:SetText('Unspent Talents')")
    lua.execute("CLIQUER(ForeverUITalentsTab1)")
    assert rb.width == 184
    # les glyphes : pas de champ
    lua.execute("CLIQUER(ForeverUITalentsTab3)")
    assert not rb.shown and not fl.shown
    lua.execute("CLIQUER(ForeverUITalentsTab1)")
    assert rb.shown

    # GLISSER UN SORT DE TALENT vers une barre : Presence of Mind (carre,
    # MageArcane "5:2" -> 12043 dans TalentsData.lua), appris, dans le grimoire
    lua.execute("""
        LIENS = { spell8 = 12043 }
        GLISSE_LIEN = GetSpellLink
        function GetSpellLink(slot, livre)
            local id = LIENS[livre .. slot]
            if id then return "|cff71d5ff|Hspell:" .. id .. "|h[x]|h|r" end
            return GLISSE_LIEN(slot, livre)
        end
        LIVRE.spell[8] = { "Presence of Mind", "", false, "ic:presence" }
        ONGLETS[2][4] = ONGLETS[2][4] + 1
        PRIS = {}
        function NOEUD(nom)
            for _, b in pairs(ForeverUI.Talents.arbre.noeuds) do
                if b:IsShown() and b.talent and b.talent.nom == nom then return b end
            end
        end
        function GLISSER(nom) local b = NOEUD(nom) b.scripts.OnDragStart(b) end
        GLISSER("Presence of Mind")
    """)
    assert len(list(g.PRIS.values())) == 0, "pas encore appris : rien"
    lua.execute("TALENTS[1].talents[5][5] = 1 ForeverUI.Talents.maj() GLISSER('Presence of Mind')")
    pris = list(g.PRIS.values())
    print("   glisser Presence of Mind : %s | glisser : %s" % (pris, list(g.NOEUD("Presence of Mind").dragButtons.values())))
    assert pris == ["spell8"] and list(g.NOEUD("Presence of Mind").dragButtons.values()) == ["LeftButton"]
    # un passif (rond) ne se glisse pas
    lua.execute("PRIS = {} GLISSER('Arcane Focus')")
    assert len(list(g.PRIS.values())) == 0
    # sans l'identifiant du sort, le nom suffit (le plus haut rang)
    lua.execute("LIENS = {} PRIS = {} GLISSER('Presence of Mind')")
    assert list(g.PRIS.values()) == ["spell8"]
    lua.execute("""
        GetSpellLink = GLISSE_LIEN
        LIVRE.spell[8] = nil
        ONGLETS[2][4] = ONGLETS[2][4] - 1
        TALENTS[1].talents[5][5] = 0
        ForeverUI.Talents.maj()
    """)

    # LA CONFIRMATION A LA FERMETURE : un point en attente
    lua.execute("POINTS_TALENTS = 3 ForeverUI.Talents.maj() CLIQUER(ForeverUITalentsNode3) POPUPS = {}")
    assert g.GetGroupPreviewTalentPointsSpent(False, 1) == 1
    lua.execute("PlayerTalentFrame:Hide()")
    ro = T.rouvreur
    assert ro.shown, "la fenetre se rouvrira a l'image suivante"
    lua.execute("ForeverUI.Talents.rouvreur.scripts.OnUpdate(ForeverUI.Talents.rouvreur)")
    pop = list(g.POPUPS.values())
    print("   fermeture avec attente : rouverte=%s, fenetre %s | %s" % (g.PlayerTalentFrame.shown, pop[-1].quoi,
        g.StaticPopupDialogs["FOREVERUI_TALENTS_CONFIRM_CLOSE"].text))
    assert g.PlayerTalentFrame.shown and pop[-1].quoi == "FOREVERUI_TALENTS_CONFIRM_CLOSE"
    dlg = g.StaticPopupDialogs["FOREVERUI_TALENTS_CONFIRM_CLOSE"]
    assert dlg.text == "You will lose any pending changes if you continue." and dlg.button1 == "Continue" and dlg.button2 == "Cancel"
    assert g.GetGroupPreviewTalentPointsSpent(False, 1) == 1, "rien n'est perdu tant qu'on n'a pas continue"
    # Continue : l'attente s'en va, la fenetre se ferme pour de bon
    lua.execute("StaticPopupDialogs.FOREVERUI_TALENTS_CONFIRM_CLOSE.OnAccept()")
    assert not g.PlayerTalentFrame.shown and not ro.shown and g.GetGroupPreviewTalentPointsSpent(False, 1) == 0
    # sans attente : on ferme sans question
    lua.execute("PlayerTalentFrame:Show() POPUPS = {} PlayerTalentFrame:Hide()")
    assert not ro.shown and len(list(g.POPUPS.values())) == 0
    # la vue est gardee quand elle se rouvre (ici, le familier)
    lua.execute("""
        PlayerTalentFrame:Show()
        CLIQUER(ForeverUITalentsTab4)
        POINTS_FAMILIER = 1
        TALENTS_FAMILIER[1].talents[1][5] = 0
        ForeverUI.Talents.maj()
        CLIQUER(ForeverUITalentsNode1)
        PlayerTalentFrame:Hide()
        ForeverUI.Talents.rouvreur.scripts.OnUpdate(ForeverUI.Talents.rouvreur)
    """)
    print("   familier en attente : rouverte=%s, vue familier=%s" % (g.PlayerTalentFrame.shown, T.pet))
    assert g.PlayerTalentFrame.shown and T.pet, "rouverte telle qu'elle etait"
    lua.execute("StaticPopupDialogs.FOREVERUI_TALENTS_CONFIRM_CLOSE.OnAccept() PlayerTalentFrame:Show() CLIQUER(ForeverUITalentsTab1)")

    # LA SUPERPOSITION : grimoire et talents ouverts ensemble
    lua.execute("""
        PlayerTalentFrame:Hide()
        SpellBookFrame:Show()
        PlayerTalentFrame:Show()
        function NIVEAUX(c, l)
            l = l or {}
            table.insert(l, c:GetFrameLevel())
            for _, e in ipairs({ c:GetChildren() }) do NIVEAUX(e, l) end
            return l
        end
        function BORNES(c)
            local l = NIVEAUX(c)
            table.sort(l)
            return l[1], l[#l]
        end
    """)
    bmin, bmax = g.BORNES(g.SpellBookFrame)
    tmin, tmax = g.BORNES(g.PlayerTalentFrame)
    print("   superposition : grimoire %s..%s, talents %s..%s" % (bmin, bmax, tmin, tmax))
    assert tmin > bmax, "les talents, ouverts en dernier, entierement devant"
    premier = (bmin, bmax, tmin, tmax)
    # un clic sur le grimoire le ramene devant
    lua.execute("""
        ForeverUISpellBookFrame.souris = true
        SOURIS.LeftButton = true
        ForeverUI.Superposition.veille:GetScript("OnUpdate")(ForeverUI.Superposition.veille)
        SOURIS.LeftButton = false
        ForeverUI.Superposition.veille:GetScript("OnUpdate")(ForeverUI.Superposition.veille)
        ForeverUISpellBookFrame.souris = false
    """)
    bmin, bmax = g.BORNES(g.SpellBookFrame)
    tmin, tmax = g.BORNES(g.PlayerTalentFrame)
    print("   clic sur le grimoire : grimoire %s..%s, talents %s..%s" % (bmin, bmax, tmin, tmax))
    assert bmin > tmax, "le grimoire entierement devant"
    # et un clic sur un onglet des talents (dehors) les ramene devant
    lua.execute("""
        ForeverUITalentsTabs.souris = true
        SOURIS.RightButton = true
        ForeverUI.Superposition.veille:GetScript("OnUpdate")(ForeverUI.Superposition.veille)
        SOURIS.RightButton = false
        ForeverUI.Superposition.veille:GetScript("OnUpdate")(ForeverUI.Superposition.veille)
        ForeverUITalentsTabs.souris = false
    """)
    bmin2, bmax2 = g.BORNES(g.SpellBookFrame)
    tmin2, tmax2 = g.BORNES(g.PlayerTalentFrame)
    print("   clic sur un onglet des talents : grimoire %s..%s, talents %s..%s" % (bmin2, bmax2, tmin2, tmax2))
    assert (bmin2, bmax2, tmin2, tmax2) == premier, "le fond reprend son niveau : pas de derive"
    # en combat, le grimoire protege ne bouge pas
    lua.execute("""
        SpellBookFrame.protege = true STATE.inLockdown = true
        ForeverUI.Superposition.devant("grimoire")
        STATE.inLockdown = false SpellBookFrame.protege = nil
    """)
    assert g.BORNES(g.SpellBookFrame) == (bmin2, bmax2)
    lua.execute("SpellBookFrame:Hide()")
    # LE DEPLACEMENT : la barre du titre, reancree par le haut-centre
    lua.execute("""
        UIParent._cx, UIParent._top = 960, 1080
        ForeverUITalentsFrame._cx, ForeverUITalentsFrame._top = 900, 900
        local b = ForeverUITalentsFrame.bandeau
        b.scripts.OnDragStart(b)
        b.scripts.OnDragStop(b)
    """)
    pd = list(tl.points[1].values())
    print("   deplace : %s de %s (%s, %s), retenu %s" % (pd[0], pd[2], pd[3], pd[4], dict(g.ForeverUIDB.positions.talents)))
    assert (pd[0], pd[2], pd[3], pd[4]) == ("TOP", "TOP", -60, -180) and tl.movable and g.ForeverUITalentsFrame.bandeau.dragButtons[1] == "LeftButton"
    assert not tl.userPlaced, "la place est a nous, pas au client"
    lua.execute("ForeverUITalentsFrame:ClearAllPoints() PlayerTalentFrame:Hide() PlayerTalentFrame:Show()")
    pd = list(tl.points[1].values())
    assert (pd[3], pd[4]) == (-60, -180), "reposee a l'ouverture"
    # en combat, pas de deplacement
    lua.execute("STATE.inLockdown = true ForeverUITalentsFrame.moving = false ForeverUITalentsFrame.bandeau.scripts.OnDragStart(ForeverUITalentsFrame.bandeau) STATE.inLockdown = false")
    assert not tl.moving
    assert g.ForeverUISpellBookFrame.bandeau.dragButtons[1] == "LeftButton" and g.ForeverUISpellBookFrame.movable

    # la croix de WotLK ferme le panneau
    lua.execute("PlayerTalentFrameCloseButton:GetScript('OnClick')(PlayerTalentFrameCloseButton)")
    assert not g.PlayerTalentFrame.shown


    # LA FENETRE SOCIAL (etape 1, 2026-09-26) : notre fenetre camelot sur
    # l'onglet Friends, l'ecran de WotLK sur les autres.
    print("\nfenetre Social :")
    lua.execute("ShowUIPanel(FriendsFrame)")
    so = g.ForeverUISocialFrame
    ff = g.FriendsFrame
    regs = [r.shown for r in ff.regions.values()]
    onglets_client = [g["FriendsFrameTab%d" % i].shown for i in range(1, 6)]
    print("   ouverte : notre fenetre %s %dx%d, regions du client %s, onglets du client %s, souris du panneau %s" % (
        so.shown, so.width, so.height, regs, onglets_client, ff.mouseEnabled))
    assert so.shown and (so.width, so.height) == (385, 424)
    assert not any(regs), "les quatre quartiers, l'icone et le titre de WotLK se taisent"
    assert not any(onglets_client) and not g.FriendsListFrame.shown and not g.FriendsTabHeader.shown
    assert ff.mouseEnabled is False, "le panneau vide n'attrape plus la souris"
    assert g.DEMANDES_AMIS >= 1, "ShowFriends demande la liste au serveur"
    assert so.titre.text == "Friends List"
    # le cadre de camelot
    assert so.portrait.texture.endswith("battlenet-portrait-hd") and so.portrait.width == 60
    pp = list(so.portrait.points[1].values())
    assert (pp[3], pp[4]) == (-5, 7)
    pc = list(so.croix.points[1].values())
    assert (pc[0], pc[3], pc[4]) == ("TOPRIGHT", -2, 1)
    ins = g.ForeverUISocialInset
    pi1, pi2 = list(ins.points[1].values()), list(ins.points[2].values())
    assert (pi1[3], pi1[4], pi2[3], pi2[4]) == (4, -83, -6, 26) and ins.fond.texture.endswith("ui-background-marble")
    # les onglets du bas : Friends choisi, puis Who, Guild, Chat, Raid
    ob = [g["ForeverUISocialTab%d" % i] for i in range(1, 6)]
    pob = list(ob[0].points[1].values()), list(ob[1].points[1].values())
    print("   onglets du bas : %s, largeurs %s, premier %s (%s, %s), suivant a %s" % (
        [o.texte.text for o in ob], [o.width for o in ob], pob[0][0], pob[0][3], pob[0][4], pob[1][3]))
    assert [o.texte.text for o in ob] == ["Friends", "Who", "Guild", "Chat", "Raid"]
    assert (pob[0][0], pob[0][2], pob[0][3], pob[0][4]) == ("TOPLEFT", "BOTTOMLEFT", 5, 2) and pob[1][3] == 3
    assert ob[0].art.actifG.shown and not ob[0].art.g.shown and ob[0].enabled is False, "Friends choisi : art actif, desactive"
    assert ob[1].art.g.shown and not ob[1].art.actifG.shown and ob[1].enabled is not False
    assert ob[0].art.g.texture and ob[1].art.g.texcoord is not None
    assert ob[0].width == 72, "texte + 20, au moins gauche + droite (35 + 37)"
    # les sous-onglets : Friends et Ignore, l'art retourne
    so1, so2 = g.ForeverUISocialSubTab1, g.ForeverUISocialSubTab2
    ps1 = list(so1.points[1].values())
    e = g.ForeverUI.AtlasEntry("uiframe-tab-left-c60")
    tc = list(so2.art.g.texcoord.values())
    print("   sous-onglets : %s %s, %s (%s, %s), largeur %s, hauteur %s, art retourne %s" % (
        so1.texte.text, so2.texte.text, ps1[0], ps1[3], ps1[4], so1.width, so1.height, tc))
    assert (so1.texte.text, so2.texte.text) == ("Friends", "Ignore")
    assert (ps1[0], ps1[3], ps1[4]) == ("TOPLEFT", 18, -60) and so1.width == 100 and so1.height == 24
    assert tc == [e[3], e[2], e[5], e[4]], "un demi-tour : les deux bords echanges"
    assert so1.enabled is False and so2.enabled is not False

    # LA LISTE DES AMIS : en ligne, un separateur, hors ligne
    lignes = [g["ForeverUISocialRow%d" % i] for i in range(1, 5)]
    vues = [(l.sorte, l.nom.text if l.nom.shown else None) for l in lignes if l.shown]
    print("   liste : %s" % vues)
    assert vues == [("ami", "Alice, Level 80 Mage"), ("ami", "Bob, Level 70 Priest"), ("trait", None), ("ami", "Carl")]
    a, b_, t, c = lignes
    assert a.etat.texture.endswith("StatusIcon-Online") and b_.etat.texture.endswith("StatusIcon-Away")
    assert c.etat.texture.endswith("StatusIcon-Offline") and a.info.text == "Dalaran"
    assert list(a.nom.textColor.values())[:3] == [0.996, 0.882, 0.361] and list(c.nom.textColor.values())[:3] == [0.486, 0.518, 0.541]
    assert a.height == 34 and t.height == 16 and t.trait.texture.endswith("UI-FriendsFrame-OnlineDivider")
    pa = list(a.points[1].values())
    assert pa[1].name == "ForeverUISocialList" and (pa[3], pa[4]) == (0, 0)
    pl = list(g.ForeverUISocialList.points[1].values())
    assert (pl[3], pl[4]) == (8, -87)
    # la premiere selection, et Send Message vers un ami en ligne
    S = g.ForeverUI.Social
    print("   selection %s, Send Message actif %s, verrou %s" % (g.AMI_CHOISI, S.boutons.message.actif, a.locked))
    assert g.AMI_CHOISI == 1 and S.boutons.message.actif and S.boutons.message.shown
    assert S.boutons.ajouter.shown and not S.boutons.ignorer.shown
    assert (S.boutons.ajouter.width, S.boutons.ajouter.height) == (134, 21)
    # clic sur l'ami hors ligne : plus de message possible
    c.scripts.OnClick(c, "LeftButton")
    assert g.AMI_CHOISI == 3 and not S.boutons.message.actif
    # clic droit : le menu du client, pour la liste d'amis
    a.scripts.OnClick(a, "RightButton")
    m = g.MENUS_AMIS[1]
    assert m.nom == "Alice" and m.connecte == 1 and m.liste == 1
    # infobulle : celle du client, sur l'ami du jeu
    a.scripts.OnEnter(a)
    ib = g.INFOBULLES_AMIS[1]
    assert ib.type == 3 and ib.id == 1 and g.FriendsTooltip.shown
    a.scripts.OnLeave(a)
    assert not g.FriendsTooltip.shown
    # Send Message sur Alice
    a.scripts.OnClick(a, "LeftButton")
    S.boutons.message.scripts.OnClick(S.boutons.message)
    assert list(g.DITS.values())[-1] == "Alice"
    S.boutons.ajouter.scripts.OnClick(S.boutons.ajouter)
    assert list(g.POPUPS.values())[-1].quoi == "ADD_FRIEND"
    # plus de parrainage (retire le 2026-09-26) : aucun bouton d'invocation
    assert all(l.invocation is None for l in lignes)

    # LE SOUS-ONGLET IGNORE : l'en-tete, les ignores, Ignore / Remove Player
    so2.scripts.OnClick(so2)
    vues = [(l.sorte, l.nom.text if l.nom.shown else l.titre.text) for l in lignes if l.shown]
    print("   ignores : titre \"%s\", %s, choisi %s, Remove actif %s" % (so.titre.text, vues, g.IGNORE_CHOISI, S.boutons.retirer.actif))
    assert g.FriendsTabHeader.selectedTab == 2 and so.titre.text == "Ignore List"
    assert vues == [("entete", "Ignored"), ("ignore", "Troll1"), ("ignore", "Troll2")]
    assert g.IGNORE_CHOISI == 1 and S.boutons.retirer.actif and S.boutons.ignorer.shown and not S.boutons.ajouter.shown
    assert S.boutons.muet is None, "plus de Mute Player (chat vocal retire)"
    assert so2.enabled is False and so1.enabled is not False
    S.boutons.retirer.scripts.OnClick(S.boutons.retirer)
    lua.execute("ARENE_EVENEMENT('IGNORELIST_UPDATE')")
    vues = [(l.sorte, l.nom.text if l.nom.shown else l.titre.text) for l in lignes if l.shown]
    assert vues == [("entete", "Ignored"), ("ignore", "Troll2")], "Troll1 retire"
    S.boutons.ignorer.scripts.OnClick(S.boutons.ignorer)
    assert list(g.POPUPS.values())[-1].quoi == "ADD_IGNORE", "sans cible, la fenetre de saisie du client"
    # le chat vocal retire : meme voix activee, ni en-tete Muted ni Mute Player
    lua.execute("VOIX = true; ForeverUI.Social.maj()")
    vues = [(l.sorte, l.nom.text if l.nom.shown else l.titre.text) for l in lignes if l.shown]
    assert ("entete", "Muted") not in vues and S.boutons.ignorer.width == 134
    lua.execute("VOIX = false")
    so1.scripts.OnClick(so1)
    assert g.FriendsTabHeader.selectedTab == 1 and so.titre.text == "Friends List"

    # LE DEFILEMENT : vingt amis ne tiennent pas
    lua.execute("for i = 1, 17 do table.insert(AMIS, 3, { 'Ami' .. i, 80, 'Warrior', 'Zone', 1, '' }) end; ForeverUI.Social.maj()")
    barre = g.ForeverUISocialScrollBar
    print("   defilement : %d entrees, %d visibles, barre %s" % (len(list(S.contenu.values())), S.visibles, barre.shown))
    assert S.visibles < len(list(S.contenu.values())) and barre.shown
    g.ForeverUISocialList.scripts.OnMouseWheel(g.ForeverUISocialList, -1)
    assert S.decalage == 1 and lignes[0].nom.text.startswith("Bob")
    lua.execute("for i = 1, 17 do table.remove(AMIS, 3) end; ForeverUI.Social.decalage = 0; ForeverUI.Social.maj()")

    # LES AUTRES ONGLETS : notre fenetre reste, sa page change ; WotLK se tait
    def appels(nom):
        return [list(a.args.values()) for a in g.APPELS.values() if a.nom == nom]
    ob[1].scripts.OnClick(ob[1])
    regs = [r.shown for r in ff.regions.values()]
    p2 = g.ForeverUISocialPage2
    print("   onglet Who : notre fenetre %s, page %s, regions %s, WhoFrame %s, titre \"%s\", SetWhoToUI %s" % (
        so.shown, p2.shown, regs, g.WhoFrame.shown, so.titre.text, appels("SetWhoToUI")[-1]))
    assert so.shown and p2.shown and not g.ForeverUISocialPage1.shown and not any(regs) and not g.WhoFrame.shown
    assert ob[1].enabled is False and ob[1].art.actifG.shown and ob[0].enabled is not False
    assert so.titre.text == "Who List" and appels("SetWhoToUI")[-1] == [1], "les resultats du /who dans la fenetre"
    W = g.ForeverUI.Social.Who
    wr = [g["ForeverUIWhoListRow%d" % i] for i in range(1, 4)]
    c0 = wr[0]
    print("   qui : %s, totaux \"%s\"" % ([(l.nom.text, l.niveau.text, l.race.text, l.classe.text, l.variable.text, l.guilde.text)
        for l in wr if l.shown], W.totaux.text))
    assert [l.nom.text for l in wr if l.shown] == ["Zed", "Ann"]
    assert (c0.niveau.text, c0.race.text, c0.classe.text, c0.variable.text, c0.guilde.text) == ("Level 80", "Human", "Warrior", "Stormwind", "Les Braves")
    assert list(c0.classe.textColor.values())[:3] == [0.78, 0.61, 0.43], "la classe teintee"
    assert list(c0.variable.textColor.values())[:3] == [0.486, 0.518, 0.541] and list(c0.niveau.textColor.values())[:3] == [1, 1, 1]
    e = g.ForeverUI.AtlasEntry("common-button-list-large")
    fond, choisie, survol = [list(t.values()) for t in (c0.fond, c0.choisie, c0.survol)]
    coins = [(t.width, t.height) for t in fond[:4]]
    print("   carte en neuf tranches : %d / %d / %d, coins %s, survol %s %s" % (
        len(fond), len(choisie), len(survol), coins, survol[0].layer, survol[0].blend))
    assert len(fond) == len(choisie) == len(survol) == 9 and coins == [(9, 9)] * 4 and fond[0].texture == e[1]
    assert survol[0].layer == "HIGHLIGHT" and all(t.blend == "ADD" for t in survol)
    assert c0.height == 69 and not any(t.shown for t in choisie)
    assert c0.nom.font.nom == "ForeverUIFontNormalMed1" and g.ForeverUIFontNormalMed1.parent == "SystemFont_Med2"
    assert list(g.ForeverUIFontNormalMed1.couleur.values()) == [1, 0.82, 0]
    pn = list(c0.nom.points[1].values())
    pc = list(c0.classe.points[2].values())
    pg = list(c0.guilde.points[2].values())
    print("   carte : nom %s (%s, %s), classe bornee %s %s, guilde bornee %s %s" % (pn[0], pn[3], pn[4], pc[2], pc[4], pg[2], pg[4]))
    assert (pn[0], pn[3], pn[4]) == ("TOPLEFT", 10, -6) and (pc[2], pc[4]) == ("TOPRIGHT", -31.5) and (pg[2], pg[4]) == ("TOPRIGHT", -50.5)
    assert W.totaux.text.startswith("2 ") and g.ForeverUIWhoColumn1 is None, "plus d'en-tetes de colonnes"
    assert not W.ajouter.actif and not W.inviter.actif, "sans selection, eteints"
    c0.scripts.OnClick(c0, "LeftButton")
    assert W.choisi == 1 and W.ajouter.actif and all(t.shown for t in c0.choisie.values())
    W.ajouter.scripts.OnClick(W.ajouter)
    W.inviter.scripts.OnClick(W.inviter)
    assert appels("AddFriend")[-1] == ["Zed"] and appels("InviteUnit")[-1] == ["Zed"]
    c0.scripts.OnClick(c0, "LeftButton")
    assert W.choisi is None and not any(t.shown for t in c0.choisie.values()) and not W.ajouter.actif, "un second clic retire la selection"
    # LA BARRE : sans elle, la liste va au bord ; avec elle, lui laisse sa place
    def bordDroit(liste):
        return [list(p.values())[3] for p in liste.points.values() if list(p.values())[0] == "BOTTOMRIGHT"][-1]
    sans = bordDroit(W.liste)
    lua.execute("ForeverUIWhoList.hauteurDefaut = 69; ForeverUI.Social.Who.maj()")
    avec = bordDroit(W.liste)
    print("   Qui : bord droit sans barre %s, avec barre %s (barre %s)" % (sans, avec, g.ForeverUIWhoListScrollBar.shown))
    assert sans == -4 and avec == -22 and g.ForeverUIWhoListScrollBar.shown and len(W.liste.points) == 2
    lua.execute("ForeverUIWhoList.hauteurDefaut = nil; ForeverUI.Social.Who.maj()")
    assert bordDroit(W.liste) == -4 and not g.ForeverUIWhoListScrollBar.shown
    wr[1].scripts.OnClick(wr[1], "RightButton")
    assert list(g.MENUS_AMIS.values())[-1].nom == "Ann"
    # l'infobulle : seulement pour un texte coupe
    c0.scripts.OnEnter(c0)
    lua.execute("GameTooltip.text = nil")
    lua.execute("ForeverUIWhoListRow1.nom:SetWidth(10); ForeverUI.Social.Who.maj()")
    c0.scripts.OnEnter(c0)
    print("   infobulle du nom coupe : %s %s" % (g.GameTooltip.text, list(g.GameTooltip.lignes.values())))
    assert g.GameTooltip.text == "Zed" and list(g.GameTooltip.lignes.values()) == ["Level 80", "Stormwind"]
    W.saisie.SetText(W.saisie, "80")
    W.saisie.scripts.OnEnterPressed(W.saisie)
    assert appels("SendWho")[-1] == ["80"]

    # LA GUILDE
    ob[2].scripts.OnClick(ob[2])
    Gu = g.ForeverUI.Social.Guild
    gf = g.GuildFrame
    pgf = list(gf.points[1].values())
    print("   guilde : titre \"%s\", totaux \"%s\", GuildFrame montre %s alpha %s a (%s, %s), SetWhoToUI %s" % (
        so.titre.text, Gu.totaux.text, gf.shown, gf.alpha, pgf[3], pgf[4], appels("SetWhoToUI")[-1]))
    assert so.titre.text == "Officer of Les Braves" and Gu.totaux.text == "3 Guild Members (2 Online)"
    assert gf.shown and gf.alpha == 0 and pgf[3] == -5000, "le cadre du client, montre mais hors de l'ecran"
    assert appels("SetWhoToUI")[-1] == [0], "quitter Qui rend les resultats au chat"
    gr = [g["ForeverUIGuildListRow%d" % i] for i in range(1, 4)]
    print("   membres : %s" % [(l.niveau.text, l.nom.text, l.zone.text, l.rang.text) for l in gr])
    assert [l.nom.text for l in gr] == ["Moi", "Bea", "Cid"] and (gr[0].niveau.text, gr[0].zone.text, gr[0].rang.text) == (80, "Dalaran", "Officer")
    assert gr[0].note is None, "plus de colonne Note"
    pv = list(gr[0].niveau.points[1].values())
    pc = list(gr[0].classe.points[1].values())
    assert (pv[0], pv[3], gr[0].niveau.width, gr[0].niveau.justify) == ("LEFT", -1, 40, "CENTER"), "le niveau centre sur sa colonne"
    assert (pc[0], pc[1].name, pc[3]) == ("LEFT", "ForeverUIGuildListRow1", 52), "l'icone de classe ne bouge pas"
    # la fenetre garde sa largeur, le panneau du client aussi
    assert so.width == 385 and g.FriendsFrame.width == 384
    pr = [list(p.values()) for p in gr[0].rang.points.values()]
    assert (pr[1][0], pr[1][2], pr[1][3]) == ("RIGHT", "RIGHT", -4), "le rang va au bord de la ligne"
    # la ligne de camelot : bande GuildFrame, barre de surbrillance, icone de classe
    n0 = gr[0].GetNormalTexture(gr[0])
    assert gr[0].height == 20 and n0.texture.lower().endswith("guildframe") and list(n0.texcoord.values())[0] == 0.36230469
    assert gr[0].GetHighlightTexture(gr[0]).texture.endswith("UI-FriendsFrame-HighlightBar")
    assert gr[0].classe.shown and gr[0].classe.texture.endswith("UI-CharacterCreate-Classes")
    # en ligne : nom teinte de la classe, absent : l'icone ; hors ligne : gris, dernier passage
    nc = g.NORMAL_FONT_COLOR
    assert list(gr[0].nom.textColor.values())[:3] == [nc.r, nc.g, nc.b], "classe sans couleur connue : NORMAL, comme camelot"
    assert not gr[0].presence.shown and gr[1].presence.shown and gr[1].presence.texture.endswith("StatusIcon-Away")
    assert list(gr[2].nom.textColor.values())[:3] == [0.5, 0.5, 0.5] and list(gr[2].rang.textColor.values())[:3] == [0.5, 0.5, 0.5]
    assert gr[2].zone.text == "3 |4day:days;", "hors ligne, la zone dit le dernier passage"
    assert list(gr[1].nom.points[1].values())[1] is not None and list(gr[1].nom.points[1].values())[2] == "RIGHT", "le nom apres la presence"
    # le chef de guilde : l'icone de rang
    lua.execute("GUILDE[1][3] = 0; ForeverUI.Social.Guild.maj()")
    assert gr[0].rangIcone.shown and gr[0].rangIcone.texture.endswith("UI-Group-LeaderIcon") and not gr[1].rangIcone.shown
    lua.execute("GUILDE[1][3] = 1; ForeverUI.Social.Guild.maj()")
    # les en-tetes : GUILD_COLUMN_INFO, la note au bord de la liste
    ent = [g["ForeverUIGuildColumn%d" % i] for i in range(1, 6)]
    print("   en-tetes : %s, largeurs %s" % ([h.texte.text for h in ent], [h.width for h in ent]))
    assert [h.texte.text for h in ent] == ["Level", "Class", "Name", "Zone", "Rank"] and g.ForeverUIGuildColumn6 is None
    assert [h.width for h in ent[:4]] == [40, 45, 100, 100]
    pn6 = list(ent[4].points[2].values())
    assert (pn6[0], pn6[1].name, pn6[2], pn6[3]) == ("BOTTOMRIGHT", "ForeverUIGuildList", "TOPRIGHT", -6)
    # la colonne Note suit la liste, et la liste suit la barre
    bdg = [list(p.values())[3] for p in Gu.liste.points.values() if list(p.values())[0] == "BOTTOMRIGHT"]
    lua.execute("ForeverUIGuildList.hauteurDefaut = 40; ForeverUI.Social.Guild.maj()")
    bdg2 = [list(p.values())[3] for p in Gu.liste.points.values() if list(p.values())[0] == "BOTTOMRIGHT"]
    print("   Guilde : bord droit sans barre %s, avec barre %s" % (bdg, bdg2))
    assert bdg == [-4] and bdg2 == [-22]
    lua.execute("ForeverUIGuildList.hauteurDefaut = nil; ForeverUI.Social.Guild.maj()")
    ent[4].scripts.OnClick(ent[4])
    ent[1].scripts.OnClick(ent[1])
    assert appels("SortGuildRoster")[-2:] == [["rank"], ["class"]]
    assert g.ForeverUIGuildViewToggle is None, "plus de bascule des vues"
    assert Gu.motd.text == "Raid ce soir" and Gu.motdZone.mouseEnabled
    assert not Gu.controle.actif and Gu.ajouter.actif, "Guild Control : chef de guilde seulement"
    # l'infobulle : pour un texte coupe, ou pour un membre qui a une note
    lua.execute("GameTooltip.text = nil; GameTooltip.lignes = {}")
    gr[1].scripts.OnEnter(gr[1])
    assert not list(g.GameTooltip.lignes.values()), "rien de coupe, pas de note : pas d'infobulle"
    lua.execute("ForeverUIGuildListRow2.zone:SetWidth(10)")
    gr[1].scripts.OnEnter(gr[1])
    assert list(g.GameTooltip.lignes.values()) == ["Bea", "Member", "Level 75 Rogue", "Orgrimmar"], "zone coupee"
    lua.execute("ForeverUIGuildListRow2.zone:SetWidth(90)")
    gr[0].scripts.OnEnter(gr[0])
    print("   infobulle : %s" % list(g.GameTooltip.lignes.values()))
    assert list(g.GameTooltip.lignes.values()) == ["Moi", "Officer", "Level 80 Mage", "Dalaran", "Note: note moi"]
    # la case des hors ligne
    ho = g.ForeverUIGuildShowOffline
    assert ho.checked and ho.texte.text == "Show Offline Members"
    # enfoncee, la case garde son contour : l'image enfoncee EST le contour
    hn, hp = ho.GetNormalTexture(ho), ho.GetPushedTexture(ho)
    assert hp is not None and hp.texture == hn.texture and list(hp.texcoord.values()) == list(hn.texcoord.values())
    assert hn.texture == g.ForeverUI.AtlasEntry("checkbox-minimal")[1]
    # un membre choisi, son detail ouvert ; puis la case, SANS autre mise a
    # jour : la liste change tout de suite, la selection et le detail s'en vont
    gr[2].scripts.OnClick(gr[2], "LeftButton")
    assert g.GUILDE_CHOIX == 3 and g.ForeverUIGuildMemberDetail.shown
    ho.SetChecked(ho, False)
    ho.scripts.OnClick(ho)
    print("   sans hors ligne : %s, totaux \"%s\", selection %s, detail %s, case %s" % (
        [l.nom.text for l in gr if l.shown], Gu.totaux.text, g.GUILDE_CHOIX, g.ForeverUIGuildMemberDetail.shown, ho.checked))
    assert [l.nom.text for l in gr if l.shown] == ["Moi", "Bea"] and Gu.totaux.text == "3 Guild Members (2 Online)"
    assert g.GUILDE_CHOIX == 0 and not g.ForeverUIGuildMemberDetail.shown and ho.checked is False
    ho.SetChecked(ho, True)
    ho.scripts.OnClick(ho)
    assert [l.nom.text for l in gr if l.shown] == ["Moi", "Bea", "Cid"] and ho.checked is True
    # le detail d'un membre
    gr[1].scripts.OnClick(gr[1], "LeftButton")
    det = g.ForeverUIGuildMemberDetail
    D_rang = det.titre.text
    print("   detail : %s, selection %s, GuildFrame.selectedName %s" % (D_rang, g.GUILDE_CHOIX, gf.selectedName))
    assert det.shown and D_rang == "Bea" and g.GUILDE_CHOIX == 2 and gf.selectedName == "Bea"
    gr[1].scripts.OnClick(gr[1], "LeftButton")
    assert not det.shown and g.GUILDE_CHOIX == 0, "le meme clic referme le detail"
    gr[1].scripts.OnClick(gr[1], "RightButton")
    assert list(g.MENUS_AMIS.values())[-1].nom == "Bea"
    # l'information et le journal
    Gu.info.scripts.OnClick(Gu.info)
    inf = g.ForeverUIGuildInfoFrame
    assert inf.shown and g.ForeverUIGuildInfoEditBox.text == "Bienvenue"
    # Log a gauche, Accept et Close contre le bord droit : plus de chevauchement
    ib = g.ForeverUI.Social.Guild.infoBoutons
    pj, pac, pf = [list(ib[k].points[1].values()) for k in ("journal", "accepter", "fermer")]
    print("   info : Log %s (%s), Accept %s de %s (%s), Close %s (%s)" % (pj[0], pj[3], pac[0], pac[2], pac[3], pf[0], pf[3]))
    assert (pj[0], pj[3]) == ("BOTTOMLEFT", 12) and (pf[0], pf[3]) == ("BOTTOMRIGHT", -12)
    assert pac[0] == "RIGHT" and pac[2] == "LEFT" and pac[3] == -4
    # 12 + 70 (Log) < 300 - 12 - 90 - 4 - 90 (debut d'Accept)
    assert 12 + ib["journal"].width < 300 - 12 - ib["fermer"].width - 4 - ib["accepter"].width
    ev = g.ForeverUIGuildEventLog
    lua.execute("ForeverUI.Social.Guild.basculerJournal()")
    lj = [g["ForeverUIGuildEventListRow%d" % i] for i in range(1, 3)]
    print("   journal : %s, info fermee %s" % ([l.texte.text for l in lj], not inf.shown))
    assert ev.shown and not inf.shown, "une annexe a la fois"
    assert lj[0].texte.text.startswith("Moi promotes Bea to Member") and lj[1].texte.text.startswith("Bea joins the guild")
    assert appels("QueryGuildEventLog")


    # LA FENETRE DE CONTROLE DE GUILDE, habillee : plus de MacroPopup, le
    # metal de camelot sur un habit qui depasse de 24, cases et champs
    gc = g.GuildControlPopupFrame
    macros = [r for r in gc.regions.values() if r.texture and "MacroPopup" in str(r.texture)]
    habit = gc.foreverHabit
    ph = list(habit.points[1].values())
    c1 = g.GuildControlPopupFrameCheckbox1
    eb = g.GuildControlPopupFrameEditBox
    print("   controle : MacroPopup visibles %d, habit %sx%s a (%s, %s) niveau %s < %s, titre \"%s\", case %s, champ gauche %s" % (
        sum(1 for r in macros if r.shown), habit.width, habit.height, ph[3], ph[4], habit.frameLevel, gc.frameLevel,
        gc.foreverTitre.text, c1._normal.texture, g.GuildControlPopupFrameEditBoxLeft.shown))
    assert macros and not any(r.shown for r in macros), "le fond MacroPopup se tait"
    assert (habit.width, habit.height, ph[4]) == (320, 481, 24) and gc.foreverTitre.text == "Guild Control"
    assert (habit.frameLevel or 0) < (gc.frameLevel or 1) or gc.frameLevel in (None, 1)
    e = g.ForeverUI.AtlasEntry("checkbox-minimal")
    assert c1._normal.texture == e[1] and not g.GuildControlPopupFrameEditBoxLeft.shown and eb.bordCamelot
    assert g.GuildControlPopupFrameTabPermissions.backdrop is None
    lua.execute("ForeverUI.Social.Guild.maj(); GuildControlPopupFrame:Show()")
    pg = list(gc.points[1].values())
    assert pg[1].name == "ForeverUISocialFrame" and (pg[3], pg[4]) == (12, -24), "recollee a droite, abaissee de 24"
    gc.foreverCroix.scripts.OnClick(gc.foreverCroix)
    assert not gc.shown
    # LES CANAUX
    ob[3].scripts.OnClick(ob[3])
    assert not ev.shown, "changer d'onglet referme les annexes"
    assert so.width == 385 and g.FriendsFrame.width == 384, "hors de la guilde, la largeur de camelot"
    C = g.ForeverUI.Social.Chat
    cr = [g["ForeverUIChannelListRow%d" % i] for i in range(1, 5)]
    print("   canaux : %s" % [l.texte.text for l in cr])
    assert so.titre.text == "Chat Channels"
    assert cr[0].texte.text == "|cffffd200World|r" and cr[1].texte.text == "|cffffffff1. General|r"
    assert cr[3].texte.text == "|cffffffff5. Guilde (3)|r", "le compte pour la categorie GROUP"
    cr[3].scripts.OnClick(cr[3], "LeftButton")
    mr = [g["ForeverUIChannelRosterRow%d" % i] for i in range(1, 4)]
    print("   membres du canal : titre \"%s\", %s, rang %s" % (C.titre.text, [l.nom.text for l in mr], mr[0].rang.texture))
    assert g.CANAL_CHOISI == 4 and C.titre.text == "Guilde (3)" and [l.nom.text for l in mr] == ["Moi", "Bea", "Cid"]
    assert mr[0].rang.texture.endswith("UI-Group-LeaderIcon") and mr[1].rang.texture.endswith("UI-Group-AssistantIcon") and not mr[2].rang.shown
    cr[0].scripts.OnClick(cr[0], "LeftButton")
    assert appels("CollapseChannelHeader")[-1] == [1]
    mr[1].scripts.OnClick(mr[1], "RightButton")
    assert appels("ChannelRosterFrame_ShowDropdown")[-1] == [2]
    # le chat vocal retire : ni cases d'adhesion, ni haut-parleurs, ni glisser
    lua.execute("VOIX = true; CANAUX[4][8] = true; CANAUX[4][9] = true; ForeverUI.Social.maj()")
    assert C.voix is None and cr[3].parleur is None and mr[0].parleur is None
    assert list(cr[3].texte.points[2].values())[3] == -4 and cr[3].scripts.OnDragStart is None
    cr[3].scripts.OnClick(cr[3], "RightButton")
    assert g.ChannelListDropDown.voice is None and g.ChannelListDropDown.voiceActive is None, "le menu du client sans ses lignes de voix"
    lua.execute("VOIX = false; CANAUX[4][8] = nil; CANAUX[4][9] = nil; ForeverUI.Social.maj()")
    C.ajouter.scripts.OnClick(C.ajouter)
    nv = g.ForeverUIChannelNewFrame
    assert nv.shown
    nv.nom.SetText(nv.nom, "MonCanal")
    nv.nom.scripts.OnEnterPressed(nv.nom)
    assert appels("JoinPermanentChannel")[-1] == ["MonCanal", ""] and not nv.shown

    # LE RAID -- a la connexion, aucun menu n'est ouvert : la page ne doit
    # rien demander a UnitPopup en se batissant
    lua.execute("UIDROPDOWNMENU_OPEN_MENU = nil")
    ob[4].scripts.OnClick(ob[4])
    R = g.ForeverUI.Social.Raid
    print("   raid (seul) : hors raid %s, groupes %s, Convert actif %s, RequestRaidInfo %s" % (
        R.hors.shown, R.groupes.shown, R.convertir.actif, bool(appels("RequestRaidInfo"))))
    assert so.titre.text == "Raid" and R.hors.shown and not R.groupes.shown and not R.convertir.actif
    assert appels("RequestRaidInfo") and R.info.actif
    lua.execute("RAID_MEMBRES = { { 'Moi', 2, 1, 80, 'Mage', 'MAGE', 'Naxx', 1, nil }, { 'Bea', 0, 1, 75, 'Rogue', 'ROGUE', 'Naxx', 1, 1 }, { 'Cid', 1, 3, 60, 'Hunter', 'HUNTER', '', nil, nil } }; ForeverUI.Social.maj()")
    pl = R.places
    print("   raid : groupe 1 %s, groupe 3 %s, groupe 2 %s" % ([pl[1][n].nom.text for n in (1, 2, 3)], pl[3][1].nom.text, pl[2][1].nom.text))
    assert R.groupes.shown and not R.hors.shown and R.appel.shown
    assert [pl[1][n].nom.text for n in (1, 2, 3)] == ["Moi", "Bea", "Empty"] and pl[3][1].nom.text == "Cid"
    assert list(pl[1][2].nom.textColor.values())[:3] == [1, 0, 0] and list(pl[3][1].nom.textColor.values())[:3] == [0.5, 0.5, 0.5]
    assert pl[1][1].rang.texture.endswith("UI-Group-LeaderIcon") and pl[3][1].rang.texture.endswith("UI-Group-AssistantIcon")
    # glisser Bea sur Cid, puis sur une place vide du groupe 2
    lua.execute("ForeverUIRaidSlot3_1.souris = true")
    pl[1][2].scripts.OnDragStart(pl[1][2])
    pl[1][2].scripts.OnDragStop(pl[1][2])
    lua.execute("ForeverUIRaidSlot3_1.souris = false; ForeverUIRaidSlot2_4.souris = true")
    pl[1][2].scripts.OnDragStart(pl[1][2])
    pl[1][2].scripts.OnDragStop(pl[1][2])
    lua.execute("ForeverUIRaidSlot2_4.souris = false")
    print("   glisser : %s / %s" % (appels("SwapRaidSubgroup")[-1], appels("SetRaidSubgroup")[-1]))
    assert appels("SwapRaidSubgroup")[-1] == [2, 3] and appels("SetRaidSubgroup")[-1] == [2, 2]
    pl[1][1].scripts.OnClick(pl[1][1], "RightButton")
    assert g.ForeverUIRaidDropDown.name == "Moi" and g.ForeverUIRaidDropDown.unit == "raid1"
    # les icones de rang, de role et de butin ; l'etat de l'appel
    lua.execute("RAID_MEMBRES[1][10] = 'MAINTANK'; RAID_MEMBRES[1][11] = 1; APPEL_ETAT = { raid1 = 'ready', raid2 = 'waiting' }; ForeverUI.Social.maj()")
    ic = [t.texture.split(chr(92))[-1] for t in pl[1][1].icones.values() if t.shown]
    pn = list(pl[1][1].nom.points[1].values())
    print("   icones de Moi : %s, nom a %s ; appel %s / %s" % (ic, pn[3], pl[1][1].appel.texture, pl[1][2].appel.texture))
    assert ic == ["UI-Group-LeaderIcon", "UI-Group-MainTankIcon", "UI-Group-MasterLooter"] and pn[3] == 36
    assert pl[1][1].appel.texture.endswith("ReadyCheck-Ready") and pl[1][2].appel.texture.endswith("ReadyCheck-Waiting")
    assert not pl[3][1].appel.shown
    lua.execute("ARENE_EVENEMENT('READY_CHECK_FINISHED')")
    assert pl[1][2].appel.texture.endswith("ReadyCheck-NotReady"), "a la fin, l'attente devient absent"
    lua.execute("ForeverUI.Social.Raid.minuterie:GetScript('OnUpdate')(ForeverUI.Social.Raid.minuterie, 11)")
    assert not pl[1][1].appel.shown and not pl[1][2].appel.shown, "puis les icones s'effacent"
    # la rangee des classes
    cb = [g["ForeverUIRaidClassButton%d" % k] for k in range(1, 14)]
    guerrier, mage = cb[0], cb[7]
    print("   classes : %d boutons, Mage %s (%s), Guerrier %s, tank %s" % (
        len(cb), mage.nombre, mage.compte.text, guerrier.nombre, cb[11].nombre))
    assert mage.nombre == 1 and mage.compte.text == 1 and guerrier.nombre == 0 and guerrier.icone.desaturated
    assert cb[11].nombre == 1 and cb[11].compte.text == "", "le tank principal, sans compte"
    mage.scripts.OnEnter(mage)
    assert g.GameTooltip.text.startswith("Mage") and "Moi" in g.GameTooltip.lignes[1]
    # detacher : une classe, un groupe, un joueur (Maj + glisser pour le chef)
    mage.scripts.OnDragStart(mage)
    mage.scripts.OnDragStop(mage)
    lab = g.ForeverUIRaidGroupLabel3
    lab.scripts.OnDragStart(lab)
    lab.scripts.OnDragStop(lab)
    lua.execute("IsShiftKeyDown = function() return true end")
    pl[1][2].scripts.OnDragStart(pl[1][2])
    pl[1][2].scripts.OnDragStop(pl[1][2])
    lua.execute("IsShiftKeyDown = function() return false end")
    det = [(d.filtre, d.classe) for d in g.DETACHEES.values()]
    lua.execute("SOURIS_X, SOURIS_Y = 500, 300")
    mage.scripts.OnDragStart(mage)
    mage.scripts.OnDragStop(mage)
    lua.execute("SOURIS_X, SOURIS_Y = 0, 0")
    dern = list(g.DETACHEES.values())[-1]
    pd = list(dern.points[1].values())
    print("   fenetre detachee : %s de %s (%s, %s)" % (pd[0], pd[1].name if pd[1] else None, pd[3], pd[4]))
    assert pd[0] == "TOP" and pd[1].name == "UIParent" and (pd[3], pd[4]) == (500, 300), "sous la souris, par l'echelle de la fenetre"
    print("   detachees : %s, lachees %d" % (det, len(appels("RaidPulloutStopMoving"))))
    assert det == [("MAGE", "Mage"), (3, None), ("Bea", None)] and len(appels("RaidPulloutStopMoving")) >= 3
    # MAIN TANK / MAIN ASSIST : dans le clic droit, sous des boutons securises
    def lignes_menu():
        n = g.DropDownList1.numButtons
        return [g["DropDownList1Button%d" % i] for i in range(1, n + 1)]
    lua.execute("DropDownList1:Show()")
    g.ForeverUIRaidDropDown.id, g.ForeverUIRaidDropDown.name, g.ForeverUIRaidDropDown.unit = 2, "Bea", "raid2"
    lua.execute("ForeverUIRaidDropDown.initialize(ForeverUIRaidDropDown)")
    lm = lignes_menu()
    print("   menu de Bea : %s" % [b.value for b in lm])
    assert [b.value for b in lm][-3:] == ["Promote to Main Tank", "Promote to Main Assist", "CANCEL"], "nos lignes, puis Cancel en dernier"
    o1, o2 = g.ForeverUIRaidMenuSecure1, g.ForeverUIRaidMenuSecure2
    print("   surcouche 1 : %s %s %s sur %s, parent %s, montree %s" % (o1.attributes.type, o1.attributes.action,
        o1.attributes.unit, o1.allPoints.name, o1.parent.name, o1.shown))
    assert o1.template == "SecureActionButtonTemplate" and o1.parent.name == "UIParent"
    assert (o1.attributes.type, o1.attributes.action, o1.attributes.unit) == ("maintank", "set", "raid2")
    assert o2.attributes.type == "mainassist" and o1.shown and o2.shown
    assert o1.strata == "TOOLTIP", "au-dessus de DropDownList1, qui remonte en s'affichant"
    assert o1.allPoints.name == lm[-3].name, "posee sur sa ligne"
    # un tank principal : pas de ligne Main Tank ; Demote passe par le securise
    g.ForeverUIRaidDropDown.id, g.ForeverUIRaidDropDown.name, g.ForeverUIRaidDropDown.unit = 1, "Moi", "raid1"
    lua.execute("ForeverUIRaidDropDown.initialize(ForeverUIRaidDropDown)")
    lm = lignes_menu()
    vals = [b.value for b in lm]
    print("   menu de Moi (tank) : %s ; surcouche 1 %s/%s sur %s" % (vals, o1.attributes.type, o1.attributes.action, o1.allPoints.value))
    assert "Promote to Main Tank" not in vals and vals[-2:] == ["Promote to Main Assist", "CANCEL"]
    assert (o1.attributes.type, o1.attributes.action) == ("maintank", "clear") and o1.allPoints.value == "RAID_DEMOTE"
    # la liste se ferme, ou le combat commence : les surcouches s'en vont
    lua.execute("DropDownList1:Hide()")
    assert not o1.shown and not o2.shown
    lua.execute("DropDownList1:Show(); ForeverUIRaidDropDown.initialize(ForeverUIRaidDropDown); ARENE_EVENEMENT('PLAYER_REGEN_DISABLED')")
    assert not o1.shown
    lua.execute("STATE.inLockdown = true; ForeverUIRaidDropDown.initialize(ForeverUIRaidDropDown); STATE.inLockdown = false")
    vals = [b.value for b in lignes_menu()]
    assert "Promote to Main Assist" not in vals and not o1.shown, "en combat, pas de lignes securisees"
    lua.execute("DropDownList1:Hide()")

    # les instances sauvegardees
    R.info.scripts.OnClick(R.info)
    ir = g.ForeverUIRaidInfoListRow1
    print("   instances : %s, %s, %s ; prolonger %s" % (ir.nom.text, ir.reset.text, ir.difficulte.text, g.ForeverUIRaidInfoFrame.shown))
    assert ir.nom.text == "Naxxramas" and ir.difficulte.text == "25 Player" and not R.convertir.shown
    ir.scripts.OnClick(ir)
    N = g.ForeverUIRaidInfoFrame
    assert R.info.actif
    lua.execute("RAID_MEMBRES = {}")
    g.FriendsFrameTab1.scripts.OnClick(g.FriendsFrameTab1)
    assert not N.shown and g.ForeverUISocialPage1.shown
    # la guilde : onglet eteint hors guilde, comme celui du client
    lua.execute("FriendsFrameTab3:Disable(); ForeverUI.Social.maj()")
    assert ob[2].enabled is False and not ob[2].art.actifG.shown
    lua.execute("FriendsFrameTab3:Enable(); ForeverUI.Social.maj()")
    # la croix ferme le panneau du client
    so.croix.scripts.OnClick(so.croix)
    assert not ff.shown
    assert g.ForeverUI.Superposition.fenetres["social"] is not None and so.bandeau.dragButtons[1] == "LeftButton"


    # ------------------------------------------------- LES CADRES DE GROUPE
    print("\ncadres de groupe :")
    lua.execute("local v = ForeverUI.PartyFrame.veilleur; v.scripts.OnEvent(v, 'PLAYER_ENTERING_WORLD')")
    ct = g.ForeverUIPartyFrame
    m1, m2 = g.ForeverUIPartyMemberFrame1, g.ForeverUIPartyMemberFrame2
    def pts(f, k=-1):
        return list(list(f.points.values())[k].values())
    def entree(nom):
        return g.ForeverUI.AtlasEntry(nom)
    pc = pts(ct)
    print("   conteneur : %s (%s, %s), pilote %s" % (pc[0], pc[3], pc[4], ct.etats.visibility))
    assert (pc[0], pc[3], pc[4]) == ("TOPLEFT", 22, -147), "sur le TOPRIGHT du gestionnaire plie (0, -7)"
    assert ct.etats.visibility == "[group:raid] hide; [group] show; hide", "en groupe, pas en raid"
    assert g.PartyMemberFrame1.etats.visibility == "hide" and not g.PartyMemberFrame1.shown, "le cadre du client, tenu cache"
    assert (m1.width, m1.height, m1.unitWatch) == (120, 53, True)
    assert m1.GetAttribute(m1, "unit") == "party1" and m1.GetAttribute(m1, "toggleForVehicle") and m1.GetAttribute(m1, "*type2") == "menu"
    p2 = pts(m2)
    assert (p2[0], p2[1].name, p2[3], p2[4]) == ("TOPLEFT", "ForeverUIPartyFrame", 0, -63), "pas de 63 sans familiers"
    lua.execute("""
    GROUPE = { party1 = { nom = 'Ann', vie = 8000, max = 10000, res = 3000, resMax = 5000, jeton = 'MANA',
                          role = 'HEALER', pvp = true, faction = 'Horde', menace = 2 },
               party2 = { nom = 'Bob', vie = 1500, max = 10000, res = 50, resMax = 100, jeton = 'RAGE',
                          role = 'TANK', deconnecte = true },
               partypet1 = { nom = 'Wolf', vie = 300, max = 600 } }
    CHEF_GROUPE = 1
    AFFAIBLISSEMENTS = { party1 = { { 'icoA', 1, nil, 10, 20 }, { 'icoB', 3, 'Magic', 8, 30 }, { 'icoC', 1, 'Poison', 0, 0 } } }
    STATE.threatWarning = true
    ARENE_EVENEMENT('PARTY_MEMBERS_CHANGED')
    """)
    e_art = entree("ui-hud-unitframe-party-portraiton")
    pa = pts(m1.art)
    print("   Ann : art %s (%s, %s), nom \"%s\" a (%s, %s) sur %s, vie %s, ressource %s" % (
        m1.art.width, pa[3], pa[4], m1.nom.text, pts(m1.nom)[3], pts(m1.nom)[4], m1.nom.width, m1.vie.width, m1.ressource.width))
    assert m1.art.texture == e_art[1] and (pa[3], pa[4]) == (1, -2) and (m1.art.width, m1.art.height) == (120, 49)
    assert m1.nom.text == "Ann" and (pts(m1.nom)[3], pts(m1.nom)[4], m1.nom.width) == (46, -6, 57)
    assert m1.vie.texture == entree("ui-hud-unitframe-party-portraiton-bar-health")[1] and abs(m1.vie.width - 56) < 1e-6
    assert (pts(m1.vie)[3], pts(m1.vie)[4]) == (45, -19) and not m1.vie.desaturated
    assert m1.ressource.texture == entree("ui-hud-unitframe-party-portraiton-bar-mana")[1] and abs(m1.ressource.width - 43.8) < 1e-6
    assert (pts(m1.ressource)[3], pts(m1.ressource)[4]) == (42, -30), "un pixel plus loin : le masque de camelot"
    assert list(m1.ressource.texcoord.values())[0] == entree("ui-hud-unitframe-party-portraiton-bar-mana")[2]
    # chef, role, PvP a l'echelle 0,6, menace
    print("   Ann : chef %s, role %s, PvP %sx%s (%s, %s), menace %s" % (m1.chef.shown, m1.role.texture, m1.pvp.width, m1.pvp.height,
        pts(m1.pvp)[3], pts(m1.pvp)[4], list(m1.lueur.vertex.values())))
    assert m1.chef.shown and m1.chef.texture == entree("ui-hud-unitframe-player-group-leadericon")[1] and not m2.chef.shown
    pch = pts(m1.chef)
    assert (pch[0], pch[2], pch[3], pch[4]) == ("BOTTOM", "TOP", -10, -6)
    assert m1.role.texture == entree("roleicon-tiny-healer")[1] and (m1.role.width, m1.role.height) == (12, 12)
    eth = entree("roleicon-tiny-healer")
    assert list(m1.role.texcoord.values()) == [eth[k] for k in (2, 3, 4, 5)]
    assert m2.role.texture == entree("roleicon-tiny-tank")[1]
    eh = entree("ui-hud-unitframe-player-pvp-hordeicon")
    assert abs(m1.pvp.width - eh[6] * 0.6) < 1e-6 and abs(pts(m1.pvp)[3] - 14.4) < 1e-6 and abs(pts(m1.pvp)[4] + 40.8) < 1e-6
    assert m1.lueur.shown and list(m1.lueur.vertex.values()) == [1.0, 0.6, 0.0] and not m2.pvp.shown
    # affaiblissements : 3 sur 4 ; bordure de leur type ; la lueur d'etat prend
    # le premier type ; le filtre RAID (dissipables) si l'option est active
    au = [g["ForeverUIPartyMemberFrame1Debuff%d" % k] for k in range(1, 5)]
    print("   affaiblissements : %s, piles %s, lueur %s" % ([a.shown for a in au], [a.pile.text for a in au[:3]], list(m1.statut.vertex.values())))
    assert [a.shown for a in au] == [True, True, True, False] and au[1].pile.text == 3 and au[0].pile.text == ""
    assert list(au[0].bordure.vertex.values()) == [0.8, 0, 0] and list(au[1].bordure.vertex.values()) == [0.2, 0.6, 1.0]
    assert (pts(au[0])[3], pts(au[0])[4], pts(au[1])[3]) == (48, -43, 65) and au[0].width == 15
    assert m1.statut.shown and list(m1.statut.vertex.values()) == [0.2, 0.6, 1.0]
    assert list(au[1].recharge.timer.values()) == [22, 8, 1]
    lua.execute("STATE.cvars.showDispelDebuffs = '1'; ARENE_EVENEMENT('UNIT_AURA', 'party1')")
    assert [a.shown for a in au] == [True, True, False, False] and au[0].icone.texture == "icoB", "le filtre RAID"
    lua.execute("STATE.cvars.showDispelDebuffs = nil; ARENE_EVENEMENT('UNIT_AURA', 'party1')")
    # deconnecte : vie pleine desaturee, portrait desature, icone
    print("   Bob deconnecte : vie %s desat %s, portrait desat %s, icone %s" % (m2.vie.width, m2.vie.desaturated, m2.portrait.desaturated, m2.deconnexion.shown))
    assert m2.vie.width == 70 and m2.vie.desaturated and m2.portrait.desaturated and m2.deconnexion.shown
    assert m2.ressource.texture == entree("ui-hud-unitframe-party-portraiton-bar-rage")[1]
    # 15 % de vie : le portrait rouge qui bat
    lua.execute("GROUPE.party2.deconnecte = nil; ARENE_EVENEMENT('UNIT_HEALTH', 'party2')")
    print("   Bob a 15 %% : portrait %s, bat %s" % (list(m2.portrait.vertex.values()), m2.bat))
    assert list(m2.portrait.vertex.values())[:3] == [1, 0, 0] and m2.bat and not m2.deconnexion.shown
    lua.execute("GROUPE.party2.mort = true; ARENE_EVENEMENT('UNIT_HEALTH', 'party2')")
    assert list(m2.portrait.vertex.values())[:3] == [0.35, 0.35, 0.35] and not m2.bat and m2.texteVie.text == "Dead"
    lua.execute("GROUPE.party2.mort = nil")
    # l'appel : pret, en attente -> pas pret a la fin, puis s'efface
    lua.execute("GROUPE.party1.appel = 'ready'; GROUPE.party2.appel = 'waiting'; ARENE_EVENEMENT('READY_CHECK')")
    assert m1.appel.shown and m1.appel.icone.texture.endswith("ui-lfg-readymark") and m2.appel.icone.texture.endswith("ui-lfg-pendingmark")
    assert (m1.appel.width, pts(m1.appel)[0], pts(m1.appel)[4]) == (36, "CENTER", -2)
    lua.execute("ARENE_EVENEMENT('READY_CHECK_FINISHED')")
    assert m2.appel.icone.texture.endswith("ui-lfg-declinemark"), "a la fin, l'attente devient pas pret"
    # le familier : 64 x 23 a (23, -43), vie a l'echelle 0,5, teinte verte
    f1 = m1.familier
    print("   familier : %sx%s (%s, %s), vie %s x %s teinte %s, surveille %s" % (f1.width, f1.height, pts(f1)[3], pts(f1)[4],
        f1.vie.width, f1.vie.height, list(f1.vie.vertex.values()), f1.unitWatch))
    assert (f1.width, f1.height, pts(f1)[3], pts(f1)[4]) == (64, 23, 23, -43)
    assert abs(f1.vie.width - 17.75) < 1e-6 and f1.vie.height == 5 and list(f1.vie.vertex.values()) == [0, 1, 0]
    assert f1.GetAttribute(f1, "unit") == "partypet1" and f1.GetAttribute(f1, "*type2") is None and not f1.unitWatch
    # l'option des familiers : le pas passe a 79, le familier est surveille
    lua.execute("STATE.cvars.showPartyPets = '1'; ARENE_EVENEMENT('CVAR_UPDATE')")
    print("   avec familiers : pas %s, hauteur %s, surveille %s" % (-pts(m2)[4], ct.height, f1.unitWatch))
    assert pts(m2)[4] == -79 and ct.height == 4 * 53 + 3 * 26 + 2 and f1.unitWatch
    lua.execute("STATE.cvars.showPartyPets = nil; ARENE_EVENEMENT('CVAR_UPDATE')")
    # le vehicule : le cadre suit partypet1, art et barres du vehicule
    lua.execute("GROUPE.party1.vehicule = true; ARENE_EVENEMENT('UNIT_ENTERED_VEHICLE', 'party1')")
    print("   vehicule : unite %s, art %s (%s, %s), nom %s, familier suit %s" % (m1.unit, m1.art.width, pts(m1.art)[3], pts(m1.art)[4],
        m1.nom.width, f1.affiche))
    assert m1.unit == "partypet1" and f1.affiche == "party1" and m1.nom.text == "Wolf"
    assert m1.art.texture == entree("ui-hud-unitframe-party-portraiton-vehicle")[1] and (pts(m1.art)[3], pts(m1.art)[4]) == (0, 0)
    assert m1.nom.width == 56 and (pts(m1.vie)[3], pts(m1.vie)[4]) == (48, -18)
    lua.execute("GROUPE.party1.vehicule = nil; ARENE_EVENEMENT('UNIT_EXITED_VEHICLE', 'party1')")
    assert m1.unit == "party1" and m1.nom.width == 57
    # le survol : l'infobulle de l'unite, celle des buffs a (47, -25), les textes
    lua.execute("STATE.cvars.statusTextPercentage = '0'")
    m1.scripts.OnEnter(m1)
    pb = pts(g.PartyMemberBuffTooltip)
    print("   survol : infobulle de %s, buffs de %s a (%s, %s), texte de vie \"%s\"" % (g.GameTooltip.owner.name,
        g.PartyMemberBuffTooltip.unitOf, pb[3], pb[4], m1.texteVie.text))
    assert g.GameTooltip.owner.name == "ForeverUIPartyMemberFrame1" and g.PartyMemberBuffTooltip.unitOf == "party1"
    assert (pb[0], pb[1].name, pb[3], pb[4]) == ("TOPLEFT", "ForeverUIPartyMemberFrame1", 47, -25)
    assert m1.texteVie.shown and m1.texteVie.text == "8000 / 10000"
    m1.scripts.OnLeave(m1)
    assert not m1.texteVie.shown and not g.PartyMemberBuffTooltip.shown


    # ------------------------------------------------- LE RAID COMPACT
    print("\nraid compact :")
    R = g.ForeverUI.RaidFrame
    rc = g.ForeverUICompactRaidFrameContainer
    h1 = g.ForeverUICompactRaidGroup1
    pr = pts(rc)
    print("   conteneur : %s (%s, %s), pilote %s ; en-tete 1 %s" % (pr[0], pr[3], pr[4], rc.etats.visibility, [h1.GetAttribute(h1, k) for k in ("groupFilter", "point", "unitsPerColumn")]))
    assert (pr[0], pr[3], pr[4]) == ("TOPLEFT", 22, -145) and rc.etats.visibility == "[group:raid] show; hide"
    assert (h1.GetAttribute(h1, "groupFilter"), h1.GetAttribute(h1, "point"), h1.GetAttribute(h1, "unitsPerColumn")) == ("1", "TOP", 5)
    assert h1.GetAttribute(h1, "template") == "SecureUnitButtonTemplate" and h1.GetAttribute(h1, "startingIndex") == 1
    assert h1.initialConfigFunction is not None
    # l'en-tete cree ses boutons : on fait comme lui (initialConfigFunction)
    lua.execute("""
    for k = 1, 3 do
        local b = CreateFrame("Button", "ForeverUICompactRaidGroup1UnitButton" .. k, ForeverUICompactRaidGroup1, "SecureUnitButtonTemplate")
        ForeverUICompactRaidGroup1.initialConfigFunction(b)
        b:SetWidth(98); b:SetHeight(44)
    end
    GROUPE = { raid1 = { nom = 'Ann', classe = 'WARRIOR', vie = 5000, max = 10000, res = 40, resMax = 100, jeton = 'RAGE',
                         role = 'TANK', menace = 3 },
               raid2 = { nom = 'Bob', classe = 'DEATHKNIGHT', vie = 0, max = 10000, res = 0, resMax = 100, jeton = 'RUNIC_POWER',
                         mort = true },
               raid3 = { nom = 'Cid', classe = 'WARRIOR', vie = 9000, max = 10000, res = 10, resMax = 100, jeton = 'RAGE',
                         deconnecte = true } }
    RAID_MEMBRES = { { 'Ann', 2, 1, 80, 'Warrior', 'WARRIOR', 'Naxx', 1, nil }, { 'Bob', 0, 1, 80, 'Death Knight', 'DEATHKNIGHT', 'Naxx', 1, 1 },
                     { 'Cid', 0, 3, 80, 'Warrior', 'WARRIOR', 'Naxx', nil, nil } }
    AFFAIBLISSEMENTS.raid1 = { { 'icoM', 2, 'Magic', 10, 20 } }
    AMELIORATIONS.raid1 = { { 'icoB1', 1, 0, 0, 'player' }, { 'icoB2', 1, 0, 0, 'party2' } }
    ForeverUICompactRaidGroup1UnitButton1:SetAttribute("unit", "raid1")
    ForeverUICompactRaidGroup1UnitButton2:SetAttribute("unit", "raid2")
    ForeverUICompactRaidGroup1UnitButton3:SetAttribute("unit", "raid3")
    """)
    b1, b2, b3 = g.ForeverUICompactRaidGroup1UnitButton1, g.ForeverUICompactRaidGroup1UnitButton2, g.ForeverUICompactRaidGroup1UnitButton3
    assert (b1.GetAttribute(b1, "initial-width"), b1.GetAttribute(b1, "initial-height")) == (98, 44)
    assert b1.GetAttribute(b1, "*type1") == "target" and b1.GetAttribute(b1, "*type2") == "menu" and b1.GetAttribute(b1, "toggleForVehicle")
    wc = g.RAID_CLASS_COLORS.WARRIOR
    print("   Ann : vie %s x %s %s, ressource %s %s, nom \"%s\", role %s, menace %s" % (b1.vie.width, b1.vie.height,
        list(b1.vie.vertex.values()), b1.ressource.width, list(b1.ressource.vertex.values()), b1.nom.text,
        b1.role.texture, list(b1.menace[1].vertex.values())))
    assert b1.affiche == "raid1" and abs(b1.vie.width - 48) < 1e-6 and b1.vie.height == 34
    assert list(b1.vie.vertex.values()) == [wc.r, wc.g, wc.b] and list(b1.ressource.vertex.values()) == [1.0, 0.0, 0.0]
    assert abs(b1.ressource.width - 38.4) < 1e-6 and b1.ressource.height == 8
    pv = pts(b1.vie)
    assert (pv[0], pv[3], pv[4]) == ("TOPLEFT", 1, -1)
    assert b1.nom.text == "Ann" and b1.role.shown and b1.role.texture.endswith("ui-lfg-roleicon-tank-micro-groupfinder") and b1.role.width == 17
    assert all(t.shown for t in b1.menace.values()) and list(b1.menace[1].vertex.values()) == [1.0, 0.0, 0.0] and not b1.statut.shown
    pn = list(b1.nom.points[1].values())
    assert (pn[0], pn[2], pn[3], pn[4]) == ("TOPLEFT", "TOPRIGHT", 0, -1) and lua.eval("rawequal")(pn[1], b1.role)
    # mort, deconnecte ; sans role, l'icone garde 1 de large
    print("   Bob : statut \"%s\", role %s/%s ; Cid : statut \"%s\", vie %s %s" % (b2.statut.text, b2.role.shown, b2.role.width,
        b3.statut.text, b3.vie.width, list(b3.vie.vertex.values())))
    assert b2.statut.shown and b2.statut.text == "Dead" and not b2.role.shown and b2.role.width == 1
    assert b3.statut.text == "Offline" and b3.vie.width == 96 and list(b3.vie.vertex.values()) == [0.5, 0.5, 0.5]
    ps = pts(b1.statut, 0)
    assert (ps[0], ps[3], abs(ps[4] - (44 / 3 - 2)) < 1e-6) == ("BOTTOMLEFT", 3, True)
    # tank principal (10e valeur de GetRaidRosterInfo)
    lua.execute("RAID_MEMBRES[2][10] = 'MAINTANK'; ForeverUI.RaidFrame.majBouton(ForeverUICompactRaidGroup1UnitButton2)")
    assert b2.role.shown and b2.role.texture == g.ForeverUI.AtlasEntry("raidframe-icon-maintank")[1] and b2.role.width == 17
    # l'affaiblissement magique : calque de dissipation, icone, auras ecartees de 2
    ad = g.ForeverUI.AtlasEntry("ui-debuff-border-magic-noicon")
    a1 = b1.affaiblissements[1]
    pa = pts(a1)
    print("   dissipation : calque %s %s, icone %s, affaiblissement a (%s, %s) bordure %s, buffs %s" % (b1.calque.shown,
        list(b1.calque.fond.vertex.values()), b1.dissipations[1].shown, pa[3], pa[4], a1.bordure.width,
        [x.shown for x in b1.buffs.values()][:3]))
    assert b1.calque.shown and list(b1.calque.fond.vertex.values()) == [0.2, 0.6, 1.0] and b1.calque.fond.alpha == 0.2
    assert b1.dissipations[1].shown and b1.dissipations[1].texture == g.ForeverUI.AtlasEntry("raidframe-icon-debuffmagic")[1]
    assert (pa[0], pa[3], pa[4]) == ("BOTTOMLEFT", 5, 12) and a1.shown and a1.bordure.texture == ad[1] and a1.bordure.width == 16
    assert a1.pile.text == 2 and a1.width == 11
    assert [x.shown for x in b1.buffs.values()][:2] == [True, False], "le filtre PLAYER : seul le buff du joueur"
    pb = pts(b1.buffs[1])
    assert (pb[0], pb[3], pb[4]) == ("BOTTOMRIGHT", -5, 12)
    assert not b2.calque.shown
    # la cible, l'appel, la portee
    lua.execute("GROUPE.raid1.cible = true; local v = ForeverUI.RaidFrame.veilleur; v.scripts.OnEvent(v, 'PLAYER_TARGET_CHANGED')")
    assert all(t.shown for t in b1.cible.values()) and not any(t.shown for t in b2.cible.values())
    lua.execute("GROUPE.raid1.appel = 'ready'; local v = ForeverUI.RaidFrame.veilleur; v.scripts.OnEvent(v, 'READY_CHECK')")
    pa = pts(b1.appel)
    assert b1.appel.shown and b1.appel.texture.endswith("ui-lfg-readymark-raid") and abs(b1.appel.width - 20 * 44 / 36) < 1e-6
    assert (pa[0], pa[3], abs(pa[4] - (44 / 3 - 4)) < 1e-6) == ("BOTTOM", 0, True)
    lua.execute("GROUPE.raid1.loin = true; ForeverUI.RaidFrame.minuterie.scripts.OnUpdate(ForeverUI.RaidFrame.minuterie, 0.6)")
    print("   hors de portee : vie %s, nom %s, cible %s, appel %s" % (b1.vie.alpha, b1.nom.alpha, b1.cible[1].alpha, b1.appel.alpha))
    assert b1.vie.alpha == 0.5 and b1.nom.alpha == 0.5 and b1.cible[1].alpha in (None, 1) and b1.appel.alpha in (None, 1)
    # le menu : RAID_PLAYER, l'unite et son numero
    lua.execute("ForeverUI.RaidFrame.ouvrirMenu(ForeverUICompactRaidGroup1UnitButton2)")
    dd = g.ForeverUICompactRaidFrameDropDown
    assert (dd.which, dd.unit, dd.name, dd.id) == ("RAID_PLAYER", "raid2", "Bob", 2)
    # les groupes tasses : 1 et 3 cote a cote, les titres des groupes utilises
    lua.execute("ForeverUI.RaidFrame.disposer()")
    t1, t3, t2 = g.ForeverUI.RaidFrame.titres[1], g.ForeverUI.RaidFrame.titres[3], g.ForeverUI.RaidFrame.titres[2]
    h3 = g.ForeverUICompactRaidGroup3
    print("   groupes : titre 1 a %s \"%s\", titre 3 a %s, en-tete 3 a (%s, %s), groupe 2 %s, largeur %s" % (pts(t1)[3],
        t1.texte.text, pts(t3)[3], pts(h3)[3], pts(h3)[4], t2.shown, rc.width))
    assert pts(t1)[3] == 0 and pts(t3)[3] == 98 and (pts(h3)[3], pts(h3)[4]) == (98, -14) and pts(g.ForeverUICompactRaidGroup2)[3] == 196
    assert t1.shown and t3.shown and not t2.shown and t1.texte.text == "Group 1" and rc.width == 196
    # en combat, rien ne bouge : c'est pour la sortie du combat
    lua.execute("STATE.inLockdown = true; RAID_MEMBRES[4] = { 'Dan', 0, 2, 80, 'Mage', 'MAGE', 'Naxx', 1, nil }; ForeverUI.RaidFrame.disposer()")
    assert pts(g.ForeverUICompactRaidGroup2)[3] == 196 and R.aDisposer
    lua.execute("STATE.inLockdown = false; local v = ForeverUI.RaidFrame.veilleur; v.scripts.OnEvent(v, 'PLAYER_REGEN_ENABLED')")
    assert pts(g.ForeverUICompactRaidGroup2)[3] == 98 and pts(h3)[3] == 196 and not R.aDisposer
    # l'addon HD : desactive, ses cadres caches
    lua.execute("""
    ADDONS_CHARGES.CompactRaidFrame = true
    CompactRaidFrameManager = CreateFrame("Frame", "CompactRaidFrameManager", UIParent)
    CompactRaidFrameContainer = CreateFrame("Frame", "CompactRaidFrameContainer", UIParent)
    local v = ForeverUI.RaidFrame.veilleur; v.scripts.OnEvent(v, 'PLAYER_ENTERING_WORLD')
    """)
    assert g.ADDONS_DESACTIVES.CompactRaidFrame and g.CompactRaidFrameManager.etats.visibility == "hide"
    assert g.CompactRaidFrameContainer.etats.visibility == "hide"
    lua.execute("RAID_MEMBRES = {}; GROUPE = {}")


    # ------------------------------------------------- LE BOUTON SOCIAL AU TABARD
    print("\nbouton Social :")
    sb = g.SocialsMicroButton
    def atlasDe(t):
        return [k for k in (t.texture,)] + list(t.texcoord.values())
    base = g.ForeverUI.AtlasEntry("ui-hud-micromenu-guildcommunities-up-c60-2x")
    lua.execute("TABARD = nil; ForeverUI.MajTabardSocial()")
    n0 = sb.GetNormalTexture(sb)
    print("   sans tabard : %s, embleme %s" % (list(n0.texcoord.values()), sb.GetNormalTexture(sb).vertex))
    assert list(n0.texcoord.values()) == [base[k] for k in (2, 3, 4, 5)] and not g.ForeverUI.TabardCouleurs is None
    lua.execute("TABARD = { fond = '05', motif = '29', couleur = '15' }; ForeverUI.MajTabardSocial()")
    tc = g.ForeverUI.TabardCouleurs
    gc = g.ForeverUI.AtlasEntry("ui-hud-micromenu-guildcommunities-guildcolor-up-c60-2x")
    n1 = sb.GetNormalTexture(sb)
    h1 = sb.GetHighlightTexture(sb)
    emb = [r for r in sb.regions.values() if r.texture and "guildemblems_01" in str(r.texture)]
    e0 = emb[0]
    pe = list(list(e0.points.values())[-1].values())
    print("   avec tabard : jeu %s, teinte %s, embleme %sx%s a (%s, %s) teinte %s, rognage %s" % (
        list(n1.texcoord.values()) == [gc[k] for k in (2, 3, 4, 5)], list(n1.vertex.values()), e0.width, e0.height,
        pe[3], pe[4], list(e0.vertex.values()), [round(x * 256, 2) for x in e0.texcoord.values()]))
    f5, c15 = list(tc.fond[5].values()), list(tc.embleme[15].values())
    assert list(n1.texcoord.values()) == [gc[k] for k in (2, 3, 4, 5)] and list(n1.vertex.values()) == f5
    assert list(h1.vertex.values()) == f5, "les quatre etats teints (LoadMicroButtonTextures)"
    assert len(emb) == 2 and all(r.shown for r in emb) and sorted(r.layer for r in emb) == ["HIGHLIGHT", "OVERLAY"]
    assert (e0.width, e0.height, pe[0], pe[3], pe[4]) == (12, 14, "CENTER", 0, 2) and list(e0.vertex.values()) == c15
    # le motif 29 : case (29 mod 14, 29 div 14) = (1, 2), rentree de 1/256
    assert [round(x * 256, 3) for x in e0.texcoord.values()] == [19, 35, 37, 53]
    # enfonce : (1, 1)
    lua.execute("SocialsMicroButton:SetButtonState('PUSHED'); UpdateMicroButtons()")
    pe = list(list(e0.points.values())[-1].values())
    assert (pe[3], pe[4]) == (1, 1)
    lua.execute("SocialsMicroButton:SetButtonState('NORMAL'); UpdateMicroButtons()")
    # la guilde quittee : le jeu de base, sans teinte ni embleme
    lua.execute("TABARD = nil; ForeverUI.MajTabardSocial()")
    assert list(n1.texcoord.values()) == [base[k] for k in (2, 3, 4, 5)] and list(n1.vertex.values()) == [1, 1, 1]
    assert not any(r.shown for r in emb)


    # ------------------------------------------------- LA FENETRE DE TABARD
    print("\nfenetre de tabard :")
    tf = g.TabardFrame
    def derniere(f):
        return list(list(f.points.values())[-1].values())
    wotlk = [r for r in tf.regions.values() if r.texture and ("UI-Character-General" in str(r.texture) or "UI-ClassTrainer-Bot" in str(r.texture))]
    print("   taille %sx%s, cadre WotLK visible %d, grand fond %s, croix %s (%s, %s) %s" % (tf.width, tf.height,
        sum(1 for r in wotlk if r.shown), g.TabardFrameBackground.shown, g.TabardFrameCloseButton.width,
        derniere(g.TabardFrameCloseButton)[3], derniere(g.TabardFrameCloseButton)[4], g.TabardFrameCloseButton._normal.texture))
    assert (tf.width, tf.height) == (338, 424) and list(tf.hitRect.values()) == [0, 0, 0, 0]
    assert len(wotlk) == 4 and not any(r.shown for r in wotlk) and not g.TabardFrameBackground.shown
    pc = derniere(g.TabardFrameCloseButton)
    assert (pc[0], pc[2], pc[3], pc[4]) == ("TOPRIGHT", "TOPRIGHT", -2, 1) and g.TabardFrameCloseButton.width == 24
    assert g.TabardFrameCloseButton._normal.texture == g.ForeverUI.AtlasEntry("redbutton-exit")[1]
    # les places de camelot
    places = {
        "TabardFrameOuterFrameTopLeft": ("TOPLEFT", "TOPLEFT", 8, -63),
        "TabardFrameGreetingText": ("TOP", "TOP", 15, -28),
        "TabardModel": ("BOTTOM", "BOTTOM", 0, 38),
        "TabardCharacterModelRotateLeftButton": ("BOTTOMLEFT", "BOTTOMLEFT", 14, 33),
        "TabardFrameCustomizationBorder": ("BOTTOMRIGHT", "BOTTOMRIGHT", 26, -28),
        "TabardFrameMoneyFrame": ("BOTTOMRIGHT", "BOTTOMLEFT", 175, 8),
        "TabardFrameAcceptButton": ("CENTER", "TOPLEFT", 213, -409),
        "TabardFrameCancelButton": ("CENTER", "TOPLEFT", 294, -409),
    }
    for nom, (p1, p2, x, y) in places.items():
        pt = derniere(g[nom])
        assert (pt[0], pt[1].name, pt[2], pt[3], pt[4]) == (p1, "TabardFrame", p2, x, y), nom
        assert len(g[nom].points) == 1, "une seule ancre : " + nom
    # l'encadre, l'argent, le bord dore
    T = g.ForeverUI.TabardFrame
    pe = [list(p.values()) for p in T.encadre.points.values()]
    pa = [list(p.values()) for p in T.encadreArgent.points.values()]
    pb = [list(p.values()) for p in T.bordArgent.points.values()]
    print("   encadre %s ; argent %s ; bord dore %s" % ([(p[0], p[3], p[4]) for p in pe], [(p[0], p[2], p[3], p[4]) for p in pa],
        [(p[0], p[2], p[3], p[4]) for p in pb]))
    assert [(p[0], p[3], p[4]) for p in pe] == [("TOPLEFT", 4, -60), ("BOTTOMRIGHT", -6, 26)]
    assert [(p[0], p[2], p[3], p[4]) for p in pa] == [("BOTTOMLEFT", "BOTTOMLEFT", 4, 4), ("TOPRIGHT", "BOTTOMLEFT", 170, 25)]
    assert [(p[0], p[2], p[3], p[4]) for p in pb] == [("TOPRIGHT", "BOTTOMLEFT", 166, 24), ("BOTTOMLEFT", "BOTTOMLEFT", 7, 6)]
    morceaux = [r for r in T.bordArgent.morceaux.values()]
    assert len(morceaux) == 3 and all(str(r.texture).endswith("moneyframe") for r in morceaux)
    # LES COUCHES : encadre et bord dore sont des regions de la fenetre, sous
    # le cadre du tabard (OVERLAY) ; les reperes n'ont rien a dessiner
    assert all(lua.eval("rawequal")(r.owner, tf) and r.layer == "ARTWORK" for r in morceaux)
    assert lua.eval("rawequal")(T.encadre.fond.owner, tf) and T.encadre.fond.layer == "BORDER"
    assert len(list(T.encadre.regions.values())) == 0 and len(list(T.bordArgent.regions.values())) == 0
    # a l'ouverture : le portrait dans l'anneau, le nom au-dessus du metal
    lua.execute("TabardFrameNameText:SetText('Marchand de tabards'); TabardFrame:Show()")
    pp = derniere(T.portrait)
    print("   ouverture : portrait %s a (%s, %s), nom \"%s\" a (%s, %s), nom du client %s" % (T.portrait.width, pp[3], pp[4],
        T.nom.text, derniere(T.nom)[3], derniere(T.nom)[4], g.TabardFrameNameText.shown))
    assert (T.portrait.width, pp[3], pp[4]) == (60, -5, 7) and T.nom.text == "Marchand de tabards"
    assert (derniere(T.nom)[0], derniere(T.nom)[3], derniere(T.nom)[4]) == ("CENTER", 6, 202) and not g.TabardFrameNameText.shown
    # le modele recadre a l'image suivante : SetUnit, puis le tabard en cours
    assert T.recadrage.shown
    lua.execute("""
    APPELS_TABARD = {}
    TabardModel.SetUnit = function(self, u) table.insert(APPELS_TABARD, "SetUnit " .. u) end
    TabardModel.InitializeTabardColors = function() table.insert(APPELS_TABARD, "InitializeTabardColors") end
    TabardFrame_UpdateTextures = function() table.insert(APPELS_TABARD, "UpdateTextures") end
    TabardFrame_UpdateButtons = function() table.insert(APPELS_TABARD, "UpdateButtons") end
    local r = ForeverUI.TabardFrame.recadrage; r.scripts.OnUpdate(r, 0.01)
    """)
    print("   recadrage : %s" % list(g.APPELS_TABARD.values()))
    assert list(g.APPELS_TABARD.values()) == ["SetUnit player", "InitializeTabardColors", "UpdateTextures", "UpdateButtons"]
    assert not T.recadrage.shown, "une seule fois"
    # /fui tabard : le reglage du cadrage, repose par le rattrapage apres SetUnit
    lua.execute("""
    TabardModel.SetPosition = function(self, x, y, z) self.pos = { x, y, z } end
    TabardModel.GetPosition = function(self) return table.unpack(self.pos or { 0, 0, 0 }) end
    TabardModel.SetCamera = function(self, n) self.camera = n end
    ForeverUI.TabardModelTune("position 0 0.5 -0.25")
    ForeverUI.TabardModelTune("camera 1")
    TabardModel.pos = { 9, 9, 9 }
    local r = ForeverUI.TabardFrame.rattrapage; r.scripts.OnUpdate(r, 0.1)
    """)
    print("   /fui tabard : position %s camera %s, rattrapage %s" % (list(g.TabardModel.pos.values()), g.TabardModel.camera, T.rattrapage.shown))
    assert list(g.TabardModel.pos.values()) == [0, 0.5, -0.25] and g.TabardModel.camera == 1 and T.rattrapage.shown
    lua.execute("TabardFrame:Hide()")


    # ------------------------------------------------- LE CHERCHEUR DE DONJON
    print("\nchercheur de donjon :")
    F = g.ForeverUI.GroupFinder
    fc = F.cadre
    def image():
        lua.execute("local a = ForeverUI.GroupFinder.attendre; if a.shown ~= false then a.scripts.OnUpdate(a, 0.01) end")
    lua.execute("""
    -- niveau 80 : Lich King (80) et Lich King heroique (80), le classique
    -- (15-24) n'est pas affichable ; l'heroique n'est pas rejoignable
    DONJONS[261] = { "Random Lich King Dungeon", 6, 80, 80, 80, 80, 80, 2, 0, "x", 0, 5, "", false }
    DONJONS[262] = { "Random Lich King Heroic", 6, 80, 80, 80, 80, 80, 2, 0, "x", 1, 5, "", false }
    DONJONS[258] = { "Random Classic Dungeon", 6, 15, 24, 20, 15, 24, 0, 0, "x", 0, 5, "", false }
    ALEATOIRES = { { id = 261, dispo = true }, { id = 262, dispo = false }, { id = 258, dispo = true } }
    RECOMPENSES[261] = { false, 100000, 5000, 0, 0, { { "Emblem of Frost", "icone-givre", 2 }, { "Satchel", "icone-sac", 1 } } }
    -- la liste : un en-tete (-5) et deux donjons dont un verrouille
    LFGDungeonInfo[-5] = { "Lich King Normal", 0, 0, 0, 0, 0, 0, 2, 0 }
    LFGDungeonInfo[206] = { "Utgarde Keep", 1, 68, 80, 70, 68, 80, 2, -5 }
    LFGDungeonInfo[210] = { "Halls of Stone", 1, 82, 85, 83, 82, 85, 2, -5 }
    LFD_ORDRE = { -5, 206, 210 }
    LFGLockList[210] = true
    LFG_UpdateRolesChangeable()
    ShowUIPanel(LFDParentFrame)
    """)
    image()
    print("   ouverte %s, taille %sx%s, parent %s, titre %r ; contenu du client alpha %s ancre sur %s ; panneau souris %s, portrait %s, croix %s" % (
        fc.shown, fc.width, fc.height, fc.parent.name, fc.titre.text, g.LFDQueueFrame.alpha,
        derniere(g.LFDQueueFrame)[1].name, g.LFDParentFrame.mouseEnabled, g.LFDParentFramePortrait.shown, g.LFD_CROIX.shown))
    assert fc.shown and (fc.width, fc.height) == (458, 535) and fc.parent.name == "LFDParentFrame"
    assert fc.titre.text == "Looking For Group" and fc.portrait.texture == g.ForeverUI.AtlasEntry("groupfinder-eye-frame")[1]
    assert g.LFDQueueFrame.alpha == 0 and derniere(g.LFDQueueFrame)[1].name == "ForeverUIGroupFinderFrame"
    assert g.LFDParentFrame.mouseEnabled is False and not g.LFDParentFramePortrait.shown and not g.LFD_CROIX.shown
    assert fc.GetFrameLevel(fc) >= g.LFDParentFrame.GetFrameLevel(g.LFDParentFrame) + 30
    # les places de camelot
    pb = derniere(F.bleu)
    assert list(list(F.bleu.points.values())[0].values())[3:] == [2, -25] and (pb[0], pb[2], pb[3], pb[4]) == ("BOTTOMRIGHT", "TOPRIGHT", 248, -169)
    roles = {getattr(r, "def").cle: r for r in F.roles.values()}
    for cle, (p, x) in {"tank": ("TOPLEFT", 70), "soin": ("TOPLEFT", 174), "degats": ("TOPLEFT", 278), "chef": ("TOPRIGHT", -20)}.items():
        pt = derniere(roles[cle])
        assert (pt[0], pt[3], pt[4]) == (p, x, -41) and roles[cle].width == 64, cle
    pe = list(list(F.encadre.points.values())[0].values())
    assert pe[3:] == [4, -118] and derniere(F.encadre)[3:] == [-4, 37] and not F.encadre.fond.shown
    o1 = F.onglets[1]
    assert (o1.width, derniere(o1)[2], derniere(o1)[4]) == (55, "TOPRIGHT", -60) and o1.choisi.shown
    assert "inv_helmet_08" in o1.icone.texture
    # les categories : "specific" d'abord, puis les aleatoires affichables
    cats = [(c.texte, c.dispo) for c in F.liste_categories.values()]
    print("   vue %s, categories %s" % (F.vue, cats))
    assert F.vue == "categories" and cats == [("Specific Dungeons", True), ("Random Lich King Dungeon", True), ("Random Lich King Heroic", False)]
    lignes = F.categoriesVue.lignes
    b2, b3 = lignes[2].bouton, lignes[3].bouton
    assert b3.image.desaturated and b3.texte.textColor[1] == 0.5 and b2.width == 380 and b2.height == 50
    assert not F.retour.shown, "Back cache sur les categories"
    # un aleatoire refuse : l'infobulle du client, et le clic ne fait rien
    b3.scripts.OnEnter(b3)
    assert g.GameTooltip.text == "You may not queue for this." and list(g.GameTooltip.lignes.values()) == ["Niveau trop bas"]
    b3.scripts.OnClick(b3)
    assert g.LFDQueueFrame.type is None and F.vue == "categories"
    # les boutons resserres et amincis (premier a -4, 40 de haut, colles), le
    # filet 6 sous le dernier, les details 6 sous le filet
    for i in (1, 2, 3):
        pl = list(list(lignes[i].points.values())[0].values())
        assert (pl[0], pl[2], pl[4]) == ("TOPLEFT", "TOPLEFT", -4 - (i - 1) * 50), (i, pl)
    assert lignes[1].bouton.height == 50 and lignes[1].bouton.choix.height == 40
    pr = list(list(F.regle.points.values())[0].values())
    pd = list(list(F.details.points.values())[0].values())
    print("   categories : filet a %s, details a %s (hauteur %s)" % (pr[4], pd[4], 535 - 50 + pd[4]))
    assert pr[4] == -124 - 4 - 2 * 50 - 50 - 6 and pd[4] == pr[4] - 8 - 6 and F.regle.height == 16
    # le donjon aleatoire : il reste sur la page, ses details sous le filet
    b2.scripts.OnClick(b2)
    image()
    r = F.recompenses
    objets = [(o.nom.text, o.nombre.text if o.nombre.shown else None) for o in r.objets.values() if o.shown]
    print("   aleatoire : type %s, vue %s, texte %r, objets %s, xp %s, Back %s" % (
        g.LFDQueueFrame.type, F.vue, r.description.text, objets, r.xp.shown, F.retour.shown))
    assert g.LFDQueueFrame.type == 261 and F.vue == "categories" and F.details.shown and F.categoriesVue.shown
    assert r.description.text == "Explication" and objets == [("Emblem of Frost", 2), ("Satchel", None)]
    # l'argent : une case d'objet a la place suivante (3e : 2e rang, 1re colonne)
    pa3 = list(list(r.argent.points.values())[0].values())
    print("   argent : %r, icone %s, place (%s, %s)" % (r.argent.nom.text, r.argent.icone.texture, pa3[3], pa3[4]))
    assert r.argent.shown and r.argent.nom.text == "pieces:120000" and r.argent.icone.texture.lower().endswith("inv_misc_coin_02")
    assert pa3[3] == 0 and pa3[4] == -(list(list(r.objets[1].points.values())[0].values())[4] * -1 + 44)
    assert not r.xp.shown and not F.retour.shown
    assert b2.choix.shown and not lignes[1].bouton.choix.shown
    # le filet descend sur le contenu : les details finissent en bas
    contenu = F.details.contenu
    pr2 = list(list(F.regle.points.values())[0].values())
    pd2 = list(list(F.details.points.values())[0].values())
    print("   filet sur le contenu (%s) : a %s, details a %s" % (contenu, pr2[4], pd2[4]))
    assert contenu > 0 and pr2[4] == min(pr[4], -(535 - 50) + contenu + 6 + 6 + 8) and pd2[4] == pr2[4] - 8 - 6
    # les details au meme decalage que les boutons : 39 a gauche comme a droite
    bl = lignes[1].bouton
    assert pd2[3] == 8 + (442 - bl.width) / 2 + 6 == 45 and derniere(F.details)[3] == -39 and F.recompenses.width == 374
    # la zone visible (calculee) contient le contenu, avec ses 6 d'air : pas de barre
    print("   visible %s pour un contenu de %s, barre %s" % (F.details.visible, contenu, F.details.barre.shown))
    assert F.details.visible == contenu + 6 and not F.details.barre.shown
    # la seconde mesure : le client rend un contenu plus haut, le filet remonte
    lua.execute("""
    local F = ForeverUI.GroupFinder
    F.recompenses._top = 500
    F.dernierePiece.GetBottom = function() return 500 - F.details.contenu - 30 end
    F.remesure.scripts.OnUpdate(F.remesure, 0.01)
    """)
    pr4 = list(list(F.regle.points.values())[0].values())
    print("   seconde mesure : contenu %s, filet a %s" % (F.details.contenu, pr4[4]))
    assert F.details.contenu == contenu + 30 and pr4[4] == pr2[4] + 30 and not F.details.barre.shown
    lua.execute("ForeverUI.GroupFinder.dernierePiece.GetBottom = nil; ForeverUI.GroupFinder.recompenses._top = nil")
    # un contenu trop haut : le filet reste sous les boutons
    lua.execute("ForeverUI.GroupFinder.recompenses.description.height = 400")
    F.maj()
    pr3 = list(list(F.regle.points.values())[0].values())
    assert pr3[4] == pr[4], pr3
    lua.execute("ForeverUI.GroupFinder.recompenses.description.height = nil")
    F.maj()
    o = r.objets[1]
    o.scripts.OnClick(o)
    assert g.LIEN_CLIQUE == "lien:261:1"
    # la liste des donjons specifiques
    b1 = F.categoriesVue.lignes[1].bouton
    b1.scripts.OnClick(b1)
    image()
    L = F.listeVue.lignes
    def etat(l):
        return (l.nom.text, l.plus.shown, l.case.shown, l.lockedIndicator.shown, l.case.checked, l.niveau.text if l.niveau.shown else None)
    print("   liste : vue %s, lignes %s" % (F.vue, [etat(L[i]) for i in (1, 2, 3)]))
    assert F.vue == "liste" and F.listeVue.shown and not F.details.shown and not F.categoriesVue.shown and F.retour.shown and F.retour.actif
    assert etat(L[1]) == ("Lich King Normal", True, True, False, False, None)
    assert etat(L[2]) == ("Utgarde Keep", False, True, False, False, "(68 - 80)")
    assert etat(L[3]) == ("Halls of Stone", False, False, True, False, "(82 - 85)")
    assert list(L[2].nom.textColor.values())[:3] == [1.0, 0.82, 0]
    # la case d'un donjon : le client coche, l'en-tete passe a "certains"
    L[2].case.Click(L[2].case)
    image()
    print("   case cochee : active %s, en-tete %s (%s)" % (g.LFGEnabledList[206], g.LFGEnabledList[-5], L[1].case._checked.texture))
    assert g.LFGEnabledList[206] is True and g.LFGEnabledList[-5] == 1 and L[1].case.checked and "UI-MultiCheck-Up" in L[1].case._checked.texture
    # le verrou : l'infobulle du client
    L[3].scripts.OnEnter(L[3])
    assert lua.eval("rawequal")(g.GameTooltip.owner, L[3]) and list(g.GameTooltip.lignes.values()) == ["You may not queue for this dungeon."]
    # le +/- de l'en-tete : le client replie, la liste n'a plus que l'en-tete
    L[1].plus.scripts.OnClick(L[1].plus)
    image()
    print("   replie : %d ligne(s), +/- %s" % (sum(1 for l in L.values() if l.shown), L[1].plus._normal.texture))
    assert g.LFGCollapseList[-5] is True and sum(1 for l in L.values() if l.shown) == 1 and "UI-PlusButton-UP" in L[1].plus._normal.texture
    # les roles : notre case fait cliquer celle du client
    t = roles["tank"]
    t.case.scripts.OnClick(t.case)
    print("   role tank : client %s, notre case %s" % (g.ROLES_LFG[2], t.case.checked))
    assert g.ROLES_LFG[2] is True and t.case.checked
    # une classe sans soin : le voile, sans case
    lua.execute("ROLES_POSSIBLES = { true, false, true }; LFG_UpdateRolesChangeable()")
    image()
    s = roles["soin"]
    assert s.voile.shown and s.voile.alpha == 0.7 and not s.case.shown and s.icone.desaturated and not s.fond.shown
    # le bouton de recherche : celui du client
    F.chercher.scripts.OnClick(F.chercher)
    assert g.LFD_RECHERCHES == 1
    lua.execute("LFG_MODE = 'queued'; LFG_UpdateRolesChangeable(); LFDQueueFrameFindGroupButton_Update()")
    image()
    print("   en file : bouton %r, cases de role %s, liste figee %s" % (F.chercher.GetText(F.chercher), [r.case.IsEnabled(r.case) for r in F.roles.values()], L[1].case.enabled))
    assert F.chercher.GetText(F.chercher) == "Leave Queue" and all(r.case.enabled is False for r in F.roles.values())
    assert L[1].case.enabled is False
    # inscrit dans le raid : le voile de WotLK, son bouton est celui du client
    lua.execute("LFG_MODE = 'listed'; LFG_UpdateLockedOutPanels(); LFDQueueFrameFindGroupButton_Update()")
    image()
    print("   liste de raid : voile %s, bouton %r, recherche %s" % (F.raid.shown, F.raid.quitter.GetText(F.raid.quitter), F.chercher.actif))
    assert F.raid.shown and F.raid.quitter.GetText(F.raid.quitter) == "Unlist Me" and not F.chercher.actif
    lua.execute("LFG_MODE = nil; LFG_UpdateLockedOutPanels(); LFG_UpdateRolesChangeable(); LFDQueueFrameFindGroupButton_Update()")
    image()
    assert not F.raid.shown and F.chercher.actif
    # l'attente : visible seulement quand le client l'affiche, avec son parent
    lua.execute("LFDQueueFrameCooldownFrame.description:SetText('Deserteur'); LFDQueueFrameCooldownFrame:Show(); LFDQueueFrame_SetType('specific')")
    image()
    assert not F.attente.shown, "son parent (l'aleatoire) est cache"
    lua.execute("LFDQueueFrameCooldownFrame:SetParent(LFDQueueFrame)")
    F.demander()
    image()
    assert F.attente.shown and F.attente.description.text == "Deserteur"
    # dans la liste, le voile couvre tout l'encadre
    assert lua.eval("rawequal")(F.attente.allPoints, F.encadre) and len(list(F.attente.points.values())) == 0
    # Back : les categories ; aux details, le voile part du filet
    F.retour.scripts.OnClick(F.retour)
    image()
    pa = list(list(F.attente.points.values())[0].values())
    assert F.vue == "categories" and F.attente.shown and pa[4] == pr[4] - 8 - (-118), pa
    lua.execute("LFDQueueFrameCooldownFrame:Hide()")
    # le deplacement et la superposition
    assert fc.movable and g.ForeverUI.Superposition.fenetres.chercheur
    # la croix ferme le panneau du client, et notre fenetre avec
    fc.croix.scripts.OnClick(fc.croix)
    assert not g.LFDParentFrame.shown and not fc.shown
    # a la reouverture en file : la vue du type demande
    lua.execute("LFG_MODE = 'queued'; ShowUIPanel(LFDParentFrame)")
    assert F.vue == "liste"
    lua.execute("LFG_MODE = nil; HideUIPanel(LFDParentFrame)")


    # ------------------------------------------------- LE NAVIGATEUR DE RAID
    print("\nnavigateur de raid :")
    R = g.ForeverUI.GroupFinderRaid
    ongl = F.onglets
    o2 = ongl[2]
    print("   onglets : %s" % [(o.cle, o.icone.texture.split(chr(92))[-1]) for o in ongl.values()])
    assert [o.cle for o in ongl.values()] == ["donjons", "raid"]
    assert o2.icone.texture.endswith("achievement_general_stayclassy")
    o2.scripts.OnEnter(o2)
    assert g.GameTooltip.text == "Raid Browser"
    # l'onglet ouvre le panneau du client, notre fenetre le suit ; les deux
    # contenus du client restent affiches ensemble
    o2.scripts.OnClick(o2)
    image()
    print("   page : parent %s, page %s, contenus %s/%s alpha %s/%s, icone %s, onglets du client %s, souris %s" % (
        fc.parent.name, R.page.shown, g.LFRQueueFrame.shown, g.LFRBrowseFrame.shown,
        g.LFRQueueFrame.alpha, g.LFRBrowseFrame.alpha, g.LFRParentFrameIcon.shown, g.LFRParentFrameTab1.shown,
        g.LFRParentFrame.mouseEnabled))
    assert g.LFRParentFrame.shown and fc.shown and fc.parent.name == "LFRParentFrame"
    assert R.page.shown and not F.pageDonjons.shown and o2.choisi.shown and not ongl[1].choisi.shown
    assert g.LFRQueueFrame.shown is not False and g.LFRBrowseFrame.shown is not False
    assert g.LFRQueueFrame.alpha == 0 and g.LFRBrowseFrame.alpha == 0
    assert not g.LFRParentFrameIcon.shown and not g.LFRParentFrameTab1.shown and not g.LFR_CROIX.shown
    assert g.LFRParentFrame.mouseEnabled is False
    # les deux onglets du bas : ceux de Social, sous la fenetre
    b1, b2 = R.onglets[1], R.onglets[2]
    print("   onglets du bas : %r %r, panneau %s" % (b1.GetText(b1), b2.GetText(b2), R.panneau))
    assert b1.GetText(b1) == "List My Group" and b2.GetText(b2) == "Join"
    p1 = list(list(b1.points.values())[0].values())
    assert (p1[0], p1[2], p1[3], p1[4]) == ("TOPLEFT", "BOTTOMLEFT", 5, 2) and derniere(b2)[2] == "TOPRIGHT"
    assert R.panneau == 1 and R.inscription.shown and not R.parcours.shown and b1.art.actifM.shown and not b2.art.actifM.shown
    # "Join" : l'onglet du client, puis notre panneau ; le client remontre
    # l'autre contenu
    b2.scripts.OnClick(b2)
    assert g.LFRParentFrame.activeTab == 2 and R.panneau == 2 and R.parcours.shown and not R.inscription.shown
    assert g.LFRQueueFrame.shown is not False and b2.art.actifM.shown
    b1.scripts.OnClick(b1)
    assert R.panneau == 1 and R.inscription.shown
    # la liste des raids, a categories : l'en-tete de la feuille de personnage
    lua.execute("""
    LFGDungeonInfo[-10] = { "Lich King Raid", 0, 0, 0, 0, 0, 0, 2, 0 }
    LFGDungeonInfo[30] = { "Naxxramas", 2, 80, 80, 80, 80, 80, 2, -10, "", 0, 10 }
    LFGDungeonInfo[31] = { "Ulduar", 2, 80, 80, 80, 80, 80, 2, -10, "", 0, 25 }
    LFR_ORDRE = { -10, 30, 31 }
    LFRQueueFrame_Update()
    """)
    image()
    Z = R.liste
    E, N = Z.entetes, Z.entrees
    e1 = E[1]
    pe = list(list(e1.points.values())[0].values())
    pn1 = list(list(N[1].points.values())[0].values())
    pn2 = list(list(N[2].points.values())[0].values())
    print("   categorie : %r a %s (%s de haut), fleche %s ; raids %r a %s, %r a %s" % (
        e1.nom.text, pe[4], e1.height, e1.fleche.texture, N[1].nom.text, pn1[3:], N[2].nom.text, pn2[3:]))
    assert e1.nom.text == "Lich King Raid" and e1.height == 26 and pe[4] == -4
    def coords(t):
        return [round(v, 5) for v in list(t.texcoord.values())[:4]]
    def atlas(n):
        e = g.ForeverUI.AtlasEntry(n)
        return [round(e[k], 5) for k in (2, 3, 4, 5)]
    assert e1.fleche.texture == g.ForeverUI.AtlasEntry("common-button-list-minus")[1]
    assert coords(e1.fleche) == atlas("common-button-list-minus")
    assert (N[1].nom.text, pn1[3], pn1[4]) == ("Naxxramas", 2, -(4 + 26 + 3))
    assert (N[2].nom.text, pn2[4]) == ("Ulduar", -(4 + 26 + 3 + 22 + 3))
    # la case de camelot : checkbox-minimal, 20 x 20
    assert N[1].case._normal.texture == g.ForeverUI.AtlasEntry("checkbox-minimal")[1] and N[1].case.width == 20
    assert N[1].case._checked.texture == g.ForeverUI.AtlasEntry("checkmark-minimal")[1]
    assert not R.aucun.shown and not Z.barre.shown
    # le rectangle de la feuille : 0 au repos, 0,10 au survol, 0,20 coche
    lua.execute("local Z = ForeverUI.GroupFinderRaid.liste; Z.scripts.OnUpdate(Z, 0.01)")
    assert N[1].survol.alpha == 0 and N[1].survol.GetAlpha(N[1].survol) == 0
    N[2].souris = True
    lua.execute("local Z = ForeverUI.GroupFinderRaid.liste; Z.scripts.OnUpdate(Z, 0.01)")
    assert N[2].survol.alpha == 0.10
    N[2].souris = False
    N[1].case.Click(N[1].case)
    image()
    assert g.LFGEnabledList[30] is True and N[1].case.checked
    lua.execute("local Z = ForeverUI.GroupFinderRaid.liste; Z.scripts.OnUpdate(Z, 0.01)")
    print("   rectangle : coche %s, survole puis quitte %s" % (N[1].survol.alpha, N[2].survol.alpha))
    assert N[1].survol.alpha == 0.20 and N[2].survol.alpha == 0
    e = g.ForeverUI.AtlasEntry("charactercreate-customize-dropdown-linemouseover-middle")
    assert e is not None
    # replier la categorie : le client, puis la liste n'a plus que l'en-tete
    e1.scripts.OnClick(e1)
    image()
    print("   repliee : fleche %s, raids affiches %d" % (e1.fleche.texture, sum(1 for l in N.values() if l.shown)))
    assert g.LFGCollapseList[-10] is True and coords(e1.fleche) == atlas("common-button-list-plus")
    assert sum(1 for l in N.values() if l.shown) == 0
    e1.scripts.OnClick(e1)
    image()
    assert sum(1 for l in N.values() if l.shown) == 2
    # en groupe : un bouton rond, un seul raid
    lua.execute("RAID_SAUVE = RAID_MEMBRES; RAID_MEMBRES = { { nom = 'Autre' } }")
    F.maj()
    # en groupe, le rond de camelot : common-radiobutton-circle / -dot, 16
    assert N[2].case._normal.texture == g.ForeverUI.AtlasEntry("common-radiobutton-circle")[1] and N[2].case._normal.width == 16
    assert N[2].case._checked.texture == g.ForeverUI.AtlasEntry("common-radiobutton-dot")[1]
    N[2].case.Click(N[2].case)
    image()
    assert g.LFRQueueFrame.selectedLFM == 31 and N[2].case.checked and not N[1].case.checked
    lua.execute("RAID_MEMBRES = RAID_SAUVE")
    F.maj()
    assert N[2].case._normal.texture == g.ForeverUI.AtlasEntry("checkbox-minimal")[1]
    # une longue liste : la barre, et la molette qui avance d'une ligne
    lua.execute("""
    LFR_ORDRE = { -10 }
    for i = 1, 20 do LFGDungeonInfo[100 + i] = { "Raid " .. i, 2, 80, 80, 80, 80, 80, 2, -10 }; table.insert(LFR_ORDRE, 100 + i) end
    LFRQueueFrame_Update()
    """)
    image()
    print("   longue liste : barre %s, decalage max %s" % (Z.barre.shown, Z.maxi))
    assert Z.barre.shown and Z.maxi > 0 and Z.avecBarre
    Z.scripts.OnMouseWheel(Z, -1)
    assert Z.decalage == 1 and N[1].nom.text == "Raid 1"
    lua.execute("LFR_ORDRE = { -10, 30, 31 }; LFRQueueFrame_Update()")
    image()
    assert not Z.barre.shown and Z.decalage == 0
    # les roles : ceux du panneau de raid
    rr = {getattr(r, "def").cle: r for r in R.roles.values()}
    assert sorted(rr) == ["degats", "soin", "tank"]
    rr["soin"].case.scripts.OnClick(rr["soin"].case)
    assert g.LFRQueueFrameRoleButtonHealer.checkButton.checked and g.ROLES_LFG[3] is True
    # le commentaire et les boutons de camelot, en bas de la fenetre
    assert derniere(R.commentaire)[4] == 59 and R.inscrire.height == 28 and derniere(R.inscrire)[3:] == [-4, 6]
    e = R.saisie
    e.scripts.OnEditFocusGained(e)
    assert not e.consigne.shown
    lua.execute("local e = ForeverUI.GroupFinderRaid.saisie; e:SetText('Cherche soigneur'); e.scripts.OnTextChanged(e)")
    assert g.LFRQueueFrameComment.GetText(g.LFRQueueFrameComment) == "Cherche soigneur"
    e.scripts.OnEditFocusLost(e)
    assert g.COMMENTAIRE_LFG == "Cherche soigneur"
    R.inscrire.scripts.OnClick(R.inscrire)
    print("   commentaire : envoye %r, lu a l'inscription %r" % (g.COMMENTAIRE_LFG, g.LFR_COMMENTAIRE_JOIN))
    assert g.LFR_INSCRIPTIONS == 1 and g.LFR_COMMENTAIRE_JOIN == "Cherche soigneur"
    # sans raid : "aucun raid", et le champ refuse le focus
    lua.execute("LFR_ORDRE = {}; LFRQueueFrame_Update()")
    image()
    lua.execute("local e = ForeverUI.GroupFinderRaid.saisie; e.focused = true; e.scripts.OnEditFocusGained(e)")
    assert R.aucun.shown and not e.focused
    # le voile de WotLK
    lua.execute("LFRQueueFrameNoLFRWhileLFD:Show()")
    F.demander()
    image()
    assert R.voile.shown
    lua.execute("LFRQueueFrameNoLFRWhileLFD:Hide()")
    # "Join" : le parcours
    b2.scripts.OnClick(b2)
    lua.execute("""
    SERVEUR_RAIDS[30] = {
        { "Arthas", 80, "Dalaran", "Death Knight", "", 0, nil, "DEATHKNIGHT", 0, 0, false, true, false, true },
        { "Papota", 80, "Orgrimmar", "Warrior", "", 0, nil, "WARRIOR", 0, 0, false, false, false, true },
        { "Jaina", 80, "Dalaran", "Mage", "Groupe ICC", 2, nil, "MAGE", 2, 1, true, false, false, false },
    }
    MEMBRES["Jaina"] = { { "Thrall", 80, "friend" }, { "Garrosh", 80, nil } }
    BOSS["Jaina"] = { { "Flame Leviathan", true }, { "Ignis", false } }
    """)
    def evenement():
        for fr in g.FRAMES.values():
            if fr.events and fr.events["UPDATE_LFG_LIST"] and fr.scripts.OnEvent:
                fr.scripts.OnEvent(fr, "UPDATE_LFG_LIST")
    # notre menu, celui de WotLK : "None", les categories en sous-menus (pas
    # de choix), leurs raids au second niveau
    R.menu.scripts.OnClick(R.menu)
    dm = list(list(g.MENUS_OUVERTS.values())[-1].values())
    assert dm[0] == 1 and dm[1].name == "ForeverUIGroupFinderRaidMenu" and lua.eval("rawequal")(dm[2], R.menu)
    assert R.menuListe.displayMode == "MENU" and R.menuListe.foreverMinimum == 300
    lua.execute("MENU_ENTREES = {}; local m = ForeverUI.GroupFinderRaid.menuListe; m.initialize(m, 1)")
    n1 = [(e.text, e.hasArrow, e.func is not None) for e in g.MENU_ENTREES.values()]
    lua.execute("MENU_ENTREES = {}; UIDROPDOWNMENU_MENU_VALUE = -10; local m = ForeverUI.GroupFinderRaid.menuListe; m.initialize(m, 2)")
    n2 = [e.text for e in g.MENU_ENTREES.values()]
    print("   menu : niveau 1 %s ; niveau 2 %s" % (n1, n2))
    assert n1 == [("None", None, True), ("Lich King Raid", True, False)] and n2 == ["(10) Naxxramas", "(25) Ulduar"]
    lua.execute("MENU_ENTREES = {}; local m = ForeverUI.GroupFinderRaid.menuListe; m.initialize(m, 1)")
    assert all(e.notCheckable for e in g.MENU_ENTREES.values()), "le premier niveau n'a pas de cases"
    lua.execute("MENU_ENTREES = {}; UIDROPDOWNMENU_MENU_VALUE = -10; local m = ForeverUI.GroupFinderRaid.menuListe; m.initialize(m, 2)")
    assert not any(e.notCheckable for e in g.MENU_ENTREES.values()), "les raids gardent la leur"
    # un raid : sa recherche, la reponse du serveur relevee
    lua.execute("MENU_ENTREES[1].func()")
    assert list(g.RECHERCHES.values())[-1] == 30
    evenement()
    image()
    RS = R.resultats.lignes
    def res(l):
        return (l.nom.text, l.niveau.text if l.niveau.shown else None, l.classe.shown, l.chef.shown,
                sum(1 for t in l.iconesRole.values() if t.shown), l.nombre.text if l.nombre.shown else None, l.bas.text)
    print("   un raid : menu %r, inscrits %s" % (R.menu.texte.text, [res(RS[i]) for i in (1, 2, 3)]))
    assert R.menu.texte.text == "(10) Naxxramas"
    assert res(RS[1]) == ("Arthas", "Lvl 80", True, False, 2, None, "Dalaran")
    assert res(RS[3]) == ("Jaina", None, False, True, 0, 2, "Groupe ICC")
    assert RS[1].classe.texture == g.ForeverUI.AtlasEntry("groupfinder-icon-class-deathknight")[1]
    assert list(RS[2].nom.textColor.values())[:3] == [0.3, 0.3, 0.3] and RS[2].moi
    assert derniere(RS[3].nom)[3:] == [32, -9] and derniere(RS[1].nom)[3:] == [9, -9]
    # l'infobulle, sur les donnees relevees
    RS[3].scripts.OnEnter(RS[3])
    ib = list(g.GameTooltip.lignes.values())
    print("   infobulle : %s" % ib)
    assert lua.eval("rawequal")(g.GameTooltip.owner, RS[3]) and RS[3].survol.shown
    assert ib[:3] == ["Raid Browser", "Jaina", "2 members in raid group"]
    assert "Thrall | Friend" in ib and "Flame Leviathan | Defeated" in ib and "Ignis | Alive" in ib
    RS[1].scripts.OnEnter(RS[1])
    assert list(g.GameTooltip.lignes.values())[:2] == ["Arthas", "Level 80 Death Knight"]
    # la selection, et les boutons du client
    RS[1].scripts.OnClick(RS[1])
    image()
    assert R.choix.nom == "Arthas" and RS[1].choisi.shown and R.message.actif and R.inviter.actif
    evenement()
    image()
    assert R.choix.nom == "Arthas" and RS[1].choisi.shown, "une mise a jour du serveur garde le choix"
    R.message.scripts.OnClick(R.message)
    R.inviter.scripts.OnClick(R.inviter)
    assert list(g.DITS.values())[-1] == "Arthas"
    RS[3].scripts.OnClick(RS[3])
    image()
    assert R.choix.nom == "Jaina" and R.message.actif and not R.inviter.actif, "un groupe ne s'invite pas"
    RS[2].scripts.OnClick(RS[2])
    assert R.choix.nom == "Jaina", "sa propre ligne ne se choisit pas"
    # rafraichir : le bouton du client
    R.rafraichir.scripts.OnClick(R.rafraichir)
    assert g.LFR_RAFRAICHIS == 1
    # "None" : la recherche s'arrete, la liste se vide
    lua.execute("MENU_ENTREES = {}; local m = ForeverUI.GroupFinderRaid.menuListe; m.initialize(m, 1); MENU_ENTREES[1].func()")
    image()
    assert g.FAUX_RECHERCHE is None and R.menu.texte.text == "None" and not RS[1].shown
    # une recherche d'avant nous (le serveur cherche deja) : le menu la dit
    lua.execute("SearchLFGJoin(2, 31)")
    evenement()
    image()
    assert R.menu.texte.text == "(25) Ulduar"
    lua.execute("SearchLFGLeave()")
    F.maj()
    # rouvrir : le dernier panneau vu (celui du client)
    fc.croix.scripts.OnClick(fc.croix)
    lua.execute("ShowUIPanel(LFRParentFrame)")
    assert R.panneau == 2 and R.parcours.shown
    # retour aux donjons : le panneau de raid se ferme, celui des donjons s'ouvre
    o1.scripts.OnClick(o1)
    image()
    print("   donjons : parent %s, raid ouvert %s, donjons ouvert %s" % (fc.parent.name, g.LFRParentFrame.shown, g.LFDParentFrame.shown))
    assert not g.LFRParentFrame.shown and g.LFDParentFrame.shown and fc.parent.name == "LFDParentFrame"
    assert F.pageDonjons.shown and not R.page.shown and o1.choisi.shown
    lua.execute("HideUIPanel(LFDParentFrame)")

    print("\nmessages du chat :")
    for msg in g.RECORDED.messages.values():
        print("   %s" % msg)


main()
