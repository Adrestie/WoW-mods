-- ForeverUI: the pet tab, built on 3.3.5's PetPaperDollFrame (camelot shows the pet as a
-- right-pane sidebar instead). Left pane: the client's pet model. Right pane: the level, then
-- General (health, armor, damage, attack power, crit) and Resistances, laid out like the
-- character stats. Values are read from the client's own frames, which keep their formatting.
-- 3.3.5 has no pet crit API: the crit shown is only GetCritChanceFromAgility("pet").

local ForeverUI = ForeverUI or {}
_G.ForeverUI = ForeverUI
local L = ForeverUI.L

-- Same measures as the character stats (CharacterFrame.lua), so both pages share one edge.
local MARGIN = 20                        -- STAT_MARGIN
local STEP = 13                          -- STAT_STEP, one row's height
local HEADER_H = 34                     -- STAT_HEADER
local HEADER_OVERHANG = 5                 -- STAT_HEADER_OVERHANG
local GROUP_GAP = 16                -- STAT_GROUP_GAP
local TOP = 14                         -- below the pane's top
local LEVEL_H = 20
local LEVEL_GAP = -8

-- Rotation arrows, placed like the character's (placeModel in CharacterFrame.lua): centered
-- on the pane's top, side by side, above the model so they get the click. Both screens use
-- 35 x 35 buttons (client XML), so only the position changes.
local ROTATION_Y = -12
local ROTATION_GAP = 4

local ATLAS_HEADER = "ui-character-info-title"
local ATLAS_LEVEL = "ui-character-info-itemlevel-bounce"
local ATLAS_DARK_BACKGROUND = "ui-character-info-itemlevel-bounce"
local ATLAS_LIGHT_BACKGROUND = "ui-character-info-line-bounce"

-- Default pane sizes: a content may be built on first open, before the window is laid out.
local PANE_W = 233
local LEFT_PANE_W, LEFT_PANE_H = 398, 464

local panel, detail

-- ---------------------------------------------------------------- Data

local function hasPet()
    return (HasPetUI and HasPetUI()) and UnitExists and UnitExists("pet")
end

-- Reads a stat's text from the client's frame after letting the client compute it,
-- so the client keeps its formatting. place: the client's PaperDollFrame_Set* function.
local function readFromClient(frameName, place)
    local frame = _G[frameName]
    if not frame then
        return nil
    end
    if place then
        place(frame, "Pet")
    end
    local text = _G[frameName .. "StatText"]
    return text and text:GetText()
end

-- Rows of the General category: { name, value }.
local function readGeneral()
    local rows = {}

    rows[#rows + 1] = {
        name = HEALTH,
        value = tostring((UnitHealthMax and UnitHealthMax("pet")) or 0),
    }
    rows[#rows + 1] = {
        name = ARMOR,
        value = readFromClient("PetArmorFrame", PaperDollFrame_SetArmor) or "",
    }
    rows[#rows + 1] = {
        name = DAMAGE,
        value = readFromClient("PetDamageFrame", PaperDollFrame_SetDamage) or "",
    }
    -- ATTACK_POWER is "Power" in this client; ATTACK_POWER_TOOLTIP is "Attack Power".
    rows[#rows + 1] = {
        name = ATTACK_POWER_TOOLTIP or ATTACK_POWER,
        value = readFromClient("PetAttackPowerFrame",
            PaperDollFrame_SetAttackPower) or "",
    }

    -- Only the agility part of crit: 3.3.5 has no pet crit API.
    local critChance = (GetCritChanceFromAgility and GetCritChanceFromAgility("pet")) or 0
    rows[#rows + 1] = {
        name = MELEE_CRIT_CHANCE,
        value = string.format("%.2f%%", critChance),
    }

    return rows
end

-- Resistance rows { name, value }, for the debug report.
local function readResistances()
    local rows = {}
    local numResistances = NUM_PET_RESISTANCE_TYPES or 5
    for rank = 1, numResistances do
        local frame = _G["PetMagicResFrame" .. rank]
        local school = frame and frame.GetID and frame:GetID()
        if school then
            local _, value = UnitResistance("pet", school)
            rows[#rows + 1] = {
                name = _G["RESISTANCE" .. school .. "_NAME"] or tostring(school),
                value = tostring(value or 0),
            }
        end
    end
    return rows
