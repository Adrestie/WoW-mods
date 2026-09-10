# -*- coding: utf-8 -*-
# This file is part of mod-spheregrid.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
# Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

"""Collects into the module everything client side its content reaches.

    python tools/collect_client.py --source <client Data> --stock <client Data>
                                   [--locale-source frFR] [--dry-run]

Two outputs from ONE walk: the DBC rows the module adds client side, and every
file those rows name. Separating them would mean keeping the same walk twice.

`--source` is a client where the module already runs, `--stock` an untouched
one. What the first has and the second has not, AND the module's own content
names, is what has to travel with the module.

THE POINT IS THE WALK. A spell names a visual, a visual names kits, a kit names
effects and a sound, an effect names a model, and A MODEL NAMES ITS OWN
TEXTURES and the skin files the client will look for beside it. Stop anywhere
along that chain and the game draws a pink chequerboard, or nothing.

None of it lives on a server: SpellVisual, SpellVisualKit and
SpellVisualEffectName are never read there. Comparing two `Data/dbc` folders
sees nothing of this, which is exactly how it came to be missed.

This is an AUTHORING tool. It runs once, where both clients are, and its output
is what the module ships. An operator never runs it.
"""
import argparse
import io
import os
import re
import struct
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
MODULE = os.path.normpath(os.path.join(HERE, os.pardir))
sys.path.insert(0, HERE)
from spheregrid import dbc, m2, mpq, owned, sqlrows

ART = os.path.join(MODULE, "data", "art")
DBCS = os.path.join(MODULE, "data", "dbc")
CPP = os.path.join(os.path.dirname(
    os.path.dirname(os.path.abspath(__file__))), "src")
SQL = os.path.join(MODULE, "data", "sql", "world")

# --- where one row names another -------------------------------------------
# Field indices from the 3.3.5 layouts. The core's own structure fixes two of
# them in SpellVisual -- HasMissile at 7, MissileModel at 8 -- and that is what
# anchors the rest. Every index below is checked at run time: a value that
# names nothing is reported, not followed.
SPELL_VISUAL_AT = (131, 132)
VISUAL_KITS_AT = (1, 2, 3, 4, 5, 6, 14, 15, 22, 23, 24, 25)
VISUAL_SOUNDS_AT = (11, 12)
VISUAL_MODEL_AT = (8,)
KIT_EFFECTS_AT = tuple(range(3, 15))
KIT_SOUND_AT = (15,)

# WHAT A SPELL POINTS AT BY INDEX. Not only visuals: a duration, a range, a
# casting time, a radius, each in a table of its own. The field is found by
# COLUMN NAME in the module's own SQL, never by counting -- being one place out
# would read a mana cost as a duration and no one would notice.
SPELL_INDEXES = {
    "Category": "SpellCategory.dbc",
    "RequiresSpellFocus": "SpellFocusObject.dbc",
    "CastingTimeIndex": "SpellCastTimes.dbc",
    "DurationIndex": "SpellDuration.dbc",
    "RangeIndex": "SpellRange.dbc",
    "EffectRadiusIndex_1": "SpellRadius.dbc",
    "EffectRadiusIndex_2": "SpellRadius.dbc",
    "EffectRadiusIndex_3": "SpellRadius.dbc",
    "RequiredTotemCategoryID_1": "TotemCategory.dbc",
    "RequiredTotemCategoryID_2": "TotemCategory.dbc",
    "RuneCostID": "SpellRuneCost.dbc",
    "SpellMissileID": "SpellMissile.dbc",
    "PowerDisplayID": "PowerDisplay.dbc",
    "SpellDescriptionVariableID": "SpellDescriptionVariables.dbc",
    "SpellDifficultyID": "SpellDifficulty.dbc",
}
NOTHING = (0, 0xFFFFFFFF)   # a field that points at nothing, both ways round

EFFECT_FILE_AT = 2          # SpellVisualEffectName: the model's path
MODEL_FILE_AT = 2           # CreatureModelData: the model's path
DISPLAY_MODEL_AT = 1        # CreatureDisplayInfo: which model it wears
DISPLAY_TEXTURES_AT = (6, 7, 8)   # and the skins laid over it
SOUND_FILES_AT = tuple(range(3, 13))   # SoundEntries: ten file names
SOUND_DIR_AT = 23                      # and the folder holding them

# WHAT MUST NOT TRAVEL UNDER ANOTHER SERVER'S NAME. The module was collected
# from a client that named its files after that server; the maps that turn
# those names into the module's own are the author's, and they live OUTSIDE
# the repository, in tools/local/origin.py (ignored by git). Without them the
# collector works at identity, which is right for anyone else: a clone has no
# such names to translate.
#
# HOW LONG THIS FILE IS MEANT TO LIVE. Not for ever. `data/` is what the
# module IS: its rows and its files are written by hand now, and everything
# fixed since it became a module of its own -- a beam, a display, two stacking
# auras, a ground kit, four model-info rows -- was written there directly and
# never collected. This file has ONE purpose left: bringing something NEW
# across from the server the module grew up in. The day nothing more is to
# come across, it leaves the published repository with tools/local/origin.py,
# and `data/` stands alone.
#
# Until then it is kept faithful: every row and file made by hand is named
# again below, in CORRECTIONS, DERIVED, EXTRA_FILES or MODULE_OWN, so that a
# collection reproduces exactly what the module ships rather than quietly
# undoing it. That is the price of keeping it, and it is paid on purpose.

# WHICH CLIENT TO COLLECT FROM. Only the one the module grew up in. A client
# the module's own installer patched carries the right names and needs no
# map -- but it is NOT a faithful source: the rows it BORROWS (54 visuals, 12
# kits, 3 effects, one display) are found by comparing the source against a
# stock client, and in a self-patched client no row of the game is altered.
# Collecting from one would leave borrowed.json empty and lose the copies.
try:
    from local.origin import NAMES, PREFIX, COLOURS, SOUNDS, FIXES, FOLDERS, UI_FOLDER
    ORIGIN = "tools/local/origin.py"
