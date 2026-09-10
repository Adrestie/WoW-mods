--[[
    This file is part of mod-spheregrid.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
    Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
]]

--[[----------------------------------------------------------------------------
    Sphere grid — the player interface, client side (shipped by AIO)

    It takes up the editor's settled visual language: a cell = a disc + a
    quality ring + a round icon, a socket = a gem setting, ring arcs baked into
    a texture, active links in cyan, the start ringed in gold.

    States: active (full colour), affordable (dimmed — the start, or a
    neighbour of an active cell), unreachable (unlit). A purchase is confirmed
    by a dialog box and carried out server side by the module's command (rules
    and messages).

    The way in: a « Sphere grid » button on the talent window, /spheregrid,
    .spheregrid show. Texts bilingual according to the client's language.
------------------------------------------------------------------------------]]

local AIO = AIO or require("AIO")

if AIO.AddAddon() then
    return                                  -- server side: we stop here
end

local PlayerHandlers = AIO.AddHandlers("SphereGridPlayer", {})

local sqrt, cos, sin, pi   = math.sqrt, math.cos, math.sin, math.pi
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local fmt                  = string.format

-- ---------------------------------------------------------------------------
-- Texts, in the client's language
-- ---------------------------------------------------------------------------

local FR = GetLocale() == "frFR"
local L = {
    title        = FR and "Sphèrier" or "Sphere Grid",
    button       = FR and "Sphèrier" or "Sphere Grid",
    points       = FR and "Spherite : |cffffd100%d|r" or "Spherite: |cffffd100%d|r",
    actives       = FR and "%d / %d actifs" or "%d / %d active",
    node        = FR and "Nœud" or "Node",
    slot         = FR and "Slot" or "Socket",
    slot_desc    = FR and "N'accueille que des runes." or "Accepts runes only.",
    stone       = FR and "Pierre %s" or "%s stone",
    spell_title   = FR and "Sort" or "Spell",
    spell_desc    = FR and "Apprend ce sort à l'activation." or "Teaches this spell when activated.",
    spell_unknown = FR and "Sort n°%d" or "Spell #%d",
    node_empty   = FR and "Nœud vide" or "Empty node",
    empty_desc    = FR and "Recevra une pierre sertie." or "Awaits a socketed stone.",
    start       = FR and "Point de départ de la classe" or "Class starting cell",
    state_active   = FR and "Actif" or "Active",
    state_cost    = FR and "Coût : %d Spherite(s) — cliquez pour acheter" or "Cost: %d Spherite — click to buy",
    state_path  = FR and "Chemin : %d emplacements, coût total %d Spherite(s) — cliquez pour tout acheter"
                       or "Path: %d cells, total cost %d Spherite — click to buy them all",
    unreachable = FR and "Inaccessible : aucun chemin ne mène ici."
                       or "Unreachable: no path leads here.",
    confirm     = FR and "Acheter cet emplacement pour %d Spherite(s) ?"
                       or "Buy this cell for %d Spherite?",
    confirm_path = FR and "Débloquer %d emplacements d'un coup pour %d Spherite(s) ?"
                          or "Unlock %d cells at once for %d Spherite?",
    confirm_spell   = FR and "Réapprendre ce sort pour %d Spherite(s) ?"
                          or "Relearn this spell for %d Spherite?",
    buy      = FR and "Buy" or "Buy",
    cancel      = FR and "Annuler" or "Cancel",
    summary_title  = FR and "Statistiques" or "Statistics",
    summary_help   = FR and "Acquis / total de la grille" or "Acquired / grid total",
    runes_title  = FR and "Runes actives" or "Active runes",
    runes_empty   = FR and "Aucune rune sertie." or "No rune socketed.",
    runes_inert = FR and "Runes inactives" or "Inactive runes",
    spells_title  = FR and "Sorts de classe" or "Class spells",
    spells_empty   = FR and "Aucun sort pour cette classe." or "No spell for this class.",
    rune_title   = FR and "Rune" or "Rune",
    rune_desc    = FR and "Ajoute un rang à %s." or "Adds one rank to %s.",
    rune_line   = FR and "%s — rang %d" or "%s — rank %d",
    rune_teaches = FR and "Sertir cette rune vous apprendra %s (rang %d)."
                       or "Socketing this rune will teach you %s (rank %d).",
    rune_required  = FR and "Pré-requis : %s" or "Requires: %s",
    rune_class  = FR and "Cette rune appartient à une autre classe."
                       or "That rune belongs to another class.",
    rune_max     = FR and "Trois runes au maximum par sort."
                       or "Three runes per spell at most.",
    rune_max_s   = FR and "Trois runes au maximum par statistique."
                       or "Three runes per statistic at most.",
    rune_stat_title = FR and "Rune de statistique" or "Statistic rune",
    rune_stat_desc  = FR and "Majore de %d %% ce que le sphèrier vous accorde en %s."
                          or "Increases by %d%% what your sphere grid grants in %s.",
    rune_stat_placed  = FR and "Sertir cette rune majorera de %d %% ce que le sphèrier vous accorde en %s."
                          or "Socketing this rune will increase by %d%% what your sphere grid grants in %s.",
    rune_stat_line = FR and "%s +%d %% (%d)" or "%s +%d%% (%d)",
    rune_item   = FR and "Rune %s" or "Rune of %s",
    rune_inert  = FR and "%s — rang de base non connu" or "%s — base rank unknown",
    rune_inert_t = FR and "%s — talent non appris" or "%s — talent not learned",
    rune_off     = FR and "Sans effet : le talent n'est pas appris."
                       or "No effect: the talent is not learned.",
    rune_off_r   = FR and "Sans effet : vous ne connaissez pas %s."
                       or "No effect: you do not know %s.",
    -- Socketing and pinning
    empty_active   = FR and "Vide — à sertir" or "Empty — awaiting a stone",
    act_socket   = FR and "Clic gauche : sertir une pierre" or "Left-click: socket a stone",
    act_socket_r = FR and "Clic gauche : sertir une rune" or "Left-click: socket a rune",
    rune_rank    = FR and "Rang %d" or "Rank %d",
    act_drop   = FR and "…ou y lâcher une pierre prise dans un sac"
                       or "…or drop a stone from your bags onto it",
    act_pin  = FR and "Clic droit : épingle de l'oubli" or "Right-click: Pin of Oblivion",
    picker_title  = FR and "Sertir une pierre" or "Socket a stone",
    picker_empty   = FR and "Aucune pierre dans vos sacs." or "No stone in your bags.",
    picker_scroll = FR and "Molette pour faire défiler" or "Scroll to see more",
    pin_rune_pct = FR and "Vider cet emplacement ?\n\n|cffff5555%s sera détruite et la majoration retombera à %d %%.|r\nÉpingles en sac : %d"
                        or "Empty this cell?\n\n|cffff5555%s will be destroyed and the bonus will drop back to %d%%.|r\nPins in bags: %d",
    pin_rune_rank = FR and "Vider cet emplacement ?\n\n|cffff5555%s sera détruite et le sort retournera au rang %d.|r\nÉpingles en sac : %d"
                        or "Empty this cell?\n\n|cffff5555%s will be destroyed and the spell will drop back to rank %d.|r\nPins in bags: %d",
    pin_rune  = FR and "Vider cet emplacement ?\n\n|cffff5555%s sera détruite.|r\nÉpingles en sac : %d"
                        or "Empty this cell?\n\n|cffff5555%s will be destroyed.|r\nPins in bags: %d",
    pin_text = FR and "Vider cet emplacement ?\n\n|cffff5555%s sera détruit.|r\nÉpingles en sac : %d"
                        or "Empty this cell?\n\n|cffff5555%s will be destroyed.|r\nPins in bags: %d",
    pin_spell  = FR and "Oublier ce sort ?\n\n|cffff5555%s sera oublié.|r\nÉpingles en sac : %d"
                        or "Forget this spell?\n\n|cffff5555%s will be forgotten.|r\nPins in bags: %d",
    confirm       = FR and "Valider" or "Confirm",
    socket_text  = FR and "Sertir %s dans cet emplacement ?\n\n|cff88ff88%s|r"
                        or "Socket %s into this cell?\n\n|cff88ff88%s|r",
    -- An item taken in hand from a bag: the window's banner.
    hand_stone   = FR and "%s en main — cliquez un emplacement vide. Clic droit pour reposer."
                        or "%s in hand — click an empty cell. Right-click to put it back.",
    hand_pin  = FR and "%s en main — cliquez un emplacement à vider. Clic droit pour la reposer."
                        or "%s in hand — click a cell to empty. Right-click to put it back.",
    -- Resetting: the confirmation reads exactly as it was asked for, word for word.
    reset_button = FR and "Réinitialiser" or "Reset",
    reset_text  = FR and "Réinitialiser votre Sphèrier va retirer votre progression, vous rembourser les points dépensés et sans modifier les nœuds ou runes."
                        or "Resetting your Sphere Grid will remove your progression and refund the points you spent, without changing the nodes or runes.",
    content_spell  = FR and "Sort appris" or "Spell learned",
    content_forgotten = FR and "Sort oublié — recliquez pour le réapprendre (coût habituel)"
                        or "Spell forgotten — click again to relearn (usual cost)",
}

-- The order of the sixteen statistics (docs/PRESENTATION.md): the five primary
-- ones, then the secondary. It is also the order of the summary.
local STAT_ORDER = {
    "stamina", "intellect", "spirit", "agility", "strength",
    "parry", "block", "dodge", "haste", "crit", "hit",
    "spell_power", "attack_power", "armor_penetration",
    "expertise", "bonus_healing",
}

local STAT_LABELS = {
    stamina = FR and "Endurance" or "Stamina",
    intellect = FR and "Intelligence" or "Intellect",
    spirit = FR and "Esprit" or "Spirit",
    agility = FR and "Dextérité" or "Agility",
    strength = FR and "Force" or "Strength",
    parry = FR and "Parade" or "Parry",
    block = FR and "Blocage" or "Block",
    dodge = FR and "Esquive" or "Dodge",
    haste = FR and "Hâte" or "Haste",
    crit = FR and "Critique" or "Critical strike",
    hit = FR and "Touché" or "Hit",
    spell_power = FR and "Puissance des sorts" or "Spell power",
    attack_power = FR and "Puissance d'attaque" or "Attack power",
    armor_penetration = FR and "Pénétration d'armure" or "Armor penetration",
    expertise = FR and "Expertise" or "Expertise",
    bonus_healing = FR and "Bonus des soins" or "Healing bonus",
}

-- What each quality grants -- a settled design (docs/PRESENTATION.md).
local QUALITIES = {
    { label = FR and "Commun"     or "Common",    bonus = 5 },
    { label = FR and "Inhabituel" or "Uncommon",  bonus = 7 },
    { label = FR and "Rare"       or "Rare",      bonus = 10 },
    { label = FR and "Épique"     or "Epic",      bonus = 15 },
    { label = FR and "Légendaire" or "Legendary", bonus = 30 },
}

-- ---------------------------------------------------------------------------
-- Drawing constants -- the editor's own, a look already settled
-- ---------------------------------------------------------------------------

-- Lua 5.1, which the client runs, allows a function sixty upvalues at most. So
-- every drawing constant lives in ONE table -- a single upvalue.
local RC = {}

RC.SPACING    = 64
RC.NODE_SIZE  = 34
RC.EDGE_THICK = 11   -- « pipe » style: must match the baked arcs
RC.MARGIN     = 120

RC.NODE_DISC_TEXTURE = "Interface\\GLUES\\MODELS\\UI_Tauren\\gradientCircle"
RC.NODE_RING_TEXTURE = "Interface\\Cooldown\\ping4"
RC.NODE_DISC_SIZE  = 78
RC.NODE_RING_SIZE  = 46  -- just beyond the icon frame (radius 19.3)
RC.NODE_DISC_COLOR = { 0.05, 0.05, 0.06 }
RC.ICON_SIZE_NODE  = 34

RC.SOCKET_SHEET        = "Interface\\ItemSocketingFrame\\UI-ItemSockets"
RC.SOCKET_HOLE_COORDS  = { 0.71875, 1, 0.7109375, 1 }
RC.SOCKET_FRAME_COORDS = { 0.171875, 0.3984375, 0.40234375, 0.609375 }
RC.SLOT_SCALE = 0.80

-- The module's textures, shipped in its archive and read from there. A path is
-- written WITHOUT its extension: the client adds .blp itself.
RC.ART_DIR      = "Interface\\Spheregrid\\"
RC.LINE_TEXTURE = RC.ART_DIR .. "line"
RC.LINEFACTOR_2 = (128 / 126) / 2
RC.ARC_TEXTURES = { RC.ART_DIR .. "arc1", RC.ART_DIR .. "arc2", RC.ART_DIR .. "arc3" }

-- AN ICON'S FRAME. The round icon sits in ARTWORK and, over it in OVERLAY, this
-- ring of the client's: transparent centre, opaque band, transparent outside.
-- That is what covers the icon's edge, the engine's mask not being adjustable
-- (and a SetTexCoord applied afterwards would destroy it). A brown-gold ring,
-- RGB(113,99,71), inner radius at 0.636 of the half-side: at 44px it bites 3px
-- into an icon of 34.
RC.FRAME_SHEET  = "Interface\\Journeys\\JourneysFrame2x"
RC.FRAME_COORDS = { 0.762207, 0.814941, 0.124512, 0.177246 }
RC.FRAME_SIZE   = 44
RC.ARC_TEX_W, RC.ARC_TEX_H = 256, 128
RC.ARC_CHORD_U0, RC.ARC_CHORD_V, RC.ARC_CHORD_TEXELS = 8, 100, 240

RC.QUALITY_COLORS = {
    { 1.00, 1.00, 1.00 }, { 0.12, 1.00, 0.00 }, { 0.00, 0.44, 0.87 },
    { 0.64, 0.21, 0.93 }, { 1.00, 0.50, 0.00 },
}
RC.SLOT_COLOR   = { 0.31, 0.69, 0.89 }
-- A SPELL CELL: the spell frame from the custom spellbook (NewSpellBook, sheet
-- Spellbook-Parts, regions read off NewSpellBookFrame.xml) -- a parchment plate,
-- a SQUARE icon, and a frame of vines: gold when the spell is active, brown
-- ("not learned") otherwise. Blizzard's reference: a 37 button, a gold frame
-- 70x65 offset by +1.5, a brown frame 70x59 offset by -3, a plate of 43 --
-- transposed for an icon of 30 (a factor of 30/37).
RC.SPELL_COLOR = { 1.00, 0.30, 0.85 }         -- colour d'accent (infobulles)
RC.SB_SHEET       = "Interface\\FrameXML\\NewSpellBook\\NewSpellbook\\Spellbook-Parts"
RC.SB_BACKGROUND_COORDS = { 0.79296875, 0.9609375, 0.00390625, 0.171875 }
RC.SB_BACKGROUND_SIZE   = 35
RC.SB_GOLD_COORDS   = { 0.00390625, 0.27734375, 0.44140625, 0.6953125 }
RC.SB_GOLD_W, RC.SB_GOLD_H, RC.SB_GOLD_DX, RC.SB_GOLD_DY = 57, 53, 1.2, 0
RC.SB_BROWN_COORDS = { 0.00390625, 0.27734375, 0.703125, 0.93359375 }
RC.SB_BROWN_W, RC.SB_BROWN_H, RC.SB_BROWN_DX, RC.SB_BROWN_DY = 57, 48, 1.2, -2.4
RC.ICON_SIZE_SPELL = 30    -- a square icon, as in the spellbook
RC.ICON_SIZE_RUNE = 26    -- the gem sits in the setting without overflowing it
-- A rune socketed but INERT -- a talent forgotten, the base rank unknown -- must
-- show at a glance: it keeps its place but turns red.
RC.RUNE_INERT = { 1, 0.30, 0.30 }
RC.RUNE_ACTIVE = { 0.9, 0.9, 0.9 }
-- An empty node: the centre is stopped by an opaque dark disc (a portrait mask
-- over a plain texture) -- the links must not show through.
RC.EMPTY_NODE_COLOR = { 0.55, 0.55, 0.55 }
-- THE STOPPER MUST BE A ROUND TEXTURE TO BEGIN WITH. It used to go through
-- SetPortraitToTexture over a WHITE8X8: that was the last call to that API, and
-- the 3.3.5 client crashes there (ACCESS_VIOLATION at 0061949A). So the texture
-- must be round ALREADY, drawn with no mask.
--
-- NOT `gradientCircle`: its circle is painted on an OPAQUE BLACK square. The
-- background disc gets away with it because it draws in SetBlendMode("ADD"),
-- where black turns transparent; the icon, in a normal fade, would show the
-- square. What is needed is a texture with REAL transparency around the disc.
RC.PLUG_TEXTURE     = "Interface\\Minimap\\UI-Minimap-Background"
RC.PLUG_COLOR       = { 0.07, 0.07, 0.08 }
RC.EDGE_ACTIVE  = { 0.20, 0.88, 0.96, 1 }    -- both ends active
RC.EDGE_FRONT   = { 0.45, 0.45, 0.45, 1 }    -- one endpoint active: the frontier
RC.EDGE_OFF     = { 0.14, 0.14, 0.14, 1 }    -- unlit
RC.START_COLOR     = { 1.00, 0.82, 0 }
RC.START_RING_SIZE = 52