end

-- --------------------------------------------------------------- Right pane

local groups = {}
local rowLines = {}

-- One stat row like StatFrameTemplate: label left, value right, alternating background.
local function createRow(rank, width)
    local row = CreateFrame("Frame", "ForeverUIPetStat" .. rank, detail)
    row:SetWidth(width)
    row:SetHeight(STEP)

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    background:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.background = background

    local label = row:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetJustifyH("LEFT")
    label:SetPoint("LEFT", row, "LEFT", 0, 0)
    row.label = label

    local value = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    value:SetJustifyH("RIGHT")
    value:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    value:SetPoint("LEFT", label, "RIGHT", 4, 0)
    row.value = value

    rowLines[rank] = row
    return row
end

local function createHeader(rank, width)
    local header = CreateFrame("Frame", "ForeverUIPetCategory" .. rank, detail)
    header:SetWidth(width + 2 * HEADER_OVERHANG)
    header:SetHeight(HEADER_H)

    -- camelot's header frame, stretched, as on the character stat category selectors.
    local background = header:CreateTexture(nil, "BACKGROUND")
    ForeverUI.SetAtlas(background, ATLAS_HEADER, true)
    background:SetAllPoints(header)

    local label = header:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    label:SetPoint("CENTER", header, "CENTER", 0, 1)
    header.label = label

    groups[rank] = header
    return header
end

-- Resistances are the client's own icons (PetMagicResFrame1-5), placed in a row, so the
-- client keeps their value, color and tooltip. They are reparented to the right pane
-- because the sweep hides their parent screen. placeResistances returns the height used.
local RES_W, RES_H = 32, 29             -- MagicResistanceFrameTemplate

local function placeResistances(width, y)
    if PetPaperDollFrame_SetResistances then
        PetPaperDollFrame_SetResistances()
    end

    local numResistances = NUM_PET_RESISTANCE_TYPES or 5
    -- Spread evenly over the row width.
    local gap = 0
    if numResistances > 1 then
        gap = (width - numResistances * RES_W) / (numResistances - 1)
        if gap < 0 then
            gap = 0
        end
    end

    for rank = 1, numResistances do
        local frame = _G["PetMagicResFrame" .. rank]
        if frame then
            frame:SetParent(detail)
            frame:SetWidth(RES_W)
            frame:SetHeight(RES_H)
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", detail, "TOPLEFT",
                MARGIN + (rank - 1) * (RES_W + gap), -y)
            frame:Show()
            for _, region in ipairs({ frame:GetRegions() }) do
                if region.Show then
                    region:Show()
                end
            end
        end
    end

    return RES_H
end

-- Stacks each category header and its rows.
local function layout()
    if not detail then
        return
    end

    local width = detail:GetWidth() or 0
    if width < 50 then
        width = PANE_W
    end
    width = width - 2 * MARGIN

    local blocks = {
        { name = GENERAL, rows = readGeneral() },
        { name = L.PETTAB_RESISTANCES, icons = true },
    }

    local y = TOP

    -- "Level X <name>" at the top of the pane.
    local level = (UnitLevel and UnitLevel("pet")) or 0
    local name = (UnitName and UnitName("pet")) or ""
    detail.level:SetWidth(width)
    detail.level:ClearAllPoints()
    detail.level:SetPoint("TOP", detail, "TOP", 0, -y)
    detail.level:SetText(string.format("%s %s",
        string.format(UNIT_LEVEL_TEMPLATE, level), name))
    y = y + LEVEL_H - LEVEL_GAP

    local headerIndex, rowIndex = 0, 0
    for _, block in ipairs(blocks) do
        headerIndex = headerIndex + 1
        local header = groups[headerIndex] or createHeader(headerIndex, width)
        header:SetWidth(width + 2 * HEADER_OVERHANG)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", detail, "TOPLEFT", MARGIN - HEADER_OVERHANG, -y)
        header.label:SetText(block.name)
        header:Show()
        y = y + HEADER_H

        if block.icons then
            y = y + placeResistances(width, y)
        else
            for number, data in ipairs(block.rows) do
                rowIndex = rowIndex + 1
                local row = rowLines[rowIndex] or createRow(rowIndex, width)
                row:SetWidth(width)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", detail, "TOPLEFT", MARGIN, -y)
                row.label:SetText(string.format(STAT_FORMAT, data.name))
                row.value:SetText(data.value)
                -- Dark first, restarting at each category, as in the character stats.
                ForeverUI.SetAtlas(row.background,
                    (number % 2 == 1) and ATLAS_DARK_BACKGROUND or ATLAS_LIGHT_BACKGROUND,
                    true)
                row:Show()
                y = y + STEP
            end
        end

        y = y + GROUP_GAP
    end

    for rank = headerIndex + 1, #groups do
        groups[rank]:Hide()
    end
    for rank = rowIndex + 1, #rowLines do
        rowLines[rank]:Hide()
    end