except ImportError:
    NAMES, COLOURS, SOUNDS, FIXES, FOLDERS = {}, {}, {}, {}, {}
    PREFIX = ("spheregrid_", "spheregrid_")
    UI_FOLDER = "Interface\\Spheregrid"
    ORIGIN = None

# What no reference in any DBC leads to: the module's own interface art, and
# two sheets it borrows. They are named by the Lua, which is not a table
# anything can walk, so they are named here instead.
BORROWED = (
    "Interface\\Journeys\\JourneysFrame2x.blp",
    "Interface\\FrameXML\\NewSpellBook\\NewSpellbook\\Spellbook-Parts.blp",
)


# WHAT THE MODULE'S OWN SOURCES NAME BY NUMBER. The walk below follows what
# one row says of another; it cannot see a kit the C++ plays itself, nor a
# display it morphs a player into. Those are read here, straight from the
# sources, so that adding one in the code is enough for the collector to bring
# it along.
# THE GAME'S ROWS THE MODULE USED TO REWRITE, and the identifiers of its own
# they are copied to. Row 8500 of GameObjectDisplayInfo is a Dalaran chair; the
# client the module grew up in had turned it into `11fx_phaseportal01`, which is
# what the death tunnel looks like. Rewriting it would change the chair for
# every server that installs the module, so the row is copied instead.
# WHERE THE SOURCE IS WRONG. Every row is collected as it stands; these are
# the ones the client itself got wrong, and the correction belongs HERE, not in
# the file, or the next collection would quietly undo it. The field is given by
# its index, and the comment says which column that is.
# THE LANGUAGE SLOT. A text block of 3.3.5 holds SIXTEEN slots, and Britain has
# none of its own -- it shares the United States'. The real order is 0 enUS,
# 1 koKR, 2 frFR, 3 deDE, 4 zhCN, 5 zhTW, 6 esES, 7 esMX, 8 ruRU... The columns
# of AzerothCore's `spell_dbc` name one more, `_Lang_enGB` at 1, and slide by
# one from there: the column that really holds the FRENCH is called
# `_Lang_koKR`, and the one called `_Lang_frFR` is the German. Writing to the
# field named after the language puts the French where nobody reads it.
#
# And a block is filled WHOLE. A derived row keeps its source's text in every
# slot left unsaid, so a row that only says its English and its French would
# still answer with its ancestor's words in the fourteen others.
def block(base, english, french=None):
    """Every slot of one text block: the English, and the French at slot 2."""
    out = {base + k: english for k in range(16)}
    if french:
        out[base + 2] = french
    return out


def texts(*blocks):
    """Several blocks of one row, merged into the map `derive` expects."""
    out = {}
    for one in blocks:
        out.update(one)
    return out


CORRECTIONS = {
    "Spell.dbc": {
        # Shunpo: RangeIndex (field 46) said 11, "Fifteen yards", where the
        # spell's own text and its use want thirty metres -- index 4.
        8600030: {46: 4},
        # Divine Steed: EffectBasePoints_1 (field 80) is the speed bonus less
        # one; 149 is the +150 % the spell is meant to give.
        8600010: {80: 149},
        # Meteor: SpellVisualID_1/_2 (fields 131, 132) said 7479, the game's
        # meteor, which has no cast in front of it. 30154 is that visual with
        # the fire cast kits -- a DERIVED row below.
        8600056: {131: 30154, 132: 30154},
        # The feather reserve: the aura whose stack is the number of
        # feathers left is an INDICATOR, kept on the priest at all times by
        # the module's own code. A player dismissing it with a right click
        # would be left blind until his next cast, so the row is given the
        # attribute that refuses a cancellation (0x80000000).
        8600099: {4: 0x80000000},
        # Ascendance: its texts, once "cast while moving" left it for the two
        # stacks. A correction that is a STRING goes to the string block.
        8600062: texts(
            block(170,
                  'Your magic damage is increased by $s1% for $d. Each Fire spell you cast raises your critical strike chance by 3% and each Nature spell your haste by 3%, stacking until Ascendance ends. In addition, five foes before you are struck by Flame Shock followed by a Lava Burst.',
                  "Vos dégâts magiques augmentent de $s1% pendant $d. Chaque sort de Feu que vous lancez augmente vos chances de coup critique de 3% et chaque sort de Nature votre hâte de 3%, cumulables jusqu'à la fin de l'Ascendance. De plus, cinq ennemis devant vous subissent un Horion de flammes puis une Explosion de lave."),
            block(187,
                  'Magic damage increased by $s1%. Fire spells raise critical strike chance, Nature spells raise haste.',
                  'Dégâts magiques augmentés de $s1%. Les sorts de Feu augmentent les chances de coup critique, les sorts de Nature la hâte.')),
    },
    # SHADOW WORD: DESPAIR PUT ITS GROUND EFFECT ON THE PRIEST. A spell
    # aimed at a point splits its visual in two, as every one of the game's
    # does: one kit on the caster -- his animation, his hands, his sound --
    # and one AT THE POINT, holding a base model and a sound (Flamestrike:
    # 61 and 9357; Shadowfury, which has Despair's very shape: 20154 and
    # 20155). The module had ONE kit, mixing the priest's animation with the
    # ground model, in the visual's `cast` slot -- which plays on the caster.
    # So the kit gives up the model and the sound to a kit of its own, below,
    # and the visual names that kit in its INSTANT AREA slot (field 23).
    #
    # Field 23 and not Flamestrike's field 25: the persistent slot plays only
    # while a lasting zone exists, and Flamestrike leaves the ground on fire.
    # Despair's two effects strike once and leave nothing, so it is
    # Shadowfury's instant slot that fires.
    "SpellVisualKit.dbc": {
        30044: {5: 0, 15: 0},       # base effect and sound leave the priest
    },
    "SpellVisual.dbc": {
        30044: {23: 30212},         # ... for the ground kit, at the point aimed at
    },
}

