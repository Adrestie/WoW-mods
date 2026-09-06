--[[----------------------------------------------------------------------------
    faux_client.lua — le FAUX CLIENT WoW des bancs d'essai (éditeur et joueur).

    Cadres, textures et chaînes sont des tables qui comptent les appels ; la
    taille d'un cadre est explicite ou déduite de deux ancres TOPLEFT/BOTTOMRIGHT
    sur son parent. Rien n'est dessiné. Les fonctions de l'API du jeu que les
    deux interfaces appellent sont posées en globales, inertes.

    Usage :  local F = dofile("…/faux_client.lua")
      F.COMPTE (appels), F.razCompte(), F.TOUS (objets créés), F.PAR_NOM,
      F.CURSEUR (position rendue par GetCursorPosition), F.creer(genre, nom, parent)
------------------------------------------------------------------------------]]

local F = {}
local COMPTE = { Show = 0, Hide = 0, SetPoint = 0, ClearAllPoints = 0, SetTexture = 0,
                 SetVertexColor = 0, SetTexCoord = 0, cadres = 0, textures = 0, chaines = 0 }
local TOUS, PAR_NOM = {}, {}
local CURSEUR = { x = 0, y = 0 }
F.COMPTE, F.TOUS, F.PAR_NOM, F.CURSEUR = COMPTE, TOUS, PAR_NOM, CURSEUR
function F.razCompte() for k in pairs(COMPTE) do COMPTE[k] = 0 end end

local Obj = {}
Obj.__index = Obj
F.Obj = Obj