end

-- Fills the right pane, or empties it when there is no pet.
local function updateDetail()
    if not detail then
        return
    end
    if not hasPet() then
        detail.level:SetText("")
        for _, header in ipairs(groups) do
            header:Hide()
        end
        for _, row in ipairs(rowLines) do
            row:Hide()
        end
        for rank = 1, (NUM_PET_RESISTANCE_TYPES or 5) do
            local frame = _G["PetMagicResFrame" .. rank]
            if frame then
                frame:Hide()
            end
        end
        return
    end
    layout()
end
ForeverUI.PetDetail = updateDetail

-- ------------------------------------------------------------- Left pane

-- Hides a client frame's art, text and children, except the spared ones.
-- PetModelFrame is a grandchild of PetPaperDollFrame (inside PetPaperDollFramePetFrame),
-- so both levels are swept, each sparing what holds the model.
-- spared: set of child frames to leave shown.
local function sweep(frame, spared)
    if not frame then
        return
    end

    if frame.SetBackdrop then
        frame:SetBackdrop(nil)
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        local objectType = region.GetObjectType and region:GetObjectType()
        if objectType == "Texture" then
            region:SetAlpha(0)
        elseif objectType == "FontString" and region.Hide then
            region:Hide()
        end
    end
    if frame.GetChildren then
        for _, childFrame in ipairs({ frame:GetChildren() }) do
            if not spared[childFrame] and childFrame.Hide then
                childFrame:Hide()
            end
        end
    end
end

-- Hides the client pet screen, except the model and its carrier.
local function suppressClientScreen()
    local screen = _G["PetPaperDollFrame"]
    local carrier = _G["PetPaperDollFramePetFrame"]
    local model = _G["PetModelFrame"]
    if not screen then
        return
    end

    sweep(screen, { [panel or false] = true, [carrier or false] = true,
        [model or false] = true })
    sweep(carrier, { [model or false] = true })

    -- PetPaperDollFrame_SetTab hides it when another client tab is chosen; it holds the model.
    if carrier then
        carrier:Show()
    end
end

-- Puts the pet model and its rotation arrows in the left pane.
local function updatePreview()
    local model = _G["PetModelFrame"]
    if not model or not panel then
        return
    end

    suppressClientScreen()

    model:ClearAllPoints()
    model:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, 0)
    model:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    -- The arrows are children of the model (PetPaperDollFrame.xml), so the sweep misses them;
    -- they only need to move where the character's are.
    local left = _G["PetModelFrameRotateLeftButton"]
    local right = _G["PetModelFrameRotateRightButton"]
    if left and right then
        local half = (left:GetWidth() or 0) / 2 + ROTATION_GAP / 2
        local level = (model:GetFrameLevel() or 0) + 2

        left:ClearAllPoints()
        left:SetPoint("TOP", panel, "TOP", -half, ROTATION_Y)
        left:SetFrameLevel(level)

        right:ClearAllPoints()
        right:SetPoint("TOP", panel, "TOP", half, ROTATION_Y)
        right:SetFrameLevel(level)
    end

    if hasPet() then
        if model.SetUnit then
            model:SetUnit("pet")
        end
        model:Show()
        if left then left:Show() end
        if right then right:Show() end
    else
        model:Hide()
        if left then left:Hide() end
        if right then right:Hide() end
    end