# ROWS THE SOURCE DOES NOT HAVE. Each is derived from a row that exists --
# "stock" for one of the game's, "module" for one collected above -- under an
# identifier of the module's own, with the fields that differ: integers by
# index, strings by index, and -- a sixth element, for a table whose fields
# are not all four bytes wide -- single bytes by offset. They are added after
# the corrections, so a correction can point at one.
#   SpellVisual 30154        the game's meteor (7479) with the classic fire
#                            cast kits (precast 30, cast 38) -- Meteor's
#   CreatureModelData 802158 the orb's own model; CreatureDisplayInfo 802158
#                            wears it. 802103 -- what the orb wore in the
#                            source -- is the druid's red star.
#   SpellChainEffects 2001   the beam Ray of Frost's kit asks for (its
#                            CharParamZero says 2001): Mind Flay's beam (750)
#                            with the frost texture. The source never had the
#                            row; the kit pointed at nothing.
#   SpellVisualKit 30212     Shadow Word: Despair's ground kit -- see the
#                            correction above.
#   Spell 8610038, 8610039   Ascendance's two stacks, derived from Ascendance
#                            but with TWELVE SECONDS of their own (duration 29):
#                            they outlive the ascendance that granted them,
#                            itself: an aura of their own, no second effect,
#                            no cost, no visual, the icons of Flame Shock and
#                            Lightning Bolt, their own names and texts.
# SkillLineAbility.dbc IS NOT COLLECTED. The origin never had it, and its rows
# are not copied from anywhere: they are BUILT, one per spell the module can
# teach, from two things the module already ships -- the class of a spell cell
# (mod_spheregrid_node_spell) and the base spell of a rank (spell_ranks). Each
# row is derived from a row of the game: a rank takes the line of ITS base
# spell, a cell the line written for it below. Identifiers 25001 and up, above
# the game's highest (21980).
#
# THE TREE IS A DECISION PER SPELL, and nothing in the data says it: a cell
# only knows its class. So it is written here. What is not named takes its
# class's default, itself written rather than counted -- a majority worked out
# from the game's own rows falls differently from one run to the next when two
# lines tie, and a shipped file must not move on its own.
#
#   default by class  1 Fury 256   2 Holy 594   3 Survival 51   4 Assassination 253
#                     5 Holy 56    6 Unholy 772 7 Elemental Combat 375
#                     8 Arcane 237 9 Affliction 355   11 Feral Combat 134
#
#   Sweeping Strikes 9000001 Arms 26          Spartan Shield 9000003 Protection 257
#   Final Reckoning 9000011 Retribution 184   Shield of the Inquisition 9000012 Protection 267
#   Roll the Bones 9000032 Combat 38          Symbols of Death 9000033 Subtlety 39
#   Shadow Word: Despair 9000041 Shadow Magic 78
#   Power Word: Barrier 9000042 Discipline 613
#   Bonestorm 9000052 Blood 770               Breath of Sindragosa 9000053 Frost 771
#   Meteor 9000056 Fire 8                     Ascendance 9000062 Elemental Combat 375
#   Earthquake 9000061 Enhancement 373       Spirit Link Totem 9000063 Restoration 374
#   Ray of Frost 9000073 Frost 6
#   Phantom Singularity 9000081 Affliction 355   Cataclysm 9000083 Destruction 593
#   Solstice and Equinox 9000092 Balance 574  Flourish 9000093 Restoration 573
#   Bear Leap 9010016, Shadow Prowler 9010017, Traveler's Bound 9010018 Feral Combat 134
#   Grove's Call 9010019 Restoration 573      Stellar Return 9010020 Balance 574
#
# THE FIVE FORM SPELLS (9010016 to 9010020) have no cell at all: the script
# teaches them alongside Light Stride. Nothing named them, so they had no line
# and fell into "General".
#
# AND WHAT BELONGS IN "General" HAS NO ROW AT ALL: it is the absence of a skill
# line that puts a spell in the general tab. Light Stride 9000090 is the only
# one.
DERIVED = {
    "Spell.dbc": [
        (8610038, "module", 8600062, {40: 29, 71: 6, 95: 57, 80: 2, 72: 0, 96: 0, 81: 0, 110: 0, 86: 1, 87: 0, 49: 99, 133: 678, 131: 0, 132: 0, 208: 0, 225: 1, 42: 0, 29: 0, 30: 0},
         texts(block(136, 'Ascendance: Fire', 'Ascendance : Feu'),
               block(170, 'Critical strike chance increased by $s1% per stack, for $d.',
                     "Chances de coup critique augmentées de $s1% par cumul, pendant $d."),
               block(187, 'Critical strike chance increased by $s1%.',
                     'Chances de coup critique augmentées de $s1%.'))),
        (8610039, "module", 8600062, {40: 29, 71: 6, 95: 216, 80: 2, 72: 0, 96: 0, 81: 0, 110: 0, 86: 1, 87: 0, 49: 99, 133: 62, 131: 0, 132: 0, 208: 0, 225: 1, 42: 0, 29: 0, 30: 0},
         texts(block(136, 'Ascendance: Nature', 'Ascendance : Nature'),
               block(170, 'Haste increased by $s1% per stack, for $d.',
                     "Hâte augmentée de $s1% par cumul, pendant $d."),
               block(187, 'Haste increased by $s1%.',
                     'Hâte augmentée de $s1%.'))),
    ],
    "SpellVisual.dbc": [
        (30154, "stock", 7479, {1: 30, 2: 38}, {}),
    ],
    "SpellVisualKit.dbc": [
        # Despair's ground kit: no animation (an area kit animates nothing),
        # the shadow model and the sound the caster's kit gave up. The values
        # are said outright rather than copied, because the row it derives
        # from has just been emptied of them by the correction above.
        (30212, "module", 30044, {2: 0xFFFFFFFF, 5: 8200221, 15: 990112}, {}),
    ],
    "CreatureModelData.dbc": [
        (802158, "module", 802103, {}, {2: "spells\\11fx_arcaneorb02.mdx"}),
    ],
    "CreatureDisplayInfo.dbc": [
        # half the model's size: the orb is a fist, not a head
        (802158, "module", 802103, {1: 802158, 4: 0x3F000000}, {}),   # 4 = CreatureModelScale, 0.5f
    ],
    # NOTHING TO DERIVE. Chain 2001 -- the beam the kit's CharParamZero
    # names -- EXISTS in the source, with a texture of its own,
    # 8fx_jaina_glacialraybeam.blp, Jaina's glacial ray. It is not a texture
    # of 3.3.5 and the source ships it; it is listed among the extra files
    # below. I twice built a row that was already there, first from Mind
    # Flay's beam and then from the game's chain 1, and neither looked like
    # the source: the row is collected, not invented.
    "SpellChainEffects.dbc": [],
}