RC.DIM_AFFORDABLE    = 0.55
RC.DIM_INACCESSIBLE = 0.15

-- A purchase awaiting confirmation: a PULSING white outline on the cells
-- concerned and on the links they will light. Nothing is lit for all that -- the
-- cells keep their state, and only the pulse says what the purchase will open.
RC.PULSE_COLOR   = { 1, 1, 1, 1 }
RC.PULSE_SIZE    = 56                -- a white ring, above all the rest
RC.PULSE_MIN     = 0.12
RC.PULSE_MAX     = 0.95
RC.PULSE_PERIOD = 2.0               -- seconds per beat

-- SPARKS: a point of light travels each link at its own pace. The texture is the
-- nodes' circular gradient in ADD blending, which gives a white core and a soft
-- halo with nothing new to ship. They are laid on the CANVAS in OVERLAY: above
-- the links (ARTWORK) and below the cells, which are child frames and therefore
-- pass in front whatever happens.
RC.SPARK_TEXTURE = RC.ART_DIR .. "spark"
RC.SPARK_SIZE = 24
-- The halo of the statistic hovered in the summary. ping4 being only a thin
-- stroke, thickness comes from stacking several rings of neighbouring radii: in
-- ADD blending they melt into one continuous band.
RC.STATHL_SIZES = { 48, 52, 56, 60 }
RC.STATHL_COLOR = { 1.00, 1.00, 0.70 }
RC.STATHL_ALPHA = 0.75
-- The summary: the panel's width, a line's height, and the first line's y
-- (the rest stack below it as they are shown).
RC.SUMMARY_W  = 236
RC.SUMMARY_H  = 15
-- The background of a line hovered in the summary. Dark red for an inert rune:
-- the highlight already says it grants nothing.
RC.SUMMARY_HL = { 0.25, 0.25, 0.18 }

-- --- Dressing --------------------------------------------------------------
-- NOTHING NEW IS PACKAGED: it all comes from the client's own archives.
--
-- The window has no background of its own: the two panels fill it entirely, and
-- there would be nothing to see behind them.
--
-- The inner margins of the dialog outline, the banner's height, and the hairline
-- that separates the two panels -- two points, not thirty-two.
RC.INSET_L, RC.INSET_R, RC.INSET_T, RC.INSET_B = 11, 12, 12, 11
RC.HEADER_H = 28
RC.HAIRLINE = 2
RC.HAIRLINE_COLOR = { 0, 0, 0 }

-- The statistics panel takes the backdrop of the CURRENT SPECIALISATION.
-- `GetTalentTabInfo` returns the file name of that scenery: nothing to write
-- into the code, and the picture follows the player as he changes tree.
RC.TALENT_PATH = "Interface\\TalentFrame\\%s-%s"
-- A backdrop is painted in FOUR QUARTERS -- no texture went beyond 256 a side in
-- 3.3.5. Assembled it is 320 by 331: 256 + 64 wide, 256 + 75 tall. Yet the two
-- lower quarters are 128 tall, of which 53 are EMPTY: without cutting them, the
-- bottom of the panel would go blank.
RC.TALENT_W = 256 / 320
RC.TALENT_H = 256 / 331
RC.TALENT_BOTTOM_V = 75 / 128
RC.TALENT_RATIO = 320 / 331
RC.TALENT_ALPHA = 0.50
RC.TALENT_TINT = { 0.42, 0.42, 0.48 }   -- darkened: the text reads over it
-- Each quarter, with the share of the picture it carries and the share of its own
-- texture that is painted: the two lower ones stop at 75 out of 128.
RC.TALENT_QUARTERS = {
    { corner = "TopLeft",     u0 = 0,           u1 = 256 / 320, v0 = 0,           v1 = 256 / 331, vmax = 1 },
    { corner = "TopRight",    u0 = 256 / 320,   u1 = 1,         v0 = 0,           v1 = 256 / 331, vmax = 1 },
    { corner = "BottomLeft",  u0 = 0,           u1 = 256 / 320, v0 = 256 / 331,   v1 = 1,         vmax = 75 / 128 },
    { corner = "BottomRight", u0 = 256 / 320,   u1 = 1,         v0 = 256 / 331,   v1 = 1,         vmax = 75 / 128 },
}
RC.SUMMARY_HL_INERT = { 0.35, 0.15, 0.15 }
-- The summary's colours. The purple is the one of epic items, so that "beyond
-- the maximum" reads with the same eye as the rest of the interface.
RC.SUMMARY_TXT = { 1, 1, 1 }
RC.SUMMARY_TXT_FULL = { 0.2, 1, 0.2 }
RC.SUMMARY_TXT_OVER = { 0.64, 0.21, 0.93 }
RC.SUMMARY_Y0 = -38
RC.SPARK_VMIN, RC.SPARK_VMAX = 0.06, 0.20   -- fraction of a link per second

RC.ZOOM_MIN, RC.ZOOM_MAX, RC.ZOOM_STEP = 0.30, 1.60, 0.10

-- The stone picker, opened by clicking an active and empty cell. It shows only
-- what the bags hold and what can be socketed; the wheel scrolls when there are
-- more than there are lines.
RC.PICK_W        = 232
RC.PICK_ROW_H    = 22
RC.PICK_ROWS     = 8
RC.PICK_ICON     = 18
RC.PICK_PAD      = 10
RC.PIN_ENTRY = 803300           -- a fallback; the authoritative value comes from the database
RC.PLAYER_BAGS   = { 0, 1, 2, 3, 4 }
-- An item taken in hand by right-clicking it in a bag: the cursor turns into
-- "apply to a target", like a spell to cast. SetCursor expects one of the
-- engine's cursor NAMES (see ShowInspectCursor in UIParent.lua), not a path.
-- It is barred while what is under it cannot receive the item -- the game's own
-- rule for anything applied to a target.
RC.CURSOR_HAND    = "CAST_CURSOR"
RC.CURSOR_HAND_NO = "CAST_ERROR_CURSOR"

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------

local UI
local DEF  = nil        -- the definition sent by the server
local STATE = nil        -- the character's state
local zoom = 1
local bounds = { minx = 0, miny = 0, maxx = 0, maxy = 0 }
-- Centring the content when it is smaller than the view: the canvas is inflated
-- to the view's size and the content offset by as much -- without which zooming
-- out packs the grid into the top-left corner (where the ScrollFrame anchors).
local offsetX, offsetY = 0, 0

local nodeById, clusterById, adjacentById = {}, {}, {}

-- A purchase awaiting confirmation: the set of cells that will be bought, and
-- the links that will light with them.
local buying = nil

-- The statistic hovered in the summary: every stone carrying it takes a halo,
-- including those not yet bought.
local statHovered = nil
-- A rune hovered in the summary: the same idea as a statistic, the cells
-- carrying it take a halo. Whether it is inert is remembered too, so that halo
-- can be tinted red.
local runeHovered, runeInert = nil, false
-- A spell line hovered in the side bar: the cell that carries it takes the halo.
local spellHovered = nil
-- The fingerprint of the definition the client holds: the server sends the grid
-- again only if it changed.
local DEF_VERSION = nil

-- Socketing, the pin and the picker list. They live in ONE table rather than as
-- bare locals: every module-level local costs an upvalue to the large functions
-- (Rebuild), and the Lua 5.1 client caps those at sixty.
local ACT = {}

-- The catalogue of the module's items -- stones, runes, the pin's entry -- asked
-- of the server as soon as the client loads: without it the client could not
-- recognise a stone in a bag BEFORE the window is first opened. Nothing here is
-- written into the code; it all comes from the module.
-- `runesPerSpell` is the operator's setting, sent with the catalogue: the rule
-- belongs to the module (SphereGridBench::TooManyRunes) and is said again here
-- so as not to invite a gesture bound to be refused. Three is the module's own
-- default, held until the catalogue arrives.
local CAT = { stones = {}, runes = {}, statRunes = {}, pin = 0, runesPerSpell = 3 }

-- A STATISTIC'S ICON IS A FILE THE MODULE SHIPS, one per statistic, named after
-- it. Nothing to send and nothing to store: the path composes itself.
local function StatIcon(stat)
    return stat and (RC.ART_DIR .. "stat_" .. stat) or nil
end

local function IsActive(id)     return STATE and STATE.actives[id] end

-- A SPELL CELL BOUGHT IS NOT ALWAYS LEARNED. The pin gives the spell back and
-- leaves the cell bought; `raw` then holds zero, and the cell is learned again
-- with one click. So the spellbook frame follows what the cell HOLDS, not
-- whether it is bought.
local function IsLearned(id)
    return IsActive(id) and STATE.raw and (STATE.raw[id] or 0) ~= 0
end

local function IsAffordable(id)
    if not DEF or not STATE or IsActive(id) then return false end
    if DEF.start == id then return true end
    for _, v in ipairs(adjacentById[id] or {}) do
        if IsActive(v) then return true end
    end
    return false
end

-- COST BY DISTANCE: what a cell costs is a property of the cell, worked out by
-- the server from its distance to the start and sent in the wire. The client no
-- longer computes it -- it could not drift from the module, which alone charges.
local function NodeCost(nodeId)
    local n = DEF and DEF.byId and DEF.byId[nodeId]
    return n and n.cost or 0
end

-- NO "NEXT COST" IN THE BANNER. With cost by distance there is no single price
-- for the next purchase: every cell has its own, and the tooltip gives it on
-- hover. The overall figure was removed rather than repaired -- it had nothing
-- true left to say.