end
ForeverUI.PetPreview = updatePreview

-- ---------------------------------------------------------- Build

-- Left pane content; host: the left pane frame.
-- Returns no root and the client frames it owns (see Panes.Register).
local function build(host)
    local frame = _G["PetPaperDollFrame"]
    if not frame or not host then
        return nil, {}
    end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    frame:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)

    if panel then
        updatePreview()
        updateDetail()
        return nil, { frame }
    end

    panel = CreateFrame("Frame", "ForeverUIPetPane", frame)
    panel:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    panel:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    local width = host:GetWidth() or 0
    if width < 100 then
        width = LEFT_PANE_W
    end
    panel:SetWidth(width)
    local height = host:GetHeight() or 0
    if height < 100 then
        height = LEFT_PANE_H
    end
    panel:SetHeight(height)

    updatePreview()
    updateDetail()
    return nil, { frame }
end

-- Right pane content; host: the right pane frame. Returns its root (see Panes.Register).
local function buildDetail(host)
    if detail then
        updateDetail()
        return detail, {}
    end
    if not host then
        return nil, {}
    end

    detail = CreateFrame("Frame", "ForeverUIPetStats", host)
    detail:SetPoint("TOPLEFT", host, "TOPLEFT", 0, 0)
    detail:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", 0, 0)
    local width = host:GetWidth() or 0
    if width < 50 then
        width = PANE_W
    end
    detail:SetWidth(width)

    -- "Level X <name>", on the same background as the character's level line.
    local background = detail:CreateTexture(nil, "BACKGROUND")
    ForeverUI.SetAtlas(background, ATLAS_LEVEL, true)

    local level = detail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    level:SetHeight(LEVEL_H)
    level:SetJustifyH("CENTER")
    level:SetJustifyV("MIDDLE")
    detail.level = level

    background:SetPoint("TOP", level, "TOP", 0, 0)
    background:SetPoint("BOTTOM", level, "BOTTOM", 0, 0)
    background:SetPoint("LEFT", level, "LEFT", 0, 0)
    background:SetPoint("RIGHT", level, "RIGHT", 0, 0)

    updateDetail()
    return detail, {}
end

ForeverUI.PetTab = { Build = build, BuildRight = buildDetail }

-- The client redraws its screen in PetPaperDollFrame_Update: re-apply both panes after it.
if hooksecurefunc and type(_G["PetPaperDollFrame_Update"]) == "function" then
    hooksecurefunc("PetPaperDollFrame_Update", function()
        updatePreview()
        updateDetail()
    end)
end

-- UNIT_PET: the pet changes; the other three: its numbers change.
local listener = CreateFrame("Frame")
listener:RegisterEvent("UNIT_PET")
listener:RegisterEvent("UNIT_STATS")
listener:RegisterEvent("UNIT_ATTACK_POWER")
listener:RegisterEvent("UNIT_RESISTANCES")
listener:SetScript("OnEvent", function()
    updatePreview()
    updateDetail()
end)

-- Debug report: /fui pet.
function ForeverUI.PetDebug()
    local say = function(text)
        DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffForeverUI|r " .. text)
    end

    say(string.format(L.PETTAB_DEBUG_PET,
        tostring(HasPetUI and HasPetUI()),
        tostring(UnitExists and UnitExists("pet")),
        tostring(UnitLevel and UnitLevel("pet")),
        tostring(UnitName and UnitName("pet")),
        tostring(UnitCreatureFamily and UnitCreatureFamily("pet"))))

    for _, data in ipairs(readGeneral()) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("   %-18s %s",
            data.name, tostring(data.value)))
    end
    for _, data in ipairs(readResistances()) do
        DEFAULT_CHAT_FRAME:AddMessage(string.format("   %-18s %s",
            data.name, tostring(data.value)))
    end

    local model = _G["PetModelFrame"]
    say(string.format(L.PETTAB_DEBUG_PREVIEW,
        tostring(model and model:IsShown()),
        tostring(detail and detail:IsShown())))
end