# FILES ONLY A DERIVED ROW NAMES, or that no row names at all: followed like
# any model -- skins and textures included -- and shipped when a stock client
# lacks them.
EXTRA_FILES = (
    "spells\\11fx_arcaneorb02.mdx",
    "spells\\11fx_phaseportal01.mdx",
    # The texture chain 2001 names: Jaina's glacial ray, not a texture of
    # 3.3.5, which the source ships itself.
    "Textures\\SpellChainEffects\\8fx_jaina_glacialraybeam.blp",
)

# WHAT IS THE MODULE'S OWN, and must not be taken from a client. One texture:
# the fully transparent square a particle emitter of Light of Dawn draws over
# its flare. Every client that ran the module kept it palettized and without a
# mipmap chain, which a particle emitter renders as GREEN SQUARES; the module
# carries its own, in data/art, and a collection leaves it where it is.
MODULE_OWN = (
    "spells\\spheregrid_vide.blp",
)


# The archive the installer writes; see `install.py`.
ARCHIVE = "patch-Z.MPQ"

GAME_OBJECT_DISPLAYS = {8500: 802100}

CPP_RANGES = {
    "kit": (30000, 30099),
    "display": (802100, 802199),
    "emote": (990000, 990999),
}


def named_by_cpp(kind):
    """Every identifier of that kind the module's C++ names.

    Comments and strings are set aside: a number in a sentence is not a
    reference, and a number in a string is data of another sort.
    """
    low, high = CPP_RANGES[kind]
    out = set()
    for base, _, names in os.walk(CPP):
        for name in sorted(names):
            if not name.endswith((".cpp", ".h")):
                continue
            text = io.open(os.path.join(base, name),
                           encoding="utf-8", newline="").read()
            text = re.sub(r'"(?:[^"\\]|\\.)*"', '""', text)
            text = re.sub(r"/\*.*?\*/", " ", text, flags=re.S)
            text = re.sub(r"//.*", " ", text)
            for m in re.finditer(r"\b(\d{5,9})\b", text):
                value = int(m.group(1))
                if low <= value <= high:
                    out.add(value)
    return out


# WHERE THE MODULE'S COPIES OF THE GAME'S ROWS LAND. The module grew up in a
# client where rows OF THE GAME had been rewritten -- a visual one of our spells
# borrows, a kit it calls, an effect that kit names. On a stock client those
# rows are Blizzard's again, and the spell looks like nothing. A module does not
# rewrite the game's rows: each one is COPIED under an identifier of its own,
# and our rows are made to point at the copy. Each block is free in a stock
# client and clear of the ranges the module already uses.
BORROWED_BASE = {
    "SpellVisual.dbc": 30100,
    "SpellVisualKit.dbc": 30200,
    "SpellVisualEffectName.dbc": 8200300,
}
SPELL_VISUAL_FIELDS = (131, 132)        # Spell.dbc: SpellVisualID_1, _2


def rewritten_rows(source, stock, name, wanted):
    """Which of `wanted` the source describes differently from a stock client.

    A string field holds an OFFSET into the file's own block, and two files do
    not lay their blocks out alike: comparing the raw value would call every
    row different. The text is compared instead.
    """
    here, there = read_dbc(source, name), read_dbc(stock, name)
    ours, theirs = here.by_id(), there.by_id()
    strings = dbc.string_fields(there)
    out = set()
    for identifier in sorted(wanted):
        a, b = ours.get(identifier), theirs.get(identifier)
        if a is None or b is None:
            continue
        for index in range(here.field_count):
            if index in strings:
                same = (dbc.read_string(here, a, index)
                        == dbc.read_string(there, b, index))
            else:
                same = here.field(a, index) == there.field(b, index)
            if not same:
                out.add(identifier)
                break
    return out


def repointed(part, fields, mapping):
    """A copy of the DBC where every named field is put through the mapping."""
    if not mapping:
        return part
    records = []
    for record in part.records:
        record = bytearray(record)
        for index in fields:
            value = struct.unpack_from("<I", record, index * 4)[0]
            if value in mapping:
                struct.pack_into("<I", record, index * 4, mapping[value])
        records.append(bytes(record))
    return dbc.Dbc(part.field_count, part.record_size, records, part.strings)


def read_dbc(chain, name):
    raw = chain.read(r"DBFilesClient\%s" % name)
    handle = tempfile.NamedTemporaryFile(suffix=".dbc", delete=False)
    handle.write(raw)
    handle.close()
    table = dbc.read(handle.name)
    os.unlink(handle.name)
    return table