-- The shortest path, in steps, between the cell aimed at and the nearest active
-- one -- or the start if nothing is active, in which case the start is part of
-- what is bought. Returns the ordered list of cells to buy, from the active side
-- towards the target, or nil if no path exists.
local function PathTo(target)
    if not DEF or not STATE or IsActive(target) then return nil end

    local noneActive = (STATE.activeCount or 0) == 0
    local seen, parent, queue = { [target] = true }, {}, { target }
    local first, arrival = 1, nil

    while queue[first] do
        local current = queue[first]
        first = first + 1

        local reached = (not noneActive and IsActive(current))
            or (noneActive and DEF.start == current)
        if reached then
            arrival = current
            break
        end

        for _, v in ipairs(adjacentById[current] or {}) do
            if not seen[v] then
                seen[v] = true
                parent[v] = current
                queue[#queue + 1] = v
            end
        end
    end

    if not arrival then return nil end

    -- The chain of parents runs from the arrival back to the target, which is the
    -- order of purchase. The active cell reached is left out; the start (on a grid
    -- still untouched) is included, and is bought like any other.
    local path = {}
    local current = noneActive and arrival or parent[arrival]
    while current do
        path[#path + 1] = current
        current = parent[current]
    end
    return #path > 0 and path or nil
end

-- The price no longer depends on the order of purchase: the order along the path
-- does not change the total, only the positions of the cells crossed count.
local function PathCost(path)
    local total = 0
    for i = 1, #path do
        total = total + NodeCost(path[i])
    end
    return total
end

-- Dresses the frame of a spell cell: gold when active, brown when not learned --
-- the geometry of NewSpellBookFrame.xml, transposed.
local function DressSpellFrame(btn, gold, r, g, b)
    local frame = btn.sbFrame
    if gold then
        frame:SetTexCoord(RC.SB_GOLD_COORDS[1], RC.SB_GOLD_COORDS[2],
            RC.SB_GOLD_COORDS[3], RC.SB_GOLD_COORDS[4])
        frame:SetWidth(RC.SB_GOLD_W)
        frame:SetHeight(RC.SB_GOLD_H)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", RC.SB_GOLD_DX, RC.SB_GOLD_DY)
    else
        frame:SetTexCoord(RC.SB_BROWN_COORDS[1], RC.SB_BROWN_COORDS[2],
            RC.SB_BROWN_COORDS[3], RC.SB_BROWN_COORDS[4])
        frame:SetWidth(RC.SB_BROWN_W)
        frame:SetHeight(RC.SB_BROWN_H)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", RC.SB_BROWN_DX, RC.SB_BROWN_DY)
    end
    frame:SetVertexColor(r, g, b)
    btn.sbBackground:SetVertexColor(r, g, b)
    btn.sbBackground:Show()
    frame:Show()
end

-- ---------------------------------------------------------------------------
-- Drawing -- the editor's segments and arcs, unchanged
-- ---------------------------------------------------------------------------

local function AcquireLine(canvas, pool, col, tex)
    local t = table.remove(pool.free)
    if not t then t = canvas:CreateTexture(nil, "ARTWORK") end
    t:SetTexture(tex or RC.LINE_TEXTURE)
    t:SetDrawLayer("ARTWORK")
    t:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
    -- A texture returned to the pool may come back from a pulse: without this reset
    -- it would serve again with the alpha the pulse left it at.
    t:SetAlpha(1)
    t:Show()
    pool.used[#pool.used + 1] = t
    return t
end

local function DrawSegment(canvas, pool, sx, sy, ex, ey, w, col)
    local T = AcquireLine(canvas, pool, col)
    T:ClearAllPoints()

    local dx, dy = ex - sx, ey - sy
    local cx, cy = (sx + ex) / 2, (sy + ey) / 2

    if dx == 0 and dy == 0 then T:Hide() return end

    if dy == 0 then
        T:SetTexCoord(0, 0, 0, 1, 1, 0, 1, 1)
        T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", min(sx, ex), cy - w / 2)
        T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", max(sx, ex), cy + w / 2)
        return T
    end

    if dx == 0 then
        T:SetTexCoord(1, 0, 0, 0, 1, 1, 0, 1)
        T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", cx - w / 2, min(sy, ey))
        T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", cx + w / 2, max(sy, ey))
        return T
    end

    if dx < 0 then dx, dy = -dx, -dy end

    local l = sqrt(dx * dx + dy * dy)
    local s, c = -dy / l, dx / l
    local sc = s * c

    local Bwid, Bhgt, BLx, BLy, TLx, TLy, TRx, TRy, BRx, BRy
    if dy >= 0 then
        Bwid = ((l * c) - (w * s)) * RC.LINEFACTOR_2
        Bhgt = ((w * c) - (l * s)) * RC.LINEFACTOR_2
        BLx, BLy, BRy = (w / l) * sc, s * s, (l / w) * sc
        BRx, TLx, TLy, TRx = 1 - BLy, BLy, 1 - BRy, 1 - BLx
        TRy = BRx
    else
        Bwid = ((l * c) + (w * s)) * RC.LINEFACTOR_2
        Bhgt = ((w * c) + (l * s)) * RC.LINEFACTOR_2
        BLx, BLy, BRx = s * s, -(l / w) * sc, 1 + (w / l) * sc
        BRy, TLx, TLy, TRy = BLx, 1 - BRx, 1 - BLx, 1 - BLy
        TRx = TLy
    end

    local function cl(v) return v > 10000 and 10000 or (v < -10000 and -10000 or v) end

    T:SetTexCoord(cl(TLx), cl(TLy), cl(BLx), cl(BLy), cl(TRx), cl(TRy), cl(BRx), cl(BRy))
    T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", cx - Bwid, cy - Bhgt)
    T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", cx + Bwid, cy + Bhgt)
    return T
end

local function DrawClusterArc(canvas, pool, ax, ay, bx, by, ccx, ccy, ring, col)
    local tex = RC.ARC_TEXTURES[ring]
    if not tex then return end

    local dx, dy = bx - ax, by - ay
    local Lg = sqrt(dx * dx + dy * dy)
    if Lg == 0 then return end
    local ux, uy = dx / Lg, dy / Lg
    local s = Lg / RC.ARC_CHORD_TEXELS

    local nx, ny = (ax + bx) / 2 - ccx, (ay + by) / 2 - ccy
    local nl = sqrt(nx * nx + ny * ny)
    if nl == 0 then nx, ny = -uy, ux else nx, ny = nx / nl, ny / nl end

    local function toScreen(tu, tv)
        local du = (tu - RC.ARC_CHORD_U0) * s
        local dv = (RC.ARC_CHORD_V - tv) * s
        return ax + ux * du + nx * dv, ay + uy * du + ny * dv
    end
    local x1, y1 = toScreen(0, 0)
    local x2, y2 = toScreen(RC.ARC_TEX_W, 0)
    local x3, y3 = toScreen(0, RC.ARC_TEX_H)
    local x4, y4 = toScreen(RC.ARC_TEX_W, RC.ARC_TEX_H)
    local minx, maxx = min(x1, x2, x3, x4), max(x1, x2, x3, x4)
    local miny, maxy = min(y1, y2, y3, y4), max(y1, y2, y3, y4)

    local function toTex(qx, qy)
        local rx, ry = qx - ax, qy - ay
        return (RC.ARC_CHORD_U0 + (rx * ux + ry * uy) / s) / RC.ARC_TEX_W,
               (RC.ARC_CHORD_V - (rx * nx + ry * ny) / s) / RC.ARC_TEX_H
    end

    local T = AcquireLine(canvas, pool, col, tex)
    T:ClearAllPoints()
    local ulu, ulv = toTex(minx, maxy)
    local llu, llv = toTex(minx, miny)
    local uru, urv = toTex(maxx, maxy)
    local lru, lrv = toTex(maxx, miny)
    T:SetTexCoord(ulu, ulv, llu, llv, uru, urv, lru, lrv)
    T:SetPoint("BOTTOMLEFT", canvas, "BOTTOMLEFT", minx, miny)
    T:SetPoint("TOPRIGHT",   canvas, "BOTTOMLEFT", maxx, maxy)
    return T
end

-- ---------------------------------------------------------------------------
-- Rendu
-- ---------------------------------------------------------------------------

local function ToPixels(gx, gy)
    return (gx - bounds.minx) * RC.SPACING + RC.MARGIN + offsetX,
           (gy - bounds.miny) * RC.SPACING + RC.MARGIN + offsetY
end

local Rebuild, CentreOn

-- ---------------------------------------------------------------------------
-- Socketing: what a cell carries, and the gestures that put it there
-- ---------------------------------------------------------------------------

-- WHAT A CELL SHOWS TODAY. While it is unbought, the grid announces what it will
-- give -- the stone in the definition. Once bought, it shows what it really
-- carries: a socketed stone may have replaced the original, and the pin may have
-- emptied it.
function ACT.Effectif(n)
    if IsActive(n.id) then
        local c = STATE.content[n.id]
        if c then return c.stat, c.amount or 0, c.quality or 0 end
        return nil, 0, 0
    end
    -- WHAT THE ACCOUNT HOLDS COUNTS BEFORE THE PURCHASE TOO: a node emptied or
    -- refilled by another character of the account shows as it is, and that is what
    -- the purchase will give.
    local account = STATE and STATE.contentCount and STATE.contentCount[n.id]
    if account ~= nil then
        local effect = CAT.stones[account]
        if effect then return effect.stat, effect.amount or 0, effect.quality or 0 end
        return nil, 0, 0
    end
    return n.stat, n.amount or 0, n.quality or 0
end

-- True if the cell is bought and carries nothing: the only case where something
-- can be socketed. `raw` is zero for a cell emptied and for a node born empty
-- alike.
function ACT.IsEmpty(n)
    return IsActive(n.id) and (not STATE.raw or (STATE.raw[n.id] or 0) == 0)
end

-- The rune a socket carries, or nothing. `content` speaks only of stones, whose
-- effect is known; for a rune it is `raw` that knows what is set, and the
-- catalogue that knows how to describe it.
function ACT.SocketedRune(n)
    if not (STATE and STATE.raw) then return nil end
    local entry = STATE.raw[n.id]
    if not entry or entry == 0 then return nil end
    -- The two kinds: `spell` marks a rank rune, `pct` a statistic rune. A stone's
    -- descriptor carries `stat` as well, hence the choice of `pct` as the mark.
    local r = CAT.runes[entry] or CAT.statRunes[entry]
    if not r then return nil end
    return r, entry
end

-- A rune grants its rank only if the player ALREADY knows the game's last rank:
-- a talent forgotten leaves it socketed but inert, and the module does not turn
-- it out. The server sends, with the state, those met at that moment -- since
-- that follows the talents.
function ACT.RuneActive(entry)
    -- A statistic rune has no condition at all: it raises what the grid grants,
    -- whatever happens.
    if entry and CAT.statRunes[entry] then return true end
    local r = entry and CAT.runes[entry]
    if not r then return false end
    if not (r.required and r.required > 0) then return true end
    return (STATE and STATE.requiredOk and STATE.requiredOk[entry]) and true or false
end

-- How many runes OF THIS ENTRY are already socketed. It is exactly the module's
-- rule -- at most three identical entries in one grid -- and it holds for both
-- kinds of rune, an entry standing for a family of spell as well as for a
-- statistic.
function ACT.CountRunes(entry)
    local n = 0
    if not (entry and DEF and STATE and STATE.raw) then return n end
    for _, e in ipairs(DEF.nodes) do
        if STATE.raw[e.id] == entry then n = n + 1 end
    end
    return n
end

-- A bought and empty cell can take something: a stone if it is a node, a rune if
-- it is a socket. A spell cell never takes anything.
function ACT.CanSocket(n)
    return (n.kind == 0 or n.kind == 1) and ACT.IsEmpty(n)
end

-- The module settles it for good; what is plainly impossible is refused here, so
-- as not to offer a gesture bound to fail.
--
-- A RANK rune belongs to a class and is only socketed into that class's grid. It
-- drops with no condition all the same: that is deliberate, and the workbench is
-- what makes it useful. Statistic runes carry no such tie.
function ACT.BonneClasse(entry)
    local r = entry and CAT.runes[entry]
    if not r or not r.class or r.class == 0 then return true end
    return not DEF or not DEF.class or DEF.class == r.class
end

function ACT.AccepteObjet(n, entry)
    if not ACT.CanSocket(n) then return false end
    if n.kind == 1 then
        if not ACT.BonneClasse(entry) then return false end
        return (CAT.runes[entry] or CAT.statRunes[entry]) ~= nil
    end
    return CAT.stones[entry] ~= nil
end

-- What the catalogue says of an item entry. A stone goes into a node, a rune
-- into a socket: the module settles that, and here we only recognise the item
-- and know how to describe it.
function ACT.Socketable(entry)
    if not entry then return nil end
    return CAT.stones[entry] or CAT.runes[entry] or CAT.statRunes[entry]
end

function ACT.PinEntry()
    return (CAT.pin and CAT.pin > 0) and CAT.pin or RC.PIN_ENTRY
end

function ACT.IsPin(entry)
    return entry == ACT.PinEntry()
end

-- "Rune de Frappe heroique", but "Rune d'Onde de choc": in French, "de" elides
-- before a vowel or a silent h. The same rule as the name the module gives the
-- item, so the two read alike.
local function OfSpell(spellName)
    local d = (spellName or ""):sub(1, 1)
    return (("aeiouyhAEIOUYHàâäéèêëîïôöùûüÿœÀÂÄÉÈÊËÎÏÔÖÙÛÜŒ"):find(d, 1, true)
            and "d'" or "de ") .. (spellName or "")
end

function ACT.ItemName(entry, descriptor)
    local name = GetItemInfo(entry)
    if name then return name end
    -- A SOCKETED rune is no longer in the bags, so the client does not necessarily
    -- have its name cached -- and without it the pin announced "+0 ?".
    if descriptor and descriptor.spell then
        local spellName = GetSpellInfo(descriptor.spell)
                        or fmt(L.spell_unknown, descriptor.spell)
        -- The elision is French only: "Rune of X" in English.
        return fmt(L.rune_item, FR and OfSpell(spellName) or spellName)
    end
    if descriptor and descriptor.pct then
        local statName = STAT_LABELS[descriptor.stat] or "?"
        return fmt(L.rune_item, FR and OfSpell(statName) or statName)
    end
    if descriptor then
        return fmt("+%d %s", descriptor.amount or 0, STAT_LABELS[descriptor.stat] or "?")
    end
    return tostring(entry)
end

function ACT.ItemIcon(entry, descriptor)
    local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(entry)
    return texture
        or (descriptor and StatIcon(descriptor.stat))
        or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Walks the player's bags. `filter` is given the entry and says whether to keep
-- it.
function ACT.WalkBags(filter, action)
    for _, bag in ipairs(RC.PLAYER_BAGS) do
        for slotIndex = 1, (GetContainerNumSlots(bag) or 0) do
            local entry = GetContainerItemID and GetContainerItemID(bag, slotIndex)
            if not entry then
                local link = GetContainerItemLink(bag, slotIndex)
                entry = link and tonumber(link:match("item:(%d+)"))
            end
            if entry and filter(entry) then
                local _, count = GetContainerItemInfo(bag, slotIndex)
                action(entry, count or 1)
            end
        end
    end
end

function ACT.CountInBags(entry)
    local total = 0
    ACT.WalkBags(function(e) return e == entry end,
        function(_, count) total = total + count end)
    return total
end

-- What the player carries that can go into THIS cell, grouped by entry and
-- ordered as the summary is: by statistic, then by quality.
function ACT.StonesInBags(n)
    local byEntry, list = {}, {}
    ACT.WalkBags(function(e)
            if n then return ACT.AccepteObjet(n, e) end
            return ACT.Socketable(e) ~= nil
        end,
        function(e, count)
            if byEntry[e] then
                byEntry[e].count = byEntry[e].count + count
            else
                local p = ACT.Socketable(e)
                byEntry[e] = { entry = e, count = count, stat = p.stat,
                                 amount = p.amount, quality = p.quality,
                                 spell = p.spell, rank = p.rank }
                list[#list + 1] = byEntry[e]
            end
        end)

    local rank = {}
    for i, key in ipairs(STAT_ORDER) do rank[key] = i end
    table.sort(list, function(a, b)
        local ra, rb = rank[a.stat] or 99, rank[b.stat] or 99
        if ra ~= rb then return ra < rb end
        return (a.quality or 0) > (b.quality or 0)
    end)
    return list
end

function ACT.ClosePicker()
    if UI and UI.picker then UI.picker:Hide() end
end

-- --- an item taken in hand ------------------------------------------------
-- Right-clicking a stone, a rune or a pin in a bag opens the sphere grid and
-- takes the item IN HAND: the cursor turns to application mode and a banner
-- recalls what is held. A left-click on a cell then does exactly what the
-- matching gesture would do in the interface.
function ACT.UpdateBanner()
    if not UI or not UI.banner then return end
    local m = ACT.inHand
    if not m then
        UI.banner:SetText("")
        UI.bannerIcon:Hide()
        return
    end
    UI.banner:SetText(fmt(m.pin and L.hand_pin or L.hand_stone,
        ACT.ItemName(m.entry, m.descriptor)))
    UI.bannerIcon:SetTexture(ACT.ItemIcon(m.entry, m.descriptor))
    UI.bannerIcon:Show()
end

-- What the item in hand can be aimed at. The pin empties a filled cell; a stone
-- or a rune fills an empty cell of the right kind.
function ACT.ValidTarget(n)
    local m = ACT.inHand
    if not m or not n then return false end
    if m.pin then return IsActive(n.id) and not ACT.IsEmpty(n) end
    return ACT.AccepteObjet(n, m.entry)
end

-- The application cursor: barred everywhere, plain over anything that can
-- receive the item.
function ACT.UpdateCursor()
    if not ACT.inHand or not SetCursor then return end
    SetCursor(ACT.ValidTarget(ACT.hover) and RC.CURSOR_HAND or RC.CURSOR_HAND_NO)
end

function ACT.TakeInHand(entry)
    local descriptor = ACT.Socketable(entry)
    if not descriptor and not ACT.IsPin(entry) then return false end

    ACT.inHand = { entry = entry, descriptor = descriptor,
                   pin = descriptor == nil }
    ACT.hover = nil
    -- The click that just took the item is still down: without this, the watch below
    -- would take it for a "click elsewhere".
    ACT.lastClick = true
    ACT.UpdateCursor()
    ACT.UpdateBanner()
    return true
end

function ACT.PutDown()
    if not ACT.inHand then return end
    ACT.inHand = nil
    ACT.hover = nil
    if ResetCursor then ResetCursor() end
    ACT.UpdateBanner()
end

-- The heartbeat of the "item in hand" mode, every frame while the window is
-- open. It holds two things:
--
-- 1. THE CURSOR, asserted continuously -- other frames of the game call
--    ResetCursor() as soon as they are hovered (CursorUpdate in UIParent.lua),
--    and ours must hold until the gesture is cancelled;
-- 2. "ANY CLICK ELSEWHERE PUTS THE ITEM DOWN". The mouse buttons are WATCHED
--    rather than the clicks intercepted: a frame catching them would stop them
--    reaching the rest of the interface. Only the rising edge counts.
function ACT.Battement()
    if not ACT.inHand then return end

    ACT.UpdateCursor()

    if not (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")) then
        ACT.lastClick = false
        return
    end
    if ACT.lastClick then return end
    ACT.lastClick = true

    -- An open confirmation carries the gesture on: it is not an elsewhere.
    if StaticPopup_Visible("SPHEREGRID_SOCKET") or StaticPopup_Visible("SPHEREGRID_PIN") then
        return
    end

    -- A cell is hovered: it is ITS click, and it decides. Putting the item down here,
    -- on the press, would let the release fall back into the click's ordinary
    -- behaviour -- an unbought cell would then offer its purchase, which is not the
    -- gesture asked for.
    if ACT.hover then return end

    ACT.PutDown()
end

function ACT.Socket(nodeId, entry)
    ACT.ClosePicker()
    AIO.Handle("SphereGridPlayer", "Socket", nodeId, entry)
    ACT.PutDown()
end

-- A stone actually held by the game's own cursor, dragged from a bag: the same
-- gesture, a different source.
function ACT.CursorStone()
    if not CursorHasItem or not CursorHasItem() then return nil end
    local kind, a, link = GetCursorInfo()
    if kind ~= "item" then return nil end
    local entry = tonumber(a) or (link and tonumber(tostring(link):match("item:(%d+)")))
    if entry and ACT.Socketable(entry) then return entry end
    return nil
end

local function PickerLine(list, i, line)
    local p = list[i]
    if not p then line:Hide() return end

    local q = RC.QUALITY_COLORS[p.quality or 1] or RC.QUALITY_COLORS[1]
    line.iconFile:SetTexture(ACT.ItemIcon(p.entry, p))
    line.name:SetText(ACT.ItemName(p.entry, p))
    line.name:SetTextColor(q[1], q[2], q[3])
    -- A rune carries no statistic: it grants a rank. So we say which one rather than
    -- showing "+0 ?".
    local count = p.count > 1 and fmt("  x%d", p.count) or ""
    if p.pct then
        line.effect:SetText(fmt("+%d %%%%  %s",
            p.pct * (ACT.CountRunes(p.entry) + 1),
            STAT_LABELS[p.stat] or "?") .. count)
        line.effect:SetTextColor(0.1, 1, 0.1)
    elseif p.spell then
        -- The rank promised counts what is already socketed: the second rune of a family
        -- gives the next one, not the first.
        line.effect:SetText(fmt(L.rune_rank,
            (p.rank or 0) + ACT.CountRunes(p.entry)) .. count)
        if ACT.RuneActive(p.entry) then
            line.effect:SetTextColor(0.1, 1, 0.1)
        else
            line.effect:SetTextColor(RC.RUNE_INERT[1], RC.RUNE_INERT[2], RC.RUNE_INERT[3])
        end
    else
        line.effect:SetText(fmt("+%d %s%s", p.amount or 0,
            STAT_LABELS[p.stat] or "?", count))
        line.effect:SetTextColor(0.1, 1, 0.1)
    end
    line.entry = p.entry
    line:Show()
end

function ACT.FillPicker()
    local frame = UI.picker
    -- Offer only what can go in here: stones for a node, runes for a socket.
    local list = ACT.StonesInBags(nodeById[frame.node])
    frame.list = list

    local maxi = max(0, #list - RC.PICK_ROWS)
    if frame.offset > maxi then frame.offset = maxi end

    for i = 1, RC.PICK_ROWS do
        PickerLine(list, i + frame.offset, frame.lines[i])
    end
    frame.empty:SetText(#list == 0 and L.picker_empty
        or (#list > RC.PICK_ROWS and L.picker_scroll or ""))
end

function ACT.OpenPicker(btn, n)
    if not UI.picker then
        local frame = CreateFrame("Frame", "SphereGridStonePicker", UI)
        frame:SetFrameStrata("DIALOG")
        frame:SetWidth(RC.PICK_W)
        frame:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 24,
            insets = { left = 6, right = 6, top = 6, bottom = 6 },
        })
        frame:EnableMouse(true)
        frame:EnableMouseWheel(true)
        frame:SetScript("OnMouseWheel", function(self, delta)
            local maxi = max(0, #(self.list or {}) - RC.PICK_ROWS)
            self.offset = min(maxi, max(0, self.offset - delta))
            ACT.FillPicker()
        end)

        local title = frame:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
        title:SetPoint("TOPLEFT", RC.PICK_PAD + 2, -RC.PICK_PAD - 2)
        title:SetText(L.picker_title)

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetWidth(24)
        close:SetHeight(24)
        close:SetPoint("TOPRIGHT", -4, -4)

        frame.lines = {}
        for i = 1, RC.PICK_ROWS do
            local line = CreateFrame("Button", nil, frame)
            line:SetWidth(RC.PICK_W - 2 * RC.PICK_PAD - 4)
            line:SetHeight(RC.PICK_ROW_H)
            line:SetPoint("TOPLEFT", RC.PICK_PAD + 2,
                -(RC.PICK_PAD + 20) - (i - 1) * RC.PICK_ROW_H)
            line:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")

            line.iconFile = line:CreateTexture(nil, "ARTWORK")
            line.iconFile:SetWidth(RC.PICK_ICON)
            line.iconFile:SetHeight(RC.PICK_ICON)
            line.iconFile:SetPoint("LEFT")

            line.name = line:CreateFontString(nil, "OVERLAY", "GameTooltipText")
            line.name:SetPoint("LEFT", RC.PICK_ICON + 6, 5)
            line.name:SetJustifyH("LEFT")

            line.effect = line:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
            line.effect:SetPoint("LEFT", RC.PICK_ICON + 6, -5)
            line.effect:SetJustifyH("LEFT")
            line.effect:SetTextColor(0.1, 1, 0.1)

            line:SetScript("OnClick", function(self)
                if self.entry and frame.node then
                    ACT.AskSocket(frame.node, self.entry)
                end
            end)
            frame.lines[i] = line
        end

        frame.empty = frame:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
        frame.empty:SetPoint("BOTTOMLEFT", RC.PICK_PAD + 2, RC.PICK_PAD + 2)

        frame:SetHeight(RC.PICK_PAD * 2 + 20 + RC.PICK_ROWS * RC.PICK_ROW_H + 16)
        table.insert(UISpecialFrames, "SphereGridStonePicker")
        UI.picker = frame
    end

    UI.picker.node = n.id
    UI.picker.offset = 0
    UI.picker:ClearAllPoints()
    UI.picker:SetPoint("TOPLEFT", btn, "BOTTOMRIGHT", 4, 0)
    UI.picker.anchor = btn
    ACT.FillPicker()
    UI.picker:Show()
end

-- The confirm button of a pin is greyed while the player carries none: the
-- module's refusal would still be the real barrier, but it is better to show at
-- once that the gesture cannot be made.
StaticPopupDialogs["SPHEREGRID_PIN"] = {
    text = "%s",
    button1 = L.confirm,
    button2 = L.cancel,
    OnShow = function(self)
        local button = _G[self:GetName() .. "Button1"]
        if not button then return end
        if ACT.CountInBags(ACT.PinEntry()) > 0 then
            button:Enable()
        else
            button:Disable()
        end
    end,
    OnAccept = function(self, data)
        AIO.Handle("SphereGridPlayer", "Pin", data)
    end,
    -- OnHide covers all three ways out: confirm, cancel and Escape.
    OnHide = function() ACT.PutDown() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

-- Set just before opening: `OnShow` is called BEFORE the caller fills
-- `popup.data`, so it can read nothing from it. The same detour as for the pin,
-- which greys its button when the bags hold none.
local socketBlocked = false

-- Socketing consumes the stone, so it is confirmed, as pinning is.
StaticPopupDialogs["SPHEREGRID_SOCKET"] = {
    text = "%s",
    button1 = L.confirm,
    button2 = L.cancel,
    OnShow = function(self)
        local button = _G[self:GetName() .. "Button1"]
        if not button then return end
        if socketBlocked then button:Disable() else button:Enable() end
    end,
    OnAccept = function(self, data)
        -- Belt and braces: the button is greyed, but refusing a second time costs
        -- nothing.
        if socketBlocked then return end
        if data then ACT.Socket(data.node, data.entry) end
    end,
    OnHide = function() ACT.PutDown() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

function ACT.AskSocket(nodeId, entry)
    local descriptor = ACT.Socketable(entry)
    if not descriptor then return end
    ACT.ClosePicker()

    local q = RC.QUALITY_COLORS[descriptor.quality or 1] or RC.QUALITY_COLORS[1]
    local name = fmt("|cff%02x%02x%02x%s|r", q[1] * 255, q[2] * 255, q[3] * 255,
        ACT.ItemName(entry, descriptor))
    local effect
    socketBlocked = false
    -- A last line of defence: the lists no longer offer another class's runes, but a
    -- loaded cursor or a drop could still lead there.
    if descriptor.spell and not ACT.BonneClasse(entry) then
        socketBlocked = true
        local popup = StaticPopup_Show("SPHEREGRID_SOCKET",
            fmt(L.socket_text, name, "|r|cffff4444" .. L.rune_class .. "|r"))
        if popup then popup.data = { node = nodeId, entry = entry } end
        return
    end

    if descriptor.pct then
        -- A statistic rune: what counts is the TOTAL increase it will carry, stacking
        -- included.
        local already = ACT.CountRunes(entry)
        if already >= CAT.runesPerSpell then
            socketBlocked = true
            local popup = StaticPopup_Show("SPHEREGRID_SOCKET",
                fmt(L.socket_text, name, "|r|cffff4444" .. L.rune_max_s .. "|r"))
            if popup then popup.data = { node = nodeId, entry = entry } end
            return
        end
        effect = fmt(L.rune_stat_placed, descriptor.pct * (already + 1),
                    STAT_LABELS[descriptor.stat] or "?")
    elseif descriptor.spell then
        local spellName = GetSpellInfo(descriptor.spell)
                        or fmt(L.spell_unknown, descriptor.spell)
        local already = ACT.CountRunes(entry)
        -- The module refuses a fourth, so it is better said beforehand than learnt from
        -- an error message.
        if already >= CAT.runesPerSpell then
            socketBlocked = true
            local popup = StaticPopup_Show("SPHEREGRID_SOCKET",
                fmt(L.socket_text, name, "|r|cffff4444" .. L.rune_max .. "|r"))
            if popup then popup.data = { node = nodeId, entry = entry } end
            return
        end
        -- The rank obtained depends on what is ALREADY socketed.
        effect = fmt(L.rune_teaches, spellName, (descriptor.rank or 0) + already)
        -- A talent rune does nothing until the talent is taken: the prerequisite is
        -- announced BEFOREHAND, green when met and red when not -- and in the second
        -- case socketing is refused, since it would achieve nothing.
        if descriptor.talent and descriptor.required and descriptor.required > 0 then
            local requiredName = GetSpellInfo(descriptor.required) or spellName
            local tenu = ACT.RuneActive(entry)
            socketBlocked = not tenu
            effect = effect .. "|r\n" .. (tenu and "|cff44ff44" or "|cffff4444")
                .. fmt(L.rune_required, requiredName) .. "|r"
        end
    else
        effect = fmt("+%d %s", descriptor.amount or 0,
                    STAT_LABELS[descriptor.stat] or "?")
    end
    local popup = StaticPopup_Show("SPHEREGRID_SOCKET", fmt(L.socket_text, name, effect))
    if popup then popup.data = { node = nodeId, entry = entry } end
end

-- THE PIN DESTROYS what the cell holds: never without confirmation. How many
-- pins are in the bags is recalled; if there are none the module will refuse in
-- red, the rule being its.
function ACT.AskPin(n)
    if not IsActive(n.id) or ACT.IsEmpty(n) then return end

    local what, model, rankAfter
    if n.kind == 2 then
        what = (n.spell and n.spell > 0 and GetSpellInfo(n.spell)) or fmt(L.spell_unknown, n.spell or 0)
        model = L.pin_spell
    else
        local rune, entry = ACT.SocketedRune(n)
        if rune then
            -- A rune has no statistic, so it is named instead. And a rune is
            -- feminine in French, hence a sentence pattern of its own.
            what, model = ACT.ItemName(entry, rune), L.pin_rune
            -- What really decides is where one lands. With no effect, an inert rune makes
            -- nobody land anywhere, so nothing is said.
            if rune.pct then
                rankAfter = rune.pct * max(0, ACT.CountRunes(entry) - 1)
                model = L.pin_rune_pct
            elseif ACT.RuneActive(entry) then
                rankAfter = (rune.rank or 1) - 1 + max(0, ACT.CountRunes(entry) - 1)
                model = L.pin_rune_rank
            end
        else
            local stat, amount = ACT.Effectif(n)
            what, model = fmt("+%d %s", amount, STAT_LABELS[stat] or "?"), L.pin_text
        end
    end

    local pins = ACT.CountInBags(ACT.PinEntry())
    local popup = StaticPopup_Show("SPHEREGRID_PIN",
        rankAfter and fmt(model, what, rankAfter, pins)
                   or fmt(model, what, pins))
    if popup then popup.data = n.id end
end

local function ShowTooltip(btn, n)
    local stat, amount, quality = ACT.Effectif(n)

    GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
    if n.kind == 1 then
        local rune, runeEntry = ACT.SocketedRune(n)
        if rune and rune.pct then
            GameTooltip:SetText(L.rune_stat_title,
                RC.SLOT_COLOR[1], RC.SLOT_COLOR[2], RC.SLOT_COLOR[3])
            GameTooltip:AddLine(fmt(L.rune_stat_desc,
                rune.pct * ACT.CountRunes(runeEntry),
                STAT_LABELS[rune.stat] or "?"), 1, 1, 1, true)
        elseif rune then
            -- THE SAME AS FOR A SPELL CELL: a rune adds a rank to a spell, and one still has
            -- to know which does what. The title "Rune" gives way to the spell's name; the
            -- line "Adds a rank to..." stays, and is what says what the rune itself does.
            local spellName = GetSpellInfo(rune.spell or 0)
                            or fmt(L.spell_unknown, rune.spell or 0)
            if GetSpellInfo(rune.spell or 0) then
                GameTooltip:SetHyperlink("spell:" .. rune.spell)
                GameTooltip:AddLine(" ")
            else
                GameTooltip:SetText(L.rune_title,
                    RC.SLOT_COLOR[1], RC.SLOT_COLOR[2], RC.SLOT_COLOR[3])
            end
            GameTooltip:AddLine(fmt(L.rune_desc, spellName), 1, 1, 1, true)
            if not ACT.RuneActive(runeEntry) then
                local c = RC.RUNE_INERT
                GameTooltip:AddLine(rune.talent and L.rune_off
                    or fmt(L.rune_off_r, GetSpellInfo(rune.required or 0) or spellName),
                    c[1], c[2], c[3], true)
            end
        else
            GameTooltip:SetText(L.slot, RC.SLOT_COLOR[1], RC.SLOT_COLOR[2], RC.SLOT_COLOR[3])
            GameTooltip:AddLine(L.slot_desc, 0.8, 0.8, 0.8, true)
        end
    elseif n.kind == 2 then
        -- THE SPELL'S OWN TOOLTIP: cost, range, cast time, cooldown and description, as
        -- the client reads them from its Spell.dbc. Only the NAME used to be written,
        -- and the player bought without knowing what for.
        --
        -- SetHyperlink REPLACES the whole content of the tooltip, so it comes first and
        -- the grid's own lines follow. It is the call to use, not SetSpellByID, which
        -- does not exist in 3.3.5.
        local spellName = n.spell and n.spell > 0 and GetSpellInfo(n.spell)
        if spellName then
            GameTooltip:SetHyperlink("spell:" .. n.spell)
            -- An empty line, without which the grid's sentence would read as a continuation
            -- of the spell's description.
            GameTooltip:AddLine(" ")
        else
            -- A spell missing from the client's Spell.dbc: the older display is better than
            -- an empty tooltip.
            GameTooltip:SetText(L.spell_title,
                RC.SPELL_COLOR[1], RC.SPELL_COLOR[2], RC.SPELL_COLOR[3])
            GameTooltip:AddLine(fmt(L.spell_unknown, n.spell or 0), 1, 1, 1, true)
        end
        -- A pinned spell stays in the grid, but is no longer learned.
        if IsActive(n.id) and ACT.IsEmpty(n) then
            GameTooltip:AddLine(L.content_forgotten, 1, 0.5, 0.1, true)
        else
            GameTooltip:AddLine(L.spell_desc, 0.8, 0.8, 0.8, true)
        end
    elseif not stat then
        GameTooltip:SetText(L.node_empty,
            RC.EMPTY_NODE_COLOR[1], RC.EMPTY_NODE_COLOR[2], RC.EMPTY_NODE_COLOR[3])
        GameTooltip:AddLine(IsActive(n.id) and L.empty_active or L.empty_desc, 0.8, 0.8, 0.8, true)
    else
        local q = RC.QUALITY_COLORS[quality] or RC.QUALITY_COLORS[1]
        local qual = QUALITIES[quality] or QUALITIES[1]
        GameTooltip:SetText(L.node, 1, 1, 1)
        GameTooltip:AddLine(fmt(L.stone, qual and qual.label or "?"), q[1], q[2], q[3], true)
        GameTooltip:AddLine(fmt("+%d %s", amount, STAT_LABELS[stat] or "?"), 0.1, 1, 0.1, true)
    end

    if DEF and DEF.start == n.id then
        GameTooltip:AddLine(L.start, 1, 0.82, 0, true)
    end

    GameTooltip:AddLine(" ")
    if IsActive(n.id) then
        GameTooltip:AddLine(L.state_active, 0.2, 1, 0.2, true)
        -- What the player can do here, right now.
        if ACT.CanSocket(n) then
            GameTooltip:AddLine(n.kind == 1 and L.act_socket_r or L.act_socket, 1, 0.82, 0, true)
            GameTooltip:AddLine(L.act_drop, 0.6, 0.6, 0.6, true)
        elseif not ACT.IsEmpty(n) then
            GameTooltip:AddLine(L.act_pin, 1, 0.82, 0, true)
        end
    else
        local path = PathTo(n.id)
        if not path then
            GameTooltip:AddLine(L.unreachable, 0.6, 0.6, 0.6, true)
        else
            local cost = PathCost(path)
            local enough = STATE and STATE.available >= cost
            local text = (#path == 1) and fmt(L.state_cost, cost)
                or fmt(L.state_path, #path, cost)
            GameTooltip:AddLine(text,
                enough and 1 or 1, enough and 0.82 or 0.25, enough and 0 or 0.25, true)
        end
    end
    GameTooltip:Show()
end

StaticPopupDialogs["SPHEREGRID_BUY"] = {
    text = "%s",
    button1 = L.buy,
    button2 = L.cancel,
    OnAccept = function(self, data)
        AIO.Handle("SphereGridPlayer", "BuyPath", data)
    end,
    -- Covers all three ways out: buy, cancel and Escape.
    OnHide = function()
        if buying then
            buying = nil
            Rebuild()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- RESETTING: hand the whole grid back and recover the Spherite spent on this
-- character. It is all in the module's command; the client only asks for
-- confirmation, then refreshes on the answer.
StaticPopupDialogs["SPHEREGRID_RESET"] = {
    text = L.reset_text,
    button1 = L.confirm,
    button2 = L.cancel,
    OnAccept = function()
        AIO.Handle("SphereGridPlayer", "Reset")
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    showAlert = true,
}

-- EVERY GESTURE ON THE GRID COMES THROUGH HERE.
--
-- An UNBOUGHT cell: the shortest path from what is already active is worked out,
-- its total cost shown, and the purchase -- once confirmed -- is made in one go.
-- A BOUGHT cell: left-click to socket (the stone on the cursor, failing that the
-- list of stones in the bags), right-click for the pin. A spell cell emptied by
-- the pin is learned again with one click, at the usual cost.
local function OnNodeClick(n, button, btn)
    -- An item taken in hand from a bag takes precedence over everything else.
    -- Right-click puts it down, left-click applies it wherever that is possible.
    if ACT.inHand then
        if button == "RightButton" or not ACT.ValidTarget(n) then
            ACT.PutDown()
        elseif ACT.inHand.pin then
            ACT.AskPin(n)
        else
            ACT.AskSocket(n.id, ACT.inHand.entry)
        end
        return
    end

    if IsActive(n.id) then
        if button == "RightButton" then
            ACT.AskPin(n)
        elseif ACT.CanSocket(n) then
            local entry = ACT.CursorStone()
            if entry then
                ClearCursor()
                ACT.AskSocket(n.id, entry)
            else
                ACT.OpenPicker(btn, n)
            end
        elseif n.kind == 2 and ACT.IsEmpty(n) then
            -- LEARNING AGAIN IS PAID FOR ONLY IF THE SPELL WAS GIVEN BACK. A cell
            -- whose spell arrived after the purchase -- a grid that gained one, a
            -- class that did -- is learned for nothing, and the module charges
            -- nothing either; `forgotten` is what tells the two apart
            -- (SphereGridPlayerMgr.cpp). Free, there is nothing to confirm.
            local cost = (STATE.forgotten and STATE.forgotten[n.id]) and NodeCost(n.id) or 0
            if cost == 0 then
                AIO.Handle("SphereGridPlayer", "Buy", n.id)
                return
            end
            if STATE.available < cost then
                AIO.Handle("SphereGridPlayer", "Reject")
                return
            end
            local popup = StaticPopup_Show("SPHEREGRID_BUY", fmt(L.confirm_spell, cost))
            if popup then popup.data = { n.id } end
        end
        return
    end

    if button == "RightButton" then return end

    local path = PathTo(n.id)
    if not path then return end
    local cost = PathCost(path)

    -- Not enough Spherite: the purchase is not even offered. The refusal is asked of
    -- the server rather than shown here, so that it travels the same red channel as
    -- every other refusal of the module -- one wording, one look.
    if not STATE or STATE.available < cost then
        AIO.Handle("SphereGridPlayer", "Reject")
        return
    end

    local text = (#path == 1) and fmt(L.confirm, cost)
        or fmt(L.confirm_path, #path, cost)
    local popup = StaticPopup_Show("SPHEREGRID_BUY", text)
    if not popup then return end
    popup.data = path

    buying = {}
    for _, id in ipairs(path) do buying[id] = true end
    Rebuild()
end

-- A POOL OF SPARKS: one spark runs along every ACTIVE, SHOWN link; it is taken
-- when the link enters the window and returned when it leaves. Speed and
-- direction are drawn at creation and kept from one use to the next.
local function TakeSpark()
    local s = table.remove(UI.sparksFree)
    if not s then
        local tex = UI.canvas:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(RC.SPARK_TEXTURE)
        tex:SetBlendMode("ADD")
        tex:SetWidth(RC.SPARK_SIZE)
        tex:SetHeight(RC.SPARK_SIZE)
        local v = RC.SPARK_VMIN + math.random() * (RC.SPARK_VMAX - RC.SPARK_VMIN)
        if math.random(2) == 1 then v = -v end
        s = { tex = tex, t = math.random(), v = v }
    end
    s.tex:Show()
    local actives = UI.sparksInUse
    actives[#actives + 1] = s
    return s
end

local function ReturnSpark(s)
    s.tex:Hide()
    local actives = UI.sparksInUse
    for i = #actives, 1, -1 do
        if actives[i] == s then
            actives[i] = actives[#actives]
            actives[#actives] = nil
            break
        end
    end
    UI.sparksFree[#UI.sparksFree + 1] = s
end

-- The summary: for each statistic, what the player ALREADY has -- the sum of the
-- stones socketed in his active cells -- and what the whole grid could give him,
-- the sum of every stone it holds.
local function ComputeTotals()
    local raw, total = {}, {}
    if not DEF then return raw, total, {}, {} end

    -- What the grid could give counts what the ACCOUNT holds: an emptied node
    -- promises nothing any more, a socketed stone promises its own.
    for _, n in ipairs(DEF.nodes) do
        local stat, amount = ACT.Effectif(n)
        if stat and amount and amount ~= 0 then
            total[stat] = (total[stat] or 0) + amount
        end
    end
    for _, c in pairs(STATE and STATE.content or {}) do
        if c.stat and c.amount then
            raw[c.stat] = (raw[c.stat] or 0) + c.amount
        end
    end

    -- A statistic rune raises WHAT THE GRID GIVES: it applies to the sum of the
    -- stones, never to a raw value of the character. The same computation as the
    -- module, the cap of three runes included -- without which the panel would
    -- announce something other than the character sheet.
    local count, pct = {}, {}
    for _, n in ipairs(DEF.nodes) do
        local entry = STATE and STATE.raw and STATE.raw[n.id]
        local r = (entry and entry ~= 0) and CAT.statRunes[entry] or nil
        if r then
            count[r.stat] = (count[r.stat] or 0) + 1
            if count[r.stat] <= CAT.runesPerSpell then
                pct[r.stat] = (pct[r.stat] or 0) + r.pct
            end
        end
    end

    -- The gain is worked out, but it does NOT enter the statistic's line: that one
    -- says what the stones give, and the rune's line says what the percentage adds.
    -- Counting it on both sides would read "55" where the grid puts 50.
    local gain = {}
    for key, v in pairs(raw) do
        gain[key] = floor(v * (pct[key] or 0) / 100)
    end
    return raw, total, pct, gain
end

-- The socketed runes, grouped by spell: three runes of one family make not three
-- lines but three ranks. The catalogue gives the rank the FIRST one grants; the
-- rest climb from there.
local function ListRunes(gains)
    local lines, inerts, perEntry, order = {}, {}, {}, {}
    if not (DEF and STATE and STATE.raw) then return lines, inerts end
    for _, n in ipairs(DEF.nodes) do
        local entry = STATE.raw[n.id]
        local r = (entry and entry ~= 0)
                  and (CAT.runes[entry] or CAT.statRunes[entry]) or nil
        if r then
            if not perEntry[entry] then
                perEntry[entry] = { r = r, count = 0, active = ACT.RuneActive(entry) }
                order[#order + 1] = entry
            end
            perEntry[entry].count = perEntry[entry].count + 1
        end
    end
    -- Two separate lists: the active ones under their heading, the inert ones under
    -- theirs. A rune whose talent is no longer taken grants no rank at all, and
    -- filing it among the active ones would be a lie.
    for _, entry in ipairs(order) do
        local e = perEntry[entry]
        local r = e.r
        local seen = min(e.count, CAT.runesPerSpell)
        if r.pct then
            -- The shape asked for: the total percentage, then in brackets what it actually
            -- returns.
            lines[#lines + 1] = {
                text = fmt(L.rune_stat_line, ACT.ItemName(entry, r),
                            r.pct * seen, (gains and gains[r.stat]) or 0),
                colour = RC.RUNE_ACTIVE, hl = RC.SUMMARY_HL,
                key = entry, inert = false }
        else
            local name = GetSpellInfo(r.spell) or fmt(L.spell_unknown, r.spell or 0)
            if e.active then
                lines[#lines + 1] = {
                    text = fmt(L.rune_line, name, (r.rank or 1) + seen - 1),
                    colour = RC.RUNE_ACTIVE, hl = RC.SUMMARY_HL,
                    key = entry, inert = false }
            else
                inerts[#inerts + 1] = {
                    text = fmt(r.talent and L.rune_inert_t or L.rune_inert, name),
                    colour = RC.RUNE_INERT, hl = RC.SUMMARY_HL_INERT,
                    key = entry, inert = true }
            end
        end
    end
    return lines, inerts
end

-- The current specialisation is the tree the player has put the most points in.
-- `GetTalentTabInfo` returns the very FILE NAME of its backdrop: nothing to
-- write into the code, and the picture follows a change of tree unaided.
local function SpecBackdrop()
    if not GetTalentTabInfo then return nil end
    local best, points = nil, -1
    for i = 1, (GetNumTalentTabs and GetNumTalentTabs() or 3) do
        local _, _, spent, queue = GetTalentTabInfo(i)
        if queue and (spent or 0) > points then
            best, points = queue, spent or 0
        end
    end
    return best
end

-- COVER THE PANEL WITHOUT DISTORTING IT: the picture is scaled by its height and
-- only a centred vertical band is shown. The panel being narrow, that band
-- usually falls entirely within the left-hand quarters -- the others then hide
-- themselves.
local function PutSpecBackground()
    if not (UI and UI.background and UI.summaryFrame) then return end
    local backdrop = SpecBackdrop()
    local width, top = UI.summaryFrame:GetWidth(), UI.summaryFrame:GetHeight()
    if not (backdrop and width and top) or width <= 0 or top <= 0 then
        for _, t in pairs(UI.background) do t:Hide() end
        return
    end

    local strip = min(1, (width / top) / RC.TALENT_RATIO)
    local u0, u1 = 0.5 - strip / 2, 0.5 + strip / 2

    for _, q in ipairs(RC.TALENT_QUARTERS) do
        local t = UI.background[q.corner]
        local a, b = max(q.u0, u0), min(q.u1, u1)
        if b <= a then
            t:Hide()
        else
            t:SetTexture(fmt(RC.TALENT_PATH, backdrop, q.corner))
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", UI.summaryFrame, "TOPLEFT",
                       (a - u0) / strip * width, -q.v0 * top)
            t:SetWidth((b - a) / strip * width)
            t:SetHeight((q.v1 - q.v0) * top)
            t:SetTexCoord((a - q.u0) / (q.u1 - q.u0), (b - q.u0) / (q.u1 - q.u0),
                          0, q.vmax)
            t:Show()
        end
    end
end

local function UpdateSummary()
    if not UI or not UI.summaryLines then return end
    local earned, total, _pct, gains = ComputeTotals()

    -- The class spells first: what the grid teaches THIS character. Learned (the
    -- cell carries the spell) in green, not yet in red.
    local y = -8
    UI.spellTitle:ClearAllPoints()
    UI.spellTitle:SetPoint("TOPLEFT", 10, y)
    y = y - 18
    local placedSpells = 0
    if DEF then
        for _, n in ipairs(DEF.nodes) do
            if n.kind == 2 and (n.spell or 0) > 0 and placedSpells < #UI.spellLines then
                placedSpells = placedSpells + 1
                local line = UI.spellLines[placedSpells]
                local learned = STATE and STATE.raw and (STATE.raw[n.id] or 0) ~= 0
                local c = learned and RC.SUMMARY_TXT_FULL or RC.RUNE_INERT
                line.name:SetText(GetSpellInfo(n.spell) or fmt(L.spell_unknown, n.spell))
                line.name:SetTextColor(c[1], c[2], c[3])
                if line.frame.node ~= n.id then line.hl:Hide() end
                line.frame.node = n.id
                line.frame:ClearAllPoints()
                line.frame:SetPoint("TOPLEFT", 6, y)
                line.frame:SetPoint("TOPRIGHT", -6, y)
                line.frame:Show()
                y = y - RC.SUMMARY_H
            end
        end
    end
    for k = placedSpells + 1, #UI.spellLines do
        UI.spellLines[k].frame.node = nil
        UI.spellLines[k].hl:Hide()
        UI.spellLines[k].frame:Hide()
    end
    if placedSpells == 0 then
        UI.spellEmpty:ClearAllPoints()
        UI.spellEmpty:SetPoint("TOPLEFT", 10, y)
        UI.spellEmpty:Show()
        y = y - RC.SUMMARY_H
    else
        UI.spellEmpty:Hide()
    end

    -- Then the statistics, under their heading and their legend.
    y = y - 10
    UI.summaryTitle:ClearAllPoints()
    UI.summaryTitle:SetPoint("TOPLEFT", 10, y)
    y = y - 14
    UI.summaryHelp:ClearAllPoints()
    UI.summaryHelp:SetPoint("TOPLEFT", 10, y)
    y = y - 16

    -- A statistic the grid does not carry at all is not shown. The lines that remain
    -- are stacked again in sequence, with no gap.
    for _, key in ipairs(STAT_ORDER) do
        local line = UI.summaryLines[key]
        -- `earned` is what THE STONES give, `gains` what the statistic runes add on top.
        -- The total shown adds the two, but the colour looks only at the stones: a rune
        -- does not make a grid complete, it goes beyond it.
        local a, g, t = earned[key] or 0, gains[key] or 0, total[key] or 0
        if line and t > 0 then
            line.value:SetText(fmt("%d / %d", a + g, t))
            local c = RC.SUMMARY_TXT
            if a >= t then
                c = (g > 0) and RC.SUMMARY_TXT_OVER or RC.SUMMARY_TXT_FULL
            end
            line.name:SetTextColor(c[1], c[2], c[3])
            line.value:SetTextColor(c[1], c[2], c[3])
            line.frame:ClearAllPoints()
            line.frame:SetPoint("TOPLEFT", 6, y)
            line.frame:SetPoint("TOPRIGHT", -6, y)
            line.frame:Show()
            y = y - RC.SUMMARY_H
        elseif line then
            line.frame:Hide()
        end
    end

    -- The runes section follows the lines actually shown. Two headings: "Active
    -- runes" always, "Inactive runes" only if there are any.
    y = y - 12
    UI.runeTitle:ClearAllPoints()
    UI.runeTitle:SetPoint("TOPLEFT", 10, y)
    y = y - 16

    -- The runes follow from what the sockets carry: the server already sends the
    -- entry socketed in `raw`, and the catalogue in `runes`.
    local actives, inerts = ListRunes(gains)
    local place = 0

    local function Put(r)
        place = place + 1
        local line = UI.runeLines[place]
        if not line then return end
        line.name:SetText(r.text)
        line.name:SetTextColor(r.colour[1], r.colour[2], r.colour[3])
        line.hl:SetTexture(r.hl[1], r.hl[2], r.hl[3], 1)
        if line.frame.key ~= r.key then line.hl:Hide() end
        line.frame.key, line.frame.inert = r.key, r.inert
        line.frame:ClearAllPoints()
        line.frame:SetPoint("TOPLEFT", 6, y)
        line.frame:SetPoint("TOPRIGHT", -6, y)
        line.frame:Show()
        y = y - RC.SUMMARY_H
    end

    for _, r in ipairs(actives) do Put(r) end
    -- SetShown does not exist in 3.3.5.
    if #actives == 0 then
        UI.runeEmpty:ClearAllPoints()
        UI.runeEmpty:SetPoint("TOPLEFT", 10, y)
        UI.runeEmpty:Show()
        y = y - RC.SUMMARY_H
    else
        UI.runeEmpty:Hide()
    end

    if #inerts > 0 then
        y = y - 8
        UI.runeTitleInert:ClearAllPoints()
        UI.runeTitleInert:SetPoint("TOPLEFT", 10, y)
        UI.runeTitleInert:Show()
        y = y - 16
        for _, r in ipairs(inerts) do Put(r) end
    else
        UI.runeTitleInert:Hide()
    end

    for k = place + 1, #UI.runeLines do
        UI.runeLines[k].frame.key = nil
        UI.runeLines[k].hl:Hide()
        UI.runeLines[k].frame:Hide()
    end

    -- Nothing bought, nothing to hand back.
    if UI.reset then
        if STATE and (STATE.activeCount or 0) > 0 then
            UI.reset:Enable()
        else
            UI.reset:Disable()
        end
    end
end

local pulsePhase = 0

local function AdvancePulses(elapsed)
    local list = UI.pulses
    local n = list and #list or 0
    if n == 0 then return end
    pulsePhase = pulsePhase + elapsed
    local a = RC.PULSE_MIN + (RC.PULSE_MAX - RC.PULSE_MIN)
        * (0.5 + 0.5 * sin(pulsePhase * 2 * pi / RC.PULSE_PERIOD))
    for i = 1, n do list[i]:SetAlpha(a) end
end

local function AdvanceSparks(elapsed)
    local list = UI.sparksInUse
    for i = 1, #list do
        local s = list[i]
        local t = s.t + s.v * elapsed
        if t >= 1 then t = t - 1 elseif t < 0 then t = t + 1 end
        s.t = t
        local x, y
        if s.arc then
            local ang = s.a0 + s.da * t
            x, y = s.cx + s.r * cos(ang), s.cy + s.r * sin(ang)
        else
            x, y = s.x0 + s.dx * t, s.y0 + s.dy * t
        end
        s.tex:SetPoint("CENTER", UI.canvas, "BOTTOMLEFT", x, y)
    end
end

-- THE VISIBLE RECTANGLE, in canvas pixels. The shared grid counts 2 442 cells:
-- dressing each of them on every rebuild brought the client to its knees. Only
-- what falls inside the window is drawn, with a margin, and a rebuild happens
-- when the window has moved far enough.
--
-- Here the scrolling ALREADY counts in canvas pixels (the drag divides by the
-- zoom, see below); the half-window comes from HalfView(). The canvas's y axis
-- goes up and the scroll's goes down, hence the flip over the height.
local CULL_MARGIN = 160
local lastCull = { h = 0, v = 0 }
local HalfView

local function RectVisible()
    local vp, canvas = UI.viewport, UI.canvas
    local halfW, halfH = HalfView()
    if halfW < 1 or halfH < 1 then
        return -math.huge, -math.huge, math.huge, math.huge
    end
    local sx, sy = vp:GetHorizontalScroll(), vp:GetVerticalScroll()
    local ch = canvas:GetHeight()
    return sx - CULL_MARGIN, ch - sy - 2 * halfH - CULL_MARGIN,
           sx + 2 * halfW + CULL_MARGIN, ch - sy + CULL_MARGIN
end

local function Inside(rect, x, y)
    return x >= rect[1] and x <= rect[3] and y >= rect[2] and y <= rect[4]
end

-- ---------------------------------------------------------------------------
-- VIRTUALISED drawing
-- ---------------------------------------------------------------------------
-- The shared grid counts 2 450 cells and as many links. NOTHING IS CREATED FOR
-- WHAT IS OUTSIDE THE WINDOW: a cell entering takes a button from a pool and
-- returns it on leaving; a link entering takes its texture (and its spark, if it
-- is active) and returns them on leaving.
--   Place()   : geometry -- positions, link boxes, buckets of 256 px.
--   Cull()    : every frame of a drag, what comes in and what goes out.
--   Restyle() : a change of state or a hover -- redresses what is shown.
--   Rebuild() : the way in from before -- geometry if it changed, otherwise
--               filter and then redress.

local CELL = 256
local currentView = { 0, 0, 0, 0 }
local shownN, shownE = {}, {}         -- index -> button; link -> true
local newN, newE = {}, {}       -- the filter's buffers, reused
local lastFilter = { h = nil, v = nil, z = nil }
local geometryKey = nil

local function CellKey(x, y)
    return floor(x / CELL) * 65536 + floor(y / CELL)
end

-- A fresh button, dressed with all its textures; it will serve many cells over
-- the course of a drag. Its scripts read self.node.
local function NewButton()
    local canvas = UI.canvas
    local btn
    btn = CreateFrame("Button", nil, canvas)
    btn:SetWidth(RC.NODE_SIZE)
    btn:SetHeight(RC.NODE_SIZE)
    btn:RegisterForClicks("LeftButtonUp")
    btn:SetFrameLevel(canvas:GetFrameLevel() + 5)

    btn.disc = btn:CreateTexture(nil, "BACKGROUND")
    btn.disc:SetTexture(RC.NODE_DISC_TEXTURE)
    btn.disc:SetBlendMode("ADD")
    btn.disc:SetWidth(RC.NODE_DISC_SIZE)
    btn.disc:SetHeight(RC.NODE_DISC_SIZE)
    btn.disc:SetPoint("CENTER")
    btn.disc:SetVertexColor(RC.NODE_DISC_COLOR[1], RC.NODE_DISC_COLOR[2], RC.NODE_DISC_COLOR[3])

    btn.ring = btn:CreateTexture(nil, "OVERLAY")
    btn.ring:SetTexture(RC.NODE_RING_TEXTURE)
    btn.ring:SetBlendMode("ADD")
    btn.ring:SetWidth(RC.NODE_RING_SIZE)
    btn.ring:SetHeight(RC.NODE_RING_SIZE)
    btn.ring:SetPoint("CENTER")

    btn.hole = btn:CreateTexture(nil, "BACKGROUND")
    btn.hole:SetTexture(RC.SOCKET_SHEET)
    btn.hole:SetTexCoord(RC.SOCKET_HOLE_COORDS[1], RC.SOCKET_HOLE_COORDS[2],
        RC.SOCKET_HOLE_COORDS[3], RC.SOCKET_HOLE_COORDS[4])
    btn.hole:SetWidth(72 * RC.SLOT_SCALE)
    btn.hole:SetHeight(74 * RC.SLOT_SCALE)
    btn.hole:SetPoint("CENTER")

    btn.socket = btn:CreateTexture(nil, "BORDER")
    btn.socket:SetTexture(RC.SOCKET_SHEET)
    btn.socket:SetTexCoord(RC.SOCKET_FRAME_COORDS[1], RC.SOCKET_FRAME_COORDS[2],
        RC.SOCKET_FRAME_COORDS[3], RC.SOCKET_FRAME_COORDS[4])
    btn.socket:SetWidth(57 * RC.SLOT_SCALE)
    btn.socket:SetHeight(52 * RC.SLOT_SCALE)
    btn.socket:SetPoint("CENTER")

    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetWidth(RC.ICON_SIZE_NODE)
    btn.icon:SetHeight(RC.ICON_SIZE_NODE)
    btn.icon:SetPoint("CENTER")

    -- A frame laid over the round icon's edge (the Paragon method).
    btn.iconRim = btn:CreateTexture(nil, "OVERLAY")
    btn.iconRim:SetTexture(RC.FRAME_SHEET)
    btn.iconRim:SetTexCoord(RC.FRAME_COORDS[1], RC.FRAME_COORDS[2],
        RC.FRAME_COORDS[3], RC.FRAME_COORDS[4])
    btn.iconRim:SetWidth(RC.FRAME_SIZE)
    btn.iconRim:SetHeight(RC.FRAME_SIZE)
    btn.iconRim:SetPoint("CENTER")

    -- The spellbook's spell frame: a parchment plate under the icon, the vined frame
    -- over it (gold or brown, decided at drawing time).
    btn.sbBackground = btn:CreateTexture(nil, "BORDER")
    btn.sbBackground:SetTexture(RC.SB_SHEET)
    btn.sbBackground:SetTexCoord(RC.SB_BACKGROUND_COORDS[1], RC.SB_BACKGROUND_COORDS[2],
        RC.SB_BACKGROUND_COORDS[3], RC.SB_BACKGROUND_COORDS[4])
    btn.sbBackground:SetWidth(RC.SB_BACKGROUND_SIZE)
    btn.sbBackground:SetHeight(RC.SB_BACKGROUND_SIZE)
    btn.sbBackground:SetPoint("CENTER")

    btn.sbFrame = btn:CreateTexture(nil, "OVERLAY")
    btn.sbFrame:SetTexture(RC.SB_SHEET)
    btn.sbFrame:SetPoint("CENTER")

    -- The halo of the statistic hovered in the summary.
    btn.statHL = {}
    for k = 1, #RC.STATHL_SIZES do
        local t = btn:CreateTexture(nil, "OVERLAY")
        t:SetTexture(RC.NODE_RING_TEXTURE)
        t:SetBlendMode("ADD")
        t:SetWidth(RC.STATHL_SIZES[k])
        t:SetHeight(RC.STATHL_SIZES[k])
        t:SetPoint("CENTER")
        t:SetVertexColor(RC.STATHL_COLOR[1], RC.STATHL_COLOR[2], RC.STATHL_COLOR[3])
        t:SetAlpha(RC.STATHL_ALPHA)
        t:Hide()
        btn.statHL[k] = t
    end

    -- The white outline of a purchase awaiting confirmation: above everything else,
    -- its alpha driven by the pulse.
    btn.pulse = btn:CreateTexture(nil, "OVERLAY")
    btn.pulse:SetTexture(RC.NODE_RING_TEXTURE)
    btn.pulse:SetBlendMode("ADD")
    btn.pulse:SetWidth(RC.PULSE_SIZE)
    btn.pulse:SetHeight(RC.PULSE_SIZE)
    btn.pulse:SetPoint("CENTER")
    btn.pulse:Hide()

    btn.startRing = btn:CreateTexture(nil, "OVERLAY")
    btn.startRing:SetTexture(RC.NODE_RING_TEXTURE)
    btn.startRing:SetBlendMode("ADD")
    btn.startRing:SetWidth(RC.START_RING_SIZE)
    btn.startRing:SetHeight(RC.START_RING_SIZE)
    btn.startRing:SetPoint("CENTER")
    btn.startRing:SetVertexColor(RC.START_COLOR[1], RC.START_COLOR[2], RC.START_COLOR[3])

    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnEnter", function(self)
        if self.node then ShowTooltip(self, self.node) end
        -- Hovering tells the cursor whether the cell can take what is held: plain if it
        -- can, barred if it cannot.
        ACT.hover = self.node
        ACT.UpdateCursor()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
        ACT.hover = nil
        ACT.UpdateCursor()
    end)
    btn:SetScript("OnClick", function(self, button)
        if self.node then OnNodeClick(self.node, button, self) end
    end)
    -- A stone dropped from a bag: the same path as a click, with a loaded cursor --
    -- the game's natural gesture for socketing.
    btn:SetScript("OnReceiveDrag", function(self)
        if not self.node or not ACT.CanSocket(self.node) then return end
        local entry = ACT.CursorStone()
        if entry then
            ClearCursor()
            ACT.AskSocket(self.node.id, entry)
        end
    end)

    return btn
end

-- A cell's halo, according to what is hovered in the side bar: a statistic
-- (every stone carrying it), a rune (the sockets carrying it, red if inert), or
-- a spell (its own cell).
local function PutHalo(btn, n, eStat)
    local halo, haloC = false, RC.STATHL_COLOR
    if runeHovered then
        local r, runeEntry = ACT.SocketedRune(n)
        if r and runeEntry == runeHovered then
            halo = true
            if runeInert then haloC = RC.RUNE_INERT end
        end
    elseif spellHovered and spellHovered == n.id then
        halo = true
    elseif statHovered and eStat == statHovered then
        halo = true
    end
    for k = 1, #btn.statHL do
        if halo then
            btn.statHL[k]:SetVertexColor(haloC[1], haloC[2], haloC[3])
            btn.statHL[k]:Show()
        else
            btn.statHL[k]:Hide()
        end
    end
end

-- Hovering a line of the side bar changes only the halos: what is shown is not
-- dressed again.
local function RestyleHalos()
    for _, btn in pairs(shownN) do
        local n = btn.node
        if n then PutHalo(btn, n, (ACT.Effectif(n))) end
    end
end

-- Dressing a cell, from the character's state and what is hovered.
local function Dress(btn, n)
    local tint = 1
    if not IsActive(n.id) then
        tint = IsAffordable(n.id) and RC.DIM_AFFORDABLE or RC.DIM_INACCESSIBLE
    end

    -- What the cell really carries: the original stone while it is unbought, and
    -- what it actually holds afterwards.
    local eStat, _, eQuality = ACT.Effectif(n)

    -- A line of the summary hovered: what it names takes a halo. For a statistic,
    -- every stone carrying it, bought or not; for a rune, the sockets carrying it --
    -- in red if it is inert, the colour saying already that it grants nothing.
    PutHalo(btn, n, eStat)

    -- A cell in a pending purchase keeps its state: only its white outline pulses,
    -- to say what is about to be opened.
    if buying and buying[n.id] then
        btn.pulse:Show()
        btn.pulseOn = true
    else
        btn.pulse:Hide()
        btn.pulseOn = false
    end

    if n.kind == 1 then
        btn.disc:Hide()
        btn.ring:Hide()
        btn.iconRim:Hide()
        btn.sbBackground:Hide()
        btn.sbFrame:Hide()
        btn.hole:Show()
        btn.socket:Show()
        btn.socket:SetVertexColor(tint, tint, tint)
        btn.hole:SetAlpha(tint < 1 and (tint < 0.5 and 0.20 or 0.6) or 1)

        -- A socketed rune shows: it takes the icon of the spell it improves and sits in
        -- the setting, like a gem. Square, therefore with no portrait mask -- and the two
        -- must NEVER be mixed.
        local rune, runeEntry = ACT.SocketedRune(n)
        if rune then
            -- A rank rune takes its spell's icon, a statistic rune takes its statistic's --
            -- the same one the stones use, read off the grid.
            local path
            if rune.pct then
                path = StatIcon(rune.stat)
            else
                local _, _, iconFile = GetSpellInfo(rune.spell or 0)
                path = iconFile
            end
            path = path or "Interface\\Icons\\INV_Misc_QuestionMark"
            if btn.iconPath ~= path or btn.iconMode ~= "square" then
                btn.iconPath, btn.iconMode = path, "square"
                btn.icon:SetTexture(path)
                btn.icon:SetTexCoord(0, 1, 0, 1)
            end
            btn.icon:SetWidth(RC.ICON_SIZE_RUNE)
            btn.icon:SetHeight(RC.ICON_SIZE_RUNE)
            btn.icon:Show()

            -- Inert: the talent is no longer taken, the rune stays in place and grants
            -- nothing. THE WHOLE CELL turns red -- the icon and the setting that holds it.
            -- No extra ring: the colour says it all, and a circle would only weigh the grid
            -- down.
            if ACT.RuneActive(runeEntry) then
                btn.icon:SetVertexColor(tint, tint, tint)
            else
                local c = RC.RUNE_INERT
                btn.icon:SetVertexColor(c[1] * tint, c[2] * tint, c[3] * tint)
                btn.socket:SetVertexColor(c[1] * tint, c[2] * tint, c[3] * tint)
            end
        else
            btn.icon:Hide()
        end
    else
        btn.hole:Hide()
        btn.socket:Hide()

        -- The icon: round (a portrait mask) for stones, SQUARE for spells -- the
        -- spellbook frame surrounds a square. An empty node gets a dark opaque disc cut
        -- round, so the links do not show through.
        local path, plug, square
        if n.kind == 2 then
            local _, _, iconFile = GetSpellInfo(n.spell or 0)
            path, square = iconFile or "Interface\\Icons\\INV_Misc_QuestionMark", true
        elseif eStat then
            -- The icon follows the stone REALLY carried: the one in the definition, or the
            -- one socketed since.
            -- THE ROUND ICON IS BAKED INTO A FILE, one per statistic: no mask on the fly.
            -- Square as far as the engine is concerned.
            path, square = RC.ART_DIR .. "stat_" .. eStat, true
        else
            -- NO MORE PORTRAIT MASK. This was the LAST call to SetPortraitToTexture in the
            -- window, and the 3.3.5 client crashes there: ACCESS_VIOLATION at 0061949A, twice
            -- over, both with "Current Addon function: SetPortraitToTexture" and 126 to 137
            -- MB of Lua memory. The statistic icons had already left that API for baked round
            -- files; the 195 empty nodes were what remained.
            --
            -- RC.PLUG_TEXTURE is now a round texture with real transparency: it draws with no
            -- mask, hence `square`.
            path, plug, square = RC.PLUG_TEXTURE, true, true
        end
        btn.icon:Show()
        local mode = square and "square" or "rond"
        if btn.iconPath ~= path or btn.iconMode ~= mode then
            btn.iconPath, btn.iconMode = path, mode
            if square or not SetPortraitToTexture then
                btn.icon:SetTexture(path)
                btn.icon:SetTexCoord(0, 1, 0, 1)
            else
                -- A DEAD BRANCH, AND IT MUST STAY DEAD: all three cases above set `square`, so
                -- nothing reaches here any more. SetPortraitToTexture crashes the 3.3.5 client
                -- (ACCESS_VIOLATION at 0061949A). Never add a case without `square`: it would
                -- reopen the crash.
                --
                -- And NEVER call SetTexCoord afterwards: the engine then loses its circular mask
                -- and the icon goes square again.
                SetPortraitToTexture(btn.icon, path)
            end
        end

        if n.kind == 2 then
            -- The spellbook frame replaces the circle entirely; brown, "not learned", while
            -- the spell is not active.
            btn.disc:Hide()
            btn.ring:Hide()
            btn.iconRim:Hide()
            btn.icon:SetWidth(RC.ICON_SIZE_SPELL)
            btn.icon:SetHeight(RC.ICON_SIZE_SPELL)
            DressSpellFrame(btn, IsLearned(n.id), tint, tint, tint)
        else
            btn.disc:Show()
            btn.ring:Show()
            btn.iconRim:Show()
            btn.iconRim:SetVertexColor(tint, tint, tint)
            btn.icon:SetWidth(RC.ICON_SIZE_NODE)
            btn.icon:SetHeight(RC.ICON_SIZE_NODE)
            btn.sbBackground:Hide()
            btn.sbFrame:Hide()

            local c
            if not eStat then
                c = RC.EMPTY_NODE_COLOR
            else
                c = RC.QUALITY_COLORS[eQuality] or RC.QUALITY_COLORS[1]
            end
            btn.ring:SetVertexColor(c[1] * tint, c[2] * tint, c[3] * tint)
        end

        if plug then
            btn.icon:SetVertexColor(RC.PLUG_COLOR[1], RC.PLUG_COLOR[2], RC.PLUG_COLOR[3])
        else
            btn.icon:SetVertexColor(tint, tint, tint)
        end
    end

    if DEF.start == n.id then btn.startRing:Show() else btn.startRing:Hide() end
    btn:Show()
end

local function ReturnTexture(t)
    if not t then return end
    t:Hide()
    t:ClearAllPoints()
    local pool = UI.linePool
    pool.free[#pool.free + 1] = t
end

local function LinkColour(it)
    local actA, actB = IsActive(it.a.id), IsActive(it.b.id)
    if actA and actB then return RC.EDGE_ACTIVE, true end
    if actA or actB then return RC.EDGE_FRONT, false end
    return RC.EDGE_OFF, false
end

-- A link the pending purchase will light: both its ends will be active, and at
-- least one of them is part of the purchase.
local function LinkPulse(it)
    if not buying then return false end
    local purchaseA, purchaseB = buying[it.a.id], buying[it.b.id]
    if not (purchaseA or purchaseB) then return false end
    return (IsActive(it.a.id) or purchaseA) and (IsActive(it.b.id) or purchaseB)
end

local function DrawLink(it, col)
    local canvas, pool = UI.canvas, UI.linePool
    if it.arc then
        return DrawClusterArc(canvas, pool, it.ax, it.ay, it.bx, it.by, it.ccx, it.ccy, it.ring, col)
    end
    return DrawSegment(canvas, pool, it.ax, it.ay, it.bx, it.by, RC.EDGE_THICK, col)
end

local function PutSpark(it)
    local s = TakeSpark()
    it.spark = s
    if it.arc then
        -- The spark follows the arc and not the chord: centre, radius, and the angle
        -- travelled by the shorter way round.
        local a0 = math.atan2(it.ay - it.ccy, it.ax - it.ccx)
        local a1 = math.atan2(it.by - it.ccy, it.bx - it.ccx)
        local da = a1 - a0
        while da >  pi do da = da - 2 * pi end
        while da < -pi do da = da + 2 * pi end
        s.arc, s.cx, s.cy = true, it.ccx, it.ccy
        s.r  = sqrt((it.ax - it.ccx) ^ 2 + (it.ay - it.ccy) ^ 2)
        s.a0, s.da = a0, da
    else
        s.arc = false
        s.x0, s.y0, s.dx, s.dy = it.ax, it.ay, it.bx - it.ax, it.by - it.ay
    end
end

-- Brings a shown link into agreement with the state -- colour, spark, purchase
-- outline -- without drawing it again.
local function StyleLink(it)
    local col, active = LinkColour(it)
    if it.tex then it.tex:SetVertexColor(col[1], col[2], col[3], col[4] or 1) end
    if active and not it.spark then
        PutSpark(it)
    elseif not active and it.spark then
        ReturnSpark(it.spark)
        it.spark = nil
    end
    local pulse = LinkPulse(it)
    if pulse and not it.texPulse then
        local T = DrawLink(it, RC.PULSE_COLOR)
        -- In OVERLAY: above the link it underlines.
        if T then T:SetDrawLayer("OVERLAY") end
        it.texPulse = T
    elseif not pulse and it.texPulse then
        ReturnTexture(it.texPulse)
        it.texPulse = nil
    end
end

local function ShowLink(it)
    it.tex = DrawLink(it, (LinkColour(it)))
    it.visible = true
    StyleLink(it)
end

local function HideLink(it)
    ReturnTexture(it.tex)
    it.tex = nil
    ReturnTexture(it.texPulse)
    it.texPulse = nil
    if it.spark then
        ReturnSpark(it.spark)
        it.spark = nil
    end
    it.visible = false
end

-- The outlines that pulse, among what is shown.
local function GatherPulses()
    local list = {}
    for _, btn in pairs(shownN) do
        if btn.pulseOn then list[#list + 1] = btn.pulse end
    end
    for it in pairs(shownE) do
        if it.texPulse then list[#list + 1] = it.texPulse end
    end
    UI.pulses = list
end

local function LayOutInCells()
    local cells = {}
    for i, n in ipairs(DEF.nodes) do
        local k = CellKey(n.px, n.py)
        local c = cells[k]
        if not c then c = { n = {}, e = {} } cells[k] = c end
        c.n[#c.n + 1] = i
    end
    for _, it in ipairs(UI.links) do
        for cx = floor(it.x0 / CELL), floor(it.x1 / CELL) do
            for cy = floor(it.y0 / CELL), floor(it.y1 / CELL) do
                local k = cx * 65536 + cy
                local c = cells[k]
                if not c then c = { n = {}, e = {} } cells[k] = c end
                c.e[#c.e + 1] = it
            end
        end
    end
    UI.cells = cells
end

-- Return everything: before a new geometry, nothing shown is worth keeping.
local function ClearAll()
    for i, btn in pairs(shownN) do
        btn:Hide()
        btn.node, btn.index = nil, nil
        UI.freeButtons[#UI.freeButtons + 1] = btn
        shownN[i] = nil
    end
    for it in pairs(shownE) do
        HideLink(it)
        shownE[it] = nil
    end
    UI.linePool.used = {}
    UI.pulses = {}
end

local function Place()
    local canvas = UI.canvas

    -- The extent of the cells.
    local minx, maxx, miny, maxy
    for _, n in ipairs(DEF.nodes) do
        minx = (not minx or n.x < minx) and n.x or minx
        maxx = (not maxx or n.x > maxx) and n.x or maxx
        miny = (not miny or n.y < miny) and n.y or miny
        maxy = (not maxy or n.y > maxy) and n.y or maxy
    end
    if not minx then minx, maxx, miny, maxy = 0, 8, 0, 6 end

    bounds.minx, bounds.miny, bounds.maxx, bounds.maxy = minx, miny, maxx, maxy

    -- The canvas carries the extent OF THE CELLS plus a whole view of margin -- half
    -- a view on each side. That margin, and nothing else, is what lets the CENTRE of
    -- the camera reach the outermost cell: without it, a cell at the edge can only
    -- be brought to the edge of the view.
    --
    -- The margin counts in canvas units, where the view occupies view / zoom of
    -- them: it grows as one zooms out, which is what makes the rule hold at every
    -- zoom.
    --
    -- The `max` is there only out of caution towards the client:
    -- `GetHorizontalScrollRange` ignores the child's scale, and were it ever to bound
    -- the scrolling itself, it would do so on that wrong value. Keeping the canvas at
    -- least as wide as the RAW view plus two margins leaves the client's bound beyond
    -- ours at every zoom.
    --
    -- RC.MARGIN otherwise serves only to keep the edge cell off the canvas's own
    -- edge, where it would be clipped.
    local spanW = (maxx - minx) * RC.SPACING
    local spanH = (maxy - miny) * RC.SPACING
    local rawW = UI.viewport:GetWidth() or 0
    local rawH = UI.viewport:GetHeight() or 0
    local viewW = zoom > 0 and rawW / zoom or 0
    local viewH = zoom > 0 and rawH / zoom or 0
    local W  = spanW + max(viewW, rawW + RC.MARGIN * 2) + RC.MARGIN * 2
    local Hh = spanH + max(viewH, rawH + RC.MARGIN * 2) + RC.MARGIN * 2
    offsetX = (W - spanW) / 2 - RC.MARGIN
    offsetY = (Hh - spanH) / 2 - RC.MARGIN
    canvas:SetWidth(W)
    canvas:SetHeight(Hh)

    for _, n in ipairs(DEF.nodes) do
        n.px, n.py = ToPixels(n.x, n.y)
    end

    -- The links: their box and their shape (an arc or a segment), with no texture.
    UI.links = {}
    for _, e in ipairs(DEF.edges) do
        local a, b = nodeById[e[1]], nodeById[e[2]]
        if a and b then
            local it = { a = a, b = b, ax = a.px, ay = a.py, bx = b.px, by = b.py,
                         x0 = min(a.px, b.px), y0 = min(a.py, b.py),
                         x1 = max(a.px, b.px), y1 = max(a.py, b.py) }
            local sameRing = a.cluster ~= 0 and a.cluster == b.cluster and a.ring == b.ring
            local adjacent = sameRing and
                (abs(a.branch - b.branch) == 1 or abs(a.branch - b.branch) == 7)
            local c = adjacent and clusterById[a.cluster]
            if c then
                it.arc = true
                it.ccx, it.ccy = ToPixels(c.x, c.y)
                it.ring = a.ring
            end
            UI.links[#UI.links + 1] = it
        end
    end
    LayOutInCells()
end

local function Cull(strength)
    if not UI or not UI.cells or not DEF then return end
    local vp = UI.viewport
    local h, v = vp:GetHorizontalScroll(), vp:GetVerticalScroll()
    if not strength and h == lastFilter.h and v == lastFilter.v and zoom == lastFilter.z then
        return
    end
    lastFilter.h, lastFilter.v, lastFilter.z = h, v, zoom
    lastCull.h, lastCull.v = h, v

    local vis = currentView
    vis[1], vis[2], vis[3], vis[4] = RectVisible()
    for k in pairs(newN) do newN[k] = nil end
    for k in pairs(newE) do newE[k] = nil end
    local cells, canvas = UI.cells, UI.canvas
    local nodes = DEF.nodes

    local function visited(c)
        for _, i in ipairs(c.n) do
            local n = nodes[i]
            if Inside(vis, n.px, n.py) then
                newN[i] = true
                if not shownN[i] then
                    local btn = table.remove(UI.freeButtons) or NewButton()
                    shownN[i] = btn
                    btn.node, btn.index = n, i
                    btn:ClearAllPoints()
                    btn:SetPoint("CENTER", canvas, "BOTTOMLEFT", n.px, n.py)
                    Dress(btn, n)
                end
            end
        end
        for _, it in ipairs(c.e) do
            if not newE[it]
               and not (it.x1 < vis[1] or it.x0 > vis[3] or it.y1 < vis[2] or it.y0 > vis[4]) then
                newE[it] = true
                if not it.visible then ShowLink(it) end
                shownE[it] = true
            end
        end
    end
    if vis[1] == -math.huge then
        for _, c in pairs(cells) do visited(c) end
    else
        for cx = floor(vis[1] / CELL), floor(vis[3] / CELL) do
            for cy = floor(vis[2] / CELL), floor(vis[4] / CELL) do
                local c = cells[cx * 65536 + cy]
                if c then visited(c) end
            end
        end
    end

    -- What was shown and is no longer gives back its button or its texture.
    for i, btn in pairs(shownN) do
        if not newN[i] then
            if UI.picker and UI.picker:IsShown() and UI.picker.anchor == btn then ACT.ClosePicker() end
            btn:Hide()
            btn.node, btn.index = nil, nil
            UI.freeButtons[#UI.freeButtons + 1] = btn
            shownN[i] = nil
        end
    end
    for it in pairs(shownE) do
        if not newE[it] then
            HideLink(it)
            shownE[it] = nil
        end
    end
    UI.linePool.used = {}       -- no longer a register: each link holds its own texture
    GatherPulses()
end

local function Restyle()
    if not UI or not DEF then return end
    for i, btn in pairs(shownN) do
        Dress(btn, DEF.nodes[i])
    end
    for it in pairs(shownE) do
        StyleLink(it)
    end
    UI.linePool.used = {}
    GatherPulses()
end

function Rebuild()
    if not UI or not DEF then return end
    local vp = UI.viewport
    local key = tostring(DEF) .. ":" .. zoom .. ":" .. (vp:GetWidth() or 0) .. ":" .. (vp:GetHeight() or 0)
    if key ~= geometryKey then
        geometryKey = key
        ClearAll()
        Place()
        Cull(true)
    else
        Cull(true)
        Restyle()
    end

    -- bandeau
    UI.pointsLabel:SetText(fmt(L.points, STATE and STATE.available or 0)
        .. "   " .. fmt(L.actives, STATE and STATE.activeCount or 0, #DEF.nodes))

    PutSpecBackground()
    UpdateSummary()
end

-- ---------------------------------------------------------------------------
-- The window
-- ---------------------------------------------------------------------------

-- THE SCROLL BOUNDS ARE SET ON THE OUTERMOST CELLS, not on the canvas: the
-- centre of the view must be able to reach exactly the leftmost, rightmost,
-- topmost and bottommost cell. Bounding on the canvas brought the content's edge
-- to the screen's edge and never to its middle.
--
-- **SCROLLING COUNTS IN THE CHILD'S UNIT**, not in screen pixels. The canvas is
-- scaled by `SetScale(zoom)`, so one scroll unit is `zoom` screen pixels, and the
-- half-view between the view's edge and its centre is viewWidth / (2 x zoom)
-- canvas units. Multiplying by the zoom instead of dividing left forty-nine grid
-- units out of reach at the right edge once zoomed out, while letting the camera
-- wander into empty space on the other side. At zoom 1 the two computations
-- agree -- which is what made the fault invisible there, and only there.
--
-- `GetHorizontalScrollRange` is of no use here: the client measures it on the
-- child's RAW width, taking no account of its scale.
--
-- And vertical scrolling starts from the TOP of the canvas where our positions
-- start from the BOTTOM -- hence the flip, which also swaps the two bounds.
HalfView = function()
    local vp = UI.viewport
    if zoom <= 0 then return 0, 0 end
    return (vp:GetWidth() or 0) / (2 * zoom), (vp:GetHeight() or 0) / (2 * zoom)
end

local function ClampScroll()
    local vp = UI.viewport
    vp:UpdateScrollChildRect()
    local halfW, halfH = HalfView()
    local canvasTop = UI.canvas:GetHeight() or 0

    local xMin, yMin = ToPixels(bounds.minx, bounds.miny)
    local xMax, yMax = ToPixels(bounds.maxx, bounds.maxy)

    local hMin, hMax = xMin - halfW, xMax - halfW
    -- The TOPMOST cell gives the LOWEST scroll bound.
    local vMin = (canvasTop - yMax) - halfH
    local vMax = (canvasTop - yMin) - halfH

    vp:SetHorizontalScroll(max(hMin, min(vp:GetHorizontalScroll(), hMax)))
    vp:SetVerticalScroll(max(vMin, min(vp:GetVerticalScroll(), vMax)))
end

-- The grid point at the centre of the view. Mind the axes: vertical scrolling is
-- measured from the TOP, our positions from the BOTTOM of the canvas.
local function ViewCentre()
    local vp = UI.viewport
    local halfW, halfH = HalfView()
    local pxTop = vp:GetHorizontalScroll() + halfW
    local pyTop = vp:GetVerticalScroll() + halfH
    local px, py = pxTop, UI.canvas:GetHeight() - pyTop
    return (px - RC.MARGIN - offsetX) / RC.SPACING + bounds.minx,
           (py - RC.MARGIN - offsetY) / RC.SPACING + bounds.miny
end

-- Scrolls to bring this grid point to the centre of the view.
function CentreOn(gx, gy)
    local vp = UI.viewport
    local px, py = ToPixels(gx, gy)
    local halfW, halfH = HalfView()
    vp:UpdateScrollChildRect()
    vp:SetHorizontalScroll(px - halfW)
    vp:SetVerticalScroll((UI.canvas:GetHeight() - py) - halfH)
    ClampScroll()
    -- CENTRING FILTERS AGAIN: the drawing is filtered on the window, and centring
    -- without filtering left the shared grid invisible on opening until the first
    -- drag. Filtering by buckets is cheap, so it is replayed on every centring.
    Cull(true)
end

-- Centred zoom: the point being looked at stays in the middle, and Rebuild works
-- out the canvas size and the content's centring at the new scale.
local function SetZoom(z)
    z = max(RC.ZOOM_MIN, min(RC.ZOOM_MAX, z))
    if z == zoom then return end
    local gx, gy = ViewCentre()
    zoom = z
    UI.canvas:SetScale(zoom)
    Rebuild()               -- new geometry: everything is placed again
    CentreOn(gx, gy)      -- and filtered where the view came to rest
end

local function BuildUI()
    -- The game's own outline rather than a one-pixel hairline: it is the same as the
    -- dialog boxes use, and therefore at home on screen.
    local backdrop = {
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    }

    local f = CreateFrame("Frame", "SphereGridPlayerFrame", UIParent)
    -- THE WINDOW TAKES THE SCREEN: four fifths of the width, six sevenths of the
    -- height, never less than it was (1000 x 680). Everything else anchors to the
    -- edges, so the grid gains whatever the window gains.
    local screenW, screenH = UIParent:GetWidth() or 1024, UIParent:GetHeight() or 768
    f:SetWidth(max(1000, min(1700, floor(screenW * 0.80))))
    f:SetHeight(max(680, min(1050, floor(screenH * 0.86))))
    f:SetPoint("CENTER")
    f:SetBackdrop(backdrop)
    -- No tint: the dialog boxes' border has colours of its own, and darkening it
    -- amounted to rubbing it out.
    f:SetBackdropColor(1, 1, 1, 1)
    f:SetBackdropBorderColor(1, 1, 1, 1)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetToplevel(true)
    f:Hide()
    -- The picker list and the item in hand are satellites of the window: they do not
    -- outlive it.
    f:SetScript("OnHide", function()
        ACT.ClosePicker()
        ACT.PutDown()
    end)
    -- Escape closes the window: the client empties `UISpecialFrames` on every press,
    -- and what is not listed there never leaves that way. The `OnHide` above does the
    -- tidying, so leaving by Escape is worth leaving by the button.
    table.insert(UISpecialFrames, "SphereGridPlayerFrame")
    UI = f
    UI.freeButtons = {}
    UI.linePool    = { free = {}, used = {} }
    UI.sparksFree, UI.sparksInUse = {}, {}
    UI.links    = {}
    UI.pulses      = {}

    -- The custom spellbook's stone, under everything else: it replaces the flat grey
    -- and does not repeat, the sheet being 1024 on a side.
    local header = CreateFrame("Frame", nil, f)
    header:SetPoint("TOPLEFT", RC.INSET_L, -RC.INSET_T)
    header:SetPoint("TOPRIGHT", -RC.INSET_R, -RC.INSET_T)
    header:SetHeight(RC.HEADER_H)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() f:StartMoving() end)
    header:SetScript("OnDragStop", function() f:StopMovingOrSizing() end)
    local hBackground = header:CreateTexture(nil, "BACKGROUND")
    hBackground:SetAllPoints()
    hBackground:SetTexture(0.12, 0.12, 0.12, 1)

    local title = header:CreateFontString(nil, "OVERLAY", "GameTooltipHeaderText")
    title:SetPoint("LEFT", 12, 0)
    title:SetText(L.title)
    title:SetTextColor(1, 0.82, 0)

    UI.pointsLabel = header:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.pointsLabel:SetPoint("RIGHT", -40, 0)

    -- The banner for the item in hand: the cursor alone does not say WHAT is held.
    UI.bannerIcon = header:CreateTexture(nil, "OVERLAY")
    UI.bannerIcon:SetWidth(18)
    UI.bannerIcon:SetHeight(18)
    UI.bannerIcon:SetPoint("LEFT", title, "RIGHT", 16, 0)
    UI.bannerIcon:Hide()

    UI.banner = header:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.banner:SetPoint("LEFT", UI.bannerIcon, "RIGHT", 6, 0)
    UI.banner:SetTextColor(1, 0.82, 0)

    local close = CreateFrame("Button", nil, header, "UIPanelCloseButton")
    close:SetPoint("RIGHT", -4, 0)
    close:SetScript("OnClick", function() f:Hide() end)

    -- ----------------------------------------------------------- summary
    -- One line per statistic in the catalogue: « earned / grid total ». Hovering a
    -- line lights every stone carrying that statistic.
    -- No border of its own: it would carry the dialog boxes' one, and the two panels
    -- would end up parted by a thick stroke and set back from the edges. They touch,
    -- and a hairline separates them.
    local summary = CreateFrame("Frame", nil, f)
    summary:SetPoint("TOPLEFT", RC.INSET_L, -(RC.INSET_T + RC.HEADER_H))
    summary:SetPoint("BOTTOMLEFT", RC.INSET_L, RC.INSET_B)
    summary:SetWidth(RC.SUMMARY_W)

    -- The current specialisation's backdrop, in four quarters. It is laid here and
    -- placed again on every change of size, its cut depending on the panel's
    -- proportions.
    local hairline = f:CreateTexture(nil, "OVERLAY")
    hairline:SetPoint("TOPLEFT", summary, "TOPRIGHT", 0, 0)
    hairline:SetPoint("BOTTOMLEFT", summary, "BOTTOMRIGHT", 0, 0)
    hairline:SetWidth(RC.HAIRLINE)
    hairline:SetTexture(RC.HAIRLINE_COLOR[1], RC.HAIRLINE_COLOR[2], RC.HAIRLINE_COLOR[3], 1)

    UI.summaryFrame = summary
    UI.background = {}
    for _, q in ipairs(RC.TALENT_QUARTERS) do
        local t = summary:CreateTexture(nil, "BACKGROUND")
        t:SetAlpha(RC.TALENT_ALPHA)
        t:SetVertexColor(RC.TALENT_TINT[1], RC.TALENT_TINT[2], RC.TALENT_TINT[3])
        t:Hide()
        UI.background[q.corner] = t
    end
    summary:SetScript("OnSizeChanged", function() PutSpecBackground() end)

    -- THE CLASS SPELLS AT THE HEAD: one line per spell cell the class can see --
    -- green learned, red not yet; hovering lights the cell on the grid, as for the
    -- runes. Placed by UpdateSummary, like the rest of the panel.
    UI.spellTitle = summary:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.spellTitle:SetPoint("TOPLEFT", 10, -8)
    UI.spellTitle:SetText(L.spells_title)
    UI.spellTitle:SetTextColor(1, 0.82, 0)
    UI.spellEmpty = summary:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    UI.spellEmpty:SetText(L.spells_empty)
    UI.spellEmpty:Hide()
    UI.spellLines = {}
    for i = 1, 8 do
        local line = CreateFrame("Frame", nil, summary)
        line:SetHeight(RC.SUMMARY_H)
        line:EnableMouse(true)
        line:Hide()

        local highlight = line:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetTexture(RC.SUMMARY_HL[1], RC.SUMMARY_HL[2], RC.SUMMARY_HL[3], 1)
        highlight:Hide()

        local name = line:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        name:SetPoint("LEFT", 4, 0)
        name:SetPoint("RIGHT", -4, 0)
        name:SetJustifyH("LEFT")

        line:SetScript("OnEnter", function(self)
            if not self.node then return end
            highlight:Show()
            spellHovered = self.node
            RestyleHalos()
        end)
        line:SetScript("OnLeave", function(self)
            highlight:Hide()
            if spellHovered == self.node then
                spellHovered = nil
                RestyleHalos()
            end
        end)

        UI.spellLines[i] = { frame = line, name = name, hl = highlight }
    end

    UI.summaryTitle = summary:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.summaryTitle:SetText(L.summary_title)
    UI.summaryTitle:SetTextColor(1, 0.82, 0)

    UI.summaryHelp = summary:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    UI.summaryHelp:SetText(L.summary_help)

    -- The lines are created here, but it is UpdateSummary that places them and
    -- decides which are shown: a statistic absent from the grid is hidden, and the
    -- others stack again with no gap.
    UI.summaryLines = {}
    local y = RC.SUMMARY_Y0
    for _, key in ipairs(STAT_ORDER) do
        local line = CreateFrame("Frame", nil, summary)
        line:SetPoint("TOPLEFT", 6, y)
        line:SetPoint("TOPRIGHT", -6, y)
        line:SetHeight(RC.SUMMARY_H)
        line:EnableMouse(true)
        line:Hide()

        local highlight = line:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetTexture(RC.SUMMARY_HL[1], RC.SUMMARY_HL[2], RC.SUMMARY_HL[3], 1)
        highlight:Hide()

        local name = line:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        name:SetPoint("LEFT", 4, 0)
        name:SetText(STAT_LABELS[key] or key)

        local value = line:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        value:SetPoint("RIGHT", -4, 0)

        line:SetScript("OnEnter", function()
            highlight:Show()
            statHovered = key
            RestyleHalos()
        end)
        line:SetScript("OnLeave", function()
            highlight:Hide()
            if statHovered == key then
                statHovered = nil
                RestyleHalos()
            end
        end)

        UI.summaryLines[key] = { frame = line, name = name, value = value }
        y = y - RC.SUMMARY_H
    end

    y = y - 12
    UI.runeTitle = summary:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.runeTitle:SetPoint("TOPLEFT", 10, y)
    UI.runeTitle:SetText(L.runes_title)
    UI.runeTitle:SetTextColor(1, 0.82, 0)
    y = y - 16

    UI.runeEmpty = summary:CreateFontString(nil, "OVERLAY", "GameTooltipTextSmall")
    UI.runeEmpty:SetPoint("TOPLEFT", 10, y)
    UI.runeEmpty:SetText(L.runes_empty)

    UI.runeTitleInert = summary:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    UI.runeTitleInert:SetPoint("TOPLEFT", 10, y)
    UI.runeTitleInert:SetText(L.runes_inert)
    UI.runeTitleInert:SetTextColor(RC.RUNE_INERT[1], RC.RUNE_INERT[2], RC.RUNE_INERT[3])
    UI.runeTitleInert:Hide()

    -- FRAMES, like the statistic lines: a rune line can be hovered, and that hover
    -- lights the sockets carrying it. UpdateSummary places them and decides which are
    -- shown.
    UI.runeLines = {}
    for i = 1, 10 do
        local line = CreateFrame("Frame", nil, summary)
        line:SetPoint("TOPLEFT", 6, y - (i - 1) * RC.SUMMARY_H)
        line:SetPoint("TOPRIGHT", -6, y - (i - 1) * RC.SUMMARY_H)
        line:SetHeight(RC.SUMMARY_H)
        line:EnableMouse(true)
        line:Hide()

        local highlight = line:CreateTexture(nil, "BACKGROUND")
        highlight:SetAllPoints()
        highlight:SetTexture(RC.SUMMARY_HL[1], RC.SUMMARY_HL[2], RC.SUMMARY_HL[3], 1)
        highlight:Hide()

        local name = line:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        name:SetPoint("LEFT", 4, 0)

        line:SetScript("OnEnter", function(self)
            if not self.key then return end
            highlight:Show()
            runeHovered, runeInert = self.key, self.inert
            RestyleHalos()
        end)
        line:SetScript("OnLeave", function(self)
            highlight:Hide()
            if runeHovered == self.key then
                runeHovered, runeInert = nil, false
                RestyleHalos()
            end
        end)

        UI.runeLines[i] = { frame = line, name = name, hl = highlight }
    end

    -- THE RESET BUTTON, right at the foot of the panel: the summary fills from the
    -- top, so that corner stays free. Greyed out while nothing is bought -- there
    -- would be nothing to hand back.
    local reset = CreateFrame("Button", nil, summary, "UIPanelButtonTemplate")
    reset:SetHeight(22)
    reset:SetPoint("BOTTOMLEFT", 8, 8)
    reset:SetPoint("BOTTOMRIGHT", -8, 8)
    reset:SetText(L.reset_button)
    reset:SetScript("OnClick", function() StaticPopup_Show("SPHEREGRID_RESET") end)
    UI.reset = reset

    local viewport = CreateFrame("ScrollFrame", "SphereGridPlayerViewport", f)
    viewport:SetPoint("TOPLEFT", RC.INSET_L + RC.SUMMARY_W + RC.HAIRLINE,
                      -(RC.INSET_T + RC.HEADER_H))
    viewport:SetPoint("BOTTOMRIGHT", -RC.INSET_R, RC.INSET_B)
    viewport:EnableMouse(true)
    viewport:EnableMouseWheel(true)
    UI.viewport = viewport

    local vpBackground = viewport:CreateTexture(nil, "BACKGROUND")
    vpBackground:SetAllPoints()
    vpBackground:SetTexture(0.03, 0.03, 0.03, 1)

    local canvas = CreateFrame("Frame", "SphereGridPlayerCanvas", viewport)
    canvas:SetWidth(1400)
    canvas:SetHeight(1000)
    viewport:SetScrollChild(canvas)
    UI.canvas = canvas

    viewport:SetScript("OnMouseDown", function(self, button)
        -- An item in hand: this click serves only to put it down. Certainly not to begin
        -- a drag of the grid.
        if ACT.inHand then
            ACT.PutDown()
            return
        end
        if button ~= "LeftButton" then return end
        local scale = UIParent:GetEffectiveScale()
        startX, startY = GetCursorPosition()
        startX, startY = startX / scale, startY / scale
        startH, startV = self:GetHorizontalScroll(), self:GetVerticalScroll()
        dragging = true
    end)
    viewport:SetScript("OnMouseUp", function()
        if dragging then
            dragging = false
            Cull(true)
        end
    end)
    viewport:SetScript("OnHide", function() dragging = false end)
    viewport:SetScript("OnUpdate", function(self)
        if not dragging then return end
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        cx, cy = cx / scale, cy / scale
        -- The cursor is measured in screen pixels, the scrolling in canvas units: without
        -- the division, the content runs faster or slower than the hand as soon as one
        -- leaves zoom 1.
        local k = (zoom > 0) and zoom or 1
        self:SetHorizontalScroll(startH - (cx - startX) / k)
        self:SetVerticalScroll(startV + (cy - startY) / k)
        ClampScroll()
        Cull()                  -- cheap: every frame, with no jolts
    end)
    viewport:SetScript("OnMouseWheel", function(_, delta) SetZoom(zoom + delta * RC.ZOOM_STEP) end)

    return f
end

local function EnsureUI()
    if not UI then BuildUI() end
end

-- ---------------------------------------------------------------------------
-- Handlers AIO
-- ---------------------------------------------------------------------------

-- The catalogue arrives on its own, before any opening: it is what lets a stone
-- or a pin be recognised in a bag.
function PlayerHandlers.Catalogue(_, cat)
    if type(cat) ~= "table" then return end
    CAT.stones      = cat.stones or {}
    CAT.runes        = cat.runes or {}
    CAT.statRunes    = cat.statRunes or {}
    CAT.pin      = cat.pin or 0
    CAT.runesPerSpell = cat.runesPerSpell or 3
end

-- THE WIRE IS UNFOLDED HERE. The server sends positional arrays and nothing that
-- can be derived; we rebuild the definition as the rest of the file reads it. See
-- Compact() in player/Player.lua.
--   n : { id, kind, cluster, ring, branch, stone, spell, x*10000, y*10000 }
local function UnpackDef(wire)
    local def = { nodes = {}, edges = {}, clusters = {},
                  stones = wire.stones or {}, runes = wire.runes or {}, statRunes = wire.statRunes or {},
                  pin = wire.pin or 0, runesPerSpell = wire.runesPerSpell or 3,
                  class = wire.class, start = wire.start or 0 }
    -- COST BY DISTANCE: the price now travels PER CELL, tenth field of the wire.
    -- `byId` serves to find it again without walking the list on every tooltip.
    def.byId = {}
    for _, r in ipairs(wire.n or {}) do
        local effect = def.stones[r[6] or 0]
        local n = {
            id = r[1], kind = r[2], cluster = r[3], ring = r[4], branch = r[5],
            stat = effect and effect.stat or nil,
            amount = effect and effect.amount or 0,
            quality = effect and effect.quality or 0,
            spell = r[7] or 0,
            x = (r[8] or 0) / 10000, y = (r[9] or 0) / 10000,
            cost = r[10] or 0,
        }
        def.nodes[#def.nodes + 1] = n
        def.byId[n.id] = n
    end
    local e = wire.e or {}
    for i = 1, #e - 1, 2 do def.edges[#def.edges + 1] = { e[i], e[i + 1] } end
    for _, c in ipairs(wire.c or {}) do
        def.clusters[#def.clusters + 1] = { id = c[1], x = c[2] / 10000, y = c[3] / 10000, rot = c[4] / 10000 }
    end
    return def
end

-- The state carries only `raw` (the entry in each active cell): `actives` and
-- `content` follow from it with the catalogue of stones.
local function UnpackState(state)
    if type(state) ~= "table" then return state end
    state.raw = state.raw or {}
    state.contentCount = state.contentCount or {}
    -- The spell cells whose spell has been given back: bought, yet unlearned.
    state.forgotten = state.forgotten or {}
    state.actives, state.content = {}, {}
    for id, entry in pairs(state.raw) do
        state.actives[id] = true
        local effect = CAT.stones[entry]
        if effect then
            state.content[id] = { stat = effect.stat, amount = effect.amount, quality = effect.quality }
        end
    end
    return state
end

-- `wire` is false when the server knows we already hold this version: only the
-- state travels. Without a definition in hand for all that, we ask for everything
-- again.
function PlayerHandlers.Show(_, wire, state, version)
    EnsureUI()

    if wire then
        -- Opening refreshes the catalogue along the way: a single source.
        PlayerHandlers.Catalogue(nil, wire)

        DEF, DEF_VERSION = UnpackDef(wire), version
        nodeById, clusterById, adjacentById = {}, {}, {}
        for _, n in ipairs(DEF.nodes) do nodeById[n.id] = n end
        for _, c in ipairs(DEF.clusters) do clusterById[c.id] = c end
        for _, e in ipairs(DEF.edges) do
            adjacentById[e[1]] = adjacentById[e[1]] or {}
            adjacentById[e[2]] = adjacentById[e[2]] or {}
            table.insert(adjacentById[e[1]], e[2])
            table.insert(adjacentById[e[2]], e[1])
        end
    elseif not DEF then
        AIO.Handle("SphereGridPlayer", "Open")
        return
    end
    STATE = UnpackState(state)

    UI:Show()
    zoom = 1
    UI.canvas:SetScale(1)
    Rebuild()
    -- An item may have been taken in hand BEFORE the window existed.
    ACT.UpdateBanner()
    CentreOn((bounds.minx + bounds.maxx) / 2, (bounds.miny + bounds.maxy) / 2)
end

function PlayerHandlers.Update(_, state)
    if not UI or not DEF then return end
    STATE = UnpackState(state)
    Rebuild()
end

-- ---------------------------------------------------------------------------
-- The way in: a button on the talent window, /spheregrid
-- ---------------------------------------------------------------------------

local function Toggle()
    if UI and UI:IsShown() then
        UI:Hide()
    else
        AIO.Handle("SphereGridPlayer", "Open", DEF_VERSION)
    end
end

-- A « Sphere grid » tab to the right of the last visible tab of the talent
-- window (« Glyphs » in the ordinary case). It does not belong to that window's
-- tab system: it stays drawn « deselected » and opens a window of our own.
-- Anchored again on every opening, since which tabs are visible changes (dual
-- specialisation, pet).
local function AnchorTab(tab)
    local anchor
    for i = 1, 8 do
        local t = _G["PlayerTalentFrameTab" .. i]
        if t and t:IsShown() then anchor = t end
    end
    tab:ClearAllPoints()
    if anchor then
        tab:SetPoint("LEFT", anchor, "RIGHT", -16, 0)
    else
        tab:SetPoint("TOPLEFT", PlayerTalentFrame, "BOTTOMLEFT", 70, 61)
    end
end

local function HookTalents()
    if not PlayerTalentFrame or SphereGridTalentFrameTab then return end

    local tab = CreateFrame("Button", "SphereGridTalentFrameTab", PlayerTalentFrame,
        "CharacterFrameTabButtonTemplate")
    tab:SetText(L.button)
    if PanelTemplates_TabResize then PanelTemplates_TabResize(tab, 0) end
    if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
    tab:SetScript("OnClick", Toggle)

    AnchorTab(tab)
    PlayerTalentFrame:HookScript("OnShow", function() AnchorTab(tab) end)
end

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:SetScript("OnEvent", function(_, _, addon)
    if addon == "Blizzard_TalentUI" then HookTalents() end
end)
if IsAddOnLoaded and IsAddOnLoaded("Blizzard_TalentUI") then HookTalents() end

SLASH_SPHEREGRIDPLAYER1 = "/spheregrid"
SlashCmdList["SPHEREGRIDPLAYER"] = Toggle

-- ---------------------------------------------------------------------------
-- Right-click on a stone, a rune or a pin in a bag
-- ---------------------------------------------------------------------------
-- The game calls UseContainerItem on every right-click of an item in a bag
-- (ContainerFrame.lua, the « else » branch of ContainerFrameItemButton_OnClick).
-- We hook it rather than replace it, so the click keeps whatever meaning the
-- game gives it and gains ours. Since the green line our items DO carry a use
-- spell -- one that does nothing whatever, and exists only so the client draws
-- its description in the colour of an effect -- so the click casts that too,
-- and nothing comes of it. The window opens and the item goes « in hand »; the
-- next gesture is the interface's own, unchanged.
hooksecurefunc("UseContainerItem", function(bag, slotName)
    -- When one of these windows is open, a right-click does NOT mean « use »: it
    -- sells, it attaches to a letter, it puts up for auction. We keep out of it.
    for _, name in ipairs({ "MerchantFrame", "MailFrame", "TradeFrame", "AuctionFrame" }) do
        local frame = _G[name]
        if frame and frame:IsShown() then return end
    end

    local entry = GetContainerItemID and GetContainerItemID(bag, slotName)
    if not entry then
        local link = GetContainerItemLink(bag, slotName)
        entry = link and tonumber(link:match("item:(%d+)"))
    end
    if not entry then return end
    if not (ACT.Socketable(entry) or ACT.IsPin(entry)) then return end

    if not (UI and UI:IsShown()) then AIO.Handle("SphereGridPlayer", "Open", DEF_VERSION) end
    ACT.TakeInHand(entry)
end)

-- ---------------------------------------------------------------------------
-- The Spherite count keeps itself up to date while the window is open
-- ---------------------------------------------------------------------------
-- Spherite arrives WITHOUT THE PLAYER TOUCHING THE INTERFACE: a Nexus consumed, a
-- boss felled, a dungeon finished. The crediting happens on the C++ side, which
-- sends no AIO message -- so the server cannot warn us. It is the client that
-- asks, and only while its window is open.
--
-- TWO STAGES, so as not to redraw for nothing: we ask only for the COUNT, in one
-- request, and claim the full state only if it has moved. A Rebuild every two
-- seconds would make the tooltips flicker and would cost three database queries
-- per beat.
--
-- A frame apart, and not an OnUpdate on the window: it beats even when the window
-- does not yet exist, and disputes its script with no one.
-- The accumulator lives ON THE FRAME and not in a local: the chunk is Lua 5.1,
-- bounded to 200 locals, and this file counts a great many already.
local PULSE = 2.0
local mixer = CreateFrame("Frame")
mixer.elapsed = 0
mixer:SetScript("OnUpdate", function(self, delta)
    self.elapsed = self.elapsed + delta
    if self.elapsed < PULSE then return end
    self.elapsed = 0
    if UI and UI:IsShown() then
        AIO.Handle("SphereGridPlayer", "Points")
    end
end)

function PlayerHandlers.Points(_, available)
    if not UI or not UI:IsShown() or not STATE then return end
    if available == STATE.available then return end
    AIO.Handle("SphereGridPlayer", "Refresh")
end

-- The catalogue is asked for as soon as the code loads: that is what makes the
-- right-click above work even before the window is first opened.
AIO.Handle("SphereGridPlayer", "Catalogue")