local function creer(genre, nom, parent)
    local o = setmetatable({ genre = genre, nom = nom, parent = parent, w = 0, h = 0,
                             montre = true, echelle = 1, hs = 0, vs = 0, alpha = 1,
                             points = {}, ordre = {}, scripts = {}, texte = "" }, Obj)
    TOUS[#TOUS + 1] = o
    if nom then PAR_NOM[nom] = o end
    return o
end
F.creer = creer

function Obj:GetWidth()
    if self.w > 0 then return self.w end
    if self.tout and self.parent then return self.parent:GetWidth() end
    local tl, br = self.points.TOPLEFT, self.points.BOTTOMRIGHT
    if tl and br and self.parent then return self.parent:GetWidth() + br.x - tl.x end
    return 0
end
function Obj:GetHeight()
    if self.h > 0 then return self.h end
    if self.tout and self.parent then return self.parent:GetHeight() end
    local tl, br = self.points.TOPLEFT, self.points.BOTTOMRIGHT
    if tl and br and self.parent then return self.parent:GetHeight() + tl.y - br.y end
    return 0
end
function Obj:SetWidth(w) self.w = w end
function Obj:SetHeight(h) self.h = h end
function Obj:SetPoint(point, a, b, c, d)
    COMPTE.SetPoint = COMPTE.SetPoint + 1
    local rel, relPoint, x, y
    if type(a) == "number" then
        x, y = a, b
    else
        rel = a
        if type(b) == "string" then relPoint, x, y = b, c, d else x, y = b, c end
    end
    if not self.points[point] then self.ordre[#self.ordre + 1] = point end
    self.points[point] = { point = point, rel = rel, relPoint = relPoint, x = x or 0, y = y or 0 }
end
function Obj:GetPoint(i)
    local p = self.points[self.ordre[i or 1]]
    if p then return p.point, p.rel, p.relPoint, p.x, p.y end
end
function Obj:ClearAllPoints()
    COMPTE.ClearAllPoints = COMPTE.ClearAllPoints + 1
    self.points, self.ordre = {}, {}
end
function Obj:SetAllPoints() self.tout = true end
function Obj:Show() COMPTE.Show = COMPTE.Show + 1; self.montre = true end
function Obj:Hide() COMPTE.Hide = COMPTE.Hide + 1; self.montre = false end
function Obj:IsShown() return self.montre end
function Obj:IsVisible() return self.montre end
function Obj:SetScript(ev, fn) self.scripts[ev] = fn end
function Obj:GetScript(ev) return self.scripts[ev] end
function Obj:HookScript(ev, fn) self.scripts[ev] = fn end
function Obj:SetText(t) self.texte = (t ~= nil) and tostring(t) or "" end
function Obj:GetText() return self.texte end
function Obj:SetTexture(a)
    COMPTE.SetTexture = COMPTE.SetTexture + 1
    if type(a) == "string" then self.chemin = a end
    return 1
end
function Obj:SetVertexColor() COMPTE.SetVertexColor = COMPTE.SetVertexColor + 1 end
function Obj:SetTexCoord() COMPTE.SetTexCoord = COMPTE.SetTexCoord + 1 end
function Obj:SetAlpha(a) self.alpha = a end
function Obj:GetAlpha() return self.alpha end
function Obj:CreateTexture(nomTex, calque)
    COMPTE.textures = COMPTE.textures + 1
    local t = creer("Texture", nomTex, self)
    t.calque = calque
    return t
end
function Obj:CreateFontString(nomChaine)
    COMPTE.chaines = COMPTE.chaines + 1
    return creer("FontString", nomChaine, self)
end
function Obj:GetHorizontalScroll() return self.hs end
function Obj:SetHorizontalScroll(v) self.hs = v end
function Obj:GetVerticalScroll() return self.vs end
function Obj:SetVerticalScroll(v) self.vs = v end
function Obj:SetScale(s) self.echelle = s end
function Obj:GetScale() return self.echelle end
function Obj:GetEffectiveScale() return self.echelle end
function Obj:GetLeft() return 0 end
function Obj:GetBottom() return 0 end
function Obj:GetTop() return self:GetHeight() end
function Obj:GetRight() return self:GetWidth() end
function Obj:SetScrollChild(c) self.enfant = c end
function Obj:GetFrameLevel() return 1 end
function Obj:HasFocus() return false end
function Obj:GetParent() return self.parent end
function Obj:GetName() return self.nom end
function Obj:GetNumPoints() return #self.ordre end
function Obj:UpdateScrollChildRect() end
for _, m in ipairs({ "AddLine", "SetBackdropColor", "SetBackdropBorderColor", "SetBackdrop",
    "SetTextColor", "RegisterForClicks", "ClearFocus", "SetOwner", "SetFrameLevel", "SetBlendMode",
    "EnableMouse", "SetTextInsets", "SetJustifyH", "SetFontObject", "SetAutoFocus", "RegisterForDrag",
    "StopMovingOrSizing", "StartMoving", "SetToplevel", "SetNumeric", "SetMovable", "SetDrawLayer",
    "EnableMouseWheel", "SetHyperlink", "SetFrameStrata", "SetClampedToScreen", "SetNormalTexture",
    "SetHighlightTexture", "SetPushedTexture", "SetFont", "SetShadowOffset", "SetJustifyV",
    "SetMaxLetters", "SetCursorPosition", "HighlightText", "SetFocus", "SetID", "Enable", "Disable",
    "SetNormalFontObject", "SetChecked", "SetMinMaxValues", "SetValue", "RegisterEvent",
    "UnregisterEvent", "SetSpellByID", "SetItemByID", "SetWordWrap", "SetNonSpaceWrap",
    "SetGradientAlpha", "SetDesaturated", "Raise", "Lower", "SetUserPlaced", "SetHitRectInsets",
    "SetDisabledTexture", "SetPushedTextOffset", "SetHighlightFontObject", "SetDisabledFontObject",
    "SetMinResize", "SetResizable", "SetTextHeight", "SetSpacing", "SetIndentedWordWrap" }) do
    Obj[m] = function() end
end

CreateFrame = function(genre, nomCadre, parent)
    COMPTE.cadres = COMPTE.cadres + 1
    return creer(genre, nomCadre, parent)
end
UIParent = creer("Frame", "UIParent")
UIParent.w, UIParent.h = 2133, 1200        -- 1920×1080 à l'échelle 0,64 (UI units)
GameTooltip = creer("GameTooltip", "GameTooltip")
GameFontNormal, GameFontNormalSmall, GameFontNormalLarge = {}, {}, {}
GameFontHighlight, GameFontHighlightSmall, GameFontDisableSmall, ChatFontNormal = {}, {}, {}, {}
GameTooltipText, GameTooltipTextSmall, GameTooltipHeaderText = {}, {}, {}
UISTYLE_BACKDROPS = nil
debugprofilestop = function() return os.clock() * 1000 end
GetTime = function() return os.clock() end
GetLocale = function() return "frFR" end
GetSpellInfo = function(id) return "Sort " .. tostring(id), "", "Interface\\Icons\\INV_Misc_QuestionMark" end
GetItemInfo = function() return nil end
GetItemQualityColor = function() return 1, 1, 1, "|cffffffff" end
ITEM_QUALITY_COLORS = { [0] = { r = 0.6, g = 0.6, b = 0.6 }, { r = 1, g = 1, b = 1 }, { r = 0.1, g = 1, b = 0 },
    { r = 0, g = 0.4, b = 0.8 }, { r = 0.6, g = 0.2, b = 0.9 }, { r = 1, g = 0.5, b = 0 } }
GetCursorPosition = function() return CURSEUR.x, CURSEUR.y end
GetCursorInfo = function() return nil end
CursorHasItem = function() return false end
ClearCursor = function() end
SetCursor = function() end
ResetCursor = function() end
IsMouseButtonDown = function() return false end
IsShiftKeyDown, IsControlKeyDown, IsAltKeyDown = function() return false end, function() return false end, function() return false end
-- Le masque rond du moteur : ici, seulement le chemin retenu sur la texture.
SetPortraitToTexture = function(tex, chemin)
    if type(tex) == "table" then tex.chemin = chemin end
end
SlashCmdList, UISpecialFrames, StaticPopupDialogs = {}, {}, {}
StaticPopup_Show = function() return { data = nil } end
StaticPopup_Hide = function() end
PlaySound = function() end
hooksecurefunc = function(a, b, c) end
GetTalentTabInfo = function() return nil end
GetNumTalentTabs = function() return 3 end
GetNumTalentGroups = function() return 1 end
GetActiveTalentGroup = function() return 1 end
GetContainerNumSlots = function() return 0 end
GetContainerItemInfo = function() return nil end
GetContainerItemLink = function() return nil end
GetContainerItemID = function() return nil end
PickupContainerItem = function() end
UseContainerItem = function() end
IsAddOnLoaded = function() return false end
LoadAddOn = function() return false end
PanelTemplates_TabResize = function() end
PanelTemplates_DeselectTab = function() end
PanelTemplates_SelectTab = function() end
InCombatLockdown = function() return false end
UnitClass = function() return "Guerrier", "WARRIOR" end
UnitName = function() return "Banc" end
tinsert, tremove = table.insert, table.remove
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end

return F