def follow(source, ids, fields, valid, what, problems):
    """The rows those fields name, checking each one leads somewhere."""
    rows, out = source.by_id(), set()
    for identifier in ids:
        record = rows.get(identifier)
        if record is None:
            continue
        for index in fields:
            value = source.field(record, index)
            if not value:
                continue
            if value in valid:
                out.add(value)
            else:
                problems.append((what, identifier, index, value))
    return out


def renamed(path):
    """A path with every trace of another server's name taken out of it."""
    out = path
    low = out.lower()
    for was, now in FOLDERS.items():
        if was in low:
            start = low.index(was)
            out = out[:start] + now + out[start + len(was):]
            low = out.lower()
    for was, now in NAMES.items():
        if was in low:
            start = low.index(was)
            out = out[:start] + now + out[start + len(was):]
            low = out.lower()
    for was, now in FIXES.items():
        if out.lower() == was.lower():
            return now
    for was, now in SOUNDS.items():
        if out == was:
            return now
    while PREFIX[0] in low:
        start = low.index(PREFIX[0])
        out = out[:start] + PREFIX[1] + out[start + len(PREFIX[0]):]
        low = out.lower()
    for was, now in COLOURS.items():
        if was in low:
            start = low.index(was)
            out = out[:start] + now + out[start + len(was):]
            low = out.lower()
    return out


def has(chain, path):
    """Whether a client can serve this path, `.mdx` standing for `.m2`."""
    path = path.replace("/", "\\")
    if chain.has(path):
        return True
    return path.lower().endswith(".mdx") and chain.has(path[:-4] + ".m2")


def real(chain, path):
    """The path a client actually stores, which may end in `.m2`."""
    path = path.replace("/", "\\")
    if chain.has(path):
        return path
    if path.lower().endswith(".mdx") and chain.has(path[:-4] + ".m2"):
        return path[:-4] + ".m2"
    return None


def main():
    parser = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--source", required=True,
                        help="a client Data directory where the module runs")
    parser.add_argument("--stock", required=True,
                        help="an untouched client Data directory")
    parser.add_argument("--locale-source", default="frFR")
    parser.add_argument("--locale-stock", default="enUS")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    # THE SOURCE OPENS EVERYTHING, its own `patch-z` first of all: that is
    # where the module's content lives, and it carries the same name as the one
    # the installer writes. Only the REFERENCE client sets ours aside -- with
    # the module installed it would answer with our own rows, and the collector
    # would conclude it has nothing left to add.
    print("origin maps: %s" % (ORIGIN or "none -- collecting at identity"))
    source = mpq.open_client(args.source, locale=args.locale_source)
    stock = mpq.open_client(args.stock, locale=args.locale_stock,
                            ignore=(ARCHIVE,))
    problems = []

    tables, added = {}, {}
    for name in ("SpellVisual.dbc", "SpellVisualKit.dbc",
                 "SpellVisualEffectName.dbc", "SoundEntries.dbc"):
        here, there = read_dbc(source, name), read_dbc(stock, name)
        tables[name] = here
        added[name] = set(here.ids()) - set(there.ids())

    # --- the walk ---------------------------------------------------------
    # The module's spells, taken from the client and narrowed to what its own
    # SQL declares. Reading its own output here would have made the tool depend
    # on a previous run of itself.
    spell_table = read_dbc(source, "Spell.dbc")
    spells = dbc.subset(spell_table,
                        owned.identifiers(SQL, 8500000, 8619999),
                        dbc.string_fields(spell_table))
    wanted = set()
    for record in spells.records:
        for index in SPELL_VISUAL_AT:
            wanted.add(spells.field(record, index))
    wanted.discard(0)

    visuals = sorted(wanted & added["SpellVisual.dbc"])
    kits = follow(tables["SpellVisual.dbc"], visuals, VISUAL_KITS_AT,
                  set(tables["SpellVisualKit.dbc"].ids()), "kit", problems)
    # The kits the C++ plays itself, added before the effects are followed:
    # they drag their own effects and their own files along.
    played = named_by_cpp("kit")
    kits |= played
    kits = sorted(kits & added["SpellVisualKit.dbc"])
    also = sorted(played & set(kits))
    if also:
        print("  kits played by the C++  %s" % also)
    effects = follow(tables["SpellVisualKit.dbc"], kits, KIT_EFFECTS_AT,
                     set(tables["SpellVisualEffectName.dbc"].ids()), "effect", problems)
    effects |= follow(tables["SpellVisual.dbc"], visuals, VISUAL_MODEL_AT,
                      set(tables["SpellVisualEffectName.dbc"].ids()), "missile", problems)
    effects = sorted(effects & added["SpellVisualEffectName.dbc"])
    sounds = follow(tables["SpellVisual.dbc"], visuals, VISUAL_SOUNDS_AT,
                    set(tables["SoundEntries.dbc"].ids()), "sound", problems)
    sounds |= follow(tables["SpellVisualKit.dbc"], kits, KIT_SOUND_AT,
                     set(tables["SoundEntries.dbc"].ids()), "kit sound", problems)
    sounds = sorted(sounds & added["SoundEntries.dbc"])

    print("THE WALK")
    print("  SpellVisual            %3d named, %3d added by the module" % (len(wanted), len(visuals)))
    print("  SpellVisualKit         %3d" % len(kits))
    print("  SpellVisualEffectName  %3d" % len(effects))
    print("  SoundEntries           %3d" % len(sounds))
    if problems:
        print("  %d reference(s) name nothing, e.g. %s" % (len(problems), problems[:2]))

    # --- the game's rows the module used to lean on -------------------------
    # Everything above collects what the source ADDS. What it also did was
    # REWRITE rows of the game that our own rows point at. Each is copied under
    # an identifier of the module's; the maps say which went where.
    stock_visuals = sorted(wanted - added["SpellVisual.dbc"])
    changed = rewritten_rows(source, stock, "SpellVisual.dbc", stock_visuals)
    visual_map = {v: BORROWED_BASE["SpellVisual.dbc"] + i
                  for i, v in enumerate(sorted(changed))}

    # The kits every visual of ours names -- the module's own AND the copies.
    all_visuals = sorted(set(visuals) | changed)
    stock_kits = follow(tables["SpellVisual.dbc"], all_visuals, VISUAL_KITS_AT,
                        set(tables["SpellVisualKit.dbc"].ids()), "kit", problems)
    stock_kits = sorted(stock_kits - added["SpellVisualKit.dbc"])
    changed_kits = rewritten_rows(source, stock, "SpellVisualKit.dbc", stock_kits)
    kit_map = {k: BORROWED_BASE["SpellVisualKit.dbc"] + i
               for i, k in enumerate(sorted(changed_kits))}

    # The effects every kit of ours names, and the missiles every visual names.
    all_kits = sorted(set(kits) | changed_kits)
    stock_effects = follow(tables["SpellVisualKit.dbc"], all_kits, KIT_EFFECTS_AT,
                           set(tables["SpellVisualEffectName.dbc"].ids()),
                           "effect", problems)
    stock_effects |= follow(tables["SpellVisual.dbc"], all_visuals, VISUAL_MODEL_AT,
                            set(tables["SpellVisualEffectName.dbc"].ids()),
                            "missile", problems)
    stock_effects = sorted(stock_effects - added["SpellVisualEffectName.dbc"])
    changed_effects = rewritten_rows(source, stock, "SpellVisualEffectName.dbc",
                                     stock_effects)
    effect_map = {e: BORROWED_BASE["SpellVisualEffectName.dbc"] + i
                  for i, e in enumerate(sorted(changed_effects))}

    print("  the game's rows copied  %3d visual(s), %3d kit(s), %3d effect(s)"
          % (len(visual_map), len(kit_map), len(effect_map)))

    visuals = sorted(set(visuals) | changed)
    kits = sorted(set(kits) | changed_kits)
    effects = sorted(set(effects) | changed_effects)
    borrowed = {"SpellVisual.dbc": visual_map, "SpellVisualKit.dbc": kit_map,
                "SpellVisualEffectName.dbc": effect_map}

    # --- the files those rows name ----------------------------------------
    paths = set()
    effect_table = tables["SpellVisualEffectName.dbc"]
    rows = effect_table.by_id()
    for identifier in effects:
        path = dbc.read_string(effect_table, rows[identifier], EFFECT_FILE_AT)
        if path.strip():
            paths.add(path)

    sound_table = tables["SoundEntries.dbc"]
    rows = sound_table.by_id()
    for identifier in sounds:
        record = rows[identifier]
        folder = dbc.read_string(sound_table, record, SOUND_DIR_AT).rstrip("\\")
        for index in SOUND_FILES_AT:
            leaf = dbc.read_string(sound_table, record, index)
            if leaf.strip():
                paths.add((folder + "\\" + leaf) if folder else leaf)

    # --- the other door a model comes through -----------------------------
    # A creature's appearance names one too, and its own skins over it. Each
    # skin belongs to THAT appearance's model: it carries neither folder nor
    # extension, and sits beside the model the client is about to load.
    creature_models = read_dbc(source, "CreatureModelData.dbc").by_id()
    creature_displays = read_dbc(source, "CreatureDisplayInfo.dbc")
    ours_displays = set(owned.identifiers(
        SQL, 802001, 802999,
        tables=("creature_template_model", "creature_model_info")))
    # A shape a spell turns a player into wears no creature: no SQL row names
    # it, and only the C++ does -- the three forms of Ascendance among them.
    morphed = named_by_cpp("display") - ours_displays
    if morphed:
        print("  displays named by the C++  %s" % sorted(morphed))
        ours_displays |= morphed
    rows = creature_displays.by_id()
    models, skins_over = 0, 0
    for identifier in sorted(ours_displays):
        record = rows.get(identifier)
        if record is None:
            continue
        model = creature_models.get(
            creature_displays.field(record, DISPLAY_MODEL_AT))
        if model is None:
            continue
        table = read_dbc(source, "CreatureModelData.dbc")
        path = dbc.read_string(table, model, MODEL_FILE_AT).strip()
        if not path:
            continue
        paths.add(path)
        models += 1
        folder = path.replace("/", "\\").rsplit("\\", 1)[0]
        for index in DISPLAY_TEXTURES_AT:
            leaf = dbc.read_string(creature_displays, record, index).strip()
            if leaf:
                paths.add(folder + "\\" + leaf + ".blp")
                skins_over += 1
    print("  creature models        %3d, skins over them %3d" % (models, skins_over))

    # a model drags its skins and its textures with it
    grown = set(paths)
    for path in sorted(paths):
        actual = real(source, path)
        if actual is None or not actual.lower().endswith(".m2"):
            continue
        raw = source.read(actual)
        if not m2.is_model(raw):
            continue
        # A model declares how many views it has ROOM for, not how many ship:
        # Blizzard's own ghoul claims four and delivers two. Only the skins
        # that exist are followed, or the walk reports phantoms.
        grown.update(s for s in m2.skins(actual, raw) if has(source, s))
        grown.update(m2.textures(raw))

    # The model of a display the module copies: no row of ours named it until
    # now, so the walk above never reached it.
    gob_table = read_dbc(source, "GameObjectDisplayInfo.dbc")
    gob_rows = gob_table.by_id()
    gob_file = min(dbc.string_fields(gob_table))
    for was in sorted(GAME_OBJECT_DISPLAYS):
        record = gob_rows.get(was)
        if record is None:
            continue
        path = dbc.read_string(gob_table, record, gob_file).strip()
        if path:
            grown.add(path)
            actual = real(source, path)
            if actual is not None:
                raw = source.read(actual)
                if m2.is_model(raw):
                    grown.update(s for s in m2.skins(actual, raw)
                                 if has(source, s))
                    grown.update(m2.textures(raw))

    # The files a derived row names, or nothing names: models are followed
    # down to their skins and textures, like the ones the rows led to.
    for path in EXTRA_FILES:
        grown.add(path)
        actual = real(source, path)
        if actual is not None:
            raw = source.read(actual)
            if m2.is_model(raw):
                grown.update(s for s in m2.skins(actual, raw) if has(source, s))
                grown.update(m2.textures(raw))

    # --- what no reference leads to ---------------------------------------
    grown.update(BORROWED)
    catalogue = source.names()
    ours = [n for n in catalogue if UI_FOLDER.lower() in n.lower()]
    grown.update(ours)
    table = read_dbc(source, "SpellIcon.dbc")
    field = min(dbc.string_fields(table))
    rows = table.by_id()
    wanted_icons = (set(spells.field(r, i) for r in spells.records
                        for i in (133, 134)) - {0}) & set(table.ids())
    named = 0
    for identifier in sorted(wanted_icons):
        leaf = dbc.read_string(table, rows[identifier], field).strip()
        if leaf:
            grown.add(leaf + ".blp")
            named += 1
    print("  interface art          %3d, borrowed %d, spell icons %3d"
          % (len(ours), len(BORROWED), named))

    missing = sorted(p for p in grown if not has(stock, p))
    print()
    print("THE FILES")
    print("  %d named, %d of them absent from a stock client" % (len(grown), len(missing)))

    lost = [p for p in missing if not has(source, p)]
    if lost:
        print("  %d CANNOT BE FOUND AT ALL: %s" % (len(lost), lost[:4]))

    # --- copy them in ------------------------------------------------------
    kinds, taken, rewritten = {}, 0, [0]
    own = {p.lower() for p in MODULE_OWN}
    for path in missing:
        if renamed(path).lower() in own:
            continue                    # the module's own, in data/art already
        actual = real(source, path)
        if actual is None:
            continue
        landing = os.path.join(ART, renamed(path).replace("\\", os.sep))
        if actual.lower().endswith(".m2") and path.lower().endswith(".mdx"):
            landing = landing[:-4] + ".m2"
        kinds[os.path.splitext(landing)[1].lower()] = \
            kinds.get(os.path.splitext(landing)[1].lower(), 0) + 1
        taken += 1
        if not args.dry_run:
            os.makedirs(os.path.dirname(landing), exist_ok=True)
            raw = source.read(actual)
            if landing.lower().endswith(".m2") and m2.is_model(raw):
                raw, touched = m2.rename_textures(raw, renamed)
                rewritten[0] += 1 if touched else 0
            open(landing, "wb").write(raw)
    print("  %d taken: %s" % (taken, ", ".join(
        "%s %d" % (k, v) for k, v in sorted(kinds.items()))))
    for path in MODULE_OWN:
        print("  %s is the module's own: left as it stands" % path)
    if rewritten[0]:
        print("  %d model(s) had their own texture names rewritten" % rewritten[0])

    # --- and the rows themselves ------------------------------------------
    # These four DBC are never read by a server. They ship as the module's own
    # rows, like the others, and the installer merges them into the client.
    print()
    print("THE ROWS")
    # Only the models that do not already exist. An appearance may well point
    # at one of the game's own -- display 802102 wears the invisible stalker --
    # and shipping a row for it would mean overwriting something that is not
    # ours. The installer refuses that, and it is right to.
    display_table = read_dbc(source, "CreatureDisplayInfo.dbc")
    stock_models = set(read_dbc(stock, "CreatureModelData.dbc").ids())
    model_ids = set()
    rows = display_table.by_id()
    for identifier in sorted(ours_displays):
        record = rows.get(identifier)
        if record is None:
            continue
        model = display_table.field(record, DISPLAY_MODEL_AT)
        if model not in stock_models:
            model_ids.add(model)
    # The spells, the items, and what they point at -- all read from the client
    # as well. A server does not read these either, and where the two had been
    # kept apart they had drifted: fifteen fields on the spells, and a whole
    # locale slot the rebuild from SQL left empty.
    spell_ids = sorted(set(owned.identifiers(SQL, 8500000, 8619999))
                       & set(read_dbc(source, "Spell.dbc").ids()))
    item_table = read_dbc(source, "Item.dbc")
    item_ids = sorted(set(owned.identifiers(SQL, 803100, 803699))
                      & set(item_table.ids()))

    icon_table = read_dbc(source, "SpellIcon.dbc")
    stock_icons = set(read_dbc(stock, "SpellIcon.dbc").ids())
    icon_ids = sorted((set(spells.field(r, i) for r in spells.records
                           for i in (133, 134)) - {0})
                      & set(icon_table.ids()) - stock_icons)

    display_info = read_dbc(source, "ItemDisplayInfo.dbc")
    stock_info = set(read_dbc(stock, "ItemDisplayInfo.dbc").ids())
    rows_item = item_table.by_id()
    item_info = sorted({item_table.field(rows_item[i], 5) for i in item_ids
                        if i in rows_item} - {0}
                       & set(display_info.ids()) - stock_info)

    # Everything a spell points at by index, gathered the same way: what the
    # module's spells name, that a stock client has not.
    columns = None
    for names, _ in sqlrows.insertions(
            os.path.join(SQL, "05_spells.sql"), "spell_dbc"):
        if len(names) == 234:
            columns = {name: i for i, name in enumerate(names)}
    indexed = []
    for column, table_name in sorted(SPELL_INDEXES.items()):
        at = columns[column]
        values = {spells.field(r, at) for r in spells.records} - set(NOTHING)
        if not values:
            continue
        here = read_dbc(source, table_name)
        there = read_dbc(stock, table_name)
        mine = sorted(values & set(here.ids()) - set(there.ids()))
        if mine:
            indexed.append((table_name, mine))
            print("  %-28s %d row(s) the module adds" % (table_name, len(mine)))

    # The emotes the C++ plays. Nothing points at them either: they are read
    # from the sources, like the kits.
    emote_table = read_dbc(source, "Emotes.dbc")
    emote_ids = sorted(named_by_cpp("emote") & set(emote_table.ids())
                       - set(read_dbc(stock, "Emotes.dbc").ids()))
    if emote_ids:
        print("  Emotes.dbc                   %d row(s) the module adds"
              % len(emote_ids))

    emitted = indexed + [("Spell.dbc", spell_ids), ("Item.dbc", item_ids),
               ("Emotes.dbc", emote_ids),
               ("GameObjectDisplayInfo.dbc", sorted(GAME_OBJECT_DISPLAYS)),
               ("SpellIcon.dbc", icon_ids), ("ItemDisplayInfo.dbc", item_info),
               ("SpellVisual.dbc", visuals), ("SpellVisualKit.dbc", kits),
               ("SpellVisualEffectName.dbc", effects), ("SoundEntries.dbc", sounds),
               ("CreatureDisplayInfo.dbc", sorted(ours_displays)),
               ("CreatureModelData.dbc", sorted(model_ids)),
               ("SpellChainEffects.dbc", [])]
    for name, ids in emitted:
        table = tables.get(name) or read_dbc(source, name)
        fields = dbc.string_fields_of(name, table)
        part = dbc.subset(table, ids, fields)

        # The renames are worked out from the rows themselves: a substitution
        # that guessed at paths could quietly match nothing.
        changes = {}
        for record in part.records:
            for index in sorted(fields):
                text = dbc.read_string(part, record, index)
                new = renamed(text)
                if new != text:
                    changes[text] = new
        if changes:
            part = dbc.rename_strings(part, fields, changes)

        # A row copied from the game takes an identifier of the module's own.
        if name == "GameObjectDisplayInfo.dbc":
            part = dbc.renumber(part, GAME_OBJECT_DISPLAYS)

        # THE COPIES TAKE THEIR OWN IDENTIFIERS, and every row of ours that
        # pointed at the game's row now points at the copy.
        if name in borrowed:
            part = dbc.renumber(part, borrowed[name])
        if name == "Spell.dbc":
            part = repointed(part, SPELL_VISUAL_FIELDS, borrowed["SpellVisual.dbc"])
        elif name == "SpellVisual.dbc":
            part = repointed(part, VISUAL_KITS_AT, borrowed["SpellVisualKit.dbc"])
            part = repointed(part, VISUAL_MODEL_AT, borrowed["SpellVisualEffectName.dbc"])
        elif name == "SpellVisualKit.dbc":
            part = repointed(part, KIT_EFFECTS_AT, borrowed["SpellVisualEffectName.dbc"])

        corrections = CORRECTIONS.get(name)
        if corrections:
            records, done, block = [], 0, bytearray(part.strings)
            for record in part.records:
                wanted = corrections.get(part.field(record, 0))
                if wanted:
                    record = bytearray(record)
                    for at, value in sorted(wanted.items()):
                        if isinstance(value, str):
                            # a text: appended to the block, the field
                            # pointed at it -- nothing else in the block moves
                            struct.pack_into("<I", record, at * 4, len(block))
                            block += value.encode("utf-8") + bytes(1)
                        else:
                            struct.pack_into("<I", record, at * 4, value)
                    record = bytes(record)
                    done += 1
                records.append(record)
            part = dbc.Dbc(part.field_count, part.record_size, records,
                           bytes(block))
            if done:
                print("    %-38s %d row(s) corrected" % ("", done))

        for spec in DERIVED.get(name, ()):
            new_id, where, from_id, ints, texts = spec[:5]
            bytes_at = spec[5] if len(spec) > 5 else None
            origin = part if where == "module" else read_dbc(stock, name)
            if where == "module":
                part = dbc.derive(part, from_id, new_id, fields, ints, texts, bytes_at)
            else:
                # A row of the game joins a table that may not hold it: the
                # record is taken from the game's table, its strings re-laid
                # into ours.
                grown_part = dbc.derive(origin, from_id, new_id,
                                        dbc.string_fields_of(name, origin), ints, texts,
                                        bytes_at)
                taken_row = dbc.subset(grown_part, [new_id], fields)
                part = dbc.concat([part, taken_row], fields) if len(part) else taken_row
            print("    %-38s row %d derived from %s %d" % ("", new_id, where, from_id))

        target = os.path.join(DBCS, "spheregrid_" + name)
        if not args.dry_run:
            os.makedirs(DBCS, exist_ok=True)
            dbc.write(target, part)
        # The identifiers as WRITTEN: a copied row has just taken one of ours.
        written = part.ids()
        marks = written and (min(written), max(written)) or (0, 0)
        print("    %-38s %3d row(s), id %d..%d%s"
              % ("spheregrid_" + name, len(part), marks[0], marks[1],
                 ", %d path(s) renamed" % len(changes) if changes else ""))

    # What was copied where, for the SQL to follow and for anyone to read.
    if not args.dry_run:
        import json
        with io.open(os.path.join(DBCS, "borrowed.json"), "w",
                     encoding="utf-8", newline="\n") as f:
            json.dump({name: {str(k): v for k, v in sorted(m.items())}
                       for name, m in sorted(borrowed.items())},
                      f, indent=2, sort_keys=True)
            f.write("\n")

    source.close()
    stock.close()


if __name__ == "__main__":
    main()
